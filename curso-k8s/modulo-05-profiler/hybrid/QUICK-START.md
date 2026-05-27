# QUICK-START: Modo Híbrido (SDK + Grafana Alloy)

> **Objetivo:** rodar o `pyroscope-io` SDK na `ranking-api` para granularidade Python  
> **e** o Grafana Alloy eBPF em todo o cluster para syscalls + infra.

---

## Pré-requisitos

| Pré-requisito | Verificar com |
|---|---|
| Kind instalado | `kind version` |
| kubectl instalado | `kubectl version --client` |
| helm instalado | `helm version` |
| Docker rodando | `docker info` |
| Stack Módulo 03 (Prometheus + Grafana + Loki) | `kubectl get pods -n monitoring` |
| Stack Módulo 04 (OTel Collector + Tempo) | `kubectl get pods -n otel` |

---

## Visão geral do que será instalado

```
┌──────────────────────────────────────────────────────────────┐
│  Namespace: monitoring                                       │
│                                                              │
│  pyroscope (server)  ← recebe profiles de ambas as fontes   │
│  alloy (DaemonSet)   ← eBPF em todos os nodes              │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│  Namespace: games                                            │
│                                                              │
│  ranking-api:v2-profiler  ← com pyroscope-io SDK            │
│    PYROSCOPE_TAGS=profiler=sdk                               │
└──────────────────────────────────────────────────────────────┘

No Grafana Pyroscope:
  {service_name="ranking-api", profiler="sdk"}  → frames Python
  {service_name="ranking-api", profiler="ebpf"} → syscalls do kernel
```

---

## Fase 1 — Cluster Kind

```bash
cd hybrid

# Criar o cluster com porta para o Pyroscope
kind create cluster --config manifests/cluster-config.yaml --name k8s-essentials

# Confirmar
kubectl get nodes
```

> Se o cluster já existe do Módulo 04, apenas confirme que a porta 34040→4040 está no mapeamento.  
> Se não, recrie o cluster (o cluster-config.yaml já inclui todas as portas dos módulos anteriores).

---

## Fase 2 — Instalar o Pyroscope Server

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install pyroscope grafana/pyroscope \
  --namespace monitoring \
  --create-namespace \
  -f helm-values/values-pyroscope.yaml

# Aguardar
kubectl rollout status deployment/pyroscope -n monitoring
```

Acessar em: **http://localhost:34040**

---

## Fase 3 — Adicionar o datasource no Grafana

1. Abra o Grafana: **http://localhost:32000** (admin/admin)
2. **Connections → Data Sources → Add new data source**
3. Tipo: **Grafana Pyroscope**
4. URL: `http://pyroscope.monitoring.svc.cluster.local:4040`
5. Salvar

### (Opcional) Correlação Trace → Profile

Se o Tempo já está configurado, habilite Trace → Profile:

1. Grafana → **Connections → Data Sources → Tempo**
2. Seção **Trace to profiles**
3. Data source: `Grafana Pyroscope`
4. Tags: `service.name` → `service_name`

---

## Fase 4 — Build e deploy da ranking-api v2 (com SDK)

```bash
# Build da imagem com pyroscope-io
docker build -t ranking-api:v2-profiler ./app

# Carregar no cluster Kind
kind load docker-image ranking-api:v2-profiler --name k8s-essentials

# Criar namespace e deploiar
kubectl create namespace games --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f manifests/01-deployment-ranking-api-v2.yaml

# Confirmar
kubectl rollout status deployment/ranking-api -n games
```

Verificar se os logs mostram o SDK se conectando:

```bash
kubectl logs -n games -l app=ranking-api --tail=20
```

Você deve ver algo como: `pyroscope: profiling started` ou ausência de erros relacionados ao Pyroscope.

---

## Fase 5 — Instalar o Grafana Alloy (eBPF)

```bash
helm install alloy grafana/alloy \
  --namespace monitoring \
  -f helm-values/values-alloy.yaml

# Verificar DaemonSet
kubectl get daemonset -n monitoring
kubectl rollout status daemonset/alloy -n monitoring
```

Confirmar que o Alloy está perfilhando:

```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=alloy --tail=30
```

Você deve ver: `component started  component=pyroscope.ebpf.default` ou similar.

---

## Fase 6 — Gerar carga

```bash
# Geração contínua de requests
kubectl run fortio \
  --image=fortio/fortio \
  --restart=Never \
  -n games \
  -- load -c 5 -qps 10 -t 300s \
  http://ranking-api.games.svc.cluster.local:8000/rankings

# Acompanhar
kubectl logs -n games fortio -f
```

Aguardar ~2 minutos para acumular profiles suficientes.

---

## Fase 7 — Visualizar no Grafana

### 7.1 — Ver profiles lado a lado

1. Grafana → **Explore**
2. Datasource: `Grafana Pyroscope`

**Profile SDK (Python frames):**
```
{service_name="ranking-api", profiler="sdk"}
```

**Profile eBPF (syscalls do kernel):**
```
{service_name="ranking-api", profiler="ebpf"}
```

> Use o botão **Split** do Explore para abrir dois painéis lado a lado.

### 7.2 — Flame Graph SDK

O SDK mostra o call stack Python nomeado:
```
ranking
  └── get_rankings
        └── _generate_scores
              └── calculate_score  ← hot path
```

Cada bloco é uma função Python real. O `tag_wrapper` isola o perfil por endpoint.

### 7.3 — Flame Graph eBPF

O Alloy mostra o que acontece abaixo do Python:
```
ranking-api
  ├── python3.12
  │     └── PyEval_EvalFrameDefault
  │           └── futex_wait        ← aqui está o tempo "perdido"
  └── libc: read, write, epoll_wait
```

> **Insight chave:** se o SDK mostra 40ms de Python mas o p99 é 380ms,  
> os 340ms restantes estão em `futex_wait` ou I/O de rede — visível no eBPF,  
> **invisível** para o SDK porque o processo não estava usando CPU Python.

### 7.4 — Infra do cluster

Outros serviços profiled pelo Alloy sem nenhuma mudança:

```
{namespace="monitoring", service_name="prometheus-server", profiler="ebpf"}
{namespace="monitoring", service_name="loki", profiler="ebpf"}
{namespace="otel", service_name="otel-collector", profiler="ebpf"}
```

---

## Troubleshooting

### Profiles não aparecem no Grafana

```bash
# Verificar conectividade do Alloy com o Pyroscope
kubectl exec -n monitoring \
  $(kubectl get pod -n monitoring -l app.kubernetes.io/name=alloy -o jsonpath='{.items[0].metadata.name}') \
  -- wget -qO- http://pyroscope.monitoring.svc.cluster.local:4040/ready

# Verificar targets descobertos pelo Alloy
kubectl logs -n monitoring -l app.kubernetes.io/name=alloy | grep "target"
```

### SDK não envia profiles

```bash
# Checar variáveis de ambiente no pod
kubectl exec -n games \
  $(kubectl get pod -n games -l app=ranking-api -o jsonpath='{.items[0].metadata.name}') \
  -- env | grep PYROSCOPE

# Deve mostrar:
# PYROSCOPE_SERVER_ADDRESS=http://pyroscope.monitoring.svc.cluster.local:4040
# PYROSCOPE_APPLICATION_NAME=ranking-api
# PYROSCOPE_TAGS=environment=kind-dev,version=2.0.0,profiler=sdk
```

### Alloy não inicia (eBPF indisponível)

```bash
kubectl describe pod -n monitoring -l app.kubernetes.io/name=alloy | grep -A5 "Events"
```

> Em Kind, o eBPF requer que o nó use o kernel do host (Linux). No Windows/macOS com  
> Docker Desktop ou Rancher Desktop, o kernel é exposto via VM Linux — geralmente funciona.

---

## Próximos Passos

- Consulte o [README.md](README.md) para entender a arquitetura
- Veja a [teoria completa](../README.md) com questões de fixação
- Compare com as abordagens individuais: [pyroscope-sdk/](../pyroscope-sdk/) e [grafana-alloy/](../grafana-alloy/)
