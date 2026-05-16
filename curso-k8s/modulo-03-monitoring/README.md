# 📊 Módulo 03: Observabilidade com Prometheus, Grafana, Loki e Fluent Bit

## 📋 Índice

1. [Visão Geral](#-visão-geral)
2. [O Problema Real que Isso Resolve](#-o-problema-real-que-isso-resolve)
3. [Os Três Pilares da Observabilidade](#-os-três-pilares-da-observabilidade)
4. [Os Four Golden Signals](#-os-four-golden-signals)
5. [Arquitetura do Stack](#-arquitetura-do-stack)
6. [Componentes em Detalhe](#-componentes-em-detalhe)
7. [Estrutura do Módulo](#-estrutura-do-módulo)
8. [Início Rápido](#-início-rápido)
9. [Alertas dos Four Golden Signals](#-alertas-dos-four-golden-signals)
10. [Questões de Fixação](#-questões-de-fixação)
11. [Recursos Adicionais](#-recursos-adicionais)

---

## 📚 Visão Geral

No **Módulo 02**, o HPA escalou os pods automaticamente durante o stress test — mas você só conseguia enxergar isso com `kubectl top`, uma linha por vez, sem histórico e sem contexto.

Este módulo monta o stack completo de observabilidade usado em produção:

- **Métricas** → Prometheus coleta, Grafana exibe
- **Logs** → Fluent Bit coleta, Loki armazena, Grafana exibe
- **Alertas** → Alertmanager dispara quando os **Four Golden Signals** saem do normal

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

> 📌 **Neste módulo** implementamos **métricas** e **logs**. Traces ficam para um módulo avançado de service mesh.

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
         │              │              │              │
    localhost:9090  localhost:3000  localhost:9093  localhost:3100
     (Prometheus)    (Grafana)    (Alertmanager)    (Loki)
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
3. Alertmanager agrupa, deduplica e roteia para canais: Slack, PagerDuty, e-mail, webhook

**Conceitos importantes:**
- **Firing:** alerta ativo, condição ainda violada
- **Resolved:** condição voltou ao normal
- **Silence:** supressão temporária de alertas (durante manutenção, por exemplo)
- **Inhibition:** alerta A suprime alerta B (ex: node down suprime todos os alertas dos pods daquele node)

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

## 📁 Estrutura do Módulo

```
modulo-03-monitoring/
├── README.md                          ← Este arquivo
├── QUICK-START.md                     ← Passo a passo completo
└── manifests/
    ├── README.md                      ← Documentação dos manifestos
    ├── cluster-config.yaml            ← Kind com todos os port mappings
    └── 03-four-golden-signals.yaml    ← PrometheusRule com alertas
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

---

## 📖 Recursos Adicionais

- [Site Reliability Engineering — Google (Four Golden Signals)](https://sre.google/sre-book/monitoring-distributed-systems/)
- [kube-prometheus-stack no ArtifactHub](https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack)
- [Loki — Documentação oficial](https://grafana.com/docs/loki/latest/)
- [Fluent Bit para Kubernetes](https://docs.fluentbit.io/manual/installation/kubernetes)
- [PromQL Cheat Sheet](https://promlabs.com/promql-cheat-sheet/)
- [LogQL — Linguagem de query do Loki](https://grafana.com/docs/loki/latest/query/)
- [Grafana Dashboard Kubernetes (ID 15661)](https://grafana.com/grafana/dashboards/15661)


## 📋 Índice

1. [Visão Geral](#-visão-geral)
2. [Objetivos de Aprendizado](#-objetivos-de-aprendizado)
3. [O Problema Real que Isso Resolve](#-o-problema-real-que-isso-resolve)
4. [Pré-requisitos](#-pré-requisitos)
5. [Arquitetura do Stack](#-arquitetura-do-stack)
6. [Estrutura do Módulo](#-estrutura-do-módulo)
7. [Início Rápido](#-início-rápido)
8. [O que Observar Durante o Stress Test](#-o-que-observar-durante-o-stress-test)
9. [Questões de Fixação](#-questões-de-fixação)
10. [Recursos Adicionais](#-recursos-adicionais)

---

## 📚 Visão Geral

No **Módulo 02**, você viu o HPA criar e destruir pods automaticamente durante o stress test. Impressionante, certo? Mas você estava monitorando via `kubectl top` — linha de linha, sem histórico, sem contexto visual.

Agora a pergunta é: **como uma equipe de produção acompanha tudo isso?**

A resposta é o **kube-prometheus-stack** — o stack de monitoramento mais usado no mundo Kubernetes, composto por:

- **Prometheus** → coleta e armazena métricas de todo o cluster
- **Grafana** → dashboards visuais com gráficos em tempo real
- **Alertmanager** → dispara alertas quando algo sai do normal
- **Node Exporter** → expõe métricas de CPU, memória e disco dos nodes
- **kube-state-metrics** → expõe estado dos objetos Kubernetes (pods, deployments, etc.)

> 🎬 **Cenário real:** Você é o engenheiro de plantão. O Super Mario (do Módulo 02) começa a receber tráfego intenso. Com esse stack, você vê em tempo real quais pods estão sobrecarregados, quando o HPA atuou, e recebe um alerta antes do serviço cair.

---

## 🎯 Objetivos de Aprendizado

Ao final deste módulo, você será capaz de:

- ✅ Instalar o kube-prometheus-stack via Helm no Kind
- ✅ Acessar o Prometheus e consultar métricas com PromQL
- ✅ Navegar nos dashboards do Grafana
- ✅ Correlacionar eventos de stress test com métricas observadas
- ✅ Entender o papel do ServiceMonitor na coleta de métricas
- ✅ Reconhecer os componentes do stack de observabilidade

**⏱️ Duração Estimada:** 45 minutos

---

## 🔥 O Problema Real que Isso Resolve

### Sem Monitoramento (o que você tinha no Módulo 02)

```
kubectl top pods -n games
# CPU e memória instantâneos. Sem histórico. Sem alertas. Sem gráficos.
# Se você não estava olhando na hora certa... perdeu.
```

### Com Monitoramento (o que você terá agora)

```
Prometheus → armazena métricas dos últimos 15 dias
Grafana    → você abre um dashboard e vê o gráfico de CPU durante o stress test
             mesmo que tenha sido 3 dias atrás às 2h da manhã
Alertmanager → você recebe um aviso antes de o serviço degradar
```

---

## 📦 Pré-requisitos

- ✅ Módulo 01 concluído (Kind funcionando)
- ✅ Módulo 02 concluído (Super Mario deployado, stress test executado)
- ✅ **Helm** instalado (`helm version`)
- ✅ **kubectl** configurado para o cluster `k8s-essentials`

### Instalar Helm (se necessário)

```powershell
# Windows (via Chocolatey)
choco install kubernetes-helm

# Ou via script oficial
winget install Helm.Helm
```

Verificar:
```powershell
helm version
# version.BuildInfo{Version:"v3.x.x", ...}
```

---

## 🏗️ Arquitetura do Stack

```
┌─────────────────────────────────────────────────────────┐
│                    Kind Cluster                          │
│                                                          │
│  namespace: games              namespace: monitoring     │
│  ┌──────────────────┐         ┌──────────────────────┐  │
│  │  Super Mario Pod │◄────────│  Prometheus           │  │
│  │  (alvo do scrape)│  coleta │  (metrics store)      │  │
│  └──────────────────┘  métr.  └──────────┬───────────┘  │
│                                          │               │
│                                ┌─────────▼────────────┐  │
│                                │  Grafana              │  │
│                                │  (dashboards visuais) │  │
│                                └──────────────────────┘  │
│                                                          │
│  Node: k8s-essentials-worker                            │
│  ┌──────────────────┐                                   │
│  │  Node Exporter   │─── CPU, Memória, Disco do Node    │
│  └──────────────────┘                                   │
└─────────────────────────────────────────────────────────┘
         │              │              │
    localhost:9090  localhost:3000  localhost:9093
     (Prometheus)    (Grafana)    (Alertmanager)
```

---

## 📁 Estrutura do Módulo

```
modulo-03-monitoring/
├── README.md              ← Este arquivo
├── QUICK-START.md         ← Passo a passo rápido (15 min)
└── manifests/
    ├── README.md          ← Documentação dos manifestos
    └── cluster-config.yaml ← Kind com port mappings adicionais
```

---

## 🚀 Início Rápido

Veja o [QUICK-START.md](./QUICK-START.md) para o passo a passo completo.

---

## 👁️ O que Observar Durante o Stress Test

### No Grafana → Dashboard "Kubernetes / Compute Resources / Namespace (Pods)"

Após rodar o Fortio do Módulo 02 (`kubectl apply -f manifests/04-stress-test-fortio.yaml -n games`), observe:

| Métrica | O que significa |
|---|---|
| CPU Usage (spike) | Carga gerada pelo Fortio chegando nos pods do Mario |
| Memory Working Set | Consumo de memória dos pods em tempo real |
| Network Receive / Transmit | Tráfego HTTP sendo processado |
| Pod count (sobe) | HPA criando novos pods para absorver a carga |
| Pod count (cai) | HPA removendo pods após fim do stress test |

### No Prometheus → Queries PromQL úteis

```promql
# CPU de todos os pods no namespace games
sum(rate(container_cpu_usage_seconds_total{namespace="games"}[2m])) by (pod)

# Memória dos pods do Mario
container_memory_working_set_bytes{namespace="games", container="mario"}

# Número de pods do Mario ao longo do tempo
kube_deployment_status_replicas{namespace="games", deployment="super-mario"}

# Requisições HTTP recebidas pelo Mario
rate(http_requests_total{namespace="games"}[1m])
```

---

## 🧪 Questões de Fixação

**Fase 1 — Conceitual**

1. O Prometheus coleta métricas de forma **push** (aplicação envia) ou **pull** (Prometheus busca)?
2. Qual componente do stack expõe métricas de CPU e memória dos nodes físicos?
3. O que é um **ServiceMonitor** e como ele instrui o Prometheus a monitorar um serviço?

**Fase 2 — Prática**

4. No Grafana, abra o dashboard *"Kubernetes / Compute Resources / Namespace (Pods)"*, selecione o namespace `games` e rode o stress test. Quantos pods o HPA criou no pico?
5. No Prometheus, escreva uma query PromQL que mostre a taxa de CPU dos pods do namespace `games` nos últimos 5 minutos.
6. Quanto tempo após o fim do stress test o HPA levou para reduzir os pods de volta ao mínimo? O que controla esse comportamento?

**Fase 3 — Reflexão**

7. Em produção, qual seria o problema de usar NodePort para expor o Grafana externamente? Qual alternativa seria mais segura?
8. O Alertmanager está instalado mas sem regras configuradas. Que tipo de alerta você criaria primeiro para monitorar o namespace `games`?

---

## 📖 Recursos Adicionais

- [kube-prometheus-stack no ArtifactHub](https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack)
- [Documentação oficial do Prometheus](https://prometheus.io/docs/)
- [PromQL Cheat Sheet](https://promlabs.com/promql-cheat-sheet/)
- [Grafana Dashboard para Kubernetes](https://grafana.com/grafana/dashboards/15661)
