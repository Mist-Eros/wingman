<#
.SYNOPSIS
    Runs every merge gate in one command. Exit code 0 = the repo is demo-able.

.DESCRIPTION
    1. taxonomy.dart <-> backend/taxonomy.json (sync_taxonomy.py)
    2. Dart wire mapping <-> FastAPI wire (check_wire_parity.py)
    3. flutter analyze
    4. flutter test   (core contract tests)
    5. backend smoke test against the running TLS backend (optional section)

    The backend must already be running (`backend\run.ps1`) for step 5; pass
    -SkipBackend to skip it.

.EXAMPLE
    .\scripts\verify_all.ps1
    .\scripts\verify_all.ps1 -SkipBackend
#>
[CmdletBinding()]
param(
    [switch]$SkipBackend,
    [string]$ApiBase = 'https://127.0.0.1:8443',
    [string]$Token = 'demo-token'
)

$ErrorActionPreference = 'Continue'
$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo

# Pick the best python: backend venv, then PATH.
$python = Join-Path $repo 'backend\.venv\Scripts\python.exe'
if (-not (Test-Path $python)) {
    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
    if ($pythonCmd) { $python = $pythonCmd.Source }
}
$env:Path = 'C:\dev\flutter\bin;' + [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')

$script:Failures = New-Object System.Collections.ArrayList

function Invoke-Gate([string]$Name, [scriptblock]$Body) {
    Write-Host ''
    Write-Host ('== ' + $Name) -ForegroundColor Cyan
    & $Body
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        Write-Host ('  [FAIL] ' + $Name + ' (exit ' + $code + ')') -ForegroundColor Red
        [void]$script:Failures.Add($Name)
    } else {
        Write-Host ('  [PASS] ' + $Name) -ForegroundColor Green
    }
}

Invoke-Gate 'taxonomy parity (Dart <-> backend json)' { & $python 'scripts\sync_taxonomy.py' --quiet }
Invoke-Gate 'wire parity (Dart <-> FastAPI)' { & $python 'scripts\check_wire_parity.py' --quiet }
Invoke-Gate 'flutter analyze' { & flutter analyze }
Invoke-Gate 'flutter test' { & flutter test }

if (-not $SkipBackend) {
    $ca = Join-Path $repo 'backend\certs\ca.crt'
    if (-not (Test-Path $ca)) {
        Write-Host '  [SKIP] backend smoke test (no backend/certs/ca.crt)' -ForegroundColor Yellow
    } else {
        Invoke-Gate 'backend smoke test (strict TLS)' {
            & $python 'scripts\smoke_test.py' --base $ApiBase --ca $ca --token $Token
        }
    }
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor White
if ($script:Failures.Count -eq 0) {
    Write-Host '  ALL GATES PASSED - repo is demo-able' -ForegroundColor Green
} else {
    Write-Host '  GATES FAILED:' -ForegroundColor Red
    foreach ($failure in $script:Failures) { Write-Host ('   - ' + $failure) -ForegroundColor Red }
}
Write-Host '============================================================' -ForegroundColor White
Write-Host ''
if ($script:Failures.Count -gt 0) { exit 1 }
exit 0
