# 📦 Manifestos Kubernetes - Super Mario 🍄

> **ℹ️ Nota:** Este README é simplificado. Para documentação completa, consulte o [README da raiz do módulo 2](../README.md).

Esta pasta contém os manifestos YAML para deploy do **Super Mario** no Kubernetes, incluindo auto-healing, auto-scaling e testes de carga.

---

## 📁 Arquivos

| Arquivo | Descrição | Recurso |
|---------|-----------|---------|
| `01-deployment-mario.yaml` | Deployment do Super Mario | Deployment |
| `02-service-mario.yaml` | Service NodePort | Service |
| `03-hpa.yaml` | Horizontal Pod Autoscaler | HPA |
| `04-stress-test-fortio.yaml` | Pods de stress test (Fortio) | Pod |
| `cluster-config.yaml` | Configuração do cluster Kind | Cluster |

---

## ⚙️ Pré-requisito: Metrics Server

O HPA (Horizontal Pod Autoscaler) **requer** o Metrics Server para funcionar.

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

## 🚀 Deploy Rápido

### Pré-requisitos

Este módulo utiliza o cluster `k8s-essentials` criado no Módulo 01. Se ainda não criou, execute:

```powershell
# Criar cluster multi-node
kind create cluster --config manifests/cluster-config.yaml
```

### Deploy completo

```powershell
# 1. Criar namespace
kubectl create namespace games

# 2. Baixar container localmente
docker pull pengbai/docker-supermario:latest

# 3. Carregar imagem Docker no Kind
kind load docker-image pengbai/docker-supermario:latest --name k8s-essentials

# Alternativa: Acessar worker node e puxar imagem manualmente
docker exec -it k8s-essentials-worker bash
ctr -n k8s.io images pull docker.io/pengbai/docker-supermario:latest
exit


# 4. Aplicar manifestos
kubectl apply -f manifests/01-deployment-mario.yaml
kubectl apply -f manifests/02-service-mario.yaml
kubectl apply -f manifests/03-hpa.yaml

# 5. Verificar status
kubectl get all -n games

# 6. Acessar aplicação via navegador
# O cluster-config.yaml mapeia NodePort 30000 → localhost:8081
Start-Process "http://localhost:8081"
```

---

## 📖 Detalhamento dos Manifestos

### 01-deployment-mario.yaml

**Deployment do Super Mario com recursos e health checks configurados.**

#### Características Principais

| Configuração | Valor | Descrição |
|--------------|-------|-----------|
| **Réplicas** | `2` | Número inicial de pods |
| **Imagem** | `pengbai/docker-supermario:latest` | Container do jogo |
| **Porta Container** | `8080` | Porta onde a aplicação escuta |
| **CPU Request** | `100m` | CPU garantida por pod |
| **Memory Request** | `256Mi` | Memória garantida por pod |
| **CPU Limit** | `500m` | CPU máxima por pod |
| **Memory Limit** | `512Mi` | Memória máxima por pod |

#### Health Checks

**Liveness Probe** (verifica se container está vivo):
- **Método:** HTTP GET `/` na porta `8080`
- **Initial Delay:** 30 segundos
- **Period:** 10 segundos
- **Timeout:** 5 segundos
- **Failure Threshold:** 3 falhas → reinicia container

**Readiness Probe** (verifica se pod está pronto para receber tráfego):
- **Método:** HTTP GET `/` na porta `8080`
- **Initial Delay:** 15 segundos
- **Period:** 5 segundos
- **Timeout:** 3 segundos
- **Failure Threshold:** 3 falhas → remove do Service

#### Por que esses valores?

| Decisão | Justificativa |
|---------|---------------|
| **2 réplicas** | Alta disponibilidade básica + demonstra load balancing |
| **256Mi RAM** | Suficiente para servidor web Java/Tomcat |
| **500m CPU limit** | Headroom para picos de carga sem throttling |
| **Liveness 30s delay** | Tempo para aplicação Java inicializar completamente |
| **Readiness 15s delay** | Mais agressivo - detecta quando pod está pronto mais rápido |

#### Comandos Úteis

```powershell
# Ver detalhes do deployment
kubectl describe deployment super-mario -n games

# Ver histórico de rollout
kubectl rollout history deployment/super-mario -n games

# Escalar manualmente
kubectl scale deployment super-mario --replicas=5 -n games

# Ver eventos relacionados
kubectl get events -n games | Select-String "super-mario"

# Verificar status de rollout
kubectl rollout status deployment/super-mario -n games
```

---

### 02-service-mario.yaml

**Service NodePort para expor o Super Mario externamente.**

#### Características Principais

| Configuração | Valor | Descrição |
|--------------|-------|-----------|
| **Tipo** | `NodePort` | Expõe em porta específica dos nodes |
| **Porta Service** | `80` | Porta interna do cluster |
| **Target Port** | `8080` | Porta do container (onde app escuta) |
| **Node Port** | `30000` | Porta externa nos nodes (30000-32767) |
| **Selector** | `app: super-mario` | Seleciona pods do deployment |
| **Session Affinity** | `None` | Distribui requests aleatoriamente (round-robin) |

#### DNS Interno do Kubernetes

Cada Service recebe um nome DNS automático:

```
<service-name>.<namespace>.svc.cluster.local
```

**Para o Super Mario:**
- **Nome completo:** `super-mario-service.games.svc.cluster.local`
- **Abreviado (mesmo namespace):** `super-mario-service`
- **Porta:** `80` (porta padrão HTTP do Service)

**Exemplos de uso:**

```bash
# De dentro de um pod no namespace 'games'
curl http://super-mario-service/

# De dentro de um pod em OUTRO namespace
curl http://super-mario-service.games.svc.cluster.local/

# Fortio usa DNS completo para garantir funcionamento
fortio load -c 50 -t 5m http://super-mario-service.games.svc.cluster.local:8080/
```

#### Fluxo de Tráfego

```
Navegador: http://localhost:8081
    ↓
cluster-config.yaml: hostPort 8081 → containerPort 30000
    ↓
Service NodePort: 30000 → port 80
    ↓
Load Balancing (round-robin entre pods)
    ↓
Pod: targetPort 8080
    ↓
Container: escutando na porta 8080
```

#### Session Affinity

| Configuração | Comportamento | Uso |
|--------------|---------------|-----|
| `sessionAffinity: None` | Requests distribuídos aleatoriamente | Apps stateless ✅ |
| `sessionAffinity: ClientIP` | Mesmo cliente → mesmo pod | Apps com sessão local |

**Super Mario usa `None` porque:**
- ✅ Aplicação é completamente stateless
- ✅ Distribui carga uniformemente entre pods
- ✅ Facilita testes de load balancing
- ✅ Pods podem ser adicionados/removidos livremente

#### Comandos Úteis

```powershell
# Ver endpoints (IPs dos pods)
kubectl get endpoints super-mario-service -n games

# Descrever service
kubectl describe service super-mario-service -n games

# Testar acesso interno
kubectl run -n games test-pod --image=busybox --restart=Never --rm -it -- wget -O- http://super-mario-service
```

---

### 03-hpa.yaml

**Horizontal Pod Autoscaler para escalar automaticamente baseado em CPU.**

#### Características Principais

| Configuração | Valor | Descrição |
|--------------|-------|-----------|
| **Min Réplicas** | `2` | Número mínimo de pods |
| **Max Réplicas** | `10` | Número máximo de pods |
| **Métrica** | `CPU` | Baseado em uso de CPU |
| **Target CPU** | `50%` | Meta de utilização de CPU |

#### Fórmula de Scaling

O HPA usa a seguinte fórmula:

```
desiredReplicas = ⌈currentReplicas × (currentMetric / targetMetric)⌉
```

**Exemplos práticos:**

```
Cenário 1:
- 2 pods @ 80% CPU
- Cálculo: ⌈2 × (80/50)⌉ = ⌈3.2⌉ = 4 pods ✅

Cenário 2:
- 4 pods @ 90% CPU
- Cálculo: ⌈4 × (90/50)⌉ = ⌈7.2⌉ = 8 pods ✅

Cenário 3:
- 8 pods @ 30% CPU
- Cálculo: ⌈8 × (30/50)⌉ = ⌈4.8⌉ = 5 pods (após 60s de estabilização)
```

#### Comportamento de Scaling

**Scale Up (aumentar pods):**

| Configuração | Valor | Motivo |
|--------------|-------|--------|
| **Stabilization Window** | `0s` | Responde imediatamente à alta carga |
| **Política 1 (Percent)** | `100%` a cada 15s | Duplica número de pods |
| **Política 2 (Pods)** | `+2 pods` a cada 15s | Adiciona 2 pods fixos |
| **Select Policy** | `Max` | Usa a política mais agressiva |

**Resultado:** Escala rapidamente em picos de carga (Black Friday, eventos virais).

**Scale Down (reduzir pods):**

| Configuração | Valor | Motivo |
|--------------|-------|--------|
| **Stabilization Window** | `60s` | Aguarda 60s antes de reduzir |
| **Política (Percent)** | `50%` a cada 15s | Reduz gradualmente (metade) |

**Resultado:** Evita oscilações (flapping) e permite observar se carga realmente caiu.

#### Timeline de Auto-Scaling

```
00:00 - Carga aumenta → CPU sobe para 80%
00:15 - HPA detecta e calcula: 2 pods → 4 pods
00:20 - Novos pods são criados (Pending)
00:30 - Novos pods ficam Running
00:45 - Novos pods passam readinessProbe → recebem tráfego
01:00 - CPU estabiliza em ~50% (4 pods distribuindo carga)
---
05:00 - Carga diminui → CPU cai para 30%
05:60 - HPA aguarda 60s (stabilization window)
06:00 - HPA inicia scale down: 4 pods → 2 pods
06:15 - Pods extras são terminados gracefully
```

#### Comandos Úteis

```powershell
# Ver status do HPA
kubectl get hpa -n games

# Monitorar continuamente
kubectl get hpa -n games --watch

# Ver detalhes e eventos
kubectl describe hpa super-mario-hpa -n games

# Ver métricas atuais dos pods
kubectl top pods -n games

# Desabilitar HPA temporariamente
kubectl delete hpa super-mario-hpa -n games

# Reabilitar
kubectl apply -f manifests/03-hpa.yaml
```

---

### 04-stress-test-fortio.yaml

**2 pods Fortio para testes de carga: automático e interativo.**

Este manifesto cria **2 pods distintos** com finalidades diferentes.

#### Pod 1: fortio-stress-test (Automático)

**Configuração:**

| Parâmetro | Valor | Descrição |
|-----------|-------|-----------|
| **Conexões** | `50` | Conexões concorrentes simultâneas |
| **QPS** | `0` | Ilimitado (máxima carga possível) |
| **Duração** | `10m` | 10 minutos de teste contínuo |
| **Restart Policy** | `Never` | Executa uma vez e termina |
| **Active Deadline** | `900s` | 15 minutos (timeout de segurança) |

**Comando executado:**

```bash
fortio load -c 50 -qps 0 -t 10m -loglevel Warning \
  http://super-mario-service.games.svc.cluster.local:8080/
```

**Por que `activeDeadlineSeconds: 900`?**

| Campo | Valor | Motivo |
|-------|-------|--------|
| **activeDeadlineSeconds** | 900s (15 min) | Garante término mesmo se travar |
| **Teste duration** | 10 minutos | Tempo real de execução |
| **Margem de segurança** | 5 minutos | Tempo para inicialização e finalização |

**Timeline de execução:**

```
00:00 - Pod criado (status: Pending)
00:05 - Container iniciado (status: Running)
00:10 - Stress test começa gerando carga
10:10 - Teste termina (pod continua Running)
10:15 - Pod finaliza gracefully (status: Completed)
15:00 - Se ainda Running, Kubernetes força término
```

#### Pod 2: fortio-interactive (Manual)

**Configuração:**

| Parâmetro | Valor | Descrição |
|-----------|-------|-----------|
| **Comando** | `sleep infinity` | Pod fica rodando indefinidamente |
| **Restart Policy** | `Always` | Reinicia se falhar |
| **Uso** | Testes manuais e debugging | Controle total |

**Como usar:**

```bash
# 1. Acessar shell do pod
kubectl exec -it fortio-interactive -n games -- /bin/sh

# 2. Executar testes customizados

# Teste leve (100 requisições, 10 concorrentes)
fortio load -c 10 -n 100 http://super-mario-service/

# Teste moderado (30 segundos, 50 conexões)
fortio load -c 50 -qps 0 -t 30s http://super-mario-service/

# Teste com QPS específico (200 req/s)
fortio load -c 20 -qps 200 -t 1m http://super-mario-service/

# Teste de conectividade simples
fortio curl http://super-mario-service/

# Sair
exit
```

#### Comparação dos Pods

| Aspecto | fortio-stress-test | fortio-interactive |
|---------|-------------------|--------------------|
| **Propósito** | Teste automático de alta carga | Testes manuais customizados |
| **Execução** | Imediata ao criar | Aguarda comandos do usuário |
| **Duração** | 10 minutos fixos | Infinita (até deletar) |
| **RestartPolicy** | Never (roda uma vez) | Always (reinicia se falhar) |
| **Deadline** | 900s (auto-termina) | Nenhum |
| **Uso Ideal** | CI/CD, testes programados | Debugging, experimentos |

#### Carregar imagem Fortio no Kind

```powershell
# Baixar imagem
docker pull fortio/fortio:latest

# Carregar no cluster Kind
kind load docker-image fortio/fortio:latest --name k8s-essentials

# Alternativa: Acessar worker node
docker exec -it k8s-essentials-worker bash
ctr -n k8s.io images pull docker.io/fortio/fortio:latest
exit
```

#### Aplicar e monitorar

```powershell
# Aplicar pods de teste
kubectl apply -f manifests/04-stress-test-fortio.yaml

# Ver status dos pods Fortio
kubectl get pods -n games -l tool=fortio

# Ver logs do stress test automático
kubectl logs -n games fortio-stress-test -f

# Monitorar HPA durante o teste
kubectl get hpa -n games --watch

# Monitorar pods do Super Mario
kubectl get pods -n games -l app=super-mario --watch

# Ver métricas de CPU
kubectl top pods -n games
```

#### Limpar após testes

```powershell
# Deletar apenas pods Fortio
kubectl delete -f manifests/04-stress-test-fortio.yaml

# Ou deletar individualmente
kubectl delete pod fortio-stress-test -n games
kubectl delete pod fortio-interactive -n games
```

---

### cluster-config.yaml

**Configuração do cluster Kind multi-node para o módulo.**

#### Estrutura do Cluster

| Node | Role | Descrição |
|------|------|-----------|
| **Node 1** | `control-plane` | Master (API Server, Scheduler, etcd) |
| **Node 2** | `worker` | Worker para cargas de trabalho |
| **Node 3** | `worker` | Worker adicional (distribuição de carga) |

#### Port Mapping

```yaml
extraPortMappings:
- containerPort: 30000  # NodePort do Service
  hostPort: 8081        # Porta no host (localhost)
  protocol: TCP
```

**Fluxo completo:**

```
localhost:8081 → NodePort 30000 → Service:80 → Pod:8080
```

**Por que porta 8081 no host?**
- Evita conflitos com outras aplicações na porta 8080
- Porta 80 requer privilégios de admin

#### Criar o cluster

```powershell
# Criar cluster
kind create cluster --config manifests/cluster-config.yaml

# Verificar nodes
kubectl get nodes

# Verificar contexto
kubectl config current-context
```

---

## 🧪 Testes e Validação

### Validar sintaxe YAML

```powershell
# Validar sem aplicar (client-side)
kubectl apply -f manifests/01-deployment-mario.yaml --dry-run=client

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
kubectl get pods -n games -w
```

### Testar HPA

```powershell
# Aplicar HPA
kubectl apply -f manifests/03-hpa.yaml

# Aguardar métricas (1-2 minutos)
Start-Sleep -Seconds 120

# Verificar status
kubectl get hpa -n games

# Deve mostrar algo como:
# NAME               REFERENCE                TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
# super-mario-hpa    Deployment/super-mario   5%/50%    2         10        2          2m
```

---

## 📊 Monitoramento

### Logs

```powershell
# Logs de um pod específico
kubectl logs -n games <pod-name>

# Logs de todos os pods do deployment
kubectl logs -n games -l app=super-mario --all-containers=true

# Seguir logs em tempo real
kubectl logs -n games -l app=super-mario -f

# Logs dos últimos 10 minutos
kubectl logs -n games <pod-name> --since=10m
```

### Eventos

```powershell
# Eventos do namespace
kubectl get events -n games --sort-by='.lastTimestamp'

# Eventos de um recurso específico
kubectl describe deployment super-mario -n games | Select-String "Events:" -A 20

# Eventos de scaling
kubectl describe hpa super-mario-hpa -n games | Select-String "Events:" -A 10
```

### Métricas

```powershell
# CPU e memória dos pods
kubectl top pods -n games

# CPU e memória dos nodes
kubectl top nodes

# Métricas de um pod específico
kubectl top pod <pod-name> -n games --containers
```

---

## 🗑️ Limpeza

### Remover recursos individualmente

```powershell
kubectl delete -f manifests/04-stress-test-fortio.yaml
kubectl delete -f manifests/03-hpa.yaml
kubectl delete -f manifests/02-service-mario.yaml
kubectl delete -f manifests/01-deployment-mario.yaml
```

### Remover tudo de uma vez

```powershell
# Deletar todos os manifestos
kubectl delete -f manifests/

# OU deletar o namespace inteiro
kubectl delete namespace games
```

### Deletar cluster

```powershell
# Deletar cluster Kind
kind delete cluster --name k8s-essentials

# Verificar que foi removido
kind get clusters
```

---

## 🔧 Customizações Comuns

### Aumentar recursos

```yaml
# 01-deployment-mario.yaml
resources:
  requests:
    cpu: 200m
    memory: 512Mi
  limits:
    cpu: 1000m
    memory: 1Gi
```

### Ajustar HPA

```yaml
# 03-hpa.yaml
spec:
  minReplicas: 3
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        averageUtilization: 70
```

### Mudar para ClusterIP (produção)

```yaml
# 02-service-mario.yaml
spec:
  type: ClusterIP  # Remove NodePort
  ports:
  - port: 80
    targetPort: 8080
    # Remove nodePort
```

---

## 📚 Referências

- [Kubernetes Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Kubernetes Services](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Horizontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Metrics Server](https://github.com/kubernetes-sigs/metrics-server)
- [Fortio](https://github.com/fortio/fortio)
- [Kind](https://kind.sigs.k8s.io/)

---

**✅ Manifestos validados e prontos para uso em ambientes de aprendizado!** 🚀
