# 🚀 Como Usar o Deployment Nginx

Este arquivo contém **3 opções** de deployment para nginx. Escolha a que melhor se adapta ao seu caso de uso.

---

## 📋 Pré-requisitos

```powershell
# 1. Verificar se cluster está rodando
kubectl get nodes

# 2. Carregar imagem nginx no cluster Kind
docker pull nginx:1.27
kind load docker-image nginx:1.27 --name k8s-essentials

# 3. Verificar se a imagem foi carregada
docker exec k8s-essentials-control-plane crictl images | grep nginx
```

---

## 🎯 Opções de Deployment

### **Opção 1: ClusterIP (Acesso Interno)** ⭐ Recomendado para produção

Deploy + Service interno no cluster.

```powershell
# Deploy
kubectl apply -f nginx.yaml

# Verificar
kubectl get deployments
kubectl get pods -l app=nginx
kubectl get svc nginx

# Testar (de dentro do cluster)
kubectl run -it --rm debug --image=busybox --restart=Never -- wget -qO- http://nginx

# Acessar via port-forward (para teste local)
kubectl port-forward svc/nginx 8080:80

# Em outro terminal ou navegador: http://localhost:8080
```

**Quando usar:**
- ✅ Aplicações internas
- ✅ Microserviços
- ✅ Backend APIs
- ✅ Produção

---

### **Opção 2: NodePort (Acesso Externo)** 🌐

Expõe na porta 30088 de todos os nodes.

```powershell
# O NodePort já está incluído no nginx.yaml
# Verificar
kubectl get svc nginx-nodeport

# Acessar via port-forward (NodePort não funciona diretamente no Kind)
kubectl port-forward svc/nginx-nodeport 8088:80

# Testar
curl http://localhost:8088
# Ou navegador: http://localhost:8088
```

**Quando usar:**
- ✅ Desenvolvimento local
- ✅ Testes rápidos
- ✅ Demonstrações
- ⚠️ NÃO recomendado para produção

---

### **Opção 3: HostPort (Localhost)** 🏠

Usa as portas mapeadas do cluster (80/443). Requer `extraPortMappings` configurado.

```powershell
# Descomente a seção OPCIONAL no nginx.yaml
# Depois aplique:
kubectl apply -f nginx.yaml

# Acessar diretamente
curl http://localhost
# Ou navegador: http://localhost
```

**Quando usar:**
- ✅ Testes locais rápidos
- ✅ Desenvolvimento com Ingress
- ⚠️ Apenas 1 pod pode usar a porta
- ⚠️ Requer extraPortMappings

---

## 🔍 Comandos Úteis

### Verificar Status

```powershell
# Pods
kubectl get pods -l app=nginx -o wide

# Deployments
kubectl get deployments nginx

# Services
kubectl get svc | Select-String "nginx"

# Logs
kubectl logs -l app=nginx --tail=50

# Descrever
kubectl describe deployment nginx
kubectl describe svc nginx
```

### Escalar

```powershell
# Aumentar réplicas
kubectl scale deployment nginx --replicas=5

# Verificar
kubectl get pods -l app=nginx
```

### Atualizar Imagem

```powershell
# Atualizar para nova versão
kubectl set image deployment/nginx nginx=nginx:1.27-alpine

# Verificar rollout
kubectl rollout status deployment/nginx

# Histórico
kubectl rollout history deployment/nginx

# Reverter se necessário
kubectl rollout undo deployment/nginx
```

### Debug

```powershell
# Executar bash no pod
kubectl exec -it $(kubectl get pod -l app=nginx -o name | Select-Object -First 1) -- /bin/bash

# Ver configuração do nginx
kubectl exec -it $(kubectl get pod -l app=nginx -o name | Select-Object -First 1) -- cat /etc/nginx/nginx.conf

# Testar conectividade
kubectl exec -it $(kubectl get pod -l app=nginx -o name | Select-Object -First 1) -- curl localhost
```

### Limpeza

```powershell
# Deletar tudo
kubectl delete -f nginx.yaml

# Ou individual
kubectl delete deployment nginx
kubectl delete svc nginx nginx-nodeport
kubectl delete pod nginx-hostport 2>$null
```

---

## 📊 Comparação das Opções

| Aspecto | ClusterIP | NodePort | HostPort |
|---------|-----------|----------|----------|
| **Acesso** | Interno | Porta do Node | Porta do Host |
| **Porta** | 80 | 30088 | 80 |
| **URL** | http://nginx | http://localhost:30088* | http://localhost |
| **Réplicas** | ✅ Múltiplas | ✅ Múltiplas | ❌ 1 apenas |
| **Produção** | ✅ Sim | ⚠️ Com LB | ❌ Não |
| **Facilidade** | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

\* No Kind, use `kubectl port-forward`

---

## 💡 Dicas

1. **Sempre use versões específicas** (`nginx:1.27` ❌ `nginx:latest`)
2. **Configure health checks** (já incluídos no deployment)
3. **Defina resource limits** (já incluídos)
4. **Use labels consistentes** para organização
5. **Teste antes de aplicar**: `kubectl apply -f nginx.yaml --dry-run=client`

---

## 🐛 Troubleshooting

### Pods não iniciam

```powershell
# Ver eventos
kubectl describe pod -l app=nginx

# Ver logs
kubectl logs -l app=nginx

# Problema comum: imagem não carregada
kind load docker-image nginx:1.27 --name k8s-essentials
```

### Service não responde

```powershell
# Verificar endpoints
kubectl get endpoints nginx

# Deve mostrar IPs dos pods
# Se vazio, o selector está errado
```

### HostPort não funciona

```powershell
# Verificar se cluster tem extraPortMappings
kubectl get nodes -o yaml | Select-String "extraPortMappings"

# Verificar se porta está em uso
netstat -an | Select-String ":80"

# Verificar se pod está no control-plane
kubectl get pods -l app=nginx-hostport -o wide
```

---

## 📚 Próximos Passos

Depois de dominar o deployment básico:

1. **Módulo 02**: Configure Ingress Controller
2. **HPA**: Auto-scaling automático
3. **ConfigMaps**: Configuração externa
4. **Volumes**: Persistência de dados
5. **SSL/TLS**: HTTPS com certificados

---

**🎉 Deployment criado com sucesso! Pronto para uso em desenvolvimento e produção.**
