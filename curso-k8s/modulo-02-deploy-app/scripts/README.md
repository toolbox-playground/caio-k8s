# 🔧 Scripts de Automação

Esta pasta contém scripts PowerShell para automatizar tarefas comuns do laboratório.

## 📁 Scripts Disponíveis

| Script | Descrição | Duração |
|--------|-----------|---------|  
| `setup-cluster.ps1` | Cria cluster Kind com Metrics Server | ~3-5 min |
| `deploy-app.ps1` | Deploy completo do Super Mario | ~1-2 min |
| `test-autoheal.ps1` | Testa auto-healing (deleta pods) | ~2-3 min |
| `load-test.ps1` | Gera carga para testar auto-scaling | ~5-10 min |

## 🚀 Guia de Uso Rápido

### Fluxo Completo (do zero ao teste)

```powershell
# 1. Setup do cluster
.\setup-cluster.ps1

# 2. Deploy da aplicação
.\deploy-app.ps1

# 3. Testar auto-healing
.\test-autoheal.ps1

# 4. Testar auto-scaling
.\load-test.ps1
```

**Tempo total:** ~15-20 minutos

---

## 📖 Documentação Detalhada

### setup-cluster.ps1

**Descrição:** Cria um cluster Kubernetes local usando Kind, otimizado para demonstrações de resiliência.

**O que faz:**
- ✅ Verifica pré-requisitos (Docker, Kind, kubectl)
- ✅ Cria cluster multi-node (1 control-plane + 2 workers)
- ✅ Mapeia porta 30080 para acesso externo
- ✅ Instala Metrics Server
- ✅ Configura Metrics Server para Kind
- ✅ Aguarda métricas ficarem disponíveis

**Parâmetros:**

```powershell
.\setup-cluster.ps1 `
    -ClusterName "lab-resiliencia" `  # Nome do cluster (padrão: "lab-resiliencia")
    -Workers 2 `                       # Número de workers (padrão: 2)
    -NodePort 30080                    # Porta para aplicação (padrão: 30080)
```

**Exemplos:**

```powershell
# Cluster padrão
.\setup-cluster.ps1

# Cluster customizado
.\setup-cluster.ps1 -ClusterName "meu-lab" -Workers 3 -NodePort 30090

# Cluster mínimo (1 worker)
.\setup-cluster.ps1 -Workers 1
```

**Solução de problemas:**

```powershell
# Se cluster já existe, o script perguntará se deve recriar
# Para forçar deleção sem perguntar:
kind delete cluster --name lab-resiliencia
.\setup-cluster.ps1

# Se métricas não aparecem após 2 minutos:
kubectl top nodes  # Aguarde até funcionar
```

---

### deploy-app.ps1

**Descrição:** Faz deploy completo do Super Mario (Deployment, Service ClusterIP, HPA).

**O que faz:**
- ✅ Verifica se há cluster ativo
- ✅ Cria namespace se não existir
- ✅ Aplica manifestos (Deployment, Service, HPA)
- ✅ Aguarda rollout completar
- ✅ Verifica recursos criados
- ✅ Oferece iniciar port-forward automaticamente

**Parâmetros:**

```powershell
.\deploy-app.ps1 `
    -Namespace "games" `      # Namespace (padrão: "games")
    -Replicas 2 `             # Réplicas iniciais (padrão: 2)
    -SkipHPA `                # Pula criação do HPA (opcional)
    -StartPortForward         # Inicia port-forward automaticamente
```

**Exemplos:**

```powershell
# Deploy padrão
.\deploy-app.ps1

# Deploy com 5 réplicas
.\deploy-app.ps1 -Replicas 5

# Deploy sem HPA (para criar manualmente depois)
.\deploy-app.ps1 -SkipHPA

# Deploy e iniciar port-forward automaticamente
.\deploy-app.ps1 -StartPortForward
```

**Verificação pós-deploy:**

```powershell
# Ver tudo
kubectl get all -n games

# Acessar via port-forward
kubectl port-forward -n games service/super-mario-service 8080:80
# Abra: http://localhost:8080

# Ver logs
kubectl logs -n games -l app=super-mario -f
```

---

### test-autoheal.ps1

**Descrição:** Demonstra auto-healing deletando pods e observando recuperação.

**O que faz:**
- ✅ Verifica aplicação está rodando
- ✅ Deleta pods aleatórios (controlado)
- ✅ Monitora tempo de recuperação
- ✅ Valida estado final
- ✅ Exibe eventos de recuperação

**Parâmetros:**

```powershell
.\test-autoheal.ps1 `
    -Namespace "games" `  # Namespace (padrão: "games")
    -Count 3              # Número de testes (padrão: 3)
```

**Exemplos:**

```powershell
# Teste padrão (3 iterações)
.\test-autoheal.ps1

# Teste único
.\test-autoheal.ps1 -Count 1

# Teste extensivo (10 iterações)
.\test-autoheal.ps1 -Count 10
```

**O que observar:**

```
Teste deleta pod → Pod entra em Terminating → Novo pod é criado (Pending) → 
Novo pod baixa imagem (ContainerCreating) → Novo pod fica Ready (Running) → 
Estado desejado restaurado ✓
```

**Tempo médio de recuperação:** 5-15 segundos

---

### load-test.ps1

**Descrição:** Gera carga HTTP para testar auto-scaling (HPA).

**O que faz:**
- ✅ Verifica HPA está configurado
- ✅ Verifica métricas disponíveis
- ✅ Cria pods geradores de carga (wget loop)
- ✅ Monitora scaling durante teste
- ✅ Para geradores após duração
- ✅ Observa scale down
- ✅ Analisa resultados

**Parâmetros:**

```powershell
.\load-test.ps1 `
    -Namespace "games" `      # Namespace (padrão: "games")
    -LoadGenerators 5 `       # Número de geradores (padrão: 5)
    -Duration 300             # Duração em segundos (padrão: 300)
```

**Exemplos:**

```powershell
# Teste padrão (5 geradores, 5 minutos)
.\load-test.ps1

# Teste rápido (3 geradores, 2 minutos)
.\load-test.ps1 -LoadGenerators 3 -Duration 120

# Teste intenso (10 geradores, 10 minutos)
.\load-test.ps1 -LoadGenerators 10 -Duration 600

# Teste leve (2 geradores, 1 minuto)
.\load-test.ps1 -LoadGenerators 2 -Duration 60
```

**Monitoramento paralelo recomendado:**

Abra 3 terminais adicionais durante o teste:

```powershell
# Terminal 1 - HPA
kubectl get hpa -n games --watch

# Terminal 2 - Pods
kubectl get pods -n games --watch

# Terminal 3 - Métricas
while ($true) {
    Clear-Host
    kubectl top pods -n games
    Start-Sleep -Seconds 5
}
```

**Padrão esperado:**

```
Tempo 0s:   2 pods @ ~5% CPU (baseline)
Tempo 30s:  2 pods @ ~80% CPU (carga aplicada)
Tempo 45s:  4 pods @ ~50% CPU (scale up 1)
Tempo 60s:  6-8 pods @ ~40-50% CPU (scale up 2)
Tempo 300s: Carga removida
Tempo 360s: 4 pods (scale down gradual)
Tempo 420s: 2 pods (voltou ao mínimo)
```

---

## 🎯 Casos de Uso

### Caso 1: Demonstração Rápida (10 minutos)

```powershell
# Setup
.\setup-cluster.ps1

# Deploy
.\deploy-app.ps1

# Abrir no navegador e jogar
Start-Process "http://localhost:30080"

# Deletar 1 pod manualmente
kubectl delete pod -n games $(kubectl get pods -n games -o name | Select-Object -First 1)

# Observar recuperação
kubectl get pods -n games --watch
```

### Caso 2: Workshop/Treinamento (1 hora)

```powershell
# 1. Setup (5 min)
.\setup-cluster.ps1

# 2. Deploy explicado (10 min)
.\deploy-app.ps1
# Explicar: Deployment, Service, HPA

# 3. Auto-healing (10 min)
.\test-autoheal.ps1
# Explicar: ReplicaSet, reconciliation loop

# 4. Auto-scaling (25 min)
.\load-test.ps1 -Duration 180
# Explicar: métricas, HPA algorithm, behavior

# 5. Q&A e cleanup (10 min)
```

### Caso 3: Testes de Stress

```powershell
# Criar cluster maior
.\setup-cluster.ps1 -Workers 4

# Deploy com mais réplicas
.\deploy-app.ps1 -Replicas 5

# Carga extrema
.\load-test.ps1 -LoadGenerators 20 -Duration 600

# Observar scaling até maxReplicas (10)
```

---

## 🧹 Limpeza

### Opção 1: Limpar aplicação, manter cluster

```powershell
kubectl delete namespace games

# Ou redeploy do zero
.\deploy-app.ps1
```

### Opção 2: Deletar cluster completo

```powershell
kind delete cluster --name lab-resiliencia

# Verificar
kind get clusters
```

### Opção 3: Limpar tudo + containers

```powershell
# Deletar todos os clusters Kind
kind delete clusters --all

# Limpar containers órfãos
docker container prune -f
docker image prune -a -f
```

---

## ⚙️ Customização

### Modificar configuração do cluster

Edite `setup-cluster.ps1` para:
- Adicionar mais workers
- Mudar versão do Kubernetes
- Configurar features gates
- Adicionar registry local

### Modificar teste de carga

Edite `load-test.ps1` para:
- Usar ferramentas diferentes (ab, wrk, hey)
- Testar endpoints específicos
- Gerar padrões de carga variáveis
- Coletar métricas customizadas

---

## 🐛 Troubleshooting

### Script falha com "Execution Policy"

```powershell
# Temporariamente permitir execução
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# Ou rodar diretamente
pwsh -ExecutionPolicy Bypass -File .\setup-cluster.ps1
```

### Métricas não aparecem

```powershell
# Verificar Metrics Server
kubectl get deployment metrics-server -n kube-system

# Ver logs
kubectl logs -n kube-system -l k8s-app=metrics-server

# Aguardar 2-3 minutos após cluster criar
Start-Sleep -Seconds 180
kubectl top nodes
```

### HPA mostra `<unknown>`

```powershell
# Aguardar 1-2 minutos
# Verificar se pods têm resource requests definidos
kubectl get deployment game-2048 -n games -o yaml | Select-String -Pattern "resources:" -Context 3

# Recriar HPA
kubectl delete hpa game-2048-hpa -n games
kubectl apply -f ..\manifests\03-hpa.yaml
```

### Port 30080 já em uso

```powershell
# Verificar processo usando porta
Get-Process -Id (Get-NetTCPConnection -LocalPort 30080).OwningProcess

# Usar porta diferente
.\setup-cluster.ps1 -NodePort 30090
# Atualizar manifests/02-service.yaml nodePort: 30090
```

---

## 📚 Recursos Adicionais

- [Kind Documentation](https://kind.sigs.k8s.io/)
- [Metrics Server](https://github.com/kubernetes-sigs/metrics-server)
- [PowerShell Kubectl](https://kubernetes.io/docs/reference/kubectl/)

---

**Pronto para começar? Execute:**

```powershell
.\setup-cluster.ps1
```

🎉 **Boa prática!**
