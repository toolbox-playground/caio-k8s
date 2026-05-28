# 🚀 Módulo 05 — Profiling Contínuo (Modo Híbrido: SDK + Grafana Alloy)

> ⚠️ **Todos os comandos devem ser executados de dentro da pasta `modulo-05-profiler/`:**
>
> **PowerShell:**
> ```powershell
> cd curso-k8s/modulo-05-profiler
> ```
> **bash / zsh:**
> ```bash
> cd curso-k8s/modulo-05-profiler
> ```

## O que será instalado neste módulo

Este módulo combina **duas fontes de profiling** rodando em paralelo sobre a mesma aplicação:

| Fonte | O que coleta | Tag no Grafana |
|---|---|---|
| **pyroscope-io SDK** | Call stack Python — funções, linhas de código, hot paths | `profiler=sdk` |
| **Grafana Alloy (eBPF)** | Syscalls do kernel, I/O, runtime C, qualquer processo | `profiler=ebpf` |

O resultado é que você pode cruzar dois flame graphs da mesma `ranking-api`:
- O SDK mostra `calculate_score` usando 40ms de CPU Python
- O eBPF mostra que `futex_wait` consumiu mais 340ms abaixo do Python

Essa combinação resolve o problema do "trace lento sem motivo aparente" — o SDK mostra o que o Python faz, o eBPF mostra o que o kernel faz enquanto o Python espera.

**Stack completa ao final deste guia:**

```
┌─────────────────────────────────────────────────┐
│  namespace: monitoring                          │
│  Prometheus · Grafana · AlertManager            │
│  Loki · Fluent Bit · Tempo · OTel Collector     │
│  Pyroscope (server) · Alloy (DaemonSet eBPF)    │
└─────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────┐
│  namespace: games                               │
│  Super Mario (HPA) · ranking-api v2 (SDK)       │
└─────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────┐
│  namespace: otel                                │
│  OTel Collector                                 │
└─────────────────────────────────────────────────┘
```

---

## Fase 0 — Preparar o cluster com toda a stack anterior

> 🎯 **Faça esta fase apenas se está recriando o cluster do zero ou iniciando o ambiente pela primeira vez.**  
> Se os módulos 03 e 04 já estão rodando (`kubectl get pods -n monitoring`), vá direto para a **Fase 1**.

### Passo 0.1 — Criar o cluster Kind com todas as portas mapeadas

O `cluster-config.yaml` deste módulo inclui os mapeamentos de todos os módulos anteriores **mais** a porta do Pyroscope (4040).

**PowerShell e bash:**

```sh
# Deletar cluster anterior se existir (ignorar erro se não existir)
kind delete cluster --name k8s-essentials

# Recriar com o config completo do Módulo 05
kind create cluster --config cluster-config.yaml

# Confirmar que os nodes ficaram Ready
kubectl get nodes
```

Portas disponíveis após a criação:

| Serviço | localhost | NodePort |
|---|---|---|
| Super Mario | http://localhost:8081 | 30000 |
| Prometheus | http://localhost:9090 | 30090 |
| Grafana | http://localhost:3000 | 31000 |
| AlertManager | http://localhost:9093 | 32000 |
| Node Exporter | http://localhost:9100 | 32001 |
| **Pyroscope** | **http://localhost:4040** | **34040** |

---

### Passo 0.2 — Instalar o Metrics Server

O Metrics Server é necessário para o HPA funcionar (`kubectl top` e escalamento automático).

**PowerShell e bash:**

```sh
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
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

> ⚠️ O patch desabilita a validação TLS do kubelet — necessário no Kind porque o kubelet usa certificados autoassinados. Não use em produção.

---

### Passo 0.3 — Deploy do Super Mario (Módulo 02)

**PowerShell e bash:**

```sh
kubectl create namespace games --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f stack/mario/01-deployment-mario.yaml
kubectl apply -f stack/mario/02-service-mario.yaml
kubectl apply -f stack/mario/03-hpa.yaml
```

---

### Passo 0.4 — Adicionar repositórios Helm

**PowerShell e bash:**

```sh
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add fluent https://fluent.github.io/helm-charts/
helm repo update
```

---

### Passo 0.5 — Instalar Prometheus + Grafana + AlertManager (Módulo 03)

**PowerShell:**

```powershell
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install kind-prometheus prometheus-community/kube-prometheus-stack `
  --namespace monitoring `
  -f stack/monitoring/helm-values/values-prometheus-stack.yaml
```

**bash / zsh:**

```bash
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install kind-prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f stack/monitoring/helm-values/values-prometheus-stack.yaml
```

---

### Passo 0.6 — Instalar o Loki (Módulo 03)

**PowerShell:**

```powershell
helm upgrade --install loki grafana/loki `
  --namespace monitoring `
  -f stack/monitoring/helm-values/values-loki.yaml
```

**bash / zsh:**

```bash
helm upgrade --install loki grafana/loki \
  --namespace monitoring \
  -f stack/monitoring/helm-values/values-loki.yaml
```

---

### Passo 0.7 — Instalar o Fluent Bit (Módulo 03)

**PowerShell:**

```powershell
helm upgrade --install fluent-bit fluent/fluent-bit `
  --namespace monitoring `
  -f stack/monitoring/helm-values/values-fluent-bit.yaml
```

**bash / zsh:**

```bash
helm upgrade --install fluent-bit fluent/fluent-bit \
  --namespace monitoring \
  -f stack/monitoring/helm-values/values-fluent-bit.yaml
```

---

### Passo 0.8 — Instalar o Blackbox Exporter + alertas (Módulo 03)

O Blackbox Exporter monitora a latência sintética do Super Mario a cada 15 segundos.

**PowerShell:**

```powershell
helm upgrade --install blackbox-exporter `
  prometheus-community/prometheus-blackbox-exporter `
  --namespace monitoring

```

**Bash:**

```sh
helm upgrade --install blackbox-exporter \
  prometheus-community/prometheus-blackbox-exporter \
  --namespace monitoring

```

**PowerShell e bash:**

```sh
kubectl apply -f stack/monitoring/manifests/01-four-golden-signals.yaml
kubectl apply -f stack/monitoring/manifests/02-blackbox-probe.yaml
kubectl apply -f stack/monitoring/manifests/03-grafana-alert-rules.yaml
```

---

### Passo 0.9 — Instalar o Grafana Tempo (Módulo 04)

**PowerShell:**

```powershell
helm upgrade --install tempo grafana/tempo `
  --namespace monitoring `
  -f stack/opentelemetry/helm-values/values-tempo.yaml
```

**bash / zsh:**

```bash
helm upgrade --install tempo grafana/tempo \
  --namespace monitoring \
  -f stack/opentelemetry/helm-values/values-tempo.yaml
```

---

### Passo 0.10 — Instalar o OTel Collector (Módulo 04)

**PowerShell e bash:**

```sh
kubectl apply -f stack/opentelemetry/manifests/03-otel-collector.yaml
kubectl apply -f stack/opentelemetry/manifests/04-podmonitor-otel-collector.yaml
```

---

### Passo 0.11 — Provisionar datasource Tempo no Grafana (Módulo 04)

O ConfigMap abaixo provisiona o Tempo no Grafana com **Trace to Logs** (Loki) e **Trace to Metrics** (Prometheus) já configurados. O sidecar do Grafana detecta e recarrega em ~30s.

**PowerShell e bash:**

```sh
kubectl apply -f stack/opentelemetry/manifests/06-grafana-datasource-tempo.yaml
```

Verificar carregamento:

**PowerShell:**

```powershell
kubectl logs -n monitoring `
  -l app.kubernetes.io/name=grafana `
  -c grafana-sc-datasources --tail=5
# Esperado: Response: 200 OK {"message":"Datasources config reloaded"}
```

**bash / zsh:**

```bash
kubectl logs -n monitoring \
  -l app.kubernetes.io/name=grafana \
  -c grafana-sc-datasources --tail=5
```

---

### Passo 0.12 — Aguardar toda a stack subir

**PowerShell e bash:**

```sh
kubectl get pods -n monitoring -w
```

Estado esperado (todos `Running`):

```
alertmanager-kind-prometheus-kube-prome-alertmanager-0   2/2   Running
blackbox-exporter-prometheus-blackbox-exporter-xxxx      1/1   Running
fluent-bit-xxxx                                          1/1   Running
kind-prometheus-grafana-xxxx                             4/4   Running
kind-prometheus-kube-prome-operator-xxxx                 1/1   Running
kind-prometheus-kube-state-metrics-xxxx                  1/1   Running
kind-prometheus-prometheus-node-exporter-xxxx            1/1   Running
loki-0                                                   2/2   Running
loki-gateway-xxxx                                        1/1   Running
prometheus-kind-prometheus-kube-prome-prometheus-0       2/2   Running
tempo-0                                                  1/1   Running
```

E no namespace `otel`:

```sh
kubectl get pods -n otel
# otel-collector-xxxx   1/1   Running
```

---

### Passo 0.13 — Importar dashboards dos Módulos 03 e 04

**Grafana: http://localhost:3000 → Dashboards → New → Import → Upload dashboard JSON file**

> 💡 **Recuperar a senha do Grafana:**
>
> **PowerShell:**
> ```powershell
> kubectl --namespace monitoring get secret kind-prometheus-grafana `
>   -o jsonpath="{.data.admin-password}" |
>   ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
> ```
> **bash / zsh:**
> ```bash
> kubectl --namespace monitoring get secret kind-prometheus-grafana \
>   -o jsonpath="{.data.admin-password}" | base64 --decode
> ```

Importe os seguintes JSONs **nesta ordem**:

#### Módulo 03 — Four Golden Signals

| Arquivo | Datasource |
|---|---|
| `stack/monitoring/grafana-dashboards/four-golden-signals.json` | Prometheus |

#### Módulo 04 — Observabilidade com OTel

| Arquivo | Datasource |
|---|---|
| `stack/opentelemetry/grafana-dashboards/latencia-p99.json` | Prometheus + Tempo |
| `stack/opentelemetry/grafana-dashboards/p99-por-endpoint.json` | Prometheus |
| `stack/opentelemetry/grafana-dashboards/logs-devops.json` | Loki |
| `stack/opentelemetry/grafana-dashboards/devsecops.json` | Prometheus + Loki + Tempo |

---

### ✅ Verificação final da stack

**PowerShell e bash:**

```sh
# Todos os pods devem estar Running
kubectl get pods -n monitoring
kubectl get pods -n otel
kubectl get pods -n games

# Serviços acessíveis (NodePort)
# Grafana:      http://localhost:3000
# Prometheus:   http://localhost:9090
# AlertManager: http://localhost:9093
# Pyroscope:    http://localhost:4040  ← instalado na Fase 1
```

---

## Fase 1 — Instalar o Pyroscope Server

O Pyroscope é o backend de continuous profiling. Ele recebe e armazena flame graphs enviados tanto pelo SDK Python quanto pelo Grafana Alloy eBPF.

**PowerShell:**

```powershell
helm upgrade --install pyroscope grafana/pyroscope `
  --namespace monitoring `
  -f helm-values/values-pyroscope.yaml
```

**bash / zsh:**

```bash
helm upgrade --install pyroscope grafana/pyroscope \
  --namespace monitoring \
  -f helm-values/values-pyroscope.yaml
```

Aguardar:

**PowerShell e bash:**

```sh
kubectl rollout status statefulset/pyroscope -n monitoring
```

Acessar: **http://localhost:4040**

---

## Fase 2 — Provisionar datasource Pyroscope no Grafana

Este ConfigMap adiciona o datasource Pyroscope **e** atualiza o datasource Tempo para habilitar a correlação **Trace → Profile** (botão "Profiles for this span" direto no trace).

**PowerShell e bash:**

```sh
kubectl apply -f manifests/02-grafana-datasource-tempo-pyroscope.yaml
```

Verificar:

**PowerShell:**

```powershell
kubectl logs -n monitoring `
  -l app.kubernetes.io/name=grafana `
  -c grafana-sc-datasources --tail=10
# Esperado: Response: 200 OK {"message":"Datasources config reloaded"}
```

**bash / zsh:**

```bash
kubectl logs -n monitoring \
  -l app.kubernetes.io/name=grafana \
  -c grafana-sc-datasources --tail=10
```

---

## Fase 3 — Build e deploy da ranking-api v2 (com SDK)

A `ranking-api:v2-profiler` adiciona o `pyroscope-io` SDK ao código Python. O tag `profiler=sdk` identifica os profiles vindos desta fonte no Grafana.

**PowerShell e bash:**

```sh
# Build da imagem com o SDK do Pyroscope
docker build -t ranking-api:v2-profiler ./app

# Carregar no cluster Kind
kind load docker-image ranking-api:v2-profiler --name k8s-essentials

# Deploy no namespace games
kubectl apply -f manifests/01-deployment-ranking-api-v2.yaml
kubectl apply -f stack/opentelemetry/manifests/02-service-ranking-api.yaml
```

Aguardar:

**PowerShell e bash:**

```sh
kubectl rollout status deployment/ranking-api -n games
```

Verificar que o SDK está se conectando:

**PowerShell e bash:**

```sh
kubectl logs -n games -l app=ranking-api --tail=20
# Deve aparecer conexão bem-sucedida ao Pyroscope sem erros
```

---

## Fase 4 — Instalar o Grafana Alloy (eBPF)

O Alloy roda como DaemonSet — um pod por node. Usa eBPF para perfilar **todos os processos do cluster** sem modificar nenhuma aplicação. O tag `profiler=ebpf` é adicionado automaticamente via relabeling no `values-alloy.yaml`.

**PowerShell:**

```powershell
helm upgrade --install alloy grafana/alloy `
  --namespace monitoring `
  -f helm-values/values-alloy.yaml
```

**bash / zsh:**

```bash
helm upgrade --install alloy grafana/alloy \
  --namespace monitoring \
  -f helm-values/values-alloy.yaml
```

Verificar DaemonSet:

**PowerShell e bash:**

```sh
kubectl get daemonset -n monitoring | grep alloy
kubectl rollout status daemonset/alloy -n monitoring
```

Confirmar que o eBPF está coletando:

**PowerShell e bash:**

```sh
kubectl logs -n monitoring -l app.kubernetes.io/name=alloy --tail=30
# Procure: component started  component=pyroscope.ebpf.default
```

---

## Fase 5 — Gerar carga

**PowerShell e bash:**

```sh
kubectl run fortio \
  --image=fortio/fortio \
  --restart=Never \
  -n games \
  -- load -c 5 -qps 10 -t 300s \
  http://ranking-api.games.svc.cluster.local:8000/rankings
```

Acompanhar:

**PowerShell e bash:**

```sh
kubectl logs -n games fortio -f
```

> Aguarde ~2 minutos para acumular profiles suficientes antes de explorar no Grafana.

---

## Fase 6 — Visualizar no Grafana

### 6.1 — Profiles lado a lado (SDK vs eBPF)

```
Grafana → Explore → Datasource: Grafana Pyroscope
```

**Profile SDK (frames Python):**
```
{service_name="ranking-api", profiler="sdk"}
```

**Profile eBPF (syscalls do kernel):**
```
{service_name="ranking-api", profiler="ebpf"}
```

> Use o botão **Split** do Explore para abrir os dois flame graphs lado a lado.

### 6.2 — O que cada flame graph mostra

**SDK — call stack Python nomeado:**
```
ranking
  └── get_rankings
        └── _generate_scores
              └── calculate_score  ← hot path em Python
```

**eBPF — o que acontece abaixo do Python:**
```
ranking-api
  ├── python3.12
  │     └── PyEval_EvalFrameDefault
  │           └── futex_wait  ← onde o tempo realmente some
  └── libc: read, write, epoll_wait
```

> **Insight chave:** se o SDK mostra 40ms de CPU Python mas o trace p99 é 380ms,  
> os 340ms restantes estão em `futex_wait` ou I/O de rede — visível no eBPF,  
> **invisível** para o SDK porque o processo não estava usando CPU Python nesse intervalo.

### 6.3 — Correlação Trace → Profile

Quando o Pyroscope datasource está configurado, o Grafana Tempo exibe um botão **"Profiles for this span"** em cada span:

```
Grafana → Explore → Datasource: Tempo
{ resource.service.name = "ranking-api" && duration > 100ms }
→ Clique em um trace → Clique em um span → "Profiles for this span"
```

Isso abre o flame graph do exato intervalo de tempo daquele span — sem precisar filtrar manualmente.

### 6.4 — Infra do cluster profiled pelo eBPF

O Alloy perfila automaticamente todos os pods do cluster. Explore no Pyroscope:

```
{namespace="monitoring", service_name="prometheus-server", profiler="ebpf"}
{namespace="monitoring", service_name="loki", profiler="ebpf"}
{namespace="otel", service_name="otel-collector", profiler="ebpf"}
```

---

## Acesso rápido aos serviços

| Serviço | URL | Credenciais |
|---|---|---|
| Grafana | http://localhost:3000 | admin / (ver Passo 0.13) |
| Prometheus | http://localhost:9090 | — |
| AlertManager | http://localhost:9093 | — |
| Pyroscope | http://localhost:4040 | — |

---

## Troubleshooting

### Profiles não aparecem no Grafana

```sh
# Verificar conectividade do Alloy com o Pyroscope
kubectl exec -n monitoring \
  $(kubectl get pod -n monitoring -l app.kubernetes.io/name=alloy \
    -o jsonpath='{.items[0].metadata.name}') \
  -- wget -qO- http://pyroscope.monitoring.svc.cluster.local:4040/ready

# Verificar targets descobertos
kubectl logs -n monitoring -l app.kubernetes.io/name=alloy | grep -i "target\|error"
```

### SDK não envia profiles

**PowerShell:**

```powershell
kubectl exec -n games `
  $(kubectl get pod -n games -l app=ranking-api -o jsonpath='{.items[0].metadata.name}') `
  -- env | Select-String PYROSCOPE
# Deve mostrar:
# PYROSCOPE_SERVER_ADDRESS=http://pyroscope.monitoring.svc.cluster.local:4040
# PYROSCOPE_APPLICATION_NAME=ranking-api
# PYROSCOPE_TAGS=...,profiler=sdk
```

**bash / zsh:**

```bash
kubectl exec -n games \
  $(kubectl get pod -n games -l app=ranking-api -o jsonpath='{.items[0].metadata.name}') \
  -- env | grep PYROSCOPE
```

### Alloy não inicia (eBPF indisponível)

```sh
kubectl describe pod -n monitoring -l app.kubernetes.io/name=alloy | grep -A10 "Events"
```

> Em Kind no Windows/macOS, o kernel Linux é exposto via VM pelo Docker Desktop — o eBPF geralmente funciona. Se falhar com `permission denied`, confirme que o pod tem `privileged: true` no `values-alloy.yaml`.

### fluent-bit falha no install

Se o `helm install` falhar com "already installed", use `helm upgrade --install` (já é o padrão em todos os comandos deste guia).

```sh
# Verificar releases instalados
helm list -n monitoring
```

---

> 📚 Para entender a teoria (o que é profiler, flame graph, eBPF, casos de uso reais),  
> consulte o [README.md do módulo](README.md).
