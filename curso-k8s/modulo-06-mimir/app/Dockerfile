# ============================================================
# Dockerfile — Ranking API v2 (com Pyroscope SDK)
# ============================================================
# Build:
#   docker build -t ranking-api:v2-profiler .
#
# Carregar no Kind:
#   kind load docker-image ranking-api:v2-profiler --name k8s-essentials
#
# Diferença em relação ao Módulo 04:
#   - pyroscope-io requer compilação de extensão C (py-spy)
#   - Adicionadas dependências de build: gcc, python3-dev
#   - Removidas após o build para manter a imagem enxuta
# ============================================================

FROM python:3.12-slim

LABEL maintainer="curso-k8s"
LABEL description="Ranking API v2 — FastAPI com OpenTelemetry + Grafana Pyroscope"

WORKDIR /app

# Dependências de build necessárias para compilar o py-spy (C extension do pyroscope-io)
# Removidas após o pip install para reduzir o tamanho da imagem final
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Remover dependências de build após a instalação do pyroscope-io
RUN apt-get purge -y gcc python3-dev && apt-get autoremove -y

COPY main.py .

EXPOSE 8000

RUN adduser --disabled-password --gecos "" appuser
USER appuser

ENV OTEL_SERVICE_NAME=ranking-api
ENV OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector.otel.svc.cluster.local:4317
ENV DEPLOYMENT_ENV=kind-dev
ENV PYROSCOPE_SERVER_ADDRESS=http://pyroscope.monitoring.svc.cluster.local:4040
ENV PYROSCOPE_APPLICATION_NAME=ranking-api
ENV PYROSCOPE_TAGS=environment=kind-dev,version=2.0.0

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
