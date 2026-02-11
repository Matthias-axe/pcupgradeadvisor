param(
    [string]$GpuSortedPath = "",
    [string]$BenchPath = "",
    [string]$MissingReportPath = "",
    [string]$VulkanUrl = "https://browser.geekbench.com/vulkan-benchmarks.json",
    [string]$OpenClUrl = "https://browser.geekbench.com/opencl-benchmarks.json"
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

function NormalizeGpuName {
    param([string]$name)
    if ([string]::IsNullOrWhiteSpace($name)) { return "" }

    $n = $name.ToLower()
    $n = $n -replace '\(.*?\)', ''
    $n = $n -replace '\[.*?\]', ''
    $n = $n -replace '\bcompute\s*engine\b', ''
    $n = $n -replace '\bgraphics\b', ''
    $n = $n -replace '\bseries\b', ''
    $n = $n -replace '\b(tm|r)\b', ''

    $n = $n -replace '\b(nvidia|amd|ati|intel|qualcomm|apple|samsung|mesa|microsoft)\b', ''

    $n = $n -replace '\b(laptop\s*gpu|laptop|mobile|max\-?q|notebook)\b', ''
    $n = $n -replace '\bgpu\b', ''
    $n = $n -replace '\blhr\b', ''
    $n = $n -replace '\b\d+gb\b', ''

    $n = $n -replace '[^a-z0-9 ]', ' '
    $n = ($n -replace '\s+', ' ').Trim()
    return $n
}

function ShouldSkipDevice {
    param([string]$name)
    if ([string]::IsNullOrWhiteSpace($name)) { return $true }
    if ($name -match '\b(Laptop|Mobile|Max-Q|Notebook)\b') { return $true }
    return $false
}

function AddScoreSample {
    param(
        [hashtable]$map,
        [string]$key,
        [double]$score,
        [int]$samples
    )

    if (-not $map.ContainsKey($key)) {
        $map[$key] = [PSCustomObject]@{ scoreSum = 0.0; sampleSum = 0 }
    }
    $map[$key].scoreSum += ($score * $samples)
    $map[$key].sampleSum += $samples
}

if (-not (Test-Path $GpuSortedPath)) {
    throw "gpuSorted.json not found: $GpuSortedPath"
}

$gpuSorted = Get-Content -Path $GpuSortedPath | ConvertFrom-Json
$chipsets = $gpuSorted | Select-Object -ExpandProperty chipset -Unique

Write-Host "Downloading Geekbench GPU benchmarks..." -ForegroundColor Cyan
$vulkanRaw = Invoke-RestMethod -Uri $VulkanUrl -Method Get
$openclRaw = Invoke-RestMethod -Uri $OpenClUrl -Method Get

$vulkanMap = @{}
$openclMap = @{}

foreach ($dev in $vulkanRaw.devices) {
    if (ShouldSkipDevice -name $dev.name) { continue }
    if ($null -eq $dev.score) { continue }
    $norm = NormalizeGpuName $dev.name
    if ([string]::IsNullOrWhiteSpace($norm)) { continue }
    $samples = if ($dev.samples) { [int]$dev.samples } else { 1 }
    AddScoreSample -map $vulkanMap -key $norm -score ([double]$dev.score) -samples $samples
}

foreach ($dev in $openclRaw.devices) {
    if (ShouldSkipDevice -name $dev.name) { continue }
    if ($null -eq $dev.score) { continue }
    $norm = NormalizeGpuName $dev.name
    if ([string]::IsNullOrWhiteSpace($norm)) { continue }
    $samples = if ($dev.samples) { [int]$dev.samples } else { 1 }
    AddScoreSample -map $openclMap -key $norm -score ([double]$dev.score) -samples $samples
}

function GetAverageScore {
    param([hashtable]$map, [string]$key)
    if (-not $map.ContainsKey($key)) { return $null }
    if ($map[$key].sampleSum -le 0) { return $null }
    return [math]::Round(($map[$key].scoreSum / $map[$key].sampleSum), 2)
}

$benchMap = [ordered]@{}
$benchMap._source = [PSCustomObject]@{
    provider = "Geekbench"
    vulkanUrl = $VulkanUrl
    openclUrl = $OpenClUrl
    blend = [PSCustomObject]@{ vulkan = 0.6; opencl = 0.4 }
    updated = (Get-Date -Format "yyyy-MM-dd")
}
$benchMap._instructions = "Auto-generated from Geekbench Vulkan/OpenCL GPU benchmarks. Scores are blended (60% Vulkan / 40% OpenCL)."

$missing = @()
$matched = 0
foreach ($chipset in $chipsets) {
    $normChip = NormalizeGpuName $chipset
    if ([string]::IsNullOrWhiteSpace($normChip)) { continue }

    $fallbackNorms = @()
    if ($chipset -match '\bG[56]\b') {
        $fallbackNorms += (NormalizeGpuName ($chipset -replace '\bG[56]\b', ''))
    }

    $vulkanScore = GetAverageScore -map $vulkanMap -key $normChip
    $openclScore = GetAverageScore -map $openclMap -key $normChip

    if ($null -eq $vulkanScore -and $fallbackNorms.Count -gt 0) {
        foreach ($alt in $fallbackNorms) {
            if ([string]::IsNullOrWhiteSpace($alt)) { continue }
            $vulkanScore = GetAverageScore -map $vulkanMap -key $alt
            if ($null -ne $vulkanScore) { break }
        }
    }
    if ($null -eq $openclScore -and $fallbackNorms.Count -gt 0) {
        foreach ($alt in $fallbackNorms) {
            if ([string]::IsNullOrWhiteSpace($alt)) { continue }
            $openclScore = GetAverageScore -map $openclMap -key $alt
            if ($null -ne $openclScore) { break }
        }
    }

    if ($null -ne $vulkanScore -and $null -ne $openclScore) {
        $combined = [math]::Round(($vulkanScore * 0.6) + ($openclScore * 0.4), 2)
        $benchMap[$chipset] = $combined
        $matched++
    } elseif ($null -ne $vulkanScore) {
        $benchMap[$chipset] = $vulkanScore
        $matched++
    } elseif ($null -ne $openclScore) {
        $benchMap[$chipset] = $openclScore
        $matched++
    } else {
        $missing += $chipset
    }
}

$missing | Sort-Object | Set-Content -Path $MissingReportPath
$benchMap | ConvertTo-Json -Depth 6 | Set-Content -Path $BenchPath

Write-Host "✓ Geekbench GPU benchmarks imported" -ForegroundColor Green
Write-Host "Matched: $matched" -ForegroundColor Green
Write-Host "Missing: $($missing.Count)" -ForegroundColor Yellow
Write-Host "Missing report: $MissingReportPath" -ForegroundColor Yellow