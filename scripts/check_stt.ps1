<#
.SYNOPSIS
    Verifies the voice pipeline (audio -> text) without a phone.

.DESCRIPTION
    Synthesizes a fixed sentence with Windows TTS, POSTs the WAV to
    /api/transcribe and checks the returned text. Proves the whole mic hop
    (PyAV decode, VAD, faster-whisper, JSON/base64 transport, token auth)
    works on this laptop — useful before rehearsals and after dependency
    changes.

.EXAMPLE
    .\scripts\check_stt.ps1
    .\scripts\check_stt.ps1 -Base https://192.168.137.1:8443
#>
[CmdletBinding()]
param(
    [string]$Base = 'https://127.0.0.1:8443',
    [string]$Token = 'demo-token',
    [string]$CaFile = ''
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
if (-not $CaFile) { $CaFile = Join-Path $repo 'backend\certs\ca.crt' }
$vpy = Join-Path $repo 'backend\.venv\Scripts\python.exe'
if (-not (Test-Path $vpy)) { throw "backend venv not found at $vpy" }

$wav = Join-Path $env:TEMP 'wingman-check-stt.wav'
Write-Host '==> synthesizing the test utterance (Windows TTS)' -ForegroundColor Cyan
Add-Type -AssemblyName System.Speech
$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$synth.SetOutputToWaveFile($wav)
$synth.Speak('There is smoke near gate twelve, please send security')
$synth.Dispose()
Write-Host ("    wav: " + [math]::Round((Get-Item $wav).Length / 1KB, 1) + " KB")

$code = @'
import base64, json, ssl, sys, time, urllib.request
wav, base, token, ca = sys.argv[1:5]
ctx = ssl.create_default_context(cafile=ca)
data = base64.b64encode(open(wav, "rb").read()).decode()
body = json.dumps({"audio_base64": data, "mime_type": "audio/wav"}).encode()
req = urllib.request.Request(base.rstrip("/") + "/api/transcribe", data=body,
    headers={"Authorization": "Bearer " + token, "Content-Type": "application/json"})
started = time.perf_counter()
with urllib.request.urlopen(req, context=ctx, timeout=180) as resp:
    result = json.load(resp)
print(json.dumps({"status": resp.status, "wall_s": round(time.perf_counter() - started, 2), **result}, ensure_ascii=False))
'@
$script = Join-Path $env:TEMP 'wingman-check-stt.py'
Set-Content -Path $script -Value $code -Encoding UTF8

Write-Host "==> transcribing via $Base/api/transcribe" -ForegroundColor Cyan
$raw = & $vpy $script $wav $Base $Token $CaFile 2>&1
$raw | ForEach-Object { "    $_" }

$json = $null
try { $json = ($raw | Where-Object { $_ -like '{*' } | Select-Object -Last 1) | ConvertFrom-Json } catch { }
if (-not $json) {
    Write-Host 'FAIL: no JSON response (is the backend running? is the CA path right?)' -ForegroundColor Red
    exit 1
}
if ($json.text -match 'smoke' -or $json.text -match 'gate') {
    Write-Host ''
    Write-Host ('PASS  voice pipeline works: "' + $json.text + '" (' + $json.latency_ms + ' ms, ' + $json.duration_ms + ' ms audio)') -ForegroundColor Green
    exit 0
}
Write-Host ''
Write-Host ('FAIL  unexpected transcription: "' + $json.text + '"') -ForegroundColor Red
exit 1
