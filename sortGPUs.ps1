# Read the raw GPU data
$gpuRawPath = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "data") -ChildPath "gpuRaw.json"
$gpuData = Get-Content -Path $gpuRawPath | ConvertFrom-Json

# Map chipset to generation number
$gpuGenerationMap = @{
    # NVIDIA GeForce Series (Consumer)
    'GeForce GTX 1060' = 4
    'GeForce GTX 1070' = 4
    'GeForce GTX 1080' = 4
    'GeForce RTX 2060' = 6
    'GeForce RTX 2070' = 6
    'GeForce RTX 2080' = 6
    'GeForce GTX 1650' = 5
    'GeForce GTX 1660' = 5
    'GeForce RTX 3060' = 8
    'GeForce RTX 3070' = 8
    'GeForce RTX 3080' = 8
    'GeForce RTX 3090' = 8
    'GeForce RTX 4060' = 10
    'GeForce RTX 4070' = 10
    'GeForce RTX 4080' = 10
    'GeForce RTX 4090' = 10
    'GeForce RTX 5070' = 12
    'GeForce RTX 5070 Ti' = 12
    'GeForce RTX 5090' = 12
    
    # AMD Radeon Series (Consumer)
    'Radeon RX 5500' = 7
    'Radeon RX 5600' = 7
    'Radeon RX 5700' = 7
    'Radeon RX 6500' = 9
    'Radeon RX 6600' = 9
    'Radeon RX 6700' = 9
    'Radeon RX 6800' = 9
    'Radeon RX 7600' = 11
    'Radeon RX 7700' = 11
    'Radeon RX 7800' = 11
    'Radeon RX 7900' = 11
    'Radeon RX 9060' = 13
    'Radeon RX 9070' = 13
    'Radeon RX 9080' = 13
    'Radeon RX 9090' = 13
    
    # Intel Arc Series
    'Arc A310' = 1
    'Arc A380' = 1
    'Arc A580' = 1
    'Arc A750' = 2
    'Arc A770' = 2
    'Arc B580' = 3
    'Arc B570' = 3
    
    # AMD FireGL/FirePro (Professional/Legacy)
    'FireGL' = 3
    'FirePro' = 4
}


# Create array with sort keys
$gpuDataWithKeys = @()
foreach ($gpu in $gpuData) {
    # Extract generation from chipset name using more flexible matching
    $gen = 0
    $chipset = $gpu.chipset
    
    # NVIDIA RTX 50 Series (Current Gen)
    if ($chipset -like '*5090*') {
        $gen = 12.7
    } elseif ($chipset -like '*5080*') {
        $gen = 12.6
    } elseif ($chipset -like '*5070 Ti*') {
        $gen = 12.5
    } elseif ($chipset -like '*5070*') {
        $gen = 12.4
    } elseif ($chipset -like '*5060*') {
        $gen = 12.3
    }
    # NVIDIA RTX 40 Series
    elseif ($chipset -like '*4090*') {
        $gen = 10.7
    } elseif ($chipset -like '*4080*') {
        $gen = 10.6
    } elseif ($chipset -like '*4070 Ti*') {
        $gen = 10.5
    } elseif ($chipset -like '*4070*') {
        $gen = 10.4
    } elseif ($chipset -like '*4060 Ti*') {
        $gen = 10.2
    } elseif ($chipset -like '*4060*') {
        $gen = 10.1
    }
    # NVIDIA RTX 30 Series
    elseif ($chipset -like '*3090*') {
        $gen = 8.7
    } elseif ($chipset -like '*3080*') {
        $gen = 8.6
    } elseif ($chipset -like '*3070*') {
        $gen = 8.5
    } elseif ($chipset -like '*3060*') {
        $gen = 8.3
    }
    # NVIDIA GTX 10 Series
    elseif ($chipset -like '*1080 Ti*') {
        $gen = 4.7
    } elseif ($chipset -like '*1080*') {
        $gen = 4.6
    } elseif ($chipset -like '*1070 Ti*') {
        $gen = 4.5
    } elseif ($chipset -like '*1070*') {
        $gen = 4.4
    } elseif ($chipset -like '*1060*') {
        $gen = 4.2
    }
    # NVIDIA RTX 20 Series
    elseif ($chipset -like '*2090*') {
        $gen = 6.7
    } elseif ($chipset -like '*2080*') {
        $gen = 6.6
    } elseif ($chipset -like '*2070*') {
        $gen = 6.5
    } elseif ($chipset -like '*2060*') {
        $gen = 6.3
    }
    # NVIDIA GTX 16 Series
    elseif ($chipset -like '*1660*') {
        $gen = 5.2
    } elseif ($chipset -like '*1650*') {
        $gen = 5.1
    }
    # AMD RX 9000 Series
    elseif ($chipset -like '*9090*') {
        $gen = 13.7
    } elseif ($chipset -like '*9080*') {
        $gen = 13.6
    } elseif ($chipset -like '*9070 XT*') {
        $gen = 13.5
    } elseif ($chipset -like '*9070*') {
        $gen = 13.4
    } elseif ($chipset -like '*9060 XT*') {
        $gen = 13.3
    } elseif ($chipset -like '*9060*') {
        $gen = 13.2
    }
    # AMD RX 7000 Series
    elseif ($chipset -like '*7900 XTX*') {
        $gen = 11.7
    } elseif ($chipset -like '*7900 XT*') {
        $gen = 11.6
    } elseif ($chipset -like '*7800 XT*') {
        $gen = 11.5
    } elseif ($chipset -like '*7700 XT*') {
        $gen = 11.4
    } elseif ($chipset -like '*7600 XT*') {
        $gen = 11.2
    } elseif ($chipset -like '*7600*') {
        $gen = 11.1
    }
    # AMD RX 6000 Series
    elseif ($chipset -like '*6900 XTX*') {
        $gen = 9.7
    } elseif ($chipset -like '*6900 XT*') {
        $gen = 9.6
    } elseif ($chipset -like '*6800 XT*') {
        $gen = 9.5
    } elseif ($chipset -like '*6700 XT*') {
        $gen = 9.4
    } elseif ($chipset -like '*6600 XT*') {
        $gen = 9.2
    } elseif ($chipset -like '*6600*') {
        $gen = 9.1
    }
    # AMD RX 5000 Series
    elseif ($chipset -like '*5700 XT*') {
        $gen = 7.5
    } elseif ($chipset -like '*5700*') {
        $gen = 7.4
    } elseif ($chipset -like '*5600 XT*') {
        $gen = 7.2
    } elseif ($chipset -like '*5600*') {
        $gen = 7.1
    }
    # Intel Arc Battlemage
    elseif ($chipset -like '*Arc B*' -or $chipset -like '*Battlemage*') {
        $gen = 3
    }
    # Intel Arc Alchemist
    elseif ($chipset -like '*Arc A*') {
        $gen = 2
    }
    # AMD FirePro
    elseif ($chipset -like '*FirePro*') {
        $gen = 4
    }
    # AMD FireGL
    elseif ($chipset -like '*FireGL*') {
        $gen = 3
    }
    
    $boost = $gpu.boost_clock
    if ($null -eq $boost -or $boost -eq 0) { $boost = $gpu.core_clock }
    
    # Add generation field to the GPU object
    $gpu | Add-Member -NotePropertyName "generation" -NotePropertyValue $gen -Force
    
    $gpuDataWithKeys += [PSCustomObject]@{
        Original = $gpu
        Generation = $gen
        BoostClock = $boost
        Memory = $gpu.memory
        CoreClock = $gpu.core_clock
    }
}

# Sort by generation (desc), then boost clock (desc), then memory (desc), then core clock (desc)
$sorted = $gpuDataWithKeys | Sort-Object `
    @{ Expression = { $_.Generation }; Descending = $true }, `
    @{ Expression = { $_.BoostClock }; Descending = $true }, `
    @{ Expression = { $_.Memory }; Descending = $true }, `
    @{ Expression = { $_.CoreClock }; Descending = $true }

# Extract original data
$sortedGpus = $sorted | ForEach-Object { $_.Original }

# Write sorted data to new file
$outputPath = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "data") -ChildPath "gpuSorted.json"
$sortedGpus | ConvertTo-Json -Depth 10 | Set-Content -Path $outputPath

Write-Host "✓ Sorted $($sortedGpus.Count) GPUs and saved to gpuSorted.json" -ForegroundColor Green
