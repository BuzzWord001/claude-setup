#requires -Version 5.1
<#
.SYNOPSIS
  Устанавливает Windows Terminal и добавляет профиль "Claude".

.USAGE
  irm https://raw.githubusercontent.com/BuzzWord001/claude-setup/main/terminal.ps1 | iex
#>

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"
$PSNativeCommandUseErrorActionPreference = $false

function Say($msg, $color = "Cyan") {
    Write-Host ""
    Write-Host "==> $msg" -ForegroundColor $color
}

Say "Установка Windows Terminal + профиль Claude" "Yellow"

# 1. Windows Terminal
$wt = Get-Command wt -ErrorAction SilentlyContinue
if ($wt) {
    Say "Windows Terminal уже установлен — пропускаю" "Green"
} else {
    Say "Устанавливаю Microsoft.WindowsTerminal..."
    winget install -e --id Microsoft.WindowsTerminal --accept-source-agreements --accept-package-agreements --silent
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
}

# 2. Fragment extension — добавляет профиль Claude БЕЗ правки основного settings.json
# https://learn.microsoft.com/en-us/windows/terminal/json-fragment-extensions
$fragmentDir  = "$env:LOCALAPPDATA\Microsoft\Windows Terminal\Fragments\Claude"
$fragmentFile = "$fragmentDir\claude-profile.json"

New-Item -ItemType Directory -Force -Path $fragmentDir | Out-Null

$fragment = @{
    profiles = @(
        [ordered]@{
            name              = "Claude"
            commandline       = 'powershell.exe -NoExit -Command "Set-Location $HOME; claude"'
            startingDirectory = "%USERPROFILE%"
            icon              = "🤖"
            colorScheme       = "Campbell Powershell"
            font              = @{ face = "Cascadia Code" }
        }
    )
}

$json = $fragment | ConvertTo-Json -Depth 10
$json | Out-File -Encoding utf8 -FilePath $fragmentFile -Force
Say "Профиль Claude добавлен: $fragmentFile" "Green"

# 3. Ярлык на рабочий стол (опционально)
$desktop = [Environment]::GetFolderPath("Desktop")
$shortcutPath = "$desktop\Claude.lnk"

if (-not (Test-Path $shortcutPath)) {
    $wtPath = (Get-Command wt -ErrorAction SilentlyContinue).Source
    if (-not $wtPath) {
        # fallback — полный путь
        $wtPath = "$env:LOCALAPPDATA\Microsoft\WindowsApps\wt.exe"
    }

    $WshShell = New-Object -ComObject WScript.Shell
    $s = $WshShell.CreateShortcut($shortcutPath)
    $s.TargetPath = $wtPath
    $s.Arguments = "-p Claude"
    $s.WorkingDirectory = $env:USERPROFILE
    $s.IconLocation = "$wtPath,0"
    $s.Save()
    Say "Ярлык создан на рабочем столе: Claude.lnk" "Green"
} else {
    Say "Ярлык уже есть — пропускаю" "Green"
}

# Финал
Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "  ГОТОВО!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
Write-Host "1. Дважды кликни по ярлыку 'Claude' на рабочем столе"
Write-Host "   ИЛИ открой Windows Terminal и выбери вкладку 'Claude'"
Write-Host ""
Write-Host "2. Claude Code запустится сразу в домашней папке"
Write-Host "   с правильным шрифтом Cascadia Code (поддержка эмодзи, греческого)"
Write-Host ""
Write-Host "Чтобы сделать 'Claude' стартовой вкладкой по умолчанию:"
Write-Host "   Открой Windows Terminal → Ctrl+, → Startup → Default profile → Claude"
Write-Host ""
