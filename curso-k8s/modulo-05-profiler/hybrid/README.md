# 🔀 Abordagem 3: Híbrido (SDK + Grafana Alloy)

> **Resumo:** a abordagem de produção mais completa.  
> O SDK cuida dos seus serviços com granularidade máxima.  
> O Alloy cuida de tudo mais no cluster sem tocar em nada.

## Por que combinar os dois?

SDK e Alloy são **complementares**, não concorrentes. Cada um enxerga uma camada diferente:

```
┌─────────────────────────────────────────────────────────────────────┐
│  ranking-api (Python)                                               │
│                                                                     │
│  SDK pyroscope-io  →  visão DENTRO do processo Python               │
│    ✅ frames Python nomeados corretamente                            │
│    ✅ tag_wrapper por endpoint (/rankings, /score)                   │
│    ✅ correlação Trace → Profile via service.name                    │
│    ❌ não enxerga chamadas de sistema, libc, runtime C              │
│                                                                     │
│  Alloy eBPF        →  visão DO KERNEL sobre o processo              │
│    ✅ chamadas de sistema (read, write, futex, epoll)               │
│    ✅ tempo gasto em I/O de rede e disco no nível do OS             │
│    ✅ frames natos da libc e CPython runtime (C extension)          │
│    ❌ não distingue endpoint /rankings de /score                    │
└─────────────────────────────────────────────────────────────────────┘
```

Resultado no Grafana: dois profiles da mesma `ranking-api` que se complementam:
- **SDK profile**: "dentro do Python, qual função gasta mais tempo?"
- **eBPF profile**: "no kernel, qual syscall essa função está chamando?"

## O cenário real que motiva este setup

> 🎬 **Cenário:** A `ranking-api` tem p99 = 380ms mas o flame graph do SDK mostra  
> que a lógica Python tota apenas 40ms. Onde estão os outros 340ms?  
> O flame graph eBPF do Alloy mostra: `futex_wait` consumindo 89% —  
> o processo está bloqueado esperando por um lock de I/O.  
> Isso é **invisível** para o SDK Python pois o processo está parado (sem CPU Python).

## O que cada componente faz

| Componente | O que perfilha | Visão |
|---|---|---|
| `pyroscope-io` SDK na `ranking-api` | Call stack Python da `ranking-api` | Aplicação |
| Alloy eBPF → `ranking-api` | Syscalls e runtime C da `ranking-api` | Kernel |
| Alloy eBPF → `otel-collector` | OTel Collector (Go) | Infra |
| Alloy eBPF → `loki` | Loki (Go) | Infra |
| Alloy eBPF → `prometheus` | Prometheus (Go) | Infra |

> No Grafana você diferencia os dois profiles da `ranking-api` pelo label:
> - `profiler=sdk` → veio do pyroscope-io
> - `profiler=ebpf` → veio do Alloy

## Diferença na configuração do Alloy

No modo híbrido, o `values-alloy.yaml` adiciona um label `profiler=ebpf` em todos os targets e **não exclui** a `ranking-api` — os dois profiles coexistem no Pyroscope e são filtráveis separadamente.

## Estrutura

```
hybrid/
├── README.md                        ← você está aqui
├── QUICK-START.md                   ← guia passo a passo
├── app/                             ← ranking-api v2 (igual ao pyroscope-sdk)
│   ├── main.py
│   ├── requirements.txt
│   └── Dockerfile
├── helm-values/
│   ├── values-alloy.yaml            ← Alloy DaemonSet (com label profiler=ebpf)
│   └── values-pyroscope.yaml        ← Pyroscope Server
└── manifests/
    ├── cluster-config.yaml
    └── 01-deployment-ranking-api-v2.yaml
```

## Início rápido

Veja o [QUICK-START.md](QUICK-START.md) para o guia completo.

> 📚 Para a **teoria**, consulte o [README.md do módulo](../README.md).
