# 🚀 Grafana Alloy — Guia de Início Rápido

> ⚠️ **Execute os comandos de dentro da pasta `modulo-05-profiler/grafana-alloy/`:**
>
> ```sh
> cd curso-k8s/modulo-05-profiler/grafana-alloy
> ```

## Diferença chave em relação ao pyroscope-sdk

**Não há nenhuma alteração na `ranking-api`.**  
Você usará a imagem `ranking-api:latest` do Módulo 04 exatamente como está.  
O Alloy perfilará o processo Python de fora, via eBPF.

## Pré-condição

Stack dos módulos 03 e 04 rodando (Prometheus, Grafana, Loki, Tempo, OTel Collector, ranking-api).  
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

### Passo 3 — Stack de monitoramento + aplicações

```sh
kubectl create namespace games --dry-run=client -o yaml | kubectl apply -f -

# Super Mario (Módulo 02)
kubectl apply -f ../../modulo-02-deploy-app/manifests/01-deployment-mario.yaml
kubectl apply -f ../../modulo-02-deploy-app/manifests/02-service-mario.yaml

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

### Passo 4 — Deploy da ranking-api (versão original do Módulo 04 — sem modificações)

```sh
# Build da imagem original (se ainda não tiver)
docker build -t ranking-api:latest ../../modulo-04-opentelemetry/app
kind load docker-image ranking-api:latest --name k8s-essentials

kubectl apply -f ../../modulo-04-opentelemetry/manifests/01-deployment-ranking-api.yaml
kubectl apply -f ../../modulo-04-opentelemetry/manifests/02-service-ranking-api.yaml
```

```sh
kubectl get pods -n games
# Aguarde STATUS = Running para todos os pods
```

---

## Etapa 1 — Instalar o Pyroscope Server

```sh
helm install pyroscope grafana/pyroscope \
  --namespace monitoring \
  --create-namespace \
  -f helm-values/values-pyroscope.yaml
```

```sh
kubectl get pods -n monitoring -l app.kubernetes.io/name=pyroscope
# Aguarde STATUS = Running
```

> 🌐 Pyroscope UI: **http://localhost:4040** (sem autenticação em dev)

---

## Etapa 2 — Instalar o Grafana Alloy (DaemonSet com eBPF)

```sh
helm install alloy grafana/alloy \
  --namespace monitoring \
  --create-namespace \
  -f helm-values/values-alloy.yaml
```

```sh
kubectl get pods -n monitoring -l app.kubernetes.io/name=alloy
# Deve mostrar 1 pod por nó do cluster (DaemonSet)
# KIND tem 2 nós (control-plane + worker) = 2 pods do Alloy
```

### Verificar que o Alloy está enviando profiles

```sh
kubectl logs -n monitoring -l app.kubernetes.io/name=alloy --tail=30
# Procure por linhas como:
#   component=pyroscope.ebpf  msg="profiling started"
#   component=pyroscope.write msg="profiles sent"
```

---

## Etapa 3 — Adicionar Pyroscope como datasource no Grafana

1. Acesse **http://localhost:3000** (admin / prom-operator)
2. **Connections → Data sources → Add new data source**
3. Selecione **"Grafana Pyroscope"**
4. URL: `http://pyroscope.monitoring.svc.cluster.local:4040`
5. **Save & test**

---

## Etapa 4 — Gerar carga para criar profiles

O eBPF captura apenas quando o processo está usando CPU.  
Gere tráfego para ver frames relevantes no flame graph:

```sh
# Port-forward da ranking-api
kubectl port-forward -n games svc/ranking-api 8000:80
```

```sh
# PowerShell — gerar carga em loop
for ($i = 0; $i -lt 200; $i++) {
  Invoke-RestMethod http://localhost:8000/rankings | Out-Null
  Invoke-RestMethod -Method Post http://localhost:8000/score `
    -ContentType "application/json" `
    -Body "{`"player`":`"jogador$i`",`"score`":$($i * 100)}" | Out-Null
  Start-Sleep -Milliseconds 50
}
```

```sh
# bash
# for i in $(seq 1 200); do
#   curl -s http://localhost:8000/rankings > /dev/null
#   curl -s -X POST http://localhost:8000/score \
#     -H "Content-Type: application/json" \
#     -d "{\"player\":\"jogador$i\",\"score\":$((i*100))}" > /dev/null
#   sleep 0.05
# done
```

---

## Etapa 5 — Ver flame graphs no Grafana

1. **Grafana → Explore → Datasource: Grafana Pyroscope**
2. **Label filters:** `service_name = ranking-api`
3. **Profile type:** `process_cpu:cpu:nanoseconds:cpu:nanoseconds`
4. Intervalo: últimos 15 minutos → **Run query**

### Diferença visível em relação ao SDK

Com o Alloy você verá o **processo inteiro** da `ranking-api` no flame graph — todos os endpoints misturados. Não há como separar `/rankings` de `/score` com filtros (pois não há `tag_wrapper`).

```
Flame graph com Alloy (processo inteiro):
  uvicorn.worker        [███████████████████████ 100%]
    ranking_api         [████████████████████    80%]
      get_rankings      [████████████   55%]
      submit_score      [██████         25%]
    asyncio             [████            20%]

Flame graph com SDK (tag_wrapper endpoint=/rankings):
  ranking_api.get_rankings  [████████████████ 100%]  ← apenas este endpoint
```

### Ver outros serviços do cluster

O Alloy perfilará **todos** os pods automaticamente.  
Experimente trocar o label para ver outros serviços:

- `service_name = super-mario` (se o label `app=super-mario` existir)
- Deixar sem filtro → verá todos os processos do nó incluindo kernel space

---

## Comparando as duas abordagens na prática

```sh
# Verificar se um pod foi descoberto pelo Alloy
kubectl logs -n monitoring -l app.kubernetes.io/name=alloy | grep "ranking-api"

# Ver todos os labels que o Alloy está enviando para o Pyroscope
# http://localhost:4040 → clique em "Labels" no menu lateral
```

---

## Resumo dos endpoints

| Serviço      | URL                   | Credenciais            |
|--------------|-----------------------|------------------------|
| Grafana      | http://localhost:3000 | admin / prom-operator  |
| Pyroscope UI | http://localhost:4040 | sem autenticação       |
| Prometheus   | http://localhost:9090 | sem autenticação       |
| ranking-api  | http://localhost:8000 | via port-forward       |

---

## Troubleshooting

### Alloy em CrashLoopBackOff

O eBPF requer `privileged: true`. Verifique:
```sh
kubectl describe pod -n monitoring -l app.kubernetes.io/name=alloy | grep -A5 "Security Context"
```

O `values-alloy.yaml` já inclui `privileged: true`. Se ainda falhar, verifique a versão do kernel do Kind:
```sh
docker exec k8s-essentials-worker uname -r
# Deve ser >= 4.9 para eBPF básico, >= 5.8 para BPF CO-RE (melhor suporte)
```

### Nenhum perfil aparece no Grafana

Aguarde pelo menos **30 segundos** após instalar o Alloy — o DaemonSet leva alguns segundos para inicializar os programas eBPF. Verifique também se há carga na aplicação (eBPF só captura quando há uso de CPU).
