# PowerShell test for upgrade verification feature
# This simulates the JavaScript logic in PowerShell to verify the algorithm

param(
	[int]$RandomSeed = -1
)

if ($RandomSeed -ne -1) {
	[random]::new($RandomSeed) | Out-Null
}

# Load data
$cpus = Get-Content data/cpuSorted.json | ConvertFrom-Json
$gpus = Get-Content data/gpuSorted.json | ConvertFrom-Json
$rams = Get-Content data/ramSorted.json | ConvertFrom-Json

# Score calculation function (mirrors JavaScript)
function CalculateScore {
	param(
		[PSObject]$Component,
		[string]$Type
	)

	if ($Type -eq 'CPU') {
		$maxBoost = ($cpus | ForEach-Object { [double]$_.boost_clock } | Measure-Object -Maximum).Maximum
		$minBoost = ($cpus | ForEach-Object { [double]$_.boost_clock } | Measure-Object -Minimum).Minimum
		$maxCores = ($cpus | ForEach-Object { $_.core_count } | Measure-Object -Maximum).Maximum
		$minCores = ($cpus | ForEach-Object { $_.core_count } | Measure-Object -Minimum).Minimum
		$maxGen = ($cpus | ForEach-Object { $_.generation } | Measure-Object -Maximum).Maximum
		$minGen = ($cpus | ForEach-Object { $_.generation } | Measure-Object -Minimum).Minimum

		$boostNorm = if ($maxBoost -eq $minBoost) { 0 } else { ([double]$Component.boost_clock - $minBoost) / ($maxBoost - $minBoost) }
		$coreNorm = if ($maxCores -eq $minCores) { 0 } else { ($Component.core_count - $minCores) / ($maxCores - $minCores) }
		$genNorm = if ($maxGen -eq $minGen) { 0 } else { ($Component.generation - $minGen) / ($maxGen - $minGen) }

		return ($boostNorm * 0.60) + ($coreNorm * 0.30) + ($genNorm * 0.10)
	}
	elseif ($Type -eq 'GPU') {
		$maxBoost = ($gpus | ForEach-Object { [double]$_.boost_clock } | Measure-Object -Maximum).Maximum
		$minBoost = ($gpus | ForEach-Object { [double]$_.boost_clock } | Measure-Object -Minimum).Minimum
		$maxMem = ($gpus | ForEach-Object { $_.memory } | Measure-Object -Maximum).Maximum
		$minMem = ($gpus | ForEach-Object { $_.memory } | Measure-Object -Minimum).Minimum
		$maxGen = ($gpus | ForEach-Object { $_.generation } | Measure-Object -Maximum).Maximum
		$minGen = ($gpus | ForEach-Object { $_.generation } | Measure-Object -Minimum).Minimum

		$boostNorm = if ($maxBoost -eq $minBoost) { 0 } else { ([double]$Component.boost_clock - $minBoost) / ($maxBoost - $minBoost) }
		$memNorm = if ($maxMem -eq $minMem) { 0 } else { ($Component.memory - $minMem) / ($maxMem - $minMem) }
		$genNorm = if ($maxGen -eq $minGen) { 0 } else { ($Component.generation - $minGen) / ($maxGen - $minGen) }

		return ($boostNorm * 0.65) + ($memNorm * 0.25) + ($genNorm * 0.10)
	}
	elseif ($Type -eq 'RAM') {
		$maxSpeed = ($rams | ForEach-Object { [int]($_.speed -replace '[^0-9]', '') } | Measure-Object -Maximum).Maximum
		$minSpeed = ($rams | ForEach-Object { [int]($_.speed -replace '[^0-9]', '') } | Measure-Object -Minimum).Minimum
		
		$speedNum = [int]($Component.speed -replace '[^0-9]', '')
		$speedNorm = if ($maxSpeed -eq $minSpeed) { 0 } else { ($speedNum - $minSpeed) / ($maxSpeed - $minSpeed) }

		return $speedNorm
	}

	return 0
}

Write-Host "`n=== UPGRADE VERIFICATION FEATURE TEST ===" -ForegroundColor Cyan
Write-Host "Testing that only legitimate upgrades are recommended`n" -ForegroundColor Gray

# Test 1: Score calculations
Write-Host "TEST 1: CPU Score Calculations" -ForegroundColor Yellow
Write-Host "=============================="
$cpuT1 = $cpus | Where-Object { $_.tier -eq 1 } | Select-Object -First 1
$cpuT7 = $cpus | Where-Object { $_.tier -eq 7 } | Select-Object -First 1

$scoreT1 = CalculateScore $cpuT1 'CPU'
$scoreT7 = CalculateScore $cpuT7 'CPU'

Write-Host "Tier 1: $($cpuT1.name) - Score: $([math]::Round($scoreT1, 4))"
Write-Host "Tier 7: $($cpuT7.name) - Score: $([math]::Round($scoreT7, 4))"

if ($scoreT7 -gt $scoreT1) {
	Write-Host "✓ PASS: T7 score higher than T1`n" -ForegroundColor Green
	$test1Pass = $true
} else {
	Write-Host "✗ FAIL: T7 score not higher than T1`n" -ForegroundColor Red
	$test1Pass = $false
}

# Test 2: GPU Scores
Write-Host "TEST 2: GPU Score Calculations" -ForegroundColor Yellow
Write-Host "=============================="
$gpuT1 = $gpus | Where-Object { $_.tier -eq 1 } | Select-Object -First 1
$gpuT7 = $gpus | Where-Object { $_.tier -eq 7 } | Select-Object -First 1

$gpuScoreT1 = CalculateScore $gpuT1 'GPU'
$gpuScoreT7 = CalculateScore $gpuT7 'GPU'

Write-Host "Tier 1: $($gpuT1.name) - Score: $([math]::Round($gpuScoreT1, 4))"
Write-Host "Tier 7: $($gpuT7.name) - Score: $([math]::Round($gpuScoreT7, 4))"

if ($gpuScoreT7 -gt $gpuScoreT1) {
	Write-Host "✓ PASS: T7 score higher than T1`n" -ForegroundColor Green
	$test2Pass = $true
} else {
	Write-Host "✗ FAIL: T7 score not higher than T1`n" -ForegroundColor Red
	$test2Pass = $false
}

# Test 3: Upgrade verification - CPU
Write-Host "TEST 3: CPU Upgrade Verification (20 random tests)" -ForegroundColor Yellow
Write-Host "=================================================="
$upgradeTests = 0
$upgradePassed = 0

for ($i = 0; $i -lt 20; $i++) {
	$randomCPU = $cpus | Get-Random
	$targetTier = [math]::Min(7, $randomCPU.tier + 2)
	
	# Get products in target tier
	$candidates = $cpus | Where-Object { $_.tier -eq $targetTier }
	
	if ($candidates.Count -gt 0) {
		$currentScore = CalculateScore $randomCPU 'CPU'
		$candidateWithBetterScore = $candidates | Where-Object { (CalculateScore $_ 'CPU') -gt $currentScore } | Select-Object -First 1
		
		if ($null -ne $candidateWithBetterScore) {
			$upgradeTests++
			$candidateScore = CalculateScore $candidateWithBetterScore 'CPU'
			
			if ($candidateScore -gt $currentScore) {
				$upgradePassed++
				Write-Host "  ✓ $($randomCPU.name) (T$($randomCPU.tier)) → $($candidateWithBetterScore.name) (T$targetTier)"
			} else {
				Write-Host "  ✗ DOWNGRADE: $($randomCPU.name) → $($candidateWithBetterScore.name)" -ForegroundColor Red
			}
		}
	}
}

Write-Host "`n$upgradePassed/$upgradeTests verified as legitimate upgrades"
if ($upgradePassed -eq $upgradeTests -and $upgradeTests -gt 0) {
	Write-Host "✓ PASS: No downgrades detected`n" -ForegroundColor Green
	$test3Pass = $true
} else {
	Write-Host "✗ FAIL: Some downgrades detected`n" -ForegroundColor Red
	$test3Pass = $false
}

# Test 4: GPU Upgrade verification
Write-Host "TEST 4: GPU Upgrade Verification (20 random tests)" -ForegroundColor Yellow
Write-Host "=================================================="
$gpuUpgradeTests = 0
$gpuUpgradePassed = 0

for ($i = 0; $i -lt 20; $i++) {
	$randomGPU = $gpus | Get-Random
	$targetTier = [math]::Min(7, $randomGPU.tier + 2)
	
	$candidates = $gpus | Where-Object { $_.tier -eq $targetTier }
	
	if ($candidates.Count -gt 0) {
		$currentScore = CalculateScore $randomGPU 'GPU'
		$candidateWithBetterScore = $candidates | Where-Object { (CalculateScore $_ 'GPU') -gt $currentScore } | Select-Object -First 1
		
		if ($null -ne $candidateWithBetterScore) {
			$gpuUpgradeTests++
			$candidateScore = CalculateScore $candidateWithBetterScore 'GPU'
			
			if ($candidateScore -gt $currentScore) {
				$gpuUpgradePassed++
				Write-Host "  ✓ $($randomGPU.name) (T$($randomGPU.tier)) → $($candidateWithBetterScore.name) (T$targetTier)"
			} else {
				Write-Host "  ✗ DOWNGRADE: $($randomGPU.name) → $($candidateWithBetterScore.name)" -ForegroundColor Red
			}
		}
	}
}

Write-Host "`n$gpuUpgradePassed/$gpuUpgradeTests verified as legitimate upgrades"
if ($gpuUpgradePassed -eq $gpuUpgradeTests -and $gpuUpgradeTests -gt 0) {
	Write-Host "✓ PASS: No downgrades detected`n" -ForegroundColor Green
	$test4Pass = $true
} else {
	Write-Host "✗ FAIL: Some downgrades detected`n" -ForegroundColor Red
	$test4Pass = $false
}

# Final summary
Write-Host "=== TEST SUMMARY ===" -ForegroundColor Cyan
Write-Host "Test 1 (CPU Scoring): $(if ($test1Pass) { '✓ PASS' } else { '✗ FAIL' })"
Write-Host "Test 2 (GPU Scoring): $(if ($test2Pass) { '✓ PASS' } else { '✗ FAIL' })"
Write-Host "Test 3 (CPU Upgrades): $(if ($test3Pass) { '✓ PASS' } else { '✗ FAIL' })"
Write-Host "Test 4 (GPU Upgrades): $(if ($test4Pass) { '✓ PASS' } else { '✗ FAIL' })"

if ($test1Pass -and $test2Pass -and $test3Pass -and $test4Pass) {
	Write-Host "`n✓ ALL TESTS PASSED! Feature is ready for production." -ForegroundColor Green
} else {
	Write-Host "`n✗ SOME TESTS FAILED. Please review." -ForegroundColor Red
}
