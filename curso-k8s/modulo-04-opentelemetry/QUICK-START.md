# 🚀 Módulo 04 — Guia de Início Rápido

> ⚠️ **Todos os comandos deste guia devem ser executados de dentro da pasta `modulo-04-opentelemetry/`:**
>
> **PowerShell:**
> ```powershell
> cd curso-k8s/modulo-04-opentelemetry
> ```
> **bash / zsh:**
> ```bash
> cd curso-k8s/modulo-04-opentelemetry
> ```

## Pré-condição: Módulo 03 concluído

Prometheus, Grafana, Loki e Fluent Bit precisam estar rodando:

**PowerShell e bash:**

```sh
kubectl get pods -n monitoring
# Todos devem estar Running antes de continuar
```

Se já estiver tudo `Running`, pule direto para a **Etapa 1**.  
Se ainda não subiu o Módulo 03, siga a seção abaixo.

---

## Subindo o Módulo 03 do zero (cluster + monitoring stack completo)

> 🎯 **Cenário:** você pulou os módulos anteriores ou deletou o cluster e quer chegar no estado necessário para este módulo com um único bloco de comandos.

### Passo 1 — Recriar o cluster Kind com as portas do Módulo 03

**PowerShell e bash:**

```sh
# Deletar cluster anterior se existir (ignorar erro se não existir)
kind delete cluster --name k8s-essentials

# Recriar com o config do Módulo 03 (expõe portas do Prometheus, Grafana, etc.)
kind create cluster --config ../modulo-03-monitoring/manifests/cluster-config.yaml
```

### Passo 2 — Instalar o Metrics Server (necessário para o HPA)

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

> ⚠️ O patch é necessário porque o Kind usa certificados TLS autoassinados no kubelet. Sem ele o `kubectl top` falha e o HPA não consegue escalar. Não use em produção.

### Passo 3 — Instalar o Super Mario (Módulo 02)

**PowerShell e bash:**

```sh
kubectl create namespace games

kubectl apply -f ../modulo-02-deploy-app/manifests/01-deployment-mario.yaml
kubectl apply -f ../modulo-02-deploy-app/manifests/02-service-mario.yaml
kubectl apply -f ../modulo-02-deploy-app/manifests/03-hpa.yaml
```

### Passo 4 — Adicionar repositórios Helm

**PowerShell e bash:**

```sh
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update
```

### Passo 5 — Criar o namespace de monitoramento

**PowerShell e bash:**

```sh
kubectl create namespace monitoring
```

### Passo 6 — Instalar o kube-prometheus-stack (Prometheus + Grafana + Alertmanager)

**PowerShell:**

```powershell
helm install kind-prometheus prometheus-community/kube-prometheus-stack `
  --namespace monitoring `
  -f ../modulo-03-monitoring/helm-values/values-prometheus-stack.yaml
```

**bash / zsh:**

```bash
helm install kind-prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f ../modulo-03-monitoring/helm-values/values-prometheus-stack.yaml
```

### Passo 7 — Instalar o Loki (backend de logs)

**PowerShell:**

```powershell
helm install loki grafana/loki `
  --namespace monitoring `
  -f ../modulo-03-monitoring/helm-values/values-loki.yaml
```

**bash / zsh:**

```bash
helm install loki grafana/loki \
  --namespace monitoring \
  -f ../modulo-03-monitoring/helm-values/values-loki.yaml
```

### Passo 8 — Instalar o Fluent Bit (agente de coleta de logs)

**PowerShell:**

```powershell
helm install fluent-bit fluent/fluent-bit `
  --namespace monitoring `
  -f ../modulo-03-monitoring/helm-values/values-fluent-bit.yaml
```

**bash / zsh:**

```bash
helm install fluent-bit fluent/fluent-bit \
  --namespace monitoring \
  -f ../modulo-03-monitoring/helm-values/values-fluent-bit.yaml
```

### Passo 9 — Aguardar toda a stack subir

**PowerShell e bash:**

```sh
kubectl get pods -n monitoring -w
```

Estado esperado (todos `Running`):

```
alertmanager-kind-prometheus-kube-prome-alertmanager-0   2/2   Running
kind-prometheus-grafana-xxxx                             3/3   Running
kind-prometheus-kube-prome-operator-xxxx                 1/1   Running
kind-prometheus-kube-state-metrics-xxxx                  1/1   Running
kind-prometheus-prometheus-node-exporter-xxxx            1/1   Running
prometheus-kind-prometheus-kube-prome-prometheus-0       2/2   Running
loki-0                                                   1/1   Running
loki-gateway-xxxx                                        1/1   Running
fluent-bit-xxxx                                          1/1   Running
```

Ou aguardar tudo de uma vez:

**PowerShell:**

```powershell
kubectl wait --for=condition=ready pod `
  --selector=app.kubernetes.io/instance=kind-prometheus `
  --namespace monitoring `
  --timeout=300s
```

**bash / zsh:**

```bash
kubectl wait --for=condition=ready pod \
  --selector=app.kubernetes.io/instance=kind-prometheus \
  --namespace monitoring \
  --timeout=300s
```

> ✅ Com a stack de monitoring no ar, volte ao início deste guia e siga a partir da **Etapa 1**.

### Passo 10 — Recuperar a senha admin do Grafana

O Grafana é instalado com senha gerada automaticamente e armazenada em um Secret do Kubernetes.

**PowerShell:**

```powershell
kubectl --namespace monitoring get secret kind-prometheus-grafana `
  -o jsonpath="{.data.admin-password}" |
  ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
```

**bash / zsh:**

```bash
kubectl --namespace monitoring get secret kind-prometheus-grafana \
  -o jsonpath="{.data.admin-password}" | base64 --decode
```

> 💡 Login padrão: usuário `admin`, senha retornada pelo comando acima.  
> Acesse o Grafana em **http://localhost:3000**

---

## Etapa 1: Instalar o Grafana Tempo

O Tempo é o backend de traces. Ele recebe spans do OTel Collector e os armazena para consulta no Grafana.

**PowerShell e bash:**

```sh
# Repositório Grafana já foi adicionado no Módulo 03
# Se não foi: helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

**PowerShell e bash:**

```sh
helm install tempo grafana/tempo \
  --namespace monitoring \
  -f helm-values/values-tempo.yaml
```

> As configurações do Tempo estão em [helm-values/values-tempo.yaml](./helm-values/values-tempo.yaml):
> - `backend: local` — armazena traces em PVC (suficiente para Kind)
> - `grpc: 0.0.0.0:4317` — porta que o OTel Collector usa para enviar traces
> - `http: 0.0.0.0:4318` — porta alternativa OTLP/HTTP

Verificar:

**PowerShell e bash:**

```sh
kubectl get pods -n monitoring | grep tempo
# tempo-0   1/1   Running   0
```

---

## Etapa 2: Adicionar Tempo e Loki como datasources no Grafana

### O que são datasources no Grafana?

O Grafana é uma camada de **visualização** — ele não armazena dados. Os **datasources** dizem ao Grafana onde buscar cada tipo de dado:

| Datasource | O que armazena | Protocolo de consulta |
|---|---|---|
| Prometheus | Métricas (séries temporais) | PromQL |
| Loki | Logs | LogQL |
| Tempo | Traces distribuídos | TraceQL |

Após esta etapa, o Grafana terá acesso a todos os três sinais de observabilidade da Ranking API.

### Por que configurar a ligação Tempo → Loki?

Esta é a feature de **Trace to logs**: ao visualizar um trace no Tempo e clicar em "Logs for this span", o Grafana abre automaticamente o Loki com o filtro correto e o time range ajustado para aquele span exato.

Para isso funcionar, o Grafana precisa saber:
1. **Qual datasource Loki** usar para buscar os logs
2. **Qual atributo do span** usar para montar o seletor de labels no Loki

### Por que `service.name`?

`service.name` é uma **convenção semântica do OpenTelemetry** (OTel Semantic Conventions). Todo dado emitido por uma aplicação instrumentada com OTel carrega um conjunto de metadados chamado **resource** — informações sobre a origem dos dados. `service.name` é o atributo padrão que identifica o serviço.

No deployment da Ranking API, definimos:
```yaml
OTEL_SERVICE_NAME: "ranking-api"
```

Isso faz com que **todos os spans, métricas e logs** da aplicação carreguem o atributo `service.name = "ranking-api"`. Quando o Grafana precisa encontrar os logs de um trace, ele lê esse atributo do span e busca no Loki.

### Por que a sintaxe `service.name as service_name`?

Há uma **incompatibilidade de nomenclatura** entre os dois sistemas:

- **OTel** usa ponto como separador hierárquico: `service.name`, `http.target`, `db.system`
- **Loki** não aceita ponto em nomes de labels (é reservado para o parser) — usa underscore: `service_name`

O OTel Collector já resolve isso automaticamente ao enviar logs para o Loki: converte `service.name` → `service_name`. Mas o Grafana precisa saber que, ao montar a query no Loki, deve usar `service_name` (com underscore), não `service.name` (com ponto).

A sintaxe `service.name as service_name` é exatamente essa instrução:
- **Esquerda do `as`**: nome do atributo no span (OTel)
- **Direita do `as`**: nome do label no Loki

Sem esse mapeamento, o Grafana geraria `{service.name="ranking-api"}`, que o Loki rejeita com `parse error: unexpected .`.

---

Antes de configurar, verifique o serviço do Tempo para confirmar a porta real:

**PowerShell e bash:**

```sh
kubectl get svc -n monitoring | grep tempo
# NAME    TYPE        CLUSTER-IP      PORT(S)
# tempo   ClusterIP   10.96.x.x       3200/TCP, 4317/TCP, 4318/TCP, ...
```

> ⚠️ Se o `Save & Test` do Tempo retornar `i/o timeout`, o pod pode estar em `Pending`. Verifique com `kubectl get pods -n monitoring | grep tempo`.

### Adicionar Loki

```
http://localhost:3000
→ Connections → Data Sources → Add data source → Loki
→ URL: http://loki-gateway.monitoring.svc.cluster.local
→ Save & Test
```

> ✅ O Loki não precisa de autenticação (instalado com `auth_enabled=false`). O `Save & Test` deve retornar sucesso imediato.

### Adicionar Tempo

```
http://localhost:3000
→ Connections → Data Sources → Add data source → Tempo
→ URL: http://tempo.monitoring.svc.cluster.local:3200
Em "Trace to logs":
  Data source: Loki
  Tags → service.name as service_name
→ Save & Test
```

---

## Etapa 3: Instalar o OTel Collector

O Collector recebe traces, métricas e logs das aplicações e distribui para Tempo, Prometheus e Loki.

**PowerShell e bash:**

```sh
kubectl create namespace otel

kubectl apply -f manifests/03-otel-collector.yaml

# PodMonitor: instrui o Prometheus a fazer scrape das métricas do Collector
kubectl apply -f manifests/04-podmonitor-otel-collector.yaml

# Verificar
kubectl get pods -n otel
# otel-collector-xxxx   1/1   Running   0

kubectl get podmonitor -n monitoring
# NAME             AGE
# otel-collector   10s
```

---

## Etapa 4: Build da Ranking API

A Ranking API é a aplicação instrumentada com OTel SDK. Precisamos fazer o build da imagem e carregá-la no Kind.

**PowerShell e bash:**

```sh
# Entrar na pasta da aplicação
cd app

# Build da imagem Docker
docker build -t ranking-api:latest .

# Carregar a imagem no cluster Kind
kind load docker-image ranking-api:latest --name k8s-essentials

# Voltar para a raiz do módulo
cd ..```
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
kubectl apply -f manifests/01-deployment-ranking-api.yaml
kubectl apply -f manifests/02-service-ranking-api.yaml

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

## Etapa 8: Explorando traces no Grafana Tempo

### O que são traces e spans?

Um **trace** representa o caminho completo de uma requisição através do sistema, do início ao fim. Ele é composto por **spans** — cada span é uma unidade de trabalho individual dentro daquele trace.

Por exemplo, uma requisição `POST /score` na Ranking API gera este trace:

```
POST /score ────────────────────────────────────── 35ms  ← span raiz (trace inteiro)
  ├── validate-score ──── 0.5ms                          ← validação do input
  ├── db-read ───────────────── 10ms                     ← leitura do score atual
  └── db-write ────────────────────── 12ms               ← escrita do novo score
```

O Grafana exibe isso como um **waterfall** (cascata): cada linha é um span, a largura da barra representa a duração, e a cor indica o status (verde = OK, vermelho = ERROR).

Ao clicar em um span, o painel lateral mostra:
- **Atributos do span**: dados definidos pela aplicação no código (e.g., `player.name`, `db.statement`)
- **Resource attributes**: metadados da origem (e.g., `service.name`, `deployment.environment`)
- **Status e mensagem de erro**: quando o span falhou

### O que é TraceQL?

TraceQL é a linguagem de query do Tempo, assim como PromQL é do Prometheus e LogQL é do Loki. A sintaxe básica é `{ condições }`.

Existem dois namespaces de atributos:

**`resource.*`** — atributos do **resource** (metadados da origem dos dados, definidos no `OTEL_SERVICE_NAME` e `OTEL_RESOURCE_ATTRIBUTES`):
```
resource.service.name        → nome do serviço ("ranking-api")
resource.deployment.environment → ambiente ("kind-dev")
```

**`span.*`** — atributos do **span individual** (definidos no código da aplicação):
```
span.http.target       → path da requisição HTTP ("/score", "/rankings")
span.http.status_code  → código de resposta (200, 400, 404)
span.db.operation      → operação no banco ("SELECT", "upsert")
span.db.system         → sistema de banco ("postgresql")
```

**Campos intrínsecos** (sem prefixo):
```
duration   → duração do span (ex: > 100ms)
status     → ok | error | unset
name       → nome do span ("submit-score", "db-read")
```

### Queries úteis (TraceQL)

```
http://localhost:3000
→ Explore
→ Datasource: Tempo

# Todos os traces da Ranking API
{ resource.service.name = "ranking-api" }

# Traces com erro (spans marcados como ERROR)
{ resource.service.name = "ranking-api" && status = error }

# Traces lentos — útil para identificar gargalos (use o endpoint /slow)
{ resource.service.name = "ranking-api" && duration > 100ms }

# Traces de um endpoint específico
{ span.http.target = "/rankings" }

# Spans de operação no banco
{ span.db.operation = "upsert" }
```

> 💡 Para abrir o waterfall de um trace, clique em qualquer linha da lista de resultados. Para ver os atributos de um span específico, clique na barra daquele span no waterfall.

---

## Etapa 9: Explorando métricas no Prometheus

### Como as métricas chegam ao Prometheus

O fluxo de métricas é diferente do de traces e logs:

```
Ranking API ──OTLP/gRPC──► OTel Collector ──expõe :8889/metrics──► Prometheus (scrape a cada 15s)
```

A Ranking API envia métricas via OTLP para o Collector. O Collector as converte para o formato Prometheus e expõe no endpoint `:8889/metrics`. O Prometheus, por sua vez, faz **scrape** — coleta periódica nesse endpoint.

O **PodMonitor** aplicado na Etapa 3 é o objeto Kubernetes que informa ao Prometheus Operator onde fazer esse scrape: "vá buscar métricas nos pods com label `app: otel-collector` no namespace `otel`, na porta `8889`."

### Por que as métricas têm esses nomes?

As métricas customizadas da Ranking API são definidas no código com nomes simples. Ao passar pelo pipeline OTel → Prometheus, ganham sufixos padrão:

| Tipo OTel | Sufixo adicionado pelo Prometheus | Nome final |
|---|---|---|
| `Counter` | `_total` | `scores_submitted_total`, `api_errors_total` |
| `Histogram` | `_count`, `_sum`, `_bucket` | `http_server_duration_milliseconds_count` |
| `Gauge` | nenhum | — |

Além dos nomes, cada métrica carrega **labels** que identificam a origem. Elas vêm dos resource attributes do OTel, graças ao `resource_to_telemetry_conversion: enabled: true` configurado no Collector:

```
service_name="ranking-api"           ← OTEL_SERVICE_NAME
deployment_environment="kind-dev"    ← OTEL_RESOURCE_ATTRIBUTES
```

### Queries PromQL explicadas

```
http://localhost:9090 → Graph

# Total acumulado de scores submetidos desde que o pod iniciou
scores_submitted_total

# Taxa de erros por segundo nos últimos 5 minutos
# rate() calcula a variação por segundo de um contador em uma janela de tempo
rate(api_errors_total[5m])

# Número de requisições HTTP por segundo, por endpoint
# http_server_duration é um histograma — _count conta requisições; sem _sum ou _bucket
rate(http_server_duration_milliseconds_count{service_name="ranking-api"}[5m])

# Confirma que o Prometheus está coletando métricas do OTel Collector
# up=1 significa target acessível; up=0 significa falha no scrape
up{job="monitoring/otel-collector"}
```

> 💡 `api_errors_total` só aparece após pelo menos um erro ser gerado — contadores com valor zero não são emitidos. Gere um erro com `POST /score` usando `score: -999`.
>
> ⚠️ Se as métricas não aparecerem, aguarde ~30s para o primeiro scrape e verifique em **http://localhost:9090 → Status → Targets** — o target `monitoring/otel-collector` deve estar `UP`.

---

## Etapa 10: Correlacionando Traces → Logs

### O modelo de dados do Loki

Antes de fazer qualquer query, é importante entender como o Loki organiza os logs. Ele tem dois níveis:

**Stream labels** — indexados, usados para selecionar quais séries de logs buscar:
```
{service_name="ranking-api", level="ERROR"}
```
Labels são definidos na ingestão e ficam no índice. Buscar por label é barato e rápido.

**Log body** — o conteúdo do log em si, não indexado por padrão:
```json
{"message": "Score inválido recebido", "player": "hacker", "score": -999, "traceID": "abc123..."}
```
Filtrar pelo body requer varredura (`|=`, `| json`, `| regexp`). Mais custoso, mas permite qualquer filtro.

### De onde vêm os labels no Loki?

Os logs da Ranking API chegam ao Loki pelo caminho: **OTel SDK → OTel Collector → Loki exporter**.

No arquivo `03-otel-collector.yaml`, o processor `resource` define quais resource attributes do OTel serão promovidos a **stream labels** no Loki:

```yaml
resource:
  attributes:
  - action: insert
    key: loki.resource.labels
    value: service.name, deployment.environment, k8s.namespace.name
```

O OTel Loki exporter lê essa instrução e cria os labels (convertendo pontos em underscores):

| Resource attribute (OTel) | Label no Loki |
|---|---|
| `service.name = "ranking-api"` | `service_name="ranking-api"` |
| `deployment.environment = "kind-dev"` | `deployment_environment="kind-dev"` |

O Loki exporter também extrai automaticamente a severidade do log como label `level`:

| Severidade Python | Label Loki |
|---|---|
| `logging.INFO` | `level="INFO"` |
| `logging.WARNING` | `level="WARN"` |
| `logging.ERROR` | `level="ERROR"` |

O `traceID` **não é um label** — ele fica no corpo do log como campo JSON. Por isso, filtrar por `traceID` requer varredura com `| json`.

### O mecanismo de correlação Trace → Logs

Quando você clica em "Logs for this span" no Tempo, o Grafana faz duas coisas simultaneamente:

1. **Monta o seletor de labels**: lê o atributo `service.name` do span e converte para `{service_name="ranking-api"}` usando o mapeamento configurado na Etapa 2
2. **Ajusta o time range**: recorta a janela de tempo exatamente no período de duração daquele span

O resultado é: você vê apenas os logs daquele serviço no exato momento em que aquele trace aconteceu — sem precisar saber o `traceID` de antemão.

---

### Passo 1 — Gerar erros reais na API

A API tem dois endpoints que produzem spans com `status = error` e logs estruturados:

**Score negativo** (HTTP 400 — span ERROR + `logger.error` + incrementa `api_errors_total`):

**PowerShell:**
```powershell
Invoke-RestMethod -Method Post -Uri http://localhost:8082/score `
  -ContentType "application/json" `
  -Body '{"player": "hacker", "score": -999}'
```

**bash / zsh:**
```bash
curl -X POST http://localhost:8082/score \
  -H "Content-Type: application/json" \
  -d '{"player": "hacker", "score": -999}'
```

**Jogador inexistente** (HTTP 404 — span ERROR + `logger.warning` + incrementa `api_errors_total`):

**PowerShell:**
```powershell
Invoke-RestMethod http://localhost:8082/score/jogador-que-nao-existe
```

**bash / zsh:**
```bash
curl http://localhost:8082/score/jogador-que-nao-existe
```

> ⚠️ Ambos os comandos retornam erro HTTP — isso é esperado. O importante é que o span ficou marcado com `status = error` e o log foi enviado ao Loki via OTel Collector.

### Passo 2 — Encontrar o trace com erro no Tempo

```
http://localhost:3000
→ Explore
→ Datasource: Tempo
→ Query TraceQL:

{ resource.service.name = "ranking-api" && status = error }

→ Run query
→ Clique em qualquer trace da lista para abrir o waterfall
→ Spans com erro aparecem em vermelho
```

### Passo 3 — Pular do trace para os logs

```
1. No waterfall, clique no span com erro (ex: "submit-score" ou "get-player-score")
2. No painel lateral, clique no ícone de log ao lado de "Logs for this span"
3. O Grafana abre o Loki Explore com:
   - Seletor:    {service_name="ranking-api"}
   - Time range: recortado para o intervalo exato do span
```

Você verá os logs gerados por aquela requisição específica, sem nenhum ruído de outros pods ou outros momentos.

> 💡 Se quiser ir além e filtrar pelo `traceID` exato (útil quando há muitas requisições simultâneas), copie o ID do trace no Tempo e adicione manualmente na query do Loki:
> ```
> {service_name="ranking-api"} | json | traceID = "cole-o-id-aqui"
> ```
> O `traceID` é injetado automaticamente no log pelo OTel SDK — basta expandir qualquer linha de log no Loki para vê-lo.

### Passo 4 — Explorar logs no Loki diretamente

```
http://localhost:3000
→ Explore
→ Datasource: Loki
→ Ajuste o time range para "Last 6 hours"

# Todos os logs da Ranking API (labels indexados → busca rápida)
{service_name="ranking-api"}

# Apenas erros — level é stream label, não precisa de | json
{service_name="ranking-api", level="ERROR"}

# Warnings — gerados pelo endpoint GET /score/{player} com jogador inexistente
{service_name="ranking-api", level="WARN"}

# Logs com traceID no body — para correlação manual com o Tempo
{service_name="ranking-api"} | json | traceID != ""
```

> ⚠️ "No logs volume available" é apenas o histograma de preview do volume — clique em **Run query** assim mesmo. Os logs existem no índice.

---

## Limpar o ambiente

**PowerShell e bash:**

```sh
# Remover a Ranking API
kubectl delete -f manifests/01-deployment-ranking-api.yaml
kubectl delete -f manifests/02-service-ranking-api.yaml

# Remover o OTel Collector
kubectl delete -f manifests/03-otel-collector.yaml
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
