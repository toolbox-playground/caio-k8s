<#
.SYNOPSIS
    Deleta clusters Kind com segurança e opção de backup.

.DESCRIPTION
    Script para deletar clusters Kind com:
    - Confirmação de segurança
    - Opção de backup de configurações
    - Deleção de um ou todos os clusters
    - Relatório de espaço liberado

.PARAMETER ClusterName
    Nome do cluster a deletar

.PARAMETER Force
    Não pedir confirmação

.PARAMETER Backup
    Criar backup antes de deletar

.PARAMETER All
    Deletar todos os clusters Kind

.EXAMPLE
    .\delete-cluster.ps1 -ClusterName dev
    
.EXAMPLE
    .\delete-cluster.ps1 -ClusterName prod -Backup
    
.EXAMPLE
    .\delete-cluster.ps1 -All -Force
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ClusterName,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force,
    
    [Parameter(Mandatory=$false)]
    [switch]$Backup,
    
    [Parameter(Mandatory=$false)]
    [switch]$All
)

# Colors
$ColorInfo = "Cyan"
$ColorSuccess = "Green"
$ColorWarning = "Yellow"
$ColorError = "Red"

# Banner
Write-Host @"

╔═══════════════════════════════════════════╗
║     Kind Cluster Deleter - Módulo 01     ║
╚═══════════════════════════════════════════╝

"@ -ForegroundColor $ColorInfo

# Validar parâmetros
if (-not $All -and -not $ClusterName) {
    Write-Host "❌ Erro: Especifique -ClusterName ou use -All" -ForegroundColor $ColorError
    Write-Host "`nUso:" -ForegroundColor $ColorInfo
    Write-Host "  .\delete-cluster.ps1 -ClusterName dev" -ForegroundColor "Gray"
    Write-Host "  .\delete-cluster.ps1 -All" -ForegroundColor "Gray"
    exit 1
}

# Verificar Kind
try {
    kind version > $null 2>&1
} catch {
    Write-Host "❌ Kind não encontrado" -ForegroundColor $ColorError
    exit 1
}

# Obter lista de clusters
$clusters = kind get clusters 2>$null

if (-not $clusters) {
    Write-Host "ℹ️  Nenhum cluster Kind encontrado" -ForegroundColor $ColorInfo
    exit 0
}

# Determinar clusters a deletar
$clustersToDelete = @()

if ($All) {
    $clustersToDelete = $clusters
    Write-Host "🗑️  Clusters a deletar: TODOS ($($clusters.Count))" -ForegroundColor $ColorWarning
} else {
    if ($clusters -notcontains $ClusterName) {
        Write-Host "❌ Cluster '$ClusterName' não encontrado" -ForegroundColor $ColorError
        Write-Host "`nClusters disponíveis:" -ForegroundColor $ColorInfo
        $clusters | ForEach-Object { Write-Host "  - $_" -ForegroundColor "Gray" }
        exit 1
    }
    $clustersToDelete = @($ClusterName)
    Write-Host "🗑️  Cluster a deletar: $ClusterName" -ForegroundColor $ColorWarning
}

# Listar clusters
Write-Host "`n📋 Clusters:" -ForegroundColor $ColorInfo
$clustersToDelete | ForEach-Object { 
    Write-Host "  - $_" -ForegroundColor "Gray"
    
    # Mostrar nodes
    try {
        $nodeCount = (kubectl get nodes --context "kind-$_" --no-headers 2>$null | Measure-Object).Count
        Write-Host "    Nodes: $nodeCount" -ForegroundColor "DarkGray"
    } catch {}
}

# Confirmação
if (-not $Force) {
    Write-Host ""
    $response = Read-Host "Tem certeza que deseja deletar? (s/N)"
    if ($response -ne 's' -and $response -ne 'S') {
        Write-Host "❌ Operação cancelada" -ForegroundColor $ColorWarning
        exit 0
    }
}

# Backup se solicitado
if ($Backup) {
    Write-Host "`n💾 Criando backups..." -ForegroundColor $ColorInfo
    
    $backupDir = Join-Path $PSScriptRoot "backups"
    if (-not (Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    
    foreach ($cluster in $clustersToDelete) {
        try {
            # Backup kubeconfig
            $kubeconfigPath = Join-Path $backupDir "kubeconfig-$cluster-$timestamp.yaml"
            kind get kubeconfig --name $cluster > $kubeconfigPath
            Write-Host "  ✅ Kubeconfig salvo: $kubeconfigPath" -ForegroundColor $ColorSuccess
            
            # Backup de todos os recursos
            $manifestPath = Join-Path $backupDir "manifests-$cluster-$timestamp.yaml"
            kubectl get all -A --context "kind-$cluster" -o yaml > $manifestPath 2>$null
            Write-Host "  ✅ Manifests salvos: $manifestPath" -ForegroundColor $ColorSuccess
            
        } catch {
            Write-Host "  ⚠️  Erro ao criar backup de $cluster" -ForegroundColor $ColorWarning
        }
    }
}

# Espaço em disco antes
$diskBefore = docker system df --format "{{.Size}}" 2>$null

# Deletar clusters
Write-Host "`n🗑️  Deletando clusters..." -ForegroundColor $ColorInfo

$deletedCount = 0
$failedCount = 0

foreach ($cluster in $clustersToDelete) {
    Write-Host "`n  Deletando: $cluster" -ForegroundColor $ColorWarning
    
    try {
        kind delete cluster --name $cluster
        $deletedCount++
        Write-Host "  ✅ $cluster deletado" -ForegroundColor $ColorSuccess
    } catch {
        $failedCount++
        Write-Host "  ❌ Erro ao deletar $cluster" -ForegroundColor $ColorError
    }
}

# Limpeza adicional
Write-Host "`n🧹 Limpeza adicional..." -ForegroundColor $ColorInfo

# Limpar volumes órfãos
try {
    $volumesPruned = docker volume prune -f 2>$null
    Write-Host "  ✅ Volumes limpos" -ForegroundColor $ColorSuccess
} catch {
    Write-Host "  ⚠️  Erro ao limpar volumes" -ForegroundColor $ColorWarning
}

# Espaço em disco depois
$diskAfter = docker system df --format "{{.Size}}" 2>$null

# Resumo
Write-Host "`n📊 Resumo" -ForegroundColor $ColorInfo
Write-Host "═══════════════════════════════════════" -ForegroundColor $ColorInfo
Write-Host "  ✅ Deletados: $deletedCount" -ForegroundColor $ColorSuccess

if ($failedCount -gt 0) {
    Write-Host "  ❌ Falhas: $failedCount" -ForegroundColor $ColorError
}

if ($Backup) {
    Write-Host "  💾 Backups: $backupDir" -ForegroundColor $ColorInfo
}

# Verificar clusters restantes
$remainingClusters = kind get clusters 2>$null
if ($remainingClusters) {
    Write-Host "`n📋 Clusters restantes:" -ForegroundColor $ColorInfo
    $remainingClusters | ForEach-Object { Write-Host "  - $_" -ForegroundColor "Gray" }
} else {
    Write-Host "`n✅ Nenhum cluster Kind restante" -ForegroundColor $ColorSuccess
}

# Comandos úteis
Write-Host "`n💡 Comandos Úteis:" -ForegroundColor $ColorInfo
Write-Host "  Listar clusters:    kind get clusters" -ForegroundColor "Gray"
Write-Host "  Ver Docker:         docker ps" -ForegroundColor "Gray"
Write-Host "  Limpar Docker:      docker system prune -a" -ForegroundColor "Gray"
Write-Host "  Ver espaço:         docker system df" -ForegroundColor "Gray"

Write-Host "`n🎉 Limpeza concluída!" -ForegroundColor $ColorSuccess
Write-Host ""
