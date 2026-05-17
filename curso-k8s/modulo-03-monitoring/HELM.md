# Helm — O gerenciador de pacotes do Kubernetes

> 🎯 Helm é para o Kubernetes o que `apt` é para o Ubuntu ou `npm` é para o Node.js. Em vez de aplicar dezenas de YAMLs manualmente, você instala um **chart** (pacote) com um único comando e o Helm cuida de criar todos os recursos no cluster.

---

## Por que Helm existe?

Um deploy típico de Prometheus sem Helm exige criar na mão: Deployment, Service, ServiceAccount, ClusterRole, ClusterRoleBinding, ConfigMap, ServiceMonitor, PrometheusRule, Secret, HPA... são mais de 50 recursos para o stack completo.

Com Helm:
```sh
helm install kind-prometheus prometheus-community/kube-prometheus-stack -n monitoring
```

Um comando cria tudo, versionado e configurável.

---

## Conceitos fundamentais

| Conceito | O que é |
|---|---|
| **Chart** | Pacote Helm — conjunto de templates de recursos Kubernetes |
| **Release** | Instância de um chart instalada no cluster (ex: `kind-prometheus`) |
| **Values** | Arquivo YAML com as configurações que sobrescrevem os defaults do chart |
| **Repository** | Servidor onde os charts ficam hospedados (como o npm registry) |
| **Revision** | Número de versão do release — cada `helm upgrade` cria uma nova revisão |

---

## Principais comandos

### Repositórios

```sh
# Adicionar um repositório
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add fluent https://fluent.github.io/helm-charts

# Atualizar a lista de charts disponíveis (como apt update)
helm repo update

# Listar repositórios adicionados
helm repo list
```

### Busca e inspeção

```sh
# Buscar um chart
helm search repo prometheus

# Ver os values default de um chart (todas as opções configuráveis)
helm show values prometheus-community/kube-prometheus-stack

# Ver os values de uma versão específica
helm show values prometheus-community/kube-prometheus-stack --version 72.3.0

# Filtrar por palavra-chave (PowerShell)
helm show values prometheus-community/kube-prometheus-stack | Select-String "externalUrl"

# Filtrar por palavra-chave (bash)
helm show values prometheus-community/kube-prometheus-stack | grep -A3 "externalUrl"
```

### Instalação

```sh
# Instalação simples
helm install NOME_RELEASE REPOSITORIO/CHART --namespace NAMESPACE

# Instalação com values de um arquivo
helm install NOME_RELEASE REPOSITORIO/CHART --namespace NAMESPACE -f values.yaml

# Instalação com valor pontual inline
helm install NOME_RELEASE REPOSITORIO/CHART --namespace NAMESPACE \
  --set chave=valor

# Criar o namespace se não existir
helm install NOME_RELEASE REPOSITORIO/CHART \
  --namespace NAMESPACE --create-namespace
```

### Inspecionar releases instalados

```sh
# Listar todos os releases no cluster
helm list -A

# Listar releases em um namespace específico
helm list -n monitoring

# Ver os values que estão aplicados no release atual
helm get values NOME_RELEASE -n NAMESPACE

# Ver TODOS os values (incluindo defaults não customizados)
helm get values NOME_RELEASE -n NAMESPACE --all

# Ver o histórico de revisões
helm history NOME_RELEASE -n NAMESPACE

# Ver o status do release
helm status NOME_RELEASE -n NAMESPACE
```

### Atualização (upgrade)

```sh
# Upgrade mantendo os values atuais (atenção: pode falhar se o chart foi atualizado)
helm upgrade NOME_RELEASE REPOSITORIO/CHART --namespace NAMESPACE --reuse-values

# Upgrade com arquivo de values (forma segura — veja abaixo)
helm upgrade NOME_RELEASE REPOSITORIO/CHART --namespace NAMESPACE -f values.yaml

# Upgrade com valor pontual inline
helm upgrade NOME_RELEASE REPOSITORIO/CHART --namespace NAMESPACE \
  --set chave=valor
```

### Rollback

```sh
# Ver o histórico de revisões
helm history NOME_RELEASE -n NAMESPACE

# Voltar para a revisão anterior
helm rollback NOME_RELEASE -n NAMESPACE

# Voltar para uma revisão específica
helm rollback NOME_RELEASE 3 -n NAMESPACE
```

### Desinstalação

```sh
# Remove todos os recursos do release
helm uninstall NOME_RELEASE -n NAMESPACE
```

---

## Como alterar configurações de um release

### Regra de ouro: não use `--reuse-values` sozinho

`--reuse-values` reutiliza os values da última revisão armazenados no cluster. Funciona bem quando o chart não mudou. Mas se o chart foi atualizado e tem novas variáveis sem default, o upgrade falha com erro de `nil pointer`.

**Padrão seguro — exportar os values atuais e aplicar junto com as alterações:**

**PowerShell:**
```powershell
# 1. Exportar os values atuais do release
helm get values kind-prometheus -n monitoring -o yaml |
  Out-File -Encoding utf8 "$env:TEMP\kind-prometheus-values.yaml"

# 2. Fazer o upgrade passando o arquivo exportado + o novo arquivo de alterações
helm upgrade kind-prometheus prometheus-community/kube-prometheus-stack `
  --namespace monitoring `
  -f "$env:TEMP\kind-prometheus-values.yaml" `
  -f manifests/values-alertmanager-discord.yaml
```

**bash / zsh:**
```bash
# 1. Exportar os values atuais do release
helm get values kind-prometheus -n monitoring -o yaml > /tmp/kind-prometheus-values.yaml

# 2. Fazer o upgrade passando o arquivo exportado + o novo arquivo de alterações
helm upgrade kind-prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f /tmp/kind-prometheus-values.yaml \
  -f manifests/values-alertmanager-discord.yaml
```

> Quando múltiplos `-f` são passados, o Helm mescla os valores em ordem — o último arquivo tem precedência em caso de conflito. Os values do arquivo de alterações sobrescrevem os do release atual.

### Alteração pontual sem arquivo (para testes rápidos)

```sh
helm upgrade kind-prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --reuse-values \
  --set prometheus.prometheusSpec.externalUrl=http://meu-servidor:9090
```

> Use `--set` apenas para testes. Para configurações permanentes, sempre prefira um arquivo de values versionado no repositório.

---

## Como foi usado no Módulo 03

O módulo instalou três stacks via Helm no namespace `monitoring`:

| Release | Chart | Para que serve |
|---|---|---|
| `kind-prometheus` | `prometheus-community/kube-prometheus-stack` | Prometheus + Grafana + Alertmanager + exporters |
| `loki` | `grafana/loki` | Agregador de logs (SingleBinary) |
| `fluent-bit` | `fluent/fluent-bit` | Agente de coleta de logs (DaemonSet) |

### Instalação do kube-prometheus-stack

**PowerShell:**
```powershell
helm install kind-prometheus prometheus-community/kube-prometheus-stack `
  --namespace monitoring --create-namespace `
  --set prometheus.service.nodePort=30090 `
  --set prometheus.service.type=NodePort `
  --set grafana.service.nodePort=32000 `
  --set grafana.service.type=NodePort `
  --set alertmanager.service.nodePort=30093 `
  --set alertmanager.service.type=NodePort `
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
```

**bash / zsh:**
```bash
helm install kind-prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set prometheus.service.nodePort=30090 \
  --set prometheus.service.type=NodePort \
  --set grafana.service.nodePort=32000 \
  --set grafana.service.type=NodePort \
  --set alertmanager.service.nodePort=30093 \
  --set alertmanager.service.type=NodePort \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
```

### Instalação do Loki

**PowerShell:**
```powershell
helm install loki grafana/loki `
  --namespace monitoring `
  --set loki.commonConfig.replication_factor=1 `
  --set loki.storage.type=filesystem `
  --set singleBinary.replicas=1 `
  --set loki.useTestSchema=true `
  --set write.replicas=0 `
  --set read.replicas=0 `
  --set backend.replicas=0
```

**bash / zsh:**
```bash
helm install loki grafana/loki \
  --namespace monitoring \
  --set loki.commonConfig.replication_factor=1 \
  --set loki.storage.type=filesystem \
  --set singleBinary.replicas=1 \
  --set loki.useTestSchema=true \
  --set write.replicas=0 \
  --set read.replicas=0 \
  --set backend.replicas=0
```

### Instalação do Fluent Bit

**PowerShell:**
```powershell
helm install fluent-bit fluent/fluent-bit `
  --namespace monitoring `
  -f manifests/values-fluent-bit.yaml
```

**bash / zsh:**
```bash
helm install fluent-bit fluent/fluent-bit \
  --namespace monitoring \
  -f manifests/values-fluent-bit.yaml
```

### Upgrade para configurar Discord no Alertmanager

O Alertmanager é configurado via values do kube-prometheus-stack — não existe um chart separado para ele. Para adicionar o receiver Discord sem sobrescrever toda a configuração:

**PowerShell:**
```powershell
# Exportar values atuais
helm get values kind-prometheus -n monitoring -o yaml |
  Out-File -Encoding utf8 "$env:TEMP\kind-prometheus-values.yaml"

# Aplicar o arquivo de Discord por cima
helm upgrade kind-prometheus prometheus-community/kube-prometheus-stack `
  --namespace monitoring `
  -f "$env:TEMP\kind-prometheus-values.yaml" `
  -f manifests/values-alertmanager-discord.yaml
```

**bash / zsh:**
```bash
# Exportar values atuais
helm get values kind-prometheus -n monitoring -o yaml > /tmp/kind-prometheus-values.yaml

# Aplicar o arquivo de Discord por cima
helm upgrade kind-prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f /tmp/kind-prometheus-values.yaml \
  -f manifests/values-alertmanager-discord.yaml
```

O arquivo `manifests/values-alertmanager-discord.yaml` contém apenas as chaves que precisam ser alteradas (`alertmanager.config` e `prometheus.prometheusSpec.externalUrl`) — o restante dos values vem do arquivo exportado.

### Arquivos de values do módulo

| Arquivo | Chart | O que configura |
|---|---|---|
| `manifests/values-fluent-bit.yaml` | `fluent/fluent-bit` | Output Loki, labels de metadado Kubernetes |
| `manifests/values-alertmanager-discord.yaml` | `kube-prometheus-stack` | Receiver Discord (URL direta), `externalUrl` |
| `manifests/values-alertmanager-discord-secret.yaml` | `kube-prometheus-stack` | Receiver Discord (via Secret K8s), `externalUrl` |

---

## Verificar o que o Helm gerou

Após a instalação, o Helm cria recursos Kubernetes normais — você pode inspecioná-los com `kubectl`:

```sh
# Ver todos os recursos criados no namespace
kubectl get all -n monitoring

# Ver os ConfigMaps gerados (config do Prometheus, Alertmanager etc.)
kubectl get configmap -n monitoring

# Ver os Secrets gerados
kubectl get secret -n monitoring

# Ver os CRDs instalados pelo chart
kubectl get crd | grep monitoring.coreos.com
```

---

## Questões de fixação

1. Qual a diferença entre um **chart** e um **release**?
2. Por que `helm upgrade --reuse-values` pode falhar quando o chart foi atualizado?
3. Qual comando mostra os values padrão de um chart antes de instalar?
4. Como você passaria dois arquivos de values para um `helm upgrade` e qual tem precedência?
5. Se você fizer um `helm upgrade` que quebrou tudo, como volta ao estado anterior?
