$gpu = Get-Content data/gpuSorted.json | ConvertFrom-Json
Write-Host "First 5 GPUs:"
for ($i = 0; $i -lt 5; $i++) {
    Write-Host "$($gpu[$i].name) - T$($gpu[$i].tier) @ $($gpu[$i].boost_clock) MHz"
}

Write-Host "`nLast 5 GPUs:"
for ($i = $gpu.Count - 5; $i -lt $gpu.Count; $i++) {
    Write-Host "$($gpu[$i].name) - T$($gpu[$i].tier) @ $($gpu[$i].boost_clock) MHz"
}
