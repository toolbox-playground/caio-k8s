# 📦 Manifestos Kubernetes

Esta pasta contém os manifestos YAML para deploy de **duas aplicações de demonstração**: Super Mario 🍄 e Jogo 2048 🎯.

## 📁 Arquivos

### Super Mario 🍄 (Recomendado para Demos!)

| Arquivo | Descrição | Recurso |
|---------|-----------|---------|
| `01-deployment-mario.yaml` | Deployment do Super Mario | Deployment |
| `02-service-mario.yaml` | Service NodePort (porta 30090) | Service |
| `03-hpa.yaml` | Horizontal Pod Autoscaler | HPA |

**Por que Super Mario?**
- 🌟 Visual impressionante para apresentações
- 🎮 Nostalgia + aprendizado
- 💼 WOW factor em entrevistas e demos
- 🚀 Mesmo setup de produção

### Jogo 2048 🎯 (Recomendado para Aprendizado)

| Arquivo | Descrição | Recurso |
|---------|-----------|---------|
| `01-deployment.yaml` | Deployment do jogo 2048 | Deployment |
| `02-service.yaml` | Service NodePort (porta 30080) | Service |
| `03-hpa.yaml` | Horizontal Pod Autoscaler | HPA |

**Por que 2048?**
- ✅ Leve e rápido
- ✅ Interface limpa
- ✅ Foco nos conceitos K8s

---

## 🚀 Uso Rápido

### Deploy Super Mario 🍄

### Deploy Super Mario 🍄

```powershell
# 1. Criar namespace
kubectl create namespace games

# 2. Aplicar manifestos do Super Mario
kubectl apply -f 01-deployment-mario.yaml
kubectl apply -f 02-service-mario.yaml
kubectl apply -f 03-hpa.yaml

# 3. Verificar
kubectl get all -n games

# 4. Acessar
Start-Process "http://localhost:30090"
```

### Deploy Jogo 2048 🎯

```powershell
# 1. Criar namespace
kubectl create namespace games

# 2. Aplicar manifestos do 2048
kubectl apply -f 01-deployment.yaml
kubectl apply -f 02-service.yaml
kubectl apply -f 03-hpa.yaml

# OU aplicar todos de uma vez
kubectl apply -f .

# 3. Verificar
kubectl get all -n games

# 4. Acessar
Start-Process "http://localhost:30080"
```

### ⚡ Qual escolher?

| Situação | Jogo Recomendado | Porta |
|----------|------------------|-------|
| 🎤 Demo/Apresentação | Super Mario 🍄 | 30090 |
| 📚 Estudo/Aprendizado | 2048 🎯 | 30080 |
| 💼 Portfolio/Entrevista | Super Mario 🍄 | 30090 |
| 🏃 Teste Rápido | 2048 🎯 | 30080 |
| 👔 Apresentar para Manager | Super Mario 🍄 | 30090 |

**Dica:** Ambos usam o mesmo HPA! Você pode deployar os dois simultaneamente (portas diferentes).

---

## 🎮 Deployando Ambos os Jogos

```powershell
# Criar namespace
kubectl create namespace games

# Deploy Super Mario (porta 30090)
kubectl apply -f 01-deployment-mario.yaml
kubectl apply -f 02-service-mario.yaml

# Deploy 2048 (porta 30080)
kubectl apply -f 01-deployment.yaml
kubectl apply -f 02-service.yaml

# HPA compartilhado (ou crie um para cada)
kubectl apply -f 03-hpa.yaml

# Acessar ambos
Start-Process "http://localhost:30090"  # Super Mario
Start-Process "http://localhost:30080"  # 2048

# Ver todos os recursos
kubectl get all -n games
```

### Verificar recursos criados

```powershell
# Ver todos os recursos
kubectl get all -n games

# Ver deployment
kubectl get deployment game-2048 -n games

# Ver pods
kubectl get pods -n games -o wide

# Ver service
kubectl get service game-2048-service -n games

# Ver HPA
kubectl get hpa game-2048-hpa -n games
```

## 📖 Detalhamento dos Manifestos

### 01-deployment.yaml

**Características principais:**

- **Réplicas:** 2 (estado inicial)
- **Imagem:** `alexwhen/docker-2048:latest`
- **Recursos:**
  - Request: 50m CPU, 64Mi RAM
  - Limit: 100m CPU, 128Mi RAM
- **Health Checks:**
  - Liveness Probe: HTTP GET / (porta 80) a cada 10s
  - Readiness Probe: HTTP GET / (porta 80) a cada 5s

**Por que esses valores?**

| Configuração | Valor | Motivo |
|--------------|-------|--------|
| `replicas: 2` | 2 pods | Garante HA básica + demonstra load balancing |
| `cpu: 50m` | 50 milicores | App leve, não precisa de muito CPU |
| `memory: 64Mi` | 64 MiB | Jogo HTML/JS simples, pouca memória |
| `limits.cpu: 100m` | 100 milicores | Dobro do request = headroom para picos |

**Comandos úteis:**

```powershell
# Ver detalhes do deployment
kubectl describe deployment game-2048 -n games

# Ver histórico de rollout
kubectl rollout history deployment/game-2048 -n games

# Escalar manualmente
kubectl scale deployment game-2048 --replicas=5 -n games

# Ver eventos relacionados
kubectl get events -n games | Select-String "game-2048"
```

### 02-service.yaml

**Características principais:**

- **Tipo:** NodePort
- **Porta do Service:** 80 (ClusterIP interno)
- **Target Port:** 80 (porta do container)
- **NodePort:** 30080 (acesso externo)
- **Selector:** `app: game-2048`

**Fluxo de tráfego:**

```
Browser (http://localhost:30080)
    ↓
NodePort (30080) no host
    ↓
Service (porta 80) no cluster
    ↓
Load balancing (round-robin)
    ↓
Pods (targetPort 80)
    ↓
Container (porta 80)
```

**Comandos úteis:**

```powershell
# Testar acesso interno
kubectl run -n games test-pod --image=busybox --restart=Never --rm -it -- wget -O- http://game-2048-service

# Ver endpoints (IPs dos pods)
kubectl get endpoints game-2048-service -n games

# Descrever service
kubectl describe service game-2048-service -n games

# Testar externamente
curl http://localhost:30080
```

**Tipos de Service alternativos:**

```yaml
# ClusterIP (padrão - apenas interno)
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 80

# LoadBalancer (em clouds - AWS ELB, GCP LB, etc)
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 80
```

### 03-hpa.yaml

**Características principais:**

- **Min réplicas:** 2
- **Max réplicas:** 10
- **Métrica:** CPU utilization @ 50%
- **Scale Up:** Rápido (100% ou +2 pods a cada 15s)
- **Scale Down:** Gradual (50% a cada 15s após 60s de estabilização)

**Fórmula de scaling:**

```
desiredReplicas = ⌈currentReplicas × (currentMetric / targetMetric)⌉

Exemplos:
- 2 pods @ 80% CPU → ⌈2 × (80/50)⌉ = 4 pods
- 4 pods @ 90% CPU → ⌈4 × (90/50)⌉ = 8 pods
- 8 pods @ 30% CPU → ⌈8 × (30/50)⌉ = 5 pods (após 60s)
```

**Comportamentos configurados:**

| Ação | Configuração | Motivo |
|------|--------------|--------|
| Scale Up | Imediato (0s window) | Responder rápido à demanda |
| Scale Up | 100% ou +2 pods | Scaling agressivo |
| Scale Down | Aguardar 60s | Evitar flapping (oscilações) |
| Scale Down | 50% por vez | Redução gradual e segura |

**Comandos úteis:**

```powershell
# Ver status do HPA
kubectl get hpa -n games

# Monitorar continuamente
kubectl get hpa -n games --watch

# Ver detalhes e eventos
kubectl describe hpa game-2048-hpa -n games

# Ver métricas atuais
kubectl top pods -n games

# Desabilitar HPA temporariamente
kubectl delete hpa game-2048-hpa -n games
```

**HPA com múltiplas métricas (exemplo avançado):**

```yaml
spec:
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 70
  # HPA escalará quando QUALQUER métrica exceder o limite
```

## 🔧 Customizações Comuns

### Aumentar recursos para cargas maiores

```yaml
# 01-deployment.yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi
```

### Ajustar limites de auto-scaling

```yaml
# 03-hpa.yaml
spec:
  minReplicas: 3      # Mais HA
  maxReplicas: 20     # Suporta mais carga
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        averageUtilization: 70  # Mais tolerante
```

### Usar LoadBalancer em vez de NodePort

```yaml
# 02-service.yaml
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 80
  # nodePort removido (será alocado automaticamente)
```

## 🧪 Testes de Validação

### Validar sintaxe YAML

```powershell
# Validar sem aplicar
kubectl apply -f 01-deployment.yaml --dry-run=client -o yaml

# Validar com server-side
kubectl apply -f 01-deployment.yaml --dry-run=server
```

### Testar deployment isoladamente

```powershell
# Aplicar apenas deployment
kubectl apply -f 01-deployment.yaml

# Aguardar rollout completar
kubectl rollout status deployment/game-2048 -n games

# Verificar pods
kubectl get pods -n games
```

### Testar service

```powershell
# Aplicar service
kubectl apply -f 02-service.yaml

# Port-forward para teste local
kubectl port-forward -n games service/game-2048-service 8080:80

# Testar: http://localhost:8080
```

### Testar HPA

```powershell
# Aplicar HPA
kubectl apply -f 03-hpa.yaml

# Aguardar métricas (1-2 minutos)
Start-Sleep -Seconds 120

# Verificar
kubectl get hpa -n games
```

## 📊 Monitoramento e Observabilidade

### Logs

```powershell
# Logs de um pod específico
kubectl logs -n games <pod-name>

# Logs de todos os pods do deployment
kubectl logs -n games -l app=game-2048 --all-containers=true

# Seguir logs em tempo real
kubectl logs -n games -l app=game-2048 -f
```

### Eventos

```powershell
# Eventos do namespace
kubectl get events -n games --sort-by='.lastTimestamp'

# Eventos de um recurso específico
kubectl describe deployment game-2048 -n games | Select-String "Events:" -A 20
```

### Métricas

```powershell
# CPU e memória dos pods
kubectl top pods -n games

# CPU e memória dos nós
kubectl top nodes

# Uso detalhado
kubectl describe node <node-name>
```

## 🗑️ Limpeza

### Remover recursos individualmente

```powershell
kubectl delete -f 03-hpa.yaml
kubectl delete -f 02-service.yaml
kubectl delete -f 01-deployment.yaml
```

### Remover tudo de uma vez

```powershell
kubectl delete -f .

# OU deletar o namespace inteiro
kubectl delete namespace games
```

## 📚 Recursos Adicionais

- [Deployment Best Practices](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#writing-a-deployment-spec)
- [Service Types](https://kubernetes.io/docs/concepts/services-networking/service/#publishing-services-service-types)
- [HPA Walkthrough](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/)

---

**Próximo passo:** Volte ao [Laboratório](../laboratorios/lab-completo-resiliencia.md) para usar esses manifestos!
