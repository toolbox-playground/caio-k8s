<#
.SYNOPSIS
    Exibe informações detalhadas de clusters Kind.

.DESCRIPTION
    Script para visualizar informações completas de clusters Kind:
    - Status geral do cluster
    - Nodes e suas capacidades
    - Pods em execução
    - Services e namespaces
    - Recursos Docker
    - Opção de exportar para JSON

.PARAMETER ClusterName
    Nome do cluster (opcional, usa contexto atual se omitido)

.PARAMETER Detailed
    Exibir informações detalhadas

.PARAMETER Export
    Exportar informações para arquivo JSON

.EXAMPLE
    .\cluster-info.ps1
    
.EXAMPLE
    .\cluster-info.ps1 -ClusterName dev -Detailed
    
.EXAMPLE
    .\cluster-info.ps1 -ClusterName prod -Export report.json
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ClusterName,
    
    [Parameter(Mandatory=$false)]
    [switch]$Detailed,
    
    [Parameter(Mandatory=$false)]
    [string]$Export
)

# Colors
$ColorInfo = "Cyan"
$ColorSuccess = "Green"
$ColorWarning = "Yellow"
$ColorError = "Red"

# Banner
Write-Host @"

╔═══════════════════════════════════════════╗
║     Kind Cluster Info - Módulo 01        ║
╚═══════════════════════════════════════════╝

"@ -ForegroundColor $ColorInfo

# Verificar Kind e kubectl
try {
    kind version > $null 2>&1
    kubectl version --client > $null 2>&1
} catch {
    Write-Host "❌ Kind ou kubectl não encontrado" -ForegroundColor $ColorError
    exit 1
}

# Determinar cluster e contexto
if ($ClusterName) {
    $context = "kind-$ClusterName"
} else {
    try {
        $context = kubectl config current-context 2>$null
        if ($context -like "kind-*") {
            $ClusterName = $context -replace "kind-", ""
        } else {
            Write-Host "❌ Contexto atual não é um cluster Kind" -ForegroundColor $ColorError
            Write-Host "Use: .\cluster-info.ps1 -ClusterName <nome>" -ForegroundColor $ColorInfo
            exit 1
        }
    } catch {
        Write-Host "❌ Nenhum contexto kubectl configurado" -ForegroundColor $ColorError
        exit 1
    }
}

# Verificar se cluster existe
$existingClusters = kind get clusters 2>$null
if ($existingClusters -notcontains $ClusterName) {
    Write-Host "❌ Cluster '$ClusterName' não encontrado" -ForegroundColor $ColorError
    Write-Host "`nClusters disponíveis:" -ForegroundColor $ColorInfo
    $existingClusters | ForEach-Object { Write-Host "  - $_" -ForegroundColor "Gray" }
    exit 1
}

# Configurar contexto
kubectl config use-context $context > $null 2>&1

# Objeto para armazenar informações (para export)
$clusterInfo = @{
    ClusterName = $ClusterName
    Context = $context
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}

# ========================================
# INFORMAÇÕES BÁSICAS
# ========================================

Write-Host "`n🔍 Informações Básicas" -ForegroundColor $ColorInfo
Write-Host "═══════════════════════════════════════" -ForegroundColor $ColorInfo

# Cluster name
Write-Host "`n📛 Cluster: $ClusterName" -ForegroundColor $ColorSuccess

# Kubernetes version
try {
    $k8sVersion = kubectl version --short 2>$null | Select-String "Server Version"
    Write-Host "🎯 Kubernetes: $k8sVersion" -ForegroundColor $ColorInfo
    $clusterInfo.KubernetesVersion = $k8sVersion.ToString()
} catch {}

# Contexto atual
Write-Host "⚙️  Contexto: $context" -ForegroundColor $ColorInfo

# ========================================
# NODES
# ========================================

Write-Host "`n🖥️  Nodes" -ForegroundColor $ColorInfo
Write-Host "═══════════════════════════════════════" -ForegroundColor $ColorInfo

$nodes = kubectl get nodes --no-headers 2>$null

if ($nodes) {
    $nodeLines = $nodes -split "`n"
    $nodeCount = $nodeLines.Count
    
    Write-Host "`nTotal: $nodeCount nodes" -ForegroundColor $ColorSuccess
    
    # Mostrar nodes
    kubectl get nodes
    
    # Armazenar para export
    $clusterInfo.NodeCount = $nodeCount
    $clusterInfo.Nodes = @()
    
    # Detalhes se solicitado
    if ($Detailed) {
        Write-Host "`n📊 Detalhes dos Nodes:" -ForegroundColor $ColorInfo
        
        foreach ($nodeLine in $nodeLines) {
            $nodeName = ($nodeLine -split "\s+")[0]
            
            Write-Host "`n  Node: $nodeName" -ForegroundColor $ColorWarning
            
            # Capacidade
            $capacity = kubectl get node $nodeName -o json | ConvertFrom-Json | Select-Object -ExpandProperty status | Select-Object -ExpandProperty capacity
            
            Write-Host "    CPU: $($capacity.cpu)" -ForegroundColor "Gray"
            Write-Host "    Memória: $($capacity.memory)" -ForegroundColor "Gray"
            Write-Host "    Pods: $($capacity.pods)" -ForegroundColor "Gray"
            
            # Labels
            $labels = kubectl get node $nodeName --show-labels --no-headers | ForEach-Object { ($_ -split "\s+")[-1] }
            Write-Host "    Labels: $labels" -ForegroundColor "DarkGray"
            
            $clusterInfo.Nodes += @{
                Name = $nodeName
                CPU = $capacity.cpu
                Memory = $capacity.memory
                Pods = $capacity.pods
            }
        }
    }
}

# ========================================
# PODS
# ========================================

Write-Host "`n🏃 Pods" -ForegroundColor $ColorInfo
Write-Host "═══════════════════════════════════════" -ForegroundColor $ColorInfo

$allPods = kubectl get pods -A --no-headers 2>$null

if ($allPods) {
    $podLines = $allPods -split "`n"
    $podCount = $podLines.Count
    
    Write-Host "`nTotal: $podCount pods" -ForegroundColor $ColorSuccess
    
    # Contar por namespace
    $namespaces = @{}
    foreach ($line in $podLines) {
        $ns = ($line -split "\s+")[0]
        if ($namespaces.ContainsKey($ns)) {
            $namespaces[$ns]++
        } else {
            $namespaces[$ns] = 1
        }
    }
    
    Write-Host "`nPor Namespace:" -ForegroundColor $ColorInfo
    $namespaces.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
        Write-Host "  $($_.Key): $($_.Value)" -ForegroundColor "Gray"
    }
    
    $clusterInfo.PodCount = $podCount
    $clusterInfo.PodsByNamespace = $namespaces
    
    if ($Detailed) {
        Write-Host "`n📋 Todos os Pods:" -ForegroundColor $ColorInfo
        kubectl get pods -A
    }
}

# ========================================
# SERVICES
# ========================================

if ($Detailed) {
    Write-Host "`n🌐 Services" -ForegroundColor $ColorInfo
    Write-Host "═══════════════════════════════════════" -ForegroundColor $ColorInfo
    
    $services = kubectl get services -A --no-headers 2>$null
    if ($services) {
        $serviceCount = ($services -split "`n").Count
        Write-Host "`nTotal: $serviceCount services" -ForegroundColor $ColorSuccess
        kubectl get services -A
        $clusterInfo.ServiceCount = $serviceCount
    }
}

# ========================================
# NAMESPACES
# ========================================

Write-Host "`n📦 Namespaces" -ForegroundColor $ColorInfo
Write-Host "═══════════════════════════════════════" -ForegroundColor $ColorInfo

$namespaces = kubectl get namespaces --no-headers 2>$null

if ($namespaces) {
    $nsCount = ($namespaces -split "`n").Count
    Write-Host "`nTotal: $nsCount namespaces" -ForegroundColor $ColorSuccess
    kubectl get namespaces
    $clusterInfo.NamespaceCount = $nsCount
}

# ========================================
# DOCKER CONTAINERS
# ========================================

if ($Detailed) {
    Write-Host "`n🐳 Docker Containers" -ForegroundColor $ColorInfo
    Write-Host "═══════════════════════════════════════" -ForegroundColor $ColorInfo
    
    $containers = docker ps --filter "label=io.x-k8s.kind.cluster=$ClusterName" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    if ($containers) {
        Write-Host ""
        Write-Host $containers
    }
}

# ========================================
# NETWORK
# ========================================

if ($Detailed) {
    Write-Host "`n🌐 Network" -ForegroundColor $ColorInfo
    Write-Host "═══════════════════════════════════════" -ForegroundColor $ColorInfo
    
    # Network do Kind
    $networkInfo = docker network inspect kind 2>$null | ConvertFrom-Json
    if ($networkInfo) {
        $subnet = $networkInfo.IPAM.Config.Subnet
        Write-Host "`nKind Network:" -ForegroundColor $ColorSuccess
        Write-Host "  Subnet: $subnet" -ForegroundColor "Gray"
        
        $clusterInfo.Network = @{
            Subnet = $subnet
        }
    }
    
    # Port mapping (se ingress-ready)
    $controlPlane = "$ClusterName-control-plane"
    $ports = docker port $controlPlane 2>$null
    
    if ($ports) {
        Write-Host "`nPort Mappings:" -ForegroundColor $ColorSuccess
        $ports | ForEach-Object { Write-Host "  $_" -ForegroundColor "Gray" }
    }
}

# ========================================
# RECURSOS
# ========================================

if ($Detailed) {
    Write-Host "`n📊 Recursos do Cluster" -ForegroundColor $ColorInfo
    Write-Host "═══════════════════════════════════════" -ForegroundColor $ColorInfo
    
    # Deployments
    $deployments = kubectl get deployments -A --no-headers 2>$null
    if ($deployments) {
        $deployCount = ($deployments -split "`n").Count
        Write-Host "`n  Deployments: $deployCount" -ForegroundColor $ColorInfo
        $clusterInfo.DeploymentCount = $deployCount
    }
    
    # StatefulSets
    $statefulsets = kubectl get statefulsets -A --no-headers 2>$null
    if ($statefulsets) {
        $stsCount = ($statefulsets -split "`n").Count
        Write-Host "  StatefulSets: $stsCount" -ForegroundColor $ColorInfo
        $clusterInfo.StatefulSetCount = $stsCount
    }
    
    # DaemonSets
    $daemonsets = kubectl get daemonsets -A --no-headers 2>$null
    if ($daemonsets) {
        $dsCount = ($daemonsets -split "`n").Count
        Write-Host "  DaemonSets: $dsCount" -ForegroundColor $ColorInfo
        $clusterInfo.DaemonSetCount = $dsCount
    }
}

# ========================================
# HEALTH
# ========================================

Write-Host "`n❤️  Health Check" -ForegroundColor $ColorInfo
Write-Host "═══════════════════════════════════════" -ForegroundColor $ColorInfo

try {
    $health = kubectl get --raw /healthz 2>$null
    if ($health -eq "ok") {
        Write-Host "`n✅ API Server: Healthy" -ForegroundColor $ColorSuccess
        $clusterInfo.APIServerHealth = "ok"
    } else {
        Write-Host "`n⚠️  API Server: $health" -ForegroundColor $ColorWarning
        $clusterInfo.APIServerHealth = $health
    }
} catch {
    Write-Host "`n❌ API Server: Unreachable" -ForegroundColor $ColorError
    $clusterInfo.APIServerHealth = "unreachable"
}

# ========================================
# EXPORT
# ========================================

if ($Export) {
    Write-Host "`n💾 Exportando informações..." -ForegroundColor $ColorInfo
    
    try {
        $clusterInfo | ConvertTo-Json -Depth 10 | Out-File -FilePath $Export -Encoding UTF8
        Write-Host "  ✅ Exportado para: $Export" -ForegroundColor $ColorSuccess
    } catch {
        Write-Host "  ❌ Erro ao exportar" -ForegroundColor $ColorError
    }
}

# ========================================
# COMANDOS ÚTEIS
# ========================================

Write-Host "`n💡 Comandos Úteis" -ForegroundColor $ColorInfo
Write-Host "═══════════════════════════════════════" -ForegroundColor $ColorInfo
Write-Host "  kubectl get all -A" -ForegroundColor "Gray"
Write-Host "  kubectl get events --sort-by='.lastTimestamp'" -ForegroundColor "Gray"
Write-Host "  kubectl cluster-info" -ForegroundColor "Gray"
Write-Host "  kubectl top nodes" -ForegroundColor "Gray"
Write-Host "  kubectl top pods -A" -ForegroundColor "Gray"

Write-Host ""
