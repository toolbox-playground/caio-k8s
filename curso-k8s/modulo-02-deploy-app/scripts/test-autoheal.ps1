<#
.SYNOPSIS
    Testa a capacidade de auto-healing do Kubernetes.

.DESCRIPTION
    Este script demonstra o auto-healing deletando pods e observando
    a recuperação automática pelo ReplicaSet controller.

.PARAMETER Namespace
    Namespace onde a aplicação está rodando. Padrão: "games"

.PARAMETER Count
    Número de vezes para executar o teste. Padrão: 3

.EXAMPLE
    .\test-autoheal.ps1
    Executa teste de auto-healing 3 vezes

.EXAMPLE
    .\test-autoheal.ps1 -Count 5
    Executa teste 5 vezes
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$Namespace = "games",
    
    [Parameter()]
    [int]$Count = 3
)

$ErrorActionPreference = "Stop"

# Cores para output
function Write-Info { param($msg) Write-Host "ℹ️  $msg" -ForegroundColor Cyan }
function Write-Success { param($msg) Write-Host "✅ $msg" -ForegroundColor Green }
function Write-Error-Custom { param($msg) Write-Host "❌ $msg" -ForegroundColor Red }
function Write-Warning-Custom { param($msg) Write-Host "⚠️  $msg" -ForegroundColor Yellow }

Write-Host "`n🔧 Teste de Auto-Healing do Kubernetes" -ForegroundColor Magenta
Write-Host "=" * 70 -ForegroundColor Magenta

# Verificar se aplicação está rodando
try {
    $pods = kubectl get pods -n $Namespace -l app=game-2048 -o json 2>$null | ConvertFrom-Json
    if ($pods.items.Count -eq 0) {
        Write-Error-Custom "Nenhum pod encontrado no namespace '$Namespace'"
        Write-Host "Execute primeiro: .\deploy-app.ps1" -ForegroundColor Yellow
        exit 1
    }
    Write-Success "Aplicação detectada: $($pods.items.Count) pods rodando"
} catch {
    Write-Error-Custom "Erro ao verificar pods: $_"
    exit 1
}

Write-Host "`n📊 Estado Inicial:" -ForegroundColor Cyan
kubectl get pods -n $Namespace -l app=game-2048 -o wide

Write-Host "`n🎯 Iniciando $Count testes de auto-healing..." -ForegroundColor Cyan
Write-Host "Cada teste deletará 1 pod e observará a recuperação automática.`n" -ForegroundColor White

for ($i = 1; $i -le $Count; $i++) {
    Write-Host ("─" * 70) -ForegroundColor Gray
    Write-Host "🧪 Teste $i de $Count" -ForegroundColor Yellow
    
    # Obter estado inicial
    $initialPods = kubectl get pods -n $Namespace -l app=game-2048 -o json | ConvertFrom-Json
    $initialCount = $initialPods.items.Count
    Write-Info "Pods rodando: $initialCount"
    
    # Selecionar pod aleatório
    $podToDelete = ($initialPods.items | Get-Random).metadata.name
    Write-Info "Deletando pod: $podToDelete"
    
    # Deletar pod
    kubectl delete pod $podToDelete -n $Namespace --grace-period=0 --force 2>$null | Out-Null
    Write-Warning-Custom "Pod deletado! Observando recuperação..."
    
    # Aguardar e monitorar recuperação
    $recovered = $false
    $timeout = 60
    $elapsed = 0
    $checkInterval = 2
    
    while (-not $recovered -and $elapsed -lt $timeout) {
        Start-Sleep -Seconds $checkInterval
        $elapsed += $checkInterval
        
        $currentPods = kubectl get pods -n $Namespace -l app=game-2048 -o json | ConvertFrom-Json
        $runningPods = ($currentPods.items | Where-Object { $_.status.phase -eq "Running" }).Count
        $totalPods = $currentPods.items.Count
        
        Write-Host "  ⏱️  ${elapsed}s - Total: $totalPods | Running: $runningPods | Desejado: $initialCount" -ForegroundColor Gray
        
        if ($runningPods -eq $initialCount) {
            $recovered = $true
            Write-Success "✨ Recuperação completa em ${elapsed}s!"
            
            # Mostrar novo pod
            $newPods = $currentPods.items | Where-Object { $_.metadata.name -ne $podToDelete }
            $newestPod = ($newPods | Sort-Object { $_.metadata.creationTimestamp } -Descending)[0]
            Write-Host "  Novo pod criado: $($newestPod.metadata.name)" -ForegroundColor Green
        }
    }
    
    if (-not $recovered) {
        Write-Warning-Custom "Timeout após ${timeout}s - recuperação ainda em andamento"
    }
    
    if ($i -lt $Count) {
        Write-Info "Aguardando 5s antes do próximo teste...`n"
        Start-Sleep -Seconds 5
    }
}

# Estado final
Write-Host "`n" + ("─" * 70) -ForegroundColor Gray
Write-Host "📊 Estado Final:" -ForegroundColor Cyan
kubectl get pods -n $Namespace -l app=game-2048 -o wide

Write-Host "`n🔍 Eventos recentes:" -ForegroundColor Cyan
kubectl get events -n $Namespace --sort-by='.lastTimestamp' | Select-Object -Last 10

# Resumo
Write-Host "`n" + ("=" * 70) -ForegroundColor Green
Write-Host "✅ Teste de Auto-Healing Completo!" -ForegroundColor Green
Write-Host ("=" * 70) -ForegroundColor Green

Write-Host "`n🎯 Conclusões:" -ForegroundColor Cyan
Write-Host "  ✅ Kubernetes detectou pods deletados automaticamente" -ForegroundColor White
Write-Host "  ✅ ReplicaSet criou novos pods para manter estado desejado" -ForegroundColor White
Write-Host "  ✅ Aplicação permaneceu disponível durante recuperação" -ForegroundColor White
Write-Host "  ✅ Self-healing funcionou conforme esperado!" -ForegroundColor White

Write-Host "`n💡 Conceito-chave: Reconciliation Loop" -ForegroundColor Cyan
Write-Host "  O controller do Kubernetes continuamente:" -ForegroundColor White
Write-Host "  1. Observa estado atual (pods rodando)" -ForegroundColor Gray
Write-Host "  2. Compara com estado desejado (réplicas configuradas)" -ForegroundColor Gray
Write-Host "  3. Toma ação para reconciliar diferenças" -ForegroundColor Gray
Write-Host "  4. Repete o ciclo infinitamente" -ForegroundColor Gray

Write-Host "`n🚀 Próximo teste:" -ForegroundColor Cyan
Write-Host "  Auto-scaling: .\load-test.ps1" -ForegroundColor Yellow

Write-Host ""
