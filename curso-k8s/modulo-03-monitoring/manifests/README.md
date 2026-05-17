# 📂 Manifestos — Módulo 03: Monitoring

## Arquivos

### Manifestos Kubernetes

| Arquivo | Descrição |
|---|---|
| `cluster-config.yaml` | Config do Kind com port mappings para Prometheus, Grafana e Alertmanager |
| `01-four-golden-signals.yaml` | PrometheusRule com alertas dos Four Golden Signals para o namespace `games` |
| `02-blackbox-probe.yaml` | Probe: latência sintética via Blackbox Exporter |
| `03-grafana-alert-rules.yaml` | ConfigMap: Grafana alert rules (motor nativo do Grafana) |

> Os values do Helm estão em [`../helm-values/`](../helm-values/) — separados dos recursos Kubernetes.

---

## Por que usar arquivos de values em vez de `--set`?

Os valores passados via `--set` no `helm install` não ficam registrados em lugar nenhum no repositório — eles estão apenas no histórico de comandos. Se o cluster for recreado, os valores se perdem. Com arquivos de values versionados:

- O estado do ambiente é reproduzível: qualquer máquina consegue recriar o cluster com os mesmos parâmetros
- É possível revisar alterações via diff no Git
- O `helm upgrade` usa os mesmos arquivos, sem depender de `--reuse-values` ou `helm get values`

Todos são instalados via **Helm**:

| Stack | Chart Helm |
|---|---|
| Prometheus + Grafana + Alertmanager | `prometheus-community/kube-prometheus-stack` |
| Loki 3.x (SingleBinary) | `grafana/loki` |
| Fluent Bit (agente independente) | `fluent/fluent-bit` |

Os comandos de instalação estão no [QUICK-START.md](../QUICK-START.md).

---

## Mapeamento de Portas (cluster-config.yaml)

| Serviço | NodePort | HostPort (localhost) | URL |
|---|---|---|---|
| Super Mario (Módulo 02) | 30000 | 8081 | http://localhost:8081 |
| Prometheus | 30090 | 9090 | http://localhost:9090 |
| Grafana | 31000 | 3000 | http://localhost:3000 |
| Alertmanager | 32000 | 9093 | http://localhost:9093 |
| Node Exporter | 32001 | 9100 | http://localhost:9100/metrics |

> Loki e Fluent Bit são **internos ao cluster** — sem NodePort. O Grafana acessa o Loki via DNS interno: `http://loki-gateway.monitoring.svc.cluster.local`.

---

## DNS interno dos componentes de logs

| Componente | DNS interno | Porta |
|---|---|---|
| Loki (instância) | `loki.monitoring.svc.cluster.local` | 3100 |
| Loki Gateway (proxy HTTP) | `loki-gateway.monitoring.svc.cluster.local` | 80 |

> O Grafana e o Fluent Bit sempre se comunicam com o **gateway** (porta 80), nunca diretamente com a instância Loki (porta 3100).

---

## Aplicar os alertas

```sh
kubectl apply -f 01-four-golden-signals.yaml

# Verificar se foi registrado
kubectl get prometheusrule -n monitoring

# Ver no Prometheus UI: Status → Rules → four-golden-signals.games
```

