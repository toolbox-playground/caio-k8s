# 🥇 Lab 01: Primeiro Cluster Kind

**Duração**: 30 minutos  
**Dificuldade**: ⭐☆☆☆☆  
**Objetivo**: Criar e explorar seu primeiro cluster Kubernetes com Kind

---

## 📋 Pré-requisitos

- ✅ Docker Desktop ou Docker Engine instalado e rodando
- ✅ PowerShell 5.1+ ou PowerShell Core
- ✅ 2GB RAM disponível
- ✅ 5GB espaço em disco

### Verificação

```powershell
# Docker rodando
docker version
docker ps

# PowerShell
$PSVersionTable.PSVersion

# Recursos
docker info | Select-String "CPUs", "Total Memory"
```

---

## 🎯 Objetivos de Aprendizado

Ao final deste lab, você será capaz de:

- ✅ Instalar Kind no seu sistema operacional
- ✅ Criar um cluster Kubernetes single-node
- ✅ Explorar componentes básicos do cluster
- ✅ Fazer deploy de uma aplicação simples
- ✅ Acessar a aplicação via port-forward
- ✅ Verificar logs e eventos
- ✅ Limpar recursos adequadamente

---

## 📖 Parte 1: Instalação do Kind

### Windows (PowerShell como Administrador)

```powershell
# Método 1: Usando Chocolatey (recomendado)
choco install kind

# Método 2: Download manual (PowerShell)
curl.exe -Lo kind-windows-amd64.exe https://kind.sigs.k8s.io/dl/v0.31.0/kind-windows-amd64
Move-Item .\kind-windows-amd64.exe c:\some-dir-in-your-PATH\kind.exe

# Verificar instalação
kind version
```

### Linux/WSL

```bash
# Download e instalação
# For AMD64 / x86_64
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.31.0/kind-linux-amd64
# For ARM64
[ $(uname -m) = aarch64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.31.0/kind-linux-arm64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Verificar
kind version
```

### macOS

```bash
# Usando Homebrew
brew install kind

# Ou download manual
# For Intel Macs
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.31.0/kind-darwin-amd64
# For M1 / ARM Macs
[ $(uname -m) = arm64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.31.0/kind-darwin-arm64
chmod +x ./kind
mv ./kind /some-dir-in-your-PATH/kind

# Verificar
kind version
```

---

## 🚀 Parte 2: Criar Primeiro Cluster

### Passo 1: Criar Cluster Padrão

```powershell
# Criar cluster com nome padrão "kind"
kind create cluster

# Aguarde aproximadamente 1-2 minutos
```

**Saída esperada:**
```
Creating cluster "kind" ...
 ✓ Ensuring node image (kindest/node:v1.27.3) 🖼
 ✓ Preparing nodes 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing CNI 🔌
 ✓ Installing StorageClass 💾
Set kubectl context to "kind-kind"
You can now use your cluster with:

kubectl cluster-info --context kind-kind

Thanks for using kind! 😊
```

### Passo 2: Verificar Cluster Criado

```powershell
# Listar clusters Kind
kind get clusters

# Verificar nodes Kubernetes
kubectl get nodes

# Ver containers Docker (o "node" é um container)
docker ps
```

**Saída esperada de `kubectl get nodes`:**
```
NAME                 STATUS   ROLES           AGE   VERSION
kind-control-plane   Ready    control-plane   1m    v1.27.3
```

---

## 🔍 Parte 3: Explorar o Cluster

### Passo 3: Verificar Contexto kubectl

```powershell
# Ver contextos disponíveis
kubectl config get-contexts

# Ver contexto atual (deve ser kind-kind)
kubectl config current-context

# Informações do cluster
kubectl cluster-info
```

### Passo 4: Explorar Componentes do Sistema

```powershell
# Ver todos os namespaces
kubectl get namespaces

# Ver pods do sistema
kubectl get pods -n kube-system

# Ver services do sistema
kubectl get services -n kube-system

# Ver todos os recursos
kubectl get all -A
```

**💡 Dica:** Os pods em `kube-system` são componentes essenciais do Kubernetes:
- `kube-apiserver`: API do Kubernetes
- `etcd`: Banco de dados do cluster
- `kube-scheduler`: Agendador de pods
- `kube-controller-manager`: Controladores
- `coredns`: DNS interno
- `kindnet`: CNI para networking

### Passo 5: Inspecionar Node Detalhadamente

```powershell
# Informações detalhadas do node
kubectl describe node kind-control-plane

# Ver labels do node
kubectl get node kind-control-plane --show-labels

# Ver recursos alocáveis
kubectl get node kind-control-plane -o json | ConvertFrom-Json | Select-Object -ExpandProperty status | Select-Object -ExpandProperty allocatable
```

---

## 🎨 Parte 4: Deploy de Aplicação Teste

### Passo 6: Criar Deployment Nginx

```powershell
# Criar deployment do nginx
kubectl create deployment nginx --image=nginx:alpine

# Verificar deployment
kubectl get deployments

# Ver pods criados
kubectl get pods

# Aguardar pod ficar Ready
kubectl wait --for=condition=ready pod -l app=nginx --timeout=120s
```

**Saída esperada:**
```
NAME    READY   UP-TO-DATE   AVAILABLE   AGE
nginx   1/1     1            1           30s
```

### Passo 7: Inspecionar o Pod

```powershell
# Detalhes do pod
kubectl get pods -l app=nginx -o wide

# Descrever pod
kubectl describe pod -l app=nginx

# Ver logs do nginx
kubectl logs -l app=nginx

# Ver eventos
kubectl get events --sort-by='.lastTimestamp' | Select-Object -Last 10
```

---

## 🌐 Parte 5: Expor e Acessar Aplicação

### Passo 8: Criar Service

```powershell
# Expor deployment como NodePort
kubectl expose deployment nginx --port=80 --type=NodePort

# Ver service criado
kubectl get service nginx

# Ver detalhes do service
kubectl describe service nginx
```

### Passo 9: Acessar via Port-Forward

```powershell
# Port-forward para acessar localmente
kubectl port-forward service/nginx 8080:80

# Em outro terminal ou navegador, acesse:
# http://localhost:8080
```

**💡 Para parar o port-forward, pressione `Ctrl+C`**

### Alternativa: Usando kubectl proxy

```powershell
# Iniciar proxy
kubectl proxy

# Acessar via:
# http://localhost:8001/api/v1/namespaces/default/services/nginx:80/proxy/
```

---

## 📊 Parte 6: Escalar Aplicação

### Passo 10: Escalar Deployment

```powershell
# Escalar para 3 réplicas
kubectl scale deployment nginx --replicas=3

# Ver pods sendo criados
kubectl get pods -l app=nginx -w  # Ctrl+C para sair

# Ver distribuição de pods
kubectl get pods -l app=nginx -o wide
```

**💡 Observação:** Em um cluster single-node, todos os pods rodam no mesmo node.

### Passo 11: Testar Alta Disponibilidade

```powershell
# Deletar um pod
$podName = kubectl get pods -l app=nginx -o jsonpath='{.items[0].metadata.name}'
kubectl delete pod $podName

# Ver novo pod sendo criado automaticamente
kubectl get pods -l app=nginx -w
```

---

## 🔧 Parte 7: Troubleshooting e Logs

### Passo 12: Ver Logs e Eventos

```powershell
# Logs de todos os pods nginx
kubectl logs -l app=nginx --all-containers=true

# Logs em tempo real (follow)
kubectl logs -l app=nginx -f

# Ver eventos do namespace
kubectl get events --sort-by='.lastTimestamp'

# Eventos de um pod específico
kubectl describe pod -l app=nginx | Select-String "Events:" -Context 0,10
```

### Passo 13: Executar Comandos no Container

```powershell
# Exec no pod
$podName = kubectl get pods -l app=nginx -o jsonpath='{.items[0].metadata.name}'
kubectl exec -it $podName -- /bin/sh

# Dentro do container:
# hostname
# nginx -v
# ps aux
# exit
```

---

## 🧪 Parte 8: Testes Avançados

### Passo 14: Testar DNS e Conectividade

```powershell
# Criar pod de teste (busybox)
kubectl run busybox --image=busybox:latest --restart=Never -- sleep 3600

# Aguardar pod ficar pronto
kubectl wait --for=condition=ready pod/busybox --timeout=60s

# Testar DNS do service
kubectl exec busybox -- nslookup nginx

# Testar conectividade HTTP
kubectl exec busybox -- wget -O- http://nginx

# Ver IP do service
kubectl get service nginx -o jsonpath='{.spec.clusterIP}'

# Testar via ClusterIP
$serviceIP = kubectl get service nginx -o jsonpath='{.spec.clusterIP}'
kubectl exec busybox -- wget -O- http://${serviceIP}
```

---

## 🧹 Parte 9: Limpeza

### Passo 15: Limpar Recursos

```powershell
# Deletar deployment e service
kubectl delete deployment nginx
kubectl delete service nginx

# Deletar pod de teste
kubectl delete pod busybox

# Verificar limpeza
kubectl get all
```

### Passo 16: Deletar Cluster

```powershell
# Deletar cluster Kind
kind delete cluster

# Verificar que foi deletado
kind get clusters
docker ps
```

---

## ✅ Checklist de Conclusão

Marque o que você completou:

- [ ] Kind instalado com sucesso
- [ ] Cluster criado e verificado
- [ ] Componentes do sistema explorados
- [ ] Nginx deployado
- [ ] Aplicação acessada via port-forward
- [ ] Deployment escalado
- [ ] Logs e eventos verificados
- [ ] DNS testado
- [ ] Recursos limpos
- [ ] Cluster deletado

---

## 🎓 O Que Você Aprendeu

Neste laboratório, você:

1. **Instalou** Kind no seu sistema
2. **Criou** seu primeiro cluster Kubernetes
3. **Explorou** componentes básicos do K8s
4. **Deployou** uma aplicação web
5. **Expôs** a aplicação com Service
6. **Escalou** deployment para múltiplas réplicas
7. **Testou** DNS e conectividade interna
8. **Troubleshooting** com logs e eventos
9. **Limpou** recursos adequadamente

---

## 🚀 Próximos Passos

Agora que você dominou o básico, continue para:

- **[Lab 02: Cluster Multi-Node](./lab-02-multi-node.md)** - Trabalhar com múltiplos workers
- **[Lab 03: Ingress-Ready](./lab-03-ingress-ready.md)** - Preparar para Ingress Controller
- **Experimentar**: Tente deployar outras aplicações (redis, postgres, etc.)

---

## 💡 Dicas e Truques

### Atalhos Úteis

```powershell
# Alias para kubectl (opcional)
Set-Alias -Name k -Value kubectl

# Ver todos os recursos
k get all -A

# Descrever rapidamente
k describe pod <nome>

# Logs rápidos
k logs -f <pod-name>
```

### Troubleshooting Comum

**Pod não inicia:**
```powershell
kubectl describe pod <pod-name>
kubectl logs <pod-name>
kubectl get events
```

**Cluster não cria:**
```powershell
# Verificar Docker
docker ps
docker info

# Recriar
kind delete cluster
kind create cluster --verbosity=3
```

---

## 📚 Recursos Complementares

- [Kind Quick Start](https://kind.sigs.k8s.io/docs/user/quick-start/)
- [Kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Kubernetes Basics Tutorial](https://kubernetes.io/docs/tutorials/kubernetes-basics/)

---

**🎉 Parabéns por completar o Lab 01!**

Você agora tem uma base sólida em Kind e Kubernetes. Continue praticando e explorando!
