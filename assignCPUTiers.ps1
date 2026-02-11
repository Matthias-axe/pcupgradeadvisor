# Read the sorted CPU data
$cpuSortedPath = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "data") -ChildPath "cpuSorted.json"
$cpuData = Get-Content -Path $cpuSortedPath | ConvertFrom-Json

# Optional benchmark overrides
$cpuBenchPath = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "data") -ChildPath "cpuBenchmarks.json"
$cpuBenchScores = @{}
if (Test-Path $cpuBenchPath) {
    $benchRaw = Get-Content -Path $cpuBenchPath | ConvertFrom-Json
    if ($benchRaw -is [System.Collections.IEnumerable]) {
        foreach ($item in $benchRaw) {
            if ($null -ne $item.name -and $null -ne $item.score) {
                $cpuBenchScores[$item.name] = [double]$item.score
            }
        }
    } else {
        $benchRaw.PSObject.Properties | ForEach-Object {
            if ($_.Name -notlike '_*') { $cpuBenchScores[$_.Name] = [double]$_.Value }
        }
    }
}

function NormalizeName {
    param([string]$name)
    if ([string]::IsNullOrWhiteSpace($name)) { return '' }
    return ($name.ToLower() -replace '[^a-z0-9 ]', '' -replace '\s+', ' ').Trim()
}

# Filter out outdated CPUs (keep only those still in use: Intel 9th gen+, AMD Ryzen 2000+)
$cpuFiltered = $cpuData | Where-Object {
    $gen = $_.generation
    $name = $_.name
    
    # Intel: Keep 9th gen and newer
    if ($name -like '*Core i*' -and $gen -ge 9) {
        $true
    }
    # AMD: Keep Ryzen 2000 and newer (generation 8+, which is Zen+)
    elseif ($name -like '*Ryzen*' -and $gen -ge 8) {
        $true
    }
    else {
        $false
    }
}

Write-Host "Filtered CPUs: $($cpuFiltered.Count) from $($cpuData.Count) total"

# Get min/max values for normalization
$coreValues = @($cpuFiltered | Where-Object { $_.core_count } | ForEach-Object { $_.core_count })
$boostValues = @($cpuFiltered | Where-Object { $_.boost_clock } | ForEach-Object { $_.boost_clock })
$genValues = @($cpuFiltered | Where-Object { $_.generation } | ForEach-Object { $_.generation })

$benchValues = @()
if ($cpuBenchScores.Count -gt 0) {
    $benchValues = @($cpuBenchScores.Values)
}

$minCores = ($coreValues | Measure-Object -Minimum).Minimum
$maxCores = ($coreValues | Measure-Object -Maximum).Maximum
$minBoost = ($boostValues | Measure-Object -Minimum).Minimum
$maxBoost = ($boostValues | Measure-Object -Maximum).Maximum
$minGen = ($genValues | Measure-Object -Minimum).Minimum
$maxGen = ($genValues | Measure-Object -Maximum).Maximum
$minBench = if ($benchValues.Count -gt 0) { ($benchValues | Measure-Object -Minimum).Minimum } else { 0 }
$maxBench = if ($benchValues.Count -gt 0) { ($benchValues | Measure-Object -Maximum).Maximum } else { 0 }

Write-Host "CPU Performance Ranges:"
Write-Host "  Cores: $minCores - $maxCores"
Write-Host "  Boost Clock: $minBoost GHz - $maxBoost GHz"
Write-Host "  Generation: $minGen - $maxGen"

# Function to normalize a value to 0-1 range
function Normalize {
    param([double]$value, [double]$min, [double]$max)
    if ($max -eq $min) { return 0.5 }
    return ([math]::Max(0, [math]::Min(1, ($value - $min) / ($max - $min))))
}

# Calculate score for each CPU
$cpuWithScores = @()
foreach ($cpu in $cpuFiltered) {
    # Normalize performance metrics
    $coreNorm = Normalize -value $cpu.core_count -min $minCores -max $maxCores
    $boostNorm = Normalize -value $cpu.boost_clock -min $minBoost -max $maxBoost
    $genNorm = Normalize -value $cpu.generation -min $minGen -max $maxGen
    
    $benchKey = NormalizeName $cpu.name
    $benchScore = $null
    if ($benchKey -and $cpuBenchScores.Count -gt 0) {
        foreach ($k in $cpuBenchScores.Keys) {
            if ((NormalizeName $k) -eq $benchKey) { $benchScore = $cpuBenchScores[$k]; break }
        }
    }

    $specScore = ($boostNorm * 0.60) + ($coreNorm * 0.30) + ($genNorm * 0.10)
    if ($null -ne $benchScore -and $maxBench -gt $minBench) {
        $benchNorm = Normalize -value $benchScore -min $minBench -max $maxBench
        $combinedScore = ($benchNorm * 0.70) + ($specScore * 0.30)
    } else {
        # Fallback to spec-only score when benchmark is missing
        $combinedScore = $specScore
    }
    
    $cpu | Add-Member -NotePropertyName "score" -NotePropertyValue $combinedScore -Force
    $cpuWithScores += $cpu
}

# Sort by score descending
$cpuSorted = $cpuWithScores | Sort-Object -Property score -Descending

# Assign tiers using equal-percentile bucketing (7 equal-sized tiers for balanced coverage)
$cpuCount = $cpuSorted.Count
$tierCount = 7
$tierSize = [math]::Ceiling($cpuCount / $tierCount)

for ($i = 0; $i -lt $cpuSorted.Count; $i++) {
    $tier = [int]($tierCount - [math]::Floor($i / $tierSize))
    $tier = [math]::Max(1, [math]::Min($tierCount, $tier))
    $cpuSorted[$i] | Add-Member -NotePropertyName "tier" -NotePropertyValue $tier -Force
}

# Remove the temporary score property
foreach ($cpu in $cpuSorted) {
    $cpu.PSObject.Properties.Remove('score')
}

# Write updated data back to file
$outputPath = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "data") -ChildPath "cpuSorted.json"
$cpuSorted | ConvertTo-Json -Depth 10 | Set-Content -Path $outputPath

# Show tier distribution
$tierDistribution = $cpuSorted | Group-Object -Property tier | Sort-Object -Property @{Expression={[int]$_.Name}; Descending=$true}
Write-Host "`n✓ CPU Tier Assignment Complete:"
Write-Host "Tier Distribution:"
foreach ($group in $tierDistribution) {
    Write-Host "  Tier $($group.Name): $($group.Count) CPUs"
}
Write-Host "`n✓ Updated cpuSorted.json with tier assignments" -ForegroundColor Green
