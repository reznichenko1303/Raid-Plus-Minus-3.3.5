# Raid +/-

[English](#english) | [Русский](#русский)

---

## English

**Raid +/-** is a World of Warcraft: Wrath of the Lich King (3.3.5a) addon for tracking a running plus/minus score per raid or party member, to help make roll and loot distribution fairer over time (e.g. penalize players who already won an item, reward those who passed).

### What it does

- Shows a window listing your current raid/party roster with class-colored names and each player's score.
- Leader/assistant can click `+`/`-` on any row, or Shift-click to open a dialog for a custom value and a short note (reason), which is stored in that player's history (last 30 entries kept).
- Right-click a row (or use it through the standard Blizzard unit menu, including ElvUI/oUF-style raid frames) to add a plus/minus from a context menu.
- A manual "Name" field lets you adjust a player's score even if they aren't currently visible in your roster.
- Real-time sync between group members over an addon-message channel, so everyone with the addon sees the same scores.
- Reset (with confirmation), export/import via a copyable text string, and a chat report of everyone with recorded history.
- Edits, resets, and syncs are restricted to the raid leader/assistant (or party leader).

### Features

- Sortable list (by score or by name)
- Per-change notes/reasons kept in player history
- Addon-message sync across the raid/party (auto-requests sync on joining a group)
- Export/import scores as a compact text string for backup
- Chat report button (posts a summary to raid/party or local chat)
- Defensive `pcall`-wrapped permission checks for compatibility with private servers
- Bilingual UI (English/Russian), auto-detected from your client language

### Slash commands

| Command | Description |
|---|---|
| `/rpm` | Open/close the main window |
| `/rpm chat` | Post the score report to chat |
| `/rpm add plus Name [value] [note]` | Add a plus to a player |
| `/rpm add minus Name [value] [note]` | Add a minus to a player |
| `/rpm status` | Show what permissions/raid rank the addon detects |
| `/rpm help` | List commands |

`value` and `note` are optional (default value is 1). The alias `/плюсы` and Russian keywords (`чат`, `плюс`, `минус`, `статус`, `помощь`) are also always accepted, regardless of client language, for backward compatibility.

### Installation

1. Copy the `RaidPlusMinus` folder into your WotLK 3.3.5 client's `Interface/AddOns/` directory.
2. Enable "Raid +/-" in the AddOns list at the character selection screen.

### Requirements

- World of Warcraft: Wrath of the Lich King, client version 3.3.5a (Interface 30300).
- No other addon dependencies.

### Tested on

- WoWCircle (3.3.5a realm).

### Localization

The UI language is selected automatically based on your client's locale (`GetLocale()`): Russian (`ruRU`) clients get a fully localized interface; all other locales default to English.

---

## Русский

**Raid +/-** — аддон для World of Warcraft: Wrath of the Lich King (3.3.5a), который ведёт учёт плюсов и минусов участников рейда/группы, чтобы со временем сделать распределение ролла и лута более честным (например, снижать приоритет тем, кто уже получил предмет, и повышать тем, кто пропустил ролл).

### Что делает аддон

- Показывает окно со списком текущего состава рейда/группы: имена, окрашенные по классу, и очки каждого игрока.
- Лидер/ассистент может нажать `+`/`-` напротив игрока, либо открыть с Shift диалог для ввода произвольного значения и короткой заметки (причины) — она сохраняется в истории игрока (хранятся последние 30 записей).
- Правый клик по строке (в том числе через стандартное меню юнита Blizzard, включая рейд-фреймы в стиле ElvUI/oUF) открывает контекстное меню для добавления плюса/минуса.
- Поле для ручного ввода ника позволяет изменить очки игрока, даже если его сейчас нет в видимом списке.
- Синхронизация в реальном времени между участниками группы через служебные аддон-сообщения — у всех, у кого установлен аддон, видны одинаковые очки.
- Сброс (с подтверждением), экспорт/импорт через копируемую текстовую строку и отчёт в чат по всем, у кого есть история изменений.
- Изменение очков, сброс и синхронизация доступны только лидеру/ассистенту рейда (или лидеру группы).

### Возможности

- Список с сортировкой (по очкам или по имени)
- Заметки/причины для каждого изменения, хранящиеся в истории игрока
- Синхронизация через аддон-сообщения по рейду/группе (автозапрос синхронизации при входе в группу)
- Экспорт/импорт очков в виде компактной текстовой строки для резервного копирования
- Кнопка отчёта в чат (публикует сводку в чат рейда/группы или локальный чат)
- Защищённые через `pcall` проверки прав для совместимости с приватными серверами
- Двуязычный интерфейс (русский/английский), определяется автоматически по языку клиента

### Слэш-команды

| Команда | Описание |
|---|---|
| `/rpm` | Открыть/закрыть главное окно |
| `/rpm chat` | Отправить отчёт по очкам в чат |
| `/rpm add plus Ник [значение] [заметка]` | Добавить плюс игроку |
| `/rpm add minus Ник [значение] [заметка]` | Добавить минус игроку |
| `/rpm status` | Показать, какие права/ранг видит аддон |
| `/rpm help` | Список команд |

`значение` и `заметка` необязательны (значение по умолчанию — 1). Алиас `/плюсы` и русские ключевые слова (`чат`, `плюс`, `минус`, `статус`, `помощь`) всегда работают независимо от языка клиента — для обратной совместимости.

### Установка

1. Скопируйте папку `RaidPlusMinus` в каталог `Interface/AddOns/` вашего клиента WotLK 3.3.5.
2. Включите «Raid +/-» в списке аддонов на экране выбора персонажа.

### Требования

- World of Warcraft: Wrath of the Lich King, версия клиента 3.3.5a (Interface 30300).
- Другие аддоны в качестве зависимостей не требуются.

### Протестировано на

- WoWCircle (реалм 3.3.5a).

### Локализация

Язык интерфейса определяется автоматически по локали клиента (`GetLocale()`): для клиентов с русской локалью (`ruRU`) интерфейс полностью на русском; для всех остальных локалей по умолчанию используется английский.
