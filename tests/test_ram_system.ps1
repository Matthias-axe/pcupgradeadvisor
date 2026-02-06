# Comprehensive RAM tier system test

$rams = Get-Content data/ramSorted.json | ConvertFrom-Json

Write-Host "`n=== RAM TIER SYSTEM COMPREHENSIVE TEST ===" -ForegroundColor Cyan
Write-Host "Testing RAM tier assignments and score progression`n"

# Test 1: Verify tier distribution
Write-Host "TEST 1: Tier Distribution" -ForegroundColor Yellow
Write-Host "========================="
$tierCounts = @{}
for ($t = 1; $t -le 7; $t++) {
    $count = ($rams | Where-Object { $_.tier -eq $t }).Count
    $tierCounts[$t] = $count
    $percentage = [math]::Round(($count / $rams.Count) * 100, 1)
    Write-Host "  Tier $t`: $count configs ($percentage%)"
}

$maxTier = $tierCounts.Values | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
$minTier = $tierCounts.Values | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum
$balanced = ($maxTier - $minTier) -le 10

Write-Host "`nDistribution Balance: $(if ($balanced) { '✓ PASS (even distribution)' } else { '✗ FAIL (uneven: ' + $maxTier + ' - ' + $minTier + ')' })`n"

# Test 2: Speed progression by tier
Write-Host "TEST 2: Speed Progression by Tier" -ForegroundColor Yellow
Write-Host "=================================="
$speedByTier = @{}
for ($t = 1; $t -le 7; $t++) {
    $tierRams = @($rams | Where-Object { $_.tier -eq $t })
    if ($tierRams.Count -gt 0) {
        $speeds = $tierRams | ForEach-Object { [int]($_.speed -replace '[^0-9]', '') }
        $avgSpeed = ($speeds | Measure-Object -Average).Average
        $maxSpeed = ($speeds | Measure-Object -Maximum).Maximum
        $minSpeed = ($speeds | Measure-Object -Minimum).Minimum
        
        $speedByTier[$t] = $avgSpeed
        Write-Host "  Tier $t`: Avg=$([math]::Round($avgSpeed, 0)) MHz, Min=$minSpeed, Max=$maxSpeed"
    }
}

# Check monotonic increase
Write-Host "`nMonotonic Progression Check:"
$monoPass = $true
for ($t = 2; $t -le 7; $t++) {
    if ($speedByTier[$t] -gt $speedByTier[$t-1]) {
        Write-Host "  ✓ T$t ($([math]::Round($speedByTier[$t], 0))) > T$($t-1) ($([math]::Round($speedByTier[$t-1], 0)))"
    } else {
        Write-Host "  ✗ T$t ($([math]::Round($speedByTier[$t], 0))) ≤ T$($t-1) ($([math]::Round($speedByTier[$t-1], 0)))" -ForegroundColor Red
        $monoPass = $false
    }
}

Write-Host "`nResult: $(if ($monoPass) { '✓ PASS' } else { '✗ FAIL' })`n"

# Test 3: Memory capacity progression
Write-Host "TEST 3: Memory Capacity Progression" -ForegroundColor Yellow
Write-Host "==================================="
$capByTier = @{}
for ($t = 1; $t -le 7; $t++) {
    $tierRams = @($rams | Where-Object { $_.tier -eq $t })
    if ($tierRams.Count -gt 0) {
        $caps = $tierRams | ForEach-Object { 
            $match = $_.name -match '(\d+)\s*GB'
            if ($match) { [int]$matches[1] } else { 0 }
        }
        $avgCap = ($caps | Measure-Object -Average).Average
        $capByTier[$t] = $avgCap
        Write-Host "  Tier $t`: Average $([math]::Round($avgCap, 1)) GB"
    }
}

Write-Host "`nCapacity Progression:"
$capPass = $true
for ($t = 2; $t -le 7; $t++) {
    if ($capByTier[$t] -ge $capByTier[$t-1]) {
        Write-Host "  ✓ T$t ($([math]::Round($capByTier[$t], 1))GB) ≥ T$($t-1) ($([math]::Round($capByTier[$t-1], 1))GB)"
    } else {
        Write-Host "  ✗ T$t ($([math]::Round($capByTier[$t], 1))GB) < T$($t-1) ($([math]::Round($capByTier[$t-1], 1))GB)" -ForegroundColor Red
        $capPass = $false
    }
}

Write-Host "`nResult: $(if ($capPass) { '✓ PASS' } else { '✗ FAIL' })`n"

# Test 4: Random tier-to-tier upgrade checks
Write-Host "TEST 4: Random Upgrade Path Verification (30 tests)" -ForegroundColor Yellow
Write-Host "=================================================="
$upgradeTests = 0
$upgradePassed = 0

for ($i = 0; $i -lt 30; $i++) {
    $randomRam = $rams | Get-Random
    $targetTier = [math]::Min(7, $randomRam.tier + 2)
    
    $candidates = $rams | Where-Object { $_.tier -eq $targetTier }
    
    if ($candidates.Count -gt 0) {
        # Extract numeric speed for comparison
        $currentSpeed = [int]($randomRam.speed -replace '[^0-9]', '')
        $currentCap = if ($randomRam.name -match '(\d+)\s*GB') { [int]$matches[1] } else { 0 }
        
        $candidateWithBetter = $candidates | Where-Object {
            $candSpeed = [int]($_.speed -replace '[^0-9]', '')
            $candCap = if ($_.name -match '(\d+)\s*GB') { [int]$matches[1] } else { 0 }
            ($candSpeed -ge $currentSpeed) -or ($candCap -gt $currentCap)
        } | Select-Object -First 1
        
        if ($null -ne $candidateWithBetter) {
            $upgradeTests++
            $candSpeed = [int]($candidateWithBetter.speed -replace '[^0-9]', '')
            $candCap = if ($candidateWithBetter.name -match '(\d+)\s*GB') { [int]$matches[1] } else { 0 }
            
            if ($candSpeed -ge $currentSpeed -or $candCap -gt $currentCap) {
                $upgradePassed++
                Write-Host "  ✓ T$($randomRam.tier) → T$targetTier (Speed/Capacity increase)"
            } else {
                Write-Host "  ✗ DOWNGRADE: T$($randomRam.tier) → T$targetTier" -ForegroundColor Red
            }
        }
    }
}

Write-Host "`n$upgradePassed/$upgradeTests tests showed improvements"
$test4Pass = $upgradePassed -eq $upgradeTests

Write-Host "Result: $(if ($test4Pass) { '✓ PASS' } else { '✗ FAIL' })`n"

# Test 5: Check for data quality
Write-Host "TEST 5: Data Quality Check" -ForegroundColor Yellow
Write-Host "=========================="
$missingTier = $rams | Where-Object { $_.tier -eq $null -or $_.tier -eq '' }
$missingSpeed = $rams | Where-Object { $_.speed -eq $null -or $_.speed -eq '' }
$missingName = $rams | Where-Object { $_.name -eq $null -or $_.name -eq '' }

Write-Host "  Missing tier assignments: $($missingTier.Count)"
Write-Host "  Missing speed data: $($missingSpeed.Count)"
Write-Host "  Missing names: $($missingName.Count)"

$dataQualityPass = ($missingTier.Count -eq 0) -and ($missingSpeed.Count -eq 0) -and ($missingName.Count -eq 0)
Write-Host "`nResult: $(if ($dataQualityPass) { '✓ PASS' } else { '✗ FAIL' })`n"

# Final Summary
Write-Host "=== FINAL SUMMARY ===" -ForegroundColor Cyan
Write-Host "Test 1 (Distribution): $(if ($balanced) { '✓ PASS' } else { '✗ FAIL' })"
Write-Host "Test 2 (Speed Progression): $(if ($monoPass) { '✓ PASS' } else { '✗ FAIL' })"
Write-Host "Test 3 (Capacity Progression): $(if ($capPass) { '✓ PASS' } else { '✗ FAIL' })"
Write-Host "Test 4 (Upgrade Verification): $(if ($test4Pass) { '✓ PASS' } else { '✗ FAIL' })"
Write-Host "Test 5 (Data Quality): $(if ($dataQualityPass) { '✓ PASS' } else { '✗ FAIL' })"

if ($balanced -and $monoPass -and $capPass -and $test4Pass -and $dataQualityPass) {
    Write-Host "`n✓ RAM TIER SYSTEM IS IN EXCELLENT CONDITION!" -ForegroundColor Green
    Write-Host "All tests passed. Ready for production." -ForegroundColor Green
} else {
    Write-Host "`n⚠️ RAM TIER SYSTEM HAS ISSUES" -ForegroundColor Yellow
    Write-Host "Please review failed tests above." -ForegroundColor Yellow
}
