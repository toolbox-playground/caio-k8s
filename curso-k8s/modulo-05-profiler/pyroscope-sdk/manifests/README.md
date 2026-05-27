# Manifests — Módulo 05

| Arquivo | Descrição |
|---|---|
| `cluster-config.yaml` | Kind cluster com porta `4040` exposta para o Grafana Pyroscope (além de todas as portas dos módulos anteriores) |
| `01-deployment-ranking-api-v2.yaml` | Deployment da `ranking-api` v2 com as variáveis `PYROSCOPE_SERVER_ADDRESS`, `PYROSCOPE_APPLICATION_NAME` e `PYROSCOPE_TAGS` configuradas |
| `02-stress-test-fortio.yaml` | Pod Fortio que gera carga no endpoint `/rankings` da `ranking-api` para popular os flame graphs |

## Ordem de aplicação

```sh
# 1. Criar o cluster (necessário para expor a porta 4040)
kind delete cluster --name k8s-essentials
kind create cluster --config cluster-config.yaml

# 2. Instalar Pyroscope (helm-values/values-pyroscope.yaml)
helm install pyroscope grafana/pyroscope --namespace monitoring -f ../helm-values/values-pyroscope.yaml

# 3. Deploy da ranking-api v2
kubectl apply -f 01-deployment-ranking-api-v2.yaml
```
