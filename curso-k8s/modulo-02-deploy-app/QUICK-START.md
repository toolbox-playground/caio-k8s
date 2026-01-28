# 🎉 Módulo 02 - Guia de Início Rápido

## ✨ O que foi criado

Um curso completo sobre **Deploy de Aplicações e Resiliência no Kubernetes** com:

### 📚 Conteúdo Educacional
- ✅ README principal com conceitos de auto-healing e auto-scaling
- ✅ Laboratório hands-on completo (1h15min)
- ✅ Documentação detalhada dos manifestos
- ✅ Guia completo dos scripts de automação
- ✅ Boas práticas com port-forward

### 🔧 Recursos Práticos
- ✅ Manifestos Kubernetes para Super Mario
- ✅ Scripts PowerShell de automação
- ✅ Configuração completa de metrics server
- ✅ HPA (Horizontal Pod Autoscaler)

---

## 🚀 Como Usar

### Opção 1: Execução Rápida com Super Mario (15 minutos) 🍄

```powershell
# Navegue até a pasta de scripts
cd curso-k8s\modulo-02-deploy-app\scripts

# 1. Criar cluster (3-5 min)
.\setup-cluster.ps1

# 2. Deploy do Super Mario
kubectl create namespace games
kubectl apply -f ..\manifests\01-deployment-mario.yaml
kubectl apply -f ..\manifests\02-service-mario.yaml
kubectl apply -f ..\manifests\03-hpa.yaml

# 3. Acessar via port-forward (boas práticas!)
kubectl port-forward -n games service/super-mario-service 8080:80

# 4. Abrir no navegador
Start-Process "http://localhost:8080"

# Em outro terminal:
# 5. Testar auto-healing (2-3 min)
.\test-autoheal.ps1

# 6. Testar auto-scaling (5-10 min)
.\load-test.ps1
```

### Opção 2: Laboratório Completo (1h15min)

```powershell
# Abra o laboratório hands-on
cd curso-k8s\modulo-02-deploy-app\laboratorios
code lab-completo-resiliencia.md

# Siga passo a passo:
# 1. Setup do Cluster (15 min)
# 2. Deploy da Aplicação (15 min)
# 3. Testar Auto-Healing (15 min)
# 4. Configurar Auto-Scaling (15 min)
# 5. Testar Auto-Scaling (15 min)
```

---

## 📁 Estrutura de Arquivos

```
curso-k8s/modulo-02-deploy-app/
├── README.md                          # Visão geral e conceitos
├── laboratorios/
│   └── lab-completo-resiliencia.md   # Lab hands-on passo-a-passo
├── manifests/
│   ├── 01-deployment-mario.yaml       # Deployment do Super Mario
│   ├── 02-service-mario.yaml          # Service ClusterIP
│   ├── 03-hpa.yaml                    # Horizontal Pod Autoscaler
│   └── README.md                      # Documentação dos manifestos
└── scripts/
    ├── setup-cluster.ps1              # Cria cluster + metrics server
    ├── deploy-app.ps1                 # Deploy completo da app
    ├── test-autoheal.ps1              # Testa auto-healing
    ├── load-test.ps1                  # Gera carga para HPA
    └── README.md                      # Guia dos scripts
```

---

## 🎯 O que Você Vai Aprender

### Conceitos-Chave

1. **Deployments** - Gerenciamento declarativo de aplicações
2. **Services** - Discovery e load balancing de pods
3. **Auto-Healing** - Recuperação automática de falhas
4. **Auto-Scaling** - Ajuste automático de réplicas (HPA)
5. **Metrics** - Coleta e uso de métricas para scaling

### Habilidades Práticas

- ✅ Deploy de aplicações containerizadas
- ✅ Exposição de serviços via NodePort
- ✅ Configuração de health checks
- ✅ Setup de Metrics Server
- ✅ Configuração de HPA
- ✅ Testes de resiliência
- ✅ Monitoramento de métricas

---

## 🎮 Aplicação de Demonstração

**Super Mario** - O clássico jogo que todo mundo conhece!

### Por que Super Mario?

- ✅ Interface web visual (você pode realmente jogar!)
- ✅ WOW factor para demos e apresentações
- ✅ Stateless (perfeito para demonstrar resiliência)
- ✅ Fácil de gerar carga
- ✅ Múltiplas réplicas funcionam perfeitamente
- ✅ Acesso via port-forward (boas práticas)

### Cenários Demonstrados

1. **Deploy Inicial**: 2 réplicas rodando
2. **Port-Forward**: Acesso seguro ao serviço
3. **Auto-Healing**: Deletar pod → recuperação automática em ~10s
4. **High Load**: Gerar carga → HPA escala de 2 para 6-10 pods
5. **Scale Down**: Remover carga → HPA reduz para 2 pods gradualmente

---

## 📊 Recursos de Aprendizado

### Documentação Incluída

| Arquivo | Conteúdo |
|---------|----------|
| [README.md](README.md) | Conceitos, arquitetura, guia do módulo |
| [lab-completo-resiliencia.md](laboratorios/lab-completo-resiliencia.md) | Lab passo-a-passo de 1h15min |
| [manifests/README.md](manifests/README.md) | Explicação detalhada dos YAMLs |
| [scripts/README.md](scripts/README.md) | Guia completo dos scripts |

### Scripts de Automação

| Script | Função | Tempo |
|--------|--------|-------|
| `setup-cluster.ps1` | Cria cluster + metrics server | 3-5 min |
| `deploy-app.ps1` | Deploy completo | 1-2 min |
| `test-autoheal.ps1` | Demonstra auto-healing | 2-3 min |
| `load-test.ps1` | Testa auto-scaling | 5-10 min |

---

## 🔍 Monitoramento Durante os Testes

### Terminais Recomendados

Abra 3 terminais para observar em tempo real:

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

---

## 🧪 Testes Incluídos

### Teste de Auto-Healing

**O que faz:**
- Deleta pods aleatoriamente
- Mede tempo de recuperação
- Valida que estado desejado é restaurado

**Resultado esperado:**
- Pod deletado → novo pod criado em ~10s
- Zero downtime (Service continua funcionando)

### Teste de Auto-Scaling

**O que faz:**
- Cria 5 pods geradores de carga (wget loop)
- Monitora CPU e scaling
- Aguarda 5 minutos
- Para carga e observa scale down

**Resultado esperado:**
```
Tempo 0s:   2 pods @ 5% CPU
Tempo 30s:  2 pods @ 80% CPU → HPA detecta
Tempo 45s:  4 pods @ 50% CPU → Scaled up
Tempo 60s:  6-8 pods @ 40% CPU → Scaled up novamente
Tempo 300s: Carga removida
Tempo 360s: 4 pods → Scale down gradual
Tempo 420s: 2 pods → Voltou ao mínimo
```

---

## 💡 Dicas de Uso

### Para Demonstrações (10-15 min)

```powershell
# Setup rápido
.\setup-cluster.ps1
.\deploy-app.ps1

# Abrir no navegador e jogar
Start-Process "http://localhost:30080"

# Demonstrar auto-healing
kubectl delete pod -n games $(kubectl get pods -n games -o name | Select-Object -First 1)
kubectl get pods -n games --watch
```

### Para Workshops/Treinamento (1 hora)

Siga o laboratório completo em:
[laboratorios/lab-completo-resiliencia.md](laboratorios/lab-completo-resiliencia.md)

### Para Experimentação

```powershell
# Modificar manifestos
code manifests\03-hpa.yaml
# Alterar minReplicas, maxReplicas, averageUtilization

# Redeploy
kubectl apply -f manifests\03-hpa.yaml

# Testar mudanças
.\load-test.ps1 -LoadGenerators 10
```

---

## 🧹 Limpeza

### Remover aplicação, manter cluster

```powershell
kubectl delete namespace games
```

### Remover cluster completo

```powershell
kind delete cluster --name lab-resiliencia
```

---

## 📚 Próximos Passos

Após completar este módulo:

1. **Revisar conceitos**: Reconciliation loop, HPA algorithm
2. **Experimentar**: Modificar configurações e observar resultados
3. **Avançar**: Módulos futuros sobre persistência, networking, observabilidade

---

## 🤝 Contribuindo

Encontrou algo para melhorar?
- 📝 Correções de documentação
- 🐛 Bugs em scripts
- 💡 Sugestões de novos labs

Abra uma issue ou PR!

---

## 📖 Recursos Adicionais

### Documentação Oficial

- [Kubernetes Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Kubernetes Services](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Horizontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Metrics Server](https://github.com/kubernetes-sigs/metrics-server)

### Tutoriais Relacionados

- [12 Factor App](https://12factor.net/)
- [Kubernetes Patterns](https://k8spatterns.io/)
- [Production Best Practices](https://kubernetes.io/docs/setup/best-practices/)

---

## ✅ Checklist de Conclusão

Você completou o módulo quando:

- [ ] Criou cluster Kind com Metrics Server
- [ ] Fez deploy da aplicação 2048
- [ ] Acessou e jogou o 2048 no navegador
- [ ] Testou auto-healing deletando pods
- [ ] Configurou HPA
- [ ] Gerou carga e observou scale up
- [ ] Removeu carga e observou scale down
- [ ] Entendeu os conceitos de reconciliation e HPA
- [ ] Consegue explicar como funcionam os manifestos

---

<div align="center">

## 🎉 Parabéns!

Você tem tudo pronto para começar a aprender sobre **deploy e resiliência no Kubernetes**!

**Comece agora:**

```powershell
cd scripts
.\setup-cluster.ps1
```

---

**Dúvidas?** Consulte a [documentação completa](README.md) ou abra uma issue.

**Boa prática! 🚀**

</div>
