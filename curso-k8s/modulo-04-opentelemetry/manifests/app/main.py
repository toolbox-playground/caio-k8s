import os
import time
import random
import logging

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

# ============================================================
# OpenTelemetry — Setup
# ============================================================
# As variáveis de ambiente abaixo controlam a configuração:
#   OTEL_SERVICE_NAME              → nome do serviço no Tempo/Grafana
#   OTEL_EXPORTER_OTLP_ENDPOINT   → endereço do OTel Collector
#   OTEL_RESOURCE_ATTRIBUTES       → atributos extras (ambiente, versão)
# ============================================================

from opentelemetry import trace, metrics
from opentelemetry.sdk.resources import Resource, SERVICE_NAME
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk.logs.export import BatchLogRecordProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.exporter.otlp.proto.grpc._log_exporter import OTLPLogExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

# ── Resource: identifica este serviço em todos os backends ──
resource = Resource.create({
    SERVICE_NAME: os.getenv("OTEL_SERVICE_NAME", "ranking-api"),
    "service.version": "1.0.0",
    "deployment.environment": os.getenv("DEPLOYMENT_ENV", "kind-dev"),
})

OTEL_ENDPOINT = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector.otel.svc.cluster.local:4317")

# ── Traces ───────────────────────────────────────────────────
tracer_provider = TracerProvider(resource=resource)
tracer_provider.add_span_processor(
    BatchSpanProcessor(OTLPSpanExporter(endpoint=OTEL_ENDPOINT, insecure=True))
)
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

# Métricas customizadas — visíveis no Prometheus via OTel Collector
scores_submitted = meter.create_counter(
    "scores_submitted_total",
    description="Total de pontuações submetidas",
)
api_errors = meter.create_counter(
    "api_errors_total",
    description="Total de erros da API por endpoint e motivo",
)
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
    description="Leaderboard para jogadores — instrumentado com OpenTelemetry",
    version="1.0.0",
)

# Instrumentação automática: injeta spans em cada requisição HTTP
FastAPIInstrumentor.instrument_app(app)

# ── Store em memória (sem dependência de banco externo) ──────
rankings: dict[str, int] = {
    "mario":  9999,
    "luigi":  8500,
    "yoshi":  7200,
    "peach":  6800,
    "bowser": 5100,
}


# ── Models ───────────────────────────────────────────────────

class ScoreRequest(BaseModel):
    player: str
    score: int


# ============================================================
# Endpoints
# ============================================================

@app.get("/health")
def health():
    """Health check — usado pelo readinessProbe e livenessProbe."""
    return {"status": "ok", "service": "ranking-api"}


@app.get("/rankings")
def get_rankings():
    """
    Retorna o top 10 jogadores ordenados por pontuação.

    Trace: cria span 'get-rankings' com span filho 'db-read'
    que simula latência de consulta ao banco de dados.
    """
    start = time.monotonic()

    with tracer.start_as_current_span("get-rankings") as span:
        logger.info("Consultando rankings", extra={"endpoint": "/rankings"})

        # Span filho: simula consulta ao banco
        with tracer.start_as_current_span("db-read") as db_span:
            db_span.set_attribute("db.system", "postgresql")
            db_span.set_attribute("db.operation", "SELECT")
            db_span.set_attribute("db.table", "rankings")
            time.sleep(random.uniform(0.02, 0.08))  # simula latência de I/O

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

    Trace: cria span 'submit-score' com spans filhos
    'validate-input' e 'db-write'.
    """
    start = time.monotonic()

    with tracer.start_as_current_span("submit-score") as span:
        span.set_attribute("player.name", req.player)
        span.set_attribute("score.value", req.score)

        # Span filho: validação
        with tracer.start_as_current_span("validate-input") as val_span:
            time.sleep(random.uniform(0.003, 0.010))
            if req.score < 0:
                val_span.set_attribute("validation.error", "negative_score")
                api_errors.add(1, {"endpoint": "submit_score", "reason": "negative_score"})
                span.set_status(trace.StatusCode.ERROR, "Score negativo não permitido")
                logger.error(
                    "Score inválido recebido",
                    extra={"player": req.player, "score": req.score},
                )
                raise HTTPException(status_code=400, detail="Score não pode ser negativo")

            if len(req.player) > 32:
                val_span.set_attribute("validation.error", "player_name_too_long")
                api_errors.add(1, {"endpoint": "submit_score", "reason": "name_too_long"})
                span.set_status(trace.StatusCode.ERROR, "Nome muito longo")
                raise HTTPException(status_code=400, detail="Nome do jogador: máximo 32 caracteres")

        # Span filho: persistência
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
    Se não encontrado, o span recebe status ERROR.
    """
    start = time.monotonic()

    with tracer.start_as_current_span("get-player-score") as span:
        span.set_attribute("player.name", player)

        with tracer.start_as_current_span("db-read") as db_span:
            db_span.set_attribute("db.system", "postgresql")
            db_span.set_attribute("db.operation", "SELECT")
            db_span.set_attribute("db.statement", f"SELECT score FROM rankings WHERE player = '{player}'")
            time.sleep(random.uniform(0.005, 0.015))

        if player not in rankings:
            api_errors.add(1, {"endpoint": "get_player_score", "reason": "not_found"})
            span.set_status(trace.StatusCode.ERROR, "Player not found")
            span.set_attribute("error.type", "PlayerNotFoundError")
            logger.warning("Jogador não encontrado", extra={"player": player})
            raise HTTPException(status_code=404, detail=f"Jogador '{player}' não encontrado")

        rank = sorted(rankings.values(), reverse=True).index(rankings[player]) + 1
        span.set_attribute("player.rank", rank)

    duration_ms = (time.monotonic() - start) * 1000
    request_duration.record(duration_ms, {"endpoint": f"/score/{{player}}"})

    return {"player": player, "score": rankings[player], "rank": rank}


@app.get("/slow")
def slow_endpoint():
    """
    Endpoint intencionalmente lento para demonstrar traces com alta duração.

    Útil para filtrar no Tempo com: { duration > 200ms }
    e observar o waterfall de spans internos.
    """
    start = time.monotonic()

    with tracer.start_as_current_span("slow-operation") as span:
        logger.info("Iniciando operação lenta simulada")

        # Simula múltiplas operações lentas encadeadas
        with tracer.start_as_current_span("cache-miss"):
            time.sleep(random.uniform(0.05, 0.10))  # cache miss

        with tracer.start_as_current_span("db-read-primary"):
            time.sleep(random.uniform(0.08, 0.15))  # leitura no primário

        with tracer.start_as_current_span("db-read-replica"):
            time.sleep(random.uniform(0.06, 0.12))  # leitura na réplica

        with tracer.start_as_current_span("serialize-response"):
            time.sleep(random.uniform(0.01, 0.03))  # serialização

        total_ms = (time.monotonic() - start) * 1000
        span.set_attribute("operation.duration_ms", round(total_ms, 2))
        logger.info("Operação lenta concluída", extra={"duration_ms": round(total_ms, 2)})

    request_duration.record(total_ms, {"endpoint": "/slow"})

    return {"message": "operação concluída", "duration_ms": round(total_ms, 2)}
