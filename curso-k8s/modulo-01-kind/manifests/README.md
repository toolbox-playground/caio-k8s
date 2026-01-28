# 📁 Manifests - Módulo 01: Kind

Configurações YAML prontas para uso com Kind.

---

## 📚 Lista de Manifests

| Arquivo | Descrição | Nodes | Uso |
|---------|-----------|-------|-----|
| [kind-single-node.yaml](./kind-single-node.yaml) | Cluster minimalista | 1 CP | Dev rápido |
| [kind-multi-node.yaml](./kind-multi-node.yaml) | Cluster distribuído | 1 CP + 2 Workers | Testes de scheduling |
| [kind-ha-cluster.yaml](./kind-ha-cluster.yaml) | Alta disponibilidade | 3 CP + 3 Workers | Simular produção |
| [kind-ingress-ready.yaml](./kind-ingress-ready.yaml) | Pronto para Ingress | 1 CP + 2 Workers | Networking avançado |

---

## 🚀 Como Usar

### Criar Cluster

```powershell
# Escolha um manifest
kind create cluster --config kind-single-node.yaml

# Ou com nome customizado
kind create cluster --name meu-cluster --config kind-multi-node.yaml
```

### Verificar

```powershell
# Ver cluster criado
kind get clusters

# Ver nodes
kubectl get nodes

# Ver containers Docker
docker ps
```

### Deletar

```powershell
# Deletar cluster
kind delete cluster --name <nome>
```

---

## 📝 Detalhes dos Manifests

### 1️⃣ kind-single-node.yaml

**Características:**
- Mais simples possível
- Mínimo de recursos
- Ideal para desenvolvimento rápido
- Não tem workers

**Quando usar:**
- Testes rápidos
- Aprendizado básico
- Recursos limitados
- CI/CD pipelines

**Recursos necessários:**
- CPU: 2 cores
- RAM: 2GB
- Disco: 5GB

---

### 2️⃣ kind-multi-node.yaml

**Características:**
- 1 control-plane
- 2 workers
- Labels customizados por zona
- Simula ambiente distribuído

**Quando usar:**
- Testar scheduling
- Pod distribution
- Node affinity/anti-affinity
- DaemonSets
- Falha de nodes

**Recursos necessários:**
- CPU: 4 cores
- RAM: 4GB
- Disco: 10GB

---

### 3️⃣ kind-ha-cluster.yaml

**Características:**
- 3 control-planes (HA)
- 3 workers
- Load balancing automático
- Simula produção real

**Quando usar:**
- Testes de alta disponibilidade
- Falha de control-plane
- Validação pré-produção
- Testes de resiliência

**Recursos necessários:**
- CPU: 8 cores
- RAM: 8GB
- Disco: 20GB

**⚠️ Nota:** Requer Docker Desktop com recursos adequados configurados.

---

### 4️⃣ kind-ingress-ready.yaml

**Características:**
- Port mapping 80:80 (HTTP)
- Port mapping 443:443 (HTTPS)
- Label `ingress-ready=true`
- 2 workers para distribuição

**Quando usar:**
- Instalar Ingress Controller
- Testar roteamento HTTP/HTTPS
- Acesso via localhost
- Preparação para Módulo 02

**Acesso:**
- HTTP: `http://localhost:80` (ou apenas `http://localhost`)
- HTTPS: `https://localhost:443` (ou apenas `https://localhost`)

> **💡 Dica**: Para usar portas alternativas (ex: 8080), altere `hostPort` no manifest.

**🔔 Nota sobre Gateway API:**  
Considere usar [Gateway API](https://gateway-api.sigs.k8s.io/) para novos projetos - é a evolução do Ingress tradicional.

---

## 🎨 Customizações Comuns

### Mudar Versão do Kubernetes

```yaml
nodes:
- role: control-plane
  image: kindest/node:v1.27.3  # Adicione esta linha
```

**Versões disponíveis:**
- `v1.28.0`
- `v1.27.3`
- `v1.26.6`
- `v1.25.11`

### Adicionar Labels aos Nodes

```yaml
nodes:
- role: worker
  labels:
    tier: frontend
    zone: us-east-1a
```

### Configurar Resources

```yaml
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        system-reserved: memory=1Gi
```

### Port Mapping Adicional

```yaml
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 80
    hostPort: 8080
  - containerPort: 443
    hostPort: 8443
  - containerPort: 8080
    hostPort: 9090  # Custom port
```

---

## 🔧 Troubleshooting

### Cluster não inicia

```powershell
# Verificar Docker
docker ps
docker info

# Limpar e recriar
kind delete cluster --name <nome>
kind create cluster --config <arquivo> --verbosity=3
```

### Falta de recursos

```powershell
# Ver uso de recursos
docker stats --no-stream

# Ajustar Docker Desktop
# Settings > Resources > Aumentar CPU e RAM

# Ou usar manifest mais leve
kind create cluster --config kind-single-node.yaml
```

### Port mapping não funciona

```powershell
# Verificar se porta está mapeada
docker port <container-name>

# Verificar se porta está em uso
netstat -an | Select-String "30080"

# Mudar porta no manifest se necessário
```

---

## 💡 Dicas

### Desenvolvimento Local

```powershell
# Use single-node para velocidade
kind create cluster --config kind-single-node.yaml

# Ative port-forward quando necessário
kubectl port-forward svc/myapp 8080:80
```

### Testes de Produção

```powershell
# Use HA cluster
kind create cluster --config kind-ha-cluster.yaml

# Simule falhas
docker stop <worker-name>
docker start <worker-name>
```

### Múltiplos Ambientes

```powershell
# Crie clusters com nomes diferentes
kind create cluster --name dev --config kind-single-node.yaml
kind create cluster --name staging --config kind-multi-node.yaml
kind create cluster --name prod --config kind-ha-cluster.yaml

# Switch entre eles
kubectl config use-context kind-dev
kubectl config use-context kind-staging
kubectl config use-context kind-prod
```

---

## 📊 Comparação Rápida

| Característica | Single | Multi | HA | Ingress |
|----------------|--------|-------|-----|---------|
| Control-Planes | 1 | 1 | 3 | 1 |
| Workers | 0 | 2 | 3 | 2 |
| Port Mapping | ❌ | ❌ | ❌ | ✅ |
| Recursos | Baixo | Médio | Alto | Médio |
| Tempo de criação | 1 min | 2 min | 4 min | 2 min |
| Uso | Dev | Testing | Pre-Prod | Networking |

---

## 🎓 Quando Usar Cada Um

### Durante o Curso

| Módulo | Manifest Recomendado |
|--------|---------------------|
| 01 - Kind | Todos (para aprender) |
| 02 - Networking | kind-ingress-ready.yaml |
| 03 - Monitoring | kind-multi-node.yaml |
| 04 - Policies | kind-multi-node.yaml |
| 05 - GitOps | kind-ingress-ready.yaml |
| 06 - Service Mesh | kind-ha-cluster.yaml |
| 07 - Keycloak | kind-ingress-ready.yaml |
| 08 - Falco | kind-multi-node.yaml |
| 09 - Integração | kind-ha-cluster.yaml |

### Para Projetos Pessoais

- **Aprendizado**: single-node
- **Desenvolvimento**: multi-node ou ingress-ready
- **Testes**: ha-cluster

---

## 📚 Recursos

- [Kind Configuration](https://kind.sigs.k8s.io/docs/user/configuration/)
- [Kind Quick Start](https://kind.sigs.k8s.io/docs/user/quick-start/)
- [Kubernetes Versions](https://github.com/kubernetes-sigs/kind/releases)

---

**💡 Escolha o manifest adequado para seu caso de uso e boa prática com Kind!**
