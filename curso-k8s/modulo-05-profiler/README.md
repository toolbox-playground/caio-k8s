# 🔥 Módulo 05: Profiling Contínuo com Grafana Pyroscope

## 📋 Índice

1. [Visão Geral](#-visão-geral)
2. [O Problema que o Profiler Resolve](#-o-problema-que-o-profiler-resolve)
3. [O que é um Profiler?](#-o-que-é-um-profiler)
4. [Continuous Profiling vs Profiling Pontual](#-continuous-profiling-vs-profiling-pontual)
5. [Como Ler um Flame Graph](#-como-ler-um-flame-graph)
6. [Os Quatro Pilares da Observabilidade](#-os-quatro-pilares-da-observabilidade)
7. [Arquitetura do Stack](#-arquitetura-do-stack)
8. [Grafana Pyroscope em Detalhe](#-grafana-pyroscope-em-detalhe)
9. [Casos de Uso Reais](#-casos-de-uso-reais)
10. [Estrutura do Módulo](#-estrutura-do-módulo)
11. [Início Rápido](#-início-rápido)
12. [Trace to Profile — A Integração Matadora](#-trace-to-profile--a-integração-matadora)
13. [Questões de Fixação](#-questões-de-fixação)
14. [Recursos Adicionais](#-recursos-adicionais)

---

## 📚 Visão Geral

Nos módulos anteriores você adicionou três camadas de observabilidade à `ranking-api`:

| Módulo | Pilar       | Ferramenta | Pergunta respondida                    |
|--------|-------------|------------|----------------------------------------|
| 03     | Métricas    | Prometheus | *Quanto?* (CPU 82%, 1.200 req/s)       |
| 03     | Logs        | Loki       | *O quê?* ("NullPointerException linha 47") |
| 04     | Traces      | Tempo      | *Onde na requisição?* (span db-read 200ms) |
| **05** | **Profiles**| **Pyroscope** | ***Por quê?*** (qual função consome CPU?) |

O **Módulo 05** fecha o ciclo: você sabe que a requisição está lenta, sabe em qual span, e agora vai descobrir **exatamente qual linha de código** dentro desse span está consumindo os recursos.

> 🎬 **Cenário real:** O time de operações abre um alerta no Slack: `p99 latência > 800ms` no `/rankings`. Você abre o Grafana, navega para o Tempo, encontra uma requisição com 820ms, clica no span `db-read` de 790ms, e então clica em **"View profile"**. O flame graph mostra que 67% do tempo dentro desse span está em `json.loads()` — alguém commitou um payload de ranking que tem 40MB de histórico acumulado. Sem o profiler, você teria que adivinhar ou adicionar `print(time.time())` em 20 lugares.

---

## 🔥 O Problema que o Profiler Resolve

```
Métricas dizem:  "O serviço está consumindo 90% de CPU."
Logs dizem:      "Requisições estão demorando mais que 500ms."
Traces dizem:    "O span 'calcular-ranking' leva 420ms de 500ms totais."
Profiler diz:    "62% do tempo do 'calcular-ranking' é gasto em sorted()
                  porque a lista tem 50.000 elementos sem paginação."
```

### O Gap entre Traces e Código

Um trace diz *qual span* é o gargalo. Mas um span pode ter centenas de linhas de código. O profiler vai ainda mais fundo: mostra o **call stack completo** — qual função chamou qual, e quanto tempo cada uma ocupou.

```
Trace (Tempo)              →  Profiler (Pyroscope)
────────────────────────      ─────────────────────────────────
span: calcular-ranking        calcular_ranking()  100%
  [420ms]                       └─ sorted()         62%
                                    └─ __lt__()     60%
                                └─ _build_list()    35%
                                    └─ json.loads() 34%
                                └─ logging.info()   3%
```

---

## 🔬 O que é um Profiler?

Um profiler é uma ferramenta que **amostra o call stack** de um processo em execução em intervalos regulares para descobrir onde o tempo (ou memória) está sendo gasto.

### Como funciona o sampling

```
Tempo →  0ms   10ms  20ms  30ms  40ms  50ms  60ms  70ms  80ms  90ms  100ms
         ────────────────────────────────────────────────────────────────────
Amostra  [A]   [A]   [B]   [B]   [B]   [A]   [C]   [B]   [A]   [A]   [A]
         │                              │           │
         └── Snapshot do call           └── Snap    └── Snap
             stack neste instante
```

Se a função `A` aparece em 6 de 10 amostras → ela ocupa ~60% do tempo.

> ⚡ **Por que sampling e não instrumentação linha a linha?**  
> Instrumentar cada linha de código (tracing) geraria overhead de 20-50%. O sampling olha o estado do processo periodicamente (a cada 10ms), causando <1% de overhead. É por isso que o profiling contínuo em produção é viável.

### O que um profiler mede

| Tipo de Profile    | O que mede                          | Caso de uso                          |
|--------------------|--------------------------------------|--------------------------------------|
| CPU                | Tempo de CPU gasto por função        | Otimizar algoritmos lentos           |
| Memory/Heap        | Alocações de memória por função      | Encontrar memory leaks               |
| Goroutines (Go)    | Número de goroutines por função      | Detectar goroutine leaks             |
| Mutex              | Tempo esperando por locks            | Diagnosticar deadlocks/contenção     |
| Block              | Tempo bloqueado em I/O ou channels   | Tuning de I/O e concorrência         |
| Inuse Objects      | Objetos vivos no heap                | Otimizar uso de memória atual        |

---

## ⏱️ Continuous Profiling vs Profiling Pontual

### Profiling Pontual (tradicional)
```bash
python -m cProfile -o profile.out meu_script.py
snakeviz profile.out
```

**Problemas:**
- Você precisa **reproduzir** o problema (às vezes impossível em produção)
- Muda o comportamento do sistema (overhead alto)
- Sem histórico — você não sabe o que mudou entre deploys

### Continuous Profiling (Pyroscope)

```
┌──────────────────────────────────────────────────────────┐
│  Pyroscope SDK (dentro da aplicação)                     │
│                                                          │
│  A cada 15 segundos:                                     │
│  1. Captura snapshot do call stack                       │
│  2. Agrega amostras em um "profile"                      │
│  3. Envia para o Pyroscope Server via HTTP               │
└──────────────────────────────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────┐
│  Pyroscope Server                                        │
│                                                          │
│  - Armazena profiles indexados por: serviço, host, labels│
│  - Permite consultar qualquer janela de tempo no passado  │
│  - Serve dados via API para o Grafana                    │
└──────────────────────────────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────┐
│  Grafana (datasource: Pyroscope)                         │
│                                                          │
│  - Exibe flame graphs interativos                        │
│  - Compara dois períodos de tempo (diff flame graph)     │
│  - Correlaciona com traces do Tempo                      │
└──────────────────────────────────────────────────────────┘
```

**Vantagens do continuous profiling:**
- **Histórico completo** — compare o perfil antes e depois de um deploy
- **Baixo overhead** — <1% de CPU/memória extra
- **Sem reprodução** — o problema já estava sendo gravado quando aconteceu
- **Correlação temporal** — "o que estava consumindo CPU durante o incidente das 14h23?"

---

## 📊 Como Ler um Flame Graph

O flame graph é a principal visualização do Pyroscope. Parece complicado, mas a lógica é simples:

```
┌──────────────────────────────────────────────────────────────────────┐
│  app.get_rankings()                                                  │  ← raiz (base)
├───────────────────────────┬─────────────────────────────────────────┤
│  sorted()                 │  _build_payload()                        │  ← filhos diretos
├────────────┬──────────────┼──────────────────────────┬──────────────┤
│  __lt__()  │  __eq__()    │  json.loads()            │  str.encode  │
├────────────┴──────────────┴──────────────────────────┴──────────────┤
│            (frames mais profundos do call stack)                     │  ← folhas (topo)
└──────────────────────────────────────────────────────────────────────┘

Eixo X: largura = % do tempo total  (mais largo = mais lento)
Eixo Y: profundidade do call stack  (raiz em baixo, folhas em cima)
```

### Regras de leitura

1. **Largura = tempo** — blocos mais largos consomem mais CPU/memória
2. **Altura = profundidade** — um bloco alto com muitos filhos indica uma cadeia de chamadas profunda
3. **Plateau (topo plano)** — funções sem filhos são onde o tempo é realmente gasto (folhas)
4. **Cor** — geralmente por módulo/biblioteca. Vermelho/laranja: framework. Azul: stdlib. Verde: seu código

### O que procurar

```
RUIM (gargalo óbvio):          BOM (trabalho bem distribuído):

┌──────────────────────────┐   ┌────────┬────────┬────────┐
│  minha_funcao()          │   │  f1()  │  f2()  │  f3()  │
├──────────────────────────┤   ├────────┴────────┴────────┤
│  json.loads() [82%!!]    │   │      app.handler()       │
└──────────────────────────┘   └──────────────────────────┘

→ json.loads ocupa 82% de tudo   → tempo bem distribuído entre funções
```

---

## 🏛️ Os Quatro Pilares da Observabilidade

Com este módulo o stack fica completo:

```
                    OBSERVABILIDADE COMPLETA
                    ────────────────────────

  📊 MÉTRICAS        📜 LOGS           🔭 TRACES          🔥 PROFILES
  (Prometheus)       (Loki)            (Tempo/OTel)       (Pyroscope)
  ──────────────     ──────────────    ──────────────     ──────────────
  O quê e quanto     Eventos           Jornada da         Custo real de
  agregado no        discretos         requisição         cada função
  tempo              com contexto      pelo sistema       no runtime

  "CPU 90%"          "Error: player    "db-read levou     "sorted() usou
                      not found"        420ms"             62% do tempo"
```

> As três primeiras colunas respondem **o quê**. O profiler responde **por quê**.

---

## 🏗️ Arquitetura do Stack

```
┌─────────────────── Namespace: games ───────────────────────────────────────────┐
│                                                                                │
│   ranking-api (Python + FastAPI)                                               │
│   ├── OTel SDK → traces, métricas, logs → OTel Collector (namespace: otel)    │
│   └── pyroscope-io SDK → CPU profiles → Pyroscope (namespace: monitoring)     │
│                                                                                │
└────────────────────────────────────────────────────────────────────────────────┘
                │                                    │
                ▼                                    ▼
┌─────── Namespace: otel ────────┐   ┌──── Namespace: monitoring ────────────────┐
│  OTel Collector                │   │                                           │
│  ├── → Tempo (traces)          │   │  Prometheus  Loki  Grafana  Pyroscope     │
│  ├── → Prometheus (métricas)   │   │  ─────────────────────────────────────    │
│  └── → Loki (logs)             │   │  Todos conectados como datasources        │
└────────────────────────────────┘   │  no Grafana                               │
                                     └───────────────────────────────────────────┘

Grafana Datasources configurados:
  • Prometheus  → http://prometheus-operated:9090
  • Loki        → http://loki:3100
  • Tempo       → http://tempo:3100
  • Pyroscope   → http://pyroscope:4040   ← novo neste módulo
```

---

## 🔭 Grafana Pyroscope em Detalhe

### O que é

Grafana Pyroscope é um servidor de **continuous profiling** open-source. Ele é o backend que armazena e serve os dados de profiling para o Grafana. Originalmente era o projeto **Phlare** do Grafana Labs, que foi renomeado/fundido com o Pyroscope (open-source).

### Como o SDK Python envia dados

```python
import pyroscope

pyroscope.configure(
    application_name="ranking-api",
    server_address="http://pyroscope.monitoring.svc.cluster.local:4040",
    tags={
        "environment": "kind-dev",
        "version":     "2.0.0",
    },
)
```

O SDK (`pyroscope-io`):
1. Inicia um thread de sampling em background
2. A cada 15 segundos (padrão) amostra o call stack Python usando `py-spy`
3. Agrega as amostras num perfil comprimido
4. Faz `HTTP POST` para `<server>/ingest` com os dados

### Labels em Pyroscope

Labels no Pyroscope funcionam como labels no Prometheus: permitem filtrar e agrupar profiles.

```python
# Labels fixos (definidos no .configure())
tags = {
    "environment": "kind-dev",  # ambiente
    "version":     "2.0.0",     # versão do deploy
}

# Labels dinâmicos (por bloco de código)
with pyroscope.tag_wrapper({"endpoint": "/rankings", "method": "GET"}):
    # todo o código aqui é taggeado com esse endpoint
    resultado = calcular_rankings()
```

Com labels dinâmicos você consegue comparar no Grafana:
- "Como o perfil do `/rankings` compara com o do `/score`?"
- "O deploy v2.0.0 melhorou o CPU vs v1.9.5?"

---

## 🎯 Casos de Uso Reais

### 1. Memory Leak em Produção
**Sintoma:** Memory usage do pod sobe ~2MB/hora. Após 3 dias, OOMKill.  
**Sem profiler:** Reinicia o pod periodicamente. Problema volta.  
**Com Pyroscope:** Flame graph de memória mostra que `cache_manager.add()` acumula objetos em um dict que nunca é limpo. Fix: adicionar TTL ao cache.

### 2. Deploy com Regressão de Performance
**Sintoma:** Após o deploy das 16h, p99 subiu de 120ms para 380ms.  
**Sem profiler:** Rollback no escuro ou "diff flame graph" mental do código.  
**Com Pyroscope:** Diff flame graph (antes × depois) mostra que a nova função `enrich_with_history()` apareceu no perfil consumindo 65% do tempo. PR foi revertido em 5 minutos.

### 3. Otimização de Custo em Cloud
**Sintoma:** A conta AWS/GCP aumentou 40% sem mudança de tráfego.  
**Sem profiler:** Olhar as métricas de CPU e "achar" o culpado por tentativa e erro.  
**Com Pyroscope:** O serviço de relatórios usa `pandas.DataFrame.apply()` em um loop que poderia ser vetorizado. Mesmo número de requisições, 3x menos CPU. Custo reduz para antes do aumento.

### 4. Investigação de Incidente (integração com Traces)
**Sintoma:** Alerta dispara: `p99 > 500ms` por 10 minutos entre 14h22 e 14h32.  
**Com Pyroscope + Tempo:**
1. Abrir Grafana Explore → Datasource: Tempo
2. Filtrar traces com duração > 400ms naquele período
3. Clicar em um trace → clicar no span lento
4. Clicar em **"View in Pyroscope"** (botão de correlação)
5. Ver o flame graph daquele serviço naquele exato período de 10 minutos

### 5. Comparação de Implementações (A/B Profiling)
**Cenário:** Reescrever a função de ordenação de rankings. Qual versão é mais eficiente?  
**Com Pyroscope:**
- Deploy v2.0.0 com label `version=v2`
- Grafana: comparar perfil `version=v1` vs `version=v2`
- Diff flame graph mostra qual versão aloca menos memória e usa menos CPU

---

## 📁 Estrutura do Módulo

Este módulo oferece **duas abordagens** de profiling. Escolha a que se encaixa no seu cenário:

```
modulo-05-profiler/
├── README.md                      ← você está aqui (teoria)
├── QUICK-START.md                 ← índice das duas abordagens
│
├── pyroscope-sdk/                 ← Abordagem 1: SDK dentro da aplicação
│   ├── README.md                  ← quando usar, o que muda, tag_wrapper
│   ├── QUICK-START.md             ← guia passo a passo
│   ├── app/
│   │   ├── main.py                ← ranking-api v2 com pyroscope.configure() + tag_wrapper
│   │   ├── requirements.txt       ← + pyroscope-io==0.8.7
│   │   └── Dockerfile             ← + gcc/python3-dev para compilar o SDK C
│   ├── helm-values/
│   │   └── values-pyroscope.yaml  ← Pyroscope Server (NodePort 4040)
│   └── manifests/
│       ├── cluster-config.yaml    ← Kind com porta 34040→4040
│       └── 01-deployment-ranking-api-v2.yaml
│
└── grafana-alloy/                 ← Abordagem 2: eBPF sem tocar no código
    ├── README.md                  ← quando usar, eBPF, limitações
    ├── QUICK-START.md             ← guia passo a passo
    ├── helm-values/
    │   ├── values-alloy.yaml      ← Alloy DaemonSet com pyroscope.ebpf
    │   └── values-pyroscope.yaml  ← Pyroscope Server (NodePort 4040)
    └── manifests/
        └── cluster-config.yaml   ← Kind com porta 34040→4040
```

### Qual abordagem escolher?

| Situação | Abordagem |
|---|---|
| Controlo o código-fonte, quero perfis por endpoint | [pyroscope-sdk/](pyroscope-sdk/README.md) |
| App de terceiro / legado / sem acesso ao código | [grafana-alloy/](grafana-alloy/README.md) |
| Quero profiling de todo o cluster sem tocar em nada | [grafana-alloy/](grafana-alloy/README.md) |
| Preciso de Trace → Profile com correlação precisa | [pyroscope-sdk/](pyroscope-sdk/README.md) |

---

## 🚀 Início Rápido

Escolha a abordagem e siga o guia correspondente:

| Abordagem | Guia | Resumo |
|---|---|---|
| **Pyroscope SDK** | [pyroscope-sdk/QUICK-START.md](pyroscope-sdk/QUICK-START.md) | Modifica a app, ganho máximo de granularidade |
| **Grafana Alloy** | [grafana-alloy/QUICK-START.md](grafana-alloy/QUICK-START.md) | Zero mudanças, perfilação de qualquer processo |

---

## 🔗 Trace to Profile — A Integração Matadora

Quando Tempo (traces) e Pyroscope (profiles) estão no mesmo Grafana, você consegue navegar diretamente de um trace para o flame graph do período correspondente. Isso é chamado de **Trace to Profile**.

### Como configurar (via Grafana UI)

1. Acesse **Grafana → Connections → Data sources → Tempo**
2. Role até a seção **"Trace to profiles"**
3. Configure:
   - **Data source:** `Grafana Pyroscope`
   - **Profile type:** `process_cpu:cpu:nanoseconds:cpu:nanoseconds`
   - **Tags:** `service.name` → `service_name`
4. Salve

### Como usar

```
Grafana Explore
  └── Datasource: Tempo
      └── Buscar trace com duração alta
          └── Abrir waterfall
              └── Clicar no span lento
                  └── Botão "View profile" aparece
                      └── Flame graph do período do span
```

### Por que funciona

O Pyroscope SDK envia profiles com `application_name = "ranking-api"`.  
O Tempo tem traces com `resource.service.name = "ranking-api"`.  
O Grafana usa esse campo como chave de correlação temporal.

---

## ❓ Questões de Fixação

### Conceitual

**1.** Um monitoramento de CPU no Prometheus mostra 85% de utilização. Um trace no Tempo mostra que o endpoint `/score` tem latência média de 400ms. O que o Pyroscope acrescenta a essa análise que os outros dois não conseguem?

**2.** Qual a diferença entre um profiler de sampling e um profiler de instrumentação completa? Por que o sampling é preferido para uso em produção?

**3.** Em um flame graph, você vê que a função `serialize_response()` ocupa 70% da largura no nível mais alto (plateau). O que isso indica? Qual seria a próxima ação?

**4.** Um desenvolvedor diz: "Não preciso de profiler, meus traces já têm spans granulares o suficiente." Em qual cenário essa afirmação seria incorreta?

**5.** Qual é a vantagem do **continuous profiling** (Pyroscope) sobre o **profiling pontual** (cProfile, py-spy direto na máquina) para diagnóstico de incidentes?

### Prático

**6.** Depois de fazer o deploy, você quer comparar o perfil de CPU da versão `v1.0.0` com o da `v2.0.0` da `ranking-api`. Como você usaria os labels do Pyroscope para fazer essa comparação no Grafana?

**7.** O SDK Pyroscope tem a função `pyroscope.tag_wrapper()`. Para que serve? Como você usaria para distinguir o perfil do endpoint `/rankings` do perfil do endpoint `/score`?

**8.** Por que o módulo cria uma nova versão da imagem Docker (`ranking-api:v2-profiler`) em vez de atualizar a imagem `ranking-api:latest` do módulo anterior? Quais são as implicações para um ambiente de produção?

**9.** No contexto do Kubernetes, o Pyroscope SDK da aplicação precisa de alguma permissão especial (ServiceAccount, RBAC) para fazer profiling? Por quê ou por quê não?

**10.** Você tem um serviço que processa filas de mensagens (background worker, sem HTTP). Quais dos quatro pilares de observabilidade (métricas, logs, traces, profiles) fazem sentido para esse tipo de serviço? O profiler seria útil?

---

## 📎 Recursos Adicionais

- [Grafana Pyroscope — Documentação oficial](https://grafana.com/docs/pyroscope/latest/)
- [pyroscope-io — SDK Python no PyPI](https://pypi.org/project/pyroscope-io/)
- [Flame Graphs — Brendan Gregg (inventor)](https://www.brendangregg.com/flamegraphs.html)
- [Grafana Pyroscope — Helm Chart](https://github.com/grafana/pyroscope/tree/main/operations/pyroscope/helm/pyroscope)
- [Trace to Profiles — Documentação Grafana](https://grafana.com/docs/grafana/latest/datasources/tempo/configure-tempo-data-source/#trace-to-profiles)
- [Continuous Profiling — Google-wide profiling](https://research.google/pubs/google-wide-profiling-a-continuous-profiling-infrastructure-for-data-centers/)
