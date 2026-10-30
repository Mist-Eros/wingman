<#
.SYNOPSIS
    Pre-demo readiness check for the laptop. ASCII-only output (PS 5.1 safe).

.DESCRIPTION
    Checks, in order:
      1. Python 3.10+ and OpenSSL
      2. TLS files + CA asset + certificate SAN covering the detected LAN IP
      3. backend/certs chain verifies with the CA
      4. uvicorn listening on 8443
      5. HTTPS health check WITH full certificate validation (curl --cacert)
      6. authenticated /api/health: taxonomy, tickets, WSS clients, Ollama state
      7. Ollama reachable and the configured model pulled
      8. Windows firewall rule for 8443
    Exit code 0 only if nothing FAILED (warnings are allowed).

.EXAMPLE
    .\scripts\preflight.ps1
    .\scripts\preflight.ps1 -ApiBase https://192.168.1.50:8443 -SkipOllama
#>
[CmdletBinding()]
param(
    [string]$ApiBase = '',
    [string]$Token = 'demo-token',
    [string]$Model = '',
    [int]$Port = 8443,
    [switch]$SkipOllama
)

$ErrorActionPreference = 'Continue'

# Freshly installed tools are not on the PATH of an already-open shell, so pull
# the machine/user PATH from the registry before probing the toolchain.
$machinePath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
$userPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
if ($machinePath -or $userPath) { $env:Path = ($machinePath + ';' + $userPath) }

$script:Passed = 0
$script:Failed = 0
$script:Warned = 0
$script:Failures = New-Object System.Collections.ArrayList

$repoRoot = Split-Path -Parent $PSScriptRoot
$backendDir = Join-Path $repoRoot 'backend'
$certDir = Join-Path $backendDir 'certs'
$caFile = Join-Path $certDir 'ca.crt'
$serverCrt = Join-Path $certDir 'server.crt'
$serverKey = Join-Path $certDir 'server.key'
$appCa = Join-Path $repoRoot 'assets\certs\ca.crt'

function Pass([string]$Message) {
    $script:Passed++
    Write-Host ('  [PASS] ' + $Message) -ForegroundColor Green
}

function Fail([string]$Message) {
    $script:Failed++
    [void]$script:Failures.Add($Message)
    Write-Host ('  [FAIL] ' + $Message) -ForegroundColor Red
}

function Warn([string]$Message) {
    $script:Warned++
    Write-Host ('  [WARN] ' + $Message) -ForegroundColor Yellow
}

function Section([string]$Title) {
    Write-Host ''
    Write-Host ('== ' + $Title) -ForegroundColor Cyan
}

# Windows' built-in curl.exe uses Schannel and cannot consume --cacert, so we
# validate TLS in .NET instead: build a chain that trusts ONLY our project CA.
function Enable-CaValidation([string]$CaPath) {
    if (-not $CaPath -or -not (Test-Path $CaPath)) { return $false }
    try {
        # Windows PowerShell 5.1 does not enable TLS 1.2 by default for HttpWebRequest.
        try {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
        } catch { }
        $script:TrustedCa = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2((Resolve-Path $CaPath).Path)
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {
            param($sender, $certificate, $chain, $sslPolicyErrors)
            if ($sslPolicyErrors -eq [System.Net.Security.SslPolicyErrors]::None) { return $true }
            if (($sslPolicyErrors -band [System.Net.Security.SslPolicyErrors]::RemoteCertificateNameMismatch) -ne 0) { return $false }
            try {
                $leaf = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certificate)
                $testChain = New-Object System.Security.Cryptography.X509Certificates.X509Chain
                $testChain.ChainPolicy.TrustMode = [System.Security.Cryptography.X509Certificates.X509ChainTrustMode]::CustomRootTrust
                [void]$testChain.ChainPolicy.CustomTrustStore.Add($script:TrustedCa)
                [void]$testChain.ChainPolicy.ExtraStore.Add($script:TrustedCa)
                $testChain.ChainPolicy.RevocationMode = [System.Security.Cryptography.X509Certificates.X509RevocationMode]::NoCheck
                return $testChain.Build($leaf)
            } catch {
                return $false
            }
        }
        return $true
    } catch {
        return $false
    }
}

function Get-JsonEndpoint([string]$Url, [string]$BearerToken) {
    # Prefer Python: its TLS stack accepts --cacert-equivalent CA files, while
    # Windows PowerShell 5.1 / built-in curl go through Schannel, which cannot
    # pin a custom CA and is blocked in some restricted sessions.
    if ($script:PythonExe -and (Test-Path $caFile)) {
        $probe = @'
import json, ssl, sys, urllib.request
url, token, ca = sys.argv[1], sys.argv[2], sys.argv[3]
if token == "-":
    token = ""
try:
    ctx = ssl.create_default_context(cafile=ca)
    req = urllib.request.Request(url)
    if token:
        req.add_header("Authorization", "Bearer " + token)
    with urllib.request.urlopen(req, context=ctx, timeout=8) as response:
        payload = response.read().decode("utf-8")
    json.loads(payload)
    print(payload)
except Exception as exc:
    print("ERROR: " + type(exc).__name__ + ": " + str(exc))
    sys.exit(1)
'@
        $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) ('wingman-probe-' + [guid]::NewGuid().ToString('N') + '.py')
        try {
            [System.IO.File]::WriteAllText($tempFile, $probe, (New-Object System.Text.UTF8Encoding($false)))
            $raw = (& $script:PythonExe $tempFile $Url $BearerToken $caFile 2>&1) -join "`n"
            if ($LASTEXITCODE -eq 0 -and $raw -match '^\s*\{') {
                return @{ ok = $true; data = ($raw | ConvertFrom-Json); error = '' }
            }
            return @{ ok = $false; data = $null; error = $raw }
        } finally {
            Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
        }
    }

    # Fallback: .NET (works when Schannel is healthy; validates via project CA).
    if (-not $script:CaValidationReady) { [void](Enable-CaValidation $caFile) }
    $headers = @{}
    if ($BearerToken) { $headers['Authorization'] = 'Bearer ' + $BearerToken }
    try {
        $data = Invoke-RestMethod -Uri $Url -Headers $headers -TimeoutSec 8 -ErrorAction Stop
        return @{ ok = $true; data = $data; error = '' }
    } catch {
        return @{ ok = $false; data = $null; error = $_.Exception.Message }
    }
}

# ── LAN IPv4 ─────────────────────────────────────────────────────────────────
function Get-LanIpv4 {
    $ips = @()
    try {
        $ips = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
            Where-Object {
                $_.IPAddress -notlike '127.*' -and
                $_.IPAddress -notlike '169.254.*' -and
                $_.IPAddress -notlike '0.*'
            } |
            Select-Object -ExpandProperty IPAddress)
    } catch {
        $ips = @()
    }
    if ($ips.Count -eq 0) {
        try {
            $ips = @(ipconfig | Select-String 'IPv4' |
                ForEach-Object { ($_.Line -split ':')[-1].Trim() } |
                Where-Object { $_ -notlike '127.*' -and $_ -notlike '169.254.*' })
        } catch {
            $ips = @()
        }
    }
    return $ips
}

$lanIps = @(Get-LanIpv4)
$primaryIp = if ($lanIps.Count -gt 0) { $lanIps[0] } else { '' }
$apiBaseExplicit = [bool]$ApiBase
if (-not $ApiBase) {
    if ($primaryIp) { $ApiBase = 'https://' + $primaryIp + ':' + $Port }
    else { $ApiBase = 'https://127.0.0.1:' + $Port }
}
if (-not $Model) { $Model = if ($env:OLLAMA_MODEL) { $env:OLLAMA_MODEL } else { 'qwen2.5:7b' } }

Write-Host ''
Write-Host '============================================================' -ForegroundColor White
Write-Host '  Wingman - pre-demo preflight' -ForegroundColor White
Write-Host ('  API base: ' + $ApiBase) -ForegroundColor White
Write-Host '============================================================' -ForegroundColor White

# ── 1. toolchain ─────────────────────────────────────────────────────────────
Section 'Toolchain'

$pythonCandidates = New-Object System.Collections.ArrayList
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if ($pythonCmd) { [void]$pythonCandidates.Add($pythonCmd.Source) }
$backendVenv = Join-Path $backendDir '.venv\Scripts\python.exe'
if (Test-Path $backendVenv) { [void]$pythonCandidates.Add($backendVenv) }
[void]$pythonCandidates.Add((Join-Path $env:LOCALAPPDATA 'Programs\Python\Python312\python.exe'))
[void]$pythonCandidates.Add('C:\Program Files\Python312\python.exe')

$python = $null
$pyVersion = $null
foreach ($candidate in $pythonCandidates) {
    if (-not (Test-Path $candidate)) { continue }
    $probe = & $candidate -c "import sys; print('%d.%d.%d' % sys.version_info[:3])" 2>$null
    if ($LASTEXITCODE -eq 0 -and $probe -match '^3\.(\d+)\.') {
        if ([int]$Matches[1] -ge 10) { $python = $candidate; $pyVersion = $probe; break }
    }
}
if ($python) {
    Pass ("Python " + $pyVersion + " (" + $python + ")")
    $script:PythonExe = $python
} else {
    Fail "no working Python 3.10+ found - winget install --id Python.Python.3.12 -e"
}

$openssl = Get-Command openssl -ErrorAction SilentlyContinue
if (-not $openssl) {
    foreach ($candidate in @(
        'C:\Program Files\OpenSSL-Win64\bin\openssl.exe',
        'C:\Program Files\OpenSSL-Win32\bin\openssl.exe',
        'C:\Program Files\Git\usr\bin\openssl.exe'
    )) {
        if (Test-Path $candidate) {
            $openssl = Get-Item $candidate
            $env:Path = (Split-Path $candidate) + ';' + $env:Path
            break
        }
    }
}
if ($openssl) {
    $sslVersion = (& openssl version) 2>$null
    Pass ("OpenSSL: " + $sslVersion)
} else {
    Warn "openssl not found - run: winget install --id ShiningLight.OpenSSL.Light -e"
}

# ── 2. files + SAN ───────────────────────────────────────────────────────────
Section 'Certificates'

$missing = @()
foreach ($file in @($caFile, $serverCrt, $serverKey, $appCa)) {
    if (-not (Test-Path $file)) { $missing += $file }
}
if ($missing.Count -eq 0) {
    Pass "CA, server cert/key and app CA asset all exist"
} else {
    Fail ("missing: " + ($missing -join ', ') + " - run .\scripts\gen_certs.ps1 -Force")
}

$sanLine = ''
if ((Test-Path $serverCrt) -and $openssl) {
    $sanLine = (& openssl x509 -in $serverCrt -noout -ext subjectAltName 2>$null) -join ' '
    if (-not $sanLine -or $sanLine -notmatch 'IP Address') {
        $sanLine = (& openssl x509 -in $serverCrt -noout -text 2>$null | Select-String 'Subject Alternative Name' -Context 0,1) -join ' '
    }
}
$ipInSan = $false
if ($lanIps.Count -gt 0 -and $sanLine) {
    foreach ($ip in $lanIps) {
        if ($sanLine -match [regex]::Escape($ip)) { $ipInSan = $true; break }
    }
}
if ($lanIps.Count -eq 0) {
    Warn "no LAN IPv4 detected - cannot verify the SAN (run ipconfig)"
} elseif ($sanLine -and $ipInSan) {
    Pass ("server cert SAN covers a current LAN IP (detected: " + ($lanIps -join ', ') + ")")
} elseif ($sanLine) {
    Fail "server cert SAN does not include any current LAN IP - re-run .\scripts\gen_certs.ps1 -Force and reinstall the CA on the phones"
} else {
    Warn "could not read the SAN (openssl missing?)"
}

# Prefer a LAN IP that the certificate actually covers (skips virtual adapters
# such as VirtualBox/Hyper-V host-only networks that phones cannot reach).
if ($sanLine) {
    foreach ($ip in $lanIps) {
        if ($ip -notlike '127.*' -and $sanLine -match [regex]::Escape($ip)) {
            $primaryIp = $ip
            break
        }
    }
}

# If the API base was auto-derived from the wrong adapter (VirtualBox/Hyper-V),
# point it at the certificate-covered address instead.
if (-not $apiBaseExplicit -and $primaryIp) {
    $ApiBase = 'https://' + $primaryIp + ':' + $Port
    Write-Host ('  [info] API base uses the certificate-covered address: ' + $ApiBase) -ForegroundColor DarkGray
}

if ((Test-Path $serverCrt) -and (Test-Path $caFile) -and $openssl) {
    $verify = (& openssl verify -CAfile $caFile $serverCrt 2>&1) -join ' '
    if ($verify -match 'OK') { Pass "leaf verifies against the CA" }
    else { Fail ("openssl verify failed: " + $verify) }
}

# ── 3. backend socket + TLS health ──────────────────────────────────────────
Section 'Backend (TLS)'

$listening = $false
try {
    $conn = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction Stop
    if ($conn) { $listening = $true }
} catch {
    $probe = Test-NetConnection -ComputerName '127.0.0.1' -Port $Port -WarningAction SilentlyContinue
    if ($probe -and $probe.TcpTestSucceeded) { $listening = $true }
}
if ($listening) { Pass ("port " + $Port + " is listening") }
else { Fail ("nothing listening on port " + $Port + " - start backend: cd backend; .\run.ps1") }

$tlsValidation = Test-Path $caFile
if ($listening -and $tlsValidation) {
    $healthUrl = $ApiBase.TrimEnd('/') + '/healthz'
    $public = Get-JsonEndpoint $healthUrl '-'
    if ($public.ok -and ([string]$public.data.status -eq 'ok')) {
        Pass ("HTTPS + certificate validation OK: " + $healthUrl)
        Pass ("public health: taxonomy v" + $public.data.taxonomy_version + ", tickets=" + $public.data.tickets + ", ws_clients=" + $public.data.ws_clients)
    } else {
        Fail ("TLS health check failed (" + $healthUrl + "): " + $public.error)
    }
} elseif ($listening -and -not $tlsValidation) {
    Warn "CA file missing - cannot validate HTTPS (run .\scripts\gen_certs.ps1 -Force)"
}

if ($listening -and $tlsValidation) {
    $healthUrl = $ApiBase.TrimEnd('/') + '/api/health'
    $healthResult = Get-JsonEndpoint $healthUrl $Token
    if ($healthResult.ok) {
        $health = $healthResult.data
        Pass ("authenticated /api/health OK (token '" + $Token + "')")
        if ([string]$health.taxonomy_version -ne '') {
            Pass ("taxonomy v" + $health.taxonomy_version + ", " + $health.incident_types + " incident types")
        }
        if ($null -ne $health.ollama) {
            if ($health.ollama.last_ok -eq $true -or $health.ollama.reachable -eq $true) {
                Pass ("backend sees Ollama (" + $health.ollama.model + ", last ok: " + $health.ollama.last_ok + ")")
            } else {
                Warn ("backend cannot use Ollama: " + $health.ollama.last_error + " - fallback classifier will be used")
            }
        }
    } elseif ($healthResult.error -match '401|Unauthorized|Invalid') {
        Fail ("auth rejected - API_TOKEN mismatch (tried '" + $Token + "')")
    } else {
        Fail ("/api/health failed: " + $healthResult.error)
    }
}

# ── 4. Ollama ───────────────────────────────────────────────────────────────
if (-not $SkipOllama) {
    Section 'Ollama'
    $tagsResult = Get-JsonEndpoint 'http://127.0.0.1:11434/api/tags' '-'
    if ($tagsResult.ok) {
        Pass "Ollama /api/tags reachable"
        $modelFound = $false
        try {
            $names = @($tagsResult.data.models | ForEach-Object { $_.name })
            $base = ($Model -split ':')[0]
            foreach ($name in $names) {
                if (($name -split ':')[0] -eq $base) { $modelFound = $true }
            }
            if ($modelFound) { Pass ("model '" + $Model + "' is pulled") }
            else { Fail ("model '" + $Model + "' is NOT pulled. Available: " + ($names -join ', ') + " - run: ollama pull " + $Model) }
        } catch {
            Warn "could not parse /api/tags"
        }
    } else {
        Fail ("Ollama not reachable on 127.0.0.1:11434 - run: ollama serve (" + $tagsResult.error + ")")
    }
}

# ── 5. firewall ─────────────────────────────────────────────────────────────
Section 'Network'

try {
    $rule = Get-NetFirewallRule -DisplayName 'Wingman 8443' -ErrorAction Stop
    if ($rule) { Pass "firewall rule 'Wingman 8443' exists" }
} catch {
    Warn "firewall rule not found - run once in an elevated shell: New-NetFirewallRule -DisplayName 'Wingman 8443' -Direction Inbound -Protocol TCP -LocalPort 8443 -Action Allow -Profile Private"
}

try {
    $profiles = Get-NetConnectionProfile -ErrorAction Stop
    $public = @($profiles | Where-Object { $_.NetworkCategory -eq 'Public' })
    if ($public.Count -gt 0) {
        Warn ("network profile is Public on: " + (($public | ForEach-Object { $_.Name }) -join ', ') + " - set it to Private or the phones will be blocked")
    } else {
        Pass "network profile is Private"
    }
} catch {
    Warn "could not read the network profile (needs NetTCPIP; non-fatal)"
}

if ($lanIps.Count -gt 0) {
    Pass ("LAN IPv4: " + ($lanIps -join ', '))
    Write-Host ''
    Write-Host '  Phone checks (open in Safari/Chrome on each device):' -ForegroundColor White
    foreach ($ip in $lanIps) {
        Write-Host ('    https://' + $ip + ':' + $Port + '/') -ForegroundColor White
        Write-Host ('    https://' + $ip + ':' + $Port + '/healthz') -ForegroundColor White
    }
    Write-Host ''
    Write-Host '  Flutter:' -ForegroundColor White
    Write-Host ('    flutter run --dart-define=API_BASE=https://' + $primaryIp + ':' + $Port + ' --dart-define=API_TOKEN=' + $Token) -ForegroundColor White
} else {
    Warn "no LAN IPv4 detected - phones will not be able to reach the laptop"
}

# ── summary ─────────────────────────────────────────────────────────────────
Write-Host ''
Write-Host '============================================================' -ForegroundColor White
Write-Host ('  ' + $script:Passed + ' passed, ' + $script:Failed + ' failed, ' + $script:Warned + ' warnings') -ForegroundColor White
if ($script:Failed -gt 0) {
    Write-Host '  Blocking failures:' -ForegroundColor Red
    foreach ($failure in $script:Failures) {
        Write-Host ('   - ' + $failure) -ForegroundColor Red
    }
}
Write-Host '============================================================' -ForegroundColor White
Write-Host ''

if ($script:Failed -gt 0) { exit 1 }
exit 0
