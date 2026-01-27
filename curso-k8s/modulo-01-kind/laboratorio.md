# 🧪 Laboratório: Cluster Kubernetes com Kind

## 🎯 Objetivo
Praticar a criação e configuração de clusters Kubernetes locais usando Kind, desde configurações básicas até ambientes multi-node avançados.

## ⏱️ Tempo Estimado: 90 minutos

## 📋 Pré-requisitos
- Docker instalado e funcionando
- Kind instalado
- kubectl instalado

## 🔬 Exercícios Práticos

### Exercício 1: Primeiro Cluster (15 min)

#### Tarefa
Criar seu primeiro cluster Kubernetes local e explorar sua estrutura.

#### Passos
1. **Criar cluster simples**:
   ```bash
   kind create cluster --name lab01
   ```

2. **Explorar o cluster**:
   ```bash
   # Verificar nós
   kubectl get nodes -o wide
   
   # Verificar pods do sistema
   kubectl get pods -n kube-system
   
   # Verificar services
   kubectl get svc -A
   ```

3. **Testar funcionalidade básica**:
   ```bash
   # Criar pod de teste
   kubectl run test-pod --image=nginx --port=80
   
   # Verificar se está rodando
   kubectl get pods
   
   # Acessar logs
   kubectl logs test-pod
   
   # Fazer port-forward para testar
   kubectl port-forward pod/test-pod 8080:80
   # Em outro terminal: curl http://localhost:8080
   ```

4. **Limpeza**:
   ```bash
   kubectl delete pod test-pod
   ```

#### ✅ Critérios de Sucesso
- Cluster criado com sucesso
- Pods do sistema rodando (kube-apiserver, etcd, etc.)
- Pod de teste funcionando e acessível

### Exercício 2: Cluster Multi-Node (25 min)

#### Tarefa
Criar um cluster com múltiplos nós e configurações customizadas.

#### Passos
1. **Criar arquivo de configuração** (`multi-node-config.yaml`):
   ```yaml
   kind: Cluster
   apiVersion: kind.x-k8s.io/v1alpha4
   name: lab02-multi
   
   nodes:
   - role: control-plane
     extraPortMappings:
     - containerPort: 80
       hostPort: 8080
       protocol: TCP
     - containerPort: 443
       hostPort: 8443
       protocol: TCP
   
   - role: worker
     labels:
       tier: frontend
       
   - role: worker
     labels:
       tier: backend
       
   - role: worker
     labels:
       tier: database
   ```

2. **Criar o cluster**:
   ```bash
   kind create cluster --config multi-node-config.yaml
   ```

3. **Explorar a configuração**:
   ```bash
   # Verificar nós e labels
   kubectl get nodes --show-labels
   
   # Verificar containers Docker
   docker ps | grep lab02-multi
   
   # Verificar mapeamento de portas
   docker port lab02-multi-control-plane
   ```

4. **Testar scheduling com node affinity**:
   ```yaml
   # deployment-with-affinity.yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: frontend-app
   spec:
     replicas: 2
     selector:
       matchLabels:
         app: frontend
     template:
       metadata:
         labels:
           app: frontend
       spec:
         nodeSelector:
           tier: frontend
         containers:
         - name: nginx
           image: nginx
           ports:
           - containerPort: 80
   ---
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: backend-app
   spec:
     replicas: 2
     selector:
       matchLabels:
         app: backend
     template:
       metadata:
         labels:
           app: backend
       spec:
         nodeSelector:
           tier: backend
         containers:
         - name: busybox
           image: busybox
           command: ['sleep', '3600']
   ```

5. **Aplicar e verificar**:
   ```bash
   kubectl apply -f deployment-with-affinity.yaml
   
   # Verificar onde os pods foram agendados
   kubectl get pods -o wide
   
   # Verificar que estão nos nós corretos
   kubectl get nodes -l tier=frontend
   kubectl get nodes -l tier=backend
   ```

#### ✅ Critérios de Sucesso
- Cluster multi-node criado (1 control-plane + 3 workers)
- Nós com labels corretas
- Pods agendados nos nós específicos conforme node selector

### Exercício 3: Configuração Avançada (30 min)

#### Tarefa
Configurar um cluster com features avançadas e networking customizado.

#### Passos
1. **Criar configuração avançada** (`advanced-config.yaml`):
   ```yaml
   kind: Cluster
   apiVersion: kind.x-k8s.io/v1alpha4
   name: lab03-advanced
   
   networking:
     # Desabilitar CNI padrão para instalar Calico
     disableDefaultCNI: true
     podSubnet: "192.168.0.0/16"
     serviceSubnet: "10.96.0.0/12"
   
   nodes:
   - role: control-plane
     kubeadmConfigPatches:
     - |
       kind: InitConfiguration
       nodeRegistration:
         kubeletExtraArgs:
           node-labels: "ingress-ready=true"
     extraPortMappings:
     - containerPort: 80
       hostPort: 30080
       protocol: TCP
     - containerPort: 443
       hostPort: 30443
       protocol: TCP
   
   - role: worker
   - role: worker
   
   featureGates:
     EphemeralContainers: true
   ```

2. **Criar cluster avançado**:
   ```bash
   kind create cluster --config advanced-config.yaml
   ```

3. **Verificar configuração de rede**:
   ```bash
   # Verificar que não há CNI instalado
   kubectl get pods -n kube-system | grep -E "(calico|weave|flannel)"
   
   # Verificar que nós estão NotReady (esperado sem CNI)
   kubectl get nodes
   ```

4. **Instalar Calico CNI**:
   ```bash
   # Instalar Calico
   kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml
   
   # Aguardar Calico ficar pronto
   kubectl wait --for=condition=ready pod -l k8s-app=calico-node -n kube-system --timeout=300s
   
   # Verificar que nós estão Ready agora
   kubectl get nodes
   ```

5. **Testar conectividade de rede**:
   ```bash
   # Criar pods de teste
   kubectl run pod1 --image=busybox -- sleep 3600
   kubectl run pod2 --image=busybox -- sleep 3600
   
   # Aguardar pods ficarem prontos
   kubectl wait --for=condition=ready pod pod1 pod2
   
   # Obter IPs dos pods
   POD1_IP=$(kubectl get pod pod1 -o jsonpath='{.status.podIP}')
   POD2_IP=$(kubectl get pod pod2 -o jsonpath='{.status.podIP}')
   
   echo "Pod1 IP: $POD1_IP"
   echo "Pod2 IP: $POD2_IP"
   
   # Testar conectividade entre pods
   kubectl exec pod1 -- ping -c 3 $POD2_IP
   kubectl exec pod2 -- ping -c 3 $POD1_IP
   ```

#### ✅ Critérios de Sucesso
- Cluster criado sem CNI padrão
- Calico instalado e funcionando
- Nós em estado Ready
- Conectividade entre pods funcionando

### Exercício 4: Gerenciamento Multi-Cluster (20 min)

#### Tarefa
Gerenciar múltiplos clusters simultaneamente.

#### Passos
1. **Criar múltiplos clusters**:
   ```bash
   # Cluster de desenvolvimento
   kind create cluster --name dev
   
   # Cluster de staging
   kind create cluster --name staging
   
   # Cluster de produção
   kind create cluster --name prod
   ```

2. **Explorar contextos**:
   ```bash
   # Listar todos os clusters
   kind get clusters
   
   # Listar contextos kubectl
   kubectl config get-contexts
   
   # Verificar contexto atual
   kubectl config current-context
   ```

3. **Alternar entre clusters e deployar aplicações**:
   ```bash
   # Deploy no cluster dev
   kubectl config use-context kind-dev
   kubectl create deployment app-dev --image=nginx
   kubectl expose deployment app-dev --port=80 --type=NodePort
   
   # Deploy no cluster staging
   kubectl config use-context kind-staging
   kubectl create deployment app-staging --image=nginx:1.20
   kubectl expose deployment app-staging --port=80 --type=NodePort
   
   # Deploy no cluster prod
   kubectl config use-context kind-prod
   kubectl create deployment app-prod --image=nginx:1.21-alpine
   kubectl expose deployment app-prod --port=80 --type=NodePort
   ```

4. **Verificar deployments em todos os clusters**:
   ```bash
   # Criar script para verificar todos os clusters
   for cluster in dev staging prod; do
     echo "=== Cluster: $cluster ==="
     kubectl get deployments --context kind-$cluster
     kubectl get svc --context kind-$cluster
     echo ""
   done
   ```

5. **Limpeza seletiva**:
   ```bash
   # Deletar apenas cluster dev
   kind delete cluster --name dev
   
   # Verificar clusters restantes
   kind get clusters
   ```

#### ✅ Critérios de Sucesso
- 3 clusters criados com sucesso
- Aplicações deployadas em cada cluster
- Consegue alternar entre contextos
- Verificação funciona em todos os clusters

## 🧹 Limpeza Final

```bash
# Deletar todos os clusters criados no laboratório
kind delete cluster --name lab01
kind delete cluster --name lab02-multi
kind delete cluster --name lab03-advanced
kind delete cluster --name staging
kind delete cluster --name prod

# Verificar limpeza
kind get clusters
docker ps | grep kind
```

## 📝 Relatório de Laboratório

Ao final, documente:

1. **Problemas encontrados** e como foram resolvidos
2. **Diferenças observadas** entre clusters single-node e multi-node
3. **Performance comparativa** entre diferentes configurações
4. **Lições aprendidas** sobre networking e scheduling

## 🎯 Desafios Extra

### Desafio 1: Registry Local
Configure um registry Docker local e conecte-o ao cluster Kind.

### Desafio 2: Persistent Volumes
Configure volumes persistentes em um cluster Kind.

### Desafio 3: High Availability
Crie um cluster com múltiplos control-plane nodes.

---

**🎉 Laboratório concluído! Você agora domina a criação e gerenciamento de clusters Kind.**