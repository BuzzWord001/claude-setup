#requires -Version 5.1
<#
.SYNOPSIS
  Установщик Claude Code + синхронизация памяти для Лира.

.DESCRIPTION
  Ставит Node.js LTS, Git, GitHub CLI, Claude Code.
  Клонирует приватный репо памяти BuzzWord001/claude-memory.
  Прописывает хуки автосинхронизации (SessionStart → git pull, Stop → git push).

.USAGE
  Запускать ОБЫЧНУЮ PowerShell (не от админа — winget сам запросит UAC):
  irm https://raw.githubusercontent.com/BuzzWord001/claude-setup/main/install.ps1 | iex
#>

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Say($msg, $color = "Cyan") {
    Write-Host ""
    Write-Host "==> $msg" -ForegroundColor $color
}

function Ensure-Command($name, $wingetId) {
    if (Get-Command $name -ErrorAction SilentlyContinue) {
        Say "$name уже установлен — пропускаю" "Green"
        return
    }
    Say "Устанавливаю $name ($wingetId)..."
    winget install -e --id $wingetId --accept-source-agreements --accept-package-agreements --silent
    # Обновить PATH в текущем процессе
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
}

Say "Claude Code installer для Лира-н" "Yellow"
Write-Host "Пользователь: $env:USERNAME"
Write-Host "Профиль:      $env:USERPROFILE"

# 1. Winget доступен?
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "winget не найден. Установи 'App Installer' из Microsoft Store и запусти скрипт снова." -ForegroundColor Red
    exit 1
}

# 2. Базовые инструменты
Ensure-Command "node" "OpenJS.NodeJS.LTS"
Ensure-Command "git"  "Git.Git"
Ensure-Command "gh"   "GitHub.cli"

# Перезагружаем PATH после установок — node/npm/git/gh могли добавиться
$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

# 3. Claude Code
if (Get-Command claude -ErrorAction SilentlyContinue) {
    Say "Claude Code уже установлен — пропускаю" "Green"
} else {
    Say "Устанавливаю Claude Code (npm install -g)..."
    # Используем cmd /c для обхода PowerShell Execution Policy (npm.ps1 может быть заблокирован)
    cmd /c "npm install -g @anthropic-ai/claude-code"
}

# 4. GitHub login (для git clone приватного репо памяти)
$ghStatus = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Say "Нужен вход в GitHub. Откроется браузер — войди как BuzzWord001."
    gh auth login --web --git-protocol https
} else {
    Say "GitHub уже авторизован — пропускаю" "Green"
}

# 5. Клонировать память
$projectDir = "$env:USERPROFILE\.claude\projects\C--Users-$env:USERNAME"
$memoryDir  = "$projectDir\memory"
if (Test-Path "$memoryDir\.git") {
    Say "Память уже клонирована — делаю pull"
    git -C $memoryDir pull --rebase --autostash
} else {
    New-Item -ItemType Directory -Force -Path $projectDir | Out-Null
    Say "Клонирую приватный репо памяти..."
    gh repo clone BuzzWord001/claude-memory $memoryDir
}

# 6. Установить memory_sync.py
$syncPath = "$env:USERPROFILE\.claude\memory_sync.py"
$syncCode = @'
"""Синхронизация памяти Claude через git.

Usage:
  python memory_sync.py pull    — SessionStart hook
  python memory_sync.py push    — Stop hook
"""
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path

_USER = os.environ["USERNAME"]
_HOME = Path(os.environ["USERPROFILE"])
REPO = _HOME / ".claude" / "projects" / f"C--Users-{_USER}" / "memory"


def _run(args, timeout=30):
    return subprocess.run(
        ["git", "-C", str(REPO)] + args,
        capture_output=True, text=True, timeout=timeout
    )


def pull():
    _run(["pull", "--rebase", "--autostash"], timeout=20)


def push():
    _run(["add", "-A"])
    r = _run(["diff", "--cached", "--quiet"])
    if r.returncode == 0:
        return
    ts = datetime.now().strftime("%Y-%m-%d %H:%M")
    _run(["commit", "-m", f"auto-sync {ts}"])
    _run(["push"], timeout=30)


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "pull"
    try:
        if mode == "pull":
            pull()
        elif mode == "push":
            push()
    except Exception:
        pass
'@
$syncCode | Out-File -Encoding utf8 -FilePath $syncPath -Force
Say "memory_sync.py сохранён в $syncPath" "Green"

# 7. Прописать хуки в settings.json
$settingsPath = "$env:USERPROFILE\.claude\settings.json"
if (Test-Path $settingsPath) {
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
} else {
    $settings = [PSCustomObject]@{}
}

if (-not $settings.hooks) {
    $settings | Add-Member -NotePropertyName hooks -NotePropertyValue ([PSCustomObject]@{}) -Force
}

$pullCmd = "pythonw `"$syncPath`" pull"
$pushCmd = "pythonw `"$syncPath`" push"

$settings.hooks | Add-Member -NotePropertyName SessionStart -NotePropertyValue @(
    [PSCustomObject]@{
        hooks = @(
            [PSCustomObject]@{ type = "command"; command = $pullCmd; async = $true }
        )
    }
) -Force

$settings.hooks | Add-Member -NotePropertyName Stop -NotePropertyValue @(
    [PSCustomObject]@{
        hooks = @(
            [PSCustomObject]@{ type = "command"; command = $pushCmd; async = $true }
        )
    }
) -Force

$settings | ConvertTo-Json -Depth 10 | Out-File -Encoding utf8 -FilePath $settingsPath -Force
Say "Хуки записаны в $settingsPath" "Green"

# 8. Проверка sync
Say "Тест синхронизации (pull)..."
& pythonw $syncPath pull

# 9. Финал
Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "  ГОТОВО! Что делать дальше:" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
Write-Host "1. Залогинься в Claude Code тем же Anthropic-аккаунтом:"
Write-Host "     claude login" -ForegroundColor Yellow
Write-Host ""
Write-Host "2. Запусти Claude в папке профиля:"
Write-Host "     cd `$HOME" -ForegroundColor Yellow
Write-Host "     claude" -ForegroundColor Yellow
Write-Host ""
Write-Host "Я уже вижу твою память с ПК и при завершении сессии"
Write-Host "автоматически запушу изменения обратно."
Write-Host ""
