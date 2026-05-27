# 🤖 Abordagem 2: Grafana Alloy (eBPF)

> **Resumo:** profiling **sem tocar no código da aplicação**.  
> O Grafana Alloy roda como DaemonSet no cluster e usa **eBPF** para capturar CPU profiles de todos os processos nos nós.

## Quando usar esta abordagem

- ✅ Você **não controla** o código-fonte (app de terceiro, JAR legado, binário sem debug)
- ✅ Quer **zero mudanças** em qualquer aplicação do cluster de uma só vez
- ✅ Profiling de infra: Redis, Postgres, Nginx, qualquer processo Linux
- ✅ Quer um **único agente** coletando métricas + logs + traces + profiles (Alloy faz tudo)
- ✅ Linguagens sem SDK Pyroscope (Rust, C/C++, binários compilados)

## Limitações em relação ao SDK

| Capacidade | SDK | Alloy (eBPF) |
|---|---|---|
| Requer mudança de código | ✅ Sim | ❌ Não |
| `tag_wrapper` por endpoint | ✅ Sim | ❌ Não disponível |
| Perfis separados por rota HTTP | ✅ Sim | ❌ Processo inteiro |
| Correlação Trace → Profile precisa | ✅ Automática | ⚠️ Parcial (por `service_name`) |
| Linguagens suportadas | Apenas com SDK | Qualquer processo Linux |
| Overhead | <1% CPU | <2% CPU |
| Requer privileges no K8s | ❌ Não | ✅ Sim (`privileged: true`) |

## Como funciona

```
Grafana Alloy (DaemonSet — 1 pod por nó)
  └── componente: pyroscope.ebpf
      ├── usa eBPF para observar chamadas de sistema dos processos
      ├── descobre pods via discovery.kubernetes
      └── envia profiles → Pyroscope Server (push)

Resultado:
  Todos os pods do cluster aparecem no Grafana Pyroscope
  sem nenhuma mudança nas aplicações.
```

> **O que é eBPF?**  
> Extended Berkeley Packet Filter — mecanismo do kernel Linux que permite executar programas sandboxed dentro do kernel. O eBPF consegue observar call stacks de qualquer processo sem modificá-lo e com overhead mínimo. É a mesma tecnologia usada pelo Cilium (network), Falco (security) e Pixie (observabilidade).

## Arquitetura no cluster

```
┌─── Nó Kind (worker) ─────────────────────────────────────────────────┐
│                                                                       │
│  ranking-api  (sem nenhuma mudança — usa a imagem do Módulo 04)       │
│  super-mario                                                          │
│  otel-collector                                                       │
│              ↑                                                        │
│  Grafana Alloy (DaemonSet)                                            │
│    └── eBPF hook → captura call stacks de todos os processos acima    │
│    └── pyroscope.write → http://pyroscope.monitoring.svc:4040         │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
                          │
                          ▼
             Pyroscope Server (namespace monitoring)
                          │
                          ▼
                  Grafana Datasource
```

## Configuração central: o arquivo `alloy-config.alloy`

O Alloy usa uma linguagem de configuração própria chamada **River** (ou Alloy config language). O arquivo configura um pipeline de componentes:

```
discovery.kubernetes → discovery.relabel → pyroscope.ebpf → pyroscope.write
```

Cada componente tem inputs/outputs fortemente tipados. Veja o arquivo `helm-values/values-alloy.yaml` para a configuração completa comentada.

## Estrutura

```
grafana-alloy/
├── README.md                        ← você está aqui
├── QUICK-START.md                   ← guia passo a passo
├── helm-values/
│   ├── values-alloy.yaml            ← Alloy como DaemonSet com pyroscope.ebpf
│   └── values-pyroscope.yaml        ← Pyroscope Server (igual ao da abordagem SDK)
└── manifests/
    ├── cluster-config.yaml          ← mesmo cluster-config do pyroscope-sdk
    └── README.md
```

## Início rápido

Veja o [QUICK-START.md](QUICK-START.md) para o guia completo.

> 📚 Para a **teoria** (o que é profiler, flame graph, 4 pilares, casos de uso), consulte o [README.md do módulo](../README.md).
