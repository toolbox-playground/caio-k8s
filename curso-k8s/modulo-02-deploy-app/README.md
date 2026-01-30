# 🎮 Módulo 02: Deploy de Aplicação e Resiliência no Kubernetes

## � Índice

1. [Visão Geral](#-visão-geral)
2. [Objetivos de Aprendizado](#-objetivos-de-aprendizado)
3. [Por Que Este Módulo](#-por-que-este-módulo-vai-fazer-seus-olhos-brilharem)
4. [Pré-requisitos](#-pré-requisitos)
5. [Conceitos Fundamentais](#-conceitos-fundamentais)
6. [Estrutura do Módulo](#-estrutura-do-módulo)
7. [Início Rápido](#-início-rápido-15-minutos)
8. [Manifestos Kubernetes](#-manifestos-kubernetes)
9. [Teste de Stress](#-teste-de-stress-com-fortio)
10. [Recursos Adicionais](#-recursos-adicionais)

---

## 📚 Visão Geral

Neste módulo prático, você vai além da criação de clusters e aprende a fazer deploy de aplicações reais, explorando os recursos de **auto-healing** e **auto-scaling** do Kubernetes. Através de um laboratório hands-on, você irá:

- ✅ Subir um cluster Kubernetes local
- ✅ Fazer deploy de um jogo web interativo (Super Mario 🍄)
- ✅ Testar a resiliência do cluster deletando pods
- ✅ Simular alta carga para observar o auto-scaling em ação
- ✅ Monitorar métricas em tempo real

## 🎯 Objetivos de Aprendizado

Ao final deste módulo, você será capaz de:

- ✅ Fazer deploy de aplicações containerizadas no Kubernetes
- ✅ Expor serviços para acesso via port-forward (boas práticas)
- ✅ Compreender o comportamento de auto-healing (recuperação automática)
- ✅ Configurar e testar Horizontal Pod Autoscaler (HPA)
- ✅ Executar testes de carga para validar resiliência
- ✅ Monitorar métricas de recursos em tempo real
- ✅ Aplicar boas práticas de deployment em produção

**⏱️ Duração Estimada:** 1 hora e 15 minutos

---

## 🌟 Por Que Este Módulo Vai Fazer Seus Olhos Brilharem

### 👨‍🎓 Para Estudantes e Iniciantes em DevOps

Esqueça os tutoriais chatos de "Hello World". Aqui você vai:

**Deployar Super Mario em Kubernetes** 🍄
- Imagine contar isso numa entrevista: *"Eu fiz deploy do Super Mario num cluster Kubernetes e testei resiliência em produção"*
- Não é teoria, é **você jogando Mario enquanto Kubernetes gerencia os pods**
- Você pode mostrar no seu portfolio, no LinkedIn, numa apresentação

**Ver Kubernetes Trabalhando em Tempo Real** 👀
```
Você deleta um pod → Kubernetes cria outro em 10s → Mario continua rodando
Você gera carga → CPU sobe → HPA cria mais pods → Carga é distribuída
```

**Ganhar Habilidades de Mercado** 💼
- Auto-healing? ✅ Você viu acontecer
- Auto-scaling? ✅ Você fez funcionar  
- Metrics? ✅ Você configurou
- Production-ready? ✅ Você deployou

**Resultado:** Confiança real. Você **sabe** como fazer, não apenas leu sobre.

---

### 👔 Para Tech Managers e Engenheiros Sêniores

Você está preocupado com esses problemas? **Este lab resolve na prática:**

#### Problema 1: "Como escalar quando tráfego aumenta 10x?" 📈

**Solução no lab:**
```powershell
# HPA configurado para escalar entre 2 e 10 pods
kubectl apply -f manifests/03-hpa.yaml

# Gere carga no serviço
kubectl apply -f manifests/04-stress-test-fortio.yaml

# Monitorar pods
kubectl get pods -n games --watch
```

**Aplicação real:** Seu e-commerce na Black Friday, sua API num evento viral, seu sistema em horário de pico.

#### Problema 2: "E se um servidor cair às 3h da manhã?" 🔥

**Solução no lab:**
```powershell
# Delete um pod (simula servidor caindo)
kubectl delete pod <pod-name> -n games

# Monitorar pods
kubectl get pods -n games --watch

# Observe:
# - Kubernetes detecta em ~1 segundo
# - Novo pod é criado imediatamente
# - Aplicação continua disponível
# - Usuários não percebem nada
# - Tempo de recuperação: ~10 segundos
```

**Aplicação real:** Sem pager duty às 3h, sem perda de vendas, sem clientes insatisfeitos.

#### Problema 3: "Como otimizar custos sem perder performance?" 💰

**Solução no lab:**
```yaml
# HPA configurado para:
minReplicas: 2   # Mínimo necessário (custo base)
maxReplicas: 10  # Máximo suportável (picos)
targetCPU: 50%   # Uso eficiente de recursos
```

**Observe:**
- Tráfego baixo → 2 pods (economia)
- Tráfego alto → scale up automático (performance)
- Tráfego normaliza → scale down gradual (economia)
- **Você paga apenas pelo que usa**

**Aplicação real:** ROI mensurável, infraestrutura elástica, otimização contínua.

---

### 🎯 O Momento "AHA!" 💡

**Para estudantes:**
> "Quando vi o Super Mario continuando a funcionar mesmo após deletar 2 pods, eu entendi. Kubernetes não é mágica, é engenharia bem feita."

**Para tech managers:**
> "Gastei 1 hora neste lab e finalmente entendi como Kubernetes pode resolver nossos problemas de escala. Semana que vem começo a migração."

**O diferencial:** Não é apresentação de slides. Você **vê acontecendo** na sua tela.

---

## �📋 Pré-requisitos

- ✅ Docker Desktop ou Docker Engine instalado e rodando
- ✅ Kind instalado (ver Módulo 01)
- ✅ kubectl instalado e configurado
- ✅ PowerShell 5.1+ ou PowerShell Core
- ✅ Conhecimento básico de Kubernetes (conceitos do Módulo 01)
- ✅ 4GB RAM disponível
- ✅ Conexão com internet (para download de imagens)

## 🧠 Conceitos Fundamentais

### O que você vai aprender na prática

#### 1. **Deployments**
Deployments são a forma declarativa de gerenciar aplicações no Kubernetes. Eles garantem que um número especificado de réplicas da sua aplicação esteja sempre rodando.

**Principais características:**
- Gerenciamento declarativo de estado desejado
- Rolling updates automáticos
- Rollback facilitado
- Controle de histórico de versões

#### 2. **Services**
Services fornecem uma abstração de rede estável para acessar pods dinâmicos. Enquanto pods podem ser criados e destruídos, o Service mantém um ponto de acesso consistente.

**Tipos que usaremos:**
- **ClusterIP**: Acesso interno ao cluster (padrão)
- **NodePort**: Expõe a aplicação em uma porta específica de cada nó

#### 3. **Auto-Healing (Recuperação Automática)**
O Kubernetes monitora continuamente o estado dos seus pods. Se um pod falha ou é deletado, o controller automaticamente cria um novo para manter o estado desejado.

**Como funciona:**
```
Estado Desejado: 3 réplicas
Estado Atual: 2 réplicas (1 pod falhou)
→ Kubernetes cria automaticamente 1 novo pod
→ Estado restaurado: 3 réplicas ✓
```

#### 4. **Horizontal Pod Autoscaler (HPA)**
O HPA ajusta automaticamente o número de réplicas baseado em métricas como CPU e memória.

**Fluxo de funcionamento:**
```
1. Métricas coletadas a cada 15s (padrão)
2. Cálculo: réplicas desejadas = ⌈réplicas atuais × (uso atual / uso alvo)⌉
3. Scale up/down conforme necessário
4. Respeita limites min/max configurados
```

**Exemplo de cálculo:**
```
Réplicas atuais: 2
CPU atual: 80%
CPU alvo: 50%
→ Réplicas desejadas = ⌈2 × (80/50)⌉ = ⌈3.2⌉ = 4 pods
```

### Arquitetura do que vamos construir

```
┌─────────────────────────────────────────────────────────────┐
│                      Cluster Kubernetes                     │
│                                                             │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                Service (NodePort)                      │ │
│  │           Porta 8081 (NodePort) → 30000                │ │
│  └─────────────┬──────────────────────────────────────────┘ │
│                │ Load Balancing                             │
│                ▼                                            │
│  ┌─────────────────────────────────────────────────────────┐│
│  │              Deployment (super-mario)                   ││
│  │                                                         ││
│  │  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐                 ││
│  │  │ Pod1 │  │ Pod2 │  │ Pod3 │  │ ...  │                 ││
│  │  │ 🍄   │  │ 🍄  │  │ 🍄   │  │  🍄  │                 ││
│  │  └──────┘  └──────┘  └──────┘  └──────┘                 ││
│  │                                                         ││
│  │  ▲ Auto-healing: Recria pods deletados                  ││
│  │  ▲ Auto-scaling: Ajusta réplicas por carga              ││
│  └─────────────────────────────────────────────────────────┘│
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐│
│  │     Horizontal Pod Autoscaler (HPA)                     ││
│  │     Min: 2 | Max: 10 | Target CPU: 50%                  ││
│  └─────────────────────────────────────────────────────────┘│
│                                                             │
└─────────────────────────────────────────────────────────────┘
         ▲
         │ Acesso direto via NodePort
         │ http://localhost:8081
   ┌─────┴─────┐
   │  Browser  │
   └───────────┘
```

---

## 📚 Estrutura do Módulo

```
modulo-02-deploy-app/
├── README.md                          # 📖 Este arquivo - Guia completo do módulo
├── QUICK-START.md                     # ⚡ Guia de início rápido
└── manifests/
    ├── 01-deployment-mario.yaml       # 🚀 Deployment da aplicação
    ├── 02-service-mario.yaml          # 🌐 Service ClusterIP
    ├── 03-hpa.yaml                    # 📈 Horizontal Pod Autoscaler
    ├── 04-stress-test-fortio.yaml     # 🔥 Pods de stress test (Fortio)
    ├── cluster-config.yaml            # 🔥 Configuração do cluster para stress test
    └── README.md                      # 📋 Documentação dos manifestos
```

---

## ⚡ Início Rápido (15 minutos)

**Prefere ir direto ao ponto?** Use nosso guia de início rápido:

📖 **[QUICK-START.md](./QUICK-START.md)** - Deploy completo do Super Mario em 15 minutos

**O que está incluído:**
- ✅ Comandos prontos para copiar e colar
- ✅ Setup completo do cluster com Metrics Server
- ✅ Deploy do Super Mario com HPA
- ✅ Configuração de port-forward
- ✅ Teste de stress com Fortio
- ✅ Verificações de validação

**Ideal para:** Quem já conhece Kubernetes e quer apenas ver funcionando rapidamente.

---

## 🚀 Deploy Passo a Passo

Verifique se você está na pasta do módulo:
```powershell
cd curso-k8s/modulo-02-deploy-app
```

Verifique se existe algum clustes com o nome `k8s-essentials` e delete se necessário:
```powershell
kind delete cluster --name k8s-essentials
```

```powershell
# 1. Criar o cluster Kubernetes com 1 control-plane e 2 workers
kind create cluster --config manifests/cluster-config.yaml

# 2. Criar namespace
kubectl create namespace games

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

# 6. Aguardar pods ficarem prontos
kubectl wait --for=condition=ready pod -l app=super-mario -n games --timeout=120s

# 7. Acessar aplicação
http://localhost:8081

# 8. Caso o NodePort não funcione, use port-forward (método profissional)
kubectl port-forward -n games service/super-mario-service 8081:8080
```

### 🎯 Próximos Passos

Após o deploy inicial:

1. 🔧 **Auto-Healing**: Use o [Guia](#-auto-healing---recuperação-automática)
2. 🔥 **Teste de Stress**: Use o [Guia de Stress Test](#-teste-de-stress-com-fortio)
3. 📊 **Monitoramento**: Configure [dashboards em tempo real](#monitoramento-em-tempo-real)

---

### Estrutura do Laboratório (5 Partes)

O módulo está dividido em 5 partes com timing preciso:

**Parte 1: Setup do Cluster** (15 min)
- Criar cluster multi-node (1 control-plane + 2 workers)
- Instalar e configurar Metrics Server
- Verificar pré-requisitos e recursos
- Validar instalação com `kubectl top nodes`

**Parte 2: Deploy da Aplicação** (15 min)
- Criar namespace `games`
- Aplicar Deployment do Super Mario
- Configurar Service NodePort
- Testar acesso via port-forward
- Validar health probes

**Parte 3: Testar Auto-Healing** (15 min)
- Deletar pods individualmente
- Deletar todos os pods simultaneamente
- Simular falha de container (`kill 1`)
- Observar recuperação automática
- Entender ReplicaSet controller

**Parte 4: Configurar Auto-Scaling** (15 min)
- Aplicar HPA (Horizontal Pod Autoscaler)
- Aguardar coleta de métricas (1-2 min)
- Verificar `kubectl get hpa`
- Entender cálculo de réplicas desejadas
- Compreender behavior (scale up/down)

**Parte 5: Testar Auto-Scaling** (15 min)
- Aplicar pods de stress test (Fortio)
- Monitorar HPA em tempo real (3 terminais)
- Observar criação de novos pods
- Aguardar término do stress test
- Observar scale down automático

**Tempo total:** 1 hora e 15 minutos

**Pré-requisitos verificados:**
- ✅ Docker rodando
- ✅ Kind v0.20.0+
- ✅ kubectl v1.28.0+
- ✅ 4GB RAM disponível
- ✅ 10GB espaço em disco

___

## 🎯 Cenários de Teste

**Você vai testar:**

1. **Deploy inicial**: Super Mario rodando com 2 réplicas
2. **Auto-healing**: Deletar pods e observar recuperação automática
3. **Auto-scaling**: Gerar carga alta e ver pods sendo criados automaticamente
4. **Scale down**: Remover carga e observar redução de pods

## 🎯 Resultados Esperados

Ao completar este módulo, você terá:

1. ✅ Um jogo web rodando em Kubernetes
2. ✅ Comprovação prática de auto-healing
3. ✅ Observação real de auto-scaling em ação
4. ✅ Conhecimento de como deployar aplicações resilientes
5. ✅ Scripts reutilizáveis para futuros projetos

## 📖 Recursos Adicionais

- [Kubernetes Deployments - Documentação Oficial](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Kubernetes Services - Documentação Oficial](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Horizontal Pod Autoscaler - Documentação Oficial](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Self-Healing no Kubernetes](https://kubernetes.io/docs/concepts/workloads/controllers/)

## 🤝 Suporte

Problemas comuns e soluções estão documentados no laboratório.

Se encontrar algum problema:
1. Verifique os logs: `kubectl logs <pod-name>`
2. Descreva o recurso: `kubectl describe <resource> <name>`
3. Verifique eventos: `kubectl get events --sort-by='.lastTimestamp'`

---

# 📦 Manifestos Kubernetes

Esta pasta contém os manifestos YAML para deploy do **Super Mario 🍄** no Kubernetes.

## 📁 Arquivos

### Super Mario 🍄

| Arquivo | Descrição | Recurso |
|---------|-----------|---------|
| `01-deployment-mario.yaml` | Deployment do Super Mario | Deployment |
| `02-service-mario.yaml` | Service NodePort | Service |
| `03-hpa.yaml` | Horizontal Pod Autoscaler | HPA |
| `04-stress-test-fortio.yaml` | 2 Pods de stress test (Fortio) | Pod |
| `cluster-config.yaml` | Configuração do cluster Kind | Cluster |

**Por que Super Mario?**
- 🌟 Visual impressionante para apresentações
- 🎮 Nostalgia + aprendizado
- 💼 WOW factor em entrevistas e demos
- 🚀 Mesmo setup de produção
- 🔒 Acesso via port-forward (boas práticas)

---

## 📖 Detalhamento dos Manifestos

Acesse o [README dos Manifestos](./manifests/README.md) para explicações detalhadas de cada YAML.

## 🔧 Customizações Comuns

### Aumentar recursos para cargas maiores

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

---

**Dica:** Use `kubectl port-forward` para acesso seguro aos serviços durante desenvolvimento!

---

## � Auto-Healing - Recuperação Automática

O **Auto-Healing** é uma das funcionalidades mais poderosas do Kubernetes, garantindo que sua aplicação permaneça disponível mesmo diante de falhas.

### 📖 O Que é Auto-Healing?

Auto-healing é a capacidade do Kubernetes de **detectar e corrigir falhas automaticamente**, sem intervenção humana. O **ReplicaSet Controller** monitora constantemente:

- ✅ Número de pods rodando
- ✅ Estado desejado (definido no Deployment)
- ✅ Se algum pod falhou ou foi deletado

**Fluxo de auto-recuperação:**
```
Estado Desejado: 2 réplicas
Estado Atual: 1 réplica (1 pod foi deletado/falhou)
→ Kubernetes AUTOMATICAMENTE cria 1 novo pod
→ Estado restaurado: 2 réplicas ✓

Timeline típica:
0s   - Pod deletado ou falhou
1s   - Kubernetes detecta (ReplicaSet vê diferença)
2s   - Novo pod é criado (status: Pending)
3-8s - Container sendo criado
8-15s- Pod fica Running e Ready
```

### 💡 Por Que Auto-Healing é Importante?

| Sem Auto-Healing | Com Auto-Healing (Kubernetes) |
|-------------------|-------------------------------|
| 🔴 Servidor cai às 3h da manhã | ✅ Novo pod criado em 10s |
| 🔴 Precisa chamar alguém no pager | ✅ Problema resolvido automaticamente |
| 🔴 Downtime de minutos/horas | ✅ Downtime de segundos |
| 🔴 Perda de receita | ✅ Alta disponibilidade |
| 🔴 Clientes insatisfeitos | ✅ Experiência sem interrupção |

---

### 🧪 Como Testar Auto-Healing (Passo a Passo)

#### 1. Verificar pods rodando

```powershell
# Ver os pods do Super Mario
kubectl get pods -n games -l app=super-mario

# Saída esperada:
# NAME                          READY   STATUS    RESTARTS   AGE
# super-mario-xxxxxxxxx-xxxxx   1/1     Running   0          2m
# super-mario-xxxxxxxxx-xxxxx   1/1     Running   0          2m
```

#### 2. Deletar um pod manualmente (simular falha)

```powershell
# Copiar o nome de um dos pods e deletar
kubectl delete pod super-mario-xxxxxxxxx-xxxxx -n games

# Você verá:
# pod "super-mario-xxxxxxxxx-xxxxx" deleted
```

#### 3. Observar auto-healing em ação

```powershell
# Monitorar em tempo real
kubectl get pods -n games -l app=super-mario --watch

# Você verá a sequência:
# super-mario-xxxxxxxxx-xxxxx   1/1   Terminating         0     5m
# super-mario-xxxxxxxxx-NEW     0/1   Pending             0     0s   ← NOVO POD CRIADO!
# super-mario-xxxxxxxxx-NEW     0/1   ContainerCreating   0     1s
# super-mario-xxxxxxxxx-NEW     1/1   Running             0     10s  ← PRONTO!
```

#### 4. Verificar que temos 2 pods novamente

```powershell
kubectl get pods -n games -l app=super-mario

# Novamente 2 pods rodando! ✅
```

---

### 🎯 Cenários de Teste Avançados

#### Deletar TODOS os pods de uma vez

```powershell
# Deletar todos os 2 pods
kubectl delete pods -n games -l app=super-mario

# Kubernetes vai RECRIAR TODOS automaticamente!
kubectl get pods -n games --watch
```

#### Simular falha de container

```powershell
# Entrar no pod e matar o processo principal
kubectl exec -n games <pod-name> -- kill 1

# Kubernetes detecta que o container morreu e reinicia automaticamente
kubectl get pods -n games --watch

# Você verá RESTARTS aumentar
# NAME                          READY   STATUS    RESTARTS   AGE
# super-mario-xxxxxxxxx-xxxxx   1/1     Running   1          5m
```

#### Teste rápido em uma linha

```powershell
# Deletar primeiro pod e monitorar recuperação
kubectl delete pod $(kubectl get pods -n games -l app=super-mario -o jsonpath='{.items[0].metadata.name}') -n games && kubectl get pods -n games --watch
```

---

### 📊 Comandos Úteis para Monitorar Auto-Healing

```powershell
# Ver status do deployment
kubectl get deployment super-mario -n games

# Ver detalhes do ReplicaSet (gerenciador de réplicas)
kubectl get replicaset -n games

# Ver eventos de criação/destruição de pods
kubectl get events -n games --sort-by='.lastTimestamp' | Select-Object -Last 20

# Você verá eventos como:
# "Killing container"
# "Created container"  
# "Started container"

# Descrever deployment (ver condições e eventos)
kubectl describe deployment super-mario -n games

# Ver histórico de rollout
kubectl rollout history deployment/super-mario -n games
```

---

### 🎓 Resumo: Auto-Healing em Ação

**Auto-Healing = Kubernetes mantém seus pods vivos automaticamente**

✅ **Você deleta um pod** → Kubernetes cria outro em ~10s  
✅ **Container trava** → Kubernetes reinicia automaticamente  
✅ **Node falha** → Kubernetes move pods para outro node  
✅ **Aplicação fica instável** → Health probes detectam e reiniciam  

**Resultado:** Sistema resiliente que **se recupera sozinho** de falhas! 🚀

**Experimente agora:**
```powershell
# Teste rápido de auto-healing
kubectl delete pod $(kubectl get pods -n games -l app=super-mario -o jsonpath='{.items[0].metadata.name}') -n games
kubectl get pods -n games --watch
# Pressione Ctrl+C para sair do watch
```

Veja a mágica do Kubernetes acontecer na sua tela! 🪄✨

---

## 🔥 Teste de Stress com Fortio

Esta seção ensina como usar Fortio para gerar carga e testar o auto-scaling (HPA) em ação.

### O que é Fortio?

Fortio é uma ferramenta de teste de carga HTTP desenvolvida pela comunidade Istio, perfeita para:
- 🔥 Testes de carga HTTP de alta performance
- 📊 Geração de métricas detalhadas
- 🎯 Controle preciso de QPS (queries per second) e concorrência
- ✅ Amplamente usado em ambientes Kubernetes
- URL oficial: [https://fortio.org/](https://fortio.org/)

### 🚀 Uso Rápido

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

#### 1. Aplicar o manifesto de stress test

```bash
# Baixar a imagem Fortio
docker pull fortio/fortio:latest

# Carregar no cluster Kind
kind load docker-image fortio/fortio:latest --name k8s-essentials

# Alternativa: Acessar worker node e puxar imagem manualmente
docker exec -it k8s-essentials-worker bash
ctr -n k8s.io images pull docker.io/fortio/fortio:latest
exit

# Aplicar pods de teste
kubectl apply -f manifests/04-stress-test-fortio.yaml

# Verificar se os pods foram criados
kubectl get pods -n games -l tool=fortio
```

Você terá dois pods:
- **fortio-stress-test**: Gera carga automática de alta intensidade (50 conexões, 10 min)
- **fortio-interactive**: Pod interativo para testes manuais personalizados

#### 2. Monitorar o HPA em ação

Abra **3 terminais** diferentes para monitorar simultaneamente:

**Terminal 1 - Monitorar HPA:**
```powershell
kubectl get hpa -n games --watch
```

**O que observar:**
- `TARGETS`: Uso atual de CPU (ex: 85%/50%)
- `REPLICAS`: Número de pods ativos
- Quando CPU > 50%, HPA aumenta réplicas

**Terminal 2 - Monitorar Pods:**
```powershell
kubectl get pods -n games -l app=super-mario --watch
```

**O que observar:**
- Novos pods sendo criados quando CPU > 50%
- Status: `Pending → ContainerCreating → Running`
- Pods sendo terminados quando carga diminui

**Terminal 3 - Monitorar Métricas:**
```bash
# Ver métricas de CPU/Memória
kubectl top pods -n games -l app=super-mario
```

#### 3. Ver logs do stress test

```bash
# Ver logs em tempo real do stress test
kubectl logs -n games fortio-stress-test -f
```

### 📊 Monitoramento em Tempo Real

#### Monitoramento Contínuo

Use múltiplos terminais com comandos `--watch`:

```bash
# Terminal 1 - Monitorar HPA
kubectl get hpa -n games --watch

# Terminal 2 - Monitorar pods
kubectl get pods -n games -l app=super-mario --watch

# Ver status do stress test
kubectl get pods -n games -l app=stress-test
```

### 🎯 Cenário de Teste Completo

#### Timeline Esperada (10-12 minutos)

```
00:00 - ✅ Teste de stress inicia
00:30 - 📈 CPU começa a subir (20% → 60%)
00:45 - 🚀 HPA detecta necessidade de escalar
01:00 - 🔢 Novos pods são criados (2 → 4 pods)
01:30 - ✅ Pods adicionais ficam Running
02:00 - 📊 Carga é distribuída, CPU estabiliza ~50%
03:00 - 📈 Se carga continua alta, escala mais (4 → 6 → 8)
...
10:00 - ⏹️  Stress test termina (timeout 600s)
10:30 - 📉 CPU cai para 10-20%
11:00 - ⏸️  HPA aguarda 60s (stabilizationWindow)
11:30 - 📉 HPA inicia scale down gradual (8 → 6 → 4 → 2)
12:00 - ✅ Volta ao mínimo de 2 réplicas
```

### 🔧 Uso Avançado

#### Pod Interativo para Debugging

```bash
# Acessar shell do pod interativo
kubectl exec -it fortio-interactive -n games -- /bin/sh

# Dentro do pod, você pode:

# 1. Teste básico (100 requisições, 10 concorrentes)
fortio load -c 10 -n 100 http://super-mario-service:8080/

# 2. Teste de stress moderado (30 segundos, 50 conexões)
fortio load -c 50 -qps 0 -t 30s http://super-mario-service:8080/

# 3. Teste customizado com QPS específico (200 QPS)
fortio load -c 20 -qps 200 -t 1m http://super-mario-service:8080/

# 4. Curl simples para testar conectividade
fortio curl http://super-mario-service:8080/
```

#### Customizar Intensidade do Stress

Edite `manifests/04-stress-test-fortio.yaml` ou crie pods manualmente:

```bash
# Parâmetros do Fortio:
# -c  = Número de conexões concorrentes
# -qps = Queries per second (0 = ilimitado)
# -t  = Duração do teste

# Exemplos de intensidade:

# 🔥 Stress leve (20 conexões, 100 QPS)
kubectl run stress-light -n games --image=fortio/fortio --restart=Never -- \
  load -c 20 -qps 100 -t 5m http://super-mario-service:8080/

# 🔥🔥 Stress moderado (50 conexões, sem limite QPS)
kubectl run stress-medium -n games --image=fortio/fortio --restart=Never -- \
  load -c 50 -qps 0 -t 5m http://super-mario-service:8080/

# 🔥🔥🔥 Stress intenso (100 conexões, sem limite QPS)
kubectl run stress-heavy -n games --image=fortio/fortio --restart=Never -- \
  load -c 100 -qps 0 -t 5m http://super-mario-service:8080/
```

#### Múltiplos Pods de Stress

Para stress distribuído mais intenso, crie pods manualmente:

```bash
# Criar múltiplos pods de stress
kubectl run stress-1 -n games --image=fortio/fortio --restart=Never -- \
  load -c 50 -qps 0 -t 10m http://super-mario-service:8080/

kubectl run stress-2 -n games --image=fortio/fortio --restart=Never -- \
  load -c 50 -qps 0 -t 10m http://super-mario-service:8080/

kubectl run stress-3 -n games --image=fortio/fortio --restart=Never -- \
  load -c 50 -qps 0 -t 10m http://super-mario-service:8080/

# Verificar pods de stress
kubectl get pods -n games | grep stress

# Limpar depois
kubectl delete pod stress-1 stress-2 stress-3 -n games
```

### 📋 Comandos Úteis de Monitoramento

```bash
# Ver eventos do namespace (útil para troubleshooting)
kubectl get events -n games --sort-by='.lastTimestamp'

# Ver detalhes do HPA
kubectl describe hpa super-mario-hpa -n games

# Métricas detalhadas de um pod
kubectl top pod <pod-name> -n games --containers

# Ver histórico de scaling
kubectl describe hpa super-mario-hpa -n games | Select-String -Pattern "ScalingReplicaSet|SuccessfulRescale"
```

### 🧹 Limpeza

```powershell
### Remover recursos individualmente
kubectl delete -f manifests/04-stress-test-fortio.yaml
kubectl delete -f manifests/03-hpa.yaml
kubectl delete -f manifests/02-service-mario.yaml
kubectl delete -f manifests/01-deployment-mario.yaml
```

### Remover tudo de uma vez

```powershell
kubectl delete -f manifests/

# OU deletar o namespace inteiro
kubectl delete namespace games

# Aguardar scale down automático (1-2 minutos)
# OU forçar reset manual para 2 réplicas
kubectl scale deployment super-mario -n games --replicas=2
```

### 📝 Comparação: Métodos de Stress Test

| Método | Complexidade | Intensidade | Controle | Uso |
|--------|--------------|-------------|----------|-----|
| **Fortio** | Baixa | Muito Alta | Excelente | ⭐ Recomendado - Profissional |
| **Apache Bench (ab)** | Baixa | Alta | Médio | Testes rápidos simples |
| **Busybox (wget loop)** | Muito baixa | Média | Baixo | Testes básicos |
| **Múltiplos pods** | Média | Variável | Alto | Stress distribuído |

**Recomendação:** Use **Fortio** - é a ferramenta profissional usada pela comunidade Istio/Kubernetes! 🚀

---

## 📚 Recursos Adicionais

### Documentação Oficial

- [Kubernetes Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/) - Documentação oficial sobre Deployments
- [Kubernetes Services](https://kubernetes.io/docs/concepts/services-networking/service/) - Guia completo de Services
- [Horizontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/) - HPA walkthrough oficial
- [Port Forwarding](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/) - Guia de port-forward
- [Metrics Server](https://github.com/kubernetes-sigs/metrics-server) - Repositório oficial do Metrics Server

### Arquivos do Módulo

- 📖 [README.md](./README.md) - Este arquivo (guia completo)
- ⚡ [QUICK-START.md](./QUICK-START.md) - Guia de início rápido

### 🤝 Suporte e Troubleshooting

#### Problemas Comuns

| Problema | Solução |
|----------|---------|
| Pods em `CrashLoopBackOff` | Aumente recursos (CPU/memória) no deployment |
| HPA mostra `<unknown>` | Aguarde 1-2 minutos para métricas serem coletadas |
| Metrics Server não funciona | Adicione flag `--kubelet-insecure-tls` (apenas local) |
| Port-forward falha | Verifique se o pod está `Running` e na porta correta |
| Imagem não encontrada | Execute `kind load docker-image` ou mude `imagePullPolicy` |

#### Comandos de Debug

```powershell
# Ver logs de um pod
kubectl logs -n games <pod-name>

# Descrever pod (ver eventos e status)
kubectl describe pod -n games <pod-name>

# Ver todos os eventos do namespace
kubectl get events -n games --sort-by='.lastTimestamp'

# Verificar recursos de um pod
kubectl top pod -n games <pod-name>

# Entrar no shell de um pod
kubectl exec -it -n games <pod-name> -- /bin/sh

# Ver configuração do HPA
kubectl get hpa -n games -o yaml

# Verificar endpoints do service
kubectl get endpoints -n games super-mario-service
```

#### Resetar Ambiente

```powershell
# Deletar namespace (remove tudo)
kubectl delete namespace games

# Recriar do zero
kubectl create namespace games
kubectl apply -f manifests/

# OU deletar cluster e começar novamente
kind delete cluster --name k8s-essentials
.\scripts\setup-cluster.ps1
```

---

## 🎓 Conclusão

Parabéns! Ao completar este módulo, você:

✅ **Deployou** uma aplicação real no Kubernetes  
✅ **Configurou** auto-healing e auto-scaling  
✅ **Testou** resiliência em cenários práticos  
✅ **Monitorou** métricas e recursos em tempo real  
✅ **Aplicou** boas práticas de produção (port-forward, ClusterIP)  
✅ **Ganhou** experiência hands-on valiosa para o mercado  

### 💡 Principais Aprendizados

1. **Auto-Healing** garante alta disponibilidade sem intervenção manual
2. **Auto-Scaling** otimiza recursos baseado em demanda real
3. **Port-Forward** é o método profissional para acessar serviços
4. **Metrics Server** é essencial para HPA funcionar
5. **Health Probes** garantem que apenas pods saudáveis recebam tráfego

### 🚀 Você Está Pronto Para

- Fazer deploys em ambientes de produção
- Configurar aplicações resilientes e escaláveis
- Troubleshooting de problemas em clusters Kubernetes
- Demonstrar conhecimento prático em entrevistas
- Contribuir em projetos DevOps reais

---

<div align="center">

**Feito com ❤️ para estudantes e profissionais de Kubernetes**

[⬆️ Voltar ao topo](#-módulo-02-deploy-de-aplicação-e-resiliência-no-kubernetes)

</div>
