# Read the raw CPU data
$cpuRawPath = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "data") -ChildPath "cpuRaw.json"
$cpuData = Get-Content -Path $cpuRawPath | ConvertFrom-Json

# Map microarchitecture to generation number
# AMD and Intel equivalent generations use the same value
$generationMap = @{
    # AMD Zen
    'Zen 1' = 7         # 2017, roughly equivalent to 7th Gen Intel
    'Zen+' = 8          # 2018, roughly equivalent to 8th Gen Intel
    'Zen 2' = 9         # 2019, roughly equivalent to 9th Gen Intel
    'Zen 3' = 11        # 2020, roughly equivalent to 11th Gen Intel
    'Zen 4' = 12        # 2022, roughly equivalent to 12th Gen Intel
    'Zen 5' = 14        # 2024, roughly equivalent to 14th Gen Intel (Arrow Lake)
    
    # Intel Codenames
    '7th Gen' = 7
    '8th Gen' = 8
    '9th Gen' = 9
    '10th Gen' = 10
    'Comet Lake' = 10
    '11th Gen' = 11
    'Rocket Lake' = 11
    '12th Gen' = 12
    'Alder Lake' = 12
    '13th Gen' = 13
    'Raptor Lake' = 13
    'Raptor Lake Refresh' = 13
    '14th Gen' = 14
    'Arrow Lake' = 14
}

# Filter out EPYC/server CPUs and remove duplicates
$cpuDataFiltered = $cpuData | Where-Object { $_.name -notlike "*EPYC*" } | Group-Object -Property name | ForEach-Object { $_.Group[0] }

# Create array with sort keys
$cpuDataWithKeys = @()
foreach ($cpu in $cpuDataFiltered) {
    $gen = $generationMap[$cpu.microarchitecture]
    if ($null -eq $gen) { $gen = 0 }
    
    $boost = $cpu.boost_clock
    if ($null -eq $boost -or $boost -eq 0) { $boost = $cpu.core_clock }
    
    # Add generation field to the CPU object
    $cpu | Add-Member -NotePropertyName "generation" -NotePropertyValue $gen -Force
    
    $cpuDataWithKeys += [PSCustomObject]@{
        Original = $cpu
        Generation = $gen
        BoostClock = $boost
        CoreCount = $cpu.core_count
        CoreClock = $cpu.core_clock
    }
}

# Sort by generation (desc), then cores (desc), then boost clock (desc)
$sorted = $cpuDataWithKeys | Sort-Object `
    @{ Expression = { $_.Generation }; Descending = $true }, `
    @{ Expression = { $_.CoreCount }; Descending = $true }, `
    @{ Expression = { $_.BoostClock }; Descending = $true }

# Extract original data
$sortedCpus = $sorted | ForEach-Object { $_.Original }

# Write sorted data to new file
$outputPath = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "data") -ChildPath "cpuSorted.json"
$sortedCpus | ConvertTo-Json -Depth 10 | Set-Content -Path $outputPath

Write-Host "✓ Sorted $($sortedCpus.Count) CPUs and saved to cpuSorted.json" -ForegroundColor Green
