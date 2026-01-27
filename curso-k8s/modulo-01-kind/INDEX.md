# 📚 Módulo 01: Kind - Índice Completo

## 📋 Visão Geral do Módulo

Este módulo ensina a criar e gerenciar clusters Kubernetes locais usando Kind (Kubernetes in Docker), estabelecendo a base para todo o curso.

**Carga Horária Estimada**: 2-3 horas  
**Nível**: Iniciante  
**Pré-requisitos**: Docker instalado

---

## 🗂️ Estrutura do Módulo

```
modulo-01-kind/
├── README.md                # Teoria e conceitos fundamentais
├── step-by-step.md          # Guia prático com comandos
├── laboratorio.md           # Lab original (básico)
├── INDEX.md                 # Este arquivo
├── CHEATSHEET.md            # Referência rápida
│
├── laboratorios/
│   ├── README.md            # Visão geral dos labs
│   ├── lab-01-primeiro-cluster.md
│   ├── lab-02-multi-node.md
│   ├── lab-03-ingress-ready.md
│   └── lab-04-multiplos-clusters.md
│
├── manifests/
│   ├── README.md            # Documentação dos manifests
│   ├── kind-single-node.yaml
│   ├── kind-multi-node.yaml
│   ├── kind-ha-cluster.yaml
│   └── kind-ingress-ready.yaml
│
└── scripts/
    ├── README.md            # Documentação dos scripts
    ├── create-cluster.ps1
    ├── delete-cluster.ps1
    └── cluster-info.ps1
```

---

## 📖 Conteúdo do Módulo

### 1️⃣ [README.md](./README.md) - Conceitos Fundamentais

**O que você aprenderá:**
- O que é Kind e por que usar
- Arquitetura do Kind
- Vantagens vs outras soluções
- Casos de uso

**Principais Tópicos:**
- Container como Node
- Networking com Docker
- Volume Mounts
- Limitações do Kind
- Comparação com Minikube, k3d, MicroK8s

**Tempo estimado**: 30 minutos de leitura

**Diagramas incluídos:**
- Arquitetura do Kind
- Cluster Multi-Node
- Networking interno
- Volume persistence

---

### 2️⃣ [step-by-step.md](./step-by-step.md) - Guia Prático

**14 Seções práticas:**

1. **Instalação** - Windows, Linux, macOS
2. **Primeiro Cluster** - Single-node básico
3. **Cluster Customizado** - Nome e configurações
4. **Config File** - YAML configuration
5. **Cluster HA** - High availability
6. **Inspeção & Debug** - Logs e troubleshooting
7. **Versões K8s** - Diferentes versões
8. **Load Imagens** - Carregar imagens Docker
9. **Múltiplos Clusters** - Dev, staging, prod
10. **Testes** - Deploy de aplicações
11. **Configs Avançadas** - Feature gates
12. **Monitoramento** - Metrics server
13. **Troubleshooting** - Problemas comuns
14. **Limpeza** - Cleanup completo

**Tempo estimado**: 1-1.5 horas executando comandos

---

### 3️⃣ [CHEATSHEET.md](./CHEATSHEET.md) - Referência Rápida

**Conteúdo:**
- Comandos essenciais
- Patterns comuns
- Troubleshooting rápido
- Quick reference table

**Uso**: Consulta rápida durante desenvolvimento

---

## 🧪 Laboratórios Práticos

### [Lab 01: Primeiro Cluster Kind](./laboratorios/lab-01-primeiro-cluster.md)
**Objetivo**: Criar e explorar primeiro cluster

**O que você fará:**
- Instalar Kind
- Criar cluster single-node
- Explorar componentes
- Deploy de aplicação teste
- Acessar aplicação

**Duração**: 30 minutos  
**Dificuldade**: ⭐☆☆☆☆

---

### [Lab 02: Cluster Multi-Node](./laboratorios/lab-02-multi-node.md)
**Objetivo**: Criar cluster com múltiplos workers

**O que você fará:**
- Criar config YAML
- Deploy cluster 1 control-plane + 2 workers
- Verificar distribuição de pods
- Testar scheduling
- Simular falha de node

**Duração**: 30 minutos  
**Dificuldade**: ⭐⭐☆☆☆

---

### [Lab 03: Cluster Ingress-Ready](./laboratorios/lab-03-ingress-ready.md)
**Objetivo**: Preparar cluster para Ingress Controller

**O que você fará:**
- Config com port mapping
- Expor portas 80 e 443
- Preparar para Nginx Ingress
- Testar acesso externo

**Duração**: 30 minutos  
**Dificuldade**: ⭐⭐☆☆☆

---

### [Lab 04: Múltiplos Clusters](./laboratorios/lab-04-multiplos-clusters.md)
**Objetivo**: Gerenciar múltiplos ambientes

**O que você fará:**
- Criar clusters dev, staging, prod
- Gerenciar contextos kubectl
- Deploy em diferentes ambientes
- Switch entre clusters

**Duração**: 30 minutos  
**Dificuldade**: ⭐⭐⭐☆☆

---

## 📁 Manifests de Configuração

### [kind-single-node.yaml](./manifests/kind-single-node.yaml)
Configuração minimalista para desenvolvimento rápido

**Uso:**
```powershell
kind create cluster --config kind-single-node.yaml
```

---

### [kind-multi-node.yaml](./manifests/kind-multi-node.yaml)
Cluster com 1 control-plane e 2 workers

**Características:**
- Simula ambiente distribuído
- Testa scheduling
- Simula alta disponibilidade básica

---

### [kind-ha-cluster.yaml](./manifests/kind-ha-cluster.yaml)
Cluster HA completo

**Características:**
- 3 control-planes
- 3 workers
- Alta disponibilidade real
- Load balancing automático

---

### [kind-ingress-ready.yaml](./manifests/kind-ingress-ready.yaml)
Pronto para Ingress Controller

**Características:**
- Port mapping 80:30080
- Port mapping 443:30443
- Labels para Ingress
- Node selector configurado

---

## 🛠️ Scripts de Automação

### [create-cluster.ps1](./scripts/create-cluster.ps1)
**Função**: Criação automatizada de clusters

**Recursos:**
- Templates pré-configurados
- Validação de requisitos
- Logging detalhado
- Error handling

**Uso:**
```powershell
.\create-cluster.ps1 -ClusterName dev -Type multi-node
.\create-cluster.ps1 -ClusterName prod -Type ha
```

---

### [delete-cluster.ps1](./scripts/delete-cluster.ps1)
**Função**: Limpeza segura de clusters

**Recursos:**
- Confirmação antes de deletar
- Backup de configs
- Limpeza de volumes
- Relatório de espaço liberado

**Uso:**
```powershell
.\delete-cluster.ps1 -ClusterName dev
.\delete-cluster.ps1 -All -Force
```

---

### [cluster-info.ps1](./scripts/cluster-info.ps1)
**Função**: Informações detalhadas do cluster

**Recursos:**
- Status de todos os componentes
- Uso de recursos
- Listagem de pods
- Network information

**Uso:**
```powershell
.\cluster-info.ps1
.\cluster-info.ps1 -ClusterName staging -Detailed
```

---

## 🎯 Trilhas de Aprendizado

### Trilha 1: Iniciante Absoluto (1 hora)
**Para quem nunca usou Kubernetes:**

1. Ler [README.md](./README.md) seções 1-3
2. Executar [step-by-step.md](./step-by-step.md) seções 1-3
3. Completar [Lab 01](./laboratorios/lab-01-primeiro-cluster.md)

**Resultado esperado:**
- ✅ Cluster Kind funcionando
- ✅ Deploy de primeira aplicação
- ✅ Conceitos básicos compreendidos

---

### Trilha 2: Desenvolvedor (2 horas)
**Para quem conhece containers:**

1. Ler [README.md](./README.md) completo
2. Executar [step-by-step.md](./step-by-step.md) seções 1-10
3. Labs:
   - [Lab 01: Primeiro Cluster](./laboratorios/lab-01-primeiro-cluster.md)
   - [Lab 02: Multi-Node](./laboratorios/lab-02-multi-node.md)
   - [Lab 04: Múltiplos Clusters](./laboratorios/lab-04-multiplos-clusters.md)

**Resultado esperado:**
- ✅ Clusters multi-node
- ✅ Gerenciar múltiplos ambientes
- ✅ Deploy e teste de aplicações

---

### Trilha 3: DevOps/SRE (3 horas)
**Para preparação profissional:**

1. [README.md](./README.md) + comparações
2. [step-by-step.md](./step-by-step.md) completo
3. Todos os 4 labs
4. Experimentar todos os scripts
5. Criar configs customizadas

**Resultado esperado:**
- ✅ Automação completa
- ✅ Troubleshooting avançado
- ✅ Pronto para produção local

---

## ✅ Checklist de Progresso

### Conceitos Fundamentais
- [ ] Entender o que é Kind
- [ ] Conhecer arquitetura de containers
- [ ] Compreender networking Docker
- [ ] Entender limitações do Kind

### Habilidades Práticas
- [ ] Instalar Kind
- [ ] Criar cluster single-node
- [ ] Criar cluster multi-node
- [ ] Usar arquivos de configuração
- [ ] Carregar imagens Docker
- [ ] Deploy de aplicações
- [ ] Gerenciar múltiplos clusters
- [ ] Troubleshooting básico

### Ferramentas
- [ ] kind CLI
- [ ] kubectl básico
- [ ] Docker CLI
- [ ] Scripts de automação

---

## 🎓 Certificação de Conhecimento

Após completar este módulo, você deve ser capaz de:

### Conhecimentos Técnicos
1. Explicar como Kind funciona
2. Criar clusters de diferentes tipos
3. Configurar networking básico
4. Gerenciar múltiplos ambientes
5. Troubleshooting de problemas comuns

### Habilidades Práticas
1. Setup completo de ambiente local
2. Deploy e teste de aplicações
3. Gerenciamento de clusters
4. Automação com scripts
5. Limpeza e manutenção

---

## 🚀 Próximos Passos

Após dominar este módulo:

1. **Módulo 02 - Networking**: Implementar CNI, MetalLB e Ingress
2. **Módulo 03 - Monitoring**: Observabilidade com Prometheus
3. **Explorar**: Testar diferentes configurações

---

## 📚 Recursos Complementares

### Documentação
- [Kind Official Docs](https://kind.sigs.k8s.io/)
- [Kubernetes Basics](https://kubernetes.io/docs/tutorials/kubernetes-basics/)
- [Docker Documentation](https://docs.docker.com/)

### Ferramentas Relacionadas
- **Minikube**: VM-based local Kubernetes
- **k3d**: K3s in Docker (similar ao Kind)
- **MicroK8s**: Lightweight Kubernetes

### Comunidade
- [Kind GitHub](https://github.com/kubernetes-sigs/kind)
- [Kubernetes Slack](https://slack.k8s.io/)
- [CNCF Community](https://www.cncf.io/community/)

---

## 📊 Estatísticas do Módulo

- **Arquivos de documentação**: 5
- **Laboratórios práticos**: 4
- **Manifests YAML**: 4
- **Scripts PowerShell**: 3
- **Comandos práticos**: 100+
- **Tempo total estimado**: 2-3 horas

---

## 💡 Dicas de Estudo

1. **Prática**: Execute todos os comandos
2. **Experimentação**: Mude configurações e veja o resultado
3. **Troubleshooting**: Force erros para aprender a corrigir
4. **Documentação**: Mantenha notes do que aprender
5. **Comunidade**: Compartilhe dúvidas e descobertas

---

**Bom estudo e divirta-se com Kind! 🐳**