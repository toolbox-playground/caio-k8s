# manifests/

Manifestos Kubernetes para o Módulo 06 — Grafana Mimir.

| Arquivo | O que faz |
|---|---|
| `01-mimir-config.yaml` | ConfigMap com `mimir.yaml` — configuração completa do Mimir (S3, limites, ingester, compactor) |
| `02-mimir-deployment.yaml` | StatefulSet + Services (ClusterIP, Headless, NodePort) para o Mimir |
| `03-grafana-datasource-mimir.yaml` | ConfigMap com provisioning do datasource Mimir no Grafana |

## Ordem de aplicação

```bash
# 1. ConfigMap de configuração (deve existir antes do pod subir)
kubectl apply -f 01-mimir-config.yaml

# 2. StatefulSet + Services
kubectl apply -f 02-mimir-deployment.yaml

# 3. Datasource no Grafana (pode aplicar a qualquer momento)
kubectl apply -f 03-grafana-datasource-mimir.yaml
```

## Dependências

O Mimir precisa que o **MinIO esteja running** antes de iniciar. O `initContainer` do StatefulSet aguarda automaticamente o MinIO ficar healthy. Instale o MinIO antes de aplicar estes manifests:

```bash
helm upgrade --install minio bitnami/minio \
  --namespace monitoring \
  -f ../helm-values/values-minio.yaml
```

## Portas expostas

| Serviço | Porta interna | Porta externa (Kind) |
|---|---|---|
| `mimir.monitoring.svc` | 9009 | — |
| `mimir-nodeport` | 9009 | **localhost:9009** (extraPortMapping 39009) |

## Verificação rápida

```bash
# Status do pod
kubectl get pods -n monitoring -l app=mimir

# Health check
curl http://localhost:9009/ready
# Esperado: "ready"

# Métricas ingeridas (via PromQL)
curl 'http://localhost:9009/prometheus/api/v1/query?query=up'
```
