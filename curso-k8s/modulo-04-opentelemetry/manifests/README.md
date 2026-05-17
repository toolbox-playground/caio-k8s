# 📂 Manifestos — Módulo 04: OpenTelemetry

## Estrutura

```
manifests/
├── cluster-config.yaml          ← Kind com port mappings de todos os módulos
├── app/
│   ├── main.py                  ← FastAPI instrumentada com OTel SDK
│   ├── requirements.txt         ← Dependências Python
│   └── Dockerfile               ← Build da imagem
└── k8s/
    ├── 01-deployment-ranking-api.yaml  ← Deployment da Ranking API
    ├── 02-service-ranking-api.yaml     ← Service (ClusterIP)
    └── 03-otel-collector.yaml          ← Namespace + ConfigMap + Deployment + Service
```

---

## Ordem de aplicação

```sh
# 1. Infraestrutura (já instalada no Módulo 03)
#    Prometheus, Grafana, Loki, Fluent Bit

# 2. Grafana Tempo (novo neste módulo)
helm install tempo grafana/tempo --namespace monitoring ...

# 3. OTel Collector
kubectl apply -f k8s/03-otel-collector.yaml

# 4. Build e load da imagem
docker build -t ranking-api:latest app/
kind load docker-image ranking-api:latest --name k8s-essentials

# 5. Ranking API
kubectl apply -f k8s/01-deployment-ranking-api.yaml
kubectl apply -f k8s/02-service-ranking-api.yaml
```

---

## Fluxo de dados

```
Ranking API (OTel SDK)
    │
    │  OTLP/gRPC → otel-collector.otel.svc.cluster.local:4317
    ▼
OTel Collector (namespace: otel)
    ├── traces  → tempo.monitoring.svc.cluster.local:4317
    ├── metrics → expõe :8889/metrics  ← Prometheus faz scrape
    └── logs    → loki.monitoring.svc.cluster.local:3100
```

---

## Endereços internos (DNS do cluster)

| Serviço | DNS interno | Porta |
|---|---|---|
| OTel Collector (gRPC) | `otel-collector.otel.svc.cluster.local` | 4317 |
| OTel Collector (HTTP) | `otel-collector.otel.svc.cluster.local` | 4318 |
| Tempo | `tempo.monitoring.svc.cluster.local` | 4317 (OTLP), 3100 (HTTP) |
| Loki | `loki.monitoring.svc.cluster.local` | 3100 |
| Prometheus | `kind-prometheus-kube-prome-prometheus.monitoring.svc.cluster.local` | 9090 |
