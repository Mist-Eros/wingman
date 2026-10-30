<#
.SYNOPSIS
    Starts the Wingman API with TLS (HTTPS + WSS) on port 8443.

.DESCRIPTION
    - Requires backend\certs\server.crt + server.key (run ..\scripts\gen_certs.ps1).
    - Requires Python 3.10+ (winget install --id Python.Python.3.12 -e).
    - Installs backend/requirements.txt on first run.
    - Prints the exact Flutter command for the demo devices.

.EXAMPLE
    .\run.ps1
    $env:OLLAMA_MODEL='llama3.1:8b'; .\run.ps1
#>
$ErrorActionPreference = 'Stop'
Set-Location -Path $PSScriptRoot

function Write-Step([string]$Message) {
    Write-Host "==> $Message" -ForegroundColor Cyan
}

# ── defaults (override from the shell if needed; see .env.example) ───────────
if (-not $env:API_TOKEN)        { $env:API_TOKEN = 'demo-token' }
if (-not $env:OLLAMA_URL)       { $env:OLLAMA_URL = 'http://127.0.0.1:11434' }
# 1.5b = fast on the demo laptop (CPU or the RTX 4060); qwen2.5:7b if you have time to pull it.
if (-not $env:OLLAMA_MODEL)     { $env:OLLAMA_MODEL = 'qwen2.5:1.5b' }
if (-not $env:CONFIDENCE_THRESHOLD)   { $env:CONFIDENCE_THRESHOLD = '0.65' }
if (-not $env:OVERRIDE_WINDOW_SECONDS) { $env:OVERRIDE_WINDOW_SECONDS = '5' }
if (-not $env:RESOLVE_QUORUM)   { $env:RESOLVE_QUORUM = '2' }
if (-not $env:ENABLE_DEV_RESET) { $env:ENABLE_DEV_RESET = '1' }
# Voice reporter flow: local faster-whisper (first call downloads the model).
if (-not $env:WHISPER_MODEL)        { $env:WHISPER_MODEL = 'small' }
if (-not $env:WHISPER_DEVICE)       { $env:WHISPER_DEVICE = 'cpu' }
if (-not $env:WHISPER_COMPUTE_TYPE) { $env:WHISPER_COMPUTE_TYPE = 'int8' }

# ── python ───────────────────────────────────────────────────────────────────
$pythonCommand = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCommand) {
    throw "python not found. Install it first:  winget install --id Python.Python.3.12 -e"
}
$python = $pythonCommand.Source
& $python -c "import sys; raise SystemExit(0 if sys.version_info >= (3,10) else 1)" 2>$null
if ($LASTEXITCODE -ne 0) {
    throw "$python is not a working Python 3.10+ (Microsoft Store stub?). Install: winget install --id Python.Python.3.12 -e"
}

# ── certificates ─────────────────────────────────────────────────────────────
$certFile = Join-Path $PSScriptRoot 'certs\server.crt'
$keyFile  = Join-Path $PSScriptRoot 'certs\server.key'
if (-not (Test-Path $certFile) -or -not (Test-Path $keyFile)) {
    throw "TLS cert missing. From the repo root run:  .\scripts\gen_certs.ps1   then start again."
}
$appCaAsset = Join-Path (Split-Path $PSScriptRoot -Parent) 'assets\certs\ca.crt'
if (-not (Test-Path $appCaAsset)) {
    Write-Warning "assets\certs\ca.crt is missing - the Flutter app will not trust the server. Run .\scripts\gen_certs.ps1"
}

# ── dependencies ─────────────────────────────────────────────────────────────
& $python -c "import uvicorn, fastapi, httpx, pydantic" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Step "Installing Python dependencies..."
    & $python -m pip install --disable-pip-version-check -r requirements.txt
    if ($LASTEXITCODE -ne 0) { throw "pip install failed. Check your network/proxy and try: $python -m pip install -r requirements.txt" }
}

# ── LAN addresses for the banner ─────────────────────────────────────────────
$lanIps = @()
try {
    $lanIps = @(
        Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
            Where-Object {
                $_.IPAddress -notlike '127.*' -and
                $_.IPAddress -notlike '169.254.*' -and
                $_.IPAddress -notlike '0.*'
            } |
            Select-Object -ExpandProperty IPAddress
    )
} catch {
    try {
        $lanIps = @(ipconfig | Select-String 'IPv4' | ForEach-Object { ($_.Line -split ':')[-1].Trim() })
    } catch { $lanIps = @() }
}

# ── banner ───────────────────────────────────────────────────────────────────
Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host '  Wingman API  ·  HTTPS + WSS on :8443' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host "  token       : $env:API_TOKEN"
Write-Host "  ollama      : $env:OLLAMA_URL  model=$env:OLLAMA_MODEL"
Write-Host "  threshold   : $env:CONFIDENCE_THRESHOLD  (override window $env:OVERRIDE_WINDOW_SECONDS s)"
if ($lanIps.Count -gt 0) {
    $primary = $lanIps[0]
    Write-Host ''
    Write-Host "  status page : https://$primary`:8443/        (test in Safari/Chrome)"
    Write-Host "  health      : https://$primary`:8443/healthz"
    Write-Host "  CA download : https://$primary`:8443/ca.crt"
    Write-Host "  swagger     : https://$primary`:8443/docs"
    Write-Host ''
    Write-Host '  Flutter on phones:' -ForegroundColor Yellow
    Write-Host "    flutter run --dart-define=API_BASE=https://$primary`:8443 --dart-define=API_TOKEN=$env:API_TOKEN" -ForegroundColor Yellow
    if ($lanIps.Count -gt 1) {
        Write-Host "  all LAN IPv4: $($lanIps -join ', ')"
    }
} else {
    Write-Warning 'Could not detect a LAN IPv4. Run ipconfig and use that address in API_BASE.'
}
Write-Host '============================================================' -ForegroundColor Green
Write-Host ''

Write-Step 'Starting uvicorn (TLS)...'
& $python -m uvicorn app.main:app --host 0.0.0.0 --port 8443 `
    --ssl-keyfile certs/server.key --ssl-certfile certs/server.crt
exit $LASTEXITCODE
