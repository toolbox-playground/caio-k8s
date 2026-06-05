# Módulo 08 — High Cardinality e Otimização do Stack de Observabilidade

> *"Sexta-feira à noite. O Prometheus começa a consumir 14 GB de RAM e o
> pod é OOMKilled. Na manhã seguinte, o time descobre a causa: um
> desenvolvedor adicionou `request_id` como label de uma métrica HTTP.
> Cada requisição gerava uma série única. Em 24h, o Prometheus saiu de
> 500 mil para 48 milhões de séries ativas. O cluster inteiro ficou
> instável. Com conhecimento de high cardinality: problema detectado em
> 10 minutos, corrigido antes de atingir produção."*

---

## Onde estamos no curso

| Módulo | O que foi construído | Pilar |
|--------|---------------------|-------|
| 01 | Kind — cluster local | Infraestrutura |
| 02 | Deploy + HPA | Escalabilidade |
| 03 | Prometheus + Loki + Grafana + Alertas | Métricas + Logs |
| 04 | OpenTelemetry + Tempo | Traces |
| 05 | Pyroscope | Profiling |
| 06 | Grafana Mimir | Retenção longa |
| 07 | ArgoCD + GitOps | Entrega contínua |
| **08** | **High Cardinality + Otimização** | **Produção** |

Nos módulos anteriores, você construiu o stack de observabilidade peça
por peça. Agora vamos olhar para o **custo** de cada peça e aprender
a mantê-lo sob controle.

O problema de alta cardinalidade existe em **todos os componentes**
que você instalou:

```
Prometheus  → séries de alta cardinalidade    → OOMKill
Loki        → streams de alta cardinalidade   → índice gigante
Mimir       → ingestão sem limites            → rejeição silenciosa
Fluent Bit  → labels desnecessários           → custo de storage
```

Este módulo ensina a diagnosticar, corrigir e prevenir o problema em
cada camada — e deixa o stack pronto para produção.

---

## O Que é High Cardinality

**Cardinalidade** é o número de combinações únicas de labels que uma
métrica possui. Cada combinação única é chamada de **série temporal
(time series)**.

```
metric_name{label_a="valor1", label_b="valor2"} → 1 série
metric_name{label_a="valor1", label_b="valor3"} → 1 série
metric_name{label_a="valor2", label_b="valor2"} → 1 série
```

Se uma métrica tem 3 labels com 100 valores possíveis cada, ela pode
gerar até $100^3 = 1.000.000$ séries. Isso é **alta cardinalidade**.

### A Armadilha dos Labels Ilimitados

O Prometheus armazena cada série em memória e em disco. O custo não é
linear — a indexação de séries usa estruturas de dados que crescem
muito além do esperado com milhões de entradas.

| Situação | Séries típicas | Impacto |
|---|---|---|
| Cluster pequeno (10 pods) | 50k–200k | Normal, < 1 GB RAM |
| Cluster médio (100 pods) | 500k–2M | Atenção, 2–4 GB RAM |
| `request_id` como label | 10M–100M+ | OOMKill, cluster instável |
| `user_id` como label | depende dos usuários | Explosão de cardinalidade |
| `query_string` como label | infinito | Nunca fazer isso |

### Labels que Explodem vs. Labels que Não Explodem

```
✅ Labels de baixa cardinalidade (seguro):
   method="GET"         → ~5 valores (GET, POST, PUT, DELETE, PATCH)
   status_code="200"    → ~10 valores (200, 400, 404, 500...)
   namespace="games"    → ~10–50 namespaces
   pod="ranking-api-*"  → número fixo de pods

❌ Labels de alta cardinalidade (perigoso):
   request_id="abc123"  → 1 valor por requisição
   user_id="42"         → 1 valor por usuário (pode ser milhões)
   trace_id="..."       → infinito (use traces para isso)
   query="SELECT ..."   → infinito (use logs para isso)
   ip="192.168.1.x"     → pode ser milhares
```

> **Regra de ouro do Prometheus**: métricas medem *categorias*, não
> *eventos individuais*. Para rastrear itens únicos (usuários, requests,
> traces), use **logs** ou **traces** — não labels.

---

## Arquitetura do Problema

```
┌────────────────────────────────────────────────────────────────────┐
│  App com label `request_id`                                         │
│                                                                     │
│  http_requests_total{method="GET", request_id="abc123"}  ← série 1  │
│  http_requests_total{method="GET", request_id="def456"}  ← série 2  │
│  http_requests_total{method="GET", request_id="ghi789"}  ← série 3  │
│  ...                                                                │
│  1.000.000 requisições = 1.000.000 séries                           │
└──────────────────────────┬─────────────────────────────────────────┘
                           │ scrape a cada 15s
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Prometheus TSDB                                                     │
│                                                                     │
│  RAM: cada série ativa ocupa ~3–5 KB em memória (head chunk)        │
│  1M séries × 4 KB = 4 GB só para essa métrica                       │
│  10M séries × 4 KB = 40 GB → OOMKill                                │
└──────────────────────────┬──────────────────────────────────────────┘
                           │ remote_write
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Grafana Mimir                                                       │
│                                                                     │
│  max_global_series_per_user: 1.500.000  ← rejeita se ultrapassar    │
│  max_global_series_per_metric: 50.000   ← por métrica               │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Fase 1 — Detectando High Cardinality

### 1.1 Verificando o Total de Séries Ativas

O Prometheus expõe métricas sobre si mesmo. A mais importante para
high cardinality é `prometheus_tsdb_head_series`:

```bash
# Total de séries no head (últimas horas)
curl -s http://localhost:9090/api/v1/query \
  --data-urlencode 'query=prometheus_tsdb_head_series' | jq .
```

No Grafana, execute via PromQL:

```promql
# Séries ativas no momento
prometheus_tsdb_head_series

# Tendência das últimas 6 horas
rate(prometheus_tsdb_head_series_created_total[6h])
```

**Thresholds de atenção**:

| Valor | Status |
|---|---|
| < 500.000 | Saudável |
| 500k – 2M | Atenção |
| > 2M | Investigar imediatamente |
| > 5M | Risco crítico de OOMKill |

### 1.2 Identificando as Métricas Problemáticas

A API do Prometheus retorna o número de séries por métrica:

```bash
# Top 20 métricas com mais séries (via TSDB status)
curl -s http://localhost:9090/api/v1/status/tsdb | \
  jq '.data.seriesCountByMetricName | sort_by(.count) | reverse | .[0:20]'
```

Saída esperada:
```json
[
  { "name": "http_requests_total", "count": 850000 },
  { "name": "grpc_server_handled_total", "count": 42000 },
  { "name": "go_gc_duration_seconds", "count": 1200 }
]
```

Se uma única métrica tem centenas de milhares de séries — ela é a culpada.

### 1.3 Identificando os Labels Problemáticos

Para saber quais labels de uma métrica explodem:

```bash
# Cardinalidade de cada label de uma métrica específica
curl -s http://localhost:9090/api/v1/status/tsdb | \
  jq '.data.seriesCountByLabelValuePair | sort_by(.count) | reverse | .[0:20]'
```

No PromQL, você pode contar os valores únicos de um label:

```promql
# Quantos valores únicos o label "request_id" tem?
count(count by (request_id) (http_requests_total))

# Quantos valores únicos o label "pod" tem por namespace?
count by (namespace) (count by (namespace, pod) (kube_pod_info))
```

### 1.4 API TSDB Status — O Diagnóstico Completo

O endpoint `/api/v1/status/tsdb` é o raio-X do Prometheus:

```bash
curl -s http://localhost:9090/api/v1/status/tsdb | jq '.data | {
  headStats: .headStats,
  top_metrics: (.seriesCountByMetricName | sort_by(.count) | reverse | .[0:5]),
  top_labels: (.seriesCountByLabelValuePair | sort_by(.count) | reverse | .[0:5]),
  top_chunks: (.chunkCount | if . then . else "n/a" end)
}'
```

Campos importantes do `headStats`:

| Campo | O que significa |
|---|---|
| `numSeries` | Total de séries ativas |
| `chunkCount` | Chunks em memória (1 chunk ≈ 120 pontos) |
| `minTime` / `maxTime` | Janela de tempo coberta |
| `numLabelPairs` | Total de pares label=valor únicos |

### 1.5 Alertas Proativos para High Cardinality

Adicione essas regras ao seu `PrometheusRule`:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: high-cardinality-alerts
  namespace: monitoring
spec:
  groups:
    - name: cardinality
      interval: 5m
      rules:
        # Alerta quando total de séries cresce mais de 20% em 1h
        - alert: PrometheusHighCardinalityGrowth
          expr: |
            (
              prometheus_tsdb_head_series
              / prometheus_tsdb_head_series offset 1h
            ) > 1.20
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "Cardinalidade crescendo rapidamente"
            description: >
              O Prometheus tem {{ $value | humanizePercentage }} mais séries
              do que há 1 hora. Verifique novos deployments com labels ruins.

        # Alerta quando total de séries passa de 2 milhões
        - alert: PrometheusCardinalityTooHigh
          expr: prometheus_tsdb_head_series > 2000000
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Cardinalidade crítica: {{ $value | humanize }} séries"
            description: >
              O Prometheus está com mais de 2M de séries ativas.
              Risco de OOMKill. Execute diagnóstico imediatamente.

        # Alerta quando o scrape demora mais do que o intervalo
        - alert: PrometheusScrapeSlowness
          expr: |
            scrape_duration_seconds > scrape_interval_seconds * 0.8
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Scrape lento em {{ $labels.job }}"
            description: >
              O job {{ $labels.job }} está demorando
              {{ $value | humanizeDuration }} por scrape.
```

---

## Fase 2 — Resolvendo High Cardinality

### 2.1 Estratégia 1: Dropar Labels na Coleta (metric_relabeling_configs)

A solução mais cirúrgica é remover o label problemático **durante o
scrape**, antes que ele chegue ao TSDB. Use `metric_relabeling_configs`
no `scrape_config`:

```yaml
# prometheus.yml ou values do kube-prometheus-stack
scrapeConfigs:
  - job_name: ranking-api
    static_configs:
      - targets: ['ranking-api:8080']
    metric_relabeling_configs:
      # Remove completamente o label "request_id"
      - action: labeldrop
        regex: request_id

      # Remove qualquer label que comece com "debug_"
      - action: labeldrop
        regex: debug_.*

      # Remove o label "user_id" apenas de uma métrica específica
      - source_labels: [__name__]
        regex: http_requests_total
        action: drop
        # Use junto com labeldrop em regra separada se precisar ser seletivo
```

Com o **kube-prometheus-stack** (PodMonitor / ServiceMonitor):

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: ranking-api
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: ranking-api
  endpoints:
    - port: metrics
      interval: 15s
      metricRelabelings:
        # Dropa o label request_id antes de gravar no TSDB
        - action: labeldrop
          regex: request_id

        # Dropa series inteiras com cardinalidade ilimitada
        - sourceLabels: [__name__, path]
          regex: 'http_requests_total;/api/v1/.*\?.*'
          action: drop
```

### 2.2 Estratégia 2: Dropar Séries Inteiras

Se uma métrica inteira é inútil e tem alta cardinalidade, descarte ela:

```yaml
metric_relabeling_configs:
  # Remove todas as métricas de debug do Go runtime
  - source_labels: [__name__]
    regex: 'go_memstats_.*|go_gc_.*'
    action: drop

  # Remove métricas de um path específico que gera muitas séries
  - source_labels: [__name__, handler]
    regex: 'http_request_duration_seconds;/health'
    action: drop
```

### 2.3 Estratégia 3: Agregar Labels com Recording Rules

Em vez de dropar, você pode **agregar** séries em granularidade menor,
preservando a utilidade da métrica:

```yaml
# prometheus-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: cardinality-reduction
  namespace: monitoring
spec:
  groups:
    - name: aggregations
      interval: 1m
      rules:
        # Agrega http_requests por method+status (sem path, sem pod)
        # De: N_pods × M_paths × K_status séries
        # Para: M_methods × K_status séries
        - record: job:http_requests_total:rate5m
          expr: |
            sum by (job, method, status_code) (
              rate(http_requests_total[5m])
            )

        # Agrega latência P99 por serviço (sem endpoint específico)
        - record: job:http_request_duration_seconds_p99:5m
          expr: |
            histogram_quantile(0.99,
              sum by (job, le) (
                rate(http_request_duration_seconds_bucket[5m])
              )
            )
```

### 2.4 Estratégia 4: sample_limit por Job

Adicione um limite de amostras por scrape para evitar que um único
target colapso o Prometheus:

```yaml
scrape_configs:
  - job_name: ranking-api
    # Falha o scrape inteiro se tiver mais de 10.000 amostras
    sample_limit: 10000
    static_configs:
      - targets: ['ranking-api:8080']
```

Com isso, se a cardinalidade explodir, o scrape falha com erro visível
em vez de silenciosamente destruir o Prometheus. Configure alertas para
`scrape_samples_post_metric_relabeling > 9000`.

---

## Fase 3 — Configurando Prometheus para Scraping Otimizado

### 3.1 Parâmetros Globais de Scrape

```yaml
# kube-prometheus-stack values.yaml
prometheus:
  prometheusSpec:
    # Intervalo global de coleta
    scrapeInterval: 30s          # padrão 1m, 15s para alta precisão
    scrapeTimeout: 10s           # nunca > scrapeInterval
    evaluationInterval: 30s      # avaliação de alertas

    # Limite global de amostras por scrape (0 = sem limite)
    sampleLimit: 0

    # Limite global de labels por sample
    labelLimit: 64

    # Limite de comprimento de nome de label
    labelNameLengthLimit: 256
    labelValueLengthLimit: 1024

    # Retenção local (antes do remote_write para Mimir)
    retention: 2h               # com Mimir, não precisa de retenção local longa
    retentionSize: "5GB"        # cap de disco

    # Recursos
    resources:
      requests:
        memory: 2Gi
        cpu: 500m
      limits:
        memory: 4Gi
        cpu: 2
```

### 3.2 Otimizando o remote_write para o Mimir

O `remote_write` é o canal entre Prometheus e Mimir. Configuração ruim
causa filas, atrasos e perda de dados:

```yaml
prometheus:
  prometheusSpec:
    remoteWrite:
      - url: "http://mimir-nginx.monitoring.svc.cluster.local/api/v1/push"

        # Identificação do tenant no Mimir (multi-tenancy)
        headers:
          X-Scope-OrgID: "default"

        # Fila de envio: buffer entre Prometheus e Mimir
        queueConfig:
          # Capacidade do buffer em memória
          capacity: 10000
          # Workers paralelos de envio
          maxShards: 200
          minShards: 1
          # Amostras por batch enviado
          maxSamplesPerSend: 2000
          # Espera máxima antes de enviar batch incompleto
          batchSendDeadline: 5s
          # Backoff em caso de erro
          minBackoff: 30ms
          maxBackoff: 5s
          # Retry em caso de erro 5xx (exceto 429 que já é respeitado)
          retryOnRateLimit: true

        # Compressão do payload (reduz bandwidth)
        writeRelabelConfigs:
          # Remove labels internos antes de enviar
          - regex: '__replica__'
            action: labeldrop

        # Timeout por request
        remoteTimeout: 30s

        # Metadados (nomes e tipos de métricas) — útil para Mimir
        sendExemplars: true
        sendNativeHistograms: false  # ative quando usar histogramas nativos
```

### 3.3 Configuração de Scrape por ServiceMonitor

Para targets Kubernetes, prefira `ServiceMonitor` ao `scrape_configs`
manual — ele é mais dinâmico e integrado ao Prometheus Operator:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: ranking-api-optimized
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: ranking-api
  namespaceSelector:
    matchNames:
      - games
  endpoints:
    - port: metrics
      path: /metrics
      interval: 15s
      scrapeTimeout: 10s

      # Limite de amostras para este endpoint específico
      sampleLimit: 5000

      # Relabeling antes do scrape (target-level)
      relabelings:
        # Mantém apenas pods Running
        - sourceLabels: [__meta_kubernetes_pod_phase]
          regex: Running
          action: keep

        # Renomeia label namespace para cluster_namespace
        - sourceLabels: [__meta_kubernetes_namespace]
          targetLabel: cluster_namespace
          action: replace

      # Relabeling das métricas (após scrape)
      metricRelabelings:
        # Remove métricas de liveness/readiness (muito frequentes, pouco úteis)
        - sourceLabels: [handler]
          regex: '/health|/ready|/live'
          action: drop

        # Normaliza valores de path com IDs dinâmicos
        # /api/v1/users/123 → /api/v1/users/:id
        - sourceLabels: [path]
          regex: '/api/v1/users/[0-9]+'
          targetLabel: path
          replacement: '/api/v1/users/:id'
          action: replace
```

---

## Fase 4 — Configurando Limites no Mimir

O Mimir tem um sistema de limites em duas camadas:
1. **Limites estáticos** no `values.yaml` do Helm
2. **Runtime config** aplicável sem reiniciar pods

### 4.1 Limites de Série por Tenant

```yaml
# helm-values/values-mimir.yaml
mimir:
  structuredConfig:
    limits:
      # Máximo de séries ativas por tenant (usuário/organização)
      max_global_series_per_user: 1500000

      # Máximo de séries por métrica (por tenant)
      # Previne que uma única métrica destrua o quota do tenant
      max_global_series_per_metric: 50000

      # Máximo de labels por série
      max_label_names_per_series: 30

      # Comprimento máximo de valor de label
      max_label_value_length: 1024

      # Taxa máxima de ingestão (amostras/segundo por tenant)
      ingestion_rate: 100000
      ingestion_burst_size: 200000

      # Janela de aceitação de dados fora de ordem (out-of-order)
      out_of_order_time_window: 5m
```

### 4.2 Limites do Ingester (instância)

```yaml
mimir:
  structuredConfig:
    ingester:
      # Limites por instância do ingester (não por tenant)
      instance_limits:
        # Máximo de séries em toda a instância
        max_series: 1500000
        # Taxa de ingestão máxima (amostras/s)
        max_ingestion_rate: 80000
        # Máximo de tenants por instância
        max_tenants: 1000
        # Requests de push simultâneos
        max_inflight_push_requests: 30000
```

### 4.3 Runtime Config — Ajuste Sem Downtime

O runtime config permite ajustar limites **sem reiniciar o Mimir**:

```yaml
# Crie um ConfigMap com o runtime config
apiVersion: v1
kind: ConfigMap
metadata:
  name: mimir-runtime-config
  namespace: monitoring
data:
  runtime.yaml: |
    ingester_limits:
      max_ingestion_rate: 120000   # sobe 50% temporariamente
      max_series: 2000000          # dobra para acomodar migração

    overrides:
      # Tenant com quota maior (ex: time de plataforma)
      platform-team:
        max_global_series_per_user: 5000000
        ingestion_rate: 500000

      # Tenant com restrição menor (ex: ambiente de dev)
      dev:
        max_global_series_per_user: 100000
        ingestion_rate: 10000
```

No `values.yaml` do Mimir, referencie o ConfigMap:

```yaml
mimir:
  structuredConfig:
    runtime_config:
      file: /etc/mimir/runtime.yaml
      period: 10s   # recarga automática a cada 10 segundos
```

### 4.4 Verificando Limites Ativos via PromQL

```promql
# Limite configurado de séries no ingester
cortex_ingester_instance_limits{limit="max_series"}

# Séries atualmente ativas no ingester
cortex_ingester_memory_series

# Percentual de uso do limite
cortex_ingester_memory_series
/ cortex_ingester_instance_limits{limit="max_series"}

# Requests rejeitados por limite de séries (deve ser 0 em normalidade)
rate(cortex_ingester_instance_limits_rejections_total[5m])

# Taxa de ingestão atual vs. limite
cortex_ingester_ingestion_rate_samples_per_second
/ cortex_ingester_instance_limits{limit="max_ingestion_rate"}
```

---

## Fase 5 — Otimizando o Scrape com Grafana Alloy

O **Grafana Alloy** (substituto do Prometheus Agent Mode) oferece
uma pipeline de coleta mais eficiente com processamento no edge:

```hcl
// alloy-config.alloy

// Descoberta de pods Kubernetes
discovery.kubernetes "pods" {
  role = "pod"
  namespaces {
    names = ["games", "monitoring"]
  }
}

// Relabeling: filtrar e normalizar antes do scrape
discovery.relabel "pod_relabel" {
  targets = discovery.kubernetes.pods.targets

  // Mantém apenas pods anotados para scrape
  rule {
    source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_scrape"]
    regex         = "true"
    action        = "keep"
  }

  // Define o path de métricas
  rule {
    source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_path"]
    regex         = "(.+)"
    target_label  = "__metrics_path__"
    action        = "replace"
  }

  // Define a porta de métricas
  rule {
    source_labels = ["__address__", "__meta_kubernetes_pod_annotation_prometheus_io_port"]
    regex         = "([^:]+)(?::[0-9]+)?;([0-9]+)"
    replacement   = "$1:$2"
    target_label  = "__address__"
    action        = "replace"
  }

  // Adiciona metadados úteis como labels
  rule {
    source_labels = ["__meta_kubernetes_namespace"]
    target_label  = "namespace"
    action        = "replace"
  }

  rule {
    source_labels = ["__meta_kubernetes_pod_name"]
    target_label  = "pod"
    action        = "replace"
  }
}

// Scrape com limite de amostras
prometheus.scrape "kubernetes_pods" {
  targets         = discovery.relabel.pod_relabel.output
  forward_to      = [prometheus.relabel.drop_high_cardinality.receiver]
  scrape_interval = "15s"
  scrape_timeout  = "10s"
}

// Filtragem de alta cardinalidade no pipeline
prometheus.relabel "drop_high_cardinality" {
  forward_to = [prometheus.remote_write.mimir.receiver]

  // Remove labels problemáticos de qualquer métrica
  rule {
    action = "labeldrop"
    regex  = "request_id|trace_id|user_id|session_id"
  }

  // Remove métricas de saúde e probe (scrape frequente, pouco valor)
  rule {
    source_labels = ["__name__"]
    regex         = "probe_.*|up"
    action        = "drop"
  }
}

// Envio para Mimir
prometheus.remote_write "mimir" {
  endpoint {
    url = "http://mimir-nginx.monitoring.svc.cluster.local/api/v1/push"

    headers = {
      "X-Scope-OrgID" = "default",
    }

    queue_config {
      capacity              = 10000
      max_shards            = 50
      max_samples_per_send  = 2000
      batch_send_deadline   = "5s"
    }
  }
}
```

---

## Fase 6 — Laboratório Prático

### Cenário

Você vai simular um problema de high cardinality adicionando um label
ruim à `ranking-api`, detectar o problema via PromQL, e corrigi-lo
com `metric_relabeling_configs`.

### Pré-requisitos

- Cluster do módulo 06 (Mimir) ou módulo 07 (ArgoCD) rodando
- Prometheus + Mimir instalados no namespace `monitoring`

### Passo 1 — Verificar Baseline

```bash
# Quantas séries o Prometheus tem agora?
kubectl -n monitoring exec -it \
  $(kubectl -n monitoring get pod -l app.kubernetes.io/name=prometheus -o name | head -1) \
  -- wget -qO- 'http://localhost:9090/api/v1/query?query=prometheus_tsdb_head_series' \
  | python3 -m json.tool

# Top 5 métricas em séries
kubectl -n monitoring exec -it \
  $(kubectl -n monitoring get pod -l app.kubernetes.io/name=prometheus -o name | head -1) \
  -- wget -qO- 'http://localhost:9090/api/v1/status/tsdb' \
  | python3 -c "
import json,sys
d=json.load(sys.stdin)
top=sorted(d['data']['seriesCountByMetricName'],key=lambda x:x['count'],reverse=True)[:5]
for m in top: print(f\"{m['count']:>10,}  {m['name']}\")
"
```

### Passo 2 — Injetar Alta Cardinalidade (Simulação)

Crie um deployment que gera métricas com `request_id` como label:

```yaml
# manifests/01-high-cardinality-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bad-metrics-app
  namespace: games
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bad-metrics-app
  template:
    metadata:
      labels:
        app: bad-metrics-app
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
    spec:
      containers:
        - name: app
          image: python:3.12-slim
          command:
            - python3
            - -c
            - |
              import http.server, uuid, time, threading

              metrics_store = {}

              def generate_metrics():
                while True:
                  req_id = str(uuid.uuid4())
                  metrics_store[req_id] = 1
                  time.sleep(0.1)  # 10 novas séries/segundo

              threading.Thread(target=generate_metrics, daemon=True).start()

              class Handler(http.server.BaseHTTPRequestHandler):
                def do_GET(self):
                  if self.path == '/metrics':
                    lines = ['# HELP http_requests_total Total de requests\n',
                             '# TYPE http_requests_total counter\n']
                    for rid, val in list(metrics_store.items()):
                      lines.append(f'http_requests_total{{request_id="{rid}"}} {val}\n')
                    body = ''.join(lines).encode()
                    self.send_response(200)
                    self.send_header('Content-Type', 'text/plain')
                    self.end_headers()
                    self.wfile.write(body)
                  self.log_message = lambda *args: None

              http.server.HTTPServer(('', 8080), Handler).serve_forever()
          ports:
            - containerPort: 8080
```

```bash
kubectl apply -f manifests/01-high-cardinality-app.yaml
```

### Passo 3 — Detectar o Problema

Aguarde 2–3 minutos e observe:

```bash
# No Grafana → Explore → Prometheus:
# prometheus_tsdb_head_series  (deve estar crescendo rapidamente)

# Via kubectl:
kubectl -n monitoring exec -it \
  $(kubectl -n monitoring get pod -l app.kubernetes.io/name=prometheus -o name | head -1) \
  -- wget -qO- 'http://localhost:9090/api/v1/status/tsdb' \
  | python3 -c "
import json,sys
d=json.load(sys.stdin)
top=sorted(d['data']['seriesCountByMetricName'],key=lambda x:x['count'],reverse=True)[:3]
print('Top métricas por cardinalidade:')
for m in top: print(f\"  {m['count']:>10,}  {m['name']}\")
hl=sorted(d['data']['seriesCountByLabelValuePair'],key=lambda x:x['count'],reverse=True)[:3]
print('Top label values:')
for l in hl: print(f\"  {l['count']:>10,}  {l['name']}\")
"
```

### Passo 4 — Corrigir com metric_relabeling_configs

Edite o `values-prometheus-stack.yaml` para adicionar a regra:

```yaml
# helm-values/values-prometheus-stack.yaml
prometheus:
  prometheusSpec:
    additionalScrapeConfigs:
      - job_name: bad-metrics-app
        kubernetes_sd_configs:
          - role: pod
            namespaces:
              names: [games]
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_label_app]
            regex: bad-metrics-app
            action: keep
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_port]
            regex: (.+)
            target_label: __address__
            replacement: '${1}:8080'
            action: replace

        # ← SOLUÇÃO: remove o label request_id antes de gravar
        metric_relabeling_configs:
          - action: labeldrop
            regex: request_id
```

Aplique:

```bash
helm upgrade prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f helm-values/values-prometheus-stack.yaml
```

### Passo 5 — Validar a Correção

```bash
# Séries devem parar de crescer e diminuir após o GC do Prometheus
# (pode demorar alguns minutos para o head chunk rotacionar)

# Verifique que http_requests_total não tem mais request_id
kubectl -n monitoring exec -it \
  $(kubectl -n monitoring get pod -l app.kubernetes.io/name=prometheus -o name | head -1) \
  -- wget -qO- 'http://localhost:9090/api/v1/query?query=count+by+(request_id)(http_requests_total)' \
  | python3 -m json.tool
# Deve retornar data: [] (sem séries com esse label)
```

---

## Referência Rápida

### PromQL de Diagnóstico

```promql
# Total de séries ativas
prometheus_tsdb_head_series

# Taxa de criação de novas séries
rate(prometheus_tsdb_head_series_created_total[10m])

# Amostras ingeridas por job
rate(scrape_samples_scraped[5m])

# Scrapes que falharam por limite de amostras
rate(scrape_samples_post_metric_relabeling[5m])

# Séries rejeitadas pelo Mimir (429 Too Many)
rate(cortex_ingester_instance_limits_rejections_total[5m])

# Uso do limite de séries no Mimir
cortex_ingester_memory_series / cortex_ingester_instance_limits{limit="max_series"}
```

### Checklist de Deploy

Antes de fazer deploy de qualquer aplicação com métricas:

- [ ] Labels possuem cardinalidade limitada e conhecida?
- [ ] Não há `request_id`, `trace_id`, `user_id` ou UUIDs como labels?
- [ ] O endpoint `/metrics` foi testado com `curl | wc -l`? (< 5.000 linhas = OK)
- [ ] Existe `sample_limit` no ServiceMonitor?
- [ ] Existe alerta para crescimento de cardinalidade?

---

## Questões de Fixação

**1.** Uma métrica `api_calls_total` tem os labels `{method, status_code, user_id}`.
O sistema tem 1 milhão de usuários. Quantas séries essa métrica pode ter no pior caso?
Qual a solução correta?

<details>
<summary>Resposta</summary>

Com 5 métodos × 10 status codes × 1.000.000 usuários = **50.000.000 séries**.
A solução é remover `user_id` das métricas e usar logs/traces para rastreamento
por usuário. Se for necessário contar por usuário, use um histogram ou
agregue via recording rule por segmento (ex: `tier="premium|free"`).

</details>

---

**2.** O Prometheus está com `prometheus_tsdb_head_series = 3.500.000`.
Você executou `/api/v1/status/tsdb` e descobriu que `http_request_duration_seconds`
tem 2.800.000 séries sozinha. Qual label provavelmente é o culpado e como investigar?

<details>
<summary>Resposta</summary>

Execute:
```promql
count(count by (path) (http_request_duration_seconds_bucket))
count(count by (handler) (http_request_duration_seconds_bucket))
count(count by (user_agent) (http_request_duration_seconds_bucket))
```
O label que retornar um número alto (ex: 50.000 paths únicos) é o culpado.
Corrija com `metric_relabeling_configs` dropando ou normalizando esse label.

</details>

---

**3.** Qual a diferença entre `relabel_configs` e `metric_relabeling_configs`
em um scrape job do Prometheus?

<details>
<summary>Resposta</summary>

- **`relabel_configs`**: aplicado nos **targets** antes do scrape acontecer.
  Usado para filtrar quais targets scrape, modificar `__address__`, adicionar
  labels aos targets. Não vê as métricas ainda.
- **`metric_relabeling_configs`**: aplicado nas **amostras** coletadas,
  após o scrape. Usado para dropar labels ruins, dropar métricas específicas,
  ou transformar valores. Opera sobre o conteúdo do endpoint `/metrics`.

</details>

---

**4.** Você configurou `max_global_series_per_metric: 50000` no Mimir.
O que acontece quando uma métrica ultrapassa esse limite?

<details>
<summary>Resposta</summary>

O Mimir rejeita as novas séries que ultrapassam o limite com HTTP 429.
O Prometheus registra o erro no log e nas métricas de remote_write
(`prometheus_remote_storage_samples_failed_total`). Séries existentes
continuam sendo ingeridas. O limite não afeta queries históricas.

</details>

---

**5.** Você tem 200 pods de uma aplicação, cada um com `pod_ip` como label
em todas as métricas. O que acontece ao fazer um rolling update de todos os pods?

<details>
<summary>Resposta</summary>

Cada pod novo tem um IP diferente → cria novas séries para cada pod novo.
As séries dos pods antigos ficam inativas (dead series) por `--storage.tsdb.retention.time`.
Se o intervalo entre scrapes for 15s e um rolling update demora 10 minutos,
você terá 400 séries paralelas por métrica durante a migração (dobro).
Isso **dobra temporariamente** a cardinalidade. Corrija dropando `pod_ip`
ou usando apenas `pod` (nome do pod), que tem cardinalidade controlada.

</details>

---

## Dicas Finais de Produção

> *"Você pode ter o melhor stack de observabilidade do mercado — mas se não souber controlar a cardinalidade, vai explodir o orçamento e o cluster ao mesmo tempo."*

Esta seção reúne o que aprendemos em todos os módulos, visto agora pela lente da **eficiência em produção**.

---

### As Três Camadas de Proteção

Pense em proteção contra high cardinality como um modelo de defesa em profundidade. Se uma camada falhar, a próxima segura:

```
┌─────────────────────────────────────────────────────────────────┐
│  CAMADA 1 — Aplicação                                           │
│  Responsabilidade: dev/time de produto                          │
│                                                                 │
│  • Não use request_id, trace_id, user_id como labels           │
│  • Use histogramas em vez de gauges por usuário                 │
│  • Documente os labels e a cardinalidade esperada              │
│  • Faça review de métricas no code review                      │
└──────────────────────────┬──────────────────────────────────────┘
                           │ se escapar da camada 1...
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  CAMADA 2 — Scrape (Prometheus / Alloy)                        │
│  Responsabilidade: time de plataforma / SRE                    │
│                                                                 │
│  • labeldrop no ServiceMonitor antes de entrar no TSDB         │
│  • sampleLimit por job (falha ruidosa > falha silenciosa)      │
│  • labelLimit: 64 global                                       │
│  • metricRelabelings para dropar métricas inúteis              │
└──────────────────────────┬──────────────────────────────────────┘
                           │ se escapar da camada 2...
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  CAMADA 3 — Storage (Mimir)                                     │
│  Responsabilidade: time de infraestrutura                      │
│                                                                 │
│  • max_global_series_per_metric: 50000 (por tenant)            │
│  • max_global_series_per_user: 1500000                         │
│  • ingestion_rate com burst controlado                         │
│  • Runtime config para ajuste sem downtime                     │
└─────────────────────────────────────────────────────────────────┘
```

---

### O Que Cada Ferramenta Protege

| Sinal | Ferramenta | Problema de Cardinalidade | Solução |
|-------|-----------|--------------------------|---------|
| Métricas | Prometheus | Labels com valores infinitos | `labeldrop` + `sampleLimit` |
| Métricas | Mimir | Ingestão sem limites | `max_global_series_per_metric` |
| Logs | Loki | Streams com labels únicos | `max_streams_per_user` |
| Logs | Fluent Bit | Labels de sistema desnecessários | `record_modifier` + grep filter |
| Traces | Tempo | N/A (traces não têm cardinality no mesmo sentido) | — |
| Profiles | Pyroscope | Profiles por request ID | Agregar por função, não por trace |

---

### Anti-Padrões Vistos em Produção

**❌ 1. User ID como label de métrica**
```promql
# Isso vai destruir seu Prometheus
http_requests_total{user_id="user-12345", method="GET"}
```
> Solução: remova `user_id`. Para análise por usuário, use logs com `user_id` no campo, não no label do Loki.

**❌ 2. Path completo com query string**
```promql
http_request_duration_seconds{path="/api/search?q=kubernetes&page=3&size=20"}
```
> Solução: normalize paths. Use `metric_relabeling_configs` para transformar `/api/search?.*` em `/api/search`.

**❌ 3. Versão de build como label**
```promql
app_info{version="1.2.3-commit-a7f3e2b-2025-01-23T15:30:00Z"}
```
> Solução: versões semânticas têm cardinalidade controlada (`1.2.3`). Hashes de commit não.

**❌ 4. `pod_ip` em vez de `pod`**
```promql
# Pod IP muda a cada restart → infinitas dead series
http_requests_total{pod_ip="10.244.1.23"}
```
> Solução: use `pod` (nome do pod) que tem cardinalidade = número de replicas.

**❌ 5. Não ter `sampleLimit`**
> Um dev sobe um serviço com 50.000 métricas por scrape às 23h de sexta. O Prometheus explode às 2h da manhã.
> `sampleLimit: 10000` no ServiceMonitor faz o scrape **falhar ruidosamente** em vez de derrubar o cluster.

---

### Runbook: Incidente de High Cardinality

Quando o alerta `PrometheusHighCardinalityGrowth` disparar:

```
PASSO 1 — Detectar (< 5 min)
════════════════════════════
□ Acesse: /api/v1/status/tsdb → top_metrics
□ Execute: count(count by (label_ruim) (metrica_culpada))
□ Identifique: qual label tem cardinalidade crescente?
□ Identifique: qual deployment fez o deploy nos últimos 30 min?

PASSO 2 — Conter (< 15 min)
════════════════════════════
□ Opção A: adicione labeldrop no ServiceMonitor da aplicação
  kubectl edit servicemonitor <nome> -n monitoring
□ Opção B: escale o Prometheus para ter mais RAM temporariamente
  (kubernetes VPA ou patch direto nos resources)
□ Opção C: se crítico, pause o scrape do job problemático
  kubectl annotate svc <nome> prometheus.io/scrape=false

PASSO 3 — Corrigir (< 2h)
════════════════════════════
□ Aplique metric_relabeling_configs ou labeldrop via Helm
□ Aguarde o GC do Prometheus (head chunks rotatam em ~2h)
□ Confirme que prometheus_tsdb_head_series está estabilizando

PASSO 4 — Prevenir (próxima sprint)
════════════════════════════════════
□ Adicione checklist de métricas no process de code review
□ Crie alerta de sampleLimit (scrape_samples_post_metric_relabeling > 8000)
□ Documente o label problemático como anti-padrão interno
□ Considere criar um dashboard "Saúde das Métricas" (manifests/05-grafana-dashboard.yaml)
```

---

### Loki: A Mesma Lógica, Outro Mundo

High cardinality em Loki funciona da mesma forma que no Prometheus, mas com **streams** em vez de séries:

```
# Prometheus: série = conjunto único de labels
http_requests_total{method="GET", status="200"} → 1 série

# Loki: stream = conjunto único de labels de log
{app="ranking-api", namespace="games"} → 1 stream
{app="ranking-api", namespace="games", pod="ranking-api-abc123"} → 1 stream
```

**O que aumenta streams no Loki:**

| Label problemático | Impacto | Solução no Fluent Bit |
|---|---|---|
| `pod` com muitas replicas | Streams × replicas | Mantém `pod` (controlado) |
| `container_id` | 1 stream por container restart | `record_modifier` remove |
| `stream` (stdout/stderr) | Dobra os streams | `record_modifier` remove |
| `logtag` | Adiciona streams desnecessários | `record_modifier` remove |
| `pod_template_hash` | 1 stream por deployment | `record_modifier` remove |

O `values-fluent-bit.yaml` deste módulo já aplica todas essas remoções.

**Verificação de saúde do Loki:**
```promql
# Total de streams ativos
loki_ingester_memory_streams

# Streams criados na última hora (crescimento)
rate(loki_ingester_streams_created_total[1h])

# Streams por tenant
loki_ingester_memory_streams_labels_bucket
```

---

### Otimização de Custos: Onde Está o Dinheiro

Em produção, os maiores consumidores de recursos são:

```
┌──────────────────────────────────────────────────────────────┐
│  RANKING DE CUSTO (maior para menor)                         │
│                                                              │
│  1. Armazenamento de séries (Mimir blocks)   ~40% do custo  │
│  2. RAM do Prometheus (head chunks em RAM)   ~30% do custo  │
│  3. Ingestão de logs (Loki chunks)           ~20% do custo  │
│  4. Scraping + network                       ~10% do custo  │
└──────────────────────────────────────────────────────────────┘
```

**Quick wins de custo:**

1. **Recording rules** reduzem queries caras em dashboards de alta frequência.
   Um dashboard com 10 painéis, cada um rodando `sum(rate(...[5m]))` a cada 15s,
   executa a query **5.760 vezes/dia**. Com recording rule: executa **2.880 vezes/dia**.

2. **Retenção curta no Prometheus local**: com Mimir para long-term storage,
   o Prometheus local pode ter `retention: 2h`. Reduz RAM e disco local em ~90%.

3. **Dropar métricas de debug do Go runtime**: `go_memstats_*`, `go_gc_*` e
   `process_*` têm baixo valor operacional e alta frequência. Dropar salva ~5–10%
   das amostras em clusters com muitos serviços Go.

4. **`scrapeInterval: 30s` para maioria das métricas** (não 15s):
   Dobra o intervalo = metade dos dados = metade do custo de storage sem perda
   significativa de observabilidade para a maioria dos alertas.

---

### Checklist Completo de Produção

**Antes de ir para produção com o stack deste curso:**

```
PROMETHEUS
□ retention: 2h (com Mimir)
□ retentionSize: 3–5GB
□ labelLimit: 64
□ scrapeInterval: 30s
□ sampleLimit nos ServiceMonitors críticos
□ metric_relabeling_configs para labels problemáticos
□ Alertas de cardinality configurados

MIMIR
□ max_global_series_per_user configurado
□ max_global_series_per_metric configurado
□ ingestion_rate com burst definido
□ Runtime config ativo (reload a cada 10s)
□ Alerta em MimirSeriesLimitApproaching (70%)

LOKI
□ max_streams_per_user: 10000
□ retention_period: 720h (30 dias)
□ max_entries_limit_per_query: 5000
□ Fluent Bit com record_modifier removendo labels inúteis

FLUENT BIT
□ Grep filter excluindo namespaces de sistema
□ Remoção de container_id, docker_id, stream, logtag
□ loki-label-map.json com labels estáveis
□ Tolerations para controle do daemonset em todos os nós

ALERTAS ATIVOS
□ PrometheusHighCardinalityGrowth (warning > 20% em 1h)
□ PrometheusCardinalityTooHigh (critical > 2M séries)
□ MimirSeriesLimitApproaching (warning > 70% do limite)
□ MimirIngestionRejections (critical rate > 0)
□ PrometheusRemoteWriteLag (warning > 120s)
```

---

## Próximos Passos

Com o domínio de high cardinality e otimização do stack, os próximos territórios naturais são:

- **SLOs com Prometheus**: calcular error budgets com séries de baixa
  cardinalidade e recording rules eficientes — a base para confiabilidade mensurável
- **Native Histograms**: reduzir cardinalidade de histogramas clássicos
  de N×buckets séries para 1 série (disponível no Prometheus 2.40+)
- **Exemplars**: ligar métricas a traces sem usar labels de alta cardinalidade
  (`trace_id` fica no exemplar, não no label — veja módulo 04)
- **Adaptive Metrics** (Grafana Cloud): identificar e arquivar automaticamente
  séries inativas para reduzir custo de armazenamento em produção real
