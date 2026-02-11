param(
    [string]$GpuSortedPath = "",
    [string]$BenchPath = "",
    [string]$MissingReportPath = "",
    [string]$ApproxReportPath = ""
)

$basePath = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($basePath)) {
    $basePath = Split-Path -Parent $MyInvocation.MyCommand.Path
}
if ([string]::IsNullOrWhiteSpace($GpuSortedPath)) {
    $GpuSortedPath = Join-Path -Path (Join-Path -Path $basePath -ChildPath "data") -ChildPath "gpuSorted.json"
}
if ([string]::IsNullOrWhiteSpace($BenchPath)) {
    $BenchPath = Join-Path -Path (Join-Path -Path $basePath -ChildPath "data") -ChildPath "gpuBenchmarks.json"
}
if ([string]::IsNullOrWhiteSpace($MissingReportPath)) {
    $MissingReportPath = Join-Path -Path (Join-Path -Path $basePath -ChildPath "data") -ChildPath "gpuBenchmarks.missing.txt"
}
if ([string]::IsNullOrWhiteSpace($ApproxReportPath)) {
    $ApproxReportPath = Join-Path -Path (Join-Path -Path $basePath -ChildPath "data") -ChildPath "gpuBenchmarks.approx.txt"
}

function NormalizeName {
    param([string]$name)
    if ([string]::IsNullOrWhiteSpace($name)) { return '' }
    return ($name.ToLower() -replace '[^a-z0-9 ]', '' -replace '\s+', ' ').Trim()
}

function Get-ApproxBaseAndMultiplier {
    param([string]$chipset)

    if ([string]::IsNullOrWhiteSpace($chipset)) { return $null }

    $base = $chipset
    $multiplier = 1.0

    if ($base -match '\bG6\b') { $base = $base -replace '\bG6\b', ''; $multiplier *= 1.03 }
    if ($base -match '\bG5\b') { $base = $base -replace '\bG5\b', ''; $multiplier *= 0.97 }

    if ($base -match '\bSUPER\b') { $base = $base -replace '\bSUPER\b', ''; $multiplier *= 1.05 }
    if ($base -match '\bTi\b') { $base = $base -replace '\bTi\b', ''; $multiplier *= 1.07 }
    if ($base -match '\bXT\b') { $base = $base -replace '\bXT\b', ''; $multiplier *= 1.05 }
    if ($base -match '\bXTX\b') { $base = $base -replace '\bXTX\b', ''; $multiplier *= 1.10 }
    if ($base -match '\bGRE\b') { $base = $base -replace '\bGRE\b', ''; $multiplier *= 1.03 }
    if ($base -match '\bSE\b') { $base = $base -replace '\bSE\b', ''; $multiplier *= 0.95 }
    if ($base -match '\bLE\b') { $base = $base -replace '\bLE\b', ''; $multiplier *= 0.98 }
    if ($base -match '\bLHR\b') { $base = $base -replace '\bLHR\b', '' }

    if ($base -match '\b(Laptop|Mobile|Max-Q)\b') { $base = $base -replace '\b(Laptop|Mobile|Max-Q)\b', ''; $multiplier *= 0.80 }

    if ($chipset -match '^Arc Pro A40$') { $base = 'Arc Pro A60'; $multiplier *= 0.85 }
    if ($chipset -match '^Arc Pro A50$') { $base = 'Arc Pro A60'; $multiplier *= 0.92 }

    $base = $base -replace '\s+\d+GB\b', ''
    $base = ($base -replace '\s+', ' ').Trim()

    if ([string]::IsNullOrWhiteSpace($base) -or $base -eq $chipset) { return $null }
    return [PSCustomObject]@{ base = $base; multiplier = $multiplier }
}

if (-not (Test-Path $GpuSortedPath)) {
    throw "gpuSorted.json not found: $GpuSortedPath"
}
if (-not (Test-Path $BenchPath)) {
    throw "gpuBenchmarks.json not found: $BenchPath"
}

$gpuSorted = Get-Content -Path $GpuSortedPath | ConvertFrom-Json
$benchRaw = Get-Content -Path $BenchPath | ConvertFrom-Json

$benchScores = @{}
if ($benchRaw -is [System.Collections.IEnumerable]) {
    foreach ($item in $benchRaw) {
        if ($null -ne $item.name -and $null -ne $item.score) {
            $benchScores[$item.name] = [double]$item.score
        }
    }
} else {
    $benchRaw.PSObject.Properties | ForEach-Object {
        if ($_.Name -notlike '_*') { $benchScores[$_.Name] = [double]$_.Value }
    }
}

$chipsets = $gpuSorted | Select-Object -ExpandProperty chipset -Unique
$missing = @()
foreach ($chipset in $chipsets) {
    if (-not $benchScores.ContainsKey($chipset)) {
        $missing += $chipset
    }
}

$approxMatches = @()
foreach ($chipset in $missing) {
    $approx = Get-ApproxBaseAndMultiplier -chipset $chipset
    if ($null -eq $approx) { continue }

    $baseKey = NormalizeName $approx.base
    $found = $null
    foreach ($k in $benchScores.Keys) {
        if ((NormalizeName $k) -eq $baseKey) { $found = $k; break }
    }

    if ($null -ne $found) {
        $score = [math]::Round(($benchScores[$found] * $approx.multiplier), 2)
        $benchScores[$chipset] = $score
        if ($benchRaw -isnot [System.Collections.IEnumerable]) {
            $benchRaw | Add-Member -NotePropertyName $chipset -NotePropertyValue $score -Force
        }
        $percent = [math]::Round((($approx.multiplier - 1.0) * 100), 1)
        $approxMatches += "$chipset -> $found ($percent%)"
    }
}

$remainingMissing = @()
foreach ($chipset in $chipsets) {
    if (-not $benchScores.ContainsKey($chipset)) {
        $remainingMissing += $chipset
    }
}

$remainingMissing | Sort-Object | Set-Content -Path $MissingReportPath
if ($approxMatches.Count -gt 0) {
    $approxMatches | Sort-Object | Set-Content -Path $ApproxReportPath
}

if ($benchRaw -is [System.Collections.IEnumerable]) {
    $out = @()
    $benchScores.Keys | Sort-Object | ForEach-Object {
        $out += [PSCustomObject]@{ name = $_; score = $benchScores[$_] }
    }
    $out | ConvertTo-Json -Depth 5 | Set-Content -Path $BenchPath
} else {
    $benchRaw | ConvertTo-Json -Depth 5 | Set-Content -Path $BenchPath
}

Write-Host "✓ GPU benchmark approximation complete. Added: $($approxMatches.Count)" -ForegroundColor Green
Write-Host "Remaining missing: $($remainingMissing.Count)" -ForegroundColor Yellow
Write-Host "Approx report: $ApproxReportPath"
Write-Host "Missing report: $MissingReportPath"
