# Raid +/-

[English](#english) | [Русский](#русский)

---

## English

**Raid +/-** is a World of Warcraft: Wrath of the Lich King (3.3.5a) addon for tracking a running plus/minus score per raid or party member, to help make roll and loot distribution fairer over time (e.g. penalize players who already won an item, reward those who passed).

### What it does

- Shows a window listing your current raid/party roster with class-colored names and each player's score. Open it with `/rpm` or the minimap button.
- Leader/assistant can click `+`/`-` on any row to add or remove **5 points**, or Shift-click to open a dialog for a custom value (default 5) and a short note (reason), which is stored in that player's history (last 30 entries kept).
- The note field has a quick-pick list of common reasons: plus — Overall, Prof, Tank, Heal, Last item; minus — AFK, Death, Dispel, Spirit, Bar.
- Right-click a row (or use it through the standard Blizzard unit menu, including ElvUI/oUF-style raid frames) to add a plus/minus from a context menu.
- A manual "Name" field lets you adjust a player's score even if they aren't currently visible in your roster. Names are auto-completed as you type (Tab/Enter accepts).
- A **History** tab shows a shared feed of who changed what and when (newest first, last 200 changes). Leaders/assistants can undo the newest change with the **Undo** button or `/rpm undo`; the undo is synced to everyone.
- Scores are **cleared automatically when you join or leave a raid**, so points from a previous raid never carry over. This is local only, and the new raid's data is then requested from its officers.
- Real-time sync between group members over an addon-message channel, so everyone with the addon sees the same scores. Full syncs carry per-player timestamps so a stale sync never overwrites newer changes, duplicate messages are ignored, and officers don't all answer a sync request at once.
- Reset (with confirmation), export/import via a copyable text string, and a chat report of everyone with recorded history.
- Edits, resets, and syncs are restricted to the raid leader/assistant (or party leader).

### Features

- Sortable list (by score or by name)
- Players / History tabs and a minimap button
- Undo of the latest change (synced)
- Ready-made reasons and name auto-completion
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
| `/rpm undo` | Undo the latest change (leader/assistant) |
| `/rpm status` | Show what permissions/raid rank the addon detects |
| `/rpm help` | List commands |

`value` and `note` are optional (default value is 1). The alias `/плюсы` and Russian keywords (`чат`, `плюс`, `минус`, `отмена`, `статус`, `помощь`) are also always accepted, regardless of client language, for backward compatibility.

### Installation

1. Copy the `RaidPlusMinus` folder into your WotLK 3.3.5 client's `Interface/AddOns/` directory.
2. Enable "Raid +/-" in the AddOns list at the character selection screen.

> **Note:** the sync protocol changed in 1.1 (prefix `RPM2`). Everyone in the raid needs the same version — older versions (1.0.x) will not sync with newer ones, though they won't corrupt each other's data either.

### Requirements

- World of Warcraft: Wrath of the Lich King, client version 3.3.5a (Interface 30300).
- No other addon dependencies.

### RaidRoll integration

If the RaidRoll addon is also installed, Raid +/- appends each roller's current score in parentheses next to their roll, e.g. `95 (+5: Tank, Heal)` or `42 (-5: AFK)` — the score followed by the player's latest reasons (up to 3, newest first). This is a display-only annotation added after RaidRoll renders its own roll list — the roll value itself is never modified, and RaidRoll's own data isn't touched.

### Tested on

- WoWCircle (3.3.5a realm).

### Localization

The UI language is selected automatically based on your client's locale (`GetLocale()`): Russian (`ruRU`) clients get a fully localized interface; all other locales default to English.

---

## Русский

**Raid +/-** — аддон для World of Warcraft: Wrath of the Lich King (3.3.5a), который ведёт учёт плюсов и минусов участников рейда/группы, чтобы со временем сделать распределение ролла и лута более честным (например, снижать приоритет тем, кто уже получил предмет, и повышать тем, кто пропустил ролл).

### Что делает аддон

- Показывает окно со списком текущего состава рейда/группы: имена, окрашенные по классу, и очки каждого игрока. Открывается через `/rpm` или кнопку у миникарты.
- Лидер/ассистент может нажать `+`/`-` напротив игрока, чтобы добавить или снять **5 очков**, либо открыть с Shift диалог для ввода произвольного значения (по умолчанию 5) и короткой заметки (причины) — она сохраняется в истории игрока (хранятся последние 30 записей).
- У поля заметки есть список быстрых причин: плюсы — Оверолл, Проф, Танк, Хил, Ласт шмотка; минусы — АФК, Смерть, Диспел, Дух, Планка.
- Правый клик по строке (в том числе через стандартное меню юнита Blizzard, включая рейд-фреймы в стиле ElvUI/oUF) открывает контекстное меню для добавления плюса/минуса.
- Поле для ручного ввода ника позволяет изменить очки игрока, даже если его сейчас нет в видимом списке. Ник дополняется по мере ввода (Tab/Enter принимает).
- Вкладка **История** показывает общую ленту: кто, кому и когда изменил очки (сначала новые, последние 200 изменений). Лидер/ассистент может отменить последнее изменение кнопкой **Отмена** или командой `/rpm undo`; отмена синхронизируется со всеми.
- При **входе в рейд и выходе из него очки сбрасываются автоматически**, чтобы очки прошлого рейда не переносились в новый. Сброс только локальный, после чего данные нового рейда запрашиваются у его офицеров.
- Синхронизация в реальном времени между участниками группы через служебные аддон-сообщения — у всех, у кого установлен аддон, видны одинаковые очки. Полная синхронизация несёт временные метки игроков, поэтому устаревшие данные не затирают более свежие, повторные сообщения игнорируются, а офицеры не отвечают на запрос синхронизации все разом.
- Сброс (с подтверждением), экспорт/импорт через копируемую текстовую строку и отчёт в чат по всем, у кого есть история изменений.
- Изменение очков, сброс и синхронизация доступны только лидеру/ассистенту рейда (или лидеру группы).

### Возможности

- Список с сортировкой (по очкам или по имени)
- Вкладки «Игроки» / «История» и кнопка у миникарты
- Отмена последнего изменения (с синхронизацией)
- Готовые причины и автодополнение ника
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
| `/rpm undo` | Отменить последнее изменение (лидер/ассистент) |
| `/rpm status` | Показать, какие права/ранг видит аддон |
| `/rpm help` | Список команд |

`значение` и `заметка` необязательны (значение по умолчанию — 1). Алиас `/плюсы` и русские ключевые слова (`чат`, `плюс`, `минус`, `отмена`, `статус`, `помощь`) всегда работают независимо от языка клиента — для обратной совместимости.

### Установка

1. Скопируйте папку `RaidPlusMinus` в каталог `Interface/AddOns/` вашего клиента WotLK 3.3.5.
2. Включите «Raid +/-» в списке аддонов на экране выбора персонажа.

> **Важно:** в версии 1.1 изменился протокол синхронизации (префикс `RPM2`). У всех в рейде должна быть одна версия — старые (1.0.x) не синхронизируются с новыми, но и данные друг другу не портят.

### Требования

- World of Warcraft: Wrath of the Lich King, версия клиента 3.3.5a (Interface 30300).
- Другие аддоны в качестве зависимостей не требуются.

### Интеграция с RaidRoll

Если также установлен аддон RaidRoll, Raid +/- дописывает текущий счёт игрока в скобках рядом с его роллом, например `95 (+5: Танк, Хил)` или `42 (-5: АФК)` — счёт и последние причины игрока (до 3, сначала новые). Это чисто визуальная надпись, добавляемая уже после того, как RaidRoll отрисовал свой список роллов — сам ролл никак не изменяется, а данные RaidRoll не затрагиваются.

### Протестировано на

- WoWCircle (реалм 3.3.5a).

### Локализация

Язык интерфейса определяется автоматически по локали клиента (`GetLocale()`): для клиентов с русской локалью (`ruRU`) интерфейс полностью на русском; для всех остальных локалей по умолчанию используется английский.
