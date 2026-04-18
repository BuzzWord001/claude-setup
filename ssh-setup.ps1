#requires -Version 5.1
<#
.SYNOPSIS
  Настройка OpenSSH Server на ноутбуке — чтобы Claude с ПК мог подключаться и выполнять команды.

.USAGE
  ТРЕБУЕТСЯ POWERSHELL ОТ АДМИНИСТРАТОРА:
  - Правый клик на иконку PowerShell → "Запуск от имени администратора"
  - Вставить:
    irm https://raw.githubusercontent.com/BuzzWord001/claude-setup/main/ssh-setup.ps1 | iex
#>

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"
$PSNativeCommandUseErrorActionPreference = $false

# 0. Проверка admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Host "❌ Нужны права администратора." -ForegroundColor Red
    Write-Host "   Закрой это окно, найди PowerShell в меню Пуск,"
    Write-Host "   правый клик → 'Запуск от имени администратора',"
    Write-Host "   и вставь команду ещё раз." -ForegroundColor Yellow
    exit 1
}

function Say($msg, $color = "Cyan") {
    Write-Host ""
    Write-Host "==> $msg" -ForegroundColor $color
}

Say "Настройка SSH Server для удалённого доступа Claude" "Yellow"

# 1. Установить OpenSSH Server (встроенный Windows capability)
$sshd = Get-Service sshd -ErrorAction SilentlyContinue
if ($sshd) {
    Say "OpenSSH Server уже установлен" "Green"
} else {
    Say "Устанавливаю OpenSSH.Server (~5 MB)..."
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 | Out-Null
}

# 2. Запуск + автозапуск
Say "Запускаю службу sshd..."
Start-Service sshd -ErrorAction SilentlyContinue
Set-Service -Name sshd -StartupType Automatic
$status = (Get-Service sshd).Status
Write-Host "Служба sshd: $status" -ForegroundColor Green

# 3. Firewall — порт 22 TCP inbound
$rule = Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue
if (-not $rule) {
    Say "Открываю порт 22 в Firewall..."
    New-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -DisplayName "OpenSSH Server (sshd)" `
        -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
} else {
    Say "Firewall уже настроен" "Green"
}

# 4. Скачать публичный ключ ПК
Say "Добавляю публичный ключ ПК в authorized_keys..."
$sshDir   = "$env:USERPROFILE\.ssh"
$authFile = "$sshDir\authorized_keys"
New-Item -ItemType Directory -Force -Path $sshDir | Out-Null

$pkUrl = "https://raw.githubusercontent.com/BuzzWord001/claude-setup/main/pc-public-key.pub"
$pcKey = (Invoke-WebRequest -Uri "$pkUrl`?t=$(Get-Random)" -UseBasicParsing).Content.Trim()

if (Test-Path $authFile) {
    $existing = Get-Content $authFile -Raw -ErrorAction SilentlyContinue
    if ($existing -and ($existing -match [regex]::Escape($pcKey))) {
        Say "Ключ уже в authorized_keys" "Green"
    } else {
        Add-Content -Path $authFile -Value $pcKey
    }
} else {
    Set-Content -Path $authFile -Value $pcKey
}

# 5. Права на authorized_keys — критично для Windows OpenSSH
icacls $authFile /inheritance:r /grant:r "${env:USERNAME}:F" /grant:r "SYSTEM:F" | Out-Null

# 6. Показать IP адреса для подключения
Say "IP-адреса для подключения с ПК:" "Yellow"
$ips = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -notmatch "^127\." -and $_.IPAddress -notmatch "^169\.254\." -and $_.InterfaceAlias -notmatch "Loopback" } |
    Select-Object -ExpandProperty IPAddress

foreach ($ip in $ips) {
    Write-Host "  ssh $env:USERNAME@$ip" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "  ГОТОВО!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Перешли Лиру одну из этих команд (IP-адресов)." -ForegroundColor Yellow
Write-Host "Он вставит её на ПК в Claude — я сразу начну работать на твоём ноуте." -ForegroundColor Yellow
Write-Host ""
Write-Host "Для подключения из интернета (когда ноут не дома) — поставь Tailscale:"
Write-Host "  https://tailscale.com/download/windows" -ForegroundColor DarkGray
