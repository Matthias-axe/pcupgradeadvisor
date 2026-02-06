# Read the sorted RAM data
$ramSortedPath = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "data") -ChildPath "ramSorted.json"
$ramData = Get-Content -Path $ramSortedPath | ConvertFrom-Json

# Optional benchmark overrides
$ramBenchPath = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "data") -ChildPath "ramBenchmarks.json"
$ramBenchScores = @{}
if (Test-Path $ramBenchPath) {
    $benchRaw = Get-Content -Path $ramBenchPath | ConvertFrom-Json
    if ($benchRaw -is [System.Collections.IEnumerable]) {
        foreach ($item in $benchRaw) {
            if ($null -ne $item.name -and $null -ne $item.score) {
                $ramBenchScores[$item.name] = [double]$item.score
            }
        }
    } else {
        $benchRaw.PSObject.Properties | ForEach-Object {
            if ($_.Name -notlike '_*') { $ramBenchScores[$_.Name] = [double]$_.Value }
        }
    }
}

function NormalizeName {
    param([string]$name)
    if ([string]::IsNullOrWhiteSpace($name)) { return '' }
    return ($name.ToLower() -replace '[^a-z0-9 ]', '' -replace '\s+', ' ').Trim()
}

# Filter out old RAM (keep only DDR4 2400+ MHz and DDR5, exclude legacy speeds)
$ramFiltered = $ramData | Where-Object {
    $speed = $_.speed
    
    # Extract DDR generation and effective MHz (e.g., "4,3200" -> gen 4, speed 3200)
    $speedDigits = ($speed -replace '[^0-9]', '')
    if ($speedDigits.Length -lt 2) { return $false }
    $ddrGen = [int]$speedDigits.Substring(0, 1)
    $speedMHz = [int]$speedDigits.Substring(1)
    if ($ddrGen -lt 4) { return $false }

    # Validate modules and total capacity (consumer-focused)
    $totalGb = 0
    if ($_.modules -match '^(\d+),(\d+)$') {
        $moduleCount = [int]$matches[1]
        $moduleSize = [int]$matches[2]
        $totalGb = $moduleCount * $moduleSize
        if ($moduleCount -gt 8 -or $moduleSize -gt 64 -or $totalGb -gt 128) { return $false }
        if ($totalGb -lt 8) { return $false }
    }

    $true
}

Write-Host "Filtered RAM: $($ramFiltered.Count) from $($ramData.Count) total"

# Get min/max values for normalization
$speedValues = @($ramFiltered | ForEach-Object {
    # Extract numeric speed value (e.g., "5,600" -> 5600 or "5.600" -> 5600)
    $speedDigits = ($_.speed -replace '[^0-9]', '')
    if ($speedDigits.Length -gt 0) { [int]$speedDigits } else { 0 }
})
$memoryValues = @($ramFiltered | ForEach-Object {
    # Extract total GB from modules (format is "2,16" = 32GB total)
    if ($_.modules -match '^(\d+),(\d+)$') {
        [int]$matches[1] * [int]$matches[2]
    } elseif ($_.name -match "\s(\d+)\s+GB\s*$") {
        [int]$matches[1]
    } else {
        4  # Default to 4GB if not found
    }
})

$casValues = @($ramFiltered | Where-Object { $_.cas_latency } | ForEach-Object { [double]$_.cas_latency })

$minSpeed = ($speedValues | Measure-Object -Minimum).Minimum
$maxSpeed = ($speedValues | Measure-Object -Maximum).Maximum
$minMemory = ($memoryValues | Measure-Object -Minimum).Minimum
$maxMemory = ($memoryValues | Measure-Object -Maximum).Maximum
$minCas = ($casValues | Measure-Object -Minimum).Minimum
$maxCas = ($casValues | Measure-Object -Maximum).Maximum

$benchValues = @()
if ($ramBenchScores.Count -gt 0) {
    $benchValues = @($ramBenchScores.Values)
}
$minBench = if ($benchValues.Count -gt 0) { ($benchValues | Measure-Object -Minimum).Minimum } else { 0 }
$maxBench = if ($benchValues.Count -gt 0) { ($benchValues | Measure-Object -Maximum).Maximum } else { 0 }

Write-Host "RAM Performance Ranges:"
Write-Host "  Speed: $minSpeed MHz - $maxSpeed MHz"
Write-Host "  Memory: $minMemory GB - $maxMemory GB"
Write-Host "  CAS Latency: $minCas - $maxCas"

# Function to normalize a value to 0-1 range
function Normalize {
    param([double]$value, [double]$min, [double]$max)
    if ($max -eq $min) { return 0.5 }
    return ([math]::Max(0, [math]::Min(1, ($value - $min) / ($max - $min))))
}

# Calculate score for each RAM config
$ramWithScores = @()
$ramWithScores = foreach ($ram in $ramFiltered) {
    # Normalize performance metrics
    $speedDigits = ($ram.speed -replace '[^0-9]', '')
    $speedMHz = if ($speedDigits.Length -gt 0) { [int]$speedDigits } else { 0 }
    $speedNorm = Normalize -value $speedMHz -min $minSpeed -max $maxSpeed
    
    # Extract total GB from modules (fallback to name if missing)
    $memoryGB = 4
    if ($ram.modules -match '^(\d+),(\d+)$') {
        $memoryGB = [int]$matches[1] * [int]$matches[2]
    } elseif ($ram.name -match "\s(\d+)\s+GB\s*$") {
        $memoryGB = [int]$matches[1]
    }
    $memoryNorm = Normalize -value $memoryGB -min $minMemory -max $maxMemory

    $casValue = if ($ram.cas_latency) { [double]$ram.cas_latency } else { $maxCas }
    $casNorm = Normalize -value $casValue -min $minCas -max $maxCas
    $casScore = 1 - $casNorm
    
    $benchKey = NormalizeName $ram.name
    $benchScore = $null
    if ($benchKey -and $ramBenchScores.Count -gt 0) {
        foreach ($k in $ramBenchScores.Keys) {
            if ((NormalizeName $k) -eq $benchKey) { $benchScore = $ramBenchScores[$k]; break }
        }
    }

    if ($null -ne $benchScore -and $maxBench -gt $minBench) {
        $combinedScore = Normalize -value $benchScore -min $minBench -max $maxBench
    } else {
        # Simpler formula: Speed is primary (MHz drives bandwidth)
        # Capacity and CAS as supporting factors
        $combinedScore = ($speedNorm * 0.65) + ($memoryNorm * 0.25) + ($casScore * 0.10)
    }
    
    $ram | Add-Member -NotePropertyName "score" -NotePropertyValue $combinedScore -Force
    $ram  # Return the object
}

# Sort by score descending
$ramSorted = $ramWithScores | Sort-Object -Property score -Descending

# Assign tiers using equal-percentile bucketing (7 equal-sized tiers for balanced coverage)
$ramCount = $ramSorted.Count
$tierCount = 7
$tierSize = [math]::Ceiling($ramCount / $tierCount)

for ($i = 0; $i -lt $ramSorted.Count; $i++) {
    $tier = [int]($tierCount - [math]::Floor($i / $tierSize))
    $tier = [math]::Max(1, [math]::Min($tierCount, $tier))
    $ramSorted[$i] | Add-Member -NotePropertyName "tier" -NotePropertyValue $tier -Force
}

# Remove the temporary score property
foreach ($ram in $ramSorted) {
    $ram.PSObject.Properties.Remove('score')
}

# Write updated data back to file
$outputPath = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "data") -ChildPath "ramSorted.json"
$ramSorted | ConvertTo-Json -Depth 10 | Set-Content -Path $outputPath

# Show tier distribution
$tierDistribution = $ramSorted | Group-Object -Property tier | Sort-Object -Property @{Expression={[int]$_.Name}; Descending=$true}
Write-Host "`n✓ RAM Tier Assignment Complete:"
Write-Host "Tier Distribution:"
foreach ($group in $tierDistribution) {
    Write-Host "  Tier $($group.Name): $($group.Count) RAM configs"
}
Write-Host "`n✓ Updated ramSorted.json with tier assignments" -ForegroundColor Green
