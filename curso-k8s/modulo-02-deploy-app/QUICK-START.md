# 🎉 Módulo 02 - Guia de Início Rápido

## ✨ O que foi criado

Um curso completo sobre **Deploy de Aplicações e Resiliência no Kubernetes** com:

### 📚 Conteúdo Educacional
- ✅ README principal com conceitos de auto-healing e auto-scaling
- ✅ Laboratório hands-on completo (1h15min)
- ✅ Documentação detalhada dos manifestos
- ✅ Guia completo de testes de stress
- ✅ Boas práticas com port-forward

### 🔧 Recursos Práticos
- ✅ Manifestos Kubernetes para Super Mario
- ✅ Configuração completa de Metrics Server
- ✅ HPA (Horizontal Pod Autoscaler)
- ✅ Pods de stress test com Polinux

---

## 🚀 Como Usar

### Deploy Passo a Passo do Super Mario (15 minutos) 🍄

```powershell
# 1. Criar cluster (3-5 min)
kind create cluster --name k8s-essentials

# 2. Instalar Metrics Server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch para ambientes locais
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

# Aguardar estar pronto
kubectl wait --for=condition=available --timeout=120s deployment/metrics-server -n kube-system

# 3. Deploy do Super Mario
kubectl create namespace games
kubectl apply -f manifests/01-deployment-mario.yaml
kubectl apply -f manifests/02-service-mario.yaml
kubectl apply -f manifests/03-hpa.yaml

# 4. Aguardar pods ficarem prontos
kubectl wait --for=condition=ready pod -l app=super-mario -n games --timeout=120s

# 5. Acessar via port-forward (boas práticas!)
kubectl port-forward -n games service/super-mario-service 8080:8080

# Em outro terminal, abra o navegador
Start-Process "http://localhost:8080"
```

### Testar Auto-Healing (5 minutos)

```powershell
# 1. Ver pods rodando
kubectl get pods -n games

# 2. Deletar um pod
kubectl delete pod <pod-name> -n games

# 3. Observar novo pod sendo criado automaticamente
kubectl get pods -n games --watch
```

### Testar Auto-Scaling com HPA (10 minutos)

```powershell
# 1. Aplicar pod de stress test
kubectl apply -f manifests/04-stress-test-fortio.yaml

# 2. Em terminal separado, monitorar HPA
kubectl get hpa -n games --watch

# 3. Em outro terminal, monitorar pods
kubectl get pods -n games --watch

# 4. Observar pods sendo criados conforme CPU aumenta
kubectl top pods -n games

# 5. Após 10 min, limpar teste
kubectl delete -f manifests/04-stress-test-fortio.yaml
```

### Laboratório Completo (1h15min)

Para experiência completa de aprendizado:

```powershell
# Abrir o laboratório hands-on
code laboratorios/lab-completo-resiliencia.md

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
├── QUICK-START.md                     # Este arquivo
├── laboratorios/
│   └── lab-completo-resiliencia.md   # Lab hands-on passo-a-passo
└── manifests/
    ├── 01-deployment-mario.yaml       # Deployment do Super Mario
    ├── 02-service-mario.yaml          # Service ClusterIP
    ├── 03-hpa.yaml                    # Horizontal Pod Autoscaler
    ├── 04-stress-test-fortio.yaml     # Pods de stress test (Fortio)
    ├── README.md                      # Documentação dos manifestos
    └── STRESS-TEST-GUIDE.md          # Guia de testes de stress
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
- ✅ Exposição de serviços via port-forward (ClusterIP)
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
- ✅ Acesso via port-forward (boas práticas de produção)

### Cenários Demonstrados

1. **Deploy Inicial**: 2 réplicas rodando
2. **Port-Forward**: Acesso seguro ao serviço (método profissional)
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
| [STRESS-TEST-GUIDE.md](manifests/STRESS-TEST-GUIDE.md) | Guia completo de testes de stress |

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
kubectl top pods -n games --watch
```

---

## 🧪 Testes Manuais

### Teste de Auto-Healing

**Procedimento:**
1. Ver pods rodando: `kubectl get pods -n games`
2. Deletar um pod: `kubectl delete pod <pod-name> -n games`
3. Observar recuperação: `kubectl get pods -n games --watch`

**Resultado esperado:**
- Pod deletado → novo pod criado em ~10-30s
- Zero downtime (Service continua funcionando)
- Estado desejado é restaurado automaticamente

### Teste de Auto-Scaling

**Procedimento:**
1. Aplicar stress test: `kubectl apply -f manifests/04-stress-test-fortio.yaml`
2. Monitorar HPA: `kubectl get hpa -n games --watch`
3. Monitorar pods: `kubectl get pods -n games --watch`
4. Ver métricas: `kubectl top pods -n games`

**Timeline esperada:**
```
Tempo 0s:   2 pods @ 5% CPU (estado inicial)
Tempo 30s:  2 pods @ 70% CPU → HPA detecta necessidade
Tempo 60s:  4 pods @ 45% CPU → Scaled up
Tempo 90s:  6-8 pods @ 35% CPU → Scaled up novamente
Tempo 600s: Teste termina automaticamente (timeout)
Tempo 660s: 4 pods → Scale down gradual inicia
Tempo 720s: 2 pods → Voltou ao mínimo
```

**Limpeza:**
```powershell
kubectl delete -f manifests/04-stress-test-fortio.yaml
```

---

## 💡 Dicas de Uso

### Para Demonstrações Rápidas (10-15 min)

```powershell
# 1. Setup
kind create cluster --name k8s-demo

# 2. Metrics Server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

# 3. Deploy
kubectl create namespace games
kubectl apply -f manifests/

# 4. Port-forward em uma janela separada
kubectl port-forward -n games service/super-mario-service 8080:8080

# 5. Abrir navegador
Start-Process "http://localhost:8080"

# 6. Demonstrar auto-healing
kubectl delete pod -n games (kubectl get pods -n games -o name | Select-Object -First 1)
kubectl get pods -n games --watch
```

### Para Workshops/Treinamento (1h15min)

Siga o laboratório completo em:
📖 [laboratorios/lab-completo-resiliencia.md](laboratorios/lab-completo-resiliencia.md)

### Para Experimentação

```powershell
# Modificar configurações do HPA
code manifests/03-hpa.yaml
# Alterar: minReplicas, maxReplicas, averageUtilization

# Reaplicar
kubectl apply -f manifests/03-hpa.yaml

# Testar mudanças
kubectl apply -f manifests/04-stress-test-fortio.yaml
kubectl get hpa -n games --watch
```

---

## 🧹 Limpeza

### Remover aplicação, manter cluster

```powershell
kubectl delete namespace games
```

### Remover cluster completo

```powershell
kind delete cluster --name k8s-essentials
```

---

## 📚 Próximos Passos

Após completar este módulo:

1. **Revisar conceitos**: Reconciliation loop, HPA algorithm, ClusterIP vs NodePort
2. **Experimentar**: Modificar configurações e observar resultados
3. **Praticar**: Tentar com suas próprias aplicações
4. **Avançar**: Módulos futuros sobre persistência, networking, observabilidade

---

## 📖 Recursos Adicionais

### Documentação Oficial

- [Kubernetes Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Kubernetes Services](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Horizontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Metrics Server](https://github.com/kubernetes-sigs/metrics-server)
- [Port Forwarding](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/)

### Tutoriais Relacionados

- [12 Factor App](https://12factor.net/)
- [Kubernetes Patterns](https://k8spatterns.io/)
- [Production Best Practices](https://kubernetes.io/docs/setup/best-practices/)

---

## ✅ Checklist de Conclusão

Você completou o módulo quando:

- [ ] Criou cluster Kind com Metrics Server
- [ ] Fez deploy do Super Mario
- [ ] Acessou via port-forward (método profissional)
- [ ] Testou auto-healing deletando pods
- [ ] Configurou HPA
- [ ] Gerou carga e observou auto-scaling
- [ ] Observou scale down após remover carga
- [ ] Entendeu conceitos de resiliência e elasticidade

**🎉 Parabéns! Você dominou auto-healing e auto-scaling no Kubernetes!**
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
