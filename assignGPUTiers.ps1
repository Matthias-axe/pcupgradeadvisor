# Read the sorted GPU data
$gpuSortedPath = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "data") -ChildPath "gpuSorted.json"
$gpuData = Get-Content -Path $gpuSortedPath | ConvertFrom-Json

# Optional benchmark overrides
$gpuBenchPath = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "data") -ChildPath "gpuBenchmarks.json"
$gpuBenchScores = @{}
if (Test-Path $gpuBenchPath) {
    $benchRaw = Get-Content -Path $gpuBenchPath | ConvertFrom-Json
    if ($benchRaw -is [System.Collections.IEnumerable]) {
        foreach ($item in $benchRaw) {
            if ($null -ne $item.name -and $null -ne $item.score) {
                $gpuBenchScores[$item.name] = [double]$item.score
            }
        }
    } else {
        $benchRaw.PSObject.Properties | ForEach-Object {
            if ($_.Name -notlike '_*') { $gpuBenchScores[$_.Name] = [double]$_.Value }
        }
    }
}

function NormalizeName {
    param([string]$name)
    if ([string]::IsNullOrWhiteSpace($name)) { return '' }
    return ($name.ToLower() -replace '[^a-z0-9 ]', '' -replace '\s+', ' ').Trim()
}

# Filter out outdated and workstation GPUs (keep GTX 10+ / RTX / RX 5000+ / Arc)
$gpuFiltered = $gpuData | Where-Object {
    $chipset = $_.chipset
    $gen = $_.generation

    # Exclude workstation/pro models
    if ($chipset -match 'Quadro|Tesla|Radeon\s+Pro|FirePro|RTX\s+A|RTX\s+PRO|A\d{3,4}|W\d{4}') {
        return $false
    }
    
    # Primary filter: generation 4+ (GTX 10 series and newer)
    if ($gen -ge 4) {
        return $true
    }
    # Intel Arc: Keep all
    if ($chipset -like '*Arc*') {
        return $true
    }

    $false
}

Write-Host "Filtered GPUs: $($gpuFiltered.Count) from $($gpuData.Count) total"

# Get min/max values for normalization
$memoryValues = @($gpuFiltered | Where-Object { $_.memory } | ForEach-Object { $_.memory })
$boostValues = @($gpuFiltered | Where-Object { $_.boost_clock } | ForEach-Object { $_.boost_clock })
$genValues = @($gpuFiltered | Where-Object { $_.generation } | ForEach-Object { $_.generation })

$benchValues = @()
if ($gpuBenchScores.Count -gt 0) {
    $benchValues = @($gpuBenchScores.Values)
}

$minMemory = ($memoryValues | Measure-Object -Minimum).Minimum
$maxMemory = ($memoryValues | Measure-Object -Maximum).Maximum
$minBoost = ($boostValues | Measure-Object -Minimum).Minimum
$maxBoost = ($boostValues | Measure-Object -Maximum).Maximum
$minGen = ($genValues | Measure-Object -Minimum).Minimum
$maxGen = ($genValues | Measure-Object -Maximum).Maximum
$minBench = if ($benchValues.Count -gt 0) { ($benchValues | Measure-Object -Minimum).Minimum } else { 0 }
$maxBench = if ($benchValues.Count -gt 0) { ($benchValues | Measure-Object -Maximum).Maximum } else { 0 }

Write-Host "GPU Performance Ranges:"
Write-Host "  Memory: $minMemory GB - $maxMemory GB"
Write-Host "  Boost Clock: $minBoost MHz - $maxBoost MHz"
Write-Host "  Generation: $minGen - $maxGen"

# Function to normalize a value to 0-1 range
function Normalize {
    param([double]$value, [double]$min, [double]$max)
    if ($max -eq $min) { return 0.5 }
    return ([math]::Max(0, [math]::Min(1, ($value - $min) / ($max - $min))))
}

# Calculate score for each GPU
$gpuWithScores = @()
foreach ($gpu in $gpuFiltered) {
    # Normalize performance metrics
    $memoryNorm = Normalize -value $gpu.memory -min $minMemory -max $maxMemory
    $boostValue = $gpu.boost_clock
    if ($null -eq $boostValue -or $boostValue -eq 0) { $boostValue = $gpu.core_clock }
    if ($null -eq $boostValue -or $boostValue -eq 0) { $boostValue = $minBoost }
    if ($null -eq $gpu.boost_clock -or $gpu.boost_clock -eq 0) { $gpu.boost_clock = $boostValue }
    $boostNorm = Normalize -value $boostValue -min $minBoost -max $maxBoost
    $genNorm = Normalize -value $gpu.generation -min $minGen -max $maxGen
    
    $benchKey = NormalizeName $gpu.chipset
    $benchScore = $null
    if ($benchKey -and $gpuBenchScores.Count -gt 0) {
        foreach ($k in $gpuBenchScores.Keys) {
            if ((NormalizeName $k) -eq $benchKey) { $benchScore = $gpuBenchScores[$k]; break }
        }
    }

    $specScore = ($boostNorm * 0.65) + ($memoryNorm * 0.25) + ($genNorm * 0.10)
    if ($null -ne $benchScore -and $maxBench -gt $minBench) {
        $benchNorm = Normalize -value $benchScore -min $minBench -max $maxBench
        $combinedScore = ($benchNorm * 0.70) + ($specScore * 0.30)
    } else {
        # Fallback to spec-only score when benchmark is missing
        $combinedScore = $specScore
    }
    
    $gpu | Add-Member -NotePropertyName "score" -NotePropertyValue $combinedScore -Force
    $gpuWithScores += $gpu
}

# Sort by score descending
$gpuSorted = $gpuWithScores | Sort-Object -Property score -Descending

# Assign tiers using equal-percentile bucketing (7 equal-sized tiers for balanced coverage)
$gpuCount = $gpuSorted.Count
$tierCount = 7
$tierSize = [math]::Ceiling($gpuCount / $tierCount)

for ($i = 0; $i -lt $gpuSorted.Count; $i++) {
    $tier = [int]($tierCount - [math]::Floor($i / $tierSize))
    $tier = [math]::Max(1, [math]::Min($tierCount, $tier))
    $gpuSorted[$i] | Add-Member -NotePropertyName "tier" -NotePropertyValue $tier -Force
}

# Remove the temporary score property
foreach ($gpu in $gpuSorted) {
    $gpu.PSObject.Properties.Remove('score')
}

# Write updated data back to file
$outputPath = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "data") -ChildPath "gpuSorted.json"
$gpuSorted | ConvertTo-Json -Depth 10 | Set-Content -Path $outputPath

# Show tier distribution
$tierDistribution = $gpuSorted | Group-Object -Property tier | Sort-Object -Property @{Expression={[int]$_.Name}; Descending=$true}
Write-Host "`n✓ GPU Tier Assignment Complete:"
Write-Host "Tier Distribution:"
foreach ($group in $tierDistribution) {
    Write-Host "  Tier $($group.Name): $($group.Count) GPUs"
}
Write-Host "`n✓ Updated gpuSorted.json with tier assignments" -ForegroundColor Green
