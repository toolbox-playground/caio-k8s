# 📂 Manifestos — Módulo 03: Monitoring

## Arquivos

| Arquivo | Descrição |
|---|---|
| `cluster-config.yaml` | Config do Kind com port mappings para Prometheus, Grafana e Alertmanager |
| `03-four-golden-signals.yaml` | PrometheusRule com alertas dos Four Golden Signals para o namespace `games` |
| `values-fluent-bit.yaml` | Values do Helm para o Fluent Bit — configura o output Loki apontando ao gateway |
| `values-alertmanager-discord.yaml` | Values do Helm para rotear alertas ao Discord — URL do webhook direta no arquivo (local/estudo) |
| `values-alertmanager-discord-secret.yaml` | Values do Helm para rotear alertas ao Discord — URL lida de um Secret Kubernetes (produção) |

---

## Por que não há YAMLs do Prometheus, Loki ou Fluent Bit aqui?

Todos são instalados via **Helm**, que gerencia centenas de recursos automaticamente:

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
kubectl apply -f 03-four-golden-signals.yaml

# Verificar se foi registrado
kubectl get prometheusrule -n monitoring

# Ver no Prometheus UI: Status → Rules → four-golden-signals.games
```

