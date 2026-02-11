param(
    [string]$Url = "https://browser.geekbench.com/processor-benchmarks.json",
    [string]$CpuSortedPath = "",
    [string]$OutputPath = "",
    [string]$MissingReportPath = "",
    [string]$FuzzyReportPath = "",
    [switch]$IncludeAll,
    [switch]$Fuzzy,
    [switch]$Approximate,
    [string]$ApproxReportPath = "",
    [ValidateSet("single","multi")]
    [string]$ScoreType = "single"
)

$basePath = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($basePath)) {
    $basePath = Split-Path -Parent $MyInvocation.MyCommand.Path
}
if ([string]::IsNullOrWhiteSpace($CpuSortedPath)) {
    $CpuSortedPath = Join-Path -Path (Join-Path -Path $basePath -ChildPath "data") -ChildPath "cpuSorted.json"
}
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path -Path (Join-Path -Path $basePath -ChildPath "data") -ChildPath "cpuBenchmarks.json"
}
if ([string]::IsNullOrWhiteSpace($MissingReportPath)) {
    $MissingReportPath = Join-Path -Path (Join-Path -Path $basePath -ChildPath "data") -ChildPath "cpuBenchmarks.missing.txt"
}
if ([string]::IsNullOrWhiteSpace($FuzzyReportPath)) {
    $FuzzyReportPath = Join-Path -Path (Join-Path -Path $basePath -ChildPath "data") -ChildPath "cpuBenchmarks.fuzzy.txt"
}
if ([string]::IsNullOrWhiteSpace($ApproxReportPath)) {
    $ApproxReportPath = Join-Path -Path (Join-Path -Path $basePath -ChildPath "data") -ChildPath "cpuBenchmarks.approx.txt"
}

function NormalizeName {
    param([string]$name)
    if ([string]::IsNullOrWhiteSpace($name)) { return '' }
    return ($name.ToLower() -replace '[^a-z0-9 ]', '' -replace '\s+', ' ').Trim()
}

function Get-CandidateNames {
    param([string]$name)
    if ([string]::IsNullOrWhiteSpace($name)) { return @() }

    $candidates = New-Object System.Collections.Generic.List[string]
    $candidates.Add($name)

    $trimmed = $name -replace '\s*\(.*\)$', ''
    if ($trimmed -ne $name) { $candidates.Add($trimmed) }

    $noEdition = $trimmed -replace "\s+Avengers.*$", '' -replace "\s+Limited Edition$", '' -replace "\s+Collector's Edition$", ''
    if ($noEdition -ne $trimmed) { $candidates.Add($noEdition) }

    $swapXt = $noEdition -replace '\bXT\b', 'X'
    if ($swapXt -ne $noEdition) { $candidates.Add($swapXt) }

    $dropX3d = $swapXt -replace '\bX3D\b', 'X'
    if ($dropX3d -ne $swapXt) { $candidates.Add($dropX3d) }

    $dropT = $dropX3d -replace '\bT\b', ''
    if ($dropT -ne $dropX3d) { $candidates.Add(($dropT -replace '\s+', ' ').Trim()) }

    $dropF = $dropT -replace '\bF\b', ''
    if ($dropF -ne $dropT) { $candidates.Add(($dropF -replace '\s+', ' ').Trim()) }

    $swapGt = $dropF -replace '\bGT\b', 'G'
    if ($swapGt -ne $dropF) { $candidates.Add($swapGt) }

    return $candidates | Select-Object -Unique
}

function Get-ApproximateMatch {
    param([string]$name)

    if ([string]::IsNullOrWhiteSpace($name)) { return $null }

    $approxMap = @{
        "AMD Ryzen 5 5500GT" = @{ base = "AMD Ryzen 5 5600G"; multiplier = 0.95 }
        "AMD Ryzen 5 5600T" = @{ base = "AMD Ryzen 5 5600"; multiplier = 0.92 }
        "AMD Ryzen 5 5600XT" = @{ base = "AMD Ryzen 5 5600X"; multiplier = 1.03 }
        "AMD Ryzen 5 7600X3D" = @{ base = "AMD Ryzen 5 7600X"; multiplier = 1.05 }
        "AMD Ryzen 5 8400F" = @{ base = "AMD Ryzen 5 8500G"; multiplier = 0.95 }
        "AMD Ryzen 7 5800XT" = @{ base = "AMD Ryzen 7 5800X"; multiplier = 1.03 }
        "AMD Ryzen 9 5900XT" = @{ base = "AMD Ryzen 9 5900X"; multiplier = 1.03 }
        "Intel Core i9-10850KA Avengers Limited Edition" = @{ base = "Intel Core i9-10850K"; multiplier = 1.00 }
        "Intel Core i9-13900T" = @{ base = "Intel Core i9-13900"; multiplier = 0.90 }
    }

    if ($approxMap.ContainsKey($name)) {
        $entry = $approxMap[$name]
        return [PSCustomObject]@{ base = $entry.base; multiplier = [double]$entry.multiplier }
    }

    $base = $name
    $multiplier = 1.00

    if ($base -match '\bX3D\b') {
        $base = $base -replace '\bX3D\b', 'X'
        $multiplier = 1.05
    } elseif ($base -match '\bXT\b') {
        $base = $base -replace '\bXT\b', 'X'
        $multiplier = 1.03
    } elseif ($base -match '\bGT\b') {
        $base = $base -replace '\bGT\b', 'G'
        $multiplier = 1.02
    }

    if ($base -match '\bKA\b') {
        $base = $base -replace '\bKA\b', 'K'
        $multiplier = 1.00
    }

    if ($base -match '\bF\b') {
        $base = $base -replace '\bF\b', ''
        $base = ($base -replace '\s+', ' ').Trim()
        $multiplier = 1.00
    }

    if ($base -match '\bT\b$') {
        $base = $base -replace '\bT\b$', ''
        $base = ($base -replace '\s+', ' ').Trim()
        $multiplier = 0.92
    }

    $base = $base -replace '\s+Avengers.*$', '' -replace '\s+Limited Edition$', '' -replace '\s+Collector''s Edition$', ''
    $base = ($base -replace '\s+', ' ').Trim()

    if ([string]::IsNullOrWhiteSpace($base) -or $base -eq $name) {
        return $null
    }

    return [PSCustomObject]@{ base = $base; multiplier = $multiplier }
}

Write-Host "Downloading Geekbench CPU benchmarks..." -ForegroundColor Cyan
try {
    $gb = Invoke-RestMethod -Uri $Url -Method Get -Headers @{ "Accept" = "application/json" }
} catch {
    throw "Failed to download Geekbench data from $Url. $($_.Exception.Message)"
}

if ($null -eq $gb -or $null -eq $gb.devices) {
    throw "Geekbench data missing 'devices' array."
}

$scoreField = if ($ScoreType -eq "multi") { "multicore_score" } else { "score" }

$gbScores = @{}
foreach ($device in $gb.devices) {
    $name = $device.name
    $scoreRaw = $device.$scoreField
    if ([string]::IsNullOrWhiteSpace($name) -or $null -eq $scoreRaw) { continue }

    $score = [double]$scoreRaw
    if ($score -le 0) { continue }

    $key = NormalizeName $name
    if (-not $gbScores.ContainsKey($key) -or $score -gt $gbScores[$key].score) {
        $gbScores[$key] = [PSCustomObject]@{ name = $name; score = $score }
    }
}

$benchmarks = [ordered]@{
    _instructions = "Populate from Geekbench Browser CPU Benchmarks. Use exact CPU names from cpuSorted.json."
    _source = "Geekbench Browser CPU Benchmarks"
    _sourceUrl = $Url
    _scoreType = $ScoreType
    _updated = (Get-Date -Format 'yyyy-MM-dd')
}

$missing = @()
$fuzzyMatches = @()
$approxMatches = @()
if ($IncludeAll) {
    foreach ($entry in ($gbScores.Values | Sort-Object -Property name)) {
        $benchmarks[$entry.name] = $entry.score
    }
} else {
    if (-not (Test-Path $CpuSortedPath)) {
        throw "cpuSorted.json not found: $CpuSortedPath"
    }

    $cpuSorted = Get-Content -Path $CpuSortedPath | ConvertFrom-Json
    $cpuNames = $cpuSorted | Select-Object -ExpandProperty name -Unique

    foreach ($cpuName in $cpuNames) {
        $key = NormalizeName $cpuName
        if ($gbScores.ContainsKey($key)) {
            $benchmarks[$cpuName] = $gbScores[$key].score
        } else {
            $missing += $cpuName
        }
    }

    if ($Fuzzy -and $missing.Count -gt 0) {
        $stillMissing = @()
        foreach ($cpuName in $missing) {
            $matched = $null
            foreach ($candidate in (Get-CandidateNames -name $cpuName)) {
                $candidateKey = NormalizeName $candidate
                if ($gbScores.ContainsKey($candidateKey)) {
                    $matched = $gbScores[$candidateKey]
                    break
                }
            }

            if ($null -ne $matched) {
                $benchmarks[$cpuName] = $matched.score
                $fuzzyMatches += "$cpuName -> $($matched.name)"
            } else {
                $stillMissing += $cpuName
            }
        }

        $missing = $stillMissing
    }

    if ($Approximate -and $missing.Count -gt 0) {
        $stillMissing = @()
        foreach ($cpuName in $missing) {
            $approx = Get-ApproximateMatch -name $cpuName
            if ($null -eq $approx) {
                $stillMissing += $cpuName
                continue
            }

            $approxKey = NormalizeName $approx.base
            if ($gbScores.ContainsKey($approxKey)) {
                $score = [math]::Round(($gbScores[$approxKey].score * $approx.multiplier), 2)
                $benchmarks[$cpuName] = $score
                $percent = [math]::Round((($approx.multiplier - 1.0) * 100), 1)
                $approxMatches += "$cpuName -> $($gbScores[$approxKey].name) ($percent%)"
            } else {
                $stillMissing += $cpuName
            }
        }

        $missing = $stillMissing
    }

    if ($MissingReportPath) {
        $missing | Sort-Object | Set-Content -Path $MissingReportPath
    }
    if ($FuzzyReportPath -and $fuzzyMatches.Count -gt 0) {
        $fuzzyMatches | Sort-Object | Set-Content -Path $FuzzyReportPath
    }
    if ($ApproxReportPath -and $approxMatches.Count -gt 0) {
        $approxMatches | Sort-Object | Set-Content -Path $ApproxReportPath
    }
}

$benchmarks | ConvertTo-Json -Depth 5 | Set-Content -Path $OutputPath

Write-Host "✓ Geekbench import complete. Entries: $($benchmarks.Keys.Count - 5)" -ForegroundColor Green
if (-not $IncludeAll) {
    Write-Host "Missing benchmarks: $($missing.Count)" -ForegroundColor Yellow
    if ($MissingReportPath) { Write-Host "Missing list: $MissingReportPath" }
    if ($FuzzyReportPath -and $fuzzyMatches.Count -gt 0) { Write-Host "Fuzzy matches: $FuzzyReportPath" }
    if ($ApproxReportPath -and $approxMatches.Count -gt 0) { Write-Host "Approx matches: $ApproxReportPath" }
}
