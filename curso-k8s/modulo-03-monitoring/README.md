# 📊 Módulo 03: Observabilidade com Prometheus, Grafana, Loki e Fluent Bit

## 📋 Índice

1. [Visão Geral](#-visão-geral)
2. [O Problema Real que Isso Resolve](#-o-problema-real-que-isso-resolve)
3. [Os Três Pilares da Observabilidade](#-os-três-pilares-da-observabilidade)
4. [Os Four Golden Signals](#-os-four-golden-signals)
5. [Arquitetura do Stack](#-arquitetura-do-stack)
6. [Componentes em Detalhe](#-componentes-em-detalhe)
7. [Como Usar Cada Componente](#-como-usar-cada-componente)
8. [Estrutura do Módulo](#-estrutura-do-módulo)
9. [Início Rápido](#-início-rápido)
10. [Alertas dos Four Golden Signals](#-alertas-dos-four-golden-signals)
11. [Receber Alertas no Discord](#-receber-alertas-no-discord)
12. [Questões de Fixação](#-questões-de-fixação)
13. [Recursos Adicionais](#-recursos-adicionais)

---

## 📚 Visão Geral

No **Módulo 02**, o HPA escalou os pods automaticamente durante o stress test — mas você só conseguia enxergar isso com `kubectl top`, uma linha por vez, sem histórico e sem contexto.

Este módulo monta o stack completo de observabilidade usado em produção:

- **Métricas** → Prometheus coleta, Grafana exibe
- **Logs** → Fluent Bit coleta, Loki armazena, Grafana exibe
- **Alertas** → Alertmanager e Grafana disparam notificações no **Discord** quando os **Four Golden Signals** saem do normal

> 🎬 **Cenário real:** O Mario está sob stress test. Com este stack, você consegue abrir o Grafana, ver a curva de CPU subindo, clicar em um pod com memória alta, e em dois cliques ver os logs de erro daquele pod — tudo na mesma tela.

---

## 🔥 O Problema Real que Isso Resolve

```
Sem observabilidade:
  "O serviço está lento."
  "Não sei por quê. Vou olhar os logs... em qual pod? São 12 pods."
  "A CPU subiu? Quando? Por quanto tempo?"

Com este stack:
  Grafana → gráfico de latência mostra pico às 14h23
  Loki    → logs do pod com mais erros naquele momento
  Alerta  → você recebeu aviso às 14h21, antes de impactar usuários
```

---

## 🔭 Os Três Pilares da Observabilidade

A observabilidade moderna se apoia em três tipos de dados:

### 1. Métricas (Metrics)
Números agregados ao longo do tempo. Respondem "quanto" e "quantas vezes".

- **Exemplos:** CPU 82%, 1.200 req/s, latência p99 = 340ms
- **Ferramenta:** Prometheus + Grafana
- **Formato:** `nome{labels} valor timestamp`
- **Analogia:** Painel do carro — velocidade, temperatura, combustível

### 2. Logs
Registros textuais de eventos discretos. Respondem "o quê aconteceu".

- **Exemplos:** `ERROR: connection refused`, `POST /api/users 500 23ms`
- **Ferramenta:** Fluent Bit (coleta) + Loki (armazena) + Grafana (consulta)
- **Analogia:** Caixa preta do avião — registro de cada evento

### 3. Traces (Rastreamento distribuído)
Caminho completo de uma requisição entre múltiplos serviços. Respondem "onde ficou lento".

- **Exemplos:** requisição passou por API Gateway → Auth → DB → Cache
- **Ferramenta:** Jaeger, Tempo (Grafana), Zipkin
- **Analogia:** GPS rastreando a rota do pacote desde o remetente até o destinatário

> 📌 **Neste módulo** implementamos **métricas** e **logs**. Traces (rastreamento distribuído) são o tema do **[Módulo 04 — OpenTelemetry](../modulo-04-opentelemetry/README.md)**.

---

## 🚦 Os Four Golden Signals

Definidos pelo livro **Site Reliability Engineering do Google**, os Four Golden Signals são as quatro métricas mais importantes para monitorar qualquer serviço:

### 1. 🚦 Latência (Latency)
**Pergunta:** Quanto tempo leva para atender uma requisição?

- Sempre meça **latência de sucesso separada da latência de erro** — um erro rápido mascara problemas reais
- Métricas: `http_request_duration_seconds` (histogram), percentis p50/p95/p99
- Alerta neste módulo: HPA atingiu réplicas máximas → sistema não consegue mais absorver carga

### 2. 📈 Tráfego (Traffic)
**Pergunta:** Qual é a demanda atual sobre o sistema?

- Para serviços HTTP: requisições/segundo
- Para streaming: bytes/segundo
- Para jobs: tasks/segundo
- Métricas: `rate(http_requests_total[5m])`, `container_network_receive_bytes_total`
- Alerta neste módulo: tráfego de rede acima de 1 MB/s por mais de 2 minutos

### 3. ❌ Erros (Errors)
**Pergunta:** Com que frequência as requisições falham?

- Inclui erros **explícitos** (HTTP 500) e **implícitos** (resposta 200 com conteúdo errado)
- Métricas: `rate(http_requests_total{status=~"5.."}[5m])`, restarts de pods
- Alerta neste módulo: pod reiniciando mais de 2x em 15 minutos; pod não-Ready por 5 minutos

### 4. 🔋 Saturação (Saturation)
**Pergunta:** Quão "cheio" está o serviço? O que está perto do limite?

- Sempre monitore o recurso **mais limitante** (CPU, memória, disco, conexões)
- Métricas: uso de CPU/memória em relação ao `limit` configurado no pod
- Alerta neste módulo: CPU ou memória acima de 80% do limite por 3 minutos

```
┌─────────────────────────────────────────────────────────────────┐
│                   Four Golden Signals                           │
│                                                                 │
│  LATÊNCIA         TRÁFEGO          ERROS           SATURAÇÃO   │
│  Quão rápido?     Quanta demanda?  Quantas falhas? Quão cheio? │
│                                                                 │
│  p99 < 500ms      req/s normal     error rate < 1% CPU < 80%   │
│  ↑ degradação     ↑ pico           ↑ incidente     ↑ risco     │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🏗️ Arquitetura do Stack

```
┌──────────────────────────────────────────────────────────────────────┐
│                         Kind Cluster                                 │
│                                                                      │
│  namespace: games                namespace: monitoring               │
│  ┌─────────────────┐             ┌─────────────────────────────────┐ │
│  │  Super Mario    │──métricas──▶│  Prometheus                     │ │
│  │  Pods           │             │  (coleta e armazena métricas)   │ │
│  │  (stress test   │             └──────────────┬──────────────────┘ │
│  │   via Fortio)   │                            │                    │
│  │                 │──logs──────▶┌──────────────▼──────────────────┐ │
│  └─────────────────┘             │  Loki                           │ │
│                                  │  (armazena logs por labels)     │ │
│  ┌─────────────────┐             └──────────────┬──────────────────┘ │
│  │  Fluent Bit     │─────────────────────────────┘                   │
│  │  (DaemonSet)    │  coleta logs de todos os nodes/pods             │
│  └─────────────────┘                                                 │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │  Grafana  ←── consulta Prometheus (métricas) + Loki (logs)     │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │  Alertmanager  ←── recebe alertas do Prometheus Operator       │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│                                                                      │
│  Node: k8s-essentials-worker                                        │
│  ┌──────────────┐  ┌────────────────────┐                           │
│  │ Node Exporter│  │ kube-state-metrics  │                          │
│  │ CPU/mem/disco│  │ estado dos objetos  │                          │
│  └──────────────┘  └────────────────────┘                           │
└──────────────────────────────────────────────────────────────────────┘
         │              │              │
    localhost:9090  localhost:3000  localhost:9093
     (Prometheus)    (Grafana)    (Alertmanager)

  Loki e Fluent Bit são internos ao cluster (sem exposição externa).
  Grafana acessa o Loki via: http://loki-gateway.monitoring.svc.cluster.local
```

---

## 🔩 Componentes em Detalhe

### Prometheus
**O que é:** Banco de dados de séries temporais (time-series database) especializado em métricas.

**Como funciona:**
- Usa modelo **pull** — ele vai buscar métricas nos targets, não espera receber
- Cada target expõe um endpoint `/metrics` em formato de texto
- Armazena métricas localmente com retenção configurável (padrão: 15 dias)
- Linguagem de consulta: **PromQL** (Prometheus Query Language)

**Por que pull e não push?**
> Com pull, o Prometheus detecta automaticamente quando um target fica indisponível (scrape falha). Com push, você só sabe que algo falhou quando o alerta dispara — já tarde demais.

---

### Grafana
**O que é:** Plataforma de visualização e dashboards, agnóstica de fonte de dados.

**Como funciona:**
- Conecta a múltiplas fontes: Prometheus, Loki, MySQL, Elasticsearch, etc.
- Dashboards são JSONs exportáveis — dá para importar dashboards prontos da comunidade
- Suporta alertas nativos (além do Alertmanager)

**Diferencial neste stack:**
> Você não precisa trocar de ferramenta para ver métricas e logs. No mesmo painel, clica num spike de CPU e vê os logs daquele pod naquele momento.

---

### Loki
**O que é:** Sistema de armazenamento de logs da Grafana Labs, inspirado no Prometheus.

**Como funciona:**
- **Não indexa o conteúdo dos logs** — indexa apenas os **labels** (namespace, pod, container)
- O conteúdo (texto) é comprimido e armazenado em chunks
- Resultado: muito mais barato e rápido que Elasticsearch para a maioria dos casos
- Linguagem de consulta: **LogQL**
- Neste módulo usamos o modo **SingleBinary** (Loki 3.x) — uma única instância gerencia ingestão, armazenamento e queries. Ideal para laboratório; em produção usa-se o modo distribuído com componentes separados de leitura/escrita.
- O **Loki Gateway** é um proxy Nginx que exposto como Service HTTP (porta 80) e roteia as requisições para o Loki. O Grafana e o Fluent Bit se comunicam exclusivamente com o gateway — nunca diretamente com a porta interna 3100.

**Comparação com Elasticsearch:**

| | Loki | Elasticsearch |
|---|---|---|
| Indexação | Só labels | Conteúdo completo |
| Custo de storage | Baixo | Alto |
| Busca por texto livre | Lento (grep) | Rápido |
| Integração Grafana | Nativa | Via plugin |
| Ideal para | Logs de K8s | Search/analytics |

---

### Fluent Bit
**O que é:** Processador e encaminhador de logs ultra-leve, escrito em C, parte da CNCF.

**Como funciona:**
- Roda como **DaemonSet** — um pod por node do cluster
- Lê os arquivos de log dos containers em `/var/log/containers/*.log`
- Parseia, filtra e envia para o Loki (ou outros destinos)
- Neste módulo, o Fluent Bit é instalado **separadamente** do Loki via chart oficial `fluent/fluent-bit`. Ele aponta ao **Loki Gateway** (`loki-gateway.monitoring.svc.cluster.local:80`), não diretamente ao Loki. Esse desacoplamento permite trocar o agente sem reinstalar o banco de logs.

**Por que Fluent Bit em vez de Promtail?**

| | Fluent Bit | Promtail |
|---|---|---|
| Origem | CNCF / Fluent | Grafana Labs |
| Multi-destino | ✅ Loki, ES, S3, Kafka... | ❌ Só Loki |
| Consumo de memória | ~10 MB | ~30 MB |
| Configuração | Mais flexível | Mais simples |
| Padrão de mercado | Amplo | Popular com Loki |

> 💡 Em empresas que já têm Elasticsearch ou Kafka, o Fluent Bit encaminha para múltiplos destinos ao mesmo tempo — sem trocar o agente.

---

### Alertmanager
**O que é:** Gerenciador de alertas do ecossistema Prometheus.

**Como funciona:**
1. Prometheus avalia regras (PrometheusRule) continuamente
2. Quando uma condição é violada, dispara um alerta para o Alertmanager
3. Alertmanager agrupa, deduplica e roteia para canais: Discord, Slack, PagerDuty, e-mail, webhook

**Conceitos importantes:**
- **Firing:** alerta ativo, condição ainda violada
- **Resolved:** condição voltou ao normal
- **Silence:** supressão temporária de alertas (durante manutenção, por exemplo)
- **Inhibition:** alerta A suprime alerta B (ex: node down suprime todos os alertas dos pods daquele node)
- **group_wait / group_interval / repeat_interval:** controles de frequência de notificação — evitam flood de mensagens

**Configuração de roteamento neste módulo:**
O arquivo `helm-values/values-alertmanager-discord.yaml` configura o roteamento de alertas para Discord. Aplique com `helm upgrade --reuse-values -f helm-values/values-alertmanager-discord.yaml`. Veja a seção [Receber Alertas no Discord](#-receber-alertas-no-discord).

---

### Node Exporter
**O que é:** Exporter que expõe métricas do sistema operacional do node.

**Métricas expostas:**
- CPU: `node_cpu_seconds_total`
- Memória: `node_memory_MemAvailable_bytes`
- Disco: `node_filesystem_avail_bytes`
- Rede: `node_network_receive_bytes_total`

---

### kube-state-metrics
**O que é:** Serviço que converte o estado dos objetos Kubernetes em métricas Prometheus.

**Exemplos de métricas:**
- `kube_pod_status_ready` — pod está Ready?
- `kube_deployment_status_replicas` — quantas réplicas estão rodando?
- `kube_horizontalpodautoscaler_status_current_replicas` — réplicas atuais do HPA
- `kube_pod_container_status_restarts_total` — quantas vezes o container reiniciou?

> 📌 **Diferença importante:** Node Exporter mede recursos do **sistema operacional**. kube-state-metrics mede o **estado dos objetos Kubernetes**. Os dois são necessários.

---

### Prometheus Operator
**O que é:** Controlador Kubernetes que gerencia o Prometheus via CRDs (Custom Resource Definitions).

**CRDs que ele adiciona ao cluster:**
- `PrometheusRule` → define regras de alerta como YAML no cluster
- `ServiceMonitor` → diz ao Prometheus quais Services monitorar
- `PodMonitor` → diz ao Prometheus quais Pods monitorar

**Por que isso importa?**
> Sem o Operator, você editaria arquivos de configuração do Prometheus manualmente e reiniciaria o pod. Com o Operator, você aplica um `kubectl apply -f alerta.yaml` e o Prometheus recarrega automaticamente.

---

## �️ Como Usar Cada Componente

### Prometheus — http://localhost:9090

| O que fazer | Caminho na UI |
|---|---|
| Ver quais endpoints estão sendo coletados | **Status → Targets** |
| Confirmar que os alertas foram carregados | **Status → Rule Health** |
| Ver alertas ativos (Pending/Firing) | **Alerts** |
| Executar queries PromQL | **Graph** |

Queries úteis para o Super Mario:
```promql
# Pods rodando
kube_pod_info{namespace="games"}

# CPU dos pods (média 2 min)
sum(rate(container_cpu_usage_seconds_total{namespace="games"}[2m])) by (pod)

# Réplicas do HPA
kube_horizontalpodautoscaler_status_current_replicas{namespace="games"}
```

---

### Grafana — http://localhost:3000

**Login:** usuário `admin` / senha: veja o QUICK-START.md

| O que fazer | Caminho na UI |
|---|---|
| Ver dashboards prontos do cluster | **Dashboards → Browse → Kubernetes** |
| Importar dashboard da comunidade | **Dashboards → New → Import → ID `15661`** |
| Consultar métricas via PromQL | **Explore → selecione Prometheus** |
| Consultar logs por label | **Explore → selecione Loki** |
| Configurar datasources | **Connections → Data Sources** |
| Cadastrar contact point (Discord, Slack...) | **Alerting → Contact Points** |
| Configurar roteamento de alertas | **Alerting → Notification Policies** |

Query LogQL para ver logs do Super Mario:
```logql
{kubernetes_namespace_name="games", kubernetes_container_name="super-mario"}
```

> ⚠️ Ajuste o intervalo de tempo para **"Last 1 hour"** antes de rodar a query — o Loki rejeita queries sem range de tempo explícito.

---

### Loki — acesso interno ao cluster

O Loki não é exposto externamente. Acesso via:
- **Grafana Explore** (caminho normal)
- **Port-forward** para diagnóstico direto:

```sh
kubectl port-forward svc/loki-gateway -n monitoring 3100:80
```

Diagnóstico via API (depois do port-forward):

**PowerShell:**
```powershell
# Namespaces indexados
$start = [DateTimeOffset]::UtcNow.AddHours(-1).ToUnixTimeSeconds()
Invoke-RestMethod "http://localhost:3100/loki/api/v1/label/kubernetes_namespace_name/values?start=$start"

# Containers indexados
Invoke-RestMethod "http://localhost:3100/loki/api/v1/label/kubernetes_container_name/values?start=$start"
```

**bash / zsh:**
```bash
start=$(date -d '1 hour ago' +%s)
curl -sG "http://localhost:3100/loki/api/v1/label/kubernetes_namespace_name/values?start=$start"
```

Labels indexados pelo Fluent Bit neste módulo:

| Label Loki | O que representa |
|---|---|
| `kubernetes_namespace_name` | Namespace do pod (ex: `games`) |
| `kubernetes_pod_name` | Nome do pod |
| `kubernetes_container_name` | Nome do container |
| `job` | Sempre `fluent-bit` (label estático) |
| Labels do pod | Labels definidos no `metadata.labels` do pod (ex: `app=super-mario`) |

---

### Alertmanager — http://localhost:9093

| O que fazer | Caminho na UI |
|---|---|
| Ver alertas FIRING agora | **Alerts** |
| Criar silêncio (suprimir alerta) | **Silences → New Silence** |
| Verificar a config carregada | **Status** |
| Confirmar que o Discord foi configurado | **Status → Config → busque `discord`** |

Consultar alertas via API:

**PowerShell:**
```powershell
(Invoke-RestMethod "http://localhost:9093/api/v2/alerts") |
  Select-Object -ExpandProperty labels |
  Format-Table alertname, namespace, severity
```

**bash / zsh:**
```bash
curl -s http://localhost:9093/api/v2/alerts | jq '.[].labels | {alertname, namespace, severity}'
```

---

## 📁 Estrutura do Módulo

```
modulo-03-monitoring/
├── README.md                               ← Este arquivo
├── QUICK-START.md                          ← Passo a passo completo com explicações
├── HELM.md                                 ← Guia de Helm: conceitos, comandos e como foi usado no módulo
├── helm-values/                            ← Values Helm de todos os releases (fonte da verdade)
│   ├── values-prometheus-stack.yaml        ← kube-prometheus-stack: NodePorts, externalUrl
│   ├── values-loki.yaml                    ← Loki: SingleBinary, filesystem, sem cache
│   ├── values-fluent-bit.yaml              ← Fluent Bit: output → Loki Gateway
│   ├── values-alertmanager-discord.yaml    ← Alertmanager: receiver Discord (URL direta)
│   └── values-alertmanager-discord-secret.yaml  ← Alertmanager: receiver Discord (Secret K8s)
└── manifests/                              ← Recursos Kubernetes (não Helm)
    ├── README.md                           ← Documentação dos manifestos
    ├── cluster-config.yaml                 ← Kind com todos os port mappings
    └── 03-four-golden-signals.yaml         ← PrometheusRule: alertas dos 4 Golden Signals
```

---

## 🚀 Início Rápido

Veja o [QUICK-START.md](./QUICK-START.md) para instalação passo a passo de todo o stack.

---

## 🚨 Alertas dos Four Golden Signals

Os alertas estão definidos em [`manifests/03-four-golden-signals.yaml`](./manifests/03-four-golden-signals.yaml) como um `PrometheusRule` — recurso nativo do Prometheus Operator.

### Como funciona o ciclo de alerta

```
1. Prometheus avalia a expr PromQL a cada 15s (padrão)
2. Se a condição for verdadeira, o alerta entra em estado "Pending"
3. Após o tempo definido em `for:`, entra em "Firing"
4. Prometheus envia para o Alertmanager
5. Alertmanager roteia para Slack/e-mail/PagerDuty
```

### Resumo dos alertas criados

| Signal | Nome do Alerta | Condição | Severidade |
|---|---|---|---|
| Tráfego | `AltoTrafego` | Rede > 1 MB/s por 2min | warning |
| Erros | `PodRestartandoFrequentemente` | > 2 restarts em 15min | critical |
| Erros | `PodNaoDisponivel` | Pod não-Ready por 5min | critical |
| Saturação | `AltoCPUSuperMario` | CPU > 80% do limit por 3min | warning |
| Saturação | `AltaMemoriaSuperMario` | Memória > 80% do limit por 3min | warning |
| Latência | `HPANoLimiteMaximo` | HPA em réplicas máximas por 5min | warning |

> ⚠️ **Sobre o alerta de Latência:** O Super Mario não expõe métricas HTTP nativas (como `http_request_duration_seconds`). O alerta usa como proxy o HPA atingir o máximo de réplicas — situação em que o sistema não consegue mais escalar para absorver carga, indicando risco de degradação de latência. Em aplicações instrumentadas (Spring Boot, FastAPI, etc.), substituir pela métrica real de duração HTTP.

---

## � Receber Alertas no Discord

O Grafana, com o kube-prometheus-stack, gerencia o Alertmanager via API interna. Isso significa que contact points e notification policies configurados no Grafana são escritos diretamente no Alertmanager — sem editar YAMLs.

### Passos rápidos

| Passo | Onde | O que fazer |
|---|---|---|
| 1 | Discord | Criar webhook: **Config do canal → Integrações → Webhooks → Novo Webhook** |
| 2 | Grafana | **Alerting → Contact Points → + Add** → tipo Discord → colar URL → Test → Save |
| 3 | Grafana | **Alerting → Notification Policies → Edit Default** → selecionar contact point Discord |
| 4 | Terminal | `kubectl apply -f ../modulo-02-deploy-app/manifests/04-stress-test-fortio.yaml` |
| 5 | Discord | Aguardar ~5 min e ver o alerta chegar no canal |

### Fluxo do alerta

```
PrometheusRule (FIRING)
    │
    ▼
Prometheus → Alertmanager
    │
    │  Grafana escreve a config do Alertmanager via API
    │  (contact point Discord + notification policy)
    │
    ▼ Notification Policy
    ├── Watchdog / InfoInhibitor  →  descartado
    └── qualquer outro           →  discord-k8s-essentials
                                         │
                                         ▼ HTTPS POST
                                 discord.com/api/webhooks/...
```

> Instruções completas com prints e troubleshooting no [QUICK-START.md](./QUICK-START.md).

---

## 🧪 Questões de Fixação

**Fase 1 — Os Três Pilares**

1. Qual é a diferença entre uma métrica e um log? Dê um exemplo de cada para o Super Mario.
2. Por que o Prometheus usa modelo **pull** em vez de **push**? Qual é a vantagem prática?
3. Por que o Loki não indexa o conteúdo dos logs? O que ele indexa e qual o benefício?

**Fase 2 — Four Golden Signals**

4. Um pod do Mario está respondendo com HTTP 200 mas retornando uma página em branco. Qual dos Four Golden Signals capturaria esse problema? Por quê?
5. Durante o stress test, a CPU sobe para 95% do limit e o HPA cria mais pods. Qual signal representa a CPU alta? E o aumento de réplicas, qual signal ele endereça?
6. O alerta `PodRestartandoFrequentemente` usa `increase(...) > 2`. Por que usar `increase` em vez de comparar o valor absoluto do contador de restarts?

**Fase 3 — Arquitetura**

7. O Fluent Bit roda como DaemonSet. O que isso significa em termos práticos para um cluster com 5 nodes?
8. Qual é a diferença entre `Node Exporter` e `kube-state-metrics`? Você precisaria dos dois se tivesse apenas um node?
9. Se o Alertmanager receber o mesmo alerta 50 vezes em 1 minuto (de 50 pods diferentes), ele dispara 50 notificações? O que evita isso?

**Fase 4 — Logs e Discord**

10. Por que o label do Loki para o namespace chama `kubernetes_namespace_name` e não só `namespace`? De onde vem esse nome?
11. O Grafana tem **Contact Points** e o Alertmanager também recebe notificações. Qual é a relação entre os dois no kube-prometheus-stack? Quando você salva um contact point no Grafana, o que acontece no Alertmanager?
12. No Discord contact point, existe uma rota que descarta os alertas `Watchdog` e `InfoInhibitor`. Por que esses alertas existem no Prometheus mas não devem gerar notificações?

---

## 📖 Recursos Adicionais

- [Site Reliability Engineering — Google (Four Golden Signals)](https://sre.google/sre-book/monitoring-distributed-systems/)
- [kube-prometheus-stack no ArtifactHub](https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack)
- [Loki — Documentação oficial](https://grafana.com/docs/loki/latest/)
- [Fluent Bit para Kubernetes](https://docs.fluentbit.io/manual/installation/kubernetes)
- [PromQL Cheat Sheet](https://promlabs.com/promql-cheat-sheet/)
- [LogQL — Linguagem de query do Loki](https://grafana.com/docs/loki/latest/query/)
- [Grafana Dashboard Kubernetes (ID 15661)](https://grafana.com/grafana/dashboards/15661)
