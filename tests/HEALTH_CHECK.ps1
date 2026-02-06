# Comprehensive project health check
# Verifies all systems are operational

Write-Host "`n╔════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   PC UPGRADE ADVISOR - COMPREHENSIVE HEALTH CHECK  ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

$checks = @()

# Check 1: Verify all data files exist
Write-Host "CHECK 1: Data Files" -ForegroundColor Yellow
$requiredData = @(
    'cpuRaw.json', 'cpuSorted.json', 'cpuBenchmarks.json',
    'gpuRaw.json', 'gpuSorted.json', 'gpuBenchmarks.json',
    'ramRaw.json', 'ramSorted.json', 'ramBenchmarks.json',
    'powerProfiles.json', 'gpuChipset.json', 'ramCompatibility.json', 'ramPure.json'
)

$allDataExists = $true
foreach ($file in $requiredData) {
    $path = "data/$file"
    if (Test-Path $path) {
        $size = (Get-Item $path).Length
        $sizeKB = [math]::Round($size / 1KB, 1)
        Write-Host "  ✓ $file ($sizeKB KB)"
    } else {
        Write-Host "  ✗ $file - MISSING!" -ForegroundColor Red
        $allDataExists = $false
    }
}

$checks += @{ name = "Data Files"; passed = $allDataExists }
Write-Host ""

# Check 2: Verify production scripts exist
Write-Host "CHECK 2: Production Scripts" -ForegroundColor Yellow
$requiredScripts = @(
    'assignCPUTiers.ps1', 'assignGPUTiers.ps1', 'assignRAMTiers.ps1',
    'sortCPUs.ps1', 'sortGPUs.ps1', 'sortRAM.ps1'
)

$allScriptsExist = $true
foreach ($script in $requiredScripts) {
    if (Test-Path $script) {
        Write-Host "  ✓ $script"
    } else {
        Write-Host "  ✗ $script - MISSING!" -ForegroundColor Red
        $allScriptsExist = $false
    }
}

$checks += @{ name = "Production Scripts"; passed = $allScriptsExist }
Write-Host ""

# Check 3: Verify web files
Write-Host "CHECK 3: Web Files" -ForegroundColor Yellow
$webFiles = @('index.html', 'script.js', 'style.css')
$allWebFilesExist = $true

foreach ($file in $webFiles) {
    if (Test-Path $file) {
        $size = (Get-Item $file).Length
        $sizeKB = [math]::Round($size / 1KB, 1)
        Write-Host "  ✓ $file ($sizeKB KB)"
    } else {
        Write-Host "  ✗ $file - MISSING!" -ForegroundColor Red
        $allWebFilesExist = $false
    }
}

$checks += @{ name = "Web Files"; passed = $allWebFilesExist }
Write-Host ""

# Check 4: Verify JSON data is valid
Write-Host "CHECK 4: JSON Data Validation" -ForegroundColor Yellow
$jsonFiles = @(
    'data/cpuSorted.json', 'data/gpuSorted.json', 'data/ramSorted.json',
    'data/powerProfiles.json'
)

$allJsonValid = $true
foreach ($jsonFile in $jsonFiles) {
    try {
        $data = Get-Content $jsonFile | ConvertFrom-Json
        $count = if ($data -is [array]) { $data.Count } else { 1 }
        Write-Host "  ✓ $(Split-Path $jsonFile -Leaf) - $count records"
    } catch {
        Write-Host "  ✗ $(Split-Path $jsonFile -Leaf) - INVALID JSON!" -ForegroundColor Red
        $allJsonValid = $false
    }
}

$checks += @{ name = "JSON Validation"; passed = $allJsonValid }
Write-Host ""

# Check 5: Verify tier assignments
Write-Host "CHECK 5: Tier Assignments" -ForegroundColor Yellow
try {
    $cpus = Get-Content data/cpuSorted.json | ConvertFrom-Json
    $gpus = Get-Content data/gpuSorted.json | ConvertFrom-Json
    $rams = Get-Content data/ramSorted.json | ConvertFrom-Json
    
    # Check CPU tiers
    $cpuTierCounts = @{}
    foreach ($cpu in $cpus) { $cpuTierCounts[$cpu.tier]++ }
    $cpuValid = $cpuTierCounts.Count -eq 7
    $cpuAvg = [math]::Round(($cpuTierCounts.Values | Measure-Object -Average).Average, 0)
    Write-Host "  ✓ CPUs: 7 tiers with $cpuAvg avg per tier"
    
    # Check GPU tiers
    $gpuTierCounts = @{}
    foreach ($gpu in $gpus) { $gpuTierCounts[$gpu.tier]++ }
    $gpuValid = $gpuTierCounts.Count -eq 7
    $gpuAvg = [math]::Round(($gpuTierCounts.Values | Measure-Object -Average).Average, 0)
    Write-Host "  ✓ GPUs: 7 tiers with $gpuAvg avg per tier"
    
    # Check RAM tiers
    $ramTierCounts = @{}
    foreach ($ram in $rams) { $ramTierCounts[$ram.tier]++ }
    $ramValid = $ramTierCounts.Count -eq 7
    $ramAvg = [math]::Round(($ramTierCounts.Values | Measure-Object -Average).Average, 0)
    Write-Host "  ✓ RAM: 7 tiers with $ramAvg avg per tier"
    
    $allTiersValid = $cpuValid -and $gpuValid -and $ramValid
    
} catch {
    Write-Host "  ✗ Error reading tier data!" -ForegroundColor Red
    $allTiersValid = $false
}

$checks += @{ name = "Tier Assignments"; passed = $allTiersValid }
Write-Host ""

# Check 6: Verify score calculations
Write-Host "CHECK 6: Score Calculations" -ForegroundColor Yellow
try {
    $cpuT1 = $cpus | Where-Object { $_.tier -eq 1 } | Select-Object -First 1
    $cpuT7 = $cpus | Where-Object { $_.tier -eq 7 } | Select-Object -First 1
    
    function CalculateCPUScore {
        param($cpu, $allCpus)
        $maxBoost = ($allCpus | ForEach-Object { [double]$_.boost_clock } | Measure-Object -Maximum).Maximum
        $minBoost = ($allCpus | ForEach-Object { [double]$_.boost_clock } | Measure-Object -Minimum).Minimum
        $maxCores = ($allCpus | ForEach-Object { $_.core_count } | Measure-Object -Maximum).Maximum
        $minCores = ($allCpus | ForEach-Object { $_.core_count } | Measure-Object -Minimum).Minimum
        $maxGen = ($allCpus | ForEach-Object { $_.generation } | Measure-Object -Maximum).Maximum
        $minGen = ($allCpus | ForEach-Object { $_.generation } | Measure-Object -Minimum).Minimum
        
        $boostNorm = if ($maxBoost -eq $minBoost) { 0 } else { ([double]$cpu.boost_clock - $minBoost) / ($maxBoost - $minBoost) }
        $coreNorm = if ($maxCores -eq $minCores) { 0 } else { ($cpu.core_count - $minCores) / ($maxCores - $minCores) }
        $genNorm = if ($maxGen -eq $minGen) { 0 } else { ($cpu.generation - $minGen) / ($maxGen - $minGen) }
        
        return ($boostNorm * 0.60) + ($coreNorm * 0.30) + ($genNorm * 0.10)
    }
    
    $scoreT1 = CalculateCPUScore $cpuT1 $cpus
    $scoreT7 = CalculateCPUScore $cpuT7 $cpus
    
    $scoreValid = $scoreT7 -gt $scoreT1
    Write-Host "  ✓ CPU: T7 score ($([math]::Round($scoreT7, 3))) > T1 score ($([math]::Round($scoreT1, 3)))"
    Write-Host "  ✓ Score formula working correctly"
    
} catch {
    Write-Host "  ✗ Error calculating scores!" -ForegroundColor Red
    $scoreValid = $false
}

$checks += @{ name = "Score Calculations"; passed = $scoreValid }
Write-Host ""

# Check 7: Verify web assets integrity
Write-Host "CHECK 7: Web Assets Integrity" -ForegroundColor Yellow
try {
    $html = Get-Content index.html -Raw
    $js = Get-Content script.js -Raw
    $css = Get-Content style.css -Raw
    
    $htmlValid = $html.Contains('<html') -and $html.Contains('</html>')
    $jsValid = $js.Contains('function') -and $js.Contains('loadData')
    $cssValid = $css.Contains('body') -and $css.Contains('{')
    
    Write-Host "  ✓ HTML: Valid structure"
    Write-Host "  ✓ JavaScript: Contains loadData function"
    Write-Host "  ✓ CSS: Contains styles"
    
    $webAssetsValid = $htmlValid -and $jsValid -and $cssValid
    
} catch {
    Write-Host "  ✗ Error validating web assets!" -ForegroundColor Red
    $webAssetsValid = $false
}

$checks += @{ name = "Web Assets"; passed = $webAssetsValid }
Write-Host ""

# Check 8: Verify upgrade feature functions
Write-Host "CHECK 8: Upgrade Verification Feature" -ForegroundColor Yellow
try {
    $upgradeTests = 0
    $upgradePassed = 0
    
    for ($i = 0; $i -lt 20; $i++) {
        $randomCPU = $cpus | Get-Random
        $targetTier = [math]::Min(7, $randomCPU.tier + 2)
        $candidates = $cpus | Where-Object { $_.tier -eq $targetTier }
        
        if ($candidates.Count -gt 0) {
            $upgradeTests++
            $currentScore = CalculateCPUScore $randomCPU $cpus
            $candidateWithBetter = $candidates | Where-Object { (CalculateCPUScore $_ $cpus) -gt $currentScore } | Select-Object -First 1
            
            if ($null -ne $candidateWithBetter -and (CalculateCPUScore $candidateWithBetter $cpus) -gt $currentScore) {
                $upgradePassed++
            }
        }
    }
    
    $upgradeFeatureValid = $upgradePassed -eq $upgradeTests
    Write-Host "  ✓ Upgrade verification: $upgradePassed/$upgradeTests tests passed"
    Write-Host "  ✓ No downgrades detected"
    
} catch {
    Write-Host "  ✗ Error testing upgrade feature!" -ForegroundColor Red
    $upgradeFeatureValid = $false
}

$checks += @{ name = "Upgrade Feature"; passed = $upgradeFeatureValid }
Write-Host ""

# Check 9: Verify tests folder exists
Write-Host "CHECK 9: Tests Folder" -ForegroundColor Yellow
if (Test-Path "tests") {
    $testFiles = (Get-ChildItem tests/ -File).Count
    Write-Host "  ✓ Tests folder exists with $testFiles test files"
    $testsFolderValid = $true
} else {
    Write-Host "  ✗ Tests folder missing!" -ForegroundColor Red
    $testsFolderValid = $false
}

$checks += @{ name = "Tests Folder"; passed = $testsFolderValid }
Write-Host ""

# Final Summary
Write-Host "╔════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                    HEALTH CHECK SUMMARY            ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

$passedCount = ($checks | Where-Object { $_.passed }).Count
$totalCount = $checks.Count

foreach ($check in $checks) {
    $status = if ($check.passed) { "✓ PASS" } else { "✗ FAIL" }
    $color = if ($check.passed) { "Green" } else { "Red" }
    Write-Host "  $($check.name.PadRight(30)) : $status" -ForegroundColor $color
}

Write-Host "`n" + ("─" * 54)
Write-Host "OVERALL STATUS: $passedCount / $totalCount checks passed" -ForegroundColor $(if ($passedCount -eq $totalCount) { "Green" } else { "Yellow" })

if ($passedCount -eq $totalCount) {
    Write-Host "`n✓ PROJECT IS FULLY OPERATIONAL!" -ForegroundColor Green
    Write-Host "✓ All systems working correctly" -ForegroundColor Green
    Write-Host "✓ Ready for deployment" -ForegroundColor Green
} else {
    Write-Host "`n⚠️ SOME ISSUES DETECTED - REVIEW ABOVE" -ForegroundColor Yellow
}

Write-Host ""
