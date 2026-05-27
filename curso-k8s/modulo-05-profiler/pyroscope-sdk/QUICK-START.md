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

```sh
docker build -t ranking-api:v2-profiler ./app
kind load docker-image ranking-api:v2-profiler --name k8s-essentials
kubectl apply -f manifests/01-deployment-ranking-api-v2.yaml
```

```sh
kubectl get pods -n games -l app=ranking-api
# Aguarde READY = 1/1
```

Verifique que o SDK iniciou:
```sh
kubectl logs -n games -l app=ranking-api --tail=5
# Deve mostrar logs do uvicorn sem erros de conexão com o Pyroscope
```

---

## Etapa 4 — Gerar carga

```sh
# Em um terminal: port-forward
kubectl port-forward -n games svc/ranking-api 8000:80

# Em outro terminal: gerar requisições
# PowerShell:
for ($i = 0; $i -lt 100; $i++) {
  Invoke-RestMethod http://localhost:8000/rankings | Out-Null
  Invoke-RestMethod -Method Post http://localhost:8000/score `
    -ContentType "application/json" `
    -Body "{`"player`":`"jogador$i`",`"score`":$($i * 100)}" | Out-Null
  Start-Sleep -Milliseconds 100
}

# bash:
# for i in $(seq 1 100); do
#   curl -s http://localhost:8000/rankings > /dev/null
#   curl -s -X POST http://localhost:8000/score \
#     -H "Content-Type: application/json" \
#     -d "{\"player\":\"jogador$i\",\"score\":$((i*100))}" > /dev/null
#   sleep 0.1
# done
```

---

## Etapa 5 — Ver flame graphs no Grafana

1. **Grafana → Explore → Datasource: Grafana Pyroscope**
2. **Label filters:** `service_name = ranking-api`
3. **Profile type:** `process_cpu:cpu:nanoseconds:cpu:nanoseconds`
4. Intervalo: últimos 15 minutos → **Run query**

### Filtrar por endpoint (tag_wrapper)

Para ver apenas o perfil do `/rankings`:

- **Label filters:** `service_name = ranking-api` + `endpoint = /rankings`

Para comparar `/rankings` vs `/score`:

- Ative o modo **"Split"** no Grafana Explore
- Lado A: `endpoint = /rankings`
- Lado B: `endpoint = /score`

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
