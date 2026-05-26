# ============================================================
# Dockerfile — Ranking API
# ============================================================
# Build:
#   docker build -t ranking-api:latest .
#
# Carregar no Kind:
#   kind load docker-image ranking-api:latest --name k8s-essentials
# ============================================================

FROM python:3.12-slim

# Metadados da imagem
LABEL maintainer="curso-k8s"
LABEL description="Ranking API — FastAPI instrumentada com OpenTelemetry"

WORKDIR /app

# Copiar e instalar dependências antes do código
# (camada de cache separada — rebuild só quando requirements mudar)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiar código da aplicação
COPY main.py .

# Porta que o uvicorn escuta
EXPOSE 8000

# Usuário não-root (boa prática de segurança)
RUN adduser --disabled-password --gecos "" appuser
USER appuser

# Variáveis de ambiente padrão (sobrescritas pelo K8s via env:)
ENV OTEL_SERVICE_NAME=ranking-api
ENV OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector.otel.svc.cluster.local:4317
ENV DEPLOYMENT_ENV=kind-dev

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
