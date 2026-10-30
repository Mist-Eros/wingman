<#
.SYNOPSIS
    Installs and launches Wingman on a USB-connected (or wireless-debugging) Android
    phone, then streams the app logs.

.DESCRIPTION
    1. checks adb / waits for exactly one authorized device
    2. prints model + Android version
    3. installs the newest APK (dist\ then build\app\outputs\flutter-apk\)
    4. launches com.wingman.wingman/.MainActivity
    5. tails logcat filtered to flutter / Wingman / crashes

.EXAMPLE
    .\scripts\phone_run.ps1
    .\scripts\phone_run.ps1 -NoLogs
    .\scripts\phone_run.ps1 -Apk D:\Hackathon\dist\wingman-tls-release.apk
#>
[CmdletBinding()]
param(
    [string]$Apk = '',
    [string]$Package = 'com.wingman.wingman',
    [string]$Activity = '.MainActivity',
    [switch]$NoLogs,
    [int]$WaitSeconds = 90
)

$ErrorActionPreference = 'Continue'
$repo = Split-Path -Parent $PSScriptRoot
$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { 'C:\Android\sdk' }
$adb = Join-Path $sdk 'platform-tools\adb.exe'
if (-not (Test-Path $adb)) {
    throw "adb not found at $adb. Install Android platform-tools or set ANDROID_HOME."
}
$env:Path = (Join-Path $sdk 'platform-tools') + ';C:\dev\flutter\bin;' + $env:Path

# ── 1. device ────────────────────────────────────────────────────────────────
Write-Host '==> waiting for an authorized Android device...' -ForegroundColor Cyan
& $adb start-server | Out-Null
$deadline = (Get-Date).AddSeconds($WaitSeconds)
$device = $null
while ((Get-Date) -lt $deadline) {
    $lines = @(& $adb devices | Select-Object -Skip 1 | Where-Object { $_.Trim() })
    $ready = @($lines | Where-Object { $_ -match '\sdevice$' })
    $unauthorized = @($lines | Where-Object { $_ -match 'unauthorized|no permissions' })
    if ($ready.Count -ge 1) { $device = ($ready[0] -split "\s+")[0]; break }
    if ($unauthorized.Count -gt 0) {
        Write-Host '    phone is connected but not authorized - accept the "Allow USB debugging" prompt on the phone.' -ForegroundColor Yellow
    }
    Start-Sleep -Seconds 2
}
if (-not $device) {
    Write-Host 'No authorized device found.' -ForegroundColor Red
    Write-Host 'Checklist: data USB cable, Developer options -> USB debugging ON, accept the RSA prompt, adb kill-server, re-plug.' -ForegroundColor Yellow
    & $adb devices
    exit 1
}

$model = (& $adb -s $device shell getprop ro.product.model) -join ''
$android = (& $adb -s $device shell getprop ro.build.version.release) -join ''
Write-Host ("    device: {0} (Android {1}, serial {2})" -f $model.Trim(), $android.Trim(), $device) -ForegroundColor Green

# ── 2. APK ───────────────────────────────────────────────────────────────────
if (-not $Apk) {
    $candidates = @()
    $dist = Join-Path (Split-Path $repo -Parent) 'dist'
    if (Test-Path $dist) { $candidates += @(Get-ChildItem $dist -Filter '*.apk' -File) }
    $build = Join-Path $repo 'build\app\outputs\flutter-apk'
    if (Test-Path $build) { $candidates += @(Get-ChildItem $build -Filter '*.apk' -File) }
    if ($candidates.Count -eq 0) {
        Write-Host 'No APK found.' -ForegroundColor Red
        Write-Host 'Build one first:  flutter build apk --debug --dart-define=API_BASE=https://<laptop-ip>:8443 --dart-define=API_TOKEN=demo-token' -ForegroundColor Yellow
        exit 1
    }
    $Apk = ($candidates | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}
Write-Host "==> installing $Apk" -ForegroundColor Cyan
& $adb -s $device install -r $Apk
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Install failed. If it says INSTALL_FAILED_UPDATE_INCOMPATIBLE run:' -ForegroundColor Yellow
    Write-Host ("    adb -s {0} uninstall {1}" -f $device, $Package) -ForegroundColor Yellow
    exit 1
}

# ── 3. launch ────────────────────────────────────────────────────────────────
Write-Host '==> launching the app' -ForegroundColor Cyan
& $adb -s $device shell am force-stop $Package | Out-Null
Start-Sleep -Milliseconds 500
& $adb -s $device logcat -c | Out-Null
& $adb -s $device shell am start -n "$Package/$Activity" | Out-Null
Start-Sleep -Seconds 3

Write-Host ''
Write-Host 'Phone is running Wingman. What to check:' -ForegroundColor Green
Write-Host '  • role picker + green "Server conectat"' -ForegroundColor White
Write-Host '  • reporter/dispatcher/crew screens against the live backend' -ForegroundColor White
Write-Host '  • Ctrl+C here to stop the log tail (app keeps running)' -ForegroundColor White
Write-Host ''

if ($NoLogs) { exit 0 }

Write-Host '==> logcat (flutter / Wingman / crashes) — Ctrl+C to stop' -ForegroundColor Cyan
& $adb -s $device logcat -v time |
    Select-String -Pattern 'flutter|Wingman|wingman|AndroidRuntime|FATAL|Handshake|HTTP' |
    ForEach-Object { $_.Line }
