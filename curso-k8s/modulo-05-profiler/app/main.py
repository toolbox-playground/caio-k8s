import os
import re
import time
import random
import logging

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

# ============================================================
# Pyroscope — Continuous Profiling + Span Profiles
# ============================================================
# São dois pacotes com funções distintas. Ambos são necessários.
#
# ┌─────────────────────────────────────────────────────────┐
# │ 1. pyroscope-io  (pip install pyroscope-io)             │
# │    Profiling contínuo, independente de traces.          │
# │                                                         │
# │    • Amostra o call stack Python a cada ~10ms           │
# │    • Agrega as amostras em um flame graph (pprof)       │
# │    • Envia o profile ao Pyroscope Server a cada 15s     │
# │    • Overhead: <1% CPU, <5MB RAM                        │
# │    • Implementação em Rust — Python 3.10+, sem gcc      │
# └─────────────────────────────────────────────────────────┘
#
# ┌─────────────────────────────────────────────────────────┐
# │ 2. pyroscope-otel  (pip install pyroscope-otel)         │
# │    Bridge entre OTel e Pyroscope (Span Profiles).       │
# │                                                         │
# │    • Registra um SpanProcessor no TracerProvider        │
# │    • Quando um span abre, gera um profile_id único      │
# │    • Injeta pyroscope.profile.id como atributo do span  │
# │    • Associa esse profile_id ao profile de CPU gravado  │
# │    • Resultado: Tempo consegue apontar para o Pyroscope │
# └─────────────────────────────────────────────────────────┘
#
# Fluxo completo de uma requisição:
#
#   request entra
#       │
#       ▼
#   span abre  ──► PyroscopeSpanProcessor injeta profile_id no span
#       │
#       ├──► pyroscope-io grava CPU amostrado com esse profile_id
#       │
#       ▼
#   span fecha ──► BatchSpanProcessor envia span (+ profile_id) ao Tempo
#                  pyroscope-io envia profile (+ profile_id) ao Pyroscope
#
#   No Grafana:
#       Tempo (span)  ──► clica "Profiles for this span"
#       Pyroscope     ◄── busca pelo profile_id  → exibe flame graph
#
# REGRA CRÍTICA: application_name (Pyroscope) == OTEL_SERVICE_NAME (OTel)
# Sem essa correspondência o Grafana não consegue correlacionar.
# ============================================================
import pyroscope
from pyroscope.otel import PyroscopeSpanProcessor

pyroscope.configure(
    # application_name → aparece como "service_name" na UI do Grafana Pyroscope.
    # DEVE ser idêntico ao OTEL_SERVICE_NAME para que a correlação
    # Trace → Profile funcione. O Tempo usa esse nome para localizar
    # o datasource correto ao renderizar "Profiles for this span".
    application_name=os.getenv("PYROSCOPE_APPLICATION_NAME", "ranking-api"),

    # server_address → URL HTTP do Pyroscope Server acessível de dentro do Pod.
    # Formato canônico no Kubernetes:
    #   http://<service-name>.<namespace>.svc.cluster.local:<porta>
    # Porta padrão: 4040 (HTTP ingest)
    server_address=os.getenv("PYROSCOPE_SERVER_ADDRESS", "http://pyroscope.monitoring.svc.cluster.local:4040"),

    # tags → labels adicionados a TODOS os profiles deste processo.
    # Aparecem como seletores no Grafana Pyroscope para:
    #   • Filtrar: {service_name="ranking-api", environment="prod"}
    #   • Comparar versões: diff flame graph v1.0.0 vs v2.0.0
    # Combine com tag_wrapper() nos endpoints para granularidade por rota.
    tags={
        "environment": os.getenv("DEPLOYMENT_ENV", "kind-dev"),
        "version":     "2.0.0",
    },
)

# ============================================================
# OpenTelemetry — Setup (mantido do Módulo 04)
# ============================================================
from opentelemetry import trace, metrics
from opentelemetry.sdk.resources import Resource, SERVICE_NAME
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.exporter.otlp.proto.grpc._log_exporter import OTLPLogExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

resource = Resource.create({
    SERVICE_NAME: os.getenv("OTEL_SERVICE_NAME", "ranking-api"),
    "service.version": "2.0.0",
    "deployment.environment": os.getenv("DEPLOYMENT_ENV", "kind-dev"),
})

OTEL_ENDPOINT = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector.otel.svc.cluster.local:4317")

# ── Traces ───────────────────────────────────────────────────
tracer_provider = TracerProvider(resource=resource)

# BatchSpanProcessor → exporta spans para o OTel Collector via gRPC.
# O Collector faz o roteamento: spans → Tempo, métricas → Prometheus.
tracer_provider.add_span_processor(
    BatchSpanProcessor(OTLPSpanExporter(endpoint=OTEL_ENDPOINT, insecure=True))
)

# ── Span Profiles bridge (Pyroscope ↔ Tempo) ─────────────────
# PyroscopeSpanProcessor implementa a interface SpanProcessor do OTel.
#
# O que ele faz em cada span:
#   on_start()  → gera profile_id único e injeta em span.attributes
#                 como pyroscope.profile.id = "<hex-id>"
#               → sinaliza ao pyroscope-io para marcar o profile
#                 corrente com esse mesmo profile_id
#   on_end()    → nenhuma ação extra (o profile_id já está no span)
#
# Pré-requisito no Grafana (configuração única, sem código):
#   Grafana → Connections → Tempo datasource
#   → seção "Trace to profiles"
#   → Profile datasource: Grafana Pyroscope
#   → Profile type: process_cpu:cpu:nanoseconds:cpu:nanoseconds
#   → Custom query: {service_name="${__tags[service.name]}"}
#
# Verificação: abra qualquer span no Grafana Explore → Tempo.
# O atributo pyroscope.profile.id deve estar visível nos detalhes
# e o botão "Profiles for this span" deve aparecer no painel lateral.
tracer_provider.add_span_processor(PyroscopeSpanProcessor())

trace.set_tracer_provider(tracer_provider)
tracer = trace.get_tracer(__name__)

# ── Métricas ─────────────────────────────────────────────────
metric_reader = PeriodicExportingMetricReader(
    OTLPMetricExporter(endpoint=OTEL_ENDPOINT, insecure=True),
    export_interval_millis=5000,
)
meter_provider = MeterProvider(resource=resource, metric_readers=[metric_reader])
metrics.set_meter_provider(meter_provider)
meter = metrics.get_meter(__name__)

scores_submitted = meter.create_counter(
    "scores_submitted_total",
    description="Total de pontuações submetidas",
)
api_errors = meter.create_counter(
    "api_errors_total",
    description="Total de erros da API por endpoint e motivo",
)
security_events = meter.create_counter(
    "security_events_total",
    description="Eventos de segurança classificados por tipo — mapeados para OWASP Top 10",
)
_INJECTION_CHARS = re.compile(r"['\";<>\\%$&|`]")
request_duration = meter.create_histogram(
    "request_duration_ms",
    description="Duração das requisições em milissegundos",
    unit="ms",
)

# ── Logs ─────────────────────────────────────────────────────
logger_provider = LoggerProvider(resource=resource)
logger_provider.add_log_record_processor(
    BatchLogRecordProcessor(OTLPLogExporter(endpoint=OTEL_ENDPOINT, insecure=True))
)
otel_handler = LoggingHandler(level=logging.DEBUG, logger_provider=logger_provider)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("ranking-api")
logger.addHandler(otel_handler)

# ============================================================
# FastAPI App
# ============================================================

app = FastAPI(
    title="Ranking API",
    description="Leaderboard para jogadores — instrumentado com OpenTelemetry + Pyroscope",
    version="2.0.0",
)

FastAPIInstrumentor.instrument_app(app)

rankings: dict[str, int] = {
    "mario":  9999,
    "luigi":  8500,
    "yoshi":  7200,
    "peach":  6800,
    "bowser": 5100,
}


class ScoreRequest(BaseModel):
    player: str
    score: int


# ============================================================
# Endpoints
# ============================================================

@app.get("/health")
def health():
    """Health check — usado pelo readinessProbe e livenessProbe."""
    return {"status": "ok", "service": "ranking-api", "version": "2.0.0"}


@app.get("/rankings")
def get_rankings():
    """
    Retorna o top 10 jogadores ordenados por pontuação.

    Pyroscope: o bloco tag_wrapper rotula o tempo de CPU gasto
    neste endpoint como endpoint="/rankings". No Grafana Pyroscope
    você pode filtrar por label endpoint="/rankings" para ver
    exclusivamente o flame graph deste handler.

    Trace: span 'get-rankings' com span filho 'db-read'.
    """
    start = time.monotonic()

    # ── Pyroscope tag_wrapper ─────────────────────────────────
    # Tudo que executar dentro deste bloco "with" terá o label
    # endpoint="/rankings" adicionado aos profiles.
    #
    # Isso permite no Grafana Pyroscope:
    #   Filtrar: {service_name="ranking-api", endpoint="/rankings"}
    #   Comparar: /rankings vs /score em um diff flame graph
    #
    # Sem tag_wrapper, todos os endpoints aparecem misturados no mesmo flame graph.
    with pyroscope.tag_wrapper({"endpoint": "/rankings"}):
        with tracer.start_as_current_span("get-rankings") as span:
            logger.info("Consultando rankings", extra={"endpoint": "/rankings"})

            with tracer.start_as_current_span("db-read") as db_span:
                db_span.set_attribute("db.system", "postgresql")
                db_span.set_attribute("db.operation", "SELECT")
                db_span.set_attribute("db.table", "rankings")
                time.sleep(random.uniform(0.02, 0.08))

            sorted_rankings = sorted(rankings.items(), key=lambda x: x[1], reverse=True)[:10]
            span.set_attribute("rankings.count", len(sorted_rankings))

    duration_ms = (time.monotonic() - start) * 1000
    request_duration.record(duration_ms, {"endpoint": "/rankings"})

    return {
        "rankings": [
            {"rank": i + 1, "player": p, "score": s}
            for i, (p, s) in enumerate(sorted_rankings)
        ]
    }


@app.post("/score", status_code=201)
def submit_score(req: ScoreRequest):
    """
    Submete ou atualiza a pontuação de um jogador.
    Mantém apenas a pontuação máxima por jogador.

    Pyroscope: tag_wrapper com endpoint="/score" isola o perfil
    deste handler para análise separada.

    Trace: span 'submit-score' com spans filhos 'validate-input' e 'db-write'.
    """
    start = time.monotonic()

    with pyroscope.tag_wrapper({"endpoint": "/score"}):
        with tracer.start_as_current_span("submit-score") as span:
            span.set_attribute("player.name", req.player)
            span.set_attribute("score.value", req.score)

            with tracer.start_as_current_span("validate-input") as val_span:
                time.sleep(random.uniform(0.003, 0.010))
                if req.score < 0:
                    val_span.set_attribute("validation.error", "negative_score")
                    api_errors.add(1, {"endpoint": "submit_score", "reason": "negative_score"})
                    security_events.add(1, {"event_type": "input_validation_failure", "endpoint": "submit_score"})
                    span.set_status(trace.StatusCode.ERROR, "Score negativo não permitido")
                    logger.error(
                        "Score inválido recebido",
                        extra={"player": req.player, "score": req.score},
                    )
                    raise HTTPException(status_code=400, detail="Score não pode ser negativo")

                if len(req.player) > 32:
                    val_span.set_attribute("validation.error", "player_name_too_long")
                    api_errors.add(1, {"endpoint": "submit_score", "reason": "name_too_long"})
                    security_events.add(1, {"event_type": "input_validation_failure", "endpoint": "submit_score"})
                    span.set_status(trace.StatusCode.ERROR, "Nome muito longo")
                    raise HTTPException(status_code=400, detail="Nome do jogador: máximo 32 caracteres")

                if req.score > 999_999:
                    val_span.set_attribute("security.warning", "suspicious_score_value")
                    span.set_attribute("security.flagged", True)
                    security_events.add(1, {"event_type": "suspicious_score_value", "endpoint": "submit_score"})
                    logger.warning(
                        "Score suspeito — possível fuzzing ou overflow",
                        extra={"player": req.player, "score": req.score},
                    )

                if _INJECTION_CHARS.search(req.player):
                    val_span.set_attribute("security.warning", "potential_injection_chars")
                    span.set_attribute("security.flagged", True)
                    security_events.add(1, {"event_type": "potential_injection", "endpoint": "submit_score"})
                    logger.warning(
                        "Possível injeção no nome do jogador",
                        extra={"player": req.player[:50]},
                    )

            with tracer.start_as_current_span("db-write") as db_span:
                db_span.set_attribute("db.system", "postgresql")
                db_span.set_attribute("db.operation", "upsert")
                db_span.set_attribute("db.table", "rankings")
                time.sleep(random.uniform(0.010, 0.040))

                previous = rankings.get(req.player, 0)
                rankings[req.player] = max(previous, req.score)
                is_new_record = req.score > previous
                db_span.set_attribute("score.is_new_record", is_new_record)

            scores_submitted.add(1, {"player": req.player})
            logger.info(
                "Score submetido",
                extra={"player": req.player, "score": req.score, "new_record": is_new_record},
            )

    duration_ms = (time.monotonic() - start) * 1000
    request_duration.record(duration_ms, {"endpoint": "/score"})

    return {
        "player": req.player,
        "score": rankings[req.player],
        "new_record": is_new_record,
    }


@app.get("/score/{player}")
def get_player_score(player: str):
    """
    Retorna a pontuação de um jogador específico.

    Trace: span 'get-player-score' com atributos do jogador.
    """
    start = time.monotonic()

    with pyroscope.tag_wrapper({"endpoint": "/score/{player}"}):
        with tracer.start_as_current_span("get-player-score") as span:
            span.set_attribute("player.name", player)

            with tracer.start_as_current_span("db-read") as db_span:
                db_span.set_attribute("db.system", "postgresql")
                db_span.set_attribute("db.operation", "SELECT")
                db_span.set_attribute("db.statement", f"SELECT score FROM rankings WHERE player = ?")
                time.sleep(random.uniform(0.005, 0.015))

            if player not in rankings:
                api_errors.add(1, {"endpoint": "get_player_score", "reason": "not_found"})
                security_events.add(1, {"event_type": "player_enumeration", "endpoint": "get_player_score"})
                span.set_status(trace.StatusCode.ERROR, "Jogador não encontrado")
                logger.warning(
                    "Jogador não encontrado",
                    extra={"player": player},
                )
                raise HTTPException(status_code=404, detail=f"Jogador '{player}' não encontrado")

    duration_ms = (time.monotonic() - start) * 1000
    request_duration.record(duration_ms, {"endpoint": "/score/{player}"})

    return {"player": player, "score": rankings[player]}
