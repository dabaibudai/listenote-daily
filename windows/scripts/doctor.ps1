$ErrorActionPreference = "Continue"
$Root = Join-Path $env:LOCALAPPDATA "Listenote Daily"
$Checks = @(
    (Join-Path $Root "ListenoteDaily.exe"),
    (Join-Path $Root "config.ini"),
    (Join-Path $Root "tools\whisper\whisper-cli.exe"),
    (Join-Path $Root "models\ggml-large-v3-turbo.bin")
)
foreach ($Path in $Checks) {
    if (Test-Path $Path) { Write-Host "OK   $Path" } else { Write-Host "MISS $Path" }
}
$Process = Get-Process -Name "ListenoteDaily" -ErrorAction SilentlyContinue
if ($Process) { Write-Host "OK   process running" } else { Write-Host "STOP process not running" }
