# 🚀 Módulo 03 — Guia de Início Rápido

## Pré-condição: Módulo 02 concluído

O Super Mario e o HPA precisam estar rodando. Verifique:

**PowerShell e bash:**

```sh
kubectl get pods -n games
kubectl get hpa -n games
```

---

## Opção A: Cluster novo com todas as portas mapeadas (recomendado)

Use se for recriar o cluster do zero ou se o cluster ainda não existe.

**PowerShell e bash:**

```sh
# 1. Deletar cluster anterior (se existir)
kind delete cluster --name k8s-essentials

# 2. Recriar com port mappings estendidos
kind create cluster --config manifests/cluster-config.yaml

# 3. Reinstalar Metrics Server (necessário após recriar)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system --type=json -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

# 4. Reinstalar o Super Mario (Módulo 02)
kubectl create namespace games
kubectl apply -f ../modulo-02-deploy-app/manifests/01-deployment-mario.yaml
kubectl apply -f ../modulo-02-deploy-app/manifests/02-service-mario.yaml
kubectl apply -f ../modulo-02-deploy-app/manifests/03-hpa.yaml
```

---

## Opção B: Cluster existente via port-forward (sem downtime)

Use se não quiser recriar o cluster e perder o estado atual.

**PowerShell e bash:**

```sh
# Após instalar o Prometheus (passo abaixo), use port-forward para acessar:
kubectl port-forward svc/kind-prometheus-kube-prome-prometheus -n monitoring 9090:9090
kubectl port-forward svc/kind-prometheus-grafana -n monitoring 3000:80
kubectl port-forward svc/kind-prometheus-kube-prome-alertmanager -n monitoring 9093:9093
```

> ⚠️ Cada `port-forward` ocupa um terminal. Abra 3 terminais separados ou use tmux.

---

## Instalação do kube-prometheus-stack via Helm

**PowerShell e bash:**

```sh
# 1. Adicionar repositórios Helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add stable https://charts.helm.sh/stable
helm repo update

# 2. Criar namespace de monitoramento
kubectl create namespace monitoring
```

# 3. Instalar o stack completo

**PowerShell:**

```powershell
helm install kind-prometheus prometheus-community/kube-prometheus-stack `
  --namespace monitoring `
  --set prometheus.service.nodePort=30090 `
  --set prometheus.service.type=NodePort `
  --set grafana.service.nodePort=31000 `
  --set grafana.service.type=NodePort `
  --set alertmanager.service.nodePort=32000 `
  --set alertmanager.service.type=NodePort `
  --set prometheus-node-exporter.service.nodePort=32001 `
  --set prometheus-node-exporter.service.type=NodePort
```

**bash / zsh (Linux, Mac, WSL):**

```bash
helm install kind-prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.service.nodePort=30090 \
  --set prometheus.service.type=NodePort \
  --set grafana.service.nodePort=31000 \
  --set grafana.service.type=NodePort \
  --set alertmanager.service.nodePort=32000 \
  --set alertmanager.service.type=NodePort \
  --set prometheus-node-exporter.service.nodePort=32001 \
  --set prometheus-node-exporter.service.type=NodePort
```

> 💡 A diferença entre os dois é apenas o caractere de continuação de linha: `` ` `` (backtick) no PowerShell e `\` (backslash) no bash/zsh.

---

## Instalação do Loki + Fluent Bit via Helm

O **loki-stack** da Grafana inclui Loki + Fluent Bit em um único chart. O Grafana já está instalado pelo kube-prometheus-stack, então desabilitamos o Grafana do loki-stack para não duplicar.

**PowerShell e bash:**

```sh
# Adicionar repositório Grafana (se ainda não adicionado)
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

**PowerShell:**

```powershell
helm install loki grafana/loki-stack `
  --namespace monitoring `
  --set fluent-bit.enabled=true `
  --set promtail.enabled=false `
  --set grafana.enabled=false `
  --set loki.persistence.enabled=false
```

**bash / zsh:**

```bash
helm install loki grafana/loki-stack \
  --namespace monitoring \
  --set fluent-bit.enabled=true \
  --set promtail.enabled=false \
  --set grafana.enabled=false \
  --set loki.persistence.enabled=false
```

> 💡 `fluent-bit.enabled=true` ativa o Fluent Bit como coletor de logs (DaemonSet).
> `promtail.enabled=false` desativa o Promtail para não coletar logs duplicados.
> `loki.persistence.enabled=false` usa armazenamento em memória — adequado para Kind/desenvolvimento.

Aguardar Loki e Fluent Bit subirem:

**PowerShell e bash:**

```sh
kubectl get pods -n monitoring -w
# Aguarde os pods loki-0 e loki-fluent-bit-* ficarem Running
```

### Adicionar Loki como datasource no Grafana

**PowerShell e bash:**

```sh
# Abra o Grafana (http://localhost:3000)
# Connections → Data Sources → Add data source → Loki
# URL: http://loki:3100
# Clique em Save & Test
```

> O Loki é acessível internamente pelo DNS do Kubernetes: `http://loki:3100`

### Verificar logs do Super Mario no Grafana

```
Grafana → Explore → Selecione datasource: Loki
Label filter: namespace = games
Label filter: container = super-mario
Clique em Run query
```

Query LogQL equivalente:
```logql
{namespace="games", container="super-mario"}
```

---

## Aplicar os alertas dos Four Golden Signals

**PowerShell e bash:**

```sh
kubectl apply -f manifests/03-four-golden-signals.yaml
```

Verificar se o Prometheus carregou as regras:

**PowerShell e bash:**

```sh
kubectl get prometheusrule -n monitoring
```

Confirmar no Prometheus UI:
```
http://localhost:9090 → Status → Rules → four-golden-signals.games
```

---

## Aguardar o stack subir

**PowerShell e bash:**

```sh
# Acompanhar pods subindo (aguarde todos ficarem Running/Ready)
kubectl get pods -n monitoring -w
```

Ou aguardar todos ficarem prontos de uma vez:

**PowerShell:**

```powershell
kubectl wait --for=condition=ready pod `
  --selector=app.kubernetes.io/instance=kind-prometheus `
  --namespace monitoring `
  --timeout=300s
```

**bash / zsh:**

```bash
kubectl wait --for=condition=ready pod \
  --selector=app.kubernetes.io/instance=kind-prometheus \
  --namespace monitoring \
  --timeout=300s
```

Resultado esperado (todos `1/1 Running` ou `2/2 Running`):

```
NAME                                                      READY   STATUS    RESTARTS
alertmanager-kind-prometheus-kube-prome-alertmanager-0   2/2     Running   0
kind-prometheus-grafana-xxxx                             3/3     Running   0
kind-prometheus-kube-prome-operator-xxxx                 1/1     Running   0
kind-prometheus-kube-state-metrics-xxxx                  1/1     Running   0
kind-prometheus-prometheus-node-exporter-xxxx            1/1     Running   0
prometheus-kind-prometheus-kube-prome-prometheus-0       2/2     Running   0
```

---

## Acessar os serviços

### Prometheus
- **Opção A (NodePort):** http://localhost:9090
- **Opção B (port-forward):** `kubectl port-forward svc/kind-prometheus-kube-prome-prometheus -n monitoring 9090:9090`

### Grafana
- **Opção A (NodePort):** http://localhost:3000
- **Opção B (port-forward):** `kubectl port-forward svc/kind-prometheus-grafana -n monitoring 3000:80`
- **Login:** usuário `admin` / senha: recupere com o comando abaixo

Se a senha padrão `prom-operator` não funcionar, busque a senha real do secret:

**PowerShell:**

```powershell
kubectl get secret --namespace monitoring `
  -l app.kubernetes.io/component=admin-secret `
  -o jsonpath="{.items[0].data.admin-password}" |
  ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
```

**bash / zsh:**

```bash
kubectl get secret --namespace monitoring \
  -l app.kubernetes.io/component=admin-secret \
  -o jsonpath="{.items[0].data.admin-password}" | base64 --decode ; echo
```

### Alertmanager
- **Opção A (NodePort):** http://localhost:9093
- **Opção B (port-forward):** `kubectl port-forward svc/kind-prometheus-kube-prome-alertmanager -n monitoring 9093:9093`

---

## Rodar o Stress Test e Observar no Grafana

**PowerShell e bash:**

```sh
# 1. Garantir que o Mario está rodando
kubectl get pods -n games

# 2. Disparar o stress test (Módulo 02)
kubectl apply -f ../modulo-02-deploy-app/manifests/04-stress-test-fortio.yaml

# 3. Em outro terminal: acompanhar HPA reagindo
kubectl get hpa -n games -w

# 4. No Grafana (http://localhost:3000):
#    Dashboards → Browse → Kubernetes → Compute Resources → Namespace (Pods)
#    Selecione namespace: games
#    Observe CPU e memória subindo em tempo real
```

---

## Verificar coleta de métricas do namespace games

> Abra o Prometheus em http://localhost:9090 e execute as queries abaixo no campo de expressão.

```promql
# Pods rodando no namespace games
kube_pod_info{namespace="games"}

# CPU dos pods do Mario (média 2 minutos)
sum(rate(container_cpu_usage_seconds_total{namespace="games", container!=""}[2m])) by (pod)

# Memória dos pods do Mario
container_memory_working_set_bytes{namespace="games", container="super-mario"}

# Réplicas do deployment ao longo do tempo
kube_deployment_status_replicas{namespace="games"}
```

---

## Limpar o ambiente

**PowerShell e bash:**

```sh
# Remover apenas o stack de monitoramento (manter o cluster)
helm uninstall kind-prometheus -n monitoring
kubectl delete namespace monitoring

# Ou deletar o cluster inteiro
kind delete cluster --name k8s-essentials
```

---

## Resumo do que foi instalado

| Componente | Função | Porta |
|---|---|---|
| Prometheus | Coleta e armazena métricas | 9090 |
| Grafana | Dashboards visuais | 3000 |
| Alertmanager | Gerenciamento de alertas | 9093 |
| Node Exporter | Métricas do node (CPU/mem/disco) | 9100 |
| kube-state-metrics | Estado dos objetos K8s | interno |
| Prometheus Operator | Gerencia o Prometheus via CRDs | interno |
