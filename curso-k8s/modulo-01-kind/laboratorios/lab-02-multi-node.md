# 🥈 Lab 02: Cluster Multi-Node

**Duração**: 30 minutos  
**Dificuldade**: ⭐⭐☆☆☆  
**Objetivo**: Criar e gerenciar cluster com múltiplos workers

---

## 📋 Pré-requisitos

- ✅ Lab 01 completo
- ✅ Docker com 4GB RAM disponível
- ✅ Kind instalado e funcionando

### Verificação Rápida

```powershell
# Verificar Kind
kind version

# Verificar recursos Docker
docker info | Select-String "CPUs", "Total Memory"

# Limpar clusters anteriores
kind delete cluster
```

**Linux/macOS:**
```bash
# Verificar Kind
kind version

# Verificar recursos Docker
docker info | grep -E "CPUs|Total Memory"

# Limpar clusters anteriores
kind delete cluster
```

---

## 🎯 Objetivos de Aprendizado

Ao final deste lab, você será capaz de:

- ✅ Criar configuração YAML para cluster multi-node
- ✅ Deploy cluster com 1 control-plane + 2 workers
- ✅ Verificar distribuição de pods entre nodes
- ✅ Entender Kubernetes scheduling
- ✅ Testar node affinity
- ✅ Simular falha de node
- ✅ Observar rescheduling automático

---

## 📝 Parte 1: Configuração do Cluster

### Passo 1: Criar Arquivo de Configuração

```powershell
# Navegar para pasta do módulo
cd c:\Users\marce\Documents\personal_projects\k8s\curso\modulo-01-kind

# Criar diretório para configs (se não existir)
New-Item -ItemType Directory -Path ".\temp-configs" -Force

# Criar arquivo de config
@"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: multi-node
nodes:
- role: control-plane
  labels:
    tier: control
- role: worker
  labels:
    tier: compute
    zone: zone-a
- role: worker
  labels:
    tier: compute
    zone: zone-b
"@ | Out-File -FilePath ".\temp-configs\kind-multi-node.yaml" -Encoding UTF8

# Visualizar o arquivo
Get-Content ".\temp-configs\kind-multi-node.yaml"
```

**Linux/macOS:**
```bash
# Navegar para pasta do módulo (ajuste o caminho)
cd ~/Documents/k8s/curso/modulo-01-kind

# Criar diretório para configs
mkdir -p ./temp-configs

# Criar arquivo de config
cat <<EOF > ./temp-configs/kind-multi-node.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: multi-node
nodes:
- role: control-plane
  labels:
    tier: control
- role: worker
  labels:
    tier: compute
    zone: zone-a
- role: worker
  labels:
    tier: compute
    zone: zone-b
EOF

# Visualizar o arquivo
cat ./temp-configs/kind-multi-node.yaml
```

**💡 Explicação da Config:**
- `kind: Cluster` - Tipo de recurso
- `nodes` - Lista de nodes
- `role: control-plane` - Node master
- `role: worker` - Nodes workers
- `labels` - Labels customizados para scheduling

---

## 🚀 Parte 2: Criar Cluster Multi-Node

### Passo 2: Deploy do Cluster

```powershell
# Criar cluster usando arquivo de config
kind create cluster --config .\temp-configs\kind-multi-node.yaml

# Aguarde aproximadamente 2-3 minutos
```

**Saída esperada:**
```
Creating cluster "multi-node" ...
 ✓ Ensuring node image (kindest/node:v1.27.3) 🖼
 ✓ Preparing nodes 📦 📦 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing CNI 🔌
 ✓ Installing StorageClass 💾
 ✓ Joining worker nodes 🚜
Set kubectl context to "kind-multi-node"
```

### Passo 3: Verificar Nodes

```powershell
# Listar todos os nodes
kubectl get nodes

# Ver detalhes dos nodes
kubectl get nodes -o wide

# Ver labels dos nodes
kubectl get nodes --show-labels
```

**Saída esperada:**
```
NAME                       STATUS   ROLES           AGE   VERSION
multi-node-control-plane   Ready    control-plane   2m    v1.35.0
multi-node-worker          Ready    <none>          2m    v1.35.0
multi-node-worker2         Ready    <none>          2m    v1.35.0
```

### Passo 4: Inspecionar Nodes Individualmente

```powershell
# Control-plane
kubectl describe node multi-node-control-plane | Select-String "Roles", "Labels", "Taints"

# Worker 1
kubectl describe node multi-node-worker | Select-String "Labels"

# Worker 2
kubectl describe node multi-node-worker2 | Select-String "Labels"

# Ver containers Docker (3 containers = 3 nodes)
docker ps
```

**Linux/macOS:**
```bash
# Control-plane
kubectl describe node multi-node-control-plane | grep -E "Roles|Labels|Taints"

# Worker 1
kubectl describe node multi-node-worker | grep "Labels"

# Worker 2
kubectl describe node multi-node-worker2 | grep "Labels"

# Ver containers Docker (3 containers = 3 nodes)
docker ps
```

---

## 🎨 Parte 3: Deploy e Distribuição de Pods

### Passo 5: Deploy Aplicação com Múltiplas Réplicas

```powershell
# Carregar imagem nginx:alpine (opcional, Kind puxa automaticamente)
docker pull nginx:alpine
kind load docker-image nginx:alpine

# Caso ocorra o seguinte erro:
# ERROR: failed to load image: command "docker exec --privileged -i kind-control-plane ctr --namespace=k8s.io images import --all-platforms --digests --snapshotter=overlayfs -" failed with error: exit status 1
# Command Output: ctr: content digest sha256:c8e83139ec2e197e88756ea0648745b9783ac2524fe3e861e50b0ada8c28d8f2: not found

docker exec -it kind-control-plane 
ctr -n k8s.io images pull docker.io/library/nginx:alpine
exit

# Criar deployment com 6 réplicas
kubectl create deployment nginx --image=nginx:alpine
kubectl scale deployment nginx --replicas=6

# Aguardar todos os pods ficarem prontos
kubectl wait --for=condition=ready pod -l app=nginx --timeout=120s --all

# Ver distribuição de pods entre nodes
kubectl get pods -l app=nginx -o wide
```

**💡 Observação:** Você verá os pods distribuídos automaticamente entre os 2 workers.

### Passo 6: Verificar Distribuição

```powershell
# Contar pods por node
kubectl get pods -l app=nginx -o wide | Select-String "worker"

# Ver métricas de distribuição
kubectl get pods -l app=nginx -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.nodeName}{"\n"}{end}'

# Verificar recursos dos nodes
kubectl describe nodes | Select-String "Non-terminated Pods"
```

**Linux/macOS:**
```bash
# Contar pods por node
kubectl get pods -l app=nginx -o wide | grep "worker"

# Ver métricas de distribuição
kubectl get pods -l app=nginx -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.nodeName}{"\n"}{end}'

# Verificar recursos dos nodes
kubectl describe nodes | grep "Non-terminated Pods"
```

---

## 🎯 Parte 4: Node Affinity e Scheduling

### Passo 7: Deploy com Node Selector

```powershell
# Criar deployment que roda apenas em zone-a
@"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-zone-a
spec:
  replicas: 3
  selector:
    matchLabels:
      app: app-zone-a
  template:
    metadata:
      labels:
        app: app-zone-a
    spec:
      nodeSelector:
        zone: zone-a
      containers:
      - name: nginx
        image: nginx:alpine
"@ | kubectl apply -f -

# Verificar onde os pods foram agendados
kubectl get pods -l app=app-zone-a -o wide
```

**Resultado esperado:** Todos os pods em `multi-node-worker` (zone-a)

### Passo 8: Deploy com Node Affinity

```powershell
# Deployment com preferência por zone-b
@"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-zone-b
spec:
  replicas: 3
  selector:
    matchLabels:
      app: app-zone-b
  template:
    metadata:
      labels:
        app: app-zone-b
    spec:
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: zone
                operator: In
                values:
                - zone-b
      containers:
      - name: nginx
        image: nginx:alpine
"@ | kubectl apply -f -

# Verificar distribuição
kubectl get pods -l app=app-zone-b -o wide
```

---

## 🧪 Parte 5: Teste de Falha de Node

### Passo 9: Simular Falha de Node

```powershell
# Ver pods atuais
kubectl get pods -o wide

# Parar um worker node (simular falha)
docker stop multi-node-worker

# Ver status dos nodes
kubectl get nodes

# Aguardar node ser marcado como NotReady (pode levar 40-60 segundos)
Start-Sleep -Seconds 60
kubectl get nodes
```

**Saída esperada:**
```
NAME                       STATUS     ROLES           AGE
multi-node-control-plane   Ready      control-plane   10m
multi-node-worker          NotReady   <none>          10m  # ❌ 
multi-node-worker2         Ready      <none>          10m
```

### Passo 10: Observar Rescheduling

```powershell
# Ver pods sendo rescheduled
kubectl get pods -o wide -w  # Ctrl+C para parar

# Ver eventos de rescheduling
kubectl get events --sort-by='.lastTimestamp' | Select-Object -Last 20

# Ver pods em estado de eviction
kubectl get pods -A -o wide | Select-String "Evicted"
```

**Linux/macOS:**
```bash
# Ver pods sendo rescheduled
kubectl get pods -o wide -w  # Ctrl+C para parar

# Ver eventos de rescheduling (últimos 20)
kubectl get events --sort-by='.lastTimestamp' | tail -n 20

# Ver pods em estado de eviction
kubectl get pods -A -o wide | grep "Evicted"
```

### Passo 11: Recuperar Node

```powershell
# Religar o worker
docker start multi-node-worker

# Aguardar node voltar a Ready
Start-Sleep -Seconds 30
kubectl get nodes

# Ver pods redistribuídos
kubectl get pods -o wide
```

---

## 📊 Parte 6: Análise de Recursos

### Passo 12: Ver Uso de Recursos

```powershell
# Instalar metrics-server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch para Kind
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--kubelet-insecure-tls"
  }
]'

# Aguardar metrics-server ficar pronto
kubectl wait --for=condition=ready pod -l k8s-app=metrics-server -n kube-system --timeout=120s

# Ver uso de recursos por node
kubectl top nodes

# Ver uso por pod
kubectl top pods -A
```

### Passo 13: Capacidade dos Nodes

```powershell
# Ver capacidade total
kubectl get nodes -o json | ConvertFrom-Json | ForEach-Object {
    $_.items | Select-Object @{
        Name='Node';Expression={$_.metadata.name}
    }, @{
        Name='CPU';Expression={$_.status.capacity.cpu}
    }, @{
        Name='Memory';Expression={$_.status.capacity.memory}
    }
}

# Ver recursos alocáveis
kubectl describe nodes | Select-String "Allocatable:" -Context 0,5
```

**Linux/macOS:**
```bash
# Ver capacidade total (com jq)
kubectl get nodes -o json | jq -r '.items[] | "\(.metadata.name)\t\(.status.capacity.cpu)\t\(.status.capacity.memory)"'

# Ou usando jsonpath
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.capacity.cpu}{"\t"}{.status.capacity.memory}{"\n"}{end}'

# Ver recursos alocáveis (5 linhas após "Allocatable:")
kubectl describe nodes | grep -A 5 "Allocatable:"
```

---

## 🔧 Parte 7: Troubleshooting Multi-Node

### Passo 14: Diagnóstico de Problemas

```powershell
# Ver pods que não estão rodando
kubectl get pods -A --field-selector=status.phase!=Running

# Ver nodes com problemas
kubectl get nodes -o json | ConvertFrom-Json | ForEach-Object {
    $_.items | Where-Object { $_.status.conditions | Where-Object { $_.type -eq "Ready" -and $_.status -ne "True" } }
}

# Logs do kubelet de um worker
docker exec multi-node-worker journalctl -u kubelet --no-pager | Select-Object -Last 50

# Ver comunicação entre nodes
kubectl exec -it deployment/nginx -- ping -c 3 multi-node-worker2
```

**Linux/macOS:**
```bash
# Ver pods que não estão rodando
kubectl get pods -A --field-selector=status.phase!=Running

# Ver nodes com problemas (com jq)
kubectl get nodes -o json | jq '.items[] | select(.status.conditions[] | select(.type=="Ready" and .status!="True"))'

# Logs do kubelet de um worker (últimas 50 linhas)
docker exec multi-node-worker journalctl -u kubelet --no-pager | tail -n 50

# Ver comunicação entre nodes
kubectl exec -it deployment/nginx -- ping -c 3 multi-node-worker2
```

---

## 🎯 Parte 8: Testes Avançados

### Passo 15: DaemonSet (Pod em Cada Node)

```powershell
# Criar DaemonSet
@"
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-monitor
spec:
  selector:
    matchLabels:
      app: node-monitor
  template:
    metadata:
      labels:
        app: node-monitor
    spec:
      containers:
      - name: busybox
        image: busybox:latest
        command: ["sh", "-c", "while true; do echo 'Monitoring node:' \$(hostname); sleep 60; done"]
"@ | kubectl apply -f -

# Verificar que há 1 pod por worker node
kubectl get pods -l app=node-monitor -o wide

# Ver logs de cada pod
kubectl logs -l app=node-monitor --all-containers=true --tail=5
```

### Passo 16: Testar Pod Anti-Affinity

```powershell
# Deployment que evita co-localização
@"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-cluster
spec:
  replicas: 2
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - redis
            topologyKey: kubernetes.io/hostname
      containers:
      - name: redis
        image: redis:alpine
"@ | kubectl apply -f -

# Verificar que pods estão em nodes diferentes
kubectl get pods -l app=redis -o wide
```

---

## 🧹 Parte 9: Limpeza

### Passo 17: Limpar Recursos

```powershell
# Deletar deployments
kubectl delete deployment nginx app-zone-a app-zone-b redis-cluster

# Deletar daemonset
kubectl delete daemonset node-monitor

# Verificar limpeza
kubectl get all
```

### Passo 18: Deletar Cluster

```powershell
# Deletar cluster multi-node
kind delete cluster --name multi-node

# Verificar
kind get clusters
docker ps

# Limpar arquivos temporários
Remove-Item -Path ".\temp-configs\kind-multi-node.yaml" -Force
```

---

## ✅ Checklist de Conclusão

- [ ] Arquivo de config YAML criado
- [ ] Cluster multi-node deployado
- [ ] Distribuição de pods verificada
- [ ] Node selector testado
- [ ] Node affinity aplicado
- [ ] Falha de node simulada
- [ ] Rescheduling observado
- [ ] Metrics-server instalado
- [ ] DaemonSet testado
- [ ] Anti-affinity testado
- [ ] Cluster deletado

---

## 🎓 O Que Você Aprendeu

Neste laboratório, você:

1. **Criou** cluster multi-node com arquivo YAML
2. **Verificou** distribuição automática de pods
3. **Aplicou** node selectors e affinity
4. **Simulou** falha de node
5. **Observou** rescheduling automático
6. **Instalou** metrics-server
7. **Testou** DaemonSet
8. **Explorou** pod anti-affinity

---

## 🚀 Próximos Passos

- **[Lab 03: Ingress-Ready](./lab-03-ingress-ready.md)** - Port mapping e acesso externo
- **[Lab 04: Múltiplos Clusters](./lab-04-multiplos-clusters.md)** - Gerenciar vários ambientes
- **Experimentar**: Criar cluster com 3+ workers, testar diferentes affinity rules

---

## 💡 Conceitos-Chave

### Kubernetes Scheduling

- **NodeSelector**: Simples, baseado em labels
- **NodeAffinity**: Mais flexível, com preferências
- **PodAffinity**: Pods próximos uns dos outros
- **PodAntiAffinity**: Pods separados

### High Availability

- Múltiplos workers = redundância
- Rescheduling automático em falhas
- DaemonSets = serviço em cada node

---

## 📚 Recursos

- [Assigning Pods to Nodes](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/)
- [Node Affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity)
- [DaemonSet](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/)

---

**🎉 Parabéns por completar o Lab 02!**

Você agora entende como Kubernetes distribui workloads em clusters multi-node!
