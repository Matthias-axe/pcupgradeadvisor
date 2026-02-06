$ram = Get-Content data/ramSorted.json | ConvertFrom-Json

$tier4 = $ram | Where-Object { $_.tier -eq 4 } | Select-Object -First 5

Write-Host "Sample Tier 4 RAM configs:"
foreach ($r in $tier4) {
    $cap = if ($r.name -match '\s(\d+)\s*GB') { $matches[1] } else { "???" }
    Write-Host "Name: $($r.name)"
    Write-Host "  Capacity: $cap GB"
    Write-Host "  Speed: $($r.speed)"
    Write-Host "  Modules: $($r.modules)"
    Write-Host ""
}
