# Test tier accuracy
$cpus = @(Get-Content data/cpuSorted.json | ConvertFrom-Json)
$gpus = @(Get-Content data/gpuSorted.json | ConvertFrom-Json)
$rams = @(Get-Content data/ramSorted.json | ConvertFrom-Json)

# Ensure we have arrays
if ($cpus -isnot [array]) { $cpus = @($cpus) }
if ($gpus -isnot [array]) { $gpus = @($gpus) }
if ($rams -isnot [array]) { $rams = @($rams) }

Write-Host "=== CPU TIER ACCURACY ===" -ForegroundColor Cyan
Write-Host "Total CPUs: $($cpus.Count)" -ForegroundColor Yellow
Write-Host ""

for ($t = 7; $t -ge 1; $t--) {
    $tierCPUs = @($cpus | Where-Object { $_.tier -eq $t })
    if ($tierCPUs.Count -gt 0) {
        $best = $tierCPUs | Sort-Object @{e={[double]$_.boost_clock}}, @{e={[int]$_.core_count}} -Descending | Select-Object -First 1
        $worst = $tierCPUs | Sort-Object @{e={[double]$_.boost_clock}}, @{e={[int]$_.core_count}} | Select-Object -First 1
        Write-Host "Tier $t (Count: $($tierCPUs.Count)):"
        Write-Host "  Best:  $($best.name) - $($best.core_count)c @$($best.boost_clock)GHz Gen$($best.generation)"
        Write-Host "  Worst: $($worst.name) - $($worst.core_count)c @$($worst.boost_clock)GHz Gen$($worst.generation)"
    }
}

Write-Host ""
Write-Host "=== GPU TIER ACCURACY ===" -ForegroundColor Cyan
Write-Host "Total GPUs: $($gpus.Count)" -ForegroundColor Yellow
Write-Host ""

for ($t = 7; $t -ge 1; $t--) {
    $tierGPUs = @($gpus | Where-Object { $_.tier -eq $t })
    if ($tierGPUs.Count -gt 0) {
        $best = $tierGPUs | Sort-Object @{e={[double]$_.boost_clock}}, @{e={[int]$_.memory}} -Descending | Select-Object -First 1
        $worst = $tierGPUs | Sort-Object @{e={[double]$_.boost_clock}}, @{e={[int]$_.memory}} | Select-Object -First 1
        Write-Host "Tier $t (Count: $($tierGPUs.Count)):"
        Write-Host "  Best:  $($best.chipset) - $($best.memory)GB @$($best.boost_clock)MHz Gen$($best.generation)"
        Write-Host "  Worst: $($worst.chipset) - $($worst.memory)GB @$($worst.boost_clock)MHz Gen$($worst.generation)"
    }
}

Write-Host ""
Write-Host "=== RAM TIER ACCURACY ===" -ForegroundColor Cyan
Write-Host "Total RAM: $($rams.Count)" -ForegroundColor Yellow
Write-Host ""

for ($t = 7; $t -ge 1; $t--) {
    $tierRAMs = @($rams | Where-Object { $_.tier -eq $t })
    if ($tierRAMs.Count -gt 0) {
        # Extract MHz from speed field
        $bestRAM = $tierRAMs | Sort-Object @{e={[int]($_.speed -replace '[^0-9]' , '')}}, @{e={[int]$_.memory}} -Descending | Select-Object -First 1
        $worstRAM = $tierRAMs | Sort-Object @{e={[int]($_.speed -replace '[^0-9]', '')}}, @{e={[int]$_.memory}} | Select-Object -First 1
        $bestMHz = $bestRAM.speed -replace '[^0-9]', ''
        $worstMHz = $worstRAM.speed -replace '[^0-9]', ''
        Write-Host "Tier $t (Count: $($tierRAMs.Count)):"
        Write-Host "  Best:  $($bestRAM.name) - $($bestRAM.memory)GB @$bestMHz MHz CAS$($bestRAM.cas_latency)"
        Write-Host "  Worst: $($worstRAM.name) - $($worstRAM.memory)GB @$worstMHz MHz CAS$($worstRAM.cas_latency)"
    }
}
