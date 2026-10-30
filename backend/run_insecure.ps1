<#
.SYNOPSIS
    DEMO-DAY EMERGENCY ONLY: starts the API without TLS on port 8080.

.DESCRIPTION
    Use this only if the self-signed certificate path fails 15 minutes before
    the demo. The Flutter app must be started with:
        flutter run --dart-define=API_BASE=http://<LAPTOP_IP>:8080 `
                    --dart-define=DEV_INSECURE=true `
                    --dart-define=API_TOKEN=demo-token
    Revert to .\run.ps1 for the judged run whenever possible — TLS is part of
    the product story.
#>
$ErrorActionPreference = 'Stop'
Set-Location -Path $PSScriptRoot

Write-Host '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!' -ForegroundColor Red
Write-Host '  INSECURE MODE: plain HTTP, no TLS. Demo fallback only.'      -ForegroundColor Red
Write-Host '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!' -ForegroundColor Red

if (-not $env:API_TOKEN)        { $env:API_TOKEN = 'demo-token' }
if (-not $env:OLLAMA_URL)       { $env:OLLAMA_URL = 'http://127.0.0.1:11434' }
if (-not $env:OLLAMA_MODEL)     { $env:OLLAMA_MODEL = 'qwen2.5:7b' }
if (-not $env:ENABLE_DEV_RESET) { $env:ENABLE_DEV_RESET = '1' }

$pythonCommand = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCommand) {
    throw "python not found. Install: winget install --id Python.Python.3.12 -e"
}
$python = $pythonCommand.Source

& $python -c "import uvicorn, fastapi, httpx, pydantic" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host '==> Installing Python dependencies...' -ForegroundColor Cyan
    & $python -m pip install --disable-pip-version-check -r requirements.txt
    if ($LASTEXITCODE -ne 0) { throw 'pip install failed' }
}

$lanIps = @()
try {
    $lanIps = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
        Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
        Select-Object -ExpandProperty IPAddress)
} catch {
    try { $lanIps = @(ipconfig | Select-String 'IPv4' | ForEach-Object { ($_.Line -split ':')[-1].Trim() }) } catch { }
}

$primary = if ($lanIps.Count -gt 0) { $lanIps[0] } else { '<LAPTOP_IP>' }
Write-Host ''
Write-Host "  status page : http://$primary`:8080/"
Write-Host "  health      : http://$primary`:8080/healthz"
Write-Host ''
Write-Host '  Flutter on phones:' -ForegroundColor Yellow
Write-Host "    flutter run --dart-define=API_BASE=http://$primary`:8080 --dart-define=DEV_INSECURE=true --dart-define=API_TOKEN=$env:API_TOKEN" -ForegroundColor Yellow
Write-Host ''

& $python -m uvicorn app.main:app --host 0.0.0.0 --port 8080
exit $LASTEXITCODE
