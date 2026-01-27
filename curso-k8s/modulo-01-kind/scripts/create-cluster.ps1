<#
.SYNOPSIS
    Cria clusters Kind com templates pré-configurados.

.DESCRIPTION
    Script para automatizar criação de clusters Kind com diferentes configurações:
    - single-node: Desenvolvimento rápido
    - multi-node: Testes distribuídos (1 CP + 2 Workers)
    - ha: Alta disponibilidade (3 CP + 3 Workers)
    - ingress-ready: Preparado para Ingress Controller

.PARAMETER ClusterName
    Nome do cluster a ser criado

.PARAMETER Type
    Tipo de cluster: single-node, multi-node, ha, ingress-ready

.PARAMETER Wait
    Aguardar até cluster estar completamente pronto

.EXAMPLE
    .\create-cluster.ps1 -ClusterName dev -Type single-node
    
.EXAMPLE
    .\create-cluster.ps1 -ClusterName prod -Type ha -Wait
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ClusterName,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet("single-node", "multi-node", "ha", "ingress-ready")]
    [string]$Type,
    
    [Parameter(Mandatory=$false)]
    [switch]$Wait
)

# Colors
$ColorInfo = "Cyan"
$ColorSuccess = "Green"
$ColorWarning = "Yellow"
$ColorError = "Red"

# Banner
Write-Host @"

╔═══════════════════════════════════════════╗
║     Kind Cluster Creator - Módulo 01     ║
╚═══════════════════════════════════════════╝

"@ -ForegroundColor $ColorInfo

# Validar requisitos
Write-Host "📋 Validando requisitos..." -ForegroundColor $ColorInfo

# Verificar Kind
try {
    $kindVersion = kind version 2>$null
    Write-Host "  ✅ Kind: $kindVersion" -ForegroundColor $ColorSuccess
} catch {
    Write-Host "  ❌ Kind não encontrado. Instale com: choco install kind" -ForegroundColor $ColorError
    exit 1
}

# Verificar Docker
try {
    docker ps > $null 2>&1
    Write-Host "  ✅ Docker: Rodando" -ForegroundColor $ColorSuccess
} catch {
    Write-Host "  ❌ Docker não está rodando. Inicie o Docker Desktop." -ForegroundColor $ColorError
    exit 1
}

# Verificar kubectl
try {
    $kubectlVersion = kubectl version --client --short 2>$null
    Write-Host "  ✅ kubectl: Instalado" -ForegroundColor $ColorSuccess
} catch {
    Write-Host "  ⚠️  kubectl não encontrado (será configurado pelo Kind)" -ForegroundColor $ColorWarning
}

# Verificar se cluster já existe
$existingClusters = kind get clusters 2>$null
if ($existingClusters -contains $ClusterName) {
    Write-Host "`n  ⚠️  Cluster '$ClusterName' já existe!" -ForegroundColor $ColorWarning
    $response = Read-Host "Deseja deletar e recriar? (s/N)"
    if ($response -eq 's' -or $response -eq 'S') {
        Write-Host "  🗑️  Deletando cluster existente..." -ForegroundColor $ColorWarning
        kind delete cluster --name $ClusterName
    } else {
        Write-Host "  ❌ Operação cancelada" -ForegroundColor $ColorError
        exit 0
    }
}

# Determinar arquivo de config
$manifestsPath = Join-Path $PSScriptRoot "..\manifests"
$configFile = ""
$description = ""

switch ($Type) {
    "single-node" {
        $configFile = "$manifestsPath\kind-single-node.yaml"
        $description = "Cluster single-node (1 control-plane)"
    }
    "multi-node" {
        $configFile = "$manifestsPath\kind-multi-node.yaml"
        $description = "Cluster multi-node (1 CP + 2 Workers)"
    }
    "ha" {
        $configFile = "$manifestsPath\kind-ha-cluster.yaml"
        $description = "Cluster HA (3 CP + 3 Workers)"
    }
    "ingress-ready" {
        $configFile = "$manifestsPath\kind-ingress-ready.yaml"
        $description = "Cluster Ingress-Ready (1 CP + 2 Workers + Port Mapping)"
    }
}

# Verificar se arquivo de config existe
if (-not (Test-Path $configFile)) {
    Write-Host "`n  ❌ Arquivo de config não encontrado: $configFile" -ForegroundColor $ColorError
    exit 1
}

# Criar cluster
Write-Host "`n🔨 Criando cluster..." -ForegroundColor $ColorInfo
Write-Host "  📝 Nome: $ClusterName" -ForegroundColor $ColorInfo
Write-Host "  🎨 Tipo: $Type" -ForegroundColor $ColorInfo
Write-Host "  📋 Descrição: $description" -ForegroundColor $ColorInfo
Write-Host "  📄 Config: $configFile" -ForegroundColor $ColorInfo
Write-Host ""

# Executar criação
$startTime = Get-Date

# Criar cluster com nome customizado
$tempConfig = Get-Content $configFile -Raw
$tempConfig = $tempConfig -replace "name: \w+", "name: $ClusterName"
$tempConfigPath = Join-Path $env:TEMP "kind-config-$ClusterName.yaml"
$tempConfig | Out-File -FilePath $tempConfigPath -Encoding UTF8

try {
    kind create cluster --config $tempConfigPath
    Remove-Item $tempConfigPath -Force
} catch {
    Write-Host "`n  ❌ Erro ao criar cluster" -ForegroundColor $ColorError
    Remove-Item $tempConfigPath -Force -ErrorAction SilentlyContinue
    exit 1
}

$endTime = Get-Date
$duration = ($endTime - $startTime).TotalSeconds

Write-Host "`n✅ Cluster criado com sucesso em $([math]::Round($duration, 1)) segundos!" -ForegroundColor $ColorSuccess

# Aguardar se especificado
if ($Wait) {
    Write-Host "`n⏳ Aguardando cluster ficar pronto..." -ForegroundColor $ColorInfo
    
    # Aguardar nodes ficarem Ready
    $maxAttempts = 30
    $attempt = 0
    $allReady = $false
    
    while (-not $allReady -and $attempt -lt $maxAttempts) {
        $attempt++
        Start-Sleep -Seconds 2
        
        $nodes = kubectl get nodes --no-headers 2>$null
        if ($nodes) {
            $notReadyCount = ($nodes | Select-String "NotReady").Count
            if ($notReadyCount -eq 0) {
                $allReady = $true
            }
        }
        
        Write-Host "  Tentativa $attempt/$maxAttempts..." -ForegroundColor $ColorInfo
    }
    
    if ($allReady) {
        # Aguardar pods do sistema
        kubectl wait --for=condition=ready pod --all -n kube-system --timeout=120s > $null 2>&1
        Write-Host "  ✅ Cluster pronto!" -ForegroundColor $ColorSuccess
    } else {
        Write-Host "  ⚠️  Timeout aguardando cluster ficar pronto" -ForegroundColor $ColorWarning
    }
}

# Resumo
Write-Host "`n📊 Resumo do Cluster" -ForegroundColor $ColorInfo
Write-Host "═══════════════════════════════════════" -ForegroundColor $ColorInfo

# Nodes
Write-Host "`n🖥️  Nodes:" -ForegroundColor $ColorInfo
kubectl get nodes

# Pods do sistema
Write-Host "`n🏃 Pods do Sistema:" -ForegroundColor $ColorInfo
kubectl get pods -n kube-system

# Contexto kubectl
$currentContext = kubectl config current-context
Write-Host "`n⚙️  Contexto kubectl: $currentContext" -ForegroundColor $ColorSuccess

# Info adicional para ingress-ready
if ($Type -eq "ingress-ready") {
    Write-Host "`n🌐 Port Mapping:" -ForegroundColor $ColorInfo
    Write-Host "  HTTP:  http://localhost:30080" -ForegroundColor $ColorSuccess
    Write-Host "  HTTPS: https://localhost:30443" -ForegroundColor $ColorSuccess
}

# Comandos úteis
Write-Host "`n💡 Comandos Úteis:" -ForegroundColor $ColorInfo
Write-Host "  Ver clusters:     kind get clusters" -ForegroundColor "Gray"
Write-Host "  Ver nodes:        kubectl get nodes" -ForegroundColor "Gray"
Write-Host "  Cluster info:     kubectl cluster-info" -ForegroundColor "Gray"
Write-Host "  Deletar cluster:  kind delete cluster --name $ClusterName" -ForegroundColor "Gray"
Write-Host "  Cluster info:     .\cluster-info.ps1 -ClusterName $ClusterName" -ForegroundColor "Gray"

Write-Host "`n🎉 Cluster '$ClusterName' está pronto para uso!" -ForegroundColor $ColorSuccess
Write-Host ""
