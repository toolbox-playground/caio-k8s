import os
import re
import time
import random
import logging

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

# ============================================================
# Pyroscope — Continuous Profiling
# ============================================================
# O SDK pyroscope-io amostra o call stack Python a cada ~10ms
# e envia os dados comprimidos para o Pyroscope Server a cada 15s.
#
# Overhead típico: <1% de CPU, <5MB de memória extra.
#
# PYROSCOPE_SERVER_ADDRESS  → URL do Pyroscope Server no cluster
# PYROSCOPE_APPLICATION_NAME → aparece como "service_name" no Grafana
# PYROSCOPE_TAGS            → labels para filtrar no Grafana (env, versão)
#
# O application_name DEVE ser igual ao OTEL_SERVICE_NAME para que
# a correlação Trace → Profile funcione no Grafana Tempo.
# ============================================================
import pyroscope
from pyroscope.otel import PyroscopeSpanProcessor

pyroscope.configure(
    # Nome do serviço — chave de correlação com o Tempo (traces)
    application_name=os.getenv("PYROSCOPE_APPLICATION_NAME", "ranking-api"),

    # Endereço do Pyroscope Server dentro do cluster Kubernetes.
    # Formato: http://<service>.<namespace>.svc.cluster.local:<porta>
    server_address=os.getenv("PYROSCOPE_SERVER_ADDRESS", "http://pyroscope.monitoring.svc.cluster.local:4040"),

    # Tags fixas que viajam em todos os profiles deste processo.
    # Visíveis como labels no Grafana Pyroscope para filtrar e comparar.
    # Ex: comparar v1.0.0 vs v2.0.0 no diff flame graph.
    #
    # ATENÇÃO: o SDK Python NÃO lê a env var PYROSCOPE_TAGS automaticamente.
    # As tags precisam ser passadas explicitamente aqui.
    tags={
        "environment": os.getenv("DEPLOYMENT_ENV", "kind-dev"),
        "version":     "2.0.0",
        "profiler":    "sdk",   # diferencia do eBPF (Alloy) no Grafana
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
tracer_provider.add_span_processor(
    BatchSpanProcessor(OTLPSpanExporter(endpoint=OTEL_ENDPOINT, insecure=True))
)
# ── Span Profiles bridge (Pyroscope ↔ Tempo) ─────────────────
# Injeta o atributo pyroscope.profile.id em cada span.
# Com isso, o Grafana Tempo exibe "Profiles for this span" + flame graph inline.
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
