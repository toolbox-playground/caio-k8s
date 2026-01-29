# 🥉 Lab 03: Cluster Ingress-Ready

**Duração**: 30 minutos  
**Dificuldade**: ⭐⭐☆☆☆  
**Objetivo**: Preparar cluster com port mapping para Ingress Controller

---

## 📋 Pré-requisitos

- ✅ Labs 01 e 02 completos
- ✅ Docker rodando
- ✅ Kind instalado

### Verificação

```powershell
kind version
docker ps
```

---

## 🎯 Objetivos de Aprendizado

Ao final deste lab, você será capaz de:

- ✅ Configurar port mapping no Kind
- ✅ Expor portas 80 e 443 para o host
- ✅ Verificar mapeamento de portas
- ✅ Preparar cluster para Nginx Ingress
- ✅ Testar acesso via localhost
- ✅ Entender networking Docker/Kind

---

## 📝 Parte 1: Configuração com Port Mapping

### Passo 1: Criar Config Ingress-Ready

```powershell
# Navegar para pasta
cd c:\Users\marce\Documents\personal_projects\k8s\curso\modulo-01-kind

# Criar diretório
New-Item -ItemType Directory -Path ".\temp-configs" -Force

# Criar configuração
@"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ingress-ready
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: \"ingress-ready=true\"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
- role: worker
"@ | Out-File -FilePath ".\temp-configs\kind-ingress-ready.yaml" -Encoding UTF8

# Visualizar
Get-Content ".\temp-configs\kind-ingress-ready.yaml"
```

**Linux/macOS:**
```bash
# Navegar para pasta (ajuste o caminho)
cd ~/Documents/k8s/curso/modulo-01-kind

# Criar diretório
mkdir -p ./temp-configs

# Criar configuração
cat <<'EOF' > ./temp-configs/kind-ingress-ready.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ingress-ready
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
- role: worker
EOF

# Visualizar
cat ./temp-configs/kind-ingress-ready.yaml
```

**💡 Explicação:**
- `extraPortMappings`: Mapeia portas do container para o host
- `containerPort: 80` → `hostPort: 80`: HTTP acessível em `localhost:80`
- `containerPort: 443` → `hostPort: 443`: HTTPS acessível em `localhost:443`
- `node-labels`: Label especial para Ingress Controller

> **🔔 Nota sobre Gateway API:**  
> O Kubernetes está migrando do Ingress tradicional para o [Gateway API](https://gateway-api.sigs.k8s.io/).  
> O Gateway API oferece mais flexibilidade e é recomendado para novos projetos.  
> Para migração, veja o [guia oficial](https://gateway-api.sigs.k8s.io/guides/migrating-from-ingress/).

---

## 🚀 Parte 2: Criar Cluster

### Passo 2: Deploy do Cluster

```powershell
# Limpar clusters anteriores
kind delete cluster --name ingress-ready

# Criar cluster
kind create cluster --config .\temp-configs\kind-ingress-ready.yaml

# Aguarde 2-3 minutos
```

**⚠️ IMPORTANTE - Problema com Kubernetes v1.35.0:**

Se você encontrar o erro `failed to init node with kubeadm: command "docker exec --privileged ingress-ready-control-plane kubeadm init"` ou avisos sobre API deprecated `kubeadm.k8s.io/v1beta3`, isso indica incompatibilidade com a versão mais recente do Kubernetes.

**Solução:** Use a versão estável v1.31.0 especificando a imagem do node na configuração:

```powershell
# Criar configuração com versão específica
@"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ingress-ready
nodes:
- role: control-plane
  image: kindest/node:v1.31.0@sha256:53df588e04085fd41ae12de0c3fe4c72f7013bba32a20e7325357a1ac94ba865
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: \"ingress-ready=true\"
  extraPortMappings:
  - containerPort: 30080
    hostPort: 80
    protocol: TCP
  - containerPort: 30443
    hostPort: 443
    protocol: TCP
- role: worker
  image: kindest/node:v1.31.0@sha256:53df588e04085fd41ae12de0c3fe4c72f7013bba32a20e7325357a1ac94ba865
- role: worker
  image: kindest/node:v1.31.0@sha256:53df588e04085fd41ae12de0c3fe4c72f7013bba32a20e7325357a1ac94ba865
"@ | Out-File -FilePath ".\temp-configs\kind-ingress-ready.yaml" -Encoding UTF8

# Criar cluster
kind create cluster --config .\temp-configs\kind-ingress-ready.yaml
```

**Linux/macOS:**
```bash
# Criar configuração com versão específica
cat <<'EOF' > ./temp-configs/kind-ingress-ready.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ingress-ready
nodes:
- role: control-plane
  image: kindest/node:v1.31.0@sha256:53df588e04085fd41ae12de0c3fe4c72f7013bba32a20e7325357a1ac94ba865
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 30080
    hostPort: 80
    protocol: TCP
  - containerPort: 30443
    hostPort: 443
    protocol: TCP
- role: worker
  image: kindest/node:v1.31.0@sha256:53df588e04085fd41ae12de0c3fe4c72f7013bba32a20e7325357a1ac94ba865
- role: worker
  image: kindest/node:v1.31.0@sha256:53df588e04085fd41ae12de0c3fe4c72f7013bba32a20e7325357a1ac94ba865
EOF

# Criar cluster
kind create cluster --config ./temp-configs/kind-ingress-ready.yaml
```

**📚 Explicação do Problema:**

- **Causa**: Kubernetes v1.35.0 introduziu mudanças que quebram compatibilidade com kubeadm
- **Sintoma**: Kubelet não inicia após 4 minutos, erro "connection refused" em `http://127.0.0.1:10248/healthz`
- **API Deprecated**: `kubeadm.k8s.io/v1beta3` foi marcada como deprecated, causando instabilidade
- **Solução**: Fixar versão em v1.31.0 (última versão estável testada com Kind)
- **SHA256**: O hash garante integridade da imagem baixada (segurança)

**💡 Dica:** Sempre especifique a versão da imagem em ambientes de produção para evitar surpresas!

### Passo 3: Verificar Port Mapping

```powershell
# Ver nodes
kubectl get nodes

# Ver portas mapeadas no Docker
docker port ingress-ready-control-plane

# Verificar labels do control-plane
kubectl get node ingress-ready-control-plane --show-labels | Select-String "ingress-ready"
```

**Linux/macOS:**
```bash
# Ver nodes
kubectl get nodes

# Ver portas mapeadas no Docker
docker port ingress-ready-control-plane

# Verificar labels do control-plane
kubectl get node ingress-ready-control-plane --show-labels | grep "ingress-ready"
```

**Saída esperada de `docker port`:**
```
443/tcp -> 0.0.0.0:30443
80/tcp -> 0.0.0.0:30080
6443/tcp -> 127.0.0.1:xxxxx
```

---

## 🌐 Parte 3: Deploy de Aplicação Teste

### Passo 4: Criar Deployment e Service

```powershell
# Deployment
kubectl create deployment web --image=nginx:alpine

# Escalar
kubectl scale deployment web --replicas=3

# Expor como ClusterIP
kubectl expose deployment web --port=80 --type=ClusterIP

# Verificar
kubectl get deployment,service
```

### Passo 5: Criar NodePort Service (Teste Temporário)

```powershell
# Criar NodePort manualmente
@"
apiVersion: v1
kind: Service
metadata:
  name: web-nodeport
spec:
  type: NodePort
  selector:
    app: web
  ports:
  - name: http
    port: 80
    targetPort: 80
    nodePort: 30080
    protocol: TCP
"@ | kubectl apply -f -

# Ver service
kubectl get service web-nodeport
```

**Linux/macOS:**
```bash
# Criar NodePort manualmente
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: web-nodeport
spec:
  type: NodePort
  selector:
    app: web
  ports:
  - name: http
    port: 80
    targetPort: 80
    nodePort: 30080
    protocol: TCP
EOF

# Ver service
kubectl get service web-nodeport
```

**💡 Nota:** Normalmente NodePort aloca porta aleatória 30000-32767, mas fixamos em 30080.

---

## 🧪 Parte 4: Testar Acesso Externo

### Passo 6: Testar via localhost

```powershell
# Teste HTTP
curl.exe http://localhost:30080

# Ou no navegador
Start-Process "http://localhost:30080"

# Teste com PowerShell
Invoke-WebRequest -Uri "http://localhost:30080" -UseBasicParsing
```

**Linux/macOS:**
```bash
# Teste HTTP
curl http://localhost:30080

# Ou no navegador (macOS)
open http://localhost:30080

# Ou no navegador (Linux com xdg-open)
xdg-open http://localhost:30080 2>/dev/null || echo "Abra http://localhost:30080 no navegador"
```

**Saída esperada:** Página padrão do Nginx

### Passo 7: Verificar Conectividade de Outro Pod

```powershell
# Criar pod de teste
kubectl run busybox --image=busybox:latest --restart=Never -- sleep 3600

# Testar DNS interno
kubectl exec busybox -- nslookup web

# Testar conectividade interna
kubectl exec busybox -- wget -O- http://web

# Limpar
kubectl delete pod busybox
```

---

## 🔧 Parte 5: Preparar para Nginx Ingress

### Passo 8: Instalar Nginx Ingress Controller

```powershell
# Instalar via manifesto oficial
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Aguardar deployment
kubectl wait --namespace ingress-nginx `
  --for=condition=ready pod `
  --selector=app.kubernetes.io/component=controller `
  --timeout=90s

# Verificar pods
kubectl get pods -n ingress-nginx
```

### Passo 9: Ver Serviços do Ingress

```powershell
# Ver services do ingress-nginx
kubectl get services -n ingress-nginx

# Ver detalhes do controller
kubectl describe service ingress-nginx-controller -n ingress-nginx

# Ver pods do controller
kubectl get pods -n ingress-nginx -o wide
```

---

## 🎨 Parte 6: Criar Ingress Resource

### Passo 10: Deploy de Segunda Aplicação

```powershell
# App 1: web (já existe)
# App 2: app2
kubectl create deployment app2 --image=httpd:alpine
kubectl expose deployment app2 --port=80

# Verificar
kubectl get deployments,services
```

### Passo 11: Criar Ingress Resource

```powershell
# Criar Ingress
@"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: web.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web
            port:
              number: 80
  - host: app2.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app2
            port:
              number: 80
"@ | kubectl apply -f -

# Ver Ingress criado
kubectl get ingress
kubectl describe ingress example-ingress
```

**Linux/macOS:**
```bash
# Criar Ingress
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: web.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web
            port:
              number: 80
  - host: app2.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app2
            port:
              number: 80
EOF

# Ver Ingress criado
kubectl get ingress
kubectl describe ingress example-ingress
```

---

## 🌐 Parte 7: Testar Ingress

### Passo 12: Adicionar Entradas no Hosts (Opcional)

```powershell
# Windows: Editar C:\Windows\System32\drivers\etc\hosts
# Adicionar linhas:
# 127.0.0.1 web.local
# 127.0.0.1 app2.local

# Ou testar com curl passando header Host
```

### Passo 13: Testar Roteamento

```powershell
# Teste com Header Host
curl.exe -H "Host: web.local" http://localhost:30080

curl.exe -H "Host: app2.local" http://localhost:30080

# Ou com Invoke-WebRequest
$headers = @{Host = "web.local"}
Invoke-WebRequest -Uri "http://localhost:30080" -Headers $headers -UseBasicParsing

$headers = @{Host = "app2.local"}
Invoke-WebRequest -Uri "http://localhost:30080" -Headers $headers -UseBasicParsing
```

**Linux/macOS:**
```bash
# Teste com Header Host
curl -H "Host: web.local" http://localhost:30080

curl -H "Host: app2.local" http://localhost:30080
```

**Resultado esperado:** 
- `web.local` → Página Nginx
- `app2.local` → Página Apache

---

## 📊 Parte 8: Análise de Networking

### Passo 14: Inspecionar Networking

```powershell
# Ver network do Kind
docker network ls | Select-String "kind"

# Inspecionar network
docker network inspect kind | ConvertFrom-Json

# Ver IP do control-plane
docker inspect ingress-ready-control-plane | ConvertFrom-Json | Select-Object -ExpandProperty NetworkSettings | Select-Object IPAddress

# Ver pods do ingress-nginx
kubectl get pods -n ingress-nginx -o wide
```

### Passo 15: Logs do Ingress Controller

```powershell
# Ver logs do controller
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller --tail=50

# Logs em tempo real
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller -f

# Ctrl+C para parar
```

---

## 🔍 Parte 9: Troubleshooting

### Passo 16: Diagnóstico de Problemas

```powershell
# Verificar se portas estão listening
netstat -an | Select-String "30080"
netstat -an | Select-String "30443"

# Ver eventos do Ingress
kubectl get events --sort-by='.lastTimestamp' | Select-Object -Last 15

# Verificar configuração do Ingress Controller
kubectl exec -n ingress-nginx deployment/ingress-nginx-controller -- /nginx-ingress-controller --version

# Ver nginx.conf gerado
kubectl exec -n ingress-nginx deployment/ingress-nginx-controller -- cat /etc/nginx/nginx.conf | Select-String "web.local" -Context 2,2
```

---

## 🧪 Parte 10: Testes Avançados

### Passo 17: Path-Based Routing

```powershell
# Criar nova app
kubectl create deployment api --image=nginx:alpine
kubectl expose deployment api --port=80

# Ingress com paths
@"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: path-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: myapp.local
    http:
      paths:
      - path: /web
        pathType: Prefix
        backend:
          service:
            name: web
            port:
              number: 80
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api
            port:
              number: 80
"@ | kubectl apply -f -

# Testar
curl.exe -H "Host: myapp.local" http://localhost:30080/web
curl.exe -H "Host: myapp.local" http://localhost:30080/api
```

**Linux/macOS:**
```bash
# Criar nova app
kubectl create deployment api --image=nginx:alpine
kubectl expose deployment api --port=80

# Ingress com paths
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: path-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: myapp.local
    http:
      paths:
      - path: /web
        pathType: Prefix
        backend:
          service:
            name: web
            port:
              number: 80
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api
            port:
              number: 80
EOF

# Testar
curl -H "Host: myapp.local" http://localhost:30080/web
curl -H "Host: myapp.local" http://localhost:30080/api
```

### Passo 18: HTTPS/TLS (Preparação)

```powershell
# Ver se Ingress suporta TLS
kubectl describe ingress example-ingress | Select-String "TLS"

# Verificar porta 443 mapeada
docker port ingress-ready-control-plane | Select-String "443"

# Teste HTTPS (sem certificado, esperado falhar)
curl.exe -k https://localhost:30443
```

---

## 🧹 Parte 11: Limpeza

### Passo 19: Limpar Recursos

```powershell
# Deletar Ingress resources
kubectl delete ingress example-ingress path-ingress

# Deletar deployments e services
kubectl delete deployment web app2 api
kubectl delete service web web-nodeport app2 api

# Desinstalar Ingress Controller
kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Verificar
kubectl get all
kubectl get ingress
```

### Passo 20: Deletar Cluster

```powershell
# Deletar cluster
kind delete cluster --name ingress-ready

# Verificar
kind get clusters

# Limpar configs
Remove-Item -Path ".\temp-configs\kind-ingress-ready.yaml" -Force
```

---

## ✅ Checklist de Conclusão

- [ ] Config com port mapping criada
- [ ] Cluster ingress-ready deployado
- [ ] Port mapping verificado
- [ ] Acesso via localhost:30080 funcionando
- [ ] Nginx Ingress Controller instalado
- [ ] Ingress resource criado
- [ ] Host-based routing testado
- [ ] Path-based routing testado
- [ ] Logs do controller verificados
- [ ] Cluster deletado

---

## 🎓 O Que Você Aprendeu

Neste laboratório, você:

1. **Configurou** port mapping no Kind
2. **Expôs** portas 80/443 para o host
3. **Instalou** Nginx Ingress Controller
4. **Criou** Ingress resources
5. **Testou** host-based routing
6. **Testou** path-based routing
7. **Analisou** logs e networking
8. **Preparou** cluster para módulos avançados

---

## 🚀 Próximos Passos

- **[Lab 04: Múltiplos Clusters](./lab-04-multiplos-clusters.md)** - Gerenciar vários ambientes
- **Módulo 02**: Networking avançado com MetalLB
- **Experimentar**: TLS/SSL com certificados, rate limiting, etc.

---

## 💡 Conceitos-Chave

### Port Mapping Kind

- `extraPortMappings`: Expõe portas do container
- Necessário para acesso externo
- Ingress Controllers dependem disso

### Ingress vs Service

- **Service**: Roteamento Layer 4 (TCP/UDP)
- **Ingress**: Roteamento Layer 7 (HTTP/HTTPS)
- **Ingress Controller**: Implementação do Ingress (nginx, traefik, etc.)

### Ingress Routing

- **Host-based**: `web.local` vs `app2.local`
- **Path-based**: `/web` vs `/api`
- **Combinação**: Host + Path

---

## 📚 Recursos

- [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [Nginx Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [Kind Ingress](https://kind.sigs.k8s.io/docs/user/ingress/)
- [🆕 Gateway API](https://gateway-api.sigs.k8s.io/) - Evolução do Ingress
- [Migrating from Ingress to Gateway API](https://gateway-api.sigs.k8s.io/guides/migrating-from-ingress/)

---

**🎉 Parabéns por completar o Lab 03!**

Seu cluster agora está preparado para receber tráfego externo via Ingress!
