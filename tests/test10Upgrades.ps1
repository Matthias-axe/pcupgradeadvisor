# Comprehensive 10-test upgrade accuracy check
$cpus = @(Get-Content data/cpuSorted.json | ConvertFrom-Json)
$gpus = @(Get-Content data/gpuSorted.json | ConvertFrom-Json)
$rams = @(Get-Content data/ramSorted.json | ConvertFrom-Json)

if ($cpus -isnot [array]) { $cpus = @($cpus) }
if ($gpus -isnot [array]) { $gpus = @($gpus) }
if ($rams -isnot [array]) { $rams = @($rams) }

Write-Host "`n==== CPU UPGRADE TESTS (10 samples) ====" -ForegroundColor Cyan
$testCount = 0
for ($fromTier = 7; $fromTier -ge 2; $fromTier--) {
    if ($testCount -ge 10) { break }
    $toTier = $fromTier - 1
    
    $from = @($cpus | Where-Object { $_.tier -eq $fromTier }) | Get-Random
    $to = @($cpus | Where-Object { $_.tier -eq $toTier }) | Get-Random
    
    $fromClock = [double]$from.boost_clock
    $toClock = [double]$to.boost_clock
    $isUpgrade = $toClock -gt $fromClock
    
    $testCount++
    $status = if ($isUpgrade) { "✓ UPGRADE" } else { "✗ DOWNGRADE" }
    Write-Host "`nTest $testCount (T$fromTier→T$toTier): $status"
    Write-Host "  From: $($from.name) - $($from.core_count)c @$fromClock GHz"
    Write-Host "  To:   $($to.name) - $($to.core_count)c @$toClock GHz"
}

Write-Host "`n`n==== GPU UPGRADE TESTS (10 samples) ====" -ForegroundColor Cyan
$testCount = 0
for ($fromTier = 7; $fromTier -ge 2; $fromTier--) {
    if ($testCount -ge 10) { break }
    $toTier = $fromTier - 1
    
    $from = @($gpus | Where-Object { $_.tier -eq $fromTier }) | Get-Random
    $to = @($gpus | Where-Object { $_.tier -eq $toTier }) | Get-Random
    
    $fromClock = [double]$from.boost_clock
    $toClock = [double]$to.boost_clock
    $isUpgrade = $toClock -gt $fromClock
    
    $testCount++
    $status = if ($isUpgrade) { "✓ UPGRADE" } else { "✗ DOWNGRADE" }
    Write-Host "`nTest $testCount (T$fromTier→T$toTier): $status"
    Write-Host "  From: $($from.chipset) - $($from.memory)GB @$fromClock MHz Gen$($from.generation)"
    Write-Host "  To:   $($to.chipset) - $($to.memory)GB @$toClock MHz Gen$($to.generation)"
}

Write-Host "`n`n==== RAM UPGRADE TESTS (10 samples) ====" -ForegroundColor Cyan
$testCount = 0
for ($fromTier = 7; $fromTier -ge 2; $fromTier--) {
    if ($testCount -ge 10) { break }
    $toTier = $fromTier - 1
    
    $from = @($rams | Where-Object { $_.tier -eq $fromTier }) | Get-Random
    $to = @($rams | Where-Object { $_.tier -eq $toTier }) | Get-Random
    
    $isUpgrade = $to.speed -gt $from.speed
    
    $testCount++
    $status = if ($isUpgrade) { "✓ UPGRADE" } else { "✗ DOWNGRADE" }
    Write-Host "`nTest $testCount (T$fromTier→T$toTier): $status"
    Write-Host "  From: $($from.name) - $($from.memory)GB @$($from.speed)"
    Write-Host "  To:   $($to.name) - $($to.memory)GB @$($to.speed)"
}

# Summary statistics
Write-Host "`n`n==== ACCURACY SUMMARY ====" -ForegroundColor Yellow
$cpuUpgrades = 0
$cpuTotal = 0
for ($t = 7; $t -ge 2; $t--) {
    $fromList = @($cpus | Where-Object { $_.tier -eq $t })
    $toList = @($cpus | Where-Object { $_.tier -eq ($t-1) })
    if ($fromList.Count -gt 0 -and $toList.Count -gt 0) {
        $avgFrom = ($fromList | Measure-Object -Property boost_clock -Average).Average
        $avgTo = ($toList | Measure-Object -Property boost_clock -Average).Average
        if ([double]$avgTo -gt [double]$avgFrom) { $cpuUpgrades++ }
        $cpuTotal++
    }
}

$gpuUpgrades = 0
$gpuTotal = 0
for ($t = 7; $t -ge 2; $t--) {
    $fromList = @($gpus | Where-Object { $_.tier -eq $t })
    $toList = @($gpus | Where-Object { $_.tier -eq ($t-1) })
    if ($fromList.Count -gt 0 -and $toList.Count -gt 0) {
        $avgFrom = ($fromList | Measure-Object -Property boost_clock -Average).Average
        $avgTo = ($toList | Measure-Object -Property boost_clock -Average).Average
        if ([double]$avgTo -gt [double]$avgFrom) { $gpuUpgrades++ }
        $gpuTotal++
    }
}

$ramUpgrades = 0
$ramTotal = 0
for ($t = 7; $t -ge 2; $t--) {
    $fromList = @($rams | Where-Object { $_.tier -eq $t })
    $toList = @($rams | Where-Object { $_.tier -eq ($t-1) })
    if ($fromList.Count -gt 0 -and $toList.Count -gt 0) {
        $avgFrom = ($fromList | Measure-Object -Property speed -Average).Average
        $avgTo = ($toList | Measure-Object -Property speed -Average).Average
        if ($avgTo -gt $avgFrom) { $ramUpgrades++ }
        $ramTotal++
    }
}

Write-Host "CPU: $cpuUpgrades/$cpuTotal tier transitions are upgrades"
Write-Host "GPU: $gpuUpgrades/$gpuTotal tier transitions are upgrades"
Write-Host "RAM: $ramUpgrades/$ramTotal tier transitions are upgrades"
