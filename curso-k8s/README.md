# 🎓 Curso Kubernetes na Prática

Bem-vindo ao curso completo de Kubernetes com abordagem 100% hands-on!

## 📚 Estrutura do Curso

```
curso-k8s/
├── modulo-00-docker.md        # Fundamentos de Docker (pré-requisito)
├── modulo-01-kind/            # Clusters Kubernetes locais
└── modulo-02-deploy-app/      # Deploy e Resiliência ⭐ NOVO!
```

## 🗺️ Trilha de Aprendizado

### 1️⃣ Módulo 00: Fundamentos Docker
**Pré-requisito** | **~1 hora**

Se você nunca trabalhou com Docker, comece aqui.

📖 [Acessar módulo](./modulo-00-docker/)

---

### 2️⃣ Módulo 01: Cluster Local com Kind
**Iniciante** | **~2 horas** | **4 labs práticos**

Aprenda a criar e gerenciar clusters Kubernetes locais.

📖 [Acessar módulo](./modulo-01-kind/)

**Labs incluídos:**
- Lab 01: Primeiro Cluster
- Lab 02: Cluster Multi-Node
- Lab 03: Cluster Ingress-Ready
- Lab 04: Múltiplos Clusters

---

### 3️⃣ Módulo 02: Deploy e Resiliência ⭐
**Intermediário** | **~1h15min** | **Super Mario + 2048**

**O módulo que vai fazer seus olhos brilharem!** 🤩

Faça deploy de jogos reais (Super Mario ou 2048) e teste:
- ✅ Auto-healing (pods se recuperam sozinhos)
- ✅ Auto-scaling (HPA ajusta réplicas automaticamente)
- ✅ Load balancing (tráfego distribuído)
- ✅ Métricas em tempo real

📖 [Acessar módulo](./modulo-02-deploy-app/)

**Início rápido:**
```powershell
cd modulo-02-deploy-app/scripts
.\setup-cluster.ps1
.\deploy-app.ps1
Start-Process "http://localhost:30080"
```

---

## 🎯 Para Quem É Este Curso?

### 👨‍🎓 Estudantes de DevOps
- Portfolio com projetos reais
- Habilidades práticas para entrevistas
- Aprendizado através de jogos

### 👔 Tech Managers
- Entenda como escalar serviços
- Veja resiliência na prática
- Tome decisões informadas

### 🔧 Engenheiros
- Domine Kubernetes hands-on
- Aprenda boas práticas
- Experimente sem custos de cloud

---

## 🚀 Como Começar

### Caminho Completo (Recomendado)
```powershell
# 1. Docker basics (se necessário)
cd modulo-00-docker

# 2. Kubernetes fundamentals
cd ..\modulo-01-kind

# 3. Deploy e resiliência
cd ..\modulo-02-deploy-app
```

### Caminho Rápido (Se já conhece K8s)
```powershell
# Vá direto para o melhor!
cd modulo-02-deploy-app
cat QUICK-START.md
```

---

## 📊 Progresso

- ✅ Módulo 00: Docker Fundamentals
- ✅ Módulo 01: Kind (4 labs)
- ✅ Módulo 02: Deploy + Resiliência (2 jogos!)
- 🔄 Módulo 03: Persistência (em breve)
- 🔄 Módulo 04: Networking (em breve)

---

## 🎮 Aplicações de Demonstração

### Super Mario 🍄
- **Porta:** 30090
- **WOW Factor:** ⭐⭐⭐⭐⭐
- **Ideal para:** Demos, apresentações, portfolio

### Jogo 2048 🎯
- **Porta:** 30080
- **Leveza:** ⭐⭐⭐⭐⭐
- **Ideal para:** Aprendizado, testes rápidos

**Ambos demonstram os mesmos conceitos de Kubernetes!**

---

## 💡 Filosofia do Curso

> "Aprender Kubernetes não precisa ser chato. Quando você vê o Super Mario rodando em múltiplos pods, se recuperando de falhas automaticamente, e escalando sob carga... você **entende** de verdade."

**Nossos princípios:**
1. 🎯 **Prática > Teoria**: Faça primeiro, entenda depois
2. 🎮 **Diversão + Aprendizado**: Jogos tornam conceitos memoráveis
3. 💻 **100% Local**: Sem custos de cloud, sem dependências externas
4. 📈 **Progressivo**: Do básico ao avançado naturalmente

---

## 🤝 Contribua

Quer melhorar o curso?
- 🐛 Reportar bugs
- 💡 Sugerir melhorias
- 📝 Corrigir documentação
- 🎮 Adicionar novos jogos

---

## 📚 Recursos Adicionais

- [Documentação Oficial Kubernetes](https://kubernetes.io/)
- [Kind Documentation](https://kind.sigs.k8s.io/)
- [Kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

---

<div align="center">

## 🎉 Pronto para Começar?

**Escolha seu módulo:**

[📖 Módulo 00](./modulo-00-docker/) | [🐳 Módulo 01](./modulo-01-kind/) | [🎮 Módulo 02](./modulo-02-deploy-app/)

---

**Feito com ❤️ para quem quer aprender Kubernetes de verdade**

</div>
