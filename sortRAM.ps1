# Read the raw RAM data
$ramRawPath = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "data") -ChildPath "ramRaw.json"
$ramData = Get-Content -Path $ramRawPath | ConvertFrom-Json

# Map RAM speed to generation number
$ramGenerationMap = @{
    '3200' = 8
    '3600' = 9
    '4000' = 9
    '4800' = 10
    '5600' = 11
    '6000' = 12
    '6400' = 13
    '7200' = 14
    '8000' = 15
}

# Create array with sort keys
$ramDataWithKeys = @()
foreach ($ram in $ramData) {
    # Extract speed from the speed field (removing commas and DDR prefix)
    $speedStr = $ram.speed -replace ',', ''
    
    # Remove DDR prefix (first digit like 3, 4, 5 which indicates DDR3, DDR4, DDR5)
    $numSpeed = [int]($speedStr -replace '[a-zA-Z]', '' -replace '^.', '')
    
    # Get generation based on speed
    $gen = 0
    foreach ($speed in $ramGenerationMap.Keys) {
        if ($numSpeed -eq [int]$speed) {
            $gen = $ramGenerationMap[$speed]
            break
        }
    }
    # Default to closest match if exact not found
    if ($gen -eq 0) {
        if ($numSpeed -ge 8000) { $gen = 15 }
        elseif ($numSpeed -ge 7200) { $gen = 14 }
        elseif ($numSpeed -ge 6400) { $gen = 13 }
        elseif ($numSpeed -ge 6000) { $gen = 12 }
        elseif ($numSpeed -ge 5600) { $gen = 11 }
        elseif ($numSpeed -ge 4800) { $gen = 10 }
        elseif ($numSpeed -ge 4000) { $gen = 9 }
        else { $gen = 8 }
    }
    
    # Extract total GB from modules field (format is like "2,16" meaning 2 modules of 16GB = 32GB total)
    $moduleParts = $ram.modules -split ','
    $totalGb = [int]$moduleParts[0] * [int]$moduleParts[1]
    
    # Add generation field to the RAM object
    $ram | Add-Member -NotePropertyName "generation" -NotePropertyValue $gen -Force
    
    $ramDataWithKeys += [PSCustomObject]@{
        Original = $ram
        Generation = $gen
        TotalGb = $totalGb
        Speed = $numSpeed
    }
}

# Sort by generation (desc), then total GB (desc), then speed (desc)
$sorted = $ramDataWithKeys | Sort-Object `
    @{ Expression = { $_.Generation }; Descending = $true }, `
    @{ Expression = { $_.TotalGb }; Descending = $true }, `
    @{ Expression = { $_.Speed }; Descending = $true }

# Extract original data
$sortedRam = $sorted | ForEach-Object { $_.Original }

# Write sorted data to new file
$outputPath = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "data") -ChildPath "ramSorted.json"
$sortedRam | ConvertTo-Json -Depth 10 | Set-Content -Path $outputPath

Write-Host "✓ Sorted $($sortedRam.Count) RAM modules and saved to ramSorted.json" -ForegroundColor Green
