# Simple tier accuracy test
$cpus = @(Get-Content data/cpuSorted.json | ConvertFrom-Json)
$gpus = @(Get-Content data/gpuSorted.json | ConvertFrom-Json)
$rams = @(Get-Content data/ramSorted.json | ConvertFrom-Json)

# Ensure arrays
if ($cpus -isnot [array]) { $cpus = @($cpus) }
if ($gpus -isnot [array]) { $gpus = @($gpus) }
if ($rams -isnot [array]) { $rams = @($rams) }

Write-Host "CPU TIERS (showing best & worst per tier):" -ForegroundColor Cyan
for ($t = 7; $t -ge 1; $t--) {
    $tier = @($cpus | Where-Object { $_.tier -eq $t })
    if ($tier.Count -gt 0) {
        $sorted = $tier | Sort-Object @{e={[double]$_.boost_clock}} -Descending
        $best = $sorted[0]
        $worst = $sorted[-1]
        Write-Host ("T{0}: {1}GHz best | {2}GHz worst" -f $t, $best.boost_clock, $worst.boost_clock)
    }
}

Write-Host "`nGPU TIERS (showing best & worst per tier):" -ForegroundColor Cyan
for ($t = 7; $t -ge 1; $t--) {
    $tier = @($gpus | Where-Object { $_.tier -eq $t })
    if ($tier.Count -gt 0) {
        $sorted = $tier | Sort-Object @{e={[double]$_.boost_clock}} -Descending
        $best = $sorted[0]
        $worst = $sorted[-1]
        Write-Host ("T{0}: {1}MHz best | {2}MHz worst" -f $t, $best.boost_clock, $worst.boost_clock)
    }
}

Write-Host "`nRAM TIERS (showing best & worst per tier):" -ForegroundColor Cyan
for ($t = 7; $t -ge 1; $t--) {
    $tier = @($rams | Where-Object { $_.tier -eq $t })
    if ($tier.Count -gt 0) {
        $sorted = $tier | Sort-Object @{e={$_.speed}} -Descending
        $best = $sorted[0]
        $worst = $sorted[-1]
        Write-Host ("T{0}: {1} best | {2} worst" -f $t, $best.speed, $worst.speed)
    }
}
