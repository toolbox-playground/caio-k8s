# 🚀 Kind - Cheat Sheet

Referência rápida de comandos essenciais para Kind (Kubernetes in Docker).

---

## 📦 Instalação

```powershell
# Windows (Winget - Recomendado)
winget install Kubernetes.kind

# Windows (Scoop)
scoop bucket add main
scoop install main/kind

# Windows (Chocolatey)
choco install kind

# Windows (Download direto)
curl.exe -Lo kind.exe https://kind.sigs.k8s.io/dl/v0.31.0/kind-windows-amd64.exe
Move-Item kind.exe C:\Windows\System32\

# Linux
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.31.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/

# macOS
brew install kind

# Verificar
kind version
```

---

## 🎯 Comandos Básicos

### Criar Clusters

```powershell
# Cluster padrão (nome: kind)
kind create cluster

# Cluster com nome customizado
kind create cluster --name dev

# Cluster com arquivo de config
kind create cluster --config kind-config.yaml

# Cluster com nome E config
kind create cluster --name prod --config ha-cluster.yaml

# Cluster com versão específica do K8s
kind create cluster --image kindest/node:v1.27.3

# Cluster com mais verbosidade (debug)
kind create cluster --verbosity=3
```

### Listar e Inspecionar

```powershell
# Listar todos os clusters
kind get clusters

# Ver nodes de um cluster
kind get nodes --name dev

# Obter kubeconfig
kind get kubeconfig --name dev

# Exportar kubeconfig para arquivo
kind get kubeconfig --name dev > kubeconfig-dev.yaml
```

### Deletar Clusters

```powershell
# Deletar cluster padrão
kind delete cluster

# Deletar cluster específico
kind delete cluster --name dev

# Deletar todos os clusters
kind get clusters | ForEach-Object { kind delete cluster --name $_ }
```

---

## 📝 Arquivos de Configuração

### Single Node

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
```

### Multi-Node (1 CP + 2 Workers)

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
```

### HA Cluster (3 CP + 3 Workers)

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: control-plane
- role: control-plane
- role: worker
- role: worker
- role: worker
```

### Ingress Ready (Port Mapping)

### Ingress-Ready (Port Mapping)

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 80
    hostPort: 80      # Acesso: http://localhost
    protocol: TCP
  - containerPort: 443
    hostPort: 443     # Acesso: https://localhost
    protocol: TCP
- role: worker
- role: worker
```

> **💡 Gateway API**: Considere [Gateway API](https://gateway-api.sigs.k8s.io/) para novos projetos.

### Com Versão Específica do Kubernetes

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  image: kindest/node:v1.30.0  # K8s 1.30
- role: worker
  image: kindest/node:v1.30.0
```

**Versões populares:**
- `v1.31.0` - Kubernetes 1.31 (mais recente)
- `v1.30.0` - Kubernetes 1.30
- `v1.29.0` - Kubernetes 1.29
- `v1.28.0` - Kubernetes 1.28

> Verifique versões disponíveis em: https://github.com/kubernetes-sigs/kind/releases

---

## 🐳 Docker Images

### Carregar Imagens

```powershell
# Build local image
docker build -t myapp:1.0 .

# Carregar no cluster padrão
kind load docker-image myapp:1.0

# Carregar em cluster específico
kind load docker-image myapp:1.0 --name dev

# Carregar arquivo tar
kind load image-archive myapp.tar --name dev
```

### Listar Imagens no Cluster

```powershell
# Ver imagens em um node
docker exec -it dev-worker crictl images

# Ver todas as imagens kind
docker images | Select-String "kindest/node"
```

---

## 🔍 Inspeção e Debug

### Logs

```powershell
# Exportar logs do cluster
kind export logs ./logs --name dev

# Ver estrutura de logs
Get-ChildItem ./logs -Recurse

# Logs de um node específico
docker logs dev-control-plane

# Logs do kubelet
docker exec -it dev-control-plane journalctl -u kubelet -f
```

### Acesso aos Nodes

```powershell
# Shell no control-plane
docker exec -it dev-control-plane bash

# Shell no worker
docker exec -it dev-worker bash

# Executar comando
docker exec dev-control-plane kubectl get nodes
```

### Networking

```powershell
# Ver network do Kind
docker network ls | Select-String "kind"

# Inspecionar network
docker network inspect kind

# Ver portas mapeadas
docker port dev-control-plane
```

---

## 🔧 kubectl com Kind

### Configuração

```powershell
# Ver contextos
kubectl config get-contexts

# Usar contexto específico
kubectl config use-context kind-dev

# Ver contexto atual
kubectl config current-context

# Configurar KUBECONFIG
$env:KUBECONFIG = "kubeconfig-dev.yaml"
```

### Verificações Básicas

```powershell
# Ver nodes
kubectl get nodes
kubectl get nodes -o wide

# Ver pods do sistema
kubectl get pods -n kube-system

# Ver todos os recursos
kubectl get all -A

# Cluster info
kubectl cluster-info
kubectl cluster-info dump

# Health check
kubectl get --raw /healthz
```

---

## 🎨 Patterns Comuns

### Dev/Staging/Prod Local

```powershell
# Criar ambientes
kind create cluster --name dev
kind create cluster --name staging
kind create cluster --name prod

# Switch entre ambientes
kubectl config use-context kind-dev
kubectl config use-context kind-staging
kubectl config use-context kind-prod
```

### Deploy Aplicação de Teste

```powershell
# Criar deployment
kubectl create deployment nginx --image=nginx:alpine

# Escalar
kubectl scale deployment nginx --replicas=3

# Expor
kubectl expose deployment nginx --port=80 --type=NodePort

# Port forward
kubectl port-forward svc/nginx 8080:80

# Limpar
kubectl delete deployment,svc nginx
```

### Load Image e Deploy

```powershell
# Build
docker build -t myapp:1.0 .

# Load
kind load docker-image myapp:1.0 --name dev

# Deploy
kubectl create deployment myapp --image=myapp:1.0

# Atualizar imagePullPolicy
kubectl patch deployment myapp -p '{"spec":{"template":{"spec":{"containers":[{"name":"myapp","imagePullPolicy":"Never"}]}}}}'
```

---

## 🛠️ Troubleshooting

### Cluster Não Inicia

```powershell
# Verificar Docker
docker version
docker ps

# Reiniciar Docker
# Windows: Restart Docker Desktop
# Linux: sudo systemctl restart docker

# Limpar e recriar
kind delete cluster --name dev
kind create cluster --name dev --verbosity=3
```

### kubectl Não Conecta

```powershell
# Reconfigurar kubeconfig
kind get kubeconfig --name dev > $env:USERPROFILE\.kube\config

# Ou
$env:KUBECONFIG = "$env:USERPROFILE\.kube\config"
kind get kubeconfig --name dev > $env:KUBECONFIG

# Testar
kubectl cluster-info
kubectl get nodes
```

### Node Não Fica Ready

```powershell
# Ver eventos
kubectl get events -A --sort-by='.lastTimestamp'

# Descrever node
kubectl describe node <node-name>

# Logs do kubelet
docker exec <node-name> journalctl -u kubelet --no-pager | tail -100

# Verificar componentes
kubectl get componentstatuses
```

### Problemas de Network

```powershell
# Verificar network exists
docker network ls

# Recriar network
docker network rm kind
kind create cluster

# Verificar portas
docker port <container-name>
netstat -an | Select-String "30080"
```

### Imagem Não Encontrada

```powershell
# Verificar se image foi loaded
docker exec <node-name> crictl images | Select-String "myapp"

# Reload image
kind load docker-image myapp:1.0 --name dev

# Usar imagePullPolicy: Never
kubectl set image deployment/myapp myapp=myapp:1.0
kubectl patch deployment myapp -p '{"spec":{"template":{"spec":{"containers":[{"name":"myapp","imagePullPolicy":"Never"}]}}}}'
```

---

## 🧹 Limpeza

```powershell
# Deletar cluster
kind delete cluster --name dev

# Deletar todos os clusters
kind get clusters | ForEach-Object { kind delete cluster --name $_ }

# Limpar imagens kindest/node
docker images | Select-String "kindest/node" | ForEach-Object {
    $imageId = ($_ -split "\s+")[2]
    docker rmi $imageId
}

# Limpar networks
docker network prune -f

# Limpar volumes
docker volume prune -f

# Verificar espaço
docker system df
```

---

## 📊 Quick Reference Table

| Comando | Descrição |
|---------|-----------|
| `kind create cluster` | Criar cluster padrão |
| `kind create cluster --name X` | Criar com nome |
| `kind create cluster --config X` | Criar com config |
| `kind get clusters` | Listar clusters |
| `kind get nodes --name X` | Listar nodes |
| `kind get kubeconfig --name X` | Obter kubeconfig |
| `kind delete cluster --name X` | Deletar cluster |
| `kind load docker-image X` | Carregar imagem |
| `kind export logs ./dir` | Exportar logs |
| `kind version` | Ver versão |

---

## 🔗 Versões do Kubernetes

| Versão K8s | Imagem Kind |
|------------|-------------|
| 1.28.0 | kindest/node:v1.28.0 |
| 1.27.3 | kindest/node:v1.27.3 |
| 1.26.6 | kindest/node:v1.26.6 |
| 1.25.11 | kindest/node:v1.25.11 |
| 1.24.15 | kindest/node:v1.24.15 |

[Lista completa de versões](https://github.com/kubernetes-sigs/kind/releases)

---

## 💡 Dicas Pro

### Performance

```powershell
# Cluster mínimo para testes rápidos
kind create cluster --name fast

# Cluster com mais recursos
# Editar Docker Desktop: Settings > Resources
# Aumentar CPUs e Memory

# Desabilitar métricas para economia
kubectl delete deployment metrics-server -n kube-system
```

### Múltiplos Kubeconfigs

```powershell
# Manter configs separados
kind get kubeconfig --name dev > kubeconfig-dev.yaml
kind get kubeconfig --name prod > kubeconfig-prod.yaml

# Usar config específico
$env:KUBECONFIG = "kubeconfig-dev.yaml"
kubectl get nodes

# Merge configs
$env:KUBECONFIG = "kubeconfig-dev.yaml;kubeconfig-prod.yaml"
kubectl config view --flatten > merged-config.yaml
```

### Scripts Úteis

```powershell
# Criar cluster e aguardar
kind create cluster --name dev --wait 5m

# One-liner para recrear
kind delete cluster --name dev; kind create cluster --name dev

# Info rápida
kubectl get nodes,pods -A

# Contexto no prompt (Oh My Posh)
# Adicionar ao profile: $env:KUBECONFIG
```

---

## 📚 Recursos

- [Kind Docs](https://kind.sigs.k8s.io/)
- [Kind GitHub](https://github.com/kubernetes-sigs/kind)
- [Kubernetes Docs](https://kubernetes.io/docs/)

---

**💡 Salve este arquivo para referência rápida!**