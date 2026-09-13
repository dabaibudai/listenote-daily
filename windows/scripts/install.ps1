param()

$ErrorActionPreference = "Stop"
$InstallDir = Join-Path $env:LOCALAPPDATA "Listenote Daily"
$SourceExe = Join-Path $PSScriptRoot "ListenoteDaily.exe"
$ModelUrl = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin"
$ModelSha256 = "1fc70f774d38eb169993ac391eea357ef47c88757ef72ee5943879b7e8e2bc69"

if (-not (Test-Path $SourceExe)) {
    throw "ListenoteDaily.exe must be next to install.ps1. Extract the release ZIP first."
}

Write-Host "[1/5] Installing Listenote Daily"
Get-Process -Name "ListenoteDaily" -ErrorAction SilentlyContinue | Stop-Process -Force
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
if ([IO.Path]::GetFullPath($PSScriptRoot) -ne [IO.Path]::GetFullPath($InstallDir)) {
    Get-ChildItem -Path $PSScriptRoot | Where-Object { $_.Name -ne "config.ini" } |
        Copy-Item -Destination $InstallDir -Recurse -Force
}

$WhisperDir = Join-Path $InstallDir "tools\whisper"
$WhisperExe = Join-Path $WhisperDir "whisper-cli.exe"
if (-not (Test-Path $WhisperExe)) {
    Write-Host "[2/5] Downloading whisper.cpp"
    $Release = Invoke-RestMethod -Headers @{ "User-Agent" = "Listenote-Daily" } -Uri "https://api.github.com/repos/ggml-org/whisper.cpp/releases/latest"
    $Asset = $Release.assets | Where-Object { $_.name -eq "whisper-bin-x64.zip" } | Select-Object -First 1
    if (-not $Asset) {
        $Asset = $Release.assets | Where-Object { $_.name -match "^whisper-(blas-)?bin-x64\.zip$" } | Select-Object -First 1
    }
    if (-not $Asset) { throw "No compatible Windows x64 whisper.cpp asset was found." }
    $TempRoot = Join-Path $env:TEMP ("listenote-install-" + [guid]::NewGuid())
    $Zip = Join-Path $TempRoot "whisper.zip"
    $Expanded = Join-Path $TempRoot "expanded"
    New-Item -ItemType Directory -Force -Path $Expanded | Out-Null
    Invoke-WebRequest -Headers @{ "User-Agent" = "Listenote-Daily" } -Uri $Asset.browser_download_url -OutFile $Zip
    if ($Asset.digest -and $Asset.digest.StartsWith("sha256:")) {
        $Expected = $Asset.digest.Substring(7).ToLowerInvariant()
        $Actual = (Get-FileHash -Algorithm SHA256 $Zip).Hash.ToLowerInvariant()
        if ($Actual -ne $Expected) { throw "whisper.cpp download checksum mismatch." }
    }
    Expand-Archive -Path $Zip -DestinationPath $Expanded -Force
    $FoundExe = Get-ChildItem -Path $Expanded -Filter "whisper-cli.exe" -Recurse | Select-Object -First 1
    if (-not $FoundExe) { throw "whisper-cli.exe was not present in the downloaded archive." }
    New-Item -ItemType Directory -Force -Path $WhisperDir | Out-Null
    Copy-Item -Path (Join-Path $FoundExe.Directory.FullName "*") -Destination $WhisperDir -Recurse -Force
    Remove-Item -Path $TempRoot -Recurse -Force
} else {
    Write-Host "[2/5] Reusing whisper.cpp"
}

$ModelsDir = Join-Path $InstallDir "models"
$ModelPath = Join-Path $ModelsDir "ggml-large-v3-turbo.bin"
New-Item -ItemType Directory -Force -Path $ModelsDir | Out-Null
if (-not (Test-Path $ModelPath) -or (Get-FileHash -Algorithm SHA256 $ModelPath).Hash.ToLowerInvariant() -ne $ModelSha256) {
    Write-Host "[3/5] Downloading Large v3 Turbo model (about 1.5 GB)"
    $Partial = "$ModelPath.partial"
    Remove-Item $Partial -Force -ErrorAction SilentlyContinue
    Start-BitsTransfer -Source $ModelUrl -Destination $Partial
    $Actual = (Get-FileHash -Algorithm SHA256 $Partial).Hash.ToLowerInvariant()
    if ($Actual -ne $ModelSha256) {
        Remove-Item $Partial -Force
        throw "Whisper model checksum mismatch."
    }
    Move-Item -Path $Partial -Destination $ModelPath -Force
} else {
    Write-Host "[3/5] Reusing verified Whisper model"
}

$ConfigPath = Join-Path $InstallDir "config.ini"
if (-not (Test-Path $ConfigPath)) {
    Copy-Item (Join-Path $PSScriptRoot "config.ini") $ConfigPath
}

Write-Host "[4/5] Enabling startup"
$Startup = [Environment]::GetFolderPath("Startup")
$ShortcutPath = Join-Path $Startup "Listenote Daily.lnk"
$Shell = New-Object -ComObject WScript.Shell
$Shortcut = $Shell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = Join-Path $InstallDir "ListenoteDaily.exe"
$Shortcut.WorkingDirectory = $InstallDir
$Shortcut.Description = "Listenote Daily"
$Shortcut.Save()
$Programs = [Environment]::GetFolderPath("Programs")
$MenuShortcut = $Shell.CreateShortcut((Join-Path $Programs "Listenote Daily.lnk"))
$MenuShortcut.TargetPath = Join-Path $InstallDir "ListenoteDaily.exe"
$MenuShortcut.WorkingDirectory = $InstallDir
$MenuShortcut.Description = "Listenote Daily"
$MenuShortcut.Save()

Write-Host "[5/5] Starting"
Start-Process (Join-Path $InstallDir "ListenoteDaily.exe")
Write-Host "Installed. Edit schedule: $ConfigPath"
Write-Host "Notes: $(Join-Path $InstallDir 'records\transcripts')"
