# claude-setup

Автоустановщик Claude Code + синхронизация памяти через приватный git-репо.

## Установка (одна команда)

Открой **PowerShell** (обычный, не от админа) на ноутбуке и вставь:

```powershell
irm https://raw.githubusercontent.com/BuzzWord001/claude-setup/main/install.ps1 | iex
```

Скрипт:

1. Ставит Node.js LTS, Git, GitHub CLI (через winget)
2. Ставит Claude Code (`npm install -g @anthropic-ai/claude-code`)
3. Логинит тебя в GitHub (интерактивно в браузере)
4. Клонирует приватный репо `BuzzWord001/claude-memory` в нужную папку
5. Прописывает хуки автосинхронизации в `~/.claude/settings.json`

После завершения — залогинься в Claude: `claude login`, и запускай `claude` в любой папке.

## Что синхронизируется

Только папка памяти: `~/.claude/projects/C--Users-<USERNAME>/memory/`.

- **Старт сессии** → `git pull`
- **Конец ответа Claude** → `git add + commit + push` (только если есть изменения)

Конфликты маловероятны (обычно работаешь на одном устройстве за раз), но при одновременной правке файла — разрулится через `git merge`.

## Что **не** синхронизируется

- `settings.json` / `settings.local.json` — специфичны для устройства
- Сессии (`sessions/`)
- Плагины (`plugins/`)
- Jarvis-инструменты (голос, статус-окно) — если нужны на ноуте, копируй отдельно

## Использование

После установки — работаешь как обычно. Я автоматически вижу на ноуте всё, что запомнила на ПК.
