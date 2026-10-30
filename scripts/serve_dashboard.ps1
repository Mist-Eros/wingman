<#
.SYNOPSIS
    Serves and opens the Wingman desktop control room in Waterfox.

.DESCRIPTION
    The primary dashboard is a zero-dependency HTML page (scripts/dashboard/)
    that talks to the SAME backend as the phones: REST snapshot + actions and a
    live WSS stream. It works in Waterfox (no canvas/WebGL requirement) and in
    any other browser.

    A Flutter web version also exists (lib/web_dashboard_main.dart) for demos on
    Chromium/Edge; pass -Flutter to build and serve that instead.

    The demo backend uses our private CA: this script trusts it in the current
    user store and opens Waterfox with a dedicated profile where
    `security.enterprise_roots.enabled=true`, so HTTPS/WSS just work.

.EXAMPLE
    .\scripts\serve_dashboard.ps1
    .\scripts\serve_dashboard.ps1 -ApiBase https://192.168.0.170:8443 -Port 8090
    .\scripts\serve_dashboard.ps1 -Flutter      # CanvasKit version (Edge/Chrome)
#>
[CmdletBinding()]
param(
    [string]$ApiBase = '',
    [int]$Port = 8090,
    [string]$Token = 'demo-token',
    [switch]$Flutter
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo

if (-not $ApiBase) {
    $ips = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' -and $_.IPAddress -notlike '192.168.56.*' } |
        Select-Object -ExpandProperty IPAddress)
    $ip = if ($ips.Count -gt 0) { $ips[0] } else { '127.0.0.1' }
    $ApiBase = "https://$ip`:8443"
}

# ── launch ──────────────────────────────────────────────────────────────────
# Primary path: the static dashboard is opened directly from disk in Waterfox
# (file://). Waterfox in this environment can be unreliable with localhost
# HTTP, but file:// works and the page talks to the API over HTTPS/WSS fine.
# -Flutter builds the CanvasKit version and serves it over HTTP for Chromium.
if ($Flutter) {
    $webDir = Join-Path $repo 'build\web'
    Write-Host "==> building Flutter web dashboard (API: $ApiBase)..." -ForegroundColor Cyan
    & flutter build web --release -t lib/web_dashboard_main.dart --no-web-resources-cdn `
        "--dart-define=API_BASE=$ApiBase" "--dart-define=API_TOKEN=$Token"
    if ($LASTEXITCODE -ne 0) { throw 'flutter build web failed' }

    $port = $Port
    $listener = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($listener) {
        foreach ($conn in $listener) { Stop-Process -Id $conn.OwningProcess -Force -ErrorAction SilentlyContinue }
        Start-Sleep -Seconds 1
    }
    $python = (Get-Command python -ErrorAction SilentlyContinue).Source
    if (-not $python) { $python = Join-Path $env:LOCALAPPDATA 'Programs\Python\Python312\python.exe' }
    Start-Process -FilePath $python -ArgumentList '-m', 'http.server', "$port", '--directory', $webDir -WindowStyle Hidden
    Start-Sleep -Seconds 2
    $url = "http://127.0.0.1:$port/"
} else {
    $url = 'file:///' + ((Join-Path $repo 'scripts\dashboard\index.html') -replace '\\', '/')
}

# Config injected at launch time (keeps the HTML free of hardcoded endpoints).
$configJs = @"
window.WINGMAN_CONFIG = {
  api: '$ApiBase',
  token: '$Token'
};
"@
Set-Content -Path (Join-Path $repo 'scripts\dashboard\config.js') -Value $configJs -Encoding UTF8

Write-Host "==> opening Waterfox (control room). Press F11 for fullscreen." -ForegroundColor Cyan$waterfoxCandidates = @(
    'C:\Program Files\Waterfox\waterfox.exe',
    'C:\Program Files (x86)\Waterfox\waterfox.exe'
)
$waterfox = $waterfoxCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($waterfox) {
    Start-Process -FilePath $waterfox -ArgumentList '-no-remote', '-profile', $profileDir, '-new-window', $url
} else {
    Write-Host "Waterfox not found. Open this URL in a browser: $url" -ForegroundColor Yellow
}
Write-Host ''
Write-Host 'Dashboard talks to the SAME store as the phones (REST + WSS).' -ForegroundColor Green
Write-Host "API base: $ApiBase   |   control room: $url" -ForegroundColor Green

# Trust our CA for the current user (Waterfox: security.enterprise_roots.enabled).
$caFile = Join-Path $repo 'backend\certs\ca.crt'
if (Test-Path $caFile) {
    $hasCa = & certutil -user -store Root 2>$null | Select-String 'Wingman Local CA'
    if (-not $hasCa) {
        Write-Host '==> trusting Wingman CA for the current user...' -ForegroundColor Cyan
        & certutil -user -addstore Root $caFile 2>&1 | Out-Null
    }
}

$profileDir = Join-Path (Split-Path -Parent $repo) 'waterfox-dashboard-profile'
New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
$userJs = @'
user_pref("security.enterprise_roots.enabled", true);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("browser.startup.page", 0);
'@
Set-Content -Path (Join-Path $profileDir 'user.js') -Value $userJs -Encoding UTF8

$port = $Port
$listener = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
if ($listener) {
    foreach ($conn in $listener) { Stop-Process -Id $conn.OwningProcess -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Seconds 1
}
$python = (Get-Command python -ErrorAction SilentlyContinue).Source
if (-not $python) { $python = Join-Path $env:LOCALAPPDATA 'Programs\Python\Python312\python.exe' }
Start-Process -FilePath $python -ArgumentList '-m', 'http.server', "$port", '--directory', $webDir -WindowStyle Hidden
Start-Sleep -Seconds 2

$url = "http://127.0.0.1:$port/"
try {
    $status = (Invoke-WebRequest $url -UseBasicParsing -TimeoutSec 5).StatusCode
    Write-Host "==> serving at $url (HTTP $status)" -ForegroundColor Green
} catch {
    throw "dashboard server did not start on port $port : $($_.Exception.Message)"
}

$waterfoxCandidates = @(
    'C:\Program Files\Waterfox\waterfox.exe',
    'C:\Program Files (x86)\Waterfox\waterfox.exe'
)
$waterfox = $waterfoxCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($waterfox) {
    Write-Host '==> opening Waterfox (control room). Press F11 for fullscreen.' -ForegroundColor Cyan
    Start-Process -FilePath $waterfox -ArgumentList '-no-remote', '-profile', $profileDir, '-new-window', $url
} else {
    Write-Host "Waterfox not found. Open this URL in a browser: $url" -ForegroundColor Yellow
}
Write-Host ''
Write-Host 'Dashboard talks to the SAME store as the phones (REST + WSS).' -ForegroundColor Green
Write-Host "API base: $ApiBase   |   local UI: $url" -ForegroundColor Green
