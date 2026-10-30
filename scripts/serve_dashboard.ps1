<#
.SYNOPSIS
    Builds, serves and opens the Wingman desktop control room in Edge.

.DESCRIPTION
    The dashboard is a Flutter web target (lib/web_dashboard_main.dart) that
    talks to the SAME backend as the phones: REST for the snapshot + actions,
    WSS for live updates. It renders in Edge fullscreen, so no Visual Studio is
    needed (the Windows desktop build requires the VS C++ workload).

    The demo backend uses a self-signed certificate; Edge is launched with
    --ignore-certificate-errors for this local dashboard only.

.EXAMPLE
    .\scripts\serve_dashboard.ps1
    .\scripts\serve_dashboard.ps1 -ApiBase https://192.168.0.170:8443 -Port 8090
#>
[CmdletBinding()]
param(
    [string]$ApiBase = '',
    [int]$Port = 8090,
    [string]$Token = 'demo-token',
    [switch]$BuildOnly
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo

if (-not $ApiBase) {
    # Prefer the Wi-Fi address that the phones/backend use.
    $ips = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' -and $_.IPAddress -notlike '192.168.56.*' } |
        Select-Object -ExpandProperty IPAddress)
    $ip = if ($ips.Count -gt 0) { $ips[0] } else { '127.0.0.1' }
    $ApiBase = "https://$ip`:8443"
}

Write-Host "==> dashboard API base: $ApiBase" -ForegroundColor Cyan
Write-Host '==> building web dashboard...' -ForegroundColor Cyan
& flutter build web --release -t lib/web_dashboard_main.dart --no-web-resources-cdn `
    "--dart-define=API_BASE=$ApiBase" "--dart-define=API_TOKEN=$Token"
if ($LASTEXITCODE -ne 0) { throw 'flutter build web failed' }
if ($BuildOnly) { Write-Host 'Build complete (BuildOnly).' -ForegroundColor Green; exit 0 }

$webDir = Join-Path $repo 'build\web'
$port = $Port
$listener = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
if (-not $listener) {
    $python = (Get-Command python -ErrorAction SilentlyContinue).Source
    if (-not $python) { $python = Join-Path $env:LOCALAPPDATA 'Programs\Python\Python312\python.exe' }
    Start-Process -FilePath $python -ArgumentList '-m', 'http.server', "$port", '--directory', $webDir -WindowStyle Hidden
    Start-Sleep -Seconds 2
}

$url = "http://127.0.0.1:$port/"
try {
    $status = (Invoke-WebRequest $url -UseBasicParsing -TimeoutSec 5).StatusCode
    Write-Host "==> serving at $url (HTTP $status)" -ForegroundColor Green
} catch {
    throw "dashboard server did not start on port $port : $($_.Exception.Message)"
}

$edgeCandidates = @(
    'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
    'C:\Program Files\Microsoft\Edge\Application\msedge.exe'
)
$edge = $edgeCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($edge) {
    Write-Host '==> opening Edge (control room). Press F11 for fullscreen.' -ForegroundColor Cyan
    Start-Process -FilePath $edge -ArgumentList '--ignore-certificate-errors', '--start-fullscreen', $url
} else {
    Write-Host "Open this URL in a browser: $url" -ForegroundColor Yellow
}
Write-Host ''
Write-Host 'Dashboard talks to the SAME store as the phones (REST + WSS).' -ForegroundColor Green
Write-Host "API base: $ApiBase   |   local UI: $url" -ForegroundColor Green
