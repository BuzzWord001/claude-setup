#requires -Version 5.1
<#
.SYNOPSIS
  Установщик Jarvis-tools для Лира.

.DESCRIPTION
  - Клонирует BuzzWord001/jarvis-tools в Desktop\take a look
  - Ставит Python 3.12 (если нет)
  - Ставит Python-зависимости (Pillow, edge-tts, pyautogui и т.д.)
  - Показывает команды для запуска сервисов

.USAGE
  irm https://raw.githubusercontent.com/BuzzWord001/claude-setup/main/jarvis.ps1 | iex
#>

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"
$PSNativeCommandUseErrorActionPreference = $false

function Say($msg, $color = "Cyan") {
    Write-Host ""
    Write-Host "==> $msg" -ForegroundColor $color
}

Say "Установка Jarvis-tools" "Yellow"

# 1. Python
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Say "Устанавливаю Python 3.12..."
    winget install -e --id Python.Python.3.12 --accept-source-agreements --accept-package-agreements --silent
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
} else {
    Say "Python уже установлен — пропускаю" "Green"
}

# 2. Клонирование репо
$jarvisDir = "$env:USERPROFILE\Desktop\take a look"

if (Test-Path "$jarvisDir\.git") {
    Say "Jarvis уже клонирован — делаю pull"
    git -C $jarvisDir pull --rebase --autostash
} else {
    Say "Клонирую BuzzWord001/jarvis-tools → $jarvisDir"
    # Родительская папка "Desktop" должна существовать
    New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\Desktop" | Out-Null
    gh repo clone BuzzWord001/jarvis-tools $jarvisDir
    if (-not (Test-Path "$jarvisDir\.git")) {
        Write-Host "Клонирование не удалось. Проверь gh auth status и права на репо." -ForegroundColor Red
        exit 1
    }
}

# 3. Python-зависимости
Say "Устанавливаю Python-зависимости (это 1-2 минуты)..."
$deps = @("pillow", "mss", "numpy", "pyautogui", "pyperclip", "pytesseract", "edge-tts", "requests", "selenium")
cmd /c "python -m pip install --upgrade pip 2>&1"
foreach ($pkg in $deps) {
    Write-Host "  pip install $pkg..." -ForegroundColor DarkGray
    cmd /c "python -m pip install --quiet $pkg 2>&1"
}
Say "Зависимости готовы" "Green"

# 4. Проверка speak.py (edge-tts)
Say "Тест speak.py..."
cmd /c "pythonw `"$jarvisDir\speak.py`" Джарвис готов 2>&1"

# 5. Итог
Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "  ГОТОВО!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Jarvis установлен в: $jarvisDir" -ForegroundColor Yellow
Write-Host ""
Write-Host "Запусти ключевые сервисы одной командой:" -ForegroundColor Cyan
Write-Host ""
$services = @("status_window", "voice_input", "show_me", "overlay", "task_list", "discord_mute")
foreach ($s in $services) {
    Write-Host "  Start-Process pythonw -ArgumentList '`"$jarvisDir\$s.pyw`"'"
}
Write-Host ""
Write-Host "Или одной строкой (скопируй и вставь):" -ForegroundColor Cyan
Write-Host ""
$oneLiner = ($services | ForEach-Object { "Start-Process pythonw -ArgumentList '`"$jarvisDir\$_.pyw`"'" }) -join "; "
Write-Host $oneLiner -ForegroundColor Yellow
Write-Host ""
Write-Host "Handy STT (для голосового ввода) нужно поставить отдельно:" -ForegroundColor DarkGray
Write-Host "  https://github.com/cjpais/Handy/releases" -ForegroundColor DarkGray
Write-Host ""
