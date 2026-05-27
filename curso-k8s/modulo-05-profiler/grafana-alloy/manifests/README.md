# Manifests — Grafana Alloy

| Arquivo | Descrição |
|---|---|
| `cluster-config.yaml` | Kind cluster com porta `4040` exposta para o Grafana Pyroscope |

> **Nota:** a abordagem Alloy não requer nenhum manifest de aplicação.  
> A `ranking-api` do Módulo 04 (`ranking-api:latest`) é usada **sem alterações**.  
> O Alloy descobre e perfila os pods automaticamente via eBPF + `discovery.kubernetes`.
