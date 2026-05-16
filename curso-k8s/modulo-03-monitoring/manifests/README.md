# 📂 Manifestos — Módulo 03: Monitoring

## Arquivos

| Arquivo | Descrição |
|---|---|
| `cluster-config.yaml` | Config do Kind com port mappings para Prometheus, Grafana e Alertmanager |

---

## Por que não há YAMLs do Prometheus aqui?

O **kube-prometheus-stack** é instalado via **Helm**, não via manifests avulsos. O Helm cuida de mais de 100 recursos (Deployments, Services, CRDs, RBAC, ServiceMonitors…) de forma gerenciada.

Os comandos de instalação estão documentados no [QUICK-START.md](../QUICK-START.md).

---

## Mapeamento de Portas (cluster-config.yaml)

| Serviço | NodePort | HostPort (localhost) | URL |
|---|---|---|---|
| Super Mario (Módulo 02) | 30000 | 8081 | http://localhost:8081 |
| Prometheus | 30090 | 9090 | http://localhost:9090 |
| Grafana | 31000 | 3000 | http://localhost:3000 |
| Alertmanager | 32000 | 9093 | http://localhost:9093 |
| Node Exporter | 32001 | 9100 | http://localhost:9100/metrics |
