# Módulo 06 — Grafana Mimir

> *"É sexta-feira, 18h. O servidor de monitoramento é reiniciado para
> aplicar patches de segurança. Na segunda-feira, o gestor pergunta:
> qual era a utilização de CPU do ranking-api na sexta à tarde, antes
> da janela de manutenção? Sem Mimir: tela vazia. Com Mimir: gráfico
> completo dos últimos 30 dias, sem lacuna."*

---

## O Problema que o Mimir Resolve

O Prometheus armazena métricas em um banco de dados de séries temporais
**local** (TSDB) no disco do pod. Isso cria três problemas reais em
ambientes de produção:

| Problema | Impacto |
|---|---|
| Pod reiniciado / upgrade | Dados locais perdidos (WAL descartado) |
| Retenção padrão de 15 dias | Impossível fazer análise de tendências mensais |
| Node com disco cheio | Dados perdidos para sempre |

O Mimir atua como **backend remoto de armazenamento** para o Prometheus.
O Prometheus continua funcionando normalmente (coletando, avaliando alertas),
mas envia uma cópia de todos os dados para o Mimir via `remote_write`.
O Mimir compacta esses dados em blocos TSDB e os grava em **object storage**
(MinIO neste módulo, AWS S3 em produção).

---

## Arquitetura

```
┌─────────────────────────────────────────────────────────────────┐
│                     namespace: monitoring                        │
│                                                                  │
│  ┌──────────────┐  remote_write  ┌──────────────────────────┐  │
│  │  Prometheus  │ ──────────────▶ │         Mimir             │  │
│  │  (TSDB local │                │  (ingester + compactor    │  │
│  │   15 dias)   │                │   + store-gateway + ...)  │  │
│  └──────────────┘                └────────────┬─────────────┘  │
│                                               │                  │
│                                        S3 API │                  │
│                                               ▼                  │
│                                  ┌───────────────────────┐      │
│                                  │    MinIO (bitnami)    │      │
│                                  │  ┌─────────────────┐  │      │
│                                  │  │ mimir-blocks    │  │      │
│                                  │  │ mimir-alertmgr  │  │      │
│                                  │  │ mimir-ruler     │  │      │
│                                  │  └─────────────────┘  │      │
│                                  └───────────────────────┘      │
│                                                                  │
│  ┌──────────────┐                                                │
│  │   Grafana    │──── uid: prometheus ──▶ Prometheus             │
│  │              │──── uid: mimir      ──▶ Mimir /prometheus API  │
│  └──────────────┘                                                │
└─────────────────────────────────────────────────────────────────┘
```

### Fluxo de dados

```
1. Targets (pods, nodes, etc.)
        │  scrape (pull)
        ▼
2. Prometheus
        │  remote_write (push, lotes de 1000 amostras a cada 5s)
        ▼
3. Mimir — Ingester
        │  (mantém em memória + WAL local no PVC)
        │  compactor (a cada 2h)
        ▼
4. MinIO — mimir-blocks/
        │  (blocos TSDB compactados, imutáveis)
        │
5. Query path: Grafana ──▶ Mimir Querier ──▶ Ingester (dados recentes)
                                           └──▶ Store-Gateway ──▶ MinIO (histórico)
```

---

## Componentes

### Grafana Mimir (modo monolítico)

Em produção, o Mimir roda em modo **microservices** com cada componente
em seu próprio Deployment, escalando de forma independente. Para aprendizado,
usamos o modo **monolítico** (`target: all`) — todos os componentes
em um único pod:

| Componente | Função |
|---|---|
| **Distributor** | Recebe o `remote_write` do Prometheus e distribui para os ingesters |
| **Ingester** | Mantém dados em memória + WAL; compacta para blocos S3 a cada 2h |
| **Compactor** | Mescla blocos pequenos em blocos maiores (reduz custo de query) |
| **Store-Gateway** | Serve blocos históricos do MinIO para queries |
| **Querier** | Executa PromQL consultando ingester (recente) + store-gateway (histórico) |
| **Query-Frontend** | Cache e paralelismo de queries pesadas |
| **Ruler** | Avalia recording rules e alertas no nível do Mimir |
| **Alertmanager** | Gerencia alertas gerados pelo Ruler |

### MinIO

Object storage S3-compatível rodando dentro do cluster. O Mimir usa
três buckets separados por responsabilidade (boa prática mesmo com
um único nó):

- `mimir-blocks` — dados de séries temporais (maior volume)
- `mimir-alertmanager` — configurações e silences do alertmanager
- `mimir-ruler` — recording rules e alerting rules gerenciadas pelo Mimir

Em produção: substitua o MinIO por AWS S3, Google Cloud Storage ou
Azure Blob. A mudança é apenas no `01-mimir-config.yaml` (endpoint
e credenciais). O restante da stack não muda.

---

## Estrutura do Módulo

```
modulo-06-mimir/
├── cluster-config.yaml              # Kind cluster com ExtraPortMappings
├── helm-values/
│   ├── values-minio.yaml            # MinIO standalone, 3 buckets, 5Gi PVC
│   └── values-prometheus-stack.yaml # kube-prometheus-stack + remoteWrite
├── manifests/
│   ├── 01-mimir-config.yaml         # ConfigMap com mimir.yaml
│   ├── 02-mimir-deployment.yaml     # StatefulSet + Services
│   ├── 03-grafana-datasource-mimir.yaml  # Datasource uid: mimir
│   └── README.md
└── stack/                           # Stack completa reutilizável
    ├── mario/                       # App de carga (Super Mario)
    └── monitoring/
        ├── grafana-dashboards/      # four-golden-signals.json
        ├── helm-values/             # values-prometheus-stack + loki + fluent-bit
        └── manifests/               # Regras, probes, dashboards como ConfigMaps
```

---

## Diferenças em Relação aos Módulos Anteriores

### vs. Módulo 03 (Monitoring)
- **Módulo 03**: Prometheus puro, sem remote_write
- **Módulo 06**: Prometheus + remote_write → Mimir → MinIO

### vs. Prometheus nativo
Prometheus e Mimir são **complementares**, não substitutos:

| Funcionalidade | Prometheus | Mimir |
|---|---|---|
| Coleta de métricas (scrape) | ✅ | ❌ |
| Avaliação de alertas | ✅ | ✅ (ruler) |
| Retenção de curto prazo | ✅ (15 dias default) | — |
| Retenção de longo prazo | ❌ (limitado por disco) | ✅ (object storage ilimitado) |
| PromQL endpoint | ✅ `/api/v1/query` | ✅ `/prometheus/api/v1/query` |
| Sobrevive a restarts | ❌ (perde WAL) | ✅ (dados no MinIO) |

---

## Conceitos Importantes

### remote_write

O mecanismo pelo qual o Prometheus envia dados a sistemas externos.
Configurado em `prometheusSpec.remoteWrite`:

```yaml
remoteWrite:
  - url: http://mimir.monitoring.svc.cluster.local:9009/api/v1/push
```

O Prometheus mantém uma fila em memória, agrupa amostras em lotes
e envia via HTTP POST. Em caso de falha temporária do Mimir,
ele tenta novamente (retry) até esgotar o buffer.

### Compactação

O Mimir ingere dados em blocos de 2 horas (mesmo formato do Prometheus TSDB).
O compactor periodicamente mescla esses blocos em blocos maiores:
2h → 8h → 24h → 48h → ...

Isso reduz o número de arquivos no MinIO e acelera queries de períodos longos.

### multi-tenancy

Neste módulo, `multitenancy_enabled: false`. Em produção com múltiplos
times usando o mesmo cluster Mimir:

```yaml
multitenancy_enabled: true
```

Cada time inclui o header `X-Scope-OrgID: <team-name>` nas requisições.
Isso isola completamente as métricas entre times no mesmo cluster.

---

## Portas Expostas

| Serviço | URL local | Credenciais |
|---|---|---|
| Grafana | http://localhost:3000 | admin / prom-operator |
| Prometheus | http://localhost:9090 | — |
| Alertmanager | http://localhost:9093 | — |
| Mimir API | http://localhost:9009 | — |
| MinIO Console | http://localhost:9001 | mimir / mimir-supersecret |
| Mario | http://localhost:8081 | — |

---

## Referências

- [Grafana Mimir Docs](https://grafana.com/docs/mimir/latest/)
- [Mimir monolithic mode](https://grafana.com/docs/mimir/latest/operators-guide/deploy-grafana-mimir/deploy-in-monolithic-mode/)
- [Prometheus remote_write](https://prometheus.io/docs/practices/remote_write/)
- [MinIO (Bitnami Helm chart)](https://github.com/bitnami/charts/tree/main/bitnami/minio)
