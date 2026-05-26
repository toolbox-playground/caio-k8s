import os
import re
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
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.exporter.otlp.proto.grpc._log_exporter import OTLPLogExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

# ── Resource: identidade permanente deste serviço ────────────
#
# O Resource é um conjunto de metadados que "viaja" junto em TODOS os dados
# emitidos por esta instância: spans, métricas e logs carregam esses campos.
#
# O que cada campo vira em cada backend:
#
#   "service.name" = "ranking-api"
#     → TEMPO:      atributo resource.service.name (filtrado via TraceQL)
#                   ex: { resource.service.name = "ranking-api" }
#     → PROMETHEUS: label service_name="ranking-api" em todas as métricas
#                   (convertido pelo OTel Collector via resource_to_telemetry_conversion)
#     → LOKI:       label de stream service_name="ranking-api" no índice
#                   (promovido via loki.resource.labels no Collector)
#
#   "deployment.environment" = "kind-dev"
#     → TEMPO:      resource.deployment.environment
#     → PROMETHEUS: label deployment_environment="kind-dev"
#     → LOKI:       label de stream deployment_environment="kind-dev"
#
# Os valores vêm das env vars definidas em 01-deployment-ranking-api.yaml.
# O OTel Collector não altera esses valores — apenas os repassa para cada backend.
resource = Resource.create({
    SERVICE_NAME: os.getenv("OTEL_SERVICE_NAME", "ranking-api"),
    "service.version": "1.0.0",
    "deployment.environment": os.getenv("DEPLOYMENT_ENV", "kind-dev"),
})

OTEL_ENDPOINT = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector.otel.svc.cluster.local:4317")

# ── Traces ───────────────────────────────────────────────────
#
# TracerProvider: gerencia o ciclo de vida de todos os spans.
# BatchSpanProcessor: acumula spans em memória e envia em lotes para o Collector.
#   - Assíncrono: não bloqueia a thread que está servindo a requisição.
#   - Alternativa SimpleSpanProcessor envia um a um e bloqueia — não usar em produção.
#
# Destino: OTel Collector porta 4317 → Tempo (via OTLP interno)
# Onde ver: Grafana → Explore → Datasource: Tempo → TraceQL
tracer_provider = TracerProvider(resource=resource)
tracer_provider.add_span_processor(
    BatchSpanProcessor(OTLPSpanExporter(endpoint=OTEL_ENDPOINT, insecure=True))
)
trace.set_tracer_provider(tracer_provider)
tracer = trace.get_tracer(__name__)

# ── Métricas ─────────────────────────────────────────────────
#
# PeriodicExportingMetricReader: envia métricas ao Collector a cada 5s via OTLP.
# O Collector converte para formato Prometheus e expõe em :8889/metrics.
# O Prometheus faz scrape periódico nesse endpoint (via PodMonitor).
#
# Destino: OTel Collector porta 4317 → Prometheus scrape :8889
# Onde ver: http://localhost:9090 | Grafana → Datasource: Prometheus
metric_reader = PeriodicExportingMetricReader(
    OTLPMetricExporter(endpoint=OTEL_ENDPOINT, insecure=True),
    export_interval_millis=5000,
)
meter_provider = MeterProvider(resource=resource, metric_readers=[metric_reader])
metrics.set_meter_provider(meter_provider)
meter = metrics.get_meter(__name__)

# Métricas customizadas — visíveis no Prometheus via OTel Collector
#
# Counter: acumula e nunca decresce.
# O exporter Prometheus adiciona sufixo `_total` automaticamente.
# Nome no Prometheus: scores_submitted_total
# Labels disponíveis: service_name, deployment_environment (do Resource) + player (do .add())
# Query útil: rate(scores_submitted_total[5m])
scores_submitted = meter.create_counter(
    "scores_submitted_total",
    description="Total de pontuações submetidas",
)

# Counter de erros.
# O dict passado ao .add() vira labels adicionais no Prometheus.
# Nome no Prometheus: api_errors_total{endpoint="submit_score", reason="negative_score"}
# Query útil: rate(api_errors_total{reason="negative_score"}[5m])
api_errors = meter.create_counter(
    "api_errors_total",
    description="Total de erros da API por endpoint e motivo",
)

# Counter de segurança — separado do api_errors para alertas e dashboards dedicados.
# Classifica ocorrências pelo campo event_type, mapeado ao OWASP Top 10:
#
#   input_validation_failure  → A03 Injection / A04 Insecure Design
#     └─ score negativo ou nome de jogador acima do limite
#   suspicious_score_value    → A04 Insecure Design
#     └─ score > 999.999: possível fuzzing de limites numéricos (overflow/wraparound)
#   potential_injection       → A03 Injection
#     └─ caracteres típicos de SQL/XSS/path injection no nome do jogador
#   player_enumeration        → A01 Broken Access Control
#     └─ consultas repetidas a players inexistentes = bruteforce de IDs
#
# Nome no Prometheus: security_events_total{event_type="...", endpoint="..."}
# Query de alerta:    sum(rate(security_events_total[5m])) by (event_type) > 0.1
# Dashboard:          grafana-dashboards/devsecops.json
security_events = meter.create_counter(
    "security_events_total",
    description="Eventos de segurança classificados por tipo — mapeados para OWASP Top 10",
)

# Padrão de detecção básica de injeção — compilado uma vez no startup.
# Detecta: aspas simples/duplas, ponto-e-vírgula, barra invertida, < > % $ & | crase
# NÃO substitui validação server-side — serve para sinalizar e auditar tentativas.
_INJECTION_CHARS = re.compile(r"['\";<>\\%$&|`]")

# Histogram: captura distribuição de valores (p50, p95, p99).
# No Prometheus gera 3 séries: _bucket (distribuição), _count (total), _sum (soma)
# Nome no Prometheus: request_duration_ms_bucket{le="...", endpoint="/score"}
# Query p99: histogram_quantile(0.99, rate(request_duration_ms_bucket[5m]))
request_duration = meter.create_histogram(
    "request_duration_ms",
    description="Duração das requisições em milissegundos",
    unit="ms",
)

# ── Logs ─────────────────────────────────────────────────────
#
# LoggerProvider + BatchLogRecordProcessor: envia logs ao Collector via OTLP em lotes.
#
# LoggingHandler: conecta o sistema de logging PADRÃO do Python ao pipeline OTel.
#   Sem este handler os logs vão apenas para o stdout do pod — não chegam ao Loki.
#   Com ele, todo logger.info/warning/error é capturado e enviado via OTLP.
#
# O nível do log vira o label `level` no Loki (stream label = indexado):
#   logger.info(...)    → level="INFO"
#   logger.warning(...) → level="WARN"
#   logger.error(...)   → level="ERROR"
#
# O body do log (message + extra) é armazenado como JSON no corpo do registro.
# O traceID ativo no momento é injetado automaticamente no body pelo SDK OTel.
#
# Destino: OTel Collector porta 4317 → Loki :3100/loki/api/v1/push
# Onde ver: Grafana → Explore → Datasource: Loki
#   {service_name="ranking-api"}              → todos os logs
#   {service_name="ranking-api", level="ERROR"} → apenas erros
logger_provider = LoggerProvider(resource=resource)
logger_provider.add_log_record_processor(
    BatchLogRecordProcessor(OTLPLogExporter(endpoint=OTEL_ENDPOINT, insecure=True))
)
otel_handler = LoggingHandler(level=logging.DEBUG, logger_provider=logger_provider)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("ranking-api")
logger.addHandler(otel_handler)   # <── ponto de integração: Python logging → OTel → Loki

# ============================================================
# FastAPI App
# ============================================================

app = FastAPI(
    title="Ranking API",
    description="Leaderboard para jogadores — instrumentado com OpenTelemetry",
    version="1.0.0",
)

# Instrumentação automática do FastAPI: injeta um span por requisição HTTP
# sem precisar alterar o código de cada endpoint individualmente.
#
# Atributos adicionados automaticamente em cada span raiz:
#   http.method      → "GET", "POST"
#   http.target      → "/score", "/rankings", "/score/mario"
#   http.status_code → 200, 400, 404, 500
#   http.route       → "/score/{player}"   (template, não o valor real)
#
# Este span é o "pai" no waterfall do Tempo — todos os spans criados com
# tracer.start_as_current_span() dentro de um endpoint aparecem como filhos dele.
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
        # Atributos enriquecem o span no Tempo: visíveis ao clicar no span no waterfall.
        # Filtráveis via TraceQL: { span.player.name = "mario" } ou { span.score.value > 9000 }
        span.set_attribute("player.name", req.player)
        span.set_attribute("score.value", req.score)

        # Span filho: validação
        with tracer.start_as_current_span("validate-input") as val_span:
            time.sleep(random.uniform(0.003, 0.010))
            if req.score < 0:
                # Atributo de diagnóstico — aparece no painel lateral do span no Tempo
                val_span.set_attribute("validation.error", "negative_score")

                # Incrementa o contador de erros no Prometheus.
                # O dict {"endpoint": ..., "reason": ...} vira labels adicionais.
                # Prometheus: api_errors_total{endpoint="submit_score", reason="negative_score"}
                # Query: rate(api_errors_total{reason="negative_score"}[5m])
                api_errors.add(1, {"endpoint": "submit_score", "reason": "negative_score"})
                # Evento de segurança — OWASP A03/A04: falha de validação de input
                # Prometheus: security_events_total{event_type="input_validation_failure", endpoint="submit_score"}
                security_events.add(1, {"event_type": "input_validation_failure", "endpoint": "submit_score"})

                # Marca o span como ERROR → aparece VERMELHO no waterfall do Tempo.
                # Filtrado por: { status = error } no TraceQL
                span.set_status(trace.StatusCode.ERROR, "Score negativo não permitido")

                # Envia log de erro para o Loki via OTel.
                # No Loki aparece com: level="ERROR", service_name="ranking-api"
                # Query Loki: {service_name="ranking-api", level="ERROR"}
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

            # ── Detecções de segurança ──────────────────────────────────
            # OWASP A04: score > 999.999 — possível fuzzing de limites numéricos
            if req.score > 999_999:
                val_span.set_attribute("security.warning", "suspicious_score_value")
                span.set_attribute("security.flagged", True)
                security_events.add(1, {"event_type": "suspicious_score_value", "endpoint": "submit_score"})
                logger.warning(
                    "Score suspeito — possível fuzzing ou overflow",
                    extra={"player": req.player, "score": req.score},
                )

            # OWASP A03: caracteres típicos de SQL/XSS/path injection no nome do jogador
            # A request não é bloqueada — apenas sinalizada para auditoria.
            if _INJECTION_CHARS.search(req.player):
                val_span.set_attribute("security.warning", "potential_injection_chars")
                span.set_attribute("security.flagged", True)
                security_events.add(1, {"event_type": "potential_injection", "endpoint": "submit_score"})
                logger.warning(
                    "Possível injeção no nome do jogador",
                    extra={"player": req.player[:50]},
                )

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

        # Incrementa o contador de scores bem-sucedidos.
        # O label "player" aparece como dimensão no Prometheus.
        # Prometheus: scores_submitted_total{service_name="ranking-api", player="mario"}
        # Query: rate(scores_submitted_total[5m])
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
        # Atributo de contexto: visível no painel do span no Tempo.
        # Útil para saber qual jogador foi consultado sem precisar ler a URL.
        span.set_attribute("player.name", player)

        with tracer.start_as_current_span("db-read") as db_span:
            db_span.set_attribute("db.system", "postgresql")
            db_span.set_attribute("db.operation", "SELECT")
            # db.statement no Tempo mostra a query exata ao clicar no span "db-read"
            db_span.set_attribute("db.statement", f"SELECT score FROM rankings WHERE player = '{player}'")
            time.sleep(random.uniform(0.005, 0.015))

        if player not in rankings:
            # Prometheus: api_errors_total{endpoint="get_player_score", reason="not_found"}
            api_errors.add(1, {"endpoint": "get_player_score", "reason": "not_found"})
            # OWASP A01: consultas repetidas a players inexistentes = enumeração de IDs
            # Um pico nesta métrica indica possível bruteforce de nomes de jogadores.
            # Prometheus: security_events_total{event_type="player_enumeration", endpoint="get_player_score"}
            security_events.add(1, {"event_type": "player_enumeration", "endpoint": "get_player_score"})

            # Marca o span como ERROR → aparece vermelho no Tempo; { status = error } no TraceQL
            span.set_status(trace.StatusCode.ERROR, "Player not found")

            # error.type é uma convenção OTel para classificar o tipo de falha.
            # Aparece no painel lateral do span; filtrável: { span.error.type = "PlayerNotFoundError" }
            span.set_attribute("error.type", "PlayerNotFoundError")

            # Nível WARNING → label level="WARN" no Loki
            # Query Loki: {service_name="ranking-api", level="WARN"}
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
