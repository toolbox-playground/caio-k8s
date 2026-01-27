# 🧪 Laboratórios Práticos - Módulo 01: Kind

Esta pasta contém laboratórios hands-on progressivos para dominar o Kind.

---

## 📚 Visão Geral dos Laboratórios

| Lab | Nome | Duração | Dificuldade | Objetivo |
|-----|------|---------|-------------|----------|
| 01 | Primeiro Cluster Kind | 30 min | ⭐☆☆☆☆ | Criar e explorar primeiro cluster |
| 02 | Cluster Multi-Node | 30 min | ⭐⭐☆☆☆ | Trabalhar com múltiplos workers |
| 03 | Cluster Ingress-Ready | 30 min | ⭐⭐☆☆☆ | Preparar para Ingress Controller |
| 04 | Múltiplos Clusters | 30 min | ⭐⭐⭐☆☆ | Gerenciar vários ambientes |

**Tempo Total**: ~2 horas

---

## 🎯 Objetivos de Aprendizado

Ao completar todos os labs, você será capaz de:

- ✅ Instalar e configurar Kind
- ✅ Criar clusters single e multi-node
- ✅ Configurar port mapping para acesso externo
- ✅ Gerenciar múltiplos clusters simultaneamente
- ✅ Deploy e teste de aplicações
- ✅ Troubleshooting básico
- ✅ Automação com scripts

---

## 📋 Pré-requisitos Gerais

Antes de iniciar os labs, certifique-se de ter:

### Software
- ✅ Docker Desktop ou Docker Engine instalado e rodando
- ✅ PowerShell 5.1+ ou PowerShell Core
- ✅ kubectl instalado (será configurado pelo Kind)

### Recursos Mínimos
- **CPU**: 2 cores
- **RAM**: 4GB disponível
- **Disco**: 10GB livre
- **Internet**: Para download de imagens

### Verificação

```powershell
# Docker rodando
docker version
docker ps

# PowerShell version
$PSVersionTable.PSVersion

# Espaço em disco
Get-PSDrive C | Select-Object Used,Free
```

---

## 🗺️ Roadmap de Aprendizado

### Trilha Iniciante (Lab 01 apenas)
**Tempo**: 30 minutos  
**Para**: Quem nunca usou Kubernetes

Foco: Entender conceitos básicos e ter primeira experiência com K8s

### Trilha Desenvolvedor (Labs 01, 02, 04)
**Tempo**: 90 minutos  
**Para**: Desenvolvedores que querem ambiente local

Foco: Setup de ambiente de desenvolvimento com Kind

### Trilha Completa (Labs 01-04)
**Tempo**: 2 horas  
**Para**: DevOps, SREs, estudantes do curso completo

Foco: Domínio completo do Kind para todos os módulos seguintes

---

## 📖 Descrição dos Laboratórios

### 🥇 Lab 01: Primeiro Cluster Kind

**Arquivo**: [lab-01-primeiro-cluster.md](./lab-01-primeiro-cluster.md)

**O que você fará**:
1. Instalar Kind no seu sistema operacional
2. Criar primeiro cluster single-node
3. Explorar componentes do cluster
4. Deploy de aplicação Nginx de teste
5. Acessar aplicação via port-forward
6. Verificar logs e eventos
7. Limpar recursos

**Conceitos Aprendidos**:
- Instalação de ferramentas
- Criação de cluster básico
- kubectl fundamentals
- Port forwarding
- Cleanup de recursos

---

### 🥈 Lab 02: Cluster Multi-Node

**Arquivo**: [lab-02-multi-node.md](./lab-02-multi-node.md)

**O que você fará**:
1. Criar arquivo de configuração YAML
2. Deploy cluster com 1 control-plane + 2 workers
3. Verificar distribuição de pods entre nodes
4. Testar scheduling e node affinity
5. Simular falha de node
6. Observar rescheduling automático
7. Escalar aplicação

**Conceitos Aprendidos**:
- Configuração declarativa
- Arquitetura multi-node
- Kubernetes scheduling
- High availability básica
- Node management

---

### 🥉 Lab 03: Cluster Ingress-Ready

**Arquivo**: [lab-03-ingress-ready.md](./lab-03-ingress-ready.md)

**O que você fará**:
1. Criar config com port mapping
2. Expor portas 80 e 443 do host
3. Verificar mapeamento de portas
4. Preparar para Nginx Ingress
5. Testar acesso via localhost
6. Entender networking

**Conceitos Aprendidos**:
- Port mapping
- Extra port mappings
- Preparação para Ingress
- Networking Docker/Kind
- Host access

---

### 🏆 Lab 04: Múltiplos Clusters

**Arquivo**: [lab-04-multiplos-clusters.md](./lab-04-multiplos-clusters.md)

**O que você fará**:
1. Criar 3 clusters: dev, staging, prod
2. Gerenciar contextos kubectl
3. Deploy diferentes apps em cada ambiente
4. Praticar switching entre clusters
5. Simular pipeline de promoção
6. Cleanup seletivo

**Conceitos Aprendidos**:
- Múltiplos ambientes
- Contextos kubectl
- Environment management
- Workflow de desenvolvimento
- Organizaçãode clusters

---

## ⚡ Quick Start

### Executar Todos os Labs em Sequência

```powershell
# Lab 01
cd laboratorios
Get-Content lab-01-primeiro-cluster.md | Select-String "```powershell" -Context 0,10

# Lab 02
Get-Content lab-02-multi-node.md | Select-String "```powershell" -Context 0,10

# Lab 03
Get-Content lab-03-ingress-ready.md | Select-String "```powershell" -Context 0,10

# Lab 04
Get-Content lab-04-multiplos-clusters.md | Select-String "```powershell" -Context 0,10
```

### Verificar Progresso

```powershell
# Ver clusters ativos
kind get clusters

# Ver contextos kubectl
kubectl config get-contexts

# Ver todos os nodes
kind get nodes --name dev
kind get nodes --name staging
kind get nodes --name prod
```

---

## 🔧 Troubleshooting dos Labs

### Problema: Docker não está rodando

```powershell
# Windows
# Abrir Docker Desktop manualmente

# Linux
sudo systemctl start docker
sudo systemctl status docker

# Verificar
docker ps
```

### Problema: Kind não encontrado

```powershell
# Reinstalar
choco install kind

# Ou download manual
curl.exe -Lo kind.exe https://kind.sigs.k8s.io/dl/v0.20.0/kind-windows-amd64.exe
Move-Item kind.exe C:\Windows\System32\

# Verificar PATH
$env:PATH -split ";" | Select-String "System32"
```

### Problema: Cluster não inicia

```powershell
# Limpar e tentar novamente
kind delete cluster --name <nome>
kind create cluster --name <nome> --verbosity=3

# Ver logs detalhados
docker logs <container-name>
```

### Problema: Sem recursos suficientes

```powershell
# Ver uso atual
docker stats --no-stream

# Liberar recursos
kind delete cluster --name <cluster-desnecessario>
docker system prune -a

# Ajustar Docker Desktop
# Settings > Resources > Aumentar RAM e CPU
```

---

## 📊 Checklist de Progresso

Marque conforme completa:

### Lab 01: Primeiro Cluster
- [ ] Kind instalado
- [ ] Cluster criado com sucesso
- [ ] Nginx deployado
- [ ] Acesso via port-forward funcionando
- [ ] Cluster deletado e limpo

### Lab 02: Multi-Node
- [ ] Config YAML criado
- [ ] Cluster multi-node funcionando
- [ ] Pods distribuídos entre workers
- [ ] Teste de falha realizado
- [ ] Rescheduling observado

### Lab 03: Ingress-Ready
- [ ] Port mapping configurado
- [ ] Portas 80/443 acessíveis
- [ ] Networking compreendido
- [ ] Preparado para Módulo 02

### Lab 04: Múltiplos Clusters
- [ ] 3 clusters criados
- [ ] Contextos gerenciados
- [ ] Switch entre ambientes dominado
- [ ] Workflow de promoção testado

---

## 🎓 Certificado de Conclusão

Ao completar todos os 4 labs, você terá:

✅ **Conhecimento Prático de Kind**
- Criação de clusters variados
- Configuração declarativa
- Gerenciamento de ambientes

✅ **Fundamentos Kubernetes**
- Deployments básicos
- Services e networking
- Troubleshooting

✅ **Preparação para Módulos Avançados**
- Base sólida para networking
- Ambiente pronto para monitoring
- Clusters preparados para GitOps

---

## 📚 Recursos Adicionais

### Durante os Labs
- [Kind Official Docs](https://kind.sigs.k8s.io/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Docker CLI Reference](https://docs.docker.com/engine/reference/commandline/cli/)

### Após os Labs
- **Módulo 02**: Networking avançado
- **Módulo 03**: Observabilidade
- **Projetos**: Aplicar conhecimento em apps reais

---

## 💡 Dicas de Estudo

1. **Não pule labs**: Cada um constrói sobre o anterior
2. **Experimente**: Mude configurações e veja o resultado
3. **Quebre coisas**: Force erros para aprender troubleshooting
4. **Documente**: Anote comandos úteis e descobertas
5. **Pratique**: Recrie clusters várias vezes até dominar

---

## 🆘 Suporte

Se encontrar problemas:

1. Consulte a seção **Troubleshooting** acima
2. Revise o [CHEATSHEET.md](../CHEATSHEET.md)
3. Consulte a [documentação oficial do Kind](https://kind.sigs.k8s.io/)
4. Verifique [Issues no GitHub do Kind](https://github.com/kubernetes-sigs/kind/issues)

---

**Bons estudos! Agora vá para o [Lab 01](./lab-01-primeiro-cluster.md)! 🚀**