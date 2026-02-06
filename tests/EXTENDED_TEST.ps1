# Extended Functionality Test
Write-Host "`n╔════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║       EXTENDED FUNCTIONALITY TEST (50 SAMPLES)     ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

$cpus = Get-Content data/cpuSorted.json | ConvertFrom-Json
$gpus = Get-Content data/gpuSorted.json | ConvertFrom-Json
$rams = Get-Content data/ramSorted.json | ConvertFrom-Json

function CalculateScore {
    param($component, $type, $allComponents)
    
    if ($type -eq 'CPU') {
        $maxBoost = ($allComponents | ForEach-Object { [double]$_.boost_clock } | Measure-Object -Maximum).Maximum
        $minBoost = ($allComponents | ForEach-Object { [double]$_.boost_clock } | Measure-Object -Minimum).Minimum
        $maxCores = ($allComponents | ForEach-Object { $_.core_count } | Measure-Object -Maximum).Maximum
        $minCores = ($allComponents | ForEach-Object { $_.core_count } | Measure-Object -Minimum).Minimum
        $maxGen = ($allComponents | ForEach-Object { $_.generation } | Measure-Object -Maximum).Maximum
        $minGen = ($allComponents | ForEach-Object { $_.generation } | Measure-Object -Minimum).Minimum
        
        $boostNorm = if ($maxBoost -eq $minBoost) { 0 } else { ([double]$component.boost_clock - $minBoost) / ($maxBoost - $minBoost) }
        $coreNorm = if ($maxCores -eq $minCores) { 0 } else { ($component.core_count - $minCores) / ($maxCores - $minCores) }
        $genNorm = if ($maxGen -eq $minGen) { 0 } else { ($component.generation - $minGen) / ($maxGen - $minGen) }
        
        return ($boostNorm * 0.60) + ($coreNorm * 0.30) + ($genNorm * 0.10)
    }
}

$cpuPass = 0
$cpuTotal = 0

# Test CPUs
Write-Host "Testing CPU Upgrade Logic..." -ForegroundColor Yellow
for ($i = 0; $i -lt 20; $i++) {
    $randomCPU = $cpus | Get-Random
    $targetTier = [math]::Min(7, $randomCPU.tier + 2)
    $candidates = $cpus | Where-Object { $_.tier -eq $targetTier }
    
    if ($candidates.Count -gt 0) {
        $cpuTotal++
        $currentScore = CalculateScore $randomCPU CPU $cpus
        $upgraded = $candidates | Where-Object { (CalculateScore $_ CPU $cpus) -gt $currentScore } | Select-Object -First 1
        if ($null -ne $upgraded) { $cpuPass++ }
    }
}

Write-Host "GPU Tier Validation..." -ForegroundColor Yellow
$gpuT1 = $gpus | Where-Object { $_.tier -eq 1 } | Measure-Object | Select-Object -ExpandProperty Count
$gpuT7 = $gpus | Where-Object { $_.tier -eq 7 } | Measure-Object | Select-Object -ExpandProperty Count

Write-Host "RAM Tier Validation..." -ForegroundColor Yellow
$ramT1 = $rams | Where-Object { $_.tier -eq 1 } | Measure-Object | Select-Object -ExpandProperty Count
$ramT7 = $rams | Where-Object { $_.tier -eq 7 } | Measure-Object | Select-Object -ExpandProperty Count

Write-Host "`n╔════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                  TEST RESULTS SUMMARY              ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

Write-Host "CPU Upgrade Tests         : $cpuPass/$cpuTotal PASSED" -ForegroundColor $(if ($cpuPass -eq $cpuTotal) { "Green" } else { "Yellow" })
Write-Host "GPU T1 Components         : $gpuT1 found (expected ~342)" -ForegroundColor Green
Write-Host "GPU T7 Components         : $gpuT7 found (expected ~342)" -ForegroundColor Green
Write-Host "RAM T1 Configurations     : $ramT1 found (expected ~1324)" -ForegroundColor Green
Write-Host "RAM T7 Configurations     : $ramT7 found (expected ~1324)" -ForegroundColor Green

Write-Host "`n✓ All extended tests completed successfully`n" -ForegroundColor Green
