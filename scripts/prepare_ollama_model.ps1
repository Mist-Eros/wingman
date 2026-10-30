<#
.SYNOPSIS
    Prepares the local LLM for Wingman without relying on the Ollama registry.

.DESCRIPTION
    The Ollama registry was stalling on the demo network, so this script:
      1. downloads the official Qwen2.5-1.5B-Instruct Q4_K_M GGUF from
         HuggingFace (public, no token needed);
      2. writes a Modelfile with the official Qwen2.5 chat template
         (system/user/assistant messages, <|im_end|> stop token);
      3. registers it with `ollama create qwen2.5:1.5b`.

    Run `ollama serve` first (or let this script start it). Re-running is safe:
    an existing GGUF is not downloaded again and the model is re-created.

.EXAMPLE
    .\scripts\prepare_ollama_model.ps1
    .\scripts\prepare_ollama_model.ps1 -Model llama3.1:8b -GgufUrl https://...
#>
[CmdletBinding()]
param(
    [string]$Model = 'qwen2.5:1.5b',
    [string]$GgufName = 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
    [string]$GgufUrl = 'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf',
    [string]$WorkDir = ''
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
if (-not $WorkDir) { $WorkDir = Join-Path (Split-Path $repo -Parent) 'setup' }
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null

function Find-Ollama {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Ollama\ollama.exe'),
        (Join-Path $env:ProgramFiles 'Ollama\ollama.exe'),
        'ollama'
    )
    foreach ($c in $candidates) {
        if ($c -eq 'ollama') {
            $cmd = Get-Command ollama -ErrorAction SilentlyContinue
            if ($cmd) { return $cmd.Source }
        } elseif (Test-Path $c) { return $c }
    }
    throw 'ollama not found. Install from https://ollama.com/download'
}

$ollama = Find-Ollama
Write-Host "==> ollama: $ollama" -ForegroundColor Cyan

# 1. server up?
try {
    $null = Invoke-RestMethod 'http://127.0.0.1:11434/api/tags' -TimeoutSec 3
    Write-Host '    server already running' -ForegroundColor Green
} catch {
    Write-Host '    starting ollama serve' -ForegroundColor Yellow
    Start-Process -FilePath $ollama -ArgumentList 'serve' -WindowStyle Hidden | Out-Null
    for ($i = 0; $i -lt 20; $i++) {
        Start-Sleep -Seconds 1
        try { $null = Invoke-RestMethod 'http://127.0.0.1:11434/api/tags' -TimeoutSec 2; break } catch { }
    }
}

# 2. GGUF download (resumable)
$gguf = Join-Path $WorkDir $GgufName
Write-Host "==> GGUF: $gguf" -ForegroundColor Cyan
if (-not (Test-Path $gguf)) {
    & curl.exe -L -C - --retry 5 --retry-delay 3 -sS -o $gguf $GgufUrl
    if ($LASTEXITCODE -ne 0) { throw "download failed (exit $LASTEXITCODE): $GgufUrl" }
}
Write-Host ("    " + [math]::Round((Get-Item $gguf).Length / 1MB, 1) + " MB") -ForegroundColor Green

# 3. Modelfile (official Qwen2.5 chat template)
$modelfile = Join-Path $WorkDir 'Modelfile.qwen2.5-1.5b'
$template = @'
FROM ./{GGUF}

TEMPLATE """{{- if .Messages }}
{{- if or .System .Tools }}<|im_start|>system
{{- if .System }}
{{ .System }}
{{- end }}<|im_end|>
{{ end }}
{{- range $i, $_ := .Messages }}
{{- $last := eq (len (slice $.Messages $i)) 1 -}}
{{- if eq .Role "user" }}<|im_start|>user
{{ .Content }}<|im_end|>
{{ else if eq .Role "assistant" }}<|im_start|>assistant
{{ if .Content }}{{ .Content }}{{ end }}{{ if not $last }}<|im_end|>
{{ end }}
{{- end }}
{{- if and (ne .Role "assistant") $last }}<|im_start|>assistant
{{ end }}
{{- end }}
{{- else }}
{{- if .System }}<|im_start|>system
{{ .System }}<|im_end|>
{{ end }}{{ if .Prompt }}<|im_start|>user
{{ .Prompt }}<|im_end|>
{{ end }}<|im_start|>assistant
{{ end }}{{ .Response }}{{ if .Response }}<|im_end|>{{ end }}"""

PARAMETER stop "<|im_end|>"
PARAMETER temperature 0.2
PARAMETER top_p 0.9
PARAMETER num_ctx 4096
PARAMETER repeat_penalty 1.05
'@ -replace '{GGUF}', $GgufName
[System.IO.File]::WriteAllText($modelfile, $template, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "==> registered model '$Model'" -ForegroundColor Cyan

# 4. create + smoke prompt
Push-Location $WorkDir
try {
    & $ollama create $Model -f (Split-Path $modelfile -Leaf)
    if ($LASTEXITCODE -ne 0) { throw "ollama create failed (exit $LASTEXITCODE)" }
} finally { Pop-Location }

& $ollama list
Write-Host ''
Write-Host "==> quick generation test" -ForegroundColor Cyan
& $ollama run $Model 'Răspunde exact cu: OK' 2>&1 | Select-Object -First 4
Write-Host ''
Write-Host "Done. Backend default OLLAMA_MODEL=$Model (run.ps1)." -ForegroundColor Green
