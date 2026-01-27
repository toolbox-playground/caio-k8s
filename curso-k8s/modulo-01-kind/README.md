# 🐳 Módulo 01: Cluster Kubernetes Local com Kind

## 📚 Visão Geral

Neste primeiro módulo, você aprenderá a criar e gerenciar clusters Kubernetes locais usando Kind (Kubernetes in Docker). Este é o alicerce de toda nossa jornada - um ambiente de desenvolvimento confiável e reproduzível.

## 🎯 Objetivos de Aprendizado

Ao final deste módulo, você será capaz de:

- ✅ Entender o que é Kind e suas vantagens
- ✅ Instalar e configurar Kind no seu sistema
- ✅ Criar clusters single-node e multi-node
- ✅ Configurar networking básico para LoadBalancer
- ✅ Gerenciar múltiplos clusters
- ✅ Fazer troubleshooting de problemas comuns

## ⏱️ Duração Estimada: 2 horas

## 📋 Pré-requisitos

- Docker Desktop ou Docker Engine instalado
- Linha de comando básica (Bash/PowerShell)
- 4GB RAM disponível
- 10GB espaço em disco

## 🧠 Conceitos Fundamentais

### O que é Kind?

**Kind** (Kubernetes in Docker) é uma ferramenta para executar clusters Kubernetes locais usando containers Docker como "nós". Foi projetado principalmente para:

- **Desenvolvimento local** de aplicações Kubernetes
- **Testes de integração** contínua (CI)
- **Educação** e aprendizado de Kubernetes
- **Prototipagem** rápida de configurações

### Vantagens do Kind

| Vantagem | Descrição |
|----------|-----------|
| **🚀 Rápido** | Clusters criados em segundos |
| **🔄 Reproduzível** | Configuração declarativa via YAML |
| **💡 Leve** | Usa containers em vez de VMs |
| **🔧 Flexível** | Suporte a multi-node e configurações avançadas |
| **🧪 Isolado** | Não interfere com outros clusters |

### Arquitetura do Kind

```mermaid
graph TB
    subgraph "Docker Host"
        subgraph "Kind Cluster"
            subgraph "Control Plane Container"
                APIServer[kube-apiserver]
                Scheduler[kube-scheduler]
                ControllerMgr[kube-controller-manager]
                ETCD[etcd]
            end
            
            subgraph "Worker Node Containers"
                Worker1[kubelet + containerd]
                Worker2[kubelet + containerd]
            end
        end
        
        subgraph "Load Balancer Container"
            HAProxy[HAProxy<br/>Port Mapping]
        end
    end
    
    kubectl[kubectl] --> HAProxy
    HAProxy --> APIServer
    APIServer --> Worker1
    APIServer --> Worker2
    
    style APIServer fill:#1976d2
    style Worker1 fill:#4caf50
    style Worker2 fill:#4caf50
    style HAProxy fill:#ff9800
```

## 🛠️ Laboratório Prático

### Passo 1: Instalação do Kind

#### Windows (PowerShell)
```powershell
# Via Chocolatey
choco install kind

# Via manual download
curl.exe -Lo kind-windows-amd64.exe https://kind.sigs.k8s.io/dl/v0.20.0/kind-windows-amd64
Move-Item .\kind-windows-amd64.exe c:\some-dir-in-your-PATH\kind.exe
```

#### Linux/macOS
```bash
# Via package manager (Linux)
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Via Homebrew (macOS)
brew install kind
```

#### Verificação
```bash
kind version
kubectl version --client
docker --version
```

### Passo 2: Primeiro Cluster Single-Node

```bash
# Criar cluster simples
kind create cluster --name meu-primeiro-cluster

# Verificar cluster
kubectl cluster-info --context kind-meu-primeiro-cluster

# Listar nós
kubectl get nodes

# Verificar pods do sistema
kubectl get pods -n kube-system
```

**🔍 O que aconteceu?**
- Kind criou um container Docker funcionando como nó único
- Kubernetes control plane foi instalado e configurado
- kubectl foi configurado automaticamente para o novo cluster

### Passo 3: Cluster Multi-Node Avançado

Crie o arquivo `cluster-config.yaml`:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: k8s-essentials

networking:
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/12"
  kubeProxyMode: "ipvs"

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
```

#### 📋 Explicação Detalhada da Configuração

**Linha 1-2: Tipo e Versão da API**
```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
```
- `kind: Cluster` - Define que este YAML é uma configuração de **Cluster** do Kind
- `apiVersion` - Especifica a versão v1alpha4 da API (única versão suportada atualmente)

**Linha 3: Nome do Cluster**
```yaml
name: k8s-essentials
```
- Identificador usado em comandos: `kubectl config use-context kind-k8s-essentials`
- Prefixo dos containers Docker: `k8s-essentials-control-plane`, `k8s-essentials-worker`

**Linha 5-8: Configuração de Networking**
```yaml
networking:
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/12"
  kubeProxyMode: "ipvs"
```

| Parâmetro | Descrição | Impacto |
|-----------|-----------|--------|
| `podSubnet` | Range CIDR para IPs dos pods (65.536 endereços) | Cada node recebe uma fatia dessa rede |
| `serviceSubnet` | Range CIDR para ClusterIPs (1.048.576 endereços) | Permite muito mais serviços que o padrão /16 |
| `kubeProxyMode` | Modo IPVS para proxy de rede | ✅ Melhor performance<br>⚠️ Requer módulos kernel IPVS |

**Linha 10-20: Control Plane com Port Mappings**
```yaml
nodes:
  - role: control-plane
    extraPortMappings:
    - containerPort: 80
      hostPort: 30080
    - containerPort: 443
      hostPort: 30443
```

- **Control Plane**: Executa API Server, Scheduler, Controller Manager e etcd
- **Port Mapping 80→30080**: Acessa serviços HTTP via `localhost:30080`
- **Port Mapping 443→30443**: Acessa serviços HTTPS via `localhost:30443`

**Linha 22-23: Workers**
```yaml
  - role: worker
  - role: worker
```
- Dois nodes adicionais para executar cargas de trabalho (pods)
- Permitem testar distribuição de carga e rolling updates

#### ⏱️ Características de Performance

| Aspecto | Impacto no Tempo de Criação |
|---------|-----------------------------|
| **Multi-node (3 containers)** | ⏱️ +30-40s (vs single-node) |
| **IPVS mode** | ⏱️ +10-20s (carrega módulos kernel) |
| **Port mappings** | ⏱️ +5-10s (configuração de rede) |
| **Total esperado** | 🕐 60-120 segundos |

```bash
# Criar cluster com configuração personalizada
kind create cluster --config cluster-config.yaml

# Verificar nós e labels
kubectl get nodes --show-labels

# Verificar mapeamento de portas
docker ps | grep k8s-essentials
```

### Passo 4: Configuração de Contexto e Multi-Cluster

```bash
# Listar clusters existentes
kind get clusters

# Criar segundo cluster para demonstração
kind create cluster --name cluster-dev

# Listar contextos kubectl
kubectl config get-contexts

# Alternar entre clusters
kubectl config use-context kind-k8s-essentials
kubectl config use-context kind-cluster-dev

# Verificar cluster atual
kubectl config current-context

# Executar comandos em contexto específico
kubectl get nodes --context kind-k8s-essentials
kubectl get nodes --context kind-cluster-dev
```

### Passo 5: Testando o Cluster

#### Teste 1: Deploy de Aplicação Simples
```bash
# Criar deployment de teste
kubectl create deployment nginx-test --image=nginx:latest

# Expor como NodePort
kubectl expose deployment nginx-test --port=80 --type=NodePort

# Obter porta do NodePort
kubectl get svc nginx-test

# Testar acesso (substituir <porta> pela porta real)
curl http://localhost:<porta>
```

#### Teste 2: Verificação de Recursos
```bash
# Verificar recursos do cluster
kubectl top nodes 2>/dev/null || echo "Metrics server não instalado (normal)"

# Verificar capacidade dos nós
kubectl describe nodes

# Verificar eventos do cluster
kubectl get events --sort-by=.metadata.creationTimestamp
```

#### Teste 3: Logs e Troubleshooting
```bash
# Ver logs de um pod
kubectl logs deployment/nginx-test

# Executar comandos dentro de um pod
kubectl exec -it deployment/nginx-test -- /bin/bash

# Verificar configuração do cluster
kubectl cluster-info dump > cluster-info.yaml
```

## 🔧 Configurações Avançadas

### Configuração de Registry Local

```yaml
# registry-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: k8s-with-registry
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:5001"]
    endpoint = ["http://kind-registry:5000"]
```

```bash
# Criar registry local
docker run -d --restart=always -p "127.0.0.1:5001:5000" --name "kind-registry" registry:2

# Conectar registry ao cluster
docker network connect "kind" "kind-registry" || true

# Criar cluster com registry
kind create cluster --config registry-config.yaml
```

### Carregamento de Imagens

```bash
# Carregar imagem para o cluster
kind load docker-image nginx:latest --name k8s-essentials

# Carregar de arquivo
docker save nginx:latest | kind load image-archive /dev/stdin --name k8s-essentials

# Verificar imagens no nó
docker exec -it k8s-essentials-control-plane crictl images
```

## 🚨 Troubleshooting

### Problema 1: Cluster Não Inicia
```bash
# Verificar logs de criação
kind create cluster --name debug --verbosity=1

# Verificar containers Docker
docker ps -a | grep kind

# Verificar logs do container
docker logs k8s-essentials-control-plane
```

### Problema 2: kubectl Não Conecta
```bash
# Verificar contexto atual
kubectl config current-context

# Reconfigurar contexto
kind export kubeconfig --name k8s-essentials

# Testar conectividade
kubectl cluster-info
```

### Problema 3: Problemas de Rede
```bash
# Verificar rede Docker
docker network ls | grep kind

# Verificar IPs dos containers
docker inspect k8s-essentials-control-plane | grep IPAddress

# Testar conectividade interna
docker exec -it k8s-essentials-control-plane ping 8.8.8.8
```

### Problema 4: Recursos Insuficientes
```bash
# Verificar uso de recursos
docker stats

# Verificar logs de sistema
docker exec -it k8s-essentials-control-plane dmesg | tail

# Ajustar limites de recursos (em cluster-config.yaml)
```

## 🧹 Limpeza e Manutenção

```bash
# Deletar cluster específico
kind delete cluster --name k8s-essentials

# Deletar todos os clusters
kind delete clusters --all

# Limpar imagens órfãs
docker system prune -f

# Verificar limpeza
kind get clusters
docker ps | grep kind
```

## ✅ Checkpoint de Validação

Antes de prosseguir para o próximo módulo, verifique:

- [ ] Kind está instalado e funcionando
- [ ] Consegue criar clusters single-node e multi-node
- [ ] kubectl está configurado e conectando
- [ ] Consegue fazer deploy de aplicações básicas
- [ ] Entende como alternar entre múltiplos clusters
- [ ] Sabe fazer troubleshooting básico

## 🎯 Exercícios Práticos

### Exercício 1: Cluster Personalizado
Crie um cluster com 1 control-plane e 3 workers, com mapeamento de portas customizado.

### Exercício 2: Multi-Cluster
Gerencie 3 clusters simultâneos: dev, staging, prod.

### Exercício 3: Troubleshooting
Simule e resolva problemas comuns de criação de cluster.

## 📚 Recursos Adicionais

- [Documentação oficial do Kind](https://kind.sigs.k8s.io/)
- [Kind GitHub Repository](https://github.com/kubernetes-sigs/kind)
- [Configurações avançadas](https://kind.sigs.k8s.io/docs/user/configuration/)

## ➡️ Próximo Módulo

No **Módulo 02**, você aprenderá a configurar networking avançado com:
- Calico CNI para networking de pods
- MetalLB para LoadBalancer local
- Nginx Ingress Controller para roteamento HTTP/HTTPS

---

**🎉 Parabéns! Você agora tem um cluster Kubernetes local funcionando!**