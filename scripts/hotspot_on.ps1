<#
.SYNOPSIS
    Turns the Wingman demo hotspot on (or off) and prints everything the phones need.

.DESCRIPTION
    Windows auto-disables Mobile Hotspot when no devices are connected, which is
    annoying before a demo. This script re-enables it and prints SSID/password,
    the laptop hotspot IP, the backend URL and the Flutter command.

.EXAMPLE
    .\scripts\hotspot_on.ps1
    .\scripts\hotspot_on.ps1 -Off
#>
[CmdletBinding()]
param(
    [switch]$Off
)

$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Networking.Connectivity.NetworkInformation, Windows.Networking.Connectivity, ContentType = WindowsRuntime]
$null = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager, Windows.Networking.NetworkOperators, ContentType = WindowsRuntime]

$profile = [Windows.Networking.Connectivity.NetworkInformation]::GetInternetConnectionProfile()
if (-not $profile) { throw 'No internet connection profile found (connect to Wi-Fi first).' }
$manager = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager]::CreateFromConnectionProfile($profile)

if ($Off) {
    $null = $manager.StopTetheringAsync()
    Start-Sleep -Seconds 3
    "hotspot: $($manager.TetheringOperationalState)"
    exit 0
}

if ($manager.TetheringOperationalState -ne 'On') {
    $null = $manager.StartTetheringAsync()
    Start-Sleep -Seconds 6
}
$config = $manager.GetCurrentAccessPointConfiguration()
Start-Sleep -Seconds 2

$hotspotIp = $null
try {
    $hotspotIp = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
        Where-Object { $_.IPAddress -like '192.168.137.*' -and $_.IPAddress -ne '192.168.137.1' }) | Select-Object -First 1
} catch { }
$laptopIp = '192.168.137.1'

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host '  Wingman demo hotspot' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host ("  state      : " + $manager.TetheringOperationalState)
Write-Host ("  connected  : " + $manager.ClientCount + " device(s)")
Write-Host ("  SSID       : " + $config.Ssid)
Write-Host ("  password   : " + $config.Passphrase)
Write-Host ("  laptop IP  : " + $laptopIp)
Write-Host ''
Write-Host '  Phone browser check:' -ForegroundColor Yellow
Write-Host ("    https://" + $laptopIp + ":8443/") -ForegroundColor Yellow
Write-Host ''
Write-Host '  Flutter (build/run against this network):' -ForegroundColor Yellow
Write-Host ("    flutter run --dart-define=API_BASE=https://" + $laptopIp + ":8443 --dart-define=API_TOKEN=demo-token") -ForegroundColor Yellow
Write-Host ''
Write-Host '  If Windows turned the hotspot off after idling, run this script again.' -ForegroundColor DarkGray
Write-Host '============================================================' -ForegroundColor Green
Write-Host ''
