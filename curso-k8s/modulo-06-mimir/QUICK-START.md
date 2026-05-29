# Módulo 06 — Grafana Mimir: Quick Start

> **Contexto**: Você acabou de terminar o Módulo 05 (Profiler).
> Este guia tem dois caminhos:
> - **Cluster já rodando** (veio do módulo 05 sem destruir): pule para a [Fase 1](#fase-1--instalar-o-minio-object-storage).
> - **Cluster novo / recriado**: siga a Fase 0 completa.
>
> O Mimir resolve o problema clássico do Prometheus:
> *"Reiniciei o servidor e perdi todos os dados históricos."*

---

## Pré-requisito — Navegar até o diretório do módulo

Todos os caminhos relativos deste guia (`cluster-config.yaml`, `stack/`, `helm-values/`, `manifests/`) partem de `modulo-06-mimir`. Execute antes de qualquer comando:

```bash
# Linux / macOS
cd curso-k8s/modulo-06-mimir
```
```pwsh
# Windows (PowerShell)
Set-Location curso-k8s\modulo-06-mimir
```

> Se você já está dentro do workspace na raiz do repo:
> `c:\Users\marce\Documents\Toolbox\caio-k8s`

---

## Fase 0 — Cluster e Stack Base

> **Vindo do Módulo 05 com o cluster ainda rodando?**
> Se o cluster `k8s-essentials` já está up e a stack (Prometheus, Loki, Grafana,
> Mario, Pyroscope) já está instalada, **pule toda a Fase 0** e vá direto para
> a **[Fase 1 — MinIO](#fase-1--instalar-o-minio-object-storage)**.
> Só precisará atualizar o `values-prometheus-stack.yaml` para adicionar o `remoteWrite`.
>
> ⚠️ **Atenção**: o MinIO agora é instalado via manifest (não mais pelo chart bitnami).
> Não é necessário adicionar nenhum repo Helm extra — apenas aplique:
>
> ```bash
> kubectl apply -f manifests/00-minio.yaml
> ```

### 0.1 — Verificar ou recriar o cluster

> **Módulos 05 e 06 usam NodePorts acima de 32767** (34040, 39009, 39001).
> O Kubernetes restringe o range padrão a 30000-32767. O `cluster-config.yaml`
> deste módulo já inclui `service-node-port-range: 30000-40000` via `kubeadmConfigPatches`.
>
> Se você criou o cluster com uma config antiga (módulo 03/04/05) **sem** essa extensão,
> precisará recriar:
> ```bash
> kind delete cluster --name k8s-essentials
> kind create cluster --name k8s-essentials --config cluster-config.yaml
> ```
> Após recriar, reaplique todos os manifests das fases anteriores.

```bash
kind get clusters
# Esperado: k8s-essentials
```

Se o cluster não existir:

```bash
# Linux / macOS
kind create cluster \
  --name k8s-essentials \
  --config cluster-config.yaml
```
```pwsh
# Windows (PowerShell)
kind create cluster `
  --name k8s-essentials `
  --config cluster-config.yaml
```

```bash
kubectl config use-context kind-k8s-essentials
kubectl get nodes
# Esperado: control-plane + worker, ambos Ready
```



### 0.2 — Criar namespaces

```bash
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace games      --dry-run=client -o yaml | kubectl apply -f -
```

### 0.3 — Instalar Metrics Server (HPA)

O Metrics Server é necessário para o HPA funcionar (`kubectl top` e escalamento automático).

**PowerShell e bash:**
```sh
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.8.1/components.yaml
```

**PowerShell:**
```powershell
kubectl patch deployment metrics-server -n kube-system `
  --type=json `
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
```

**bash / zsh:**
```bash
kubectl patch deployment metrics-server -n kube-system \
  --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
```

### 0.4 — Instalar o Mario (app de carga)

```bash
kubectl apply -f stack/mario/
kubectl rollout status deployment/super-mario -n games
```

Acesse em: http://localhost:8081

### 0.5 — Adicionar repos Helm

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana              https://grafana.github.io/helm-charts
helm repo add fluent               https://fluent.github.io/helm-charts
helm repo add bitnami              https://charts.bitnami.com/bitnami
helm repo update
```

### 0.6 — Instalar kube-prometheus-stack

> **Atenção**: neste módulo, o `values-prometheus-stack.yaml` inclui o bloco
> `remoteWrite` que envia métricas ao Mimir. O Mimir precisa estar rodando
> antes para não gerar erros — mas é seguro instalar agora, pois o Prometheus
> fica em retry automático até o Mimir subir.

```bash
# Linux / macOS
helm upgrade --install kind-prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f stack/monitoring/helm-values/values-prometheus-stack.yaml \
  --wait --timeout 5m
```
```pwsh
# Windows (PowerShell)
helm upgrade --install kind-prometheus prometheus-community/kube-prometheus-stack `
  --namespace monitoring `
  -f stack/monitoring/helm-values/values-prometheus-stack.yaml `
  --wait --timeout 5m
```

### 0.7 — Instalar Loki + Fluent Bit

```bash
# Linux / macOS
helm upgrade --install loki grafana/loki \
  --namespace monitoring \
  -f stack/monitoring/helm-values/values-loki.yaml \
  --wait --timeout 3m

helm upgrade --install fluent-bit fluent/fluent-bit \
  --namespace monitoring \
  -f stack/monitoring/helm-values/values-fluent-bit.yaml \
  --wait --timeout 2m
```
```pwsh
# Windows (PowerShell)
helm upgrade --install loki grafana/loki `
  --namespace monitoring `
  -f stack/monitoring/helm-values/values-loki.yaml `
  --wait --timeout 3m

helm upgrade --install fluent-bit fluent/fluent-bit `
  --namespace monitoring `
  -f stack/monitoring/helm-values/values-fluent-bit.yaml `
  --wait --timeout 2m
```

### 0.8 — Aplicar dashboards e alerts da stack base

```bash
kubectl apply -f stack/monitoring/manifests/
```

---

## Fase 1 — Instalar o MinIO (object storage)

> **Por que MinIO antes do Mimir?**
> O Mimir precisa dos buckets S3 no MinIO para inicializar.
> O `initContainer` do StatefulSet aguarda o MinIO subir, mas é
> melhor tê-lo funcionando antes de aplicar os manifests do Mimir.

> **Nota**: o chart `bitnami/minio` foi descontinuado. Usamos agora a imagem
> oficial `minio/minio` via manifest Kubernetes (sem dependência de Helm chart externo).
> O arquivo `manifests/00-minio.yaml` contém: Secret, StatefulSet, Services e um Job
> que cria os 3 buckets automaticamente via `minio/mc`.

### 1.1 — Instalar o MinIO

```bash
kubectl apply -f manifests/00-minio.yaml
```

Aguarde o StatefulSet e o Job de criação de buckets:

```bash
kubectl rollout status statefulset/minio -n monitoring

# Verificar o Job de provisionamento dos buckets
kubectl wait --for=condition=complete job/minio-create-buckets -n monitoring --timeout=120s
```

### 1.2 — Verificar os buckets provisionados

```bash
kubectl get pods -n monitoring -l app=minio
# Esperado: minio-0 Running 1/1

kubectl logs -n monitoring job/minio-create-buckets -c mc
# Esperado: "Buckets criados: mimir-blocks, mimir-alertmanager, mimir-ruler"
```

Console web (login: mimir / mimir-supersecret):
http://localhost:9001

---

## Fase 2 — Instalar o Mimir

### 2.1 — Aplicar ConfigMap de configuração

```bash
kubectl apply -f manifests/01-mimir-config.yaml
```

### 2.2 — Aplicar StatefulSet + Services

```bash
kubectl apply -f manifests/02-mimir-deployment.yaml
```

### 2.3 — Aguardar o Mimir ficar ready

O `initContainer` aguarda o MinIO primeiro. Depois o próprio Mimir
leva ~30-45s para inicializar todos os componentes.

```bash
kubectl rollout status statefulset/mimir -n monitoring
# Esperado: statefulset rolling update complete
```

```bash
kubectl get pods -n monitoring -l app=mimir
# Esperado: mimir-0   1/1   Running
```

### 2.4 — Health check

```bash
# Linux / macOS
curl http://localhost:9009/ready
# Esperado: ready
```
```pwsh
# Windows (PowerShell)
Invoke-RestMethod http://localhost:9009/ready
# Esperado: ready
```

```bash
# Linux / macOS
curl http://localhost:9009/api/v1/status/config | head -5
```
```pwsh
# Windows (PowerShell)
Invoke-RestMethod http://localhost:9009/api/v1/status/config
```

---

## Fase 3 — Configurar o Datasource no Grafana

### 3.1 — Aplicar o datasource Mimir

```bash
kubectl apply -f manifests/03-grafana-datasource-mimir.yaml
```

### 3.2 — Verificar que o sidecar do Grafana detectou o ConfigMap

```bash
# Linux / macOS
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana \
  -c grafana-sc-datasources --tail=5
# Esperado: "Datasources config reloaded"
```
```pwsh
# Windows (PowerShell)
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana `
  -c grafana-sc-datasources --tail=5
# Esperado: "Datasources config reloaded"
```

### 3.3 — Verificar no Grafana

Acesse: http://localhost:3000 (admin / prom-operator)

Navegue até **Connections → Data sources** e confirme:
- `Mimir` com status **OK** (verde)

---

## Fase 4 — Confirmar que o Prometheus está enviando dados

### 4.1 — Verificar métricas do remote_write no Prometheus

Acesse: http://localhost:9090

```promql
# Amostras enviadas com sucesso ao Mimir
prometheus_remote_storage_samples_total{remote_name="0"}

# Amostras pendentes na fila (deve ser próximo de 0 em estado estável)
prometheus_remote_storage_pending_samples{remote_name="0"}

# Falhas (deve ser 0 — se > 0, verifique os logs do pod mimir-0)
prometheus_remote_storage_failed_samples_total{remote_name="0"}
```

### 4.2 — Querier o Mimir diretamente

```bash
# Linux / macOS

# Listar séries ativas no Mimir
curl 'http://localhost:9009/prometheus/api/v1/label/__name__/values' | \
  python -m json.tool | head -20

# Verificar o uptime dos pods (mesmos dados que o Prometheus)
curl 'http://localhost:9009/prometheus/api/v1/query?query=up' | \
  python -m json.tool
```
```pwsh
# Windows (PowerShell)

# Listar séries ativas no Mimir
(Invoke-RestMethod "http://localhost:9009/prometheus/api/v1/label/__name__/values").data |
  Select-Object -First 20

# Verificar o uptime dos pods
Invoke-RestMethod "http://localhost:9009/prometheus/api/v1/query?query=up"
```

### 4.3 — Comparar no Grafana

No **Explore** do Grafana, execute a mesma query em dois datasources:

| Datasource | Query | Esperado |
|---|---|---|
| **Prometheus** | `up` | Dados dos últimos 15 dias |
| **Mimir** | `up` | Mesmos dados (em breve mais histórico) |

---

## Fase 5 — Demonstração de Persistência ⭐

> Este é o ponto central do módulo.
> Vamos simular o "problema de sexta-feira": reiniciar o Prometheus
> e verificar que os dados históricos continuam disponíveis via Mimir.

### 5.1 — Verificar dados atuais

No Grafana → Explore → Datasource: **Prometheus**

```promql
rate(container_cpu_usage_seconds_total{namespace="games"}[5m])
```

Anote o horário atual.

### 5.2 — Deletar o pod do Prometheus (simula restart/upgrade)

```bash
# Linux / macOS
kubectl delete pod -n monitoring \
  -l app.kubernetes.io/name=prometheus --wait=false

# O Kubernetes recria imediatamente — aguarde:
kubectl rollout status statefulset/prometheus-kind-prometheus-kube-pro-prometheus \
  -n monitoring
```
```pwsh
# Windows (PowerShell)
kubectl delete pod -n monitoring `
  -l app.kubernetes.io/name=prometheus --wait=false

# O Kubernetes recria imediatamente — aguarde:
kubectl rollout status statefulset/prometheus-kind-prometheus-kube-pro-prometheus `
  -n monitoring
```

### 5.3 — Verificar que o Prometheus perdeu dados locais

No Grafana → Explore → Datasource: **Prometheus**

```promql
rate(container_cpu_usage_seconds_total{namespace="games"}[5m])
```

Coloque o time range para incluir 5 minutos antes do restart.
**Resultado esperado**: Lacuna nos dados durante o restart.

### 5.4 — Verificar que o Mimir preservou os dados

Mude o Datasource para **Mimir** e execute a mesma query com o mesmo range.

**Resultado esperado**: Dados contínuos — sem lacuna.

> **Isso é o Mimir funcionando**: o Prometheus recebeu os dados, enviou
> ao Mimir via remote_write, e quando o TSDB local foi perdido no restart,
> os dados continuaram acessíveis no object storage (MinIO).

---

## Fase 6 — Explorar Queries de Longo Prazo

### 6.1 — Queries que só funcionam no Mimir

No Grafana → Explore → Datasource: **Mimir**

```promql
# Quantas horas de dados temos no Mimir?
(max_over_time(up[30d]) - min_over_time(up[30d])) / 3600
```

```promql
# Comparar CPU desta semana vs semana passada (offset)
rate(container_cpu_usage_seconds_total{namespace="games"}[5m])
  /
rate(container_cpu_usage_seconds_total{namespace="games"}[5m] offset 7d)
```

### 6.2 — Verificar blocos gravados no MinIO

Acesse o console do MinIO: http://localhost:9001

Navegue em **mimir-blocks** e observe os diretórios com ULIDs (IDs dos blocos TSDB).

Cada diretório contém:
- `chunks/` — dados binários compactados
- `index` — índice de séries e labels
- `meta.json` — metadados do bloco (min/max timestamp, número de séries)

```bash
# Linux / macOS
kubectl exec -n monitoring statefulset/mimir -- ls /data/tsdb
# Mostra o WAL local do ingester (pré-compactação)
```
```pwsh
# Windows (PowerShell)
kubectl exec -n monitoring statefulset/mimir -- ls /data/tsdb
```

> Para visualizar os blocos já compactados no MinIO via CLI:
> ```bash
> kubectl exec -n monitoring statefulset/minio -- mc ls local/mimir-blocks
> ```

---

## Troubleshooting

### Mimir não inicia — "bucket not found"

```bash
kubectl logs -n monitoring statefulset/mimir --tail=30
# Se: "bucket does not exist: mimir-blocks"
# Significa que o Job de criação de buckets falhou ou ainda não terminou

# Verificar status do Job
kubectl get job minio-create-buckets -n monitoring
kubectl logs -n monitoring job/minio-create-buckets -c mc

# Reaplicar o Job (se necessário)
kubectl delete job minio-create-buckets -n monitoring
kubectl apply -f manifests/00-minio.yaml
```

### remote_write com falha — "connection refused"

```bash
# Verifique se o pod do Mimir está Running
kubectl get pod -n monitoring mimir-0
```

```bash
# Linux / macOS — erros de remote_write aparecem aqui
kubectl logs -n monitoring \
  statefulset/prometheus-kind-prometheus-kube-pro-prometheus \
  --tail=20 | grep -i remote
```
```pwsh
# Windows (PowerShell)
kubectl logs -n monitoring `
  statefulset/prometheus-kind-prometheus-kube-pro-prometheus `
  --tail=20 | Select-String "remote"
```

### Grafana não mostra o datasource Mimir

```bash
# Forçar reload dos datasources pelo sidecar
kubectl rollout restart deployment/kind-prometheus-grafana -n monitoring

# Ou reaplique o ConfigMap
kubectl apply -f manifests/03-grafana-datasource-mimir.yaml
```

### Mimir não inicia — alertmanager ring / compactor

**Causa**: O `alertmanager.sharding_ring.replication_factor` padrão é **3**. Com 1 instância, o ring nunca atinge quórum e bloqueia a subida. O `compactor.data_dir` padrão (`./data-compactor/`) também pode falhar se o working dir do container não for gravável.

**Solução** (já aplicada no `manifests/01-mimir-config.yaml`):
- `alertmanager.sharding_ring.replication_factor: 1`
- `compactor.data_dir: /data/compactor`

Se você já tinha o Mimir rodando com a config antiga, force o restart após reaplicar:

```bash
kubectl apply -f manifests/01-mimir-config.yaml
kubectl rollout restart statefulset/mimir -n monitoring
kubectl rollout status statefulset/mimir -n monitoring
```

Verifique os logs em tempo real para confirmar que subiu sem erros:
```bash
kubectl logs -n monitoring statefulset/mimir -f --tail=40
```

### Query no Mimir retorna "no data"

O Mimir só tem dados a partir do momento em que o remote_write foi configurado.
Se você acabou de instalar, aguarde pelo menos 1-2 minutos de scrape do Prometheus.

```bash
# Linux / macOS
curl 'http://localhost:9009/prometheus/api/v1/query?query=scrape_samples_scraped' | \
  python -m json.tool | grep value
```
```pwsh
# Windows (PowerShell)
(Invoke-RestMethod "http://localhost:9009/prometheus/api/v1/query?query=scrape_samples_scraped").data.result
```
