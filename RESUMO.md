# 🚨 Kubernetes - Guia de Referência Rápida

> **Documento de emergência:** Comandos essenciais e conceitos-chave para consulta rápida

**Use este guia quando precisar:**
- ⚡ Subir cluster rapidamente
- 🔧 Resolver problemas urgentes
- 📝 Relembrar comandos importantes
- 🚀 Fazer deploy emergencial

---

## 📋 Índice Rápido

- [Setup Inicial](#-setup-inicial)
- [Cluster com Kind](#-cluster-com-kind)
- [Deploy de Aplicação](#-deploy-de-aplicação)
- [Comandos Essenciais](#-comandos-essenciais-kubectl)
- [Auto-Healing](#-auto-healing)
- [Auto-Scaling (HPA)](#-auto-scaling-hpa)
- [Troubleshooting](#-troubleshooting)
- [Manifestos YAML Rápidos](#-manifestos-yaml-rápidos)

---

## 🔧 Setup Inicial

### Verificar Pré-requisitos
```powershell
# Docker rodando?
docker ps

# Kind instalado?
kind version

# kubectl instalado?
kubectl version --client

# Recursos disponíveis?
docker info | Select-String "CPUs", "Total Memory"
```

### Instalação Rápida (se necessário)
```powershell
# Windows - Kind
choco install kind

# Windows - kubectl
choco install kubernetes-cli

# Linux/Mac - Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

---

## 🐳 Cluster com Kind

### Criar Cluster Mínimo (30 segundos)
```powershell
# Cluster single-node
kind create cluster --name meu-cluster

# Verificar
kubectl cluster-info --context kind-meu-cluster
kubectl get nodes
```

### Criar Cluster Multi-Node (recomendado)
```powershell
# Criar config
@"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: lab-cluster
nodes:
  - role: control-plane
    extraPortMappings:
    - containerPort: 30080
      hostPort: 30080
  - role: worker
  - role: worker
"@ | Out-File cluster-config.yaml -Encoding UTF8

# Criar cluster
kind create cluster --config cluster-config.yaml
```

### Cluster com Metrics Server (para HPA)
```powershell
# Aplicar metrics-server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch para Kind
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
  {"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}
]'

# Aguardar (~60s)
kubectl wait --for=condition=ready pod -l k8s-app=metrics-server -n kube-system --timeout=120s

# Verificar métricas
kubectl top nodes
```

### Deletar Cluster
```powershell
# Deletar específico
kind delete cluster --name lab-cluster

# Deletar todos
kind delete clusters --all
```

---

## 🚀 Deploy de Aplicação

### Deploy Rápido (Super Mario ou 2048)

#### Super Mario (porta 30090)
```powershell
# Criar namespace
kubectl create namespace games

# Deployment
kubectl create deployment super-mario --image=pengbai/docker-supermario -n games

# Expor serviço
kubectl expose deployment super-mario --port=8080 --target-port=8080 --type=NodePort --name=mario-svc -n games

# Ajustar NodePort para 30090
kubectl patch service mario-svc -n games -p '{"spec":{"ports":[{"port":8080,"nodePort":30090}]}}'

# Acessar
Start-Process "http://localhost:30090"
```

#### Jogo 2048 (porta 30080)
```powershell
kubectl create namespace games
kubectl create deployment game-2048 --image=alexwhen/docker-2048 -n games
kubectl expose deployment game-2048 --port=80 --target-port=80 --type=NodePort --name=game-svc -n games
kubectl patch service game-svc -n games -p '{"spec":{"ports":[{"port":80,"nodePort":30080}]}}'
Start-Process "http://localhost:30080"
```

### Deploy com YAML (Produção)

**Deployment básico:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minha-app
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: minha-app
  template:
    metadata:
      labels:
        app: minha-app
    spec:
      containers:
      - name: app
        image: minha-imagem:latest
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 256Mi
```

**Service NodePort:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: minha-app-svc
spec:
  type: NodePort
  selector:
    app: minha-app
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
```

**Aplicar:**
```powershell
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

---

## 📦 Comandos Essenciais kubectl

### Ver Recursos
```powershell
# Tudo em um namespace
kubectl get all -n games

# Pods
kubectl get pods -n games
kubectl get pods -n games -o wide  # Mais detalhes
kubectl get pods --all-namespaces  # Todos os namespaces

# Deployments
kubectl get deployments -n games

# Services
kubectl get services -n games

# Ver YAML de recurso
kubectl get deployment minha-app -o yaml
```

### Descrever (Debug)
```powershell
# Detalhes + eventos
kubectl describe pod <pod-name> -n games
kubectl describe deployment <deployment-name> -n games
kubectl describe node <node-name>
```

### Logs
```powershell
# Logs de um pod
kubectl logs <pod-name> -n games

# Logs em tempo real
kubectl logs -f <pod-name> -n games

# Logs de todos os pods de um deployment
kubectl logs -l app=minha-app -n games --all-containers=true

# Últimas 50 linhas
kubectl logs --tail=50 <pod-name> -n games
```

### Executar Comandos
```powershell
# Shell interativo
kubectl exec -it <pod-name> -n games -- /bin/sh
kubectl exec -it <pod-name> -n games -- /bin/bash

# Comando único
kubectl exec <pod-name> -n games -- ls /app
kubectl exec <pod-name> -n games -- env
```

### Escalar
```powershell
# Escalar manualmente
kubectl scale deployment minha-app --replicas=5 -n games

# Ver status
kubectl get deployment minha-app -n games
```

### Deletar
```powershell
# Deletar pod específico
kubectl delete pod <pod-name> -n games

# Deletar deployment (deleta pods também)
kubectl delete deployment minha-app -n games

# Deletar service
kubectl delete service minha-app-svc -n games

# Deletar tudo de um namespace
kubectl delete all --all -n games

# Deletar namespace (deleta tudo dentro)
kubectl delete namespace games
```

### Monitoramento
```powershell
# Watch (atualização contínua)
kubectl get pods -n games --watch

# Métricas (requer metrics-server)
kubectl top nodes
kubectl top pods -n games

# Eventos
kubectl get events -n games --sort-by='.lastTimestamp'
```

---

## 🔧 Auto-Healing

### Conceito
Kubernetes **automaticamente recria pods** que falham ou são deletados.

### Testar
```powershell
# 1. Ver pods rodando
kubectl get pods -n games

# 2. Deletar um pod
kubectl delete pod <pod-name> -n games

# 3. Observar novo pod sendo criado
kubectl get pods -n games --watch

# Resultado: Pod deletado → Novo pod criado em ~10s
```

### Como Funciona
```
ReplicaSet Controller:
1. Monitora estado atual (quantos pods rodando?)
2. Compara com estado desejado (quantos pods devem rodar?)
3. Se diferente → cria/deleta pods
4. Repete a cada 15s
```

### Forçar Restart de Deployment
```powershell
# Restart todos os pods (rolling restart)
kubectl rollout restart deployment minha-app -n games

# Ver status
kubectl rollout status deployment minha-app -n games
```

---

## 📈 Auto-Scaling (HPA)

### Conceito
**Horizontal Pod Autoscaler** ajusta número de réplicas baseado em CPU/memória.

### Pré-requisito
- ✅ Metrics Server instalado e funcionando
- ✅ Pods com `resources.requests` definidos

### Criar HPA (Imperativo)
```powershell
# HPA baseado em CPU
kubectl autoscale deployment minha-app --cpu-percent=50 --min=2 --max=10 -n games

# Ver HPA
kubectl get hpa -n games
```

### Criar HPA (YAML - Recomendado)
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: minha-app-hpa
  namespace: games
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: minha-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
```

### Monitorar HPA
```powershell
# Ver status
kubectl get hpa -n games

# Watch contínuo
kubectl get hpa -n games --watch

# Detalhes
kubectl describe hpa minha-app-hpa -n games

# Ver métricas atuais
kubectl top pods -n games
```

### Testar Auto-Scaling
```powershell
# Gerar carga (criar pod que faz requests)
kubectl run load-gen --image=busybox -n games --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://minha-app-svc; done"

# Observar scaling
kubectl get hpa -n games --watch

# Parar carga
kubectl delete pod load-gen -n games
```

### Fórmula do HPA
```
desiredReplicas = ⌈currentReplicas × (currentCPU / targetCPU)⌉

Exemplo:
- Réplicas atuais: 2
- CPU atual: 80%
- CPU alvo: 50%
→ Réplicas desejadas = ⌈2 × (80/50)⌉ = 4 pods
```

---

## 🚨 Troubleshooting

### Pod Não Inicia

**Ver status:**
```powershell
kubectl get pods -n games
kubectl describe pod <pod-name> -n games
```

**Problemas comuns:**

| Status | Causa Provável | Solução |
|--------|----------------|---------|
| `ImagePullBackOff` | Imagem não existe/privada | Verificar nome da imagem |
| `CrashLoopBackOff` | App crashando | Ver logs: `kubectl logs` |
| `Pending` | Sem recursos | Ver eventos: `kubectl describe pod` |
| `Error` | Falha ao iniciar | Ver logs e eventos |

**Debug:**
```powershell
# Ver eventos
kubectl get events -n games --sort-by='.lastTimestamp' | Select-String <pod-name>

# Ver logs (mesmo se pod crashou)
kubectl logs <pod-name> -n games --previous
```

### HPA Mostra `<unknown>`

**Causa:** Metrics Server não está funcionando ou sem dados ainda

**Solução:**
```powershell
# 1. Verificar metrics-server
kubectl get deployment metrics-server -n kube-system

# 2. Ver logs
kubectl logs -n kube-system -l k8s-app=metrics-server

# 3. Aguardar 1-2 minutos
Start-Sleep -Seconds 120

# 4. Testar métricas
kubectl top nodes
kubectl top pods -n games
```

### Service Não Responde

**Verificar:**
```powershell
# 1. Service existe?
kubectl get service -n games

# 2. Tem endpoints (pods)?
kubectl get endpoints -n games

# 3. Portas corretas?
kubectl describe service minha-app-svc -n games

# 4. Testar internamente
kubectl run test --image=busybox --rm -it -- wget -O- http://minha-app-svc.games.svc.cluster.local
```

### Cluster Lento/Travado

**Verificar recursos:**
```powershell
# CPU e memória dos nós
kubectl top nodes

# Pods consumindo muito
kubectl top pods --all-namespaces | Sort-Object -Descending

# Ver pods em todos os namespaces
kubectl get pods --all-namespaces
```

**Limpar recursos:**
```powershell
# Deletar pods completed/errored
kubectl delete pod --field-selector=status.phase==Succeeded --all-namespaces
kubectl delete pod --field-selector=status.phase==Failed --all-namespaces

# Limpar imagens não usadas no Docker
docker system prune -a
```

### Resetar Tudo
```powershell
# Deletar cluster e recriar
kind delete cluster --name lab-cluster
kind create cluster --name lab-cluster

# Ou reiniciar Docker Desktop
```

---

## 📝 Manifestos YAML Rápidos

### Namespace
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: meu-namespace
```

### Deployment Completo
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  namespace: default
  labels:
    app: minha-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: minha-app
  template:
    metadata:
      labels:
        app: minha-app
    spec:
      containers:
      - name: app
        image: nginx:latest
        ports:
        - containerPort: 80
          name: http
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
```

### Service (3 tipos)

**ClusterIP (interno):**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: app-svc
spec:
  type: ClusterIP
  selector:
    app: minha-app
  ports:
  - port: 80
    targetPort: 80
```

**NodePort (acesso externo - Kind):**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: app-svc
spec:
  type: NodePort
  selector:
    app: minha-app
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080  # 30000-32767
```

**LoadBalancer (cloud):**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: app-svc
spec:
  type: LoadBalancer
  selector:
    app: minha-app
  ports:
  - port: 80
    targetPort: 80
```

### ConfigMap
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  database_url: "postgres://localhost:5432/db"
  app_mode: "production"
```

### Secret
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
type: Opaque
data:
  password: cGFzc3dvcmQxMjM=  # base64 encoded
```

---

## ⚡ Comandos de Uma Linha

```powershell
# Criar deployment rápido
kubectl create deployment nginx --image=nginx --replicas=3

# Expor deployment
kubectl expose deployment nginx --port=80 --type=NodePort

# Ver tudo
kubectl get all -A

# Restart deployment
kubectl rollout restart deployment/nginx

# Ver uso de recursos
kubectl top nodes && kubectl top pods -A

# Criar namespace
kubectl create namespace dev

# Aplicar todos YAMLs de uma pasta
kubectl apply -f ./manifests/

# Deletar tudo de um namespace
kubectl delete all --all -n dev

# Port-forward para acesso local
kubectl port-forward svc/nginx 8080:80

# Ver pods que não estão Running
kubectl get pods --all-namespaces --field-selector=status.phase!=Running

# Backup de recursos
kubectl get all -o yaml > backup.yaml

# Ver contexts disponíveis
kubectl config get-contexts

# Mudar context
kubectl config use-context kind-lab-cluster
```

---

## 🎯 Fluxos de Trabalho Comuns

### Deploy Nova Aplicação
```powershell
# 1. Criar namespace
kubectl create namespace minha-app

# 2. Criar deployment
kubectl apply -f deployment.yaml

# 3. Criar service
kubectl apply -f service.yaml

# 4. (Opcional) Criar HPA
kubectl apply -f hpa.yaml

# 5. Verificar
kubectl get all -n minha-app

# 6. Acessar
Start-Process "http://localhost:30080"
```

### Atualizar Imagem
```powershell
# Atualizar imagem
kubectl set image deployment/minha-app app=nova-imagem:v2 -n minha-app

# Verificar rollout
kubectl rollout status deployment/minha-app -n minha-app

# Ver histórico
kubectl rollout history deployment/minha-app -n minha-app

# Rollback se necessário
kubectl rollout undo deployment/minha-app -n minha-app
```

### Debug de Pod
```powershell
# 1. Ver status
kubectl get pod <pod-name> -n games

# 2. Descrever (eventos)
kubectl describe pod <pod-name> -n games

# 3. Ver logs
kubectl logs <pod-name> -n games

# 4. Entrar no pod
kubectl exec -it <pod-name> -n games -- /bin/sh

# 5. Criar pod debug
kubectl debug <pod-name> -n games -it --image=busybox
```

### Limpeza Completa
```powershell
# Deletar namespace (deleta tudo)
kubectl delete namespace games

# Ou deletar recursos individualmente
kubectl delete deployment,service,hpa --all -n games

# Deletar cluster
kind delete cluster --name lab-cluster

# Limpar Docker
docker system prune -a -f
```

---

## 📚 Conceitos-Chave

### Pods
- **Menor unidade deployável**
- Pode ter 1+ containers
- Efêmero (pode ser deletado/recriado)
- IP dinâmico

### ReplicaSet
- Mantém número desejado de pods
- Auto-healing automático
- Geralmente gerenciado por Deployment

### Deployment
- Gerencia ReplicaSets
- Rolling updates
- Rollback
- Declarativo

### Service
- Abstração de rede estável
- Load balancing interno
- DNS interno (nome.namespace.svc.cluster.local)
- 3 tipos: ClusterIP, NodePort, LoadBalancer

### HPA
- Ajusta réplicas automaticamente
- Baseado em métricas (CPU, memória, custom)
- Requer Metrics Server
- Min/max configuráveis

### Namespace
- Isolamento lógico
- Quotas de recursos
- Boas práticas: dev, staging, prod

---

## 🔗 Links Rápidos

- [Kubernetes Docs](https://kubernetes.io/docs/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Kind Docs](https://kind.sigs.k8s.io/)
- [Metrics Server](https://github.com/kubernetes-sigs/metrics-server)

---

## 📞 Próximos Passos

**Se você tem tempo:**
- 📖 Leia o curso completo em `curso-k8s/`
- 🧪 Faça os laboratórios práticos
- 🎮 Deploy Super Mario e 2048
- 📊 Configure monitoring avançado

**Se está com pressa:**
- ⚡ Use este guia como referência
- 🔖 Marque as seções importantes
- 🚀 Execute os comandos conforme necessário

---

<div align="center">

## ⚡ Lembre-se

**Em caso de pânico:**
1. `kubectl get pods -n <namespace>` - Ver o que está rodando
2. `kubectl describe pod <pod-name>` - Ver o que deu errado
3. `kubectl logs <pod-name>` - Ver logs
4. Google / Stack Overflow / ChatGPT

**Este guia é seu amigo em emergências! 🚨**

---

**Última atualização:** Janeiro 2026  
**Curso completo:** [README.md](../README.md)

</div>
