"""webapp — API de referência do Módulo 11 (GitOps de produção).

Mostra na prática o que o pipeline entrega:
  /version  → qual imagem/ambiente está rodando (prova visual do deploy)
  /secret   → impressão digital do segredo injetado pelo ESO (nunca o valor)
  /work     → latência aleatória, gera traces e métricas interessantes
  /metrics  → Prometheus (scrape via ServiceMonitor)
  /healthz  → liveness    /readyz → readiness
"""
import hashlib
import os
import random
import time

from fastapi import FastAPI, Request, Response
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Gauge, Histogram, generate_latest

APP_VERSION = os.getenv("APP_VERSION", "dev")
ENVIRONMENT = os.getenv("DEPLOYMENT_ENV", "local")
POD_NAME = os.getenv("POD_NAME", "local")

app = FastAPI(title="webapp", version=APP_VERSION)

# ── Métricas ────────────────────────────────────────────────
# Labels de BAIXA cardinalidade (rota template, não o path bruto) — lição do módulo 09.
REQUESTS = Counter("webapp_http_requests_total", "Requisições HTTP", ["method", "route", "status"])
LATENCY = Histogram(
    "webapp_http_request_duration_seconds",
    "Latência HTTP",
    ["route"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5),
)
BUILD_INFO = Gauge("webapp_build_info", "Versão em execução (valor sempre 1; use os labels)", ["version", "environment"])
BUILD_INFO.labels(APP_VERSION, ENVIRONMENT).set(1)


@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    start = time.perf_counter()
    response = await call_next(request)
    route = request.scope.get("route")
    route_path = route.path if route else "unmatched"
    if route_path != "/metrics":
        LATENCY.labels(route_path).observe(time.perf_counter() - start)
        REQUESTS.labels(request.method, route_path, str(response.status_code)).inc()
    return response


# ── Traces (só se houver collector configurado) ─────────────
if os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT"):
    from opentelemetry import trace
    from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
    from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
    from opentelemetry.sdk.resources import Resource
    from opentelemetry.sdk.trace import TracerProvider
    from opentelemetry.sdk.trace.export import BatchSpanProcessor
    from opentelemetry.sdk.trace.sampling import ParentBasedTraceIdRatio

    ratio = float(os.getenv("OTEL_TRACES_SAMPLER_ARG", "1.0"))
    provider = TracerProvider(
        # Resource.create() já lê OTEL_SERVICE_NAME e OTEL_RESOURCE_ATTRIBUTES
        resource=Resource.create({"service.instance.id": POD_NAME}),
        sampler=ParentBasedTraceIdRatio(ratio),
    )
    provider.add_span_processor(
        BatchSpanProcessor(OTLPSpanExporter(endpoint=os.environ["OTEL_EXPORTER_OTLP_ENDPOINT"], insecure=True))
    )
    trace.set_tracer_provider(provider)
    FastAPIInstrumentor.instrument_app(app, excluded_urls="healthz,readyz,metrics")


# ── Endpoints ───────────────────────────────────────────────
@app.get("/")
def root():
    return {"service": "webapp", "docs": "/docs", "try": ["/version", "/secret", "/work"]}


@app.get("/version")
def version():
    return {"version": APP_VERSION, "environment": ENVIRONMENT, "pod": POD_NAME}


@app.get("/secret")
def secret():
    """Prova que o ESO entregou o segredo, sem vazá-lo: devolve só um hash curto."""
    value = os.getenv("API_KEY")
    if not value:
        return {"api_key_loaded": False}
    return {"api_key_loaded": True, "fingerprint": hashlib.sha256(value.encode()).hexdigest()[:8]}


@app.get("/work")
def work(ms: int = 0):
    """Simula trabalho. ?ms=200 fixa a latência; sem parâmetro é aleatória (10–150ms)."""
    delay = (ms if ms > 0 else random.randint(10, 150)) / 1000
    time.sleep(min(delay, 2.5))
    return {"slept_ms": int(delay * 1000)}


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


@app.get("/readyz")
def readyz():
    return {"status": "ready"}


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
