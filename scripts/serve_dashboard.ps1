<#
.SYNOPSIS
    Serves and opens the Wingman desktop control room in Waterfox.

.DESCRIPTION
    The dashboard is a zero-dependency HTML page (scripts/dashboard/) opened from
    disk (file://) in a dedicated Waterfox profile. It talks to the same backend
    as the phones: REST snapshot + live WSS + confirm/deny/reclassify actions.

    The demo backend uses a private CA. This script trusts it in the current-user
    Windows store and enables security.enterprise_roots.enabled in the Waterfox
    profile, so HTTPS/WSS work without ignore-certificate flags.

    -Flutter builds the optional CanvasKit dashboard and serves it over HTTP for
    Chromium instead.

.EXAMPLE
    .\scripts\serve_dashboard.ps1
    .\scripts\serve_dashboard.ps1 -ApiBase https://127.0.0.1:8443
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
        Where-Object {
            $_.IPAddress -notlike '127.*' -and
            $_.IPAddress -notlike '169.254.*' -and
            $_.IPAddress -notlike '192.168.56.*'
        } | Select-Object -ExpandProperty IPAddress)
    $ip = if ($ips.Count -gt 0) { $ips[0] } else { '127.0.0.1' }
    $ApiBase = "https://$ip`:8443"
}

# ── dashboard URL ───────────────────────────────────────────────────────────
if ($Flutter) {
    $webDir = Join-Path $repo 'build\web'
    Write-Host "==> building Flutter web dashboard (API: $ApiBase)..." -ForegroundColor Cyan
    & flutter build web --release -t lib/web_dashboard_main.dart --no-web-resources-cdn `
        "--dart-define=API_BASE=$ApiBase" "--dart-define=API_TOKEN=$Token"
    if ($LASTEXITCODE -ne 0) { throw 'flutter build web failed' }

    $listener = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    if ($listener) {
        foreach ($conn in $listener) {
            Stop-Process -Id $conn.OwningProcess -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep -Seconds 1
    }
    $python = (Get-Command python -ErrorAction SilentlyContinue).Source
    if (-not $python) { $python = Join-Path $env:LOCALAPPDATA 'Programs\Python\Python312\python.exe' }
    Start-Process -FilePath $python -ArgumentList '-m', 'http.server', "$Port", '--directory', $webDir -WindowStyle Hidden
    Start-Sleep -Seconds 2
    $url = "http://127.0.0.1:$Port/"
} else {
    $url = 'file:///' + ((Join-Path $repo 'scripts\dashboard\index.html') -replace '\\', '/')
}

# ── config the static page reads ────────────────────────────────────────────
$configJs = @"
window.WINGMAN_CONFIG = {
  api: '$ApiBase',
  token: '$Token'
};
"@
Set-Content -Path (Join-Path $repo 'scripts\dashboard\config.js') -Value $configJs -Encoding UTF8

# ── trust the demo CA for the current user (Waterfox enterprise roots) ──────
$caFile = Join-Path $repo 'backend\certs\ca.crt'
if (Test-Path $caFile) {
    $hasCa = & certutil -user -store Root 2>$null | Select-String 'Wingman Local CA'
    if (-not $hasCa) {
        Write-Host '==> trusting Wingman CA for the current user...' -ForegroundColor Cyan
        & certutil -user -addstore Root $caFile 2>&1 | Out-Null
    }
}

# ── dedicated Waterfox profile ──────────────────────────────────────────────
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

# ── launch ──────────────────────────────────────────────────────────────────
$waterfoxCandidates = @(
    'C:\Program Files\Waterfox\waterfox.exe',
    'C:\Program Files (x86)\Waterfox\waterfox.exe'
)
$waterfox = $waterfoxCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

Write-Host "==> opening Waterfox (control room). Press F11 for fullscreen." -ForegroundColor Cyan
if ($waterfox) {
    Start-Process -FilePath $waterfox -ArgumentList '-no-remote', '-profile', $profileDir, '-new-window', $url
} else {
    Write-Host "Waterfox not found. Open this URL in a browser: $url" -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'Dashboard talks to the SAME store as the phones (REST + WSS).' -ForegroundColor Green
Write-Host "API base: $ApiBase   |   control room: $url" -ForegroundColor Green
