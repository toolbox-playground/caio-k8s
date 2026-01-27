# 🎮 Módulo 02: Deploy de Aplicação e Resiliência no Kubernetes

## 📚 Visão Geral

Neste módulo prático, você vai além da criação de clusters e aprende a fazer deploy de aplicações reais, explorando os recursos de **auto-healing** e **auto-scaling** do Kubernetes. Através de um laboratório hands-on, você irá:

- Subir um cluster Kubernetes local
- Fazer deploy de um jogo web interativo
- Testar a resiliência do cluster deletando pods
- Simular alta carga para observar o auto-scaling em ação

## 🎯 Objetivos de Aprendizado

Ao final deste módulo, você será capaz de:

- ✅ Fazer deploy de aplicações containerizadas no Kubernetes
- ✅ Expor serviços para acesso externo
- ✅ Compreender o comportamento de auto-healing (recuperação automática)
- ✅ Configurar e testar Horizontal Pod Autoscaler (HPA)
- ✅ Executar testes de carga para validar resiliência
- ✅ Monitorar métricas de recursos em tempo real
- ✅ Aplicar boas práticas de deployment em produção

## ⏱️ Duração Estimada: 1 hora e 15 minutos

## � Por Que Este Módulo Vai Fazer Seus Olhos Brilharem

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
# Gere carga no serviço
.\load-test.ps1

# Observe em tempo real:
# - CPU sobe de 5% para 80%
# - HPA detecta automaticamente
# - Novos pods são criados (2 → 4 → 6 → 8)
# - Carga é distribuída
# - CPU volta para 50%
# - Tudo em ~60 segundos
```

**Aplicação real:** Seu e-commerce na Black Friday, sua API num evento viral, seu sistema em horário de pico.

#### Problema 2: "E se um servidor cair às 3h da manhã?" 🔥

**Solução no lab:**
```powershell
# Delete um pod (simula servidor caindo)
kubectl delete pod <pod-name> -n games

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
- **LoadBalancer**: Provisiona um load balancer externo (em clouds)

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
│                      Cluster Kubernetes                      │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                  Service (NodePort)                     │ │
│  │              Expõe na porta 30080                       │ │
│  └─────────────┬──────────────────────────────────────────┘ │
│                │ Load Balancing                              │
│                ▼                                              │
│  ┌─────────────────────────────────────────────────────────┐│
│  │              Deployment (2048-game)                      ││
│  │                                                          ││
│  │  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐               ││
│  │  │ Pod1 │  │ Pod2 │  │ Pod3 │  │ ...  │               ││
│  │  │ 🎮   │  │ 🎮   │  │ 🎮   │  │ 🎮   │               ││
│  │  └──────┘  └──────┘  └──────┘  └──────┘               ││
│  │                                                          ││
│  │  ▲ Auto-healing: Recria pods deletados                  ││
│  │  ▲ Auto-scaling: Ajusta réplicas por carga             ││
│  └─────────────────────────────────────────────────────────┘│
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐│
│  │     Horizontal Pod Autoscaler (HPA)                      ││
│  │     Min: 2 | Max: 10 | Target CPU: 50%                  ││
│  └─────────────────────────────────────────────────────────┘│
│                                                               │
└───────────────────────────────────────────────────────────────┘
         ▲
         │ Acesso via http://localhost:30080
         │
   ┌─────┴─────┐
   │  Browser  │
   └───────────┘
```

## 📚 Estrutura do Módulo

```
modulo-02-deploy-app/
├── README.md                          # Este arquivo
├── laboratorios/
│   └── lab-completo-resiliencia.md   # Lab hands-on completo
├── manifests/
│   ├── 01-deployment.yaml             # Deployment da aplicação
│   ├── 02-service.yaml                # Service NodePort
│   ├── 03-hpa.yaml                    # Horizontal Pod Autoscaler
│   └── README.md                      # Guia dos manifestos
└── scripts/
    ├── setup-cluster.ps1              # Cria cluster com métricas
    ├── deploy-app.ps1                 # Faz deploy completo
    ├── test-autoheal.ps1              # Testa auto-healing
    ├── load-test.ps1                  # Gera carga para teste
    └── README.md                      # Guia dos scripts
```

## 🚀 Início Rápido

Se você quer ir direto ao laboratório:

```powershell
# 1. Crie o cluster
.\scripts\setup-cluster.ps1

# 2. Faça o deploy da aplicação
.\scripts\deploy-app.ps1

# 3. Acesse o jogo
Start-Process "http://localhost:30080"

# 4. Teste o auto-healing
.\scripts\test-autoheal.ps1

# 5. Teste o auto-scaling
.\scripts\load-test.ps1
```

## 🎓 Roteiro de Aprendizado

### Passo 1: Entenda os Conceitos (10 min)
Leia esta seção de conceitos fundamentais para entender:
- O que são Deployments e Services
- Como funciona auto-healing
- Como funciona auto-scaling (HPA)

### Passo 2: Laboratório Hands-On (60 min)
Siga o laboratório completo em:
📖 [Lab: Deploy, Auto-Healing e Auto-Scaling](./laboratorios/lab-completo-resiliencia.md)

### Passo 3: Explore os Manifestos (5 min)
Estude os arquivos YAML em `manifests/` para entender:
- Como definir um Deployment
- Como criar um Service
- Como configurar HPA

## 📊 O que você vai construir

**Escolha sua aplicação:**

### Opção 1: Super Mario 🍄
O clássico jogo Super Mario rodando no Kubernetes!

**Por que Super Mario?**
- 🎮 **Nostalgia + Aprendizado**: Todo mundo conhece e ama Mario!
- 🌟 **Visual impressionante**: Perfeito para demos e apresentações
- 🚀 **Mesma complexidade**: Tudo que funciona para Mario funciona para apps reais
- 💼 **WOW factor**: Imagine mostrar isso numa entrevista ou reunião!

**Deploy rápido:**
```powershell
kubectl create namespace games
kubectl apply -f manifests/01-deployment-mario.yaml
kubectl apply -f manifests/02-service-mario.yaml
# Acesse: http://localhost:30090
```

### Opção 2: Jogo 2048 🎯
Clone web do famoso jogo de puzzle

**Por que 2048?**
- ✅ Leve e rápido para deploy
- ✅ Interface limpa e moderna
- ✅ Não requer banco de dados ou estado
- ✅ Perfeita para demonstrar resiliência

**Deploy rápido:**
```powershell
kubectl create namespace games
kubectl apply -f manifests/01-deployment.yaml
kubectl apply -f manifests/02-service.yaml
# Acesse: http://localhost:30080
```

### 💡 Escolha Baseada em Seu Objetivo

| Objetivo | Jogo Recomendado |
|----------|------------------|
| Demo/Apresentação | 🍄 Super Mario (visual impressionante!) |
| Aprendizado rápido | 🎯 2048 (mais leve) |
| Portfolio GitHub | 🍄 Super Mario (diferencial!) |
| Workshop/Treinamento | 🎯 2048 (foco nos conceitos) |
| Impressionar tech manager | 🍄 Super Mario (WOW factor) |

**Importante:** Ambos demonstram **exatamente os mesmos conceitos** de Kubernetes! A escolha é puramente por preferência visual e impacto.

---

## 🎯 Cenários de Teste

**Aplicáveis a qualquer jogo escolhido:**

1. **Deploy inicial**: Aplicação rodando com 2 réplicas
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

## ⏭️ Próximos Passos

Após completar este módulo, você estará pronto para:
- Módulo 03: Persistência e StatefulSets (em breve)
- Módulo 04: Networking Avançado e Ingress (em breve)
- Módulo 05: Monitoramento e Observabilidade (em breve)

---

**Vamos começar! 🚀**

Vá para: [Lab Completo - Deploy e Resiliência](./laboratorios/lab-completo-resiliencia.md)
