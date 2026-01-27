<#
.SYNOPSIS
    Configura cluster Kind com Metrics Server para laboratório de resiliência.

.DESCRIPTION
    Este script automatiza a criação de um cluster Kubernetes local usando Kind,
    com configuração otimizada para demonstrações de auto-healing e auto-scaling.
    Inclui instalação e configuração do Metrics Server.

.PARAMETER ClusterName
    Nome do cluster Kind a ser criado. Padrão: "lab-resiliencia"

.PARAMETER Workers
    Número de nós workers. Padrão: 2

.PARAMETER NodePort
    Porta NodePort para expor a aplicação. Padrão: 30080

.EXAMPLE
    .\setup-cluster.ps1
    Cria cluster com configurações padrão

.EXAMPLE
    .\setup-cluster.ps1 -ClusterName "meu-lab" -Workers 3
    Cria cluster customizado com 3 workers
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ClusterName = "lab-resiliencia",
    
    [Parameter()]
    [int]$Workers = 2,
    
    [Parameter()]
    [int]$NodePort = 30080
)

$ErrorActionPreference = "Stop"

# Cores para output
function Write-Info { param($msg) Write-Host "ℹ️  $msg" -ForegroundColor Cyan }
function Write-Success { param($msg) Write-Host "✅ $msg" -ForegroundColor Green }
function Write-Error-Custom { param($msg) Write-Host "❌ $msg" -ForegroundColor Red }
function Write-Warning-Custom { param($msg) Write-Host "⚠️  $msg" -ForegroundColor Yellow }

Write-Host "`n🚀 Setup do Cluster Kubernetes para Laboratório de Resiliência" -ForegroundColor Magenta
Write-Host "=" * 70 -ForegroundColor Magenta

# Verificar pré-requisitos
Write-Info "Verificando pré-requisitos..."

try {
    $dockerVersion = docker version --format '{{.Server.Version}}' 2>$null
    if (-not $dockerVersion) { throw }
    Write-Success "Docker está rodando (versão $dockerVersion)"
} catch {
    Write-Error-Custom "Docker não encontrado ou não está rodando"
    Write-Host "Instale Docker Desktop: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
    exit 1
}

try {
    $kindVersion = kind version 2>$null
    Write-Success "Kind instalado ($kindVersion)"
} catch {
    Write-Error-Custom "Kind não encontrado"
    Write-Host "Instale via: choco install kind (Windows) ou https://kind.sigs.k8s.io/docs/user/quick-start/" -ForegroundColor Yellow
    exit 1
}

try {
    $kubectlVersion = kubectl version --client --short 2>$null
    Write-Success "kubectl instalado"
} catch {
    Write-Warning-Custom "kubectl não encontrado - será necessário para próximos passos"
}

# Verificar se cluster já existe
Write-Info "Verificando se cluster '$ClusterName' já existe..."
$existingClusters = kind get clusters 2>$null
if ($existingClusters -contains $ClusterName) {
    Write-Warning-Custom "Cluster '$ClusterName' já existe!"
    $response = Read-Host "Deseja deletá-lo e recriar? (S/N)"
    if ($response -eq 'S' -or $response -eq 's') {
        Write-Info "Deletando cluster existente..."
        kind delete cluster --name $ClusterName
        Write-Success "Cluster deletado"
    } else {
        Write-Info "Mantendo cluster existente. Encerrando."
        exit 0
    }
}

# Criar configuração do cluster
Write-Info "Criando configuração do cluster..."

$workerNodes = @()
for ($i = 1; $i -le $Workers; $i++) {
    $workerNodes += "  - role: worker"
}

$clusterConfig = @"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: $ClusterName
nodes:
  # Control plane node
  - role: control-plane
    kubeadmConfigPatches:
    - |
      kind: InitConfiguration
      nodeRegistration:
        kubeletExtraArgs:
          node-labels: "ingress-ready=true"
    extraPortMappings:
    - containerPort: $NodePort
      hostPort: $NodePort
      protocol: TCP
  # Worker nodes
$($workerNodes -join "`n")
"@

$configFile = "kind-cluster-config-temp.yaml"
$clusterConfig | Out-File -FilePath $configFile -Encoding UTF8
Write-Success "Configuração criada: $configFile"

# Criar cluster
Write-Info "Criando cluster Kind (isso pode levar alguns minutos)..."
try {
    kind create cluster --config=$configFile --wait 120s
    Write-Success "Cluster '$ClusterName' criado com sucesso!"
} catch {
    Write-Error-Custom "Falha ao criar cluster"
    Remove-Item $configFile -ErrorAction SilentlyContinue
    exit 1
}

# Limpar arquivo de configuração temporário
Remove-Item $configFile -ErrorAction SilentlyContinue

# Verificar cluster
Write-Info "Verificando cluster..."
kubectl cluster-info --context "kind-$ClusterName"
kubectl get nodes

# Instalar Metrics Server
Write-Info "`nInstalando Metrics Server..."
try {
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml | Out-Null
    Write-Success "Metrics Server instalado"
} catch {
    Write-Warning-Custom "Falha ao instalar Metrics Server - continuando..."
}

# Patch para funcionar no Kind
Write-Info "Configurando Metrics Server para Kind..."
try {
    kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
      {
        "op": "add",
        "path": "/spec/template/spec/containers/0/args/-",
        "value": "--kubelet-insecure-tls"
      }
    ]' | Out-Null
    Write-Success "Metrics Server configurado"
} catch {
    Write-Warning-Custom "Falha ao configurar Metrics Server"
}

# Aguardar Metrics Server estar pronto
Write-Info "Aguardando Metrics Server ficar pronto (pode levar até 2 minutos)..."
try {
    kubectl wait --for=condition=ready pod -l k8s-app=metrics-server -n kube-system --timeout=120s | Out-Null
    Write-Success "Metrics Server está pronto"
} catch {
    Write-Warning-Custom "Timeout aguardando Metrics Server - pode ainda estar inicializando"
}

# Aguardar métricas estarem disponíveis
Write-Info "Aguardando coleta inicial de métricas (60 segundos)..."
Start-Sleep -Seconds 60

# Verificar métricas
Write-Info "Testando coleta de métricas..."
try {
    kubectl top nodes | Out-Null
    Write-Success "Métricas estão disponíveis!"
    kubectl top nodes
} catch {
    Write-Warning-Custom "Métricas ainda não disponíveis - aguarde mais 1-2 minutos"
    Write-Host "  Execute: kubectl top nodes" -ForegroundColor Yellow
}

# Resumo
Write-Host "`n" + ("=" * 70) -ForegroundColor Green
Write-Host "✨ Setup Completo!" -ForegroundColor Green
Write-Host ("=" * 70) -ForegroundColor Green

Write-Host "`n📊 Resumo do Cluster:" -ForegroundColor Cyan
Write-Host "  Nome: $ClusterName" -ForegroundColor White
Write-Host "  Nós: 1 control-plane + $Workers workers" -ForegroundColor White
Write-Host "  NodePort exposta: $NodePort" -ForegroundColor White
Write-Host "  Context: kind-$ClusterName" -ForegroundColor White

Write-Host "`n🎯 Próximos Passos:" -ForegroundColor Cyan
Write-Host "  1. Fazer deploy da aplicação:" -ForegroundColor White
Write-Host "     .\deploy-app.ps1" -ForegroundColor Yellow
Write-Host ""
Write-Host "  2. Ou seguir o laboratório completo:" -ForegroundColor White
Write-Host "     ..\laboratorios\lab-completo-resiliencia.md" -ForegroundColor Yellow

Write-Host "`n📝 Comandos Úteis:" -ForegroundColor Cyan
Write-Host "  kubectl get nodes" -ForegroundColor Yellow
Write-Host "  kubectl top nodes" -ForegroundColor Yellow
Write-Host "  kubectl cluster-info" -ForegroundColor Yellow
Write-Host "  kind delete cluster --name $ClusterName" -ForegroundColor Yellow

Write-Host ""
