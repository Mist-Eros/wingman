<#
.SYNOPSIS
    Generates the Wingman private CA and TLS server certificate for the
    FastAPI + uvicorn backend that serves HTTPS REST and WSS on port 8443.

.DESCRIPTION
    Produces (default output folder: <repo>\backend\certs):
        ca.key    ca.crt    server.key    server.csr    server.crt    san.cnf
    and copies ca.crt to <repo>\assets\certs\ca.crt (Flutter asset bundle).
    The backend (backend\run.ps1) starts with exactly these file names, and the
    backend also serves the CA at https://<laptop-ip>:8443/ca.crt.

    - CA: RSA 2048 / SHA-256 / 10 years, CA:TRUE.
    - Leaf: RSA 2048 / SHA-256 / 397 days (Apple rejects > 398), serverAuth,
      SAN with every detected private LAN IPv4 + 127.0.0.1 + DNS names.
    - OpenSSL is located on PATH first, then in the usual install folders.
    - Works on Windows PowerShell 5.1 and PowerShell 7+.

    Run it again with -Force after the laptop IP changes (DHCP / hotspot).

.PARAMETER Force
    Overwrite existing certificates. Required if output files already exist.

.PARAMETER ExtraIps
    Extra IPv4 addresses to append to the SAN (comma separated), for example:
    -ExtraIps 192.168.1.50,10.0.0.9

.PARAMETER Dns
    DNS names for the SAN. Default: wingman.local, localhost
    ("localhost" is always added).

.PARAMETER OutDir
    Certificate output folder. Default: <repo>\backend\certs

.EXAMPLE
    .\scripts\gen_certs.ps1 -Force

.EXAMPLE
    .\scripts\gen_certs.ps1 -Force -ExtraIps 192.168.1.50 -Dns wingman.local,wingman.test

.NOTES
    The private key (ca.key) can mint certificates trusted by every phone that
    installed the CA: never copy it to a phone and never commit it to git.
#>
[CmdletBinding()]
param(
    [switch]$Force,
    [string[]]$ExtraIps = @(),
    [string[]]$Dns = @('wingman.local', 'localhost'),
    [string]$OutDir = ''
)

$ErrorActionPreference = 'Stop'
$script:OpenSslPath = $null

# ---------------------------------------------------------------------------
# Small console helpers (write to host only, never to the pipeline).
# ---------------------------------------------------------------------------
function Write-Step {
    param([string]$Text)
    Write-Host ''
    Write-Host ("== " + $Text) -ForegroundColor Cyan
}

function Write-Ok {
    param([string]$Text)
    Write-Host ("  [ok]   " + $Text) -ForegroundColor Green
}

function Write-WarnMsg {
    param([string]$Text)
    Write-Host ("  [warn] " + $Text) -ForegroundColor Yellow
}

function Write-FailMsg {
    param([string]$Text)
    Write-Host ("  [fail] " + $Text) -ForegroundColor Red
}

function Write-KeyValue {
    param([string]$Key, [string]$Value)
    Write-Host ("  " + $Key.PadRight(14) + $Value)
}

# ---------------------------------------------------------------------------
# Validation helpers.
# ---------------------------------------------------------------------------
function Test-IPv4 {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    if ($Value -notmatch '^\d{1,3}(\.\d{1,3}){3}$') { return $false }
    foreach ($part in $Value.Split('.')) {
        if ([int]$part -gt 255) { return $false }
    }
    return $true
}

function Test-PrivateIPv4 {
    param([string]$Value)
    $parts = $Value.Split('.')
    $a = [int]$parts[0]
    $b = [int]$parts[1]
    if ($a -eq 10) { return $true }
    if ($a -eq 172 -and $b -ge 16 -and $b -le 31) { return $true }
    if ($a -eq 192 -and $b -eq 168) { return $true }
    return $false
}

function Get-LinkKind {
    param($Adapter, [string]$Alias)
    $text = ''
    if ($null -ne $Adapter) {
        $text = [string]$Adapter.InterfaceDescription + ' ' + [string]$Adapter.Name + ' ' +
                [string]$Adapter.MediaType + ' ' + [string]$Adapter.PhysicalMediaType
    }
    $text = $text + ' ' + $Alias
    if ($text -match '(?i)(wi-?fi|wireless|802\.11|wlan)') { return 'Wi-Fi' }
    if ($text -match '(?i)(ethernet|802\.3|realtek|gbe|usb.*lan)') { return 'Ethernet' }
    return 'Other'
}

function Test-VirtualLink {
    param($Adapter, [string]$Alias)
    $text = ''
    if ($null -ne $Adapter) {
        $text = [string]$Adapter.InterfaceDescription + ' ' + [string]$Adapter.Name
    }
    $text = $text + ' ' + $Alias
    return ($text -match '(?i)(vethernet|hyper-v|virtual|vmware|virtualbox|wsl|docker|tap-|tailscale|zerotier|wireguard|openvpn|bluetooth|loopback|npcap|vpn)')
}

# ---------------------------------------------------------------------------
# OpenSSL discovery + safe invocation.
# ---------------------------------------------------------------------------
function Find-OpenSsl {
    $fromPath = Get-Command -Name 'openssl' -CommandType Application -ErrorAction SilentlyContinue |
                Select-Object -First 1
    if ($null -ne $fromPath) {
        $candidate = [string]$fromPath.Path
        if (-not $candidate) { $candidate = [string]$fromPath.Source }
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) { return $candidate }
    }
    $probes = @(
        'C:\Program Files\OpenSSL-Win64\bin\openssl.exe',
        'C:\Program Files\OpenSSL-Win32\bin\openssl.exe',
        'C:\Program Files\Git\usr\bin\openssl.exe'
    )
    foreach ($probe in $probes) {
        if (Test-Path -LiteralPath $probe -PathType Leaf) { return $probe }
    }
    return $null
}

function Invoke-OpenSsl {
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [switch]$NoThrow
    )
    if (-not $script:OpenSslPath) { throw 'Internal error: the OpenSSL path was not initialised.' }

    $previousEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $lines = @(& $script:OpenSslPath @Arguments 2>&1 | ForEach-Object { [string]$_ })
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousEap
    }

    $text = $lines -join "`n"
    if ($exitCode -ne 0 -and -not $NoThrow) {
        $cmdText = 'openssl ' + ($Arguments -join ' ')
        throw ("openssl failed (exit code " + $exitCode + ").`nCommand: " + $cmdText + "`nOutput:`n" + $text)
    }
    return [PSCustomObject]@{ ExitCode = $exitCode; Output = $text; Lines = $lines }
}

# ---------------------------------------------------------------------------
# LAN IPv4 detection.
# Primary path: NetTCPIP cmdlets (Get-NetIPAddress / Get-NetRoute / Get-NetAdapter).
# Fallback: .NET NetworkInterface enumeration, for locked-down machines where
# the NetTCPIP CIM cmdlets are unavailable or denied.
# ---------------------------------------------------------------------------
function Get-LanIpEntriesFromNetShell {
    $entries = @()

    # Default-route interface indexes (used to skip virtual/disconnected NICs).
    $routeInfoKnown = $true
    $gatewayIndexes = @{}
    try {
        foreach ($route in @(Get-NetRoute -AddressFamily IPv4 -ErrorAction Stop)) {
            if ([string]$route.DestinationPrefix -eq '0.0.0.0/0') {
                $gatewayIndexes[[int]$route.InterfaceIndex] = $true
            }
        }
    }
    catch {
        $routeInfoKnown = $false
        Write-WarnMsg 'Get-NetRoute failed - gateway detection skipped; private Wi-Fi/Ethernet adapters are still accepted.'
    }

    # Adapter metadata for type detection (Wi-Fi / Ethernet / virtual).
    $adapters = @{}
    try {
        foreach ($adapter in @(Get-NetAdapter -ErrorAction Stop)) {
            $adapters[[int]$adapter.ifIndex] = $adapter
        }
    }
    catch {
        Write-WarnMsg 'Get-NetAdapter failed - adapter type is guessed from the interface alias.'
    }

    try {
        $configs = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop)
    }
    catch {
        throw ("Get-NetIPAddress failed: " + $_.Exception.Message + ". gen_certs.ps1 requires Windows 10/11 (NetTCPIP module).")
    }

    foreach ($config in $configs) {
        $ip = [string]$config.IPAddress
        if (-not (Test-IPv4 $ip)) { continue }
        if ($ip -like '127.*' -or $ip -like '169.254.*' -or $ip -eq '0.0.0.0' -or $ip -eq '255.255.255.255') { continue }
        if ($config.AddressState -and ([string]$config.AddressState -ne 'Preferred')) { continue }

        $index = [int]$config.InterfaceIndex
        $alias = [string]$config.InterfaceAlias
        $adapter = $null
        if ($adapters.ContainsKey($index)) { $adapter = $adapters[$index] }

        $kind = Get-LinkKind -Adapter $adapter -Alias $alias
        $virtual = Test-VirtualLink -Adapter $adapter -Alias $alias
        $private = Test-PrivateIPv4 $ip
        if ($routeInfoKnown) {
            $hasGateway = $gatewayIndexes.ContainsKey($index)
        }
        else {
            $hasGateway = $true
        }

        # Rule: keep adapters that have a default gateway, plus real private
        # Wi-Fi/Ethernet adapters even without one (static LAN, ICS, hotspot).
        $eligible = $hasGateway -or ($private -and -not $virtual -and ($kind -eq 'Wi-Fi' -or $kind -eq 'Ethernet'))
        $reason = ''
        if (-not $eligible) {
            $bits = @()
            if (-not $hasGateway) { $bits += 'no default gateway' }
            if ($virtual) { $bits += 'virtual/VPN adapter' }
            if (-not ($kind -eq 'Wi-Fi' -or $kind -eq 'Ethernet')) { $bits += ('adapter type ' + $kind + ' is not Wi-Fi/Ethernet') }
            if (-not $private) { $bits += 'not a 10/172.16-31/192.168 address' }
            $reason = ($bits -join '; ')
        }

        $entries += [PSCustomObject]@{
            IP          = $ip
            Alias       = $alias
            Kind        = $kind
            Virtual     = $virtual
            Private     = $private
            HasGateway  = $hasGateway
            SkipAsSource = [bool]$config.SkipAsSource
            Eligible    = $eligible
            InSan       = ($private -and $eligible)
            Reason      = $reason
        }
    }

    return [PSCustomObject]@{ Entries = $entries; RouteInfoKnown = $routeInfoKnown }
}

function Get-LanIpEntriesFromDotNet {
    $entries = @()
    try {
        $interfaces = @([System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces())
    }
    catch {
        throw ('Could not enumerate network interfaces: ' + $_.Exception.Message)
    }

    foreach ($nic in $interfaces) {
        if ([string]$nic.OperationalStatus -ne 'Up') { continue }

        $description = [string]$nic.Description + ' ' + [string]$nic.Name
        $typeText = [string]$nic.NetworkInterfaceType
        $kind = 'Other'
        if ($typeText -eq 'Wireless80211') { $kind = 'Wi-Fi' }
        elseif ($typeText -match 'Ethernet') { $kind = 'Ethernet' }
        $virtual = ($description -match '(?i)(vethernet|hyper-v|virtual|vmware|virtualbox|wsl|docker|tap-|tailscale|zerotier|wireguard|openvpn|bluetooth|loopback|npcap|vpn|wi-fi direct)')

        $properties = $null
        try { $properties = $nic.GetIPProperties() }
        catch { continue }

        $gateways = @()
        try {
            $gateways = @($properties.GatewayAddresses |
                Where-Object { $null -ne $_.Address } |
                ForEach-Object { $_.Address.ToString() } |
                Where-Object { $_ -ne '0.0.0.0' -and $_ -ne '::' })
        }
        catch { $gateways = @() }
        $hasGateway = ($gateways.Count -gt 0)

        $unicastAddresses = @()
        try { $unicastAddresses = @($properties.UnicastAddresses) }
        catch { continue }

        foreach ($unicast in $unicastAddresses) {
            if ($null -eq $unicast -or $null -eq $unicast.Address) { continue }
            if ([string]$unicast.Address.AddressFamily -ne 'InterNetwork') { continue }
            $ip = [string]$unicast.Address
            if (-not (Test-IPv4 $ip)) { continue }
            if ($ip -like '127.*' -or $ip -like '169.254.*' -or $ip -eq '0.0.0.0') { continue }

            $private = Test-PrivateIPv4 $ip
            $eligible = $hasGateway -or ($private -and -not $virtual -and ($kind -eq 'Wi-Fi' -or $kind -eq 'Ethernet'))
            $reason = ''
            if (-not $eligible) {
                $bits = @()
                if (-not $hasGateway) { $bits += 'no default gateway' }
                if ($virtual) { $bits += 'virtual/VPN adapter' }
                if (-not ($kind -eq 'Wi-Fi' -or $kind -eq 'Ethernet')) { $bits += ('adapter type ' + $kind + ' is not Wi-Fi/Ethernet') }
                if (-not $private) { $bits += 'not a 10/172.16-31/192.168 address' }
                $reason = ($bits -join '; ')
            }

            $entries += [PSCustomObject]@{
                IP           = $ip
                Alias        = [string]$nic.Name
                Kind         = $kind
                Virtual      = $virtual
                Private      = $private
                HasGateway   = $hasGateway
                SkipAsSource = $false
                Eligible     = $eligible
                InSan        = ($private -and $eligible)
                Reason       = $reason
            }
        }
    }

    return [PSCustomObject]@{ Entries = $entries; RouteInfoKnown = $true }
}

function Get-LanIpEntries {
    try {
        return (Get-LanIpEntriesFromNetShell)
    }
    catch {
        $reason = ($_.Exception.Message -replace '\s+', ' ').Trim()
        Write-WarnMsg ('NetTCPIP cmdlets unavailable (' + $reason + '); using the .NET network API instead.')
        return (Get-LanIpEntriesFromDotNet)
    }
}

# ===========================================================================
# MAIN
# ===========================================================================
try {
    # ---- Paths -----------------------------------------------------------
    if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        throw 'Run this script from a file (scripts\gen_certs.ps1); PSScriptRoot is empty.'
    }
    $scriptDir = $PSScriptRoot
    $repoRoot = Split-Path -Parent $scriptDir
    if ((Split-Path -Leaf $scriptDir) -ne 'scripts') {
        Write-WarnMsg ("This script is not inside a 'scripts' folder. Treating '" + $repoRoot + "' as the repository root.")
    }

    if ([string]::IsNullOrWhiteSpace($OutDir)) {
        $OutDir = Join-Path $repoRoot 'backend\certs'
    }
    elseif (-not [System.IO.Path]::IsPathRooted($OutDir)) {
        $OutDir = Join-Path (Get-Location).Path $OutDir
    }

    $assetDir = Join-Path $repoRoot 'assets\certs'
    $assetCaPath = Join-Path $assetDir 'ca.crt'

    $caKeyPath = Join-Path $OutDir 'ca.key'
    $caCrtPath = Join-Path $OutDir 'ca.crt'
    $serverKeyPath = Join-Path $OutDir 'server.key'
    $serverCsrPath = Join-Path $OutDir 'server.csr'
    $serverCrtPath = Join-Path $OutDir 'server.crt'
    $sanCnfPath = Join-Path $OutDir 'san.cnf'
    $serialPath = Join-Path $OutDir 'ca.srl'

    # ---- Validate -Dns / -ExtraIps --------------------------------------
    # Accept both -Dns a,b (PowerShell array) and -Dns a,b passed through
    # powershell.exe -File, where the whole value arrives as one string.
    $dnsList = @()
    foreach ($rawDns in @($Dns)) {
        foreach ($name in ([string]$rawDns -split '[,;]')) {
            if ([string]::IsNullOrWhiteSpace($name)) { continue }
            $trimmed = $name.Trim()
            if ($trimmed.Length -gt 253 -or $trimmed -notmatch '^[A-Za-z0-9]([A-Za-z0-9\-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9\-]*[A-Za-z0-9])?)*$') {
                throw ("Invalid -Dns value '" + $trimmed + "': expected a hostname like wingman.local.")
            }
            if ($dnsList -notcontains $trimmed) { $dnsList += $trimmed }
        }
    }
    if ($dnsList -notcontains 'localhost') { $dnsList += 'localhost' }

    $extraIpList = @()
    foreach ($rawIp in @($ExtraIps)) {
        foreach ($value in ([string]$rawIp -split '[,;]')) {
            if ([string]::IsNullOrWhiteSpace($value)) { continue }
            $trimmed = $value.Trim()
            if (-not (Test-IPv4 $trimmed)) {
                throw ("Invalid -ExtraIps value '" + $trimmed + "': expected an IPv4 address like 192.168.1.50.")
            }
            if ($extraIpList -notcontains $trimmed) { $extraIpList += $trimmed }
        }
    }

    # ---- Locate OpenSSL --------------------------------------------------
    Write-Step 'OpenSSL'
    $openssl = Find-OpenSsl
    if (-not $openssl) {
        Write-FailMsg 'OpenSSL was not found on PATH and not in the usual install folders.'
        Write-Host ''
        Write-Host '  Install one of these, then open a NEW terminal so PATH refreshes:'
        Write-Host ''
        Write-Host '    winget install --id ShiningLight.OpenSSL.Light -e' -ForegroundColor White
        Write-Host '       (installs to C:\Program Files\OpenSSL-Win64\bin\openssl.exe)'
        Write-Host ''
        Write-Host '    choco install openssl -y'
        Write-Host '       (installs to C:\Program Files\OpenSSL-Win64\bin\openssl.exe)'
        Write-Host ''
        Write-Host '    Git for Windows (already includes openssl): https://git-scm.com/download/win'
        Write-Host '       (probed at C:\Program Files\Git\usr\bin\openssl.exe)'
        Write-Host ''
        Write-Host '  Then re-run:  .\scripts\gen_certs.ps1 -Force'
        exit 1
    }
    $script:OpenSslPath = $openssl
    Write-Ok ("Found: " + $openssl)

    $versionResult = Invoke-OpenSsl -Arguments @('version')
    $versionLine = @($versionResult.Lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1)
    if ($versionLine.Count -eq 0) { throw 'openssl version produced no output - is this a real OpenSSL binary?' }
    Write-Ok ("Version: " + $versionLine[0])

    $useAddext = $false
    if ($versionLine[0] -match '^OpenSSL\s+(\d+)\.(\d+)\.(\d+)') {
        $major = [int]$Matches[1]
        $minor = [int]$Matches[2]
        $patch = [int]$Matches[3]
        if ($major -gt 1) { $useAddext = $true }
        elseif ($major -eq 1 -and $minor -gt 1) { $useAddext = $true }
        elseif ($major -eq 1 -and $minor -eq 1 -and $patch -ge 1) { $useAddext = $true }
        if ($useAddext) {
            Write-Ok 'Extension support: -addext (OpenSSL 1.1.1+)'
        }
        else {
            Write-WarnMsg 'OpenSSL older than 1.1.1: using a temporary config file instead of -addext.'
        }
    }
    else {
        Write-WarnMsg 'Could not parse the OpenSSL version; using a temporary config file instead of -addext.'
    }

    # ---- Detect LAN addresses and build the SAN --------------------------
    Write-Step 'Detecting laptop IPv4 addresses'
    $lan = Get-LanIpEntries

    $sanIps = @('127.0.0.1')
    $detectedPrivate = @()
    foreach ($entry in @($lan.Entries | Sort-Object IP)) {
        if ($entry.InSan) {
            $detectedPrivate += $entry.IP
            if ($sanIps -notcontains $entry.IP) { $sanIps += $entry.IP }
        }
    }
    foreach ($ip in $extraIpList) {
        if ($sanIps -notcontains $ip) { $sanIps += $ip }
    }

    $ranked = @($lan.Entries |
        Where-Object { $_.InSan -and $_.IP -ne '127.0.0.1' } |
        Sort-Object `
            @{ Expression = { if ($_.HasGateway) { 0 } else { 1 } } },
            @{ Expression = { if ($_.Virtual) { 1 } else { 0 } } },
            @{ Expression = { if ($_.Kind -eq 'Wi-Fi') { 0 } elseif ($_.Kind -eq 'Ethernet') { 1 } else { 2 } } },
            @{ Expression = { $_.IP } })

    $recommendedIp = $null
    $recommendedEntry = $null
    if ($ranked.Count -gt 0) {
        $recommendedEntry = $ranked[0]
        $recommendedIp = $recommendedEntry.IP
    }
    elseif ($extraIpList.Count -gt 0) {
        $recommendedIp = $extraIpList[0]
    }

    if ($lan.Entries.Count -eq 0) {
        Write-WarnMsg 'No usable IPv4 address was detected on this laptop.'
    }
    foreach ($entry in @($lan.Entries | Sort-Object IP)) {
        $tags = @()
        if ($entry.InSan) { $tags += 'IN SAN' }
        if ($recommendedIp -and $entry.IP -eq $recommendedIp) { $tags += 'USE THIS' }
        if (-not $entry.Eligible) {
            $tags += ('skipped (' + $entry.Reason + ')')
        }
        elseif (-not $entry.Private) {
            $tags += 'not private - not in SAN'
        }
        if ($entry.SkipAsSource) { $tags += 'SkipAsSource' }
        $kind = $entry.Kind
        if ($entry.Virtual) { $kind = $kind + '*' }
        Write-Host ('  ' + $entry.IP.PadRight(15) + $kind.PadRight(11) + $entry.Alias.PadRight(28) + ($tags -join ' | '))
    }
    Write-Host '  (* adapter reported as virtual/VPN by its description)'
    Write-Ok ('SAN IPs : 127.0.0.1, ' + ($detectedPrivate -join ', ') + $(if ($extraIpList.Count -gt 0) { ' (+ extra: ' + ($extraIpList -join ', ') + ')' } else { '' }))
    Write-Ok ('SAN DNS : ' + ($dnsList -join ', '))

    if ($recommendedIp) {
        Write-Ok ('Phone URL host to use: ' + $recommendedIp + '  (all listed SAN IPs validate, so a DHCP change to another listed IP still works)')
        if ($recommendedEntry -and $recommendedEntry.Virtual) {
            Write-WarnMsg ('The best candidate ' + $recommendedIp + ' belongs to a virtual/VPN adapter and may not be reachable from the phones. Pass -ExtraIps <real-LAN-ip> if the phones cannot connect.')
        }
    }
    else {
        Write-WarnMsg 'No LAN IP in the SAN: the certificate will only work on 127.0.0.1. Connect Wi-Fi and re-run with -Force, or pass -ExtraIps <laptop-ip>.'
    }

    # ---- Refuse to silently overwrite -----------------------------------
    $targets = @($caKeyPath, $caCrtPath, $serverKeyPath, $serverCsrPath, $serverCrtPath, $sanCnfPath)
    $existing = @($targets | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
    if ($existing.Count -gt 0 -and -not $Force) {
        Write-Step 'Existing certificate files found'
        foreach ($path in $existing) { Write-Host ('  ' + $path) }
        Write-Host ''
        Write-Host '  Nothing was changed. Re-run with -Force to regenerate everything:' -ForegroundColor Yellow
        Write-Host '    .\scripts\gen_certs.ps1 -Force'
        exit 1
    }

    # ---- Generate --------------------------------------------------------
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    New-Item -ItemType Directory -Force -Path $assetDir | Out-Null

    # san.cnf is written on purpose: it documents exactly what went into the
    # certificate and is the -extfile used when signing.
    $sanParts = @()
    foreach ($ip in $sanIps) { $sanParts += ('IP:' + $ip) }
    foreach ($name in $dnsList) { $sanParts += ('DNS:' + $name) }
    $sanText = @(
        '# Generated by scripts/gen_certs.ps1 - rerun the script instead of editing this file.',
        '# A Subject Alternative Name is mandatory: iOS rejects certs that only have a CN.',
        '[req]',
        'distinguished_name = dn',
        'prompt = no',
        '',
        '[dn]',
        'CN = wingman.local',
        '',
        '[v3_leaf]',
        'basicConstraints = critical,CA:FALSE',
        'keyUsage = critical,digitalSignature,keyEncipherment',
        'extendedKeyUsage = serverAuth',
        ('subjectAltName = ' + ($sanParts -join ', '))
    ) -join "`n"
    [System.IO.File]::WriteAllText($sanCnfPath, $sanText + "`n", [System.Text.Encoding]::ASCII)
    Write-Ok ('Wrote ' + (Split-Path -Leaf $sanCnfPath) + ' (' + $sanParts.Count + ' SAN entries)')

    Write-Step 'Generating CA (RSA 2048, SHA-256, 10 years, CA:TRUE)'
    if (Test-Path -LiteralPath $serialPath) { Remove-Item -LiteralPath $serialPath -Force }

    $tempCaConfig = $null
    try {
        $caArgs = @(
            'req', '-x509', '-newkey', 'rsa:2048', '-sha256', '-days', '3650', '-nodes',
            '-keyout', $caKeyPath, '-out', $caCrtPath,
            '-subj', '/CN=Wingman Local CA/O=Wingman'
        )
        if ($useAddext) {
            $caArgs += @('-addext', 'basicConstraints=critical,CA:TRUE')
            $caArgs += @('-addext', 'keyUsage=critical,keyCertSign,cRLSign')
        }
        else {
            $tempCaConfig = Join-Path ([System.IO.Path]::GetTempPath()) ('airport-hack-ca-' + [guid]::NewGuid().ToString('N') + '.cnf')
            $caConfigText = @(
                '[req]',
                'distinguished_name = dn',
                'prompt = no',
                'x509_extensions = v3_ca',
                '',
                '[dn]',
                'CN = Wingman Local CA',
                'O = Wingman',
                '',
                '[v3_ca]',
                'basicConstraints = critical,CA:TRUE',
                'keyUsage = critical,keyCertSign,cRLSign'
            ) -join "`n"
            [System.IO.File]::WriteAllText($tempCaConfig, $caConfigText + "`n", [System.Text.Encoding]::ASCII)
            $caArgs += @('-config', $tempCaConfig, '-extensions', 'v3_ca')
        }
        Invoke-OpenSsl -Arguments $caArgs | Out-Null
        if (-not (Test-Path -LiteralPath $caCrtPath -PathType Leaf)) { throw ('The CA certificate was not created at ' + $caCrtPath) }
        if ((Get-Item -LiteralPath $caCrtPath).Length -le 0) { throw ('The CA certificate is empty: ' + $caCrtPath) }
        if (-not (Test-Path -LiteralPath $caKeyPath -PathType Leaf)) { throw ('The CA private key was not created at ' + $caKeyPath) }
        if ((Get-Item -LiteralPath $caKeyPath).Length -le 0) { throw ('The CA private key is empty: ' + $caKeyPath) }
        Write-Ok 'CA certificate and key created.'
    }
    finally {
        if ($tempCaConfig -and (Test-Path -LiteralPath $tempCaConfig)) {
            Remove-Item -LiteralPath $tempCaConfig -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Step 'Generating server key and CSR (CN=wingman.local)'
    Invoke-OpenSsl -Arguments @(
        'req', '-new', '-newkey', 'rsa:2048', '-sha256', '-nodes',
        '-keyout', $serverKeyPath, '-out', $serverCsrPath,
        '-subj', '/CN=wingman.local'
    ) | Out-Null
    if (-not (Test-Path -LiteralPath $serverCsrPath -PathType Leaf)) { throw ('The CSR was not created at ' + $serverCsrPath) }
    if ((Get-Item -LiteralPath $serverCsrPath).Length -le 0) { throw ('The CSR is empty: ' + $serverCsrPath) }
    Write-Ok 'Server key and CSR created.'

    Write-Step 'Signing server certificate with the CA (397 days, SHA-256, SAN mandatory)'
    Invoke-OpenSsl -Arguments @(
        'x509', '-req', '-in', $serverCsrPath,
        '-CA', $caCrtPath, '-CAkey', $caKeyPath,
        '-CAcreateserial', '-CAserial', $serialPath,
        '-days', '397', '-sha256',
        '-extfile', $sanCnfPath, '-extensions', 'v3_leaf',
        '-out', $serverCrtPath
    ) | Out-Null
    Write-Ok 'Server certificate signed.'

    # ---- Verify ----------------------------------------------------------
    Write-Step 'Verifying generated files'
    $written = @(
        [PSCustomObject]@{ Path = $caKeyPath;     What = 'CA private key - keep secret, never on a phone' },
        [PSCustomObject]@{ Path = $caCrtPath;     What = 'CA certificate - install on both iPhones and both Androids' },
        [PSCustomObject]@{ Path = $serverKeyPath; What = 'TLS private key - uvicorn --ssl-keyfile' },
        [PSCustomObject]@{ Path = $serverCsrPath; What = 'certificate signing request - not needed at runtime' },
        [PSCustomObject]@{ Path = $serverCrtPath; What = 'TLS certificate - uvicorn --ssl-certfile' },
        [PSCustomObject]@{ Path = $sanCnfPath;    What = 'SAN config used to sign the leaf' }
    )
    foreach ($item in $written) {
        if (-not (Test-Path -LiteralPath $item.Path -PathType Leaf)) { throw ('Missing generated file: ' + $item.Path) }
        if ((Get-Item -LiteralPath $item.Path).Length -le 0) { throw ('Generated file is empty: ' + $item.Path) }
    }
    Write-Ok 'All expected files exist and are non-empty.'

    $leafText = (Invoke-OpenSsl -Arguments @('x509', '-in', $serverCrtPath, '-noout', '-text')).Output
    if ($leafText -notmatch 'Subject Alternative Name') {
        throw ('server.crt has NO Subject Alternative Name - iOS and Android will reject it. Check ' + $sanCnfPath + ' and re-run with -Force.')
    }
    $flatLeafText = $leafText -replace '\s+', ' '
    foreach ($ip in $sanIps) {
        if (-not $flatLeafText.Contains($ip)) { throw ('SAN check failed: IP ' + $ip + ' is missing from server.crt.') }
    }
    foreach ($name in $dnsList) {
        if (-not $flatLeafText.Contains('DNS:' + $name)) { throw ('SAN check failed: DNS ' + $name + ' is missing from server.crt.') }
    }

    $caText = (Invoke-OpenSsl -Arguments @('x509', '-in', $caCrtPath, '-noout', '-text')).Output
    if ($caText -notmatch 'CA:TRUE') { throw 'ca.crt is not a CA certificate (basicConstraints CA:TRUE missing).' }

    $chainResult = Invoke-OpenSsl -Arguments @('verify', '-CAfile', $caCrtPath, $serverCrtPath)
    if ($chainResult.Output -notmatch ':\s*OK') {
        throw ('openssl verify did not report OK:`n' + $chainResult.Output)
    }

    $certModulusText = (Invoke-OpenSsl -Arguments @('x509', '-in', $serverCrtPath, '-noout', '-modulus')).Output
    $keyModulusText = (Invoke-OpenSsl -Arguments @('rsa', '-in', $serverKeyPath, '-noout', '-modulus')).Output
    $certModulus = $null
    $keyModulus = $null
    if ($certModulusText -match 'Modulus=([0-9A-Fa-f]+)') { $certModulus = $Matches[1] }
    if ($keyModulusText -match 'Modulus=([0-9A-Fa-f]+)') { $keyModulus = $Matches[1] }
    if (-not $certModulus -or -not $keyModulus -or $certModulus -ne $keyModulus) {
        throw 'server.key does not match server.crt (modulus mismatch) - uvicorn would fail to start.'
    }
    Write-Ok 'SAN present, CA:TRUE present, chain verifies with ca.crt, server.key matches server.crt.'

    $sanLine = ''
    $leafLines = $leafText -split "`r?`n"
    for ($i = 0; $i -lt $leafLines.Count; $i++) {
        if ($leafLines[$i] -match 'Subject Alternative Name') {
            if (($i + 1) -lt $leafLines.Count) { $sanLine = $leafLines[$i + 1].Trim() }
            break
        }
    }
    $dateInfo = (Invoke-OpenSsl -Arguments @('x509', '-in', $serverCrtPath, '-noout', '-subject', '-issuer', '-dates')).Output
    $caFingerprint = (Invoke-OpenSsl -Arguments @('x509', '-in', $caCrtPath, '-noout', '-fingerprint', '-sha256')).Output

    # ---- Copy the CA into the Flutter asset bundle -----------------------
    Copy-Item -LiteralPath $caCrtPath -Destination $assetCaPath -Force
    if (-not (Test-Path -LiteralPath $assetCaPath -PathType Leaf)) { throw ('Could not copy the CA to ' + $assetCaPath) }
    if ((Get-Item -LiteralPath $assetCaPath).Length -ne (Get-Item -LiteralPath $caCrtPath).Length) {
        throw ('The CA copy at ' + $assetCaPath + ' does not match backend\certs\ca.crt.')
    }

    # ---- Summary ---------------------------------------------------------
    function Get-DisplayPath {
        param([string]$Path)
        if ($Path.Length -gt $repoRoot.Length) {
            if ($Path.Substring(0, $repoRoot.Length) -eq $repoRoot) {
                return $Path.Substring($repoRoot.Length).TrimStart('\')
            }
        }
        return $Path
    }

    Write-Step 'Files written'
    foreach ($item in $written) {
        Write-Ok ((Get-DisplayPath $item.Path) + '  (' + (Get-Item -LiteralPath $item.Path).Length + ' bytes)  ' + $item.What)
    }
    Write-Ok ((Get-DisplayPath $assetCaPath) + '  (' + (Get-Item -LiteralPath $assetCaPath).Length + ' bytes)  copy of the CA bundled into the Flutter app')

    Write-Step 'SAN actually present in server.crt'
    Write-KeyValue 'IP SAN :' ($sanIps -join ', ')
    Write-KeyValue 'DNS SAN:' ($dnsList -join ', ')
    if ($sanLine) { Write-KeyValue 'openssl:' $sanLine }

    Write-Step 'Certificate details'
    foreach ($line in @($dateInfo -split "`r?`n")) {
        if (-not [string]::IsNullOrWhiteSpace($line)) { Write-Host ('  ' + $line.Trim()) }
    }
    foreach ($line in @($caFingerprint -split "`r?`n")) {
        if (-not [string]::IsNullOrWhiteSpace($line)) { Write-Host ('  ' + $line.Trim()) }
    }

    Write-Step 'Phones use this host'
    if ($recommendedIp) {
        Write-Host ('  https://' + $recommendedIp + ':8443/healthz   (JSON health)') -ForegroundColor Green
        Write-Host ('  https://' + $recommendedIp + ':8443/          (status page: also tells you if the CA is trusted)') -ForegroundColor Green
        Write-Host ('  wss://' + $recommendedIp + ':8443/ws')
        Write-Host ''
        Write-Host '  All private LAN IPs listed above are in the SAN, so the certificate keeps'
        Write-Host '  validating if DHCP hands the laptop a different address from that list.'
        Write-Host '  If the address is not in the list at all, re-run: .\scripts\gen_certs.ps1 -Force'
    }
    else {
        Write-WarnMsg 'No LAN IP available - fix networking and re-run with -Force before testing phones.'
    }

    Write-Step 'Start the backend (run from the backend folder)'
    Write-Host '  cd backend'
    Write-Host '  uvicorn app.main:app --host 0.0.0.0 --port 8443 --ssl-keyfile certs/server.key --ssl-certfile certs/server.crt'

    Write-Step 'One-time firewall rule (elevated PowerShell, run once)'
    Write-Host '  New-NetFirewallRule -DisplayName "Wingman 8443" -Direction Inbound -Protocol TCP -LocalPort 8443 -Action Allow -Profile Private' -ForegroundColor White
    Write-Host ''
    Write-Host '  Windows must treat the Wi-Fi/Ethernet network as Private for that rule to match:'
    Write-Host '  Set-NetConnectionProfile -InterfaceAlias "Wi-Fi" -NetworkCategory Private'

    Write-Step 'Next: install the CA on all 4 phones'
    Write-Host ('  CA file: ' + (Get-DisplayPath $assetCaPath) + '  (same file as backend\certs\ca.crt)')
    Write-Host '  iPhone: Settings > General > VPN & Device Management > install, then'
    Write-Host '          Settings > General > About > Certificate Trust Settings > Full Trust ON.'
    Write-Host '  Android: Settings > Security & privacy > More security settings >'
    Write-Host '           Encryption & credentials > Install a certificate > CA certificate.'
    Write-Host '  Full runbook: docs\certs-and-phones.md'
    Write-Host ''
    Write-WarnMsg 'The Flutter app must ALSO trust this CA explicitly from assets/certs/ca.crt'
    Write-WarnMsg '(installing the phone profile alone is not enough for dart:io - see the doc).'
    Write-WarnMsg 'Re-run this script with -Force if the laptop IP changes (DHCP, hotspot, new network).'

    if (Test-Path -LiteralPath $serialPath) { Remove-Item -LiteralPath $serialPath -Force -ErrorAction SilentlyContinue }

    Write-Host ''
    Write-Host 'gen_certs.ps1 finished successfully.' -ForegroundColor Green
    exit 0
}
catch {
    Write-Host ''
    Write-FailMsg $_.Exception.Message
    Write-Host ''
    Write-Host 'No phones will trust this certificate until the script completes cleanly.' -ForegroundColor Yellow
    Write-Host 'Fix the problem above, then re-run: .\scripts\gen_certs.ps1 -Force' -ForegroundColor Yellow
    exit 1
}
