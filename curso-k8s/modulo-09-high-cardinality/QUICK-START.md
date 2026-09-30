# Módulo 08 — High Cardinality: Quick Start

> **Contexto**: Você chegou ao módulo final do curso. O cluster tem o stack
> completo rodando — Prometheus, Loki, Grafana, Tempo, Pyroscope, Mimir e
> ArgoCD. Agora você vai aprender a identificar e resolver o problema que
> mata clusters de produção sem aviso: **alta cardinalidade**.
>
> Este módulo é o **"capô aberto"** de tudo o que construímos juntos.
> Você vai ver o custo real de cada decisão de label, e aprender a
> otimizar cada peça da stack para produção.

---

## Pré-requisito — Navegar até o diretório do módulo

```bash
# Linux / macOS
cd curso-k8s/modulo-08-high-cardinality
```
```pwsh
# Windows (PowerShell)
Set-Location curso-k8s\modulo-08-high-cardinality
```

---

## Pré-condição: Módulo 07 ou 06 concluído

O cluster precisa ter Prometheus + Mimir rodando no namespace `monitoring`.
Verifique:

```bash
kubectl get pods -n monitoring | grep -E "prometheus|mimir|grafana"
```

Se todos os pods estão `Running`, você está pronto.

---

## Fase 1 — Diagnóstico do Cluster Atual

### 1.1 — Quantas séries o seu cluster tem agora?

```bash
# Port-forward para o Prometheus se ainda não estiver ativo
kubectl port-forward svc/kind-prometheus-kube-prome-prometheus \
  -n monitoring 9090:9090 &
```

Abra http://localhost:9090 e execute no **Query** field:

```promql
prometheus_tsdb_head_series
```

> **Referência**: < 500k = saudável, 500k–2M = atenção, > 2M = risco.

### 1.2 — Top métricas por cardinalidade

```bash
# Acesso direto à API TSDB do Prometheus
curl -s http://localhost:9090/api/v1/status/tsdb | python3 -c "
import json, sys
d = json.load(sys.stdin)
print('=== Top 10 Métricas (séries) ===')
top = sorted(d['data']['seriesCountByMetricName'], key=lambda x: x['count'], reverse=True)[:10]
for m in top:
    print(f\"  {m['count']:>10,}  {m['name']}\")

print()
print('=== Top 10 Labels (combinações únicas) ===')
top_l = sorted(d['data']['seriesCountByLabelValuePair'], key=lambda x: x['count'], reverse=True)[:10]
for l in top_l:
    print(f\"  {l['count']:>10,}  {l['name']}\")
"
```

Salve esse output — é o **baseline antes das otimizações**. Você vai
comparar com o estado final no Passo 5.

### 1.3 — Verificar scrape times e custos por job

```promql
# Duração de cada scrape (quanto tempo leva coletar cada job)
scrape_duration_seconds

# Amostras por job no último scrape
scrape_samples_scraped

# Capacidade da fila de remote_write para Mimir
prometheus_remote_storage_queue_highest_sent_timestamp_seconds
  - prometheus_remote_storage_highest_timestamp_in_seconds
```

> Um `remote_storage lag > 30s` indica que o Mimir não está consumindo
> rápido o suficiente — causa: muitas séries ou queueConfig mal ajustado.

---

## Fase 2 — Injetando Alta Cardinalidade (Laboratório)

### 2.1 — Deploy do app problemático

```bash
kubectl apply -f manifests/01-bad-metrics-app.yaml
```

Este app expõe métricas com `request_id` como label — cada poll gera
10 novas séries únicas. Em 5 minutos: ~3.000 séries extras por scrape.

### 2.2 — Verificar que o Prometheus coletou

Aguarde um ciclo de scrape (30s) e confirme:

```promql
# Deve aparecer com dezenas de valores únicos para request_id
count by (request_id) (http_requests_total{job="bad-metrics-app"})
```

Você vai ver centenas de linhas — cada uma com um UUID diferente.

### 2.3 — Observar o crescimento

```promql
# Rate de criação de séries (deve estar subindo)
rate(prometheus_tsdb_head_series_created_total[2m])

# Total de séries (deve estar crescendo progressivamente)
prometheus_tsdb_head_series
```

Deixe o app rodando por **3 minutos** antes de prosseguir — para
ter um impacto visível no TSDB status.

---

## Fase 3 — Aplicando as Otimizações

### 3.1 — Corrigir o scrape com metric_relabeling

Aplique o ServiceMonitor corrigido:

```bash
kubectl apply -f manifests/02-service-monitor-fixed.yaml
```

O que esse manifest faz:
- `labeldrop: request_id` — remove o label antes de gravar no TSDB
- `sampleLimit: 5000` — falha o scrape inteiro se passar de 5k amostras
- `drop: /health|/ready` — remove paths de liveness (alta freq, baixo valor)

### 3.2 — Validar que o label sumiu

Aguarde 30s (próximo ciclo de scrape):

```promql
# Deve retornar vazio ou erro "no data"
count by (request_id) (http_requests_total{job="bad-metrics-app"})

# Mas a métrica ainda existe (sem o label ruim)
http_requests_total{job="bad-metrics-app"}
```

### 3.3 — Aplicar alertas de cardinalidade

```bash
kubectl apply -f manifests/03-cardinality-alerts.yaml
```

Verifique no Prometheus → Alerts:

```bash
open http://localhost:9090/alerts
# Ou no Grafana → Alerting
```

### 3.4 — Atualizar o Prometheus com configurações otimizadas

```bash
helm upgrade kind-prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f helm-values/values-prometheus-stack.yaml \
  --reuse-values
```

As principais mudanças neste `values.yaml`:
- `retention: 2h` — não armazena localmente o que o Mimir já tem
- `retentionSize: 3GB` — cap de disco
- `queueConfig` otimizado para o Mimir
- `scrapeInterval: 30s` para jobs menos críticos

### 3.5 — Atualizar o Mimir com limites por métrica

```bash
helm upgrade mimir grafana/mimir-distributed \
  --namespace monitoring \
  -f helm-values/values-mimir.yaml \
  --reuse-values
```

Agora o Mimir rejeita qualquer métrica que tenha > 50.000 séries,
prevenindo que um deploy ruim destrua o storage inteiro.

---

## Fase 4 — Otimizando Loki e Fluent Bit

### 4.1 — O Problema de Cardinalidade no Loki

O Loki tem o **mesmo problema** do Prometheus, mas para logs.
Labels de stream com alta cardinalidade explodem o índice do Loki:

```bash
# Veja quantos streams únicos o Loki tem
kubectl port-forward svc/kind-prometheus-loki -n monitoring 3100:3100 &
curl -s 'http://localhost:3100/loki/api/v1/label' | python3 -m json.tool
```

Labels problemáticos no Loki (os mesmos que no Prometheus):
- `filename` com path completo (`/var/log/pods/xxx/yyy/0.log`)
- `pod_name` com hash de ReplicaSet (`api-7f9d4b8c6-xkzpq`)
- `container_id` (UUID do container)

### 4.2 — Atualizar o Fluent Bit para normalizar labels

```bash
helm upgrade fluent-bit fluent/fluent-bit \
  --namespace monitoring \
  -f helm-values/values-fluent-bit.yaml \
  --reuse-values
```

As mudanças:
- Mantém apenas: `namespace`, `app`, `pod`, `container`
- Remove: `stream`, `logtag`, `docker_id`, `container_id`
- Normaliza `pod` para remover o hash do ReplicaSet (opcional)

### 4.3 — Verificar os labels do Loki depois

```bash
# Labels disponíveis após a limpeza
curl -s 'http://localhost:3100/loki/api/v1/label' | jq .

# Deve ter apenas: app, namespace, pod, container, node
```

---

## Fase 5 — Recording Rules para Redução de Cardinalidade

### 5.1 — O Problema

O `kube-state-metrics` (parte do kube-prometheus-stack) expõe dezenas
de labels de cada Pod/Deployment/Node. Uma query como:

```promql
kube_pod_info
```

Tem ~40 labels por pod. Com 200 pods: 8.000 séries só para essa métrica.

### 5.2 — Aplicar Recording Rules de Redução

```bash
kubectl apply -f manifests/04-recording-rules.yaml
```

Estas regras criam versões **enxutas** das métricas mais usadas:

```promql
# Em vez de kube_pod_info (40 labels), use:
job:kube_pod_info:slim  # apenas namespace, pod, app, node
```

### 5.3 — Verificar as recording rules

```promql
# Deve existir com menos labels do que kube_pod_info original
job:kube_pod_info:slim

# Compare o número de séries:
count(kube_pod_info)              # original (muitas séries)
count(job:kube_pod_info:slim)     # reduzido (mesma info, menos labels)
```

---

## Fase 6 — Dashboard de Saúde do Stack

### 6.1 — Importar dashboard de monitoramento do Prometheus

No Grafana (http://localhost:31000):
1. Menu lateral → **Dashboards → Import**
2. Cole o ID: `3662` (Prometheus 2.0 Stats — dashboard oficial)
3. Datasource: `prometheus`

Este dashboard mostra:
- Séries ativas (head series)
- Taxa de ingestão de amostras
- Uso de memória e CPU do Prometheus
- Lag do remote_write para Mimir

### 6.2 — Aplicar o dashboard customizado do módulo

```bash
kubectl apply -f manifests/05-grafana-dashboard.yaml
```

O dashboard **"Stack Health — Módulo 08"** mostra:
- Cardinalidade por job (quem está crescendo?)
- Uso de limites no Mimir (% do max_global_series)
- Streams ativos no Loki
- Lag do remote_write

---

## Fase 7 — Comparação Antes e Depois

### 7.1 — Novo snapshot do TSDB

```bash
curl -s http://localhost:9090/api/v1/status/tsdb | python3 -c "
import json, sys
d = json.load(sys.stdin)
print('=== Estado ATUAL ===')
print(f\"Total séries: {d['data']['headStats']['numSeries']:,}\")
print()
print('Top 5 métricas:')
top = sorted(d['data']['seriesCountByMetricName'], key=lambda x: x['count'], reverse=True)[:5]
for m in top:
    print(f\"  {m['count']:>10,}  {m['name']}\")
"
```

Compare com o baseline do Passo 1.2.

### 7.2 — Verificar a saúde do Mimir

```promql
# Séries ativas no Mimir (deve ser menor agora, sem os request_ids)
cortex_ingester_memory_series

# Limite configurado
cortex_ingester_instance_limits{limit="max_series"}

# Percentual de uso (meta: < 60%)
cortex_ingester_memory_series
/ cortex_ingester_instance_limits{limit="max_series"}
```

### 7.3 — Limpeza (opcional)

Para remover o app problemático após o laboratório:

```bash
kubectl delete deployment bad-metrics-app -n games
kubectl delete service bad-metrics-app -n games
```

---

## Resumo das Otimizações Aplicadas

| Componente | O que foi otimizado | Impacto |
|---|---|---|
| **Prometheus** | `retention: 2h` + `retentionSize: 3GB` | -80% disco local |
| **Prometheus** | `sample_limit` por ServiceMonitor | Fail-fast em vez de OOMKill |
| **Prometheus** | `metric_relabeling: labeldrop` | Elimina labels de UUID |
| **Prometheus** | `queueConfig` otimizado | Mimir sem lag |
| **Mimir** | `max_global_series_per_metric: 50000` | Proteção por métrica |
| **Mimir** | `max_global_series_per_user: 1500000` | Proteção por tenant |
| **Loki** | Labels de stream reduzidos | Índice 10× menor |
| **Fluent Bit** | Drop de campos de alta cardinalidade | Logs mais limpos |
| **Recording Rules** | Versões slim de kube_pod_info | -60% séries de infra |

---

## Checklist de Produção

Use este checklist antes de qualquer deploy que expõe `/metrics`:

```
ANTES DO DEPLOY
  [ ] Listei todos os labels que a métrica vai ter?
  [ ] Algum label tem mais de 1.000 valores possíveis? (RED FLAG)
  [ ] Tem request_id, trace_id, user_id, UUID como label? (BLOQUEIO)
  [ ] Testei curl http://app/metrics | wc -l ? (meta: < 3.000 linhas)

NO ServiceMonitor / scrape_config
  [ ] sample_limit configurado?
  [ ] metricRelabelings com labeldrop para labels dinâmicos?
  [ ] scrapeInterval adequado ao tipo de dado?

NO MIMIR
  [ ] max_global_series_per_metric definido para métricas críticas?
  [ ] Alertas de rejeição configurados?

NO LOKI (se a app gera logs)
  [ ] Labels de stream são apenas: namespace, app, pod, container?
  [ ] Não estou usando filename completo como label?
```

---

## Próximos Passos

Você completou o curso! O que vem a seguir em um ambiente de produção real:

- **SLOs e Error Budgets**: usar as recording rules para calcular
  percentual de requests bem-sucedidos por janela de 30 dias
- **Native Histograms** (Prometheus 2.40+): reduzir a explosão de séries
  de histogramas de `N_buckets × N_labels` para `1 série`
- **Adaptive Metrics** (Grafana Cloud): arquivamento automático de séries
  que não aparecem em nenhuma dashboard ou alerta por 30 dias
- **Exemplars**: ligar traces a métricas sem usar `trace_id` como label
  (trace_id fica no exemplar OpenMetrics, não no label)
- **Mimir em produção**: substituir MinIO local por AWS S3 ou GCS,
  configurar múltiplas réplicas de ingester, compactor autônomo
