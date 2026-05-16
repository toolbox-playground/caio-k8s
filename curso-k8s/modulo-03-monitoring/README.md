# 📊 Módulo 03: Monitoramento com Prometheus + Grafana no Kind

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
