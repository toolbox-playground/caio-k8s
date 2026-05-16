# 📂 Manifestos — Módulo 03: Monitoring

## Arquivos

| Arquivo | Descrição |
|---|---|
| `cluster-config.yaml` | Config do Kind com port mappings para Prometheus, Grafana e Alertmanager |
| `03-four-golden-signals.yaml` | PrometheusRule com alertas dos Four Golden Signals para o namespace `games` |

---

## Por que não há YAMLs do Prometheus, Loki ou Fluent Bit aqui?

Todos são instalados via **Helm**, que gerencia centenas de recursos automaticamente:

| Stack | Chart Helm |
|---|---|
| Prometheus + Grafana + Alertmanager | `prometheus-community/kube-prometheus-stack` |
| Loki + Fluent Bit | `grafana/loki-stack` |

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
| Loki | interno | 3100 | `http://loki:3100` (DNS interno) |

> O Loki não precisa de NodePort — o Grafana o acessa internamente pelo DNS do cluster.

---

## Aplicar os alertas

```sh
kubectl apply -f 03-four-golden-signals.yaml

# Verificar se foi registrado
kubectl get prometheusrule -n monitoring

# Ver no Prometheus UI: Status → Rules → four-golden-signals.games
```
