# manifests — Modo Híbrido

| Arquivo | Finalidade |
|---|---|
| `cluster-config.yaml` | Kind cluster com porta 34040→4040 para o Pyroscope |
| `01-deployment-ranking-api-v2.yaml` | ranking-api v2 com pyroscope-io SDK + tag `profiler=sdk` |

> O Alloy eBPF não precisa de manifests adicionais — é instalado via Helm (`values-alloy.yaml`).

## Pré-requisitos

Este módulo presume que o stack do Módulo 03 (Prometheus + Grafana + Loki)  
e o stack do Módulo 04 (OTel Collector + Tempo) já estão rodando.

Consulte o [QUICK-START.md](../QUICK-START.md) para o guia completo.
