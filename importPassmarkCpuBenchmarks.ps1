param(
    [Parameter(Mandatory = $true)]
    [string]$CsvPath,
    [string]$CpuSortedPath = "",
    [string]$OutputPath = "",
    [string]$MissingReportPath = "",
    [switch]$IncludeAll,
    [string]$NameColumn = "CPU Name",
    [string]$ScoreColumn = "CPU Mark"
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

function NormalizeName {
    param([string]$name)
    if ([string]::IsNullOrWhiteSpace($name)) { return '' }
    return ($name.ToLower() -replace '[^a-z0-9 ]', '' -replace '\s+', ' ').Trim()
}

if (-not (Test-Path $CsvPath)) {
    throw "CSV not found: $CsvPath"
}

$csv = Import-Csv -Path $CsvPath
if (-not $csv -or $csv.Count -eq 0) {
    throw "CSV is empty or unreadable: $CsvPath"
}

$columns = $csv[0].PSObject.Properties.Name
if (-not ($columns -contains $NameColumn)) {
    $nameCandidates = @('CPU Name','Processor','CPU','Name')
    $NameColumn = $nameCandidates | Where-Object { $columns -contains $_ } | Select-Object -First 1
}
if (-not $NameColumn) {
    throw "Could not detect CPU name column. Available columns: $($columns -join ', ')"
}

if (-not ($columns -contains $ScoreColumn)) {
    $scoreCandidates = @('CPU Mark','CPUMark','CPU_Mark','Score','Mark')
    $ScoreColumn = $scoreCandidates | Where-Object { $columns -contains $_ } | Select-Object -First 1
}
if (-not $ScoreColumn) {
    throw "Could not detect CPU score column. Available columns: $($columns -join ', ')"
}

$passmark = @{}
foreach ($row in $csv) {
    $name = $row.$NameColumn
    $scoreRaw = $row.$ScoreColumn
    if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($scoreRaw)) { continue }

    $scoreClean = ($scoreRaw -replace '[^0-9\.]', '')
    if ([string]::IsNullOrWhiteSpace($scoreClean)) { continue }
    $score = [double]$scoreClean
    if ($score -le 0) { continue }

    $key = NormalizeName $name
    if (-not $passmark.ContainsKey($key) -or $score -gt $passmark[$key].score) {
        $passmark[$key] = [PSCustomObject]@{ name = $name; score = $score }
    }
}

$benchmarks = [ordered]@{
    _instructions = "Populate from PassMark CPU Mark data. Use exact CPU names from cpuSorted.json."
    _source = "PassMark CPU Benchmark (CPU Mark)"
    _sourceUrl = "https://www.cpubenchmark.net/"
    _updated = (Get-Date -Format 'yyyy-MM-dd')
}

$missing = @()
if ($IncludeAll) {
    foreach ($entry in ($passmark.Values | Sort-Object -Property name)) {
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
        if ($passmark.ContainsKey($key)) {
            $benchmarks[$cpuName] = $passmark[$key].score
        } else {
            $missing += $cpuName
        }
    }

    if ($MissingReportPath) {
        $missing | Sort-Object | Set-Content -Path $MissingReportPath
    }
}

$benchmarks | ConvertTo-Json -Depth 5 | Set-Content -Path $OutputPath

Write-Host "✓ PassMark import complete. Entries: $($benchmarks.Keys.Count - 4)" -ForegroundColor Green
if (-not $IncludeAll) {
    Write-Host "Missing benchmarks: $($missing.Count)" -ForegroundColor Yellow
    if ($MissingReportPath) { Write-Host "Missing list: $MissingReportPath" }
}
