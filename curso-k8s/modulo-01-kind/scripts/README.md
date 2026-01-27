# 🛠️ Scripts - Módulo 01: Kind

Scripts PowerShell para automação de tarefas com Kind.

---

## 📚 Lista de Scripts

| Script | Descrição | Uso |
|--------|-----------|-----|
| [create-cluster.ps1](./create-cluster.ps1) | Criação automatizada de clusters | Vários templates pré-configurados |
| [delete-cluster.ps1](./delete-cluster.ps1) | Limpeza segura de clusters | Confirmação e backup |
| [cluster-info.ps1](./cluster-info.ps1) | Informações detalhadas | Status completo do cluster |

---

## 🚀 Como Usar

### Pré-requisitos

```powershell
# PowerShell 5.1+ ou PowerShell Core
$PSVersionTable.PSVersion

# Kind instalado
kind version

# Docker rodando
docker ps
```

### Executar Scripts

```powershell
# Navegar para pasta de scripts
cd c:\Users\marce\Documents\personal_projects\k8s\curso\modulo-01-kind\scripts

# Executar script
.\create-cluster.ps1 -ClusterName dev -Type single-node
```

---

## 📝 create-cluster.ps1

Cria clusters Kind com templates pré-configurados.

### Sintaxe

```powershell
.\create-cluster.ps1 [-ClusterName] <String> [-Type] <String> [-Wait]
```

### Parâmetros

- `ClusterName`: Nome do cluster (obrigatório)
- `Type`: Tipo de cluster (obrigatório)
  - `single-node`: Desenvolvimento rápido
  - `multi-node`: Testes distribuídos
  - `ha`: Alta disponibilidade
  - `ingress-ready`: Networking avançado
- `Wait`: Aguardar cluster ficar pronto (opcional)

### Exemplos

```powershell
# Cluster single-node para dev
.\create-cluster.ps1 -ClusterName dev -Type single-node

# Cluster multi-node
.\create-cluster.ps1 -ClusterName staging -Type multi-node -Wait

# Cluster HA
.\create-cluster.ps1 -ClusterName prod -Type ha -Wait

# Cluster com Ingress
.\create-cluster.ps1 -ClusterName ingress -Type ingress-ready
```

### Saída

- Validação de requisitos
- Criação do cluster
- Configuração do kubectl
- Resumo de nodes e pods
- Comandos úteis

---

## 🗑️ delete-cluster.ps1

Deleta clusters com segurança e opções de backup.

### Sintaxe

```powershell
.\delete-cluster.ps1 [-ClusterName] <String> [-Force] [-Backup] [-All]
```

### Parâmetros

- `ClusterName`: Nome do cluster a deletar
- `Force`: Não pedir confirmação
- `Backup`: Criar backup antes de deletar
- `All`: Deletar todos os clusters Kind

### Exemplos

```powershell
# Deletar cluster com confirmação
.\delete-cluster.ps1 -ClusterName dev

# Deletar sem confirmação
.\delete-cluster.ps1 -ClusterName dev -Force

# Deletar com backup
.\delete-cluster.ps1 -ClusterName prod -Backup

# Deletar todos
.\delete-cluster.ps1 -All

# Deletar todos sem confirmação
.\delete-cluster.ps1 -All -Force
```

### Saída

- Confirmação (se não usar `-Force`)
- Backup de kubeconfig e manifests (se usar `-Backup`)
- Status da deleção
- Espaço em disco liberado

---

## 📊 cluster-info.ps1

Exibe informações completas do cluster.

### Sintaxe

```powershell
.\cluster-info.ps1 [[-ClusterName] <String>] [-Detailed] [-Export <String>]
```

### Parâmetros

- `ClusterName`: Nome do cluster (opcional, usa contexto atual)
- `Detailed`: Informações detalhadas
- `Export`: Exportar para arquivo JSON

### Exemplos

```powershell
# Info do cluster atual
.\cluster-info.ps1

# Info de cluster específico
.\cluster-info.ps1 -ClusterName dev

# Info detalhada
.\cluster-info.ps1 -ClusterName prod -Detailed

# Exportar para JSON
.\cluster-info.ps1 -ClusterName dev -Export info-dev.json

# Todas as opções
.\cluster-info.ps1 -ClusterName prod -Detailed -Export prod-report.json
```

### Saída

**Básica:**
- Nome do cluster
- Número de nodes
- Versão do Kubernetes
- Status geral

**Detalhada:**
- Lista completa de nodes
- Pods em execução
- Services
- Namespaces
- Recursos alocados
- Docker containers
- Network info

---

## 🎯 Casos de Uso

### Desenvolvimento Diário

```powershell
# Manhã: Criar cluster
.\create-cluster.ps1 -ClusterName dev -Type single-node -Wait

# Trabalhar...

# Noite: Limpar
.\delete-cluster.ps1 -ClusterName dev -Force
```

### Testes Multi-Ambiente

```powershell
# Criar ambientes
.\create-cluster.ps1 -ClusterName dev -Type single-node
.\create-cluster.ps1 -ClusterName staging -Type multi-node
.\create-cluster.ps1 -ClusterName prod -Type ha

# Verificar todos
kind get clusters
.\cluster-info.ps1 -ClusterName dev
.\cluster-info.ps1 -ClusterName staging
.\cluster-info.ps1 -ClusterName prod

# Limpar quando terminar
.\delete-cluster.ps1 -All -Backup
```

### CI/CD Pipeline

```powershell
# Create ephemeral cluster
.\create-cluster.ps1 -ClusterName ci-$env:BUILD_ID -Type single-node -Wait

# Run tests...
# kubectl apply -f tests/
# kubectl wait...

# Cleanup
.\delete-cluster.ps1 -ClusterName ci-$env:BUILD_ID -Force
```

---

## 🔧 Customização

### Modificar Templates

Os scripts usam os manifests em `../manifests/`. Para customizar:

1. Editar arquivos em `../manifests/`
2. Scripts usarão automaticamente as novas configs

### Adicionar Novo Tipo

Em `create-cluster.ps1`, adicione novo tipo:

```powershell
"custom" {
    $configFile = "$manifestsPath\kind-custom.yaml"
    $description = "Minha configuração customizada"
}
```

---

## 🛡️ Segurança

### Backups

Scripts criam backups em:
```
.\backups\
├── kubeconfig-<cluster>-<timestamp>.yaml
└── manifests-<cluster>-<timestamp>.yaml
```

### Validações

- Verificação de Kind instalado
- Verificação de Docker rodando
- Confirmação antes de deletar (exceto com `-Force`)
- Validação de nomes de cluster

---

## 📊 Performance

### Tempos Médios

| Tipo | Criação | Deleção |
|------|---------|---------|
| single-node | 1-2 min | 10 seg |
| multi-node | 2-3 min | 15 seg |
| ha | 4-5 min | 20 seg |
| ingress-ready | 2-3 min | 15 seg |

### Recursos

| Tipo | CPU | RAM | Disco |
|------|-----|-----|-------|
| single-node | 2 | 2GB | 5GB |
| multi-node | 4 | 4GB | 10GB |
| ha | 8 | 8GB | 20GB |
| ingress-ready | 4 | 4GB | 10GB |

---

## 🔍 Troubleshooting

### Script não executa

```powershell
# Verificar execution policy
Get-ExecutionPolicy

# Permitir scripts (se necessário)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Ou executar com bypass
powershell -ExecutionPolicy Bypass -File .\create-cluster.ps1
```

### Erro "Kind não encontrado"

```powershell
# Verificar instalação
kind version

# Reinstalar
choco install kind
```

### Erro "Docker não está rodando"

```powershell
# Iniciar Docker Desktop
# Ou verificar serviço
docker ps
```

---

## 💡 Dicas

### Alias PowerShell

```powershell
# Adicionar ao $PROFILE
function kc { .\cluster-info.ps1 @args }
function kcc { .\create-cluster.ps1 @args }
function kcd { .\delete-cluster.ps1 @args }

# Usar
kcc -ClusterName dev -Type single-node
kc -ClusterName dev
kcd -ClusterName dev -Force
```

### Logging

Scripts incluem logging colorido:
- 🔨 Amarelo: Ações
- ✅ Verde: Sucesso
- ❌ Vermelho: Erro
- 📋 Cyan: Informações

---

## 📚 Recursos

- [PowerShell Documentation](https://docs.microsoft.com/powershell/)
- [Kind CLI Reference](https://kind.sigs.k8s.io/docs/user/quick-start/)

---

**💡 Use estes scripts para automatizar seu workflow com Kind!**
