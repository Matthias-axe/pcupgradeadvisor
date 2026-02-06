param(
	[int]$Iterations = 1000
)

$ErrorActionPreference = 'Stop'

$cpuData = Get-Content "$PSScriptRoot\data\cpuSorted.json" | ConvertFrom-Json
$gpuData = Get-Content "$PSScriptRoot\data\gpuSorted.json" | ConvertFrom-Json
$ramData = Get-Content "$PSScriptRoot\data\ramSorted.json" | ConvertFrom-Json
$powerProfiles = Get-Content "$PSScriptRoot\data\powerProfiles.json" | ConvertFrom-Json

$RAM_GOOD_ENOUGH_TIER = 4
$epsilon = 1e-9

function Get-DisplayTier($component, $type) {
	return [int]$component.tier
}

function Get-RamDdrType($ram) {
	if ($null -eq $ram) { return $null }
	if ($ram.generation -is [ValueType]) {
		if ($ram.generation -le 9) { return 'DDR4' }
		return 'DDR5'
	}
	if ($ram.speed -is [string]) {
		if ($ram.speed -match '5[,\.]') { return 'DDR5' }
		if ($ram.speed -match '4[,\.]') { return 'DDR4' }
	}
	return $null
}

function Is-RamCompatibleWithCpu($ram, $cpu) {
	if ($null -eq $ram -or $null -eq $cpu -or [string]::IsNullOrWhiteSpace($cpu.ramType)) { return $true }
	$ramType = Get-RamDdrType $ram
	if (-not $ramType) { return $true }
	return $cpu.ramType -like "*$ramType*"
}

function Get-PsuRecommendation($cpuTier, $gpuTier) {
	$profile = $powerProfiles | Where-Object { $_.cpuTier -eq $cpuTier -and $_.gpuTier -eq $gpuTier } | Select-Object -First 1
	if ($profile) { return [int]$profile.recommendedPsu }
	return $null
}

function Get-UpgradeEffort($component, $product, $selectedCPU, $selectedGPU, $selectedRAM) {
	$requiredParts = @()
	$notes = @()
	$requiredLevel = 'simple'

	if ($component -eq 'CPU') {
		if ($selectedCPU -and $product.socket -and $selectedCPU.socket -and $product.socket -ne $selectedCPU.socket) {
			$requiredParts += 'Motherboard'
		}
		if ($selectedRAM -and $product.ramType -and -not (Is-RamCompatibleWithCpu $selectedRAM $product)) {
			$requiredParts += 'RAM'
		}
		if ($requiredParts.Count -gt 0) { $requiredLevel = 'complex' }
	}

	if ($component -eq 'RAM') {
		if ($selectedCPU -and -not (Is-RamCompatibleWithCpu $product $selectedCPU)) {
			$requiredParts += 'CPU/Motherboard'
			$requiredLevel = 'complex'
		}
	}

	if ($component -eq 'GPU') {
		if ($selectedCPU -and $selectedGPU) {
			$currentPsu = Get-PsuRecommendation $selectedCPU.tier $selectedGPU.tier
			$targetPsu = Get-PsuRecommendation $selectedCPU.tier $product.tier
			if ($currentPsu -and $targetPsu -and $targetPsu -gt $currentPsu) {
				$requiredParts += 'PSU'
				$requiredLevel = 'moderate'
				$notes += "Estimated PSU need: $targetPsu W (current estimate: $currentPsu W)"
			}
		}
	}

	return [pscustomobject]@{
		requiredLevel = $requiredLevel
		requiredParts = $requiredParts
		notes = $notes
	}
}

function Get-EffortRank($level) {
	switch ($level) {
		'any' { return 4 }
		'complex' { return 3 }
		'moderate' { return 2 }
		default { return 1 }
	}
}

function Is-EffortAllowed($requiredLevel, $selectedLevel) {
	if ($selectedLevel -eq 'any') { return $true }
	return (Get-EffortRank $requiredLevel) -le (Get-EffortRank $selectedLevel)
}

function Get-NextAvailableTier($currentTier, $component, $advancement) {
	$availableTiers = if ($component -eq 'CPU') { $cpuTiers } elseif ($component -eq 'GPU') { $gpuTiers } else { $ramTiers }
	$maxTier = $availableTiers[-1]

	if ($advancement -eq 'max') { return $maxTier }
	$target = [Math]::Min($currentTier + [int]$advancement, $maxTier)
	if ($availableTiers -contains $target) { return $target }
	$higher = $availableTiers | Where-Object { $_ -gt $target } | Select-Object -First 1
	if ($higher) { return $higher }
	return $maxTier
}

function Get-Score($component, $type) {
	if ($null -eq $component) { return 0 }
	return [double]$component.score
}

function Get-UpgradeProducts($component, $currentComponent, $recommendedTier, $selectedEffort, $selectedCPU, $selectedGPU, $selectedRAM) {
	$currentScore = Get-Score $currentComponent $component
	$products = @()
	if ($component -eq 'CPU') {
		$products = $cpuByTier[$recommendedTier]
	} elseif ($component -eq 'GPU') {
		$products = $gpuByTier[$recommendedTier]
	} else {
		$products = $ramByTier[$recommendedTier]
	}
	if (-not $products) { $products = @() }
	$results = @()
	foreach ($product in $products) {
		if ($product.score -le $currentScore) { continue }
		$effort = Get-UpgradeEffort $component $product $selectedCPU $selectedGPU $selectedRAM
		if (-not (Is-EffortAllowed $effort.requiredLevel $selectedEffort)) { continue }
		$results += $product
		if ($results.Count -ge 5) { break }
	}

	return $results
}

$cpuStats = @{
	maxBoost = ($cpuData | ForEach-Object { [double]$_.boost_clock } | Measure-Object -Maximum).Maximum
	minBoost = ($cpuData | ForEach-Object { [double]$_.boost_clock } | Measure-Object -Minimum).Minimum
	maxCores = ($cpuData | ForEach-Object { [double]$_.core_count } | Measure-Object -Maximum).Maximum
	minCores = ($cpuData | ForEach-Object { [double]$_.core_count } | Measure-Object -Minimum).Minimum
	maxGen = ($cpuData | ForEach-Object { [double]$_.generation } | Measure-Object -Maximum).Maximum
	minGen = ($cpuData | ForEach-Object { [double]$_.generation } | Measure-Object -Minimum).Minimum
}

$gpuStats = @{
	maxBoost = ($gpuData | ForEach-Object { [double]$_.boost_clock } | Measure-Object -Maximum).Maximum
	minBoost = ($gpuData | ForEach-Object { [double]$_.boost_clock } | Measure-Object -Minimum).Minimum
	maxMem = ($gpuData | ForEach-Object { [double]$_.memory } | Measure-Object -Maximum).Maximum
	minMem = ($gpuData | ForEach-Object { [double]$_.memory } | Measure-Object -Minimum).Minimum
	maxGen = ($gpuData | ForEach-Object { [double]$_.generation } | Measure-Object -Maximum).Maximum
	minGen = ($gpuData | ForEach-Object { [double]$_.generation } | Measure-Object -Minimum).Minimum
}

$ramSpeeds = $ramData | ForEach-Object { [int]($_.speed -replace '[^0-9]', '') }
$ramMems = $ramData | ForEach-Object {
	$match = [regex]::Match($_.name, '(\d+)\s*GB')
	if ($match.Success) { [int]$match.Groups[1].Value } else { 16 }
}

$ramStats = @{
	maxSpeed = ($ramSpeeds | Measure-Object -Maximum).Maximum
	minSpeed = ($ramSpeeds | Measure-Object -Minimum).Minimum
	maxMem = ($ramMems | Measure-Object -Maximum).Maximum
	minMem = ($ramMems | Measure-Object -Minimum).Minimum
}

$cpuData | ForEach-Object {
	$boost = [double]$_.boost_clock
	$cores = [double]$_.core_count
	$gen = [double]$_.generation
	$boostNorm = ($boost - $cpuStats.minBoost) / (($cpuStats.maxBoost - $cpuStats.minBoost) + $epsilon)
	$coreNorm = ($cores - $cpuStats.minCores) / (($cpuStats.maxCores - $cpuStats.minCores) + $epsilon)
	$genNorm = ($gen - $cpuStats.minGen) / (($cpuStats.maxGen - $cpuStats.minGen) + $epsilon)
	$score = ($boostNorm * 0.60) + ($coreNorm * 0.30) + ($genNorm * 0.10)
	$_ | Add-Member -NotePropertyName score -NotePropertyValue $score -Force
}

$gpuData | ForEach-Object {
	$boost = [double]$_.boost_clock
	$mem = [double]$_.memory
	$gen = [double]$_.generation
	$boostNorm = ($boost - $gpuStats.minBoost) / (($gpuStats.maxBoost - $gpuStats.minBoost) + $epsilon)
	$memNorm = ($mem - $gpuStats.minMem) / (($gpuStats.maxMem - $gpuStats.minMem) + $epsilon)
	$genNorm = ($gen - $gpuStats.minGen) / (($gpuStats.maxGen - $gpuStats.minGen) + $epsilon)
	$score = ($boostNorm * 0.65) + ($memNorm * 0.25) + ($genNorm * 0.10)
	$_ | Add-Member -NotePropertyName score -NotePropertyValue $score -Force
}

$ramData | ForEach-Object {
	$speedNum = [int]($_.speed -replace '[^0-9]', '')
	$memMatch = [regex]::Match($_.name, '(\d+)\s*GB')
	$memGB = if ($memMatch.Success) { [int]$memMatch.Groups[1].Value } else { 16 }
	$speedNorm = ($speedNum - $ramStats.minSpeed) / (($ramStats.maxSpeed - $ramStats.minSpeed) + $epsilon)
	$memNorm = ($memGB - $ramStats.minMem) / (($ramStats.maxMem - $ramStats.minMem) + $epsilon)
	$score = ($speedNorm * 0.65) + ($memNorm * 0.35)
	$_ | Add-Member -NotePropertyName score -NotePropertyValue $score -Force
	$_ | Add-Member -NotePropertyName memGB -NotePropertyValue $memGB -Force
}

$cpuByTier = @{}
$gpuByTier = @{}
$ramByTier = @{}
$ramSeenByTier = @{}

foreach ($cpu in $cpuData) {
	$tier = Get-DisplayTier $cpu 'cpu'
	if (-not $cpuByTier.ContainsKey($tier)) { $cpuByTier[$tier] = @() }
	$cpuByTier[$tier] += $cpu
}

foreach ($gpu in $gpuData) {
	$tier = Get-DisplayTier $gpu 'gpu'
	if (-not $gpuByTier.ContainsKey($tier)) { $gpuByTier[$tier] = @() }
	$gpuByTier[$tier] += $gpu
}

foreach ($ram in $ramData) {
	$tier = Get-DisplayTier $ram 'ram'
	if (-not $ramByTier.ContainsKey($tier)) {
		$ramByTier[$tier] = @()
		$ramSeenByTier[$tier] = @{}
	}
	if (-not $ramSeenByTier[$tier].ContainsKey($ram.name)) {
		$ramSeenByTier[$tier][$ram.name] = $true
		$ramByTier[$tier] += $ram
	}
}

$cpuTiers = $cpuByTier.Keys | Sort-Object
$gpuTiers = $gpuByTier.Keys | Sort-Object
$ramTiers = $ramByTier.Keys | Sort-Object

foreach ($tier in $cpuTiers) { $cpuByTier[$tier] = $cpuByTier[$tier] | Sort-Object score -Descending }
foreach ($tier in $gpuTiers) { $gpuByTier[$tier] = $gpuByTier[$tier] | Sort-Object score -Descending }
foreach ($tier in $ramTiers) { $ramByTier[$tier] = $ramByTier[$tier] | Sort-Object score -Descending }

$effortLevels = @('simple','moderate','complex','any')
$results = @{}
$effortLevels | ForEach-Object {
	$results[$_] = [pscustomobject]@{ total = 0; noProducts = 0; fallbackTierUsed = 0; errors = 0 }
}

$advancements = @(1,2,3,'max')
$rand = New-Object System.Random

for ($i = 0; $i -lt $Iterations; $i++) {
	$selectedCPU = $cpuData[$rand.Next(0, $cpuData.Count)]
	$selectedGPU = $gpuData[$rand.Next(0, $gpuData.Count)]
	$selectedRAM = $ramData[$rand.Next(0, $ramData.Count)]

	$cpuTier = Get-DisplayTier $selectedCPU 'cpu'
	$gpuTier = Get-DisplayTier $selectedGPU 'gpu'
	$ramTier = Get-DisplayTier $selectedRAM 'ram'

	$ramIsSufficient = $ramTier -ge $RAM_GOOD_ENOUGH_TIER
	if ($ramIsSufficient) {
		$minTier = [Math]::Min($cpuTier, $gpuTier)
	} else {
		$minTier = [Math]::Min([Math]::Min($cpuTier, $gpuTier), $ramTier)
	}
	$bottleneck = $null

	if ($ramIsSufficient) {
		if ($cpuTier -eq $minTier -and $cpuTier -lt $gpuTier) { $bottleneck = 'CPU' }
		elseif ($gpuTier -eq $minTier -and $gpuTier -lt $cpuTier) { $bottleneck = 'GPU' }
	} else {
		if ($cpuTier -eq $minTier -and ($cpuTier -lt $gpuTier -or $cpuTier -lt $ramTier)) { $bottleneck = 'CPU' }
		elseif ($gpuTier -eq $minTier -and ($gpuTier -lt $cpuTier -or $gpuTier -lt $ramTier)) { $bottleneck = 'GPU' }
		elseif ($ramTier -eq $minTier -and ($ramTier -lt $cpuTier -or $ramTier -lt $gpuTier)) { $bottleneck = 'RAM' }
	}

	if (-not $bottleneck) { $bottleneck = 'CPU' }
	$advancement = $advancements[$rand.Next(0, $advancements.Count)]

	foreach ($level in $effortLevels) {
		$results[$level].total++
		try {
			$currentTier = if ($bottleneck -eq 'CPU') { $cpuTier } elseif ($bottleneck -eq 'GPU') { $gpuTier } else { $ramTier }
			$recommendedTier = Get-NextAvailableTier $currentTier $bottleneck $advancement
			$currentComponent = if ($bottleneck -eq 'CPU') { $selectedCPU } elseif ($bottleneck -eq 'GPU') { $selectedGPU } else { $selectedRAM }
			$products = Get-UpgradeProducts $bottleneck $currentComponent $recommendedTier $level $selectedCPU $selectedGPU $selectedRAM

			if ($products.Count -eq 0) {
				$maxTier = if ($bottleneck -eq 'CPU') { $cpuTiers[-1] } elseif ($bottleneck -eq 'GPU') { $gpuTiers[-1] } else { $ramTiers[-1] }
				if ($recommendedTier -lt $maxTier) {
					$fallbackTier = $recommendedTier + 1
					$products = Get-UpgradeProducts $bottleneck $currentComponent $fallbackTier $level $selectedCPU $selectedGPU $selectedRAM
					if ($products.Count -gt 0) { $results[$level].fallbackTierUsed++ }
				}
			}

			if ($products.Count -eq 0) { $results[$level].noProducts++ }
		} catch {
			$results[$level].errors++
		}
	}
}

Write-Output "Stress Test Completed: $Iterations iterations per effort level"
foreach ($level in $effortLevels) {
	$r = $results[$level]
	Write-Output "`nEffort: $level"
	Write-Output "Total cases: $($r.total)"
	Write-Output "No products found: $($r.noProducts)"
	Write-Output "Fallback tier used: $($r.fallbackTierUsed)"
	Write-Output "Errors: $($r.errors)"
}
