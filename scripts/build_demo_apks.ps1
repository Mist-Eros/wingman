<#
.SYNOPSIS
    Builds the two APKs the demo needs and drops them in D:\Hackathon\dist.

.DESCRIPTION
    build 1 "TLS"      -API_BASE=https://<ip>:8443  (normal, certificate pinned)
    build 2 "INSECURE" -API_BASE=http://<ip>:8080   (emergency, plain HTTP)

    Install both on every demo phone. If TLS misbehaves on stage, switch to the
    insecure build (and start `backend\run_insecure.ps1`) instead of debugging.

.EXAMPLE
    .\scripts\build_demo_apks.ps1
    .\scripts\build_demo_apks.ps1 -ApiHost 10.10.28.37 -Debug
#>
[CmdletBinding()]
param(
    [string]$ApiHost = '',
    [string]$Token = 'demo-token',
    [switch]$Debug
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo

# ── resolve the laptop IP ────────────────────────────────────────────────────
if (-not $ApiHost) {
    $ips = @()
    try {
        $ips = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
            Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' -and $_.IPAddress -notlike '192.168.56.*' } |
            Select-Object -ExpandProperty IPAddress)
    } catch {
        $ips = @(ipconfig | Select-String 'IPv4' | ForEach-Object { ($_.Line -split ':')[-1].Trim() } |
            Where-Object { $_ -notlike '127.*' -and $_ -notlike '192.168.56.*' })
    }
    if ($ips.Count -eq 0) { throw "Could not detect the LAN IP. Pass -ApiHost <laptop-ip>." }
    $ApiHost = $ips[0]
}
Write-Host "Laptop IP for the APKs: $ApiHost" -ForegroundColor Cyan

$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutter) { throw "flutter not on PATH. Add C:\dev\flutter\bin to PATH (or run in a new terminal)." }

$mode = if ($Debug) { 'debug' } else { 'release' }
$dist = Join-Path $repo '..\dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null

function Save-Build([string]$name, [string[]]$dartDefines) {
    $args = @('build', 'apk', "--$mode") + $dartDefines
    Write-Host ('==> flutter ' + ($args -join ' ')) -ForegroundColor Cyan
    & flutter @args
    if ($LASTEXITCODE -ne 0) { throw "build failed for $name" }
    $built = Join-Path $repo "build\app\outputs\flutter-apk\app-$mode.apk"
    if (-not (Test-Path $built)) { throw "APK not found at $built" }
    $target = Join-Path $dist $name
    Copy-Item $built $target -Force
    Write-Host ('    ' + $target) -ForegroundColor Green
    return $target
}

$tlsApk = Save-Build "wingman-tls-$mode.apk" @(
    '--dart-define=API_BASE=https://' + $ApiHost + ':8443',
    '--dart-define=API_TOKEN=' + $Token
)

$insecureApk = Save-Build "wingman-insecure-$mode.apk" @(
    '--dart-define=API_BASE=http://' + $ApiHost + ':8080',
    '--dart-define=DEV_INSECURE=true',
    '--dart-define=API_TOKEN=' + $Token
)

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host "  Demo APKs ready in $dist" -ForegroundColor Green
Write-Host "  TLS build      : $tlsApk" -ForegroundColor White
Write-Host "  Emergency build: $insecureApk" -ForegroundColor White
Write-Host ''
Write-Host '  Install on a USB-connected phone:' -ForegroundColor Yellow
Write-Host ('    adb install -r "' + $tlsApk + '"') -ForegroundColor Yellow
Write-Host ('    adb install -r "' + $insecureApk + '"') -ForegroundColor Yellow
Write-Host '============================================================' -ForegroundColor Green
