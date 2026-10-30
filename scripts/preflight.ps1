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

$python = $null
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if ($pythonCmd) { $python = $pythonCmd.Source }
if ($python) {
    $pyVersion = & $python -c "import sys; print('%d.%d.%d' % sys.version_info[:3])" 2>$null
    if ($LASTEXITCODE -eq 0 -and $pyVersion) {
        $parts = $pyVersion.Split('.')
        if ([int]$parts[0] -ge 3 -and [int]$parts[1] -ge 10) {
            Pass ("Python " + $pyVersion + " (" + $python + ")")
        } else {
            Fail ("Python " + $pyVersion + " is too old (need 3.10+)")
        }
    } else {
        Fail "python found but not runnable (Microsoft Store stub?) - install Python 3.12"
    }
} else {
    Fail "python not found - winget install --id Python.Python.3.12 -e"
}

$openssl = Get-Command openssl -ErrorAction SilentlyContinue
if ($openssl) {
    $sslVersion = (& openssl version) 2>$null
    Pass ("OpenSSL: " + $sslVersion)
} else {
    Warn "openssl not on PATH - cert generation/verification commands will not work"
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

$curl = Get-Command curl.exe -ErrorAction SilentlyContinue
if ($listening -and (Test-Path $caFile) -and $curl) {
    $healthUrl = $ApiBase.TrimEnd('/') + '/healthz'
    $raw = (& curl.exe -sS --max-time 8 --cacert $caFile $healthUrl 2>&1) -join "`n"
    if ($LASTEXITCODE -eq 0 -and $raw -match '"status"') {
        Pass ("HTTPS + certificate validation OK: " + $healthUrl)
        try {
            $publicHealth = $raw | ConvertFrom-Json
            Pass ("public health: taxonomy v" + $publicHealth.taxonomy_version + ", tickets=" + $publicHealth.tickets + ", ws_clients=" + $publicHealth.ws_clients)
        } catch {
            Warn "could not parse /healthz JSON"
        }
    } else {
        Fail ("TLS health check failed (" + $healthUrl + "): " + $raw)
    }
} elseif (-not $curl) {
    Warn "curl.exe not found - cannot do the validated HTTPS check"
}

if ($listening) {
    $healthUrl = $ApiBase.TrimEnd('/') + '/api/health'
    $authRaw = ''
    if ($curl) {
        $authRaw = (& curl.exe -sS --max-time 8 --cacert $caFile -H ('Authorization: Bearer ' + $Token) $healthUrl 2>&1) -join "`n"
    }
    if ($authRaw -match '"status"') {
        try {
            $health = $authRaw | ConvertFrom-Json
            Pass ("authenticated /api/health OK (token '" + $Token + "')")
            if ([string]$health.taxonomy_version -ne '') {
                Pass ("taxonomy v" + $health.taxonomy_version + ", " + $health.incident_types + " incident types")
            }
            if ($health.ollama -ne $null) {
                if ($health.ollama.last_ok -eq $true -or $health.ollama.reachable -eq $true) {
                    Pass ("backend sees Ollama (" + $health.ollama.model + ", last ok: " + $health.ollama.last_ok + ")")
                } else {
                    Warn ("backend cannot use Ollama: " + $health.ollama.last_error + " - fallback classifier will be used")
                }
            }
        } catch {
            Warn "could not parse /api/health JSON"
        }
    } elseif ($authRaw -match '401|Invalid') {
        Fail ("auth rejected - API_TOKEN mismatch (tried '" + $Token + "')")
    } else {
        Fail ("/api/health failed: " + $authRaw)
    }
}

# ── 4. Ollama ───────────────────────────────────────────────────────────────
if (-not $SkipOllama) {
    Section 'Ollama'
    if ($curl) {
        $tagsRaw = (& curl.exe -sS --max-time 5 'http://127.0.0.1:11434/api/tags' 2>&1) -join "`n"
        if ($LASTEXITCODE -eq 0 -and $tagsRaw -match '"models"') {
            Pass "Ollama /api/tags reachable"
            $modelFound = $false
            try {
                $tags = $tagsRaw | ConvertFrom-Json
                $names = @($tags.models | ForEach-Object { $_.name })
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
            Fail ("Ollama not reachable on 127.0.0.1:11434 - run: ollama serve (" + $tagsRaw + ")")
        }
    } else {
        Warn "curl.exe missing - skipped Ollama probe"
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
