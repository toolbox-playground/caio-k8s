# 🚀 Pyroscope SDK — Guia de Início Rápido

> ⚠️ **Execute os comandos de dentro da pasta `modulo-05-profiler/pyroscope-sdk/`:**
>
> ```sh
> cd curso-k8s/modulo-05-profiler/pyroscope-sdk
> ```

## Pré-condição

Stack dos módulos 03 e 04 rodando (Prometheus, Grafana, Loki, Tempo, OTel Collector).  
Se precisar recriar tudo do zero, siga a seção abaixo.

---

## Do zero — recriar cluster e stack completo

### Passo 1 — Criar cluster Kind com porta do Pyroscope

```sh
kind delete cluster --name k8s-essentials
kind create cluster --config manifests/cluster-config.yaml
```

### Passo 2 — Metrics Server

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

### Passo 3 — Stack de monitoramento (módulos 03 e 04)

```sh
kubectl create namespace games --dry-run=client -o yaml | kubectl apply -f -

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install kind-prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f ../../modulo-03-monitoring/helm-values/values-prometheus-stack.yaml

helm install loki grafana/loki \
  --namespace monitoring \
  -f ../../modulo-03-monitoring/helm-values/values-loki.yaml

helm install fluent-bit grafana/fluent-bit \
  --namespace monitoring \
  -f ../../modulo-03-monitoring/helm-values/values-fluent-bit.yaml

helm install tempo grafana/tempo \
  --namespace monitoring \
  -f ../../modulo-04-opentelemetry/helm-values/values-tempo.yaml

kubectl apply -f ../../modulo-04-opentelemetry/manifests/03-otel-collector.yaml
```

---

## Etapa 1 — Instalar o Pyroscope Server

```sh
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install pyroscope grafana/pyroscope \
  --namespace monitoring \
  --create-namespace \
  -f helm-values/values-pyroscope.yaml
```

```sh
kubectl get pods -n monitoring -l app.kubernetes.io/name=pyroscope
# Aguarde STATUS = Running
```

> 🌐 Pyroscope UI: **http://localhost:4040**

---

## Etapa 2 — Adicionar Pyroscope como datasource no Grafana

1. Acesse **http://localhost:3000** (admin / prom-operator)
2. **Connections → Data sources → Add new data source**
3. Selecione **"Grafana Pyroscope"**
4. URL: `http://pyroscope.monitoring.svc.cluster.local:4040`
5. **Save & test**

---

## Etapa 3 — Build e deploy da ranking-api v2

> ✅ **Python 3.12 suportado**
>
> O SDK `pyroscope-io==1.0.8` usa uma implementação em **Rust** (substituiu o py-spy da 0.8.x)
> e é distribuído como wheel `cp310-abi3` — compatível com Python 3.10, 3.11 e 3.12.
> O `Dockerfile` usa `python:3.12-slim`.

```sh
docker build -t ranking-api:v2-profiler ./app
kind load docker-image ranking-api:v2-profiler --name k8s-essentials
kubectl apply -f manifests/01-deployment-ranking-api-v2.yaml
```

```sh
kubectl get pods -n games -l app=ranking-api
# Aguarde READY = 1/1
```

Verifique que o SDK iniciou (ele é **silencioso** no startup — sem mensagem de confirmação):
```sh
kubectl logs -n games -l app=ranking-api --tail=5
# Deve mostrar apenas logs do uvicorn, sem erros
```

---

## Etapa 4 — Gerar carga (Fortio)

O Fortio faz 20 requisições/s por 10 minutos para a `ranking-api`:

```sh
kubectl apply -f manifests/02-stress-test-fortio.yaml
kubectl get pod fortio-ranking-api -n games
# Aguarde STATUS = Running
```

Verifique que o tráfego chegou:
```sh
kubectl logs -n games fortio-ranking-api --tail=3
# Deve mostrar: Starting at 20 qps ...
```

> 💡 O fortio roda por 10 minutos (`-t 10m`). Após isso fica com `Completed`.
> Para rodar novamente: `kubectl delete pod fortio-ranking-api -n games` e aplique de novo.

---

## Etapa 5 — Confirmar que profiles chegaram

Antes de abrir o Grafana, confirme nos logs do Pyroscope:

```sh
kubectl logs -n monitoring pyroscope-0 --tail=20 | grep ranking-api
# Deve aparecer:
# msg="profile accepted" service_name=ranking-api profile_type=process_cpu detected_language=python
```

Se não aparecer nada, verifique:
1. O pod da ranking-api tem a imagem nova? `kubectl get pod -n games -l app=ranking-api -o jsonpath='{.items[0].spec.containers[0].image}'`
2. O fortio está rodando? `kubectl get pod fortio-ranking-api -n games`

---

## Etapa 6 — Ver flame graphs no Grafana

1. **Grafana → Explore** (`http://localhost:3000/explore`)
2. No dropdown de datasource (canto superior esquerdo), selecione **Grafana Pyroscope**
3. O UI mostra dois dropdowns:
   - **Service Name:** selecione `ranking-api`
   - **Profile type:** selecione `process_cpu:cpu:nanoseconds:cpu:nanoseconds`
4. Intervalo: últimos 15 minutos → **Run query**
5. O flame graph aparece abaixo — as funções mais largas são as que consomem mais CPU

> 🔥 Procure no flame graph as funções `get_rankings` e `calcular_score` — elas têm sleeps
> simulando latência real, então vão aparecer com destaque no perfil de CPU.

### Filtrar por tag

O SDK envia os profiles com as tags definidas no `PYROSCOPE_TAGS`.
Para filtrar por versão ou ambiente, adicione um **Label filter** no Explore:

- `version = 2.0.0`
- `environment = kind-dev`

---

## Etapa 6 — Trace to Profile

### Configurar correlação no datasource Tempo

1. **Grafana → Connections → Data sources → Tempo**
2. Seção **"Trace to profiles"**
3. Ative e configure:
   - Data source: `Grafana Pyroscope`
   - Profile type: `process_cpu:cpu:nanoseconds:cpu:nanoseconds`
   - Tags: `service.name` → `service_name`
4. **Save & test**

### Usar

1. **Explore → Datasource: Tempo**
2. Query: `{ resource.service.name = "ranking-api" && duration > 50ms }`
3. Abra um trace → clique em um span lento → **"View profile"**

---

## Resumo dos endpoints

| Serviço      | URL                   | Credenciais            |
|--------------|-----------------------|------------------------|
| Grafana      | http://localhost:3000 | admin / prom-operator  |
| Pyroscope UI | http://localhost:4040 | sem autenticação       |
| Prometheus   | http://localhost:9090 | sem autenticação       |
| ranking-api  | http://localhost:8000 | via port-forward       |
