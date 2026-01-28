<#
.SYNOPSIS
    Faz deploy completo do Super Mario no cluster Kubernetes.

.DESCRIPTION
    Este script automatiza o deploy do Super Mario,
    incluindo Deployment, Service (ClusterIP) e Horizontal Pod Autoscaler.
    Acesso via kubectl port-forward (método profissional).

.PARAMETER Namespace
    Namespace onde a aplicação será deployada. Padrão: "games"

.PARAMETER Replicas
    Número inicial de réplicas. Padrão: 2

.PARAMETER SkipHPA
    Se especificado, não cria o HPA (apenas Deployment e Service)

.PARAMETER StartPortForward
    Se especificado, inicia port-forward automaticamente após deploy

.EXAMPLE
    .\deploy-app.ps1
    Deploy com configurações padrão

.EXAMPLE
    .\deploy-app.ps1 -Replicas 3 -SkipHPA
    Deploy com 3 réplicas sem HPA

.EXAMPLE
    .\deploy-app.ps1 -StartPortForward
    Deploy e inicia port-forward automaticamente
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$Namespace = "games",
    
    [Parameter()]
    [int]$Replicas = 2,
    
    [Parameter()]
    [switch]$SkipHPA,
    
    [Parameter()]
    [switch]$StartPortForward
)

$ErrorActionPreference = "Stop"

# Cores para output
function Write-Info { param($msg) Write-Host "ℹ️  $msg" -ForegroundColor Cyan }
function Write-Success { param($msg) Write-Host "✅ $msg" -ForegroundColor Green }
function Write-Error-Custom { param($msg) Write-Host "❌ $msg" -ForegroundColor Red }
function Write-Warning-Custom { param($msg) Write-Host "⚠️  $msg" -ForegroundColor Yellow }

Write-Host "`n🎮 Deploy do Super Mario no Kubernetes" -ForegroundColor Magenta
Write-Host "=" * 70 -ForegroundColor Magenta

# Verificar se kubectl está disponível
try {
    kubectl version --client --short 2>$null | Out-Null
} catch {
    Write-Error-Custom "kubectl não encontrado"
    exit 1
}

# Verificar se há cluster ativo
try {
    kubectl cluster-info 2>$null | Out-Null
    Write-Success "Cluster Kubernetes detectado"
} catch {
    Write-Error-Custom "Nenhum cluster Kubernetes ativo encontrado"
    Write-Host "Execute primeiro: .\setup-cluster.ps1" -ForegroundColor Yellow
    exit 1
}

# Navegar para a pasta de manifestos
$manifestsPath = Join-Path $PSScriptRoot "..\manifests"
if (-not (Test-Path $manifestsPath)) {
    Write-Error-Custom "Pasta de manifestos não encontrada: $manifestsPath"
    exit 1
}

Push-Location $manifestsPath

try {
    # Criar namespace se não existir
    Write-Info "Verificando namespace '$Namespace'..."
    $namespaceExists = kubectl get namespace $Namespace 2>$null
    if (-not $namespaceExists) {
        Write-Info "Criando namespace '$Namespace'..."
        kubectl create namespace $Namespace | Out-Null
        Write-Success "Namespace criado"
    } else {
        Write-Success "Namespace já existe"
    }

    # Deploy do Deployment
    Write-Info "`nFazendo deploy do Deployment..."
    kubectl apply -f 01-deployment-mario.yaml
    
    if ($Replicas -ne 2) {
        Write-Info "Ajustando para $Replicas réplicas..."
        kubectl scale deployment super-mario -n $Namespace --replicas=$Replicas | Out-Null
    }
    
    Write-Success "Deployment criado"

    # Aguardar rollout
    Write-Info "Aguardando pods ficarem prontos..."
    kubectl rollout status deployment/super-mario -n $Namespace --timeout=120s
    Write-Success "Deployment está pronto!"

    # Deploy do Service
    Write-Info "`nFazendo deploy do Service (ClusterIP)..."
    kubectl apply -f 02-service-mario.yaml
    Write-Success "Service criado"

    # Deploy do HPA (se não pulado)
    if (-not $SkipHPA) {
        Write-Info "`nFazendo deploy do Horizontal Pod Autoscaler..."
        
        # Verificar se métricas estão disponíveis
        try {
            kubectl top nodes 2>$null | Out-Null
            kubectl apply -f 03-hpa.yaml
            Write-Success "HPA criado"
        } catch {
            Write-Warning-Custom "Métricas não disponíveis - HPA não foi criado"
            Write-Host "  Aguarde 1-2 minutos e execute:" -ForegroundColor Yellow
            Write-Host "  kubectl apply -f $manifestsPath\03-hpa.yaml" -ForegroundColor Yellow
        }
    } else {
        Write-Warning-Custom "HPA pulado (flag -SkipHPA)"
    }

    # Verificar recursos criados
    Write-Info "`nVerificando recursos criados..."
    Start-Sleep -Seconds 3
    
    Write-Host "`n📦 Pods:" -ForegroundColor Cyan
    kubectl get pods -n $Namespace -o wide
    
    Write-Host "`n🌐 Service:" -ForegroundColor Cyan
    kubectl get service -n $Namespace
    
    if (-not $SkipHPA) {
        Write-Host "`n📊 HPA:" -ForegroundColor Cyan
        kubectl get hpa -n $Namespace 2>$null
    }
    
    # Resumo
    Write-Host "`n" + ("=" * 70) -ForegroundColor Green
    Write-Host "✨ Deploy Completo!" -ForegroundColor Green
    Write-Host ("=" * 70) -ForegroundColor Green

    Write-Host "`n🎮 Acesse o Super Mario via Port-Forward:" -ForegroundColor Cyan
    Write-Host "  kubectl port-forward -n $Namespace service/super-mario-service 8080:80" -ForegroundColor Yellow
    Write-Host "  Depois abra: http://localhost:8080" -ForegroundColor Yellow
    Write-Host ""
    
    if ($StartPortForward) {
        Write-Info "Iniciando port-forward..."
        Write-Host "Pressione Ctrl+C para parar o port-forward" -ForegroundColor Yellow
        Write-Host ""
        kubectl port-forward -n $Namespace service/super-mario-service 8080:80
    } else {
        $startPf = Read-Host "Deseja iniciar port-forward agora? (S/N)"
        if ($startPf -eq 'S' -or $startPf -eq 's') {
            Write-Info "Iniciando port-forward..."
            Write-Host "Pressione Ctrl+C para parar o port-forward" -ForegroundColor Yellow
            Write-Host ""
            # Abrir navegador em background
            Start-Process "http://localhost:8080"
            Start-Sleep -Seconds 2
            kubectl port-forward -n $Namespace service/super-mario-service 8080:80
        }
    }

    Write-Host "`n🔍 Monitoramento:" -ForegroundColor Cyan
    Write-Host "  Ver pods:         kubectl get pods -n $Namespace --watch" -ForegroundColor Yellow
    Write-Host "  Ver HPA:          kubectl get hpa -n $Namespace --watch" -ForegroundColor Yellow
    Write-Host "  Ver métricas:     kubectl top pods -n $Namespace" -ForegroundColor Yellow
    Write-Host "  Ver logs:         kubectl logs -n $Namespace -l app=super-mario -f" -ForegroundColor Yellow

    Write-Host "`n🧪 Testes de Resiliência:" -ForegroundColor Cyan
    Write-Host "  Auto-healing:     .\test-autoheal.ps1" -ForegroundColor Yellow
    Write-Host "  Auto-scaling:     .\load-test.ps1" -ForegroundColor Yellow

    Write-Host ""

} catch {
    Write-Error-Custom "Erro durante deploy: $_"
    exit 1
} finally {
    Pop-Location
}
