# 📦 Manifestos Kubernetes

Esta pasta contém os manifestos YAML para deploy do **Super Mario 🍄** no Kubernetes.

## 📁 Arquivos

### Super Mario 🍄

| Arquivo | Descrição | Recurso |
|---------|-----------|---------|
| `01-deployment-mario.yaml` | Deployment do Super Mario | Deployment |
| `02-service-mario.yaml` | Service ClusterIP | Service |
| `03-hpa.yaml` | Horizontal Pod Autoscaler | HPA |

**Por que Super Mario?**
- 🌟 Visual impressionante para apresentações
- 🎮 Nostalgia + aprendizado
- 💼 WOW factor em entrevistas e demos
- 🚀 Mesmo setup de produção
- 🔒 Acesso via port-forward (boas práticas)

---

## ⚙️ Pré-requisito: Metrics Server

O HPA (Horizontal Pod Autoscaler) **requer** o Metrics Server para funcionar. Instale antes de fazer o deploy:

### Verificar se já está instalado

```powershell
# Verificar deployment do Metrics Server
kubectl get deployment metrics-server -n kube-system

# Testar se está funcionando
kubectl top nodes
```

### Instalar Metrics Server (se necessário)

```powershell
# Instalar Metrics Server (versão oficial mais recente)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# ⚠️ APENAS para ambientes locais (Kind/Docker Desktop)
# Adicionar flag --kubelet-insecure-tls (NÃO use em produção!)
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

# Aguardar deployment estar pronto
kubectl wait --for=condition=available --timeout=120s deployment/metrics-server -n kube-system

# Verificar funcionamento
kubectl top nodes
kubectl top pods -n kube-system
```

**⚠️ Nota de Segurança:**
- O flag `--kubelet-insecure-tls` desabilita verificação de certificados TLS
- **Use APENAS em ambientes locais** (Kind, Minikube, Docker Desktop)
- **NUNCA use em produção** - configure certificados adequados

**✅ Metrics Server instalado quando:** `kubectl top nodes` mostra uso de CPU/memória.

---

## 🚀 Uso Rápido

### Deploy Super Mario 🍄

Primeiramente, recorde-se que vamos utilizar o mesmo cluster `k8s-essentials` criado no passo [#3](https://github.com/toolbox-playground/caio-k8s/blob/main/curso-k8s/modulo-01-kind/README.md#passo-3-cluster-multi-node-avan%C3%A7ado) do `modulo-01-kind` anterior. Caso tenha pulado esse módulo, te entendemos, você deve ser viciado em Mario e já pulou diretamente para cá. Execute os passos do link para criar o cluster.

Após ter o cluster `k8s-essentials` criado:

```powershell
# 1. Criar namespace
kubectl create namespace games

# 2. Carregar imagem Docker no Kind
kind load docker-image pengbai/docker-supermario:latest --name k8s-essentials

## Alternativa 1: Acessar worker node e puxar imagem manualmente
docker exec -it k8s-essentials-worker bash
ctr -n k8s.io images pull docker.io/pengbai/docker-supermario:latest
exit

## Alternativa 2: Baixar container localmente
docker pull pengbai/docker-supermario:latest


# 3. Aplicar manifestos
kubectl apply -f manifests/01-deployment-mario.yaml
kubectl apply -f manifests/02-service-mario.yaml
kubectl apply -f manifests/03-hpa.yaml

# 4. Verificar
kubectl get all -n games

# 5. Acessar via port-forward (método profissional)
kubectl port-forward -n games service/super-mario-service 8080:8080

# 6. Abrir no navegador
Start-Process "http://localhost:8080"
```

### 💡 Por que Port-Forward?

| Benefício | Descrição |
|-----------|-----------|
| 🔒 Segurança | Não expõe portas publicamente |
| 🏢 Profissional | Método usado em produção |
| 🎯 Aprendizado | Boas práticas desde o início |
| 🌐 Flexibilidade | Funciona em qualquer ambiente |
| 🔧 Debugging | Facilita troubleshooting |

---

## 📖 Detalhamento dos Manifestos

## 📖 Detalhamento dos Manifestos

### 01-deployment-mario.yaml

**Características principais:**

- **Réplicas:** 2 (estado inicial)
- **Imagem:** `pengbai/docker-supermario:latest`
- **Recursos:**
  - Request: 100m CPU, 128Mi RAM
  - Limit: 200m CPU, 256Mi RAM
- **Health Checks:**
  - Liveness Probe: HTTP GET / (porta 8080) a cada 10s
  - Readiness Probe: HTTP GET / (porta 8080) a cada 5s

**Por que esses valores?**

| Configuração | Valor | Motivo |
|--------------|-------|--------|
| `replicas: 2` | 2 pods | Garante HA básica + demonstra load balancing |
| `cpu: 100m` | 100 milicores | Jogo mais complexo, precisa de mais recursos |
| `memory: 128Mi` | 128 MiB | Interface rica, mais assets |
| `limits.cpu: 200m` | 200 milicores | Dobro do request = headroom para picos |

**Comandos úteis:**

```powershell
# Ver detalhes do deployment
kubectl describe deployment super-mario -n games

# Ver histórico de rollout
kubectl rollout history deployment/super-mario -n games

# Escalar manualmente
kubectl scale deployment super-mario --replicas=5 -n games

# Ver eventos relacionados
kubectl get events -n games | Select-String "super-mario"
```

### 02-service-mario.yaml

**Características principais:**

- **Tipo:** ClusterIP (acesso interno - melhor prática)
- **Porta do Service:** 80
- **Target Port:** 8080 (porta do container)
- **Selector:** `app: super-mario`
- **Acesso:** Via kubectl port-forward

**Por que ClusterIP ao invés de NodePort?**

| Aspecto | ClusterIP + Port-Forward | NodePort |
|---------|-------------------------|----------|
| 🔒 Segurança | Não expõe porta publicamente | Expõe porta em todos os nós |
| 🏢 Produção | Método usado em ambientes reais | Raramente usado em prod |
| 🎯 Flexibilidade | Qualquer porta local | Porta fixa 30000-32767 |
| 🔧 Debug | Fácil troubleshooting | Mais complexo |

**Fluxo de tráfego com port-forward:**

```
Browser (http://localhost:8081)
    ↓
kubectl port-forward (túnel seguro)
    ↓
Service (porta 80) no cluster
    ↓
Load balancing (round-robin)
    ↓
Pods (targetPort 8080)
    ↓
Container (porta 8080)
```

**Comandos úteis:**

```powershell
# Acessar via port-forward (recomendado)
kubectl port-forward -n games service/super-mario-service 8081:8080

# Testar acesso interno
kubectl run -n games test-pod --image=busybox --restart=Never --rm -it -- wget -O- http://super-mario-service

# Ver endpoints (IPs dos pods)
kubectl get endpoints super-mario-service -n games

# Descrever service
kubectl describe service super-mario-service -n games
```

**Port-forward em background:**

```powershell
# Executar port-forward em background
Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward -n games service/super-mario-service 8081:8080"

# Ou criar um alias
function Start-MarioPortForward {
    kubectl port-forward -n games service/super-mario-service 8081:8080
}
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
kubectl describe hpa super-mario-hpa -n games

# Ver métricas atuais
kubectl top pods -n games

# Desabilitar HPA temporariamente
kubectl delete hpa super-mario-hpa -n games
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
# 01-deployment-mario.yaml
resources:
  requests:
    cpu: 200m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi
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

### Usar LoadBalancer (em ambientes cloud)

```yaml
# 02-service-mario.yaml (para ambientes cloud)
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
  # Automaticamente provisiona um LB externo
```

**Nota:** ClusterIP + port-forward é recomendado para desenvolvimento local.

## 🧪 Testes de Validação

### Validar sintaxe YAML

```powershell
# Validar sem aplicar
kubectl apply -f manifests/01-deployment-mario.yaml --dry-run=client -o yaml

# Validar com server-side
kubectl apply -f manifests/01-deployment-mario.yaml --dry-run=server
```

### Testar deployment isoladamente

```powershell
# Aplicar apenas deployment
kubectl apply -f manifests/01-deployment-mario.yaml

# Aguardar rollout completar
kubectl rollout status deployment/super-mario -n games

# Verificar pods
kubectl get pods -n games
```

### Testar service com port-forward

```powershell
# Aplicar service
kubectl apply -f manifests/02-service-mario.yaml

# Port-forward para teste local (método recomendado)
kubectl port-forward -n games service/super-mario-service 8080:8080

# Abrir no navegador
Start-Process "http://localhost:8080"
```

### Testar HPA

```powershell
# Aplicar HPA
kubectl apply -f manifests/03-hpa.yaml

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
kubectl logs -n games -l app=super-mario --all-containers=true

# Seguir logs em tempo real
kubectl logs -n games -l app=super-mario -f
```

### Eventos

```powershell
# Eventos do namespace
kubectl get events -n games --sort-by='.lastTimestamp'

# Eventos de um recurso específico
kubectl describe deployment super-mario -n games | Select-String "Events:" -A 20
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
kubectl delete -f manifests/03-hpa.yaml
kubectl delete -f manifests/02-service-mario.yaml
kubectl delete -f manifests/01-deployment-mario.yaml
```

### Remover tudo de uma vez

```powershell
kubectl delete -f ./manifests/

# OU deletar o namespace inteiro
kubectl delete namespace games
```

## 📚 Recursos Adicionais

- [Deployment Best Practices](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#writing-a-deployment-spec)
- [Service Types](https://kubernetes.io/docs/concepts/services-networking/service/#publishing-services-service-types)
- [HPA Walkthrough](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/)
- [Port Forwarding](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/)

---

**Dica:** Use `kubectl port-forward` para acesso seguro aos serviços durante desenvolvimento! 🚀
