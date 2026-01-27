# 🏆 Lab 04: Múltiplos Clusters

**Duração**: 30 minutos  
**Dificuldade**: ⭐⭐⭐☆☆  
**Objetivo**: Gerenciar múltiplos ambientes (dev, staging, prod)

---

## 📋 Pré-requisitos

- ✅ Labs 01, 02 e 03 completos
- ✅ Docker com 6GB+ RAM disponível
- ✅ Entendimento de contextos kubectl

### Verificação

```powershell
kind version
docker info | Select-String "Total Memory"

# Limpar clusters anteriores
kind get clusters | ForEach-Object { kind delete cluster --name $_ }
```

---

## 🎯 Objetivos de Aprendizado

Ao final deste lab, você será capaz de:

- ✅ Criar múltiplos clusters simultaneamente
- ✅ Gerenciar contextos kubectl
- ✅ Switch entre ambientes facilmente
- ✅ Deploy apps em diferentes clusters
- ✅ Simular pipeline de promoção (dev → staging → prod)
- ✅ Cleanup seletivo de clusters

---

## 📝 Parte 1: Planejamento dos Ambientes

### Passo 1: Criar Configurações dos Clusters

```powershell
# Navegar para pasta
cd c:\Users\marce\Documents\personal_projects\k8s\curso\modulo-01-kind

# Criar diretório
New-Item -ItemType Directory -Path ".\temp-configs" -Force

# Config DEV (single-node, leve)
@"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: dev
nodes:
- role: control-plane
  labels:
    environment: dev
"@ | Out-File -FilePath ".\temp-configs\kind-dev.yaml" -Encoding UTF8

# Config STAGING (multi-node)
@"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: staging
nodes:
- role: control-plane
  labels:
    environment: staging
- role: worker
  labels:
    environment: staging
"@ | Out-File -FilePath ".\temp-configs\kind-staging.yaml" -Encoding UTF8

# Config PROD (HA)
@"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: prod
nodes:
- role: control-plane
  labels:
    environment: prod
- role: control-plane
  labels:
    environment: prod
- role: control-plane
  labels:
    environment: prod
- role: worker
  labels:
    environment: prod
- role: worker
  labels:
    environment: prod
"@ | Out-File -FilePath ".\temp-configs\kind-prod.yaml" -Encoding UTF8
```

**💡 Estratégia:**
- **DEV**: Leve, rápido para testes
- **STAGING**: Simula produção
- **PROD**: Alta disponibilidade

---

## 🚀 Parte 2: Criar Todos os Clusters

### Passo 2: Deploy dos 3 Ambientes

```powershell
# Criar cluster DEV
Write-Host "🔨 Creating DEV cluster..." -ForegroundColor Yellow
kind create cluster --config .\temp-configs\kind-dev.yaml

# Criar cluster STAGING
Write-Host "🔨 Creating STAGING cluster..." -ForegroundColor Yellow
kind create cluster --config .\temp-configs\kind-staging.yaml

# Criar cluster PROD
Write-Host "🔨 Creating PROD cluster..." -ForegroundColor Yellow
kind create cluster --config .\temp-configs\kind-prod.yaml

# Aguarde 5-7 minutos para todos os clusters
```

### Passo 3: Verificar Todos os Clusters

```powershell
# Listar clusters Kind
Write-Host "`n📋 Kind Clusters:" -ForegroundColor Cyan
kind get clusters

# Ver containers Docker
Write-Host "`n🐳 Docker Containers:" -ForegroundColor Cyan
docker ps --format "table {{.Names}}\t{{.Status}}"

# Ver contextos kubectl
Write-Host "`n⚙️  Kubectl Contexts:" -ForegroundColor Cyan
kubectl config get-contexts
```

**Saída esperada - Clusters:**
```
dev
prod
staging
```

---

## 🎨 Parte 3: Gerenciar Contextos

### Passo 4: Switch Entre Contextos

```powershell
# Ver contexto atual
kubectl config current-context

# Mudar para DEV
kubectl config use-context kind-dev
kubectl get nodes

# Mudar para STAGING
kubectl config use-context kind-staging
kubectl get nodes

# Mudar para PROD
kubectl config use-context kind-prod
kubectl get nodes
```

### Passo 5: Comandos Diretos com Contexto

```powershell
# Executar comando em contexto específico (sem mudar contexto atual)
kubectl get nodes --context kind-dev
kubectl get nodes --context kind-staging
kubectl get nodes --context kind-prod

# Ver todos os pods de todos os clusters
Write-Host "`nDEV Pods:" -ForegroundColor Green
kubectl get pods -A --context kind-dev

Write-Host "`nSTAGING Pods:" -ForegroundColor Yellow
kubectl get pods -A --context kind-staging

Write-Host "`nPROD Pods:" -ForegroundColor Red
kubectl get pods -A --context kind-prod
```

---

## 🌐 Parte 4: Deploy em Múltiplos Ambientes

### Passo 6: Deploy Versão 1.0 em DEV

```powershell
# Mudar para DEV
kubectl config use-context kind-dev

# Criar namespace app
kubectl create namespace myapp

# Deploy versão 1.0
@"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: myapp
  labels:
    version: v1.0
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
        version: v1.0
    spec:
      containers:
      - name: app
        image: nginx:1.25-alpine
        env:
        - name: ENVIRONMENT
          value: "DEV"
        - name: VERSION
          value: "1.0"
        ports:
        - containerPort: 80
"@ | kubectl apply -f -

# Expor
kubectl expose deployment myapp -n myapp --port=80 --type=ClusterIP

# Verificar
kubectl get all -n myapp
```

### Passo 7: Promover para STAGING

```powershell
# Mudar para STAGING
kubectl config use-context kind-staging

# Criar namespace
kubectl create namespace myapp

# Deploy versão 1.0 (mesma versão de DEV)
@"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: myapp
  labels:
    version: v1.0
spec:
  replicas: 2  # Mais réplicas em staging
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
        version: v1.0
    spec:
      containers:
      - name: app
        image: nginx:1.25-alpine
        env:
        - name: ENVIRONMENT
          value: "STAGING"
        - name: VERSION
          value: "1.0"
        ports:
        - containerPort: 80
"@ | kubectl apply -f -

kubectl expose deployment myapp -n myapp --port=80

# Verificar distribuição em múltiplos workers
kubectl get pods -n myapp -o wide
```

### Passo 8: Promover para PROD

```powershell
# Mudar para PROD
kubectl config use-context kind-prod

# Criar namespace
kubectl create namespace myapp

# Deploy versão 1.0 (produção)
@"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: myapp
  labels:
    version: v1.0
spec:
  replicas: 5  # Mais réplicas em prod
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
        version: v1.0
    spec:
      containers:
      - name: app
        image: nginx:1.25-alpine
        env:
        - name: ENVIRONMENT
          value: "PRODUCTION"
        - name: VERSION
          value: "1.0"
        ports:
        - containerPort: 80
      # Prod tem health checks
      livenessProbe:
        httpGet:
          path: /
          port: 80
        initialDelaySeconds: 5
        periodSeconds: 10
      readinessProbe:
        httpGet:
          path: /
          port: 80
        initialDelaySeconds: 5
        periodSeconds: 5
"@ | kubectl apply -f -

kubectl expose deployment myapp -n myapp --port=80

# Verificar alta disponibilidade
kubectl get pods -n myapp -o wide
kubectl get nodes
```

---

## 📊 Parte 5: Comparar Ambientes

### Passo 9: Status de Todos os Ambientes

```powershell
# Função helper
function Show-EnvStatus {
    param($context, $envName, $color)
    
    Write-Host "`n=== $envName ===" -ForegroundColor $color
    Write-Host "Nodes:" -ForegroundColor $color
    kubectl get nodes --context $context
    
    Write-Host "`nPods:" -ForegroundColor $color
    kubectl get pods -n myapp --context $context -o wide
    
    Write-Host "`nService:" -ForegroundColor $color
    kubectl get svc -n myapp --context $context
}

# Mostrar todos
Show-EnvStatus "kind-dev" "DEV" "Green"
Show-EnvStatus "kind-staging" "STAGING" "Yellow"
Show-EnvStatus "kind-prod" "PROD" "Red"
```

### Passo 10: Testar Conectividade em Cada Ambiente

```powershell
# DEV
kubectl config use-context kind-dev
kubectl run test-dev -n myapp --image=busybox:latest --restart=Never -- sleep 3600
kubectl exec -n myapp test-dev -- wget -O- http://myapp

# STAGING
kubectl config use-context kind-staging
kubectl run test-staging -n myapp --image=busybox:latest --restart=Never -- sleep 3600
kubectl exec -n myapp test-staging -- wget -O- http://myapp

# PROD
kubectl config use-context kind-prod
kubectl run test-prod -n myapp --image=busybox:latest --restart=Never -- sleep 3600
kubectl exec -n myapp test-prod -- wget -O- http://myapp
```

---

## 🔄 Parte 6: Simular Update/Rollout

### Passo 11: Nova Versão em DEV

```powershell
# Mudar para DEV
kubectl config use-context kind-dev

# Atualizar para v1.1
kubectl set image deployment/myapp app=nginx:1.26-alpine -n myapp
kubectl set env deployment/myapp VERSION=1.1 -n myapp

# Aguardar rollout
kubectl rollout status deployment/myapp -n myapp

# Verificar
kubectl get pods -n myapp -o jsonpath='{.items[*].spec.containers[0].image}'
```

### Passo 12: Validar em DEV, Promover para STAGING

```powershell
# Após validação em DEV, atualizar STAGING
kubectl config use-context kind-staging

kubectl set image deployment/myapp app=nginx:1.26-alpine -n myapp
kubectl set env deployment/myapp VERSION=1.1 -n myapp

# Rollout gradual
kubectl rollout status deployment/myapp -n myapp

# Ver histórico
kubectl rollout history deployment/myapp -n myapp
```

### Passo 13: Blue-Green em PROD

```powershell
# Mudar para PROD
kubectl config use-context kind-prod

# Criar deployment v1.1 (green)
@"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-green
  namespace: myapp
spec:
  replicas: 5
  selector:
    matchLabels:
      app: myapp
      slot: green
  template:
    metadata:
      labels:
        app: myapp
        slot: green
        version: v1.1
    spec:
      containers:
      - name: app
        image: nginx:1.26-alpine
        env:
        - name: ENVIRONMENT
          value: "PRODUCTION"
        - name: VERSION
          value: "1.1"
"@ | kubectl apply -f -

# Aguardar pods prontos
kubectl wait --for=condition=ready pod -l slot=green -n myapp --timeout=120s

# Switch service para green
kubectl patch service myapp -n myapp -p '{"spec":{"selector":{"slot":"green"}}}'

# Deletar deployment old (blue)
kubectl delete deployment myapp -n myapp

# Renomear green para padrão
kubectl patch deployment myapp-green -n myapp --type='json' -p='[{"op": "remove", "path": "/spec/selector/matchLabels/slot"}]'
```

---

## 🔧 Parte 7: Gerenciamento Avançado

### Passo 14: Recursos por Cluster

```powershell
# Script para ver recursos de todos os clusters
function Get-ClusterResources {
    foreach ($ctx in @("kind-dev", "kind-staging", "kind-prod")) {
        Write-Host "`n=== $ctx ===" -ForegroundColor Cyan
        
        $nodes = kubectl get nodes --context $ctx --no-headers | Measure-Object
        Write-Host "Nodes: $($nodes.Count)"
        
        $pods = kubectl get pods -A --context $ctx --no-headers | Measure-Object
        Write-Host "Pods: $($pods.Count)"
        
        $deploys = kubectl get deployments -A --context $ctx --no-headers | Measure-Object
        Write-Host "Deployments: $($deploys.Count)"
    }
}

Get-ClusterResources
```

### Passo 15: Backup de Configs

```powershell
# Exportar kubeconfigs
New-Item -ItemType Directory -Path ".\backups" -Force

kind get kubeconfig --name dev > .\backups\kubeconfig-dev.yaml
kind get kubeconfig --name staging > .\backups\kubeconfig-staging.yaml
kind get kubeconfig --name prod > .\backups\kubeconfig-prod.yaml

# Backup de manifestos
kubectl get all -n myapp --context kind-dev -o yaml > .\backups\dev-manifest.yaml
kubectl get all -n myapp --context kind-staging -o yaml > .\backups\staging-manifest.yaml
kubectl get all -n myapp --context kind-prod -o yaml > .\backups\prod-manifest.yaml

Write-Host "Backups criados em .\backups\" -ForegroundColor Green
```

---

## 🧪 Parte 8: Testes de Isolamento

### Passo 16: Verificar Isolamento

```powershell
# Tentar acessar STAGING de DEV (deve falhar)
kubectl config use-context kind-dev

# Pegar IP de um pod no STAGING
$stagingPodIP = kubectl get pod -n myapp --context kind-staging -o jsonpath='{.items[0].status.podIP}'

# Tentar ping de DEV (não deve funcionar - redes diferentes)
kubectl exec -n myapp test-dev -- ping -c 3 $stagingPodIP

Write-Host "`nClusters são isolados - esperado falhar ✓" -ForegroundColor Green
```

---

## 🧹 Parte 9: Limpeza

### Passo 17: Cleanup Seletivo

```powershell
# Limpar apenas DEV (manter STAGING e PROD)
kubectl delete namespace myapp --context kind-dev
kind delete cluster --name dev

# Verificar
kind get clusters
kubectl config get-contexts
```

### Passo 18: Cleanup Completo

```powershell
# Deletar todos os clusters
kind delete cluster --name staging
kind delete cluster --name prod

# Verificar
kind get clusters

# Limpar arquivos temporários
Remove-Item -Path ".\temp-configs" -Recurse -Force
Remove-Item -Path ".\backups" -Recurse -Force

Write-Host "`nLimpeza completa!" -ForegroundColor Green
```

---

## ✅ Checklist de Conclusão

- [ ] 3 clusters criados (dev, staging, prod)
- [ ] Contextos kubectl configurados
- [ ] Deploy em DEV realizado
- [ ] Promoção para STAGING executada
- [ ] Deploy blue-green em PROD testado
- [ ] Switch entre contextos dominado
- [ ] Isolamento de clusters verificado
- [ ] Backups de configs criados
- [ ] Cleanup realizado

---

## 🎓 O Que Você Aprendeu

Neste laboratório, você:

1. **Criou** múltiplos clusters simultâneos
2. **Gerenciou** contextos kubectl eficientemente
3. **Deployou** apps em diferentes ambientes
4. **Simulou** pipeline de promoção
5. **Implementou** estratégia blue-green
6. **Verificou** isolamento entre clusters
7. **Criou** backups de configurações
8. **Dominou** workflow multi-cluster

---

## 🚀 Próximos Passos

- **Módulo 02**: Networking avançado
- **Módulo 05**: GitOps com ArgoCD para automação de promoções
- **Experimentar**: CI/CD pipeline real, mais ambientes, different K8s versions

---

## 💡 Conceitos-Chave

### Multi-Cluster Strategy

- **DEV**: Desenvolvimento rápido
- **STAGING**: Validação pré-prod
- **PROD**: Alta disponibilidade

### Deployment Strategies

- **Rolling Update**: Gradual (padrão K8s)
- **Blue-Green**: Zero downtime
- **Canary**: Tráfego gradual

### Best Practices

1. Ambientes isolados
2. Configurações por ambiente
3. Testes antes de promoção
4. Backups regulares
5. Automação via GitOps

---

## 📚 Recursos

- [Multi-Cluster Management](https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/)
- [Deployment Strategies](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#strategy)
- [Kubectl Context](https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/)

---

**🎉 Parabéns por completar todos os Labs do Módulo 01!**

Você agora domina Kind e está pronto para os módulos avançados de Kubernetes!
