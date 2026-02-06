$ErrorActionPreference = 'Stop'

$port = 8000
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
	$python = Get-Command py -ErrorAction SilentlyContinue
}

if (-not $python) {
	Write-Host 'Python not found. Install Python 3 from https://www.python.org/downloads/ then re-run.' -ForegroundColor Yellow
	exit 1
}

Write-Host "Starting local server at http://localhost:$port" -ForegroundColor Green
& $python.Source -m http.server $port
