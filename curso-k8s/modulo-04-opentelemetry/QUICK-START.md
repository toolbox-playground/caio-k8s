# 🚀 Módulo 04 — Guia de Início Rápido

## Pré-condição: Módulo 03 concluído

Prometheus, Grafana, Loki e Fluent Bit precisam estar rodando:

**PowerShell e bash:**

```sh
kubectl get pods -n monitoring
# Todos devem estar Running antes de continuar
```

---

## Etapa 1: Instalar o Grafana Tempo

O Tempo é o backend de traces. Ele recebe spans do OTel Collector e os armazena para consulta no Grafana.

**PowerShell e bash:**

```sh
# Repositório Grafana já foi adicionado no Módulo 03
# Se não foi: helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

**PowerShell:**

```powershell
helm install tempo grafana/tempo `
  --namespace monitoring `
  --set tempo.storage.trace.backend=local `
  --set tempo.storage.trace.local.path=/var/tempo/traces `
  --set tempo.receivers.otlp.protocols.grpc.endpoint=0.0.0.0:4317 `
  --set tempo.receivers.otlp.protocols.http.endpoint=0.0.0.0:4318
```

**bash / zsh:**

```bash
helm install tempo grafana/tempo \
  --namespace monitoring \
  --set tempo.storage.trace.backend=local \
  --set tempo.storage.trace.local.path=/var/tempo/traces \
  --set tempo.receivers.otlp.protocols.grpc.endpoint=0.0.0.0:4317 \
  --set tempo.receivers.otlp.protocols.http.endpoint=0.0.0.0:4318
```

Verificar:

**PowerShell e bash:**

```sh
kubectl get pods -n monitoring | grep tempo
# tempo-0   1/1   Running   0
```

---

## Etapa 2: Adicionar Tempo como datasource no Grafana

```
http://localhost:3000
→ Connections → Data Sources → Add data source → Tempo
→ URL: http://tempo.monitoring.svc.cluster.local:3100
→ Save & Test
```

Ativar correlação Trace → Logs (opcional mas recomendado):
```
Em "Trace to logs":
  Data source: Loki
  Tags: service.name, pod
```

---

## Etapa 3: Instalar o OTel Collector

O Collector recebe traces, métricas e logs das aplicações e distribui para Tempo, Prometheus e Loki.

**PowerShell e bash:**

```sh
kubectl create namespace otel

kubectl apply -f manifests/k8s/03-otel-collector.yaml

# Verificar
kubectl get pods -n otel
# otel-collector-xxxx   1/1   Running   0
```

---

## Etapa 4: Build da Ranking API

A Ranking API é a aplicação instrumentada com OTel SDK. Precisamos fazer o build da imagem e carregá-la no Kind.

**PowerShell e bash:**

```sh
# Entrar na pasta da aplicação
cd manifests/app

# Build da imagem Docker
docker build -t ranking-api:latest .

# Carregar a imagem no cluster Kind
kind load docker-image ranking-api:latest --name k8s-essentials

# Voltar para a raiz do módulo
cd ../..
```

Verificar que a imagem foi carregada:

**PowerShell e bash:**

```sh
docker exec k8s-essentials-control-plane crictl images | grep ranking-api
```

---

## Etapa 5: Deploy da Ranking API

**PowerShell e bash:**

```sh
kubectl apply -f manifests/k8s/01-deployment-ranking-api.yaml
kubectl apply -f manifests/k8s/02-service-ranking-api.yaml

# Aguardar pods ficarem Ready
kubectl wait --for=condition=ready pod \
  --selector=app=ranking-api \
  --namespace games \
  --timeout=120s

# Verificar
kubectl get pods -n games
```

---

## Etapa 6: Testar a API

**PowerShell e bash:**

```sh
# Port-forward para testar localmente
kubectl port-forward svc/ranking-api -n games 8082:80
```

Em outro terminal:

**PowerShell:**

```powershell
# Health check
Invoke-RestMethod http://localhost:8082/health

# Listar rankings
Invoke-RestMethod http://localhost:8082/rankings

# Submeter pontuação
Invoke-RestMethod -Method Post -Uri http://localhost:8082/score `
  -ContentType "application/json" `
  -Body '{"player": "caio", "score": 15000}'

# Buscar jogador
Invoke-RestMethod http://localhost:8082/score/caio

# Endpoint lento (gera trace interessante)
Invoke-RestMethod http://localhost:8082/slow
```

**bash / zsh:**

```bash
# Health check
curl http://localhost:8082/health

# Listar rankings
curl http://localhost:8082/rankings

# Submeter pontuação
curl -X POST http://localhost:8082/score \
  -H "Content-Type: application/json" \
  -d '{"player": "caio", "score": 15000}'

# Buscar jogador
curl http://localhost:8082/score/caio

# Endpoint lento (gera trace interessante)
curl http://localhost:8082/slow
```

---

## Etapa 7: Gerar carga para traces ricos

**PowerShell:**

```powershell
# Gerar múltiplas requisições para popular o Tempo com traces variados
for ($i = 1; $i -le 20; $i++) {
    Invoke-RestMethod http://localhost:8082/rankings | Out-Null
    Invoke-RestMethod -Method Post -Uri http://localhost:8082/score `
        -ContentType "application/json" `
        -Body "{`"player`": `"jogador$i`", `"score`": $(Get-Random -Minimum 100 -Maximum 9999)}" | Out-Null
}
Write-Host "20 requisições enviadas. Abra o Grafana Tempo para ver os traces."
```

**bash / zsh:**

```bash
# Gerar múltiplas requisições para popular o Tempo com traces variados
for i in $(seq 1 20); do
  curl -s http://localhost:8082/rankings > /dev/null
  curl -s -X POST http://localhost:8082/score \
    -H "Content-Type: application/json" \
    -d "{\"player\": \"jogador$i\", \"score\": $((RANDOM % 9999 + 100))}" > /dev/null
done
echo "20 requisições enviadas. Abra o Grafana Tempo para ver os traces."
```

---

## Etapa 8: Ver traces no Grafana Tempo

```
http://localhost:3000
→ Explore
→ Datasource: Tempo

Queries úteis (TraceQL):

# Todos os traces da Ranking API
{ resource.service.name = "ranking-api" }

# Traces lentos (> 100ms)
{ resource.service.name = "ranking-api" && duration > 100ms }

# Apenas erros
{ resource.service.name = "ranking-api" && status = error }

# Traces do endpoint /rankings
{ span.http.target = "/rankings" }

# Span de escrita no banco
{ span.db.operation = "upsert" }
```

---

## Etapa 9: Ver métricas da aplicação no Grafana

As métricas customizadas (`scores_submitted_total`, `api_errors_total`) são enviadas pelo OTel Collector para o Prometheus.

```
http://localhost:9090 → Graph:

# Total de scores submetidos
scores_submitted_total

# Taxa de erros da API (por minuto)
rate(api_errors_total[1m])

# Requisições HTTP por endpoint
rate(http_server_duration_count{job="ranking-api"}[5m])
```

---

## Etapa 10: Correlacionar Trace → Logs

1. No Grafana Explore → Tempo, clique em qualquer trace
2. Clique em um span com erro
3. Clique no botão **"Logs for this span"** (ícone de log)
4. O Grafana abre automaticamente o Loki com o `trace_id` filtrado

Você verá os logs daquele pod exatamente no momento daquele trace.

---

## Limpar o ambiente

**PowerShell e bash:**

```sh
# Remover a Ranking API
kubectl delete -f manifests/k8s/01-deployment-ranking-api.yaml
kubectl delete -f manifests/k8s/02-service-ranking-api.yaml

# Remover o OTel Collector
kubectl delete -f manifests/k8s/03-otel-collector.yaml
kubectl delete namespace otel

# Remover o Tempo
helm uninstall tempo -n monitoring

# Ou deletar o cluster inteiro
kind delete cluster --name k8s-essentials
```

---

## Resumo do que foi instalado

| Componente | Namespace | Função | Porta |
|---|---|---|---|
| Ranking API | games | App instrumentada com OTel SDK | 8082 (via port-forward) |
| OTel Collector | otel | Recebe OTLP, distribui para backends | 4317 (gRPC), 4318 (HTTP) |
| Grafana Tempo | monitoring | Armazena e consulta traces | 3100 (interno) |
| Prometheus | monitoring | Armazena métricas (Módulo 03) | 9090 |
| Loki | monitoring | Armazena logs (Módulo 03) | 3100 (interno) |
| Grafana | monitoring | Dashboard unificado | 3000 |
