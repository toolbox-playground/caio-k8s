# Manifests — Módulo 08

| Arquivo | O que faz |
|---|---|
| `01-bad-metrics-app.yaml` | App que simula alta cardinalidade (request_id como label) |
| `02-service-monitor-fixed.yaml` | ServiceMonitor com `labeldrop` e `sampleLimit` |
| `03-cardinality-alerts.yaml` | PrometheusRule com alertas de crescimento de cardinalidade |
| `04-recording-rules.yaml` | Versões "slim" de métricas de infra (redução de cardinalidade) |
| `05-grafana-dashboard.yaml` | ConfigMap com dashboard de saúde do stack observability |
