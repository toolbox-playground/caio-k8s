<#
.SYNOPSIS
    Gera carga para testar auto-scaling do Kubernetes (HPA).

.DESCRIPTION
    Este script cria pods que geram carga HTTP contínua na aplicação,
    permitindo observar o Horizontal Pod Autoscaler em ação.

.PARAMETER Namespace
    Namespace onde a aplicação está rodando. Padrão: "games"

.PARAMETER LoadGenerators
    Número de pods geradores de carga. Padrão: 5

.PARAMETER Duration
    Duração do teste em segundos. Padrão: 300 (5 minutos)

.EXAMPLE
    .\load-test.ps1
    Executa teste de carga padrão (5 geradores, 5 minutos)

.EXAMPLE
    .\load-test.ps1 -LoadGenerators 10 -Duration 600
    Teste intenso: 10 geradores por 10 minutos
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$Namespace = "games",
    
    [Parameter()]
    [int]$LoadGenerators = 5,
    
    [Parameter()]
    [int]$Duration = 300
)

$ErrorActionPreference = "Stop"

# Cores para output
function Write-Info { param($msg) Write-Host "ℹ️  $msg" -ForegroundColor Cyan }
function Write-Success { param($msg) Write-Host "✅ $msg" -ForegroundColor Green }
function Write-Error-Custom { param($msg) Write-Host "❌ $msg" -ForegroundColor Red }
function Write-Warning-Custom { param($msg) Write-Host "⚠️  $msg" -ForegroundColor Yellow }

Write-Host "`n⚡ Teste de Auto-Scaling (HPA)" -ForegroundColor Magenta
Write-Host "=" * 70 -ForegroundColor Magenta

# Verificar HPA
Write-Info "Verificando HPA..."
try {
    $hpa = kubectl get hpa -n $Namespace -o json 2>$null | ConvertFrom-Json
    if ($hpa.items.Count -eq 0) {
        Write-Warning-Custom "Nenhum HPA encontrado no namespace '$Namespace'"
        $continue = Read-Host "Deseja continuar mesmo assim? (S/N)"
        if ($continue -ne 'S' -and $continue -ne 's') {
            exit 0
        }
    } else {
        Write-Success "HPA detectado: $($hpa.items[0].metadata.name)"
    }
} catch {
    Write-Warning-Custom "Não foi possível verificar HPA"
}

# Verificar métricas
Write-Info "Verificando se métricas estão disponíveis..."
try {
    kubectl top nodes 2>$null | Out-Null
    kubectl top pods -n $Namespace 2>$null | Out-Null
    Write-Success "Métricas disponíveis"
} catch {
    Write-Warning-Custom "Métricas não disponíveis - HPA pode não funcionar corretamente"
    Write-Host "  Aguarde 1-2 minutos após criar o cluster" -ForegroundColor Yellow
}

# Estado inicial
Write-Host "`n📊 Estado Inicial:" -ForegroundColor Cyan
Write-Host "Pods:" -ForegroundColor White
kubectl get pods -n $Namespace -l app=game-2048

Write-Host "`nHPA:" -ForegroundColor White
kubectl get hpa -n $Namespace 2>$null

Write-Host "`nMétricas:" -ForegroundColor White
kubectl top pods -n $Namespace 2>$null

# Preparar teste
Write-Host "`n⚙️  Configuração do Teste:" -ForegroundColor Cyan
Write-Host "  Geradores de carga: $LoadGenerators" -ForegroundColor White
Write-Host "  Duração: $Duration segundos ($([math]::Round($Duration/60, 1)) minutos)" -ForegroundColor White
Write-Host "  Namespace: $Namespace" -ForegroundColor White

$confirm = Read-Host "`nIniciar teste de carga? (S/N)"
if ($confirm -ne 'S' -and $confirm -ne 's') {
    Write-Info "Teste cancelado pelo usuário"
    exit 0
}

# Criar geradores de carga
Write-Host "`n🚀 Criando geradores de carga..." -ForegroundColor Yellow

$generatorNames = @()
for ($i = 1; $i -le $LoadGenerators; $i++) {
    $generatorName = "load-generator-$i"
    $generatorNames += $generatorName
    
    Write-Host "  Criando $generatorName..." -NoNewline
    kubectl run $generatorName -n $Namespace `
        --image=busybox `
        --restart=Never `
        -- /bin/sh -c "while true; do wget -q -O- http://game-2048-service; done" 2>$null | Out-Null
    Write-Host " ✓" -ForegroundColor Green
}

Write-Success "Todos os geradores criados!"

# Instruções de monitoramento
Write-Host "`n" + ("=" * 70) -ForegroundColor Yellow
Write-Host "📺 ABRA NOVOS TERMINAIS PARA MONITORAMENTO:" -ForegroundColor Yellow
Write-Host ("=" * 70) -ForegroundColor Yellow

Write-Host "`nTerminal 1 - Monitorar HPA:" -ForegroundColor Cyan
Write-Host "  kubectl get hpa -n $Namespace --watch" -ForegroundColor White

Write-Host "`nTerminal 2 - Monitorar Pods:" -ForegroundColor Cyan
Write-Host "  kubectl get pods -n $Namespace --watch" -ForegroundColor White

Write-Host "`nTerminal 3 - Monitorar Métricas:" -ForegroundColor Cyan
Write-Host @"
  while (`$true) {
    Clear-Host
    Write-Host '=== Métricas de CPU ===' -ForegroundColor Cyan
    kubectl top pods -n $Namespace
    Start-Sleep -Seconds 5
  }
"@ -ForegroundColor White

# Monitoramento durante o teste
Write-Host "`n" + ("=" * 70) -ForegroundColor Green
Write-Host "⏱️  Teste em andamento - $Duration segundos" -ForegroundColor Green
Write-Host ("=" * 70) -ForegroundColor Green

$startTime = Get-Date
$endTime = $startTime.AddSeconds($Duration)

Write-Host "`n🔍 Observações a cada 30 segundos:`n" -ForegroundColor Cyan

while ((Get-Date) -lt $endTime) {
    $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds)
    $remaining = [math]::Round(($endTime - (Get-Date)).TotalSeconds)
    
    Write-Host ("─" * 70) -ForegroundColor Gray
    Write-Host "⏱️  Tempo: ${elapsed}s / ${Duration}s (restam ${remaining}s)" -ForegroundColor Yellow
    
    # Métricas atuais
    Write-Host "`nPods da aplicação:" -ForegroundColor White
    kubectl get pods -n $Namespace -l app=game-2048 --no-headers | ForEach-Object { Write-Host "  $_" }
    
    Write-Host "`nHPA:" -ForegroundColor White
    $hpaStatus = kubectl get hpa -n $Namespace --no-headers 2>$null
    if ($hpaStatus) {
        Write-Host "  $hpaStatus"
    }
    
    Write-Host "`nCPU (top 5 pods):" -ForegroundColor White
    kubectl top pods -n $Namespace 2>$null | Select-Object -First 6 | ForEach-Object { 
        if ($_ -notmatch "NAME") { Write-Host "  $_" }
    }
    
    Write-Host ""
    Start-Sleep -Seconds 30
}

# Teste completo - parar geradores
Write-Host "`n" + ("=" * 70) -ForegroundColor Yellow
Write-Host "🛑 Tempo esgotado - Parando geradores de carga..." -ForegroundColor Yellow
Write-Host ("=" * 70) -ForegroundColor Yellow

foreach ($generator in $generatorNames) {
    Write-Host "  Deletando $generator..." -NoNewline
    kubectl delete pod $generator -n $Namespace --grace-period=0 2>$null | Out-Null
    Write-Host " ✓" -ForegroundColor Green
}

Write-Success "Todos os geradores deletados!"

# Observar scale down
Write-Host "`n🔍 Observando scale down (aguarde 60-90 segundos)..." -ForegroundColor Cyan
Write-Host "HPA tem stabilizationWindow de 60s antes de reduzir pods`n" -ForegroundColor Gray

for ($i = 0; $i -lt 120; $i += 15) {
    Write-Host "⏱️  ${i}s após parar carga:" -ForegroundColor Yellow
    
    Write-Host "Pods:" -ForegroundColor White
    kubectl get pods -n $Namespace -l app=game-2048 --no-headers | ForEach-Object { Write-Host "  $_" }
    
    Write-Host "`nHPA:" -ForegroundColor White
    kubectl get hpa -n $Namespace --no-headers | ForEach-Object { Write-Host "  $_" }
    
    Write-Host ""
    Start-Sleep -Seconds 15
}

# Estado final
Write-Host "`n" + ("=" * 70) -ForegroundColor Green
Write-Host "✅ Teste de Auto-Scaling Completo!" -ForegroundColor Green
Write-Host ("=" * 70) -ForegroundColor Green

Write-Host "`n📊 Estado Final:" -ForegroundColor Cyan
Write-Host "Pods:" -ForegroundColor White
kubectl get pods -n $Namespace -l app=game-2048

Write-Host "`nHPA:" -ForegroundColor White
kubectl get hpa -n $Namespace

Write-Host "`nMétricas:" -ForegroundColor White
kubectl top pods -n $Namespace 2>$null

# Eventos recentes
Write-Host "`n🔍 Eventos de scaling:" -ForegroundColor Cyan
kubectl get events -n $Namespace --sort-by='.lastTimestamp' | 
    Select-String -Pattern "Scaled|HorizontalPodAutoscaler" | 
    Select-Object -Last 10

# Resumo e análise
Write-Host "`n" + ("=" * 70) -ForegroundColor Magenta
Write-Host "📈 Análise dos Resultados" -ForegroundColor Magenta
Write-Host ("=" * 70) -ForegroundColor Magenta

Write-Host "`n✅ O que você deve ter observado:" -ForegroundColor Cyan
Write-Host "  1. CPU aumentou nos pods existentes" -ForegroundColor White
Write-Host "  2. HPA detectou uso acima do target (50%)" -ForegroundColor White
Write-Host "  3. Novos pods foram criados (scale up)" -ForegroundColor White
Write-Host "  4. Carga foi distribuída entre os pods" -ForegroundColor White
Write-Host "  5. Após remover carga, HPA aguardou 60s (stabilizationWindow)" -ForegroundColor White
Write-Host "  6. Pods foram removidos gradualmente (scale down)" -ForegroundColor White

Write-Host "`n💡 Fórmula do HPA:" -ForegroundColor Cyan
Write-Host "  desiredReplicas = ⌈currentReplicas × (currentCPU / targetCPU)⌉" -ForegroundColor Gray
Write-Host "`n  Exemplo:" -ForegroundColor White
Write-Host "    2 pods @ 80% CPU → ⌈2 × (80/50)⌉ = 4 pods" -ForegroundColor Gray
Write-Host "    4 pods @ 90% CPU → ⌈4 × (90/50)⌉ = 8 pods" -ForegroundColor Gray

Write-Host "`n🎯 Conclusões:" -ForegroundColor Cyan
Write-Host "  ✅ HPA monitora métricas a cada 15s (padrão)" -ForegroundColor White
Write-Host "  ✅ Scale up é rápido (responde imediatamente)" -ForegroundColor White
Write-Host "  ✅ Scale down é gradual (evita flapping)" -ForegroundColor White
Write-Host "  ✅ Aplicação mantém performance sob carga" -ForegroundColor White

Write-Host "`n🔧 Para ajustar comportamento:" -ForegroundColor Cyan
Write-Host "  Edite: ..\manifests\03-hpa.yaml" -ForegroundColor Yellow
Write-Host "  - minReplicas/maxReplicas: limites de scaling" -ForegroundColor Gray
Write-Host "  - averageUtilization: % de CPU alvo" -ForegroundColor Gray
Write-Host "  - behavior: políticas de scale up/down" -ForegroundColor Gray

Write-Host ""
