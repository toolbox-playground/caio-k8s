# 🚀 Módulo 01: Kind - Guia Passo a Passo

Este guia contém todos os comandos práticos para trabalhar com Kind (Kubernetes in Docker).

---

## 📋 Pré-requisitos

```powershell
# Verificar se Docker está rodando
docker version
docker ps

# Verificar recursos disponíveis
docker info | Select-String "CPUs", "Total Memory"
```

---

## 🔧 Seção 1: Instalação do Kind

### Windows (PowerShell)

```powershell
# Método 1: Chocolatey
choco install kind

# Método 2: Download direto
$kindVersion = "v0.20.0"
curl.exe -Lo kind-windows-amd64.exe "https://kind.sigs.k8s.io/dl/${kindVersion}/kind-windows-amd64.exe"
Move-Item .\kind-windows-amd64.exe C:\Windows\System32\kind.exe

# Verificar instalação
kind version
```

### Linux/WSL

```bash
# Download e instalação
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Verificar
kind version
```

### macOS

```bash
# Homebrew
brew install kind

# Verificar
kind version
```

---

## 🎯 Seção 2: Primeiro Cluster Kind

### Cluster Single-Node

```powershell
# Criar cluster simples
kind create cluster

# Verificar cluster
kind get clusters

# Verificar nodes
kubectl get nodes

# Informações do cluster
kubectl cluster-info --context kind-kind

# Ver containers Docker
docker ps
```

### Explorar o Cluster

```powershell
# Verificar namespaces
kubectl get namespaces

# Verificar pods do sistema
kubectl get pods -n kube-system

# Verificar services
kubectl get services -A

# Informações detalhadas do node
kubectl describe node kind-control-plane
```

### Deletar Cluster

```powershell
# Deletar cluster padrão
kind delete cluster

# Deletar cluster específico
kind delete cluster --name meu-cluster
```

---

## 🏗️ Seção 3: Cluster com Nome Customizado

```powershell
# Criar cluster com nome específico
kind create cluster --name dev

# Listar clusters
kind get clusters

# Configurar kubectl para usar este cluster
kubectl config use-context kind-dev

# Verificar contexto atual
kubectl config current-context

# Ver todos os contextos
kubectl config get-contexts

# Trabalhar com o cluster
kubectl get nodes

# Deletar quando não precisar mais
kind delete cluster --name dev
```

---

## 📝 Seção 4: Cluster com Arquivo de Configuração

### Cluster Multi-Node Básico

```powershell
# Criar arquivo de config (kind-config.yaml)
@"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
"@ | Out-File -FilePath kind-config.yaml -Encoding UTF8

# Criar cluster usando o arquivo
kind create cluster --name multi-node --config kind-config.yaml

# Verificar nodes
kubectl get nodes
```

### Cluster com Port Mapping

```powershell
# Config com port mapping para Ingress
@"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 80
    hostPort: 30080
    protocol: TCP
  - containerPort: 443
    hostPort: 30443
    protocol: TCP
- role: worker
- role: worker
"@ | Out-File -FilePath kind-ingress-config.yaml -Encoding UTF8

# Criar cluster
kind create cluster --name ingress-ready --config kind-ingress-config.yaml

# Verificar
kubectl get nodes
docker port ingress-ready-control-plane
```

---

## 🌐 Seção 5: Cluster HA (High Availability)

```powershell
# Cluster com 3 control-planes e 3 workers
@"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: control-plane
- role: control-plane
- role: worker
- role: worker
- role: worker
"@ | Out-File -FilePath kind-ha-config.yaml -Encoding UTF8

# Criar cluster HA
kind create cluster --name ha-cluster --config kind-ha-config.yaml

# Verificar control-planes
kubectl get nodes -l node-role.kubernetes.io/control-plane

# Verificar workers
kubectl get nodes -l node-role.kubernetes.io/worker
```

---

## 🔍 Seção 6: Inspeção e Debug

### Informações do Cluster

```powershell
# Ver configuração completa
kind get kubeconfig --name multi-node

# Exportar kubeconfig
kind get kubeconfig --name multi-node > kubeconfig-multi-node.yaml

# Usar kubeconfig específico
$env:KUBECONFIG = "kubeconfig-multi-node.yaml"
kubectl get nodes
```

### Logs e Debugging

```powershell
# Ver logs do kind
kind export logs --name multi-node ./kind-logs

# Inspecionar containers do cluster
docker ps --filter "label=io.x-k8s.kind.cluster=multi-node"

# Executar comando no node
docker exec -it multi-node-control-plane bash

# Dentro do node, verificar kubelet
systemctl status kubelet

# Ver logs do kubelet
journalctl -u kubelet -f

# Sair do container
exit
```

### Diagnóstico de Problemas

```powershell
# Verificar se API server está respondendo
kubectl get --raw /healthz

# Ver componentes do cluster
kubectl get componentstatuses

# Verificar eventos
kubectl get events -A --sort-by='.lastTimestamp'

# Recursos do cluster
kubectl top nodes  # Requer metrics-server
```

---

## 🎨 Seção 7: Versões Específicas do Kubernetes

```powershell
# Listar imagens disponíveis
docker pull kindest/node:v1.28.0
docker pull kindest/node:v1.27.3
docker pull kindest/node:v1.26.6

# Criar cluster com versão específica
kind create cluster --name k8s-1-27 --image kindest/node:v1.27.3

# Verificar versão
kubectl version --short

# Config com versão específica
@"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  image: kindest/node:v1.27.3
- role: worker
  image: kindest/node:v1.27.3
"@ | Out-File -FilePath kind-version-config.yaml -Encoding UTF8

kind create cluster --name versioned --config kind-version-config.yaml
```

---

## 📦 Seção 8: Load de Imagens Docker

```powershell
# Criar uma imagem de exemplo
@"
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/
"@ | Out-File -FilePath Dockerfile -Encoding UTF8

@"
<h1>Hello from Kind!</h1>
"@ | Out-File -FilePath index.html -Encoding UTF8

# Build da imagem
docker build -t my-app:1.0 .

# Carregar imagem no cluster Kind
kind load docker-image my-app:1.0 --name multi-node

# Verificar imagens no node
docker exec multi-node-worker crictl images | Select-String "my-app"

# Deploy da aplicação
kubectl create deployment my-app --image=my-app:1.0
kubectl set image deployment/my-app my-app=my-app:1.0

# Expor aplicação
kubectl expose deployment my-app --port=80 --type=NodePort

# Ver service
kubectl get svc my-app
```

---

## 🔄 Seção 9: Múltiplos Clusters

```powershell
# Criar múltiplos clusters para diferentes ambientes
kind create cluster --name dev
kind create cluster --name staging
kind create cluster --name prod

# Listar todos os clusters
kind get clusters

# Mudar entre clusters
kubectl config use-context kind-dev
kubectl get nodes

kubectl config use-context kind-staging
kubectl get nodes

kubectl config use-context kind-prod
kubectl get nodes

# Ver todos os contextos
kubectl config get-contexts

# Deletar clusters
kind delete cluster --name dev
kind delete cluster --name staging
kind delete cluster --name prod
```

---

## 🧪 Seção 10: Testes e Aplicações

### Deploy de Aplicação Simples

```powershell
# Criar deployment
kubectl create deployment nginx --image=nginx:alpine

# Verificar
kubectl get deployments
kubectl get pods

# Escalar
kubectl scale deployment nginx --replicas=3
kubectl get pods

# Expor
kubectl expose deployment nginx --port=80 --type=LoadBalancer

# Ver service (LoadBalancer não funcionará sem MetalLB)
kubectl get svc nginx

# Usar NodePort ao invés
kubectl delete svc nginx
kubectl expose deployment nginx --port=80 --type=NodePort

# Acessar aplicação
$nodePort = kubectl get svc nginx -o jsonpath='{.spec.ports[0].nodePort}'
Write-Host "Application available at: http://localhost:$nodePort"

# Ou via port-forward
kubectl port-forward svc/nginx 8080:80
# Acessar http://localhost:8080
```

### Testar Comunicação entre Pods

```powershell
# Criar segundo deployment
kubectl create deployment busybox --image=busybox:latest -- sleep 3600

# Pegar IP do nginx
$nginxIP = kubectl get pod -l app=nginx -o jsonpath='{.items[0].status.podIP}'

# Testar conectividade
kubectl exec -it deployment/busybox -- wget -O- $nginxIP

# Testar DNS
kubectl exec -it deployment/busybox -- nslookup nginx

# Limpar
kubectl delete deployment nginx busybox
```

---

## 🛠️ Seção 11: Configurações Avançadas

### Feature Gates

```powershell
# Config com feature gates
@"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
featureGates:
  EphemeralContainers: true
  GracefulNodeShutdown: true
nodes:
- role: control-plane
"@ | Out-File -FilePath kind-features.yaml -Encoding UTF8

kind create cluster --name features --config kind-features.yaml
```

### Runtime Config

```powershell
# Config com runtime personalizado
@"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: ClusterConfiguration
    apiServer:
      extraArgs:
        enable-admission-plugins: NodeRestriction,PodSecurityPolicy
"@ | Out-File -FilePath kind-runtime.yaml -Encoding UTF8

kind create cluster --name custom-runtime --config kind-runtime.yaml
```

---

## 📊 Seção 12: Monitoramento Básico

```powershell
# Install metrics-server (modificado para Kind)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch para funcionar no Kind
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--kubelet-insecure-tls"
  }
]'

# Aguardar metrics-server estar pronto
kubectl wait --for=condition=ready pod -l k8s-app=metrics-server -n kube-system --timeout=120s

# Ver uso de recursos
kubectl top nodes
kubectl top pods -A
```

---

## 🔧 Seção 13: Troubleshooting Comum

### Cluster não inicia

```powershell
# Limpar clusters anteriores
kind delete cluster --name <nome>

# Verificar Docker
docker ps
docker info

# Reiniciar Docker se necessário
# Windows: Restart Docker Desktop
# Linux: sudo systemctl restart docker

# Criar cluster com mais verbosidade
kind create cluster --verbosity=3
```

### Problemas de Network

```powershell
# Verificar network do Kind
docker network ls | Select-String "kind"

# Inspecionar network
docker network inspect kind

# Recriar network se necessário
docker network rm kind
kind create cluster
```

### kubectl não conecta

```powershell
# Verificar kubeconfig
kubectl config view

# Reconfigurar
kind get kubeconfig --name <cluster-name> > $env:USERPROFILE\.kube\config

# Ou usar variável de ambiente
$env:KUBECONFIG = "$env:USERPROFILE\.kube\config"

# Testar conexão
kubectl cluster-info
kubectl get nodes
```

---

## 🧹 Seção 14: Limpeza

```powershell
# Deletar cluster específico
kind delete cluster --name meu-cluster

# Deletar todos os clusters Kind
kind get clusters | ForEach-Object { kind delete cluster --name $_ }

# Limpar imagens Kind antigas
docker images | Select-String "kindest/node" | ForEach-Object {
    $imageId = ($_ -split "\s+")[2]
    docker rmi $imageId
}

# Limpar volumes não usados
docker volume prune -f

# Verificar espaço recuperado
docker system df
```

---

## 📚 Resumo de Comandos Essenciais

```powershell
# Criar cluster
kind create cluster
kind create cluster --name <name>
kind create cluster --config <file>

# Listar clusters
kind get clusters

# Deletar cluster
kind delete cluster
kind delete cluster --name <name>

# Kubeconfig
kind get kubeconfig --name <name>

# Carregar imagem
kind load docker-image <image:tag> --name <cluster>

# Logs
kind export logs <dir> --name <cluster>

# Verificar versão
kind version
```

---

## ✅ Próximos Passos

Agora que você domina o Kind, está pronto para:

1. **Módulo 02**: Implementar networking com Calico e MetalLB
2. **Módulo 03**: Adicionar observabilidade com Prometheus e Grafana
3. **Experimentos**: Testar diferentes configurações de cluster

---

## 🔗 Recursos Adicionais

- [Documentação Oficial Kind](https://kind.sigs.k8s.io/)
- [Kind GitHub Repository](https://github.com/kubernetes-sigs/kind)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Docker Documentation](https://docs.docker.com/)

---

**Pronto para o próximo módulo!** 🚀