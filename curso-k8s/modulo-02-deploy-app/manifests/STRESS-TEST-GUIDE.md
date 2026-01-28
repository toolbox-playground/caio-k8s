# 🔥 Teste de Stress com Polinux

Este guia mostra como usar o Polinux para testar auto-scaling (HPA) no Kubernetes.

## 📋 O que é Polinux?

Polinux é uma imagem Docker leve baseada em Alpine Linux com ferramentas úteis para:
- Testes de carga HTTP (Apache Bench, curl, wget)
- Monitoramento (htop, top)
- Debugging de rede
- Testes de conectividade

## 🚀 Uso Rápido

### 1. Aplicar o manifesto de stress test

```powershell
# Aplicar pods de teste
kubectl apply -f manifests/04-stress-test-fortio.yaml

# Verificar se os pods foram criados
kubectl get pods -n games -l tool=polinux
```

### 2. Monitorar o HPA em ação

Abra **3 terminais** diferentes para monitorar simultaneamente:

#### Terminal 1: Monitorar HPA
```powershell
# Ver status do HPA atualizando a cada 2 segundos
kubectl get hpa -n games --watch
```

**O que observar:**
- `TARGETS`: Uso atual de CPU (ex: 85%/50%)
- `REPLICAS`: Número de pods ativos
- `AGE`: Quanto tempo o HPA está rodando

#### Terminal 2: Monitorar Pods
```powershell
# Ver pods sendo criados/destruídos em tempo real
kubectl get pods -n games -l app=super-mario --watch
```

**O que observar:**
- Novos pods sendo criados quando CPU > 50%
- Status `Pending → ContainerCreating → Running`
- Pods sendo terminados quando carga diminui

#### Terminal 3: Monitorar Métricas de CPU/Memória
```bash
# Ver métricas de CPU/Memória atualizando automaticamente
kubectl top pods -n games -l app=super-mario --watch
```

### 3. Comandos Úteis de Monitoramento

#### Ver logs do teste de stress
```powershell
# Ver logs do pod de stress
kubectl logs -n games polinux-stress-test -f
```

#### Ver eventos do namespace
```powershell
# Eventos recentes (útil para troubleshooting)
kubectl get events -n games --sort-by='.lastTimestamp' | Select-Object -Last 20
```

#### Verificar detalhes do HPA
```powershell
# Ver configuração e eventos do HPA
kubectl describe hpa super-mario-hpa -n games
```

#### Métricas detalhadas de um pod específico
```powershell
# Substituir <pod-name> pelo nome real do pod
kubectl top pod <pod-name> -n games --containers
```

## 🎯 Cenário de Teste Completo

### Passo 1: Preparar monitoramento (30 segundos)

```powershell
# Terminal 1 - Monitorar HPA
kubectl get hpa -n games --watch

# Terminal 2 - Monitorar Pods  
kubectl get pods -n games --watch

# Terminal 3 - Ver métricas
kubectl top pods -n games -l app=super-mario --watch
```

### Passo 2: Iniciar teste de stress

```powershell
# Aplicar o pod de stress
kubectl apply -f manifests/04-stress-test-fortio.yaml

# Verificar que o pod está rodando
kubectl get pods -n games -l app=stress-test
```

### Passo 3: Observar auto-scaling (2-3 minutos)

**Timeline esperada:**
```
00:00 - Teste inicia, CPU começa a subir
00:30 - CPU atinge 60-80%, HPA detecta necessidade de escalar
00:45 - Novos pods são criados (2 → 4 pods)
01:00 - Pods adicionais ficam Running
01:15 - Carga é distribuída, CPU estabiliza em ~50%
02:00 - Se carga continua alta, pode escalar mais (4 → 6 → 8)
```

**Após ~10 minutos:** O pod de stress para automaticamente (activeDeadlineSeconds: 600)

### Passo 4: Observar scale down (1-2 minutos após stress parar)

```
10:00 - Stress test termina
10:30 - CPU cai para 10-20%
11:00 - HPA aguarda 60s (stabilizationWindow)
11:30 - HPA inicia scale down gradual (8 → 6 → 4 → 2)
12:00 - Volta ao mínimo de 2 réplicas
```

## 🔧 Uso Avançado

### Pod Interativo para Debugging

O manifesto também cria um pod interativo que fica sempre disponível:

```powershell
# Acessar shell do pod interativo
kubectl exec -it polinux-interactive -n games -- /bin/sh

# Dentro do pod, você pode:

# 1. Testar conectividade
wget -O- http://super-mario-service:8080

# 2. Fazer requisições específicas
curl -I http://super-mario-service:8080

# 3. Teste de carga manual
for i in $(seq 1 100); do
  wget -q -O- http://super-mario-service:8080 > /dev/null &
done

# 4. Ver processos (se htop disponível)
htop
```

### Customizar intensidade do stress

Edite o arquivo `04-stress-test-fortio.yaml`:

```yaml
# Linha do Apache Bench (ab)
ab -n 1000 -c 50 http://...

# Parâmetros:
# -n 1000   = Total de requisições (aumente para mais carga)
# -c 50     = Requisições concorrentes (aumente para mais pressão)

# Exemplos:
ab -n 5000 -c 100    # Stress moderado
ab -n 10000 -c 200   # Stress alto
ab -n 50000 -c 500   # Stress muito alto
```

### Múltiplos pods de stress

Para stress distribuído, crie pods manualmente:

```bash
# Criar pods de stress (repita o comando conforme necessário)
kubectl run stress-1 -n games \
  --image=nixery.dev/shell/apache-bench \
  --restart=Never \
  --command -- /bin/sh -c "while true; do ab -n 1000 -c 50 http://super-mario-service:8080/; done"

kubectl run stress-2 -n games \
  --image=nixery.dev/shell/apache-bench \
  --restart=Never \
  --command -- /bin/sh -c "while true; do ab -n 1000 -c 50 http://super-mario-service:8080/; done"

# Limpar depois
kubectl delete pods -n games stress-1 stress-2
```

## 📊 Monitoramento em Tempo Real

Use os comandos com `--watch` para monitoramento contínuo:

```bash
# Monitorar HPA (terminal 1)
kubectl get hpa -n games --watch

# Monitorar pods (terminal 2)
kubectl get pods -n games -l app=super-mario --watch

# Monitorar métricas (terminal 3)
kubectl top pods -n games -l app=super-mario --watch

# Ver status do stress test
kubectl get pods -n games -l app=stress-test
```

## 🧹 Limpeza

### Remover pods de stress
```powershell
# Remover todos os pods de teste
kubectl delete -f manifests/04-stress-test-fortio.yaml

# OU remover apenas por label
kubectl delete pods -n games -l tool=polinux
```

### Resetar HPA (volta para 2 réplicas)
```powershell
# Aguardar scale down automático (pode levar 1-2 minutos)
# OU forçar scale down manual
kubectl scale deployment super-mario -n games --replicas=2
```

## 📚 Referências

- [Horizontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Apache Bench Documentation](https://httpd.apache.org/docs/2.4/programs/ab.html)
- [Kubectl Top Command](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_top/)

---

**Dica Pro:** Use múltiplos terminais para monitorar diferentes aspectos simultaneamente e ter uma visão completa do auto-scaling em ação! 🚀
