# 🎮 Lab Completo: Deploy, Auto-Healing e Auto-Scaling

**Duração**: 1 hora e 15 minutos  
**Dificuldade**: ⭐⭐☆☆☆  
**Objetivo**: Fazer deploy de uma aplicação real, testar auto-healing e auto-scaling

> **⚠️ NOTA IMPORTANTE:**  
> Este laboratório está sendo atualizado para usar **Super Mario** ao invés do jogo 2048, e **port-forward** ao invés de NodePort.  
> Para a versão mais atualizada, use o script automatizado:
> ```powershell
> .\scripts\deploy-app.ps1 -StartPortForward
> ```
> Para referências atualizadas, consulte:
> - [manifests/README.md](../manifests/README.md) - Manifestos atualizados
> - [QUICK-START.md](../QUICK-START.md) - Guia rápido
> - [README.md](../README.md) - Documentação principal

---

## 📋 Pré-requisitos

### Verificação Inicial

```powershell
# Verificar Docker
docker --version
docker ps

# Verificar Kind
kind version

# Verificar kubectl
kubectl version --client

# Verificar recursos disponíveis
docker info | Select-String "CPUs", "Total Memory"
```

**Requisitos mínimos:**
- ✅ Docker rodando
- ✅ Kind v0.20.0+
- ✅ kubectl v1.28.0+
- ✅ 4GB RAM disponível
- ✅ 10GB espaço em disco

---

## 🎯 O que você vai aprender

Este laboratório é dividido em 5 partes:

1. **Setup do Cluster** (15 min) - Criar cluster com metrics-server
2. **Deploy da Aplicação** (15 min) - Deployar Super Mario com Service e Port-Forward
3. **Testar Auto-Healing** (15 min) - Deletar pods e observar recuperação
4. **Configurar Auto-Scaling** (15 min) - Configurar HPA
5. **Testar Auto-Scaling** (15 min) - Gerar carga e observar scaling

---

## 📖 Parte 1: Setup do Cluster com Metrics Server

### 1.1 Criar Cluster Kind

Vamos criar um cluster multi-node otimizado para este lab:

```powershell
# Criar arquivo de configuração do cluster
$clusterConfig = @"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: lab-resiliencia
nodes:
  # Control plane
  - role: control-plane
    kubeadmConfigPatches:
    - |
      kind: InitConfiguration
      nodeRegistration:
        kubeletExtraArgs:
          node-labels: "ingress-ready=true"
    extraPortMappings:
    - containerPort: 30080
      hostPort: 30080
      protocol: TCP
  # Workers
  - role: worker
  - role: worker
"@

$clusterConfig | Out-File -FilePath "cluster-config.yaml" -Encoding UTF8

# Criar cluster
kind create cluster --config=cluster-config.yaml

# Verificar cluster
kubectl cluster-info --context kind-lab-resiliencia
kubectl get nodes
```

**Saída esperada:**
```
Creating cluster "lab-resiliencia" ...
 ✓ Ensuring node image (kindest/node:v1.29.0)
 ✓ Preparing nodes 📦 📦 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing CNI 🔌
 ✓ Installing StorageClass 💾
 ✓ Joining worker nodes 🚜
Set kubectl context to "kind-lab-resiliencia"

NAME                            STATUS   ROLES           AGE   VERSION
lab-resiliencia-control-plane   Ready    control-plane   60s   v1.29.0
lab-resiliencia-worker          Ready    <none>          40s   v1.29.0
lab-resiliencia-worker2         Ready    <none>          40s   v1.29.0
```

### 1.2 Instalar Metrics Server

O Metrics Server é essencial para o HPA funcionar. Ele coleta métricas de CPU e memória dos pods.

```powershell
# Download e modificação do Metrics Server para Kind
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch para funcionar no Kind (aceita certificados auto-assinados)
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--kubelet-insecure-tls"
  }
]'

# Aguardar metrics-server estar pronto
Write-Host "Aguardando Metrics Server..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l k8s-app=metrics-server -n kube-system --timeout=120s

# Aguardar métricas estarem disponíveis (pode levar 1-2 minutos)
Write-Host "Aguardando coleta de métricas..." -ForegroundColor Yellow
Start-Sleep -Seconds 60

# Verificar métricas
kubectl top nodes
```

**Saída esperada (após ~1 minuto):**
```
NAME                            CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
lab-resiliencia-control-plane   150m         7%     800Mi           10%
lab-resiliencia-worker          50m          2%     400Mi           5%
lab-resiliencia-worker2         50m          2%     400Mi           5%
```

**💡 Troubleshooting:**
Se `kubectl top nodes` retornar erro:
- Aguarde mais 1-2 minutos (métricas levam tempo para coletar)
- Verifique logs: `kubectl logs -n kube-system -l k8s-app=metrics-server`

---

## 📚 Parte 2: Deploy da Aplicação (Super Mario)

### 2.1 Criar Deployment

Vamos criar um Deployment para o Super Mario:

```powershell
# Criar namespace para organização
kubectl create namespace games

# Criar arquivo de Deployment
$deployment = @"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: game-2048
  namespace: games
  labels:
    app: game-2048
spec:
  replicas: 2
  selector:
    matchLabels:
      app: game-2048
  template:
    metadata:
      labels:
        app: game-2048
    spec:
      containers:
      - name: game-2048
        image: alexwhen/docker-2048
        ports:
        - containerPort: 80
          name: http
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
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
"@

$deployment | Out-File -FilePath "deployment.yaml" -Encoding UTF8

# Aplicar Deployment
kubectl apply -f deployment.yaml

# Verificar Deployment
kubectl get deployments -n games
kubectl get pods -n games -o wide
```

**Entendendo o Deployment:**

| Campo | Descrição |
|-------|-----------|
| `replicas: 2` | Mantém 2 pods rodando sempre |
| `requests.cpu: 50m` | Cada pod precisa de no mínimo 50 milicores |
| `limits.cpu: 100m` | Cada pod pode usar no máximo 100 milicores |
| `livenessProbe` | Verifica se o pod está vivo (reinicia se não responder) |
| `readinessProbe` | Verifica se o pod está pronto para receber tráfego |

**Saída esperada:**
```
NAME        READY   UP-TO-DATE   AVAILABLE   AGE
game-2048   2/2     2            2           30s

NAME                        READY   STATUS    RESTARTS   AGE   NODE
game-2048-7d8f9c5b4-abc12   1/1     Running   0          30s   lab-resiliencia-worker
game-2048-7d8f9c5b4-def34   1/1     Running   0          30s   lab-resiliencia-worker2
```

### 2.2 Criar Service

Agora vamos expor a aplicação via Service:

```powershell
$service = @"
apiVersion: v1
kind: Service
metadata:
  name: game-2048-service
  namespace: games
  labels:
    app: game-2048
spec:
  type: NodePort
  selector:
    app: game-2048
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
    protocol: TCP
    name: http
"@

$service | Out-File -FilePath "service.yaml" -Encoding UTF8

# Aplicar Service
kubectl apply -f service.yaml

# Verificar Service
kubectl get service -n games
kubectl describe service game-2048-service -n games
```

**Entendendo o Service:**

| Campo | Descrição |
|-------|-----------|
| `type: NodePort` | Expõe o serviço em uma porta de cada nó |
| `selector` | Seleciona todos os pods com label `app: game-2048` |
| `port: 80` | Porta do Service dentro do cluster |
| `targetPort: 80` | Porta do container nos pods |
| `nodePort: 30080` | Porta exposta externamente (30000-32767) |

**Saída esperada:**
```
NAME                TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
game-2048-service   NodePort   10.96.123.45    <none>        80:30080/TCP   10s
```

### 2.3 Acessar a Aplicação

```powershell
# Abrir no navegador
Start-Process "http://localhost:30080"

# Ou testar com curl
curl http://localhost:30080
```

**🎮 Teste a aplicação:**
- O jogo 2048 deve abrir no seu navegador
- Jogue algumas partidas para confirmar que está funcionando
- Atualize a página várias vezes - você pode estar acessando pods diferentes!

---

## 📖 Parte 3: Testar Auto-Healing (Recuperação Automática)

### 3.1 Observar Estado Atual

Vamos monitorar os pods em uma janela separada:

```powershell
# Terminal 1 - Monitoramento contínuo
kubectl get pods -n games --watch
```

Mantenha este terminal aberto. Abra um **novo terminal** para os próximos comandos.

### 3.2 Deletar um Pod

```powershell
# Terminal 2 - Obter nome de um pod
$podName = kubectl get pods -n games -o jsonpath='{.items[0].metadata.name}'
Write-Host "Deletando pod: $podName" -ForegroundColor Yellow

# Deletar o pod
kubectl delete pod $podName -n games

# Observar no Terminal 1 - você verá:
# 1. Pod entrando em estado Terminating
# 2. Novo pod sendo criado automaticamente
# 3. Novo pod entrando em Running
```

**Comportamento esperado no Terminal 1:**
```
NAME                        READY   STATUS    RESTARTS   AGE
game-2048-7d8f9c5b4-abc12   1/1     Running   0          5m
game-2048-7d8f9c5b4-def34   1/1     Running   0          5m
game-2048-7d8f9c5b4-abc12   1/1     Terminating   0      5m
game-2048-7d8f9c5b4-xyz99   0/1     Pending       0      0s    ← Novo pod criado
game-2048-7d8f9c5b4-xyz99   0/1     ContainerCreating   0   0s
game-2048-7d8f9c5b4-abc12   0/1     Terminating         0   5m
game-2048-7d8f9c5b4-xyz99   1/1     Running             0   3s    ← Pronto!
game-2048-7d8f9c5b4-abc12   0/1     Terminating         0   5m
```

### 3.3 Verificar Continuidade do Serviço

```powershell
# Durante o processo de deleção, a aplicação continua acessível!
# Teste no navegador: http://localhost:30080
# O Service continua direcionando tráfego para o pod restante

# Verificar eventos
kubectl get events -n games --sort-by='.lastTimestamp' | Select-String -Pattern "game-2048"
```

**🔍 O que aconteceu:**

1. ✅ **Pod deletado** → ReplicaSet detectou estado divergente
2. ✅ **Novo pod criado** → ReplicaSet restaurou estado desejado (2 réplicas)
3. ✅ **Serviço não caiu** → Service continuou roteando para pod saudável
4. ✅ **Zero downtime** → Usuários não perceberam a falha

**💡 Conceito-chave: Reconciliation Loop**
```
Kubernetes Controller:
1. Observa estado atual (1 pod rodando)
2. Compara com estado desejado (2 pods)
3. Toma ação para reconciliar (cria 1 pod)
4. Repete continuamente
```

### 3.4 Teste Extremo: Deletar TODOS os Pods

```powershell
# Deletar todos os pods de uma vez
kubectl delete pods -n games -l app=game-2048

# Observar recuperação automática
kubectl get pods -n games --watch
```

**Resultado:**
- Todos os pods são deletados
- Kubernetes imediatamente cria 2 novos pods
- Em ~10 segundos, aplicação está 100% operacional novamente

---

## 📖 Parte 4: Configurar Auto-Scaling (HPA)

### 4.1 Criar Horizontal Pod Autoscaler

```powershell
$hpa = @"
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: game-2048-hpa
  namespace: games
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: game-2048
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 50
        periodSeconds: 15
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
      - type: Pods
        value: 2
        periodSeconds: 15
      selectPolicy: Max
"@

$hpa | Out-File -FilePath "hpa.yaml" -Encoding UTF8

# Aplicar HPA
kubectl apply -f hpa.yaml

# Verificar HPA
kubectl get hpa -n games
kubectl describe hpa game-2048-hpa -n games
```

**Entendendo a configuração do HPA:**

| Campo | Valor | Significado |
|-------|-------|-------------|
| `minReplicas` | 2 | Nunca ter menos que 2 pods |
| `maxReplicas` | 10 | Nunca ter mais que 10 pods |
| `averageUtilization` | 50 | Manter CPU média em 50% |
| `scaleUp.policies` | Max | Escalar rápido (100% ou +2 pods) |
| `scaleDown.stabilizationWindow` | 60s | Aguardar 60s antes de reduzir |

**Saída esperada:**
```
NAME             REFERENCE              TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
game-2048-hpa    Deployment/game-2048   5%/50%    2         10        2          10s
                                        ↑ CPU atual: 5%
                                           ↑ Alvo: 50%
```

**Fórmula de cálculo do HPA:**
```
desiredReplicas = ⌈currentReplicas × (currentMetricValue / targetMetricValue)⌉

Exemplo:
- Réplicas atuais: 2
- CPU atual: 80%
- CPU alvo: 50%
→ Réplicas desejadas = ⌈2 × (80/50)⌉ = ⌈3.2⌉ = 4 pods
```

---

## 📖 Parte 5: Testar Auto-Scaling com Carga

### 5.1 Preparar Monitoramento

Abra **3 terminais** para monitoramento simultâneo:

```powershell
# Terminal 1 - Monitorar HPA
kubectl get hpa -n games --watch

# Terminal 2 - Monitorar Pods
kubectl get pods -n games --watch

# Terminal 3 - Monitorar uso de CPU
while ($true) {
    Clear-Host
    Write-Host "=== Métricas de CPU ===" -ForegroundColor Cyan
    kubectl top pods -n games
    Start-Sleep -Seconds 5
}
```

### 5.2 Gerar Carga (Load Test)

Abra um **4º terminal** para gerar carga:

```powershell
# Criar pod de load test
kubectl run -n games load-generator --image=busybox --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://game-2048-service; done"

# Adicionar mais geradores de carga (opcional, para scaling mais rápido)
kubectl run -n games load-generator-2 --image=busybox --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://game-2048-service; done"
kubectl run -n games load-generator-3 --image=busybox --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://game-2048-service; done"
```

### 5.3 Observar Auto-Scaling em Ação

**No Terminal 1 (HPA)**, você verá:
```
NAME             REFERENCE              TARGETS    MINPODS   MAXPODS   REPLICAS   AGE
game-2048-hpa    Deployment/game-2048   5%/50%     2         10        2          2m
game-2048-hpa    Deployment/game-2048   85%/50%    2         10        2          2m30s  ← CPU aumentou!
game-2048-hpa    Deployment/game-2048   85%/50%    2         10        4          2m45s  ← Scaled up para 4!
game-2048-hpa    Deployment/game-2048   65%/50%    2         10        4          3m
game-2048-hpa    Deployment/game-2048   72%/50%    2         10        6          3m15s  ← Scaled up para 6!
game-2048-hpa    Deployment/game-2048   48%/50%    2         10        6          4m     ← Estabilizou
```

**No Terminal 2 (Pods)**, você verá novos pods sendo criados:
```
NAME                        READY   STATUS    RESTARTS   AGE
game-2048-7d8f9c5b4-abc12   1/1     Running   0          5m
game-2048-7d8f9c5b4-def34   1/1     Running   0          5m
game-2048-7d8f9c5b4-ghi56   0/1     Pending   0          0s     ← Novo!
game-2048-7d8f9c5b4-jkl78   0/1     Pending   0          0s     ← Novo!
game-2048-7d8f9c5b4-ghi56   0/1     ContainerCreating   0   1s
game-2048-7d8f9c5b4-jkl78   0/1     ContainerCreating   0   1s
game-2048-7d8f9c5b4-ghi56   1/1     Running             0   5s
game-2048-7d8f9c5b4-jkl78   1/1     Running             0   6s
```

**No Terminal 3 (CPU)**, você verá o uso distribuído:
```
=== Métricas de CPU ===
NAME                        CPU(cores)   MEMORY(bytes)
game-2048-7d8f9c5b4-abc12   95m          45Mi
game-2048-7d8f9c5b4-def34   92m          43Mi
game-2048-7d8f9c5b4-ghi56   48m          41Mi  ← Carga distribuída
game-2048-7d8f9c5b4-jkl78   45m          40Mi  ← Carga distribuída
```

### 5.4 Parar Carga e Observar Scale Down

```powershell
# Deletar geradores de carga
kubectl delete pod -n games load-generator
kubectl delete pod -n games load-generator-2
kubectl delete pod -n games load-generator-3

# Observar nos terminais de monitoramento
# O HPA aguardará 60s (stabilizationWindow) antes de reduzir pods
```

**Comportamento esperado:**
```
Tempo 0s:  CPU cai para 5-10%
Tempo 60s: HPA inicia scale down gradual (50% por vez)
Tempo 75s: Reduz de 6 para 3 pods
Tempo 90s: Aguarda estabilização
Tempo 150s: Reduz de 3 para 2 pods (minReplicas)
```

---

## 📊 Análise de Resultados

### Você acabou de comprovar:

#### ✅ **Auto-Healing**
- Pods deletados são **automaticamente recriados**
- Estado desejado é **sempre mantido**
- Serviço **não sofre downtime** (graças às múltiplas réplicas)

#### ✅ **Auto-Scaling**
- HPA **monitora métricas continuamente** (a cada 15s)
- **Scale up é rápido** (responde imediatamente à carga)
- **Scale down é gradual** (evita oscilações)
- **Carga é distribuída** entre os pods

### Comparação: Antes vs Depois do Kubernetes

| Cenário | Sem Kubernetes | Com Kubernetes |
|---------|----------------|----------------|
| Pod falha | ❌ App para | ✅ Auto-recupera em ~10s |
| Alta carga | ❌ App lento/trava | ✅ Escala automaticamente |
| Deploy manual | ❌ SSH, rsync, rezar 🙏 | ✅ `kubectl apply` |
| Monitoramento | ❌ Scripts customizados | ✅ Métricas nativas |
| Load balancing | ❌ Nginx/HAProxy | ✅ Service nativo |

---

## 🧹 Limpeza

### Opção 1: Deletar recursos, manter cluster

```powershell
# Deletar namespace (remove tudo)
kubectl delete namespace games

# Verificar
kubectl get all -n games
```

### Opção 2: Deletar cluster completo

```powershell
# Deletar cluster
kind delete cluster --name lab-resiliencia

# Verificar
kind get clusters
```

---

## 🎓 Conceitos-Chave Aprendidos

### 1. Deployments gerenciam o ciclo de vida
```yaml
spec:
  replicas: 2           # Estado desejado
  template:             # Como criar pods
    spec:
      containers: ...
```

### 2. Services fornecem discovery e load balancing
```yaml
spec:
  selector:             # Quais pods
    app: game-2048
  ports:                # Como acessar
  - port: 80
    nodePort: 30080
```

### 3. HPA escala baseado em métricas
```yaml
spec:
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        averageUtilization: 50
```

### 4. Kubernetes usa Reconciliation Loop
```
┌─────────────────────────────────────┐
│  while (true) {                     │
│    observed = getCurrentState()     │
│    desired = getDesiredState()      │
│    if (observed != desired) {       │
│      reconcile()                    │
│    }                                │
│    sleep(15s)                       │
│  }                                  │
└─────────────────────────────────────┘
```

---

## 🚀 Próximos Passos

Agora que você domina o básico, experimente:

### Desafios Adicionais:

1. **Métricas customizadas:**
   - Configurar HPA com memória em vez de CPU
   - Usar múltiplas métricas simultaneamente

2. **Resiliência avançada:**
   - Configurar PodDisruptionBudget
   - Testar rolling updates com zero downtime

3. **Monitoramento:**
   - Instalar Prometheus e Grafana
   - Criar dashboards personalizados

4. **Testes de chaos:**
   - Usar `kubectl debug` para inspecionar pods
   - Simular falhas de rede
   - Testar comportamento sob estresse

### Aplicação em Produção:

Para usar esses conceitos em produção:

```yaml
# Adicione:
- PodDisruptionBudget (mínimo de pods disponíveis)
- Resource Quotas (limites por namespace)
- LimitRanges (limites padrão para containers)
- NetworkPolicies (segurança de rede)
- Persistent Volumes (para dados)
```

---

## 📖 Recursos de Estudo

- [12 Factor App](https://12factor.net/) - Metodologia para apps cloud-native
- [Kubernetes Patterns](https://kubernetes.io/docs/concepts/cluster-administration/manage-deployment/) - Padrões de deployment
- [Production Best Practices](https://kubernetes.io/docs/setup/best-practices/) - Boas práticas oficiais

---

## ❓ Troubleshooting

### HPA mostra `<unknown>` em TARGETS

**Causa:** Metrics Server ainda coletando dados

**Solução:**
```powershell
# Aguardar 1-2 minutos
Start-Sleep -Seconds 120

# Verificar métricas disponíveis
kubectl top pods -n games
```

### Pods ficam em `Pending`

**Causa:** Recursos insuficientes

**Solução:**
```powershell
# Verificar eventos
kubectl describe pod <pod-name> -n games

# Reduzir resource requests ou adicionar nós
```

### Service não responde em localhost:30080

**Causa:** Porta não mapeada no cluster Kind

**Solução:**
```powershell
# Recriar cluster com port mapping correto
# Veja seção 1.1 - extraPortMappings
```

### Load test não gera carga suficiente

**Solução:**
```powershell
# Aumentar número de geradores
for ($i=1; $i -le 10; $i++) {
    kubectl run -n games "load-gen-$i" --image=busybox --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://game-2048-service; done"
}
```

---

## ✅ Checklist de Conclusão

Você completou o lab com sucesso se:

- [ ] Criou cluster Kind com 3 nós
- [ ] Instalou e configurou Metrics Server
- [ ] Fez deploy da aplicação (2 réplicas)
- [ ] Acessou o jogo no navegador
- [ ] Deletou pods e viu auto-healing
- [ ] Configurou HPA (min: 2, max: 10)
- [ ] Gerou carga e observou scale up
- [ ] Removeu carga e observou scale down
- [ ] Entendeu os conceitos de reconciliation loop
- [ ] Limpou os recursos criados

---

## 🎉 Parabéns!

Você completou o laboratório de **Deploy, Auto-Healing e Auto-Scaling**!

Agora você sabe:
- ✅ Como fazer deploy de aplicações reais
- ✅ Como Kubernetes garante resiliência
- ✅ Como configurar auto-scaling
- ✅ Como testar e validar comportamentos

**Continue praticando e explorando o ecossistema Kubernetes! 🚀**

---

**Próximo módulo:** Persistência de Dados e StatefulSets (em breve)
