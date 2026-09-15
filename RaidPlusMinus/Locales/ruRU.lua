if GetLocale() ~= "ruRU" then return end

RaidPlusMinusLocale = RaidPlusMinusLocale or {}
local L = RaidPlusMinusLocale

-- UI labels
L["EMPTY_TEXT"] = "Вы не в рейде/группе"
L["HEADER_PLAYER"] = "Игрок"
L["HEADER_SCORE"] = "Очки"
L["ADD_NAME_LABEL"] = "Ник:"
L["SORT_BY_SCORE"] = "Сорт: очки"
L["SORT_BY_NAME"] = "Сорт: имя"
L["TOOLTIP_NO_NOTES"] = "Нет заметок"

-- Buttons
L["BTN_RESET"] = "Сброс"
L["BTN_SYNC"] = "Синхр."
L["BTN_CHAT"] = "Чат"
L["BTN_EXPORT"] = "Экспорт"
L["BTN_IMPORT"] = "Импорт"
L["BTN_CANCEL"] = "Отмена"
L["ACTION_ADD_PLUS"] = "Добавить плюс"
L["ACTION_ADD_MINUS"] = "Добавить минус"

-- Input dialog
L["INPUT_VALUE_LABEL"] = "Значение:"
L["INPUT_NOTE_LABEL"] = "Заметка:"
L["ERR_VALUE_POSITIVE"] = "Введите значение больше нуля"
L["ERR_ENTER_NAME"] = "Введите ник игрока"

-- Popups
L["POPUP_EXPORT_TEXT"] = "Экспорт очков (Ctrl+C, чтобы скопировать):"
L["POPUP_IMPORT_TEXT"] = "Вставьте строку импорта:"
L["POPUP_RESET_TEXT"] = "Сбросить все очки и историю? Это разошлётся всем в рейде."

-- Permission / dialog / chat errors
L["ERR_RESET_PERM"] = "Сброс доступен только лидеру/ассистенту рейда"
L["ERR_SYNC_PERM"] = "Синхронизацию может запускать только лидер/ассистент"
L["ERR_EDIT_PERM"] = "Изменять очки может только лидер/ассистент"
L["MSG_NO_PERMISSION"] = "нет прав (не лидер/ассистент)"
L["ERR_NO_DATA"] = "Нет данных для отображения"
L["ERR_GENERIC"] = "Ошибка: %s"
L["MSG_RESET_DONE"] = "Все очки сброшены."
L["MSG_RESET_ERR"] = "Ошибка сброса: %s"
L["MSG_BROADCAST_FAILED"] = "Рассылка не удалась: %s"
L["ERR_ADD_USAGE"] = "Используй plus или minus: /rpm add plus Ник [значение] [заметка]"

-- Sync/status text
L["SYNC_SENT"] = "Разослано: %s"
L["SYNC_UPDATED"] = "Обновлено: %s"
L["SYNC_SYNCED"] = "Синхронизировано: %s"
L["SYNC_RESET_BY"] = "Сброшено (%s): %s"

-- Chat report
L["CHAT_REPORT_LABEL"] = "----ОТЧЁТ----"

-- Slash command output (status/help)
L["STATUS_HEADER"] = "статус:"
L["STATUS_NAME"] = "Имя: %s"
L["STATUS_GROUP"] = "В рейде: %s (%d), в группе: %s (%d)"
L["STATUS_LEADER"] = "UnitIsGroupLeader: %s"
L["STATUS_ASSISTANT"] = "UnitIsGroupAssistant: %s"
L["STATUS_ERROR_PREFIX"] = "ОШИБКА: %s"
L["STATUS_RANK"] = "Ранг из GetRaidRosterInfo: %s"
L["STATUS_RANK_LEGEND"] = "%s (0=участник,1=ассистент,2=лидер)"
L["STATUS_CANEDIT"] = "CanEdit() итог: %s"
L["HELP_HEADER"] = "команды:"
L["HELP_LINE_TOGGLE"] = "/rpm - открыть/закрыть окно"
L["HELP_LINE_CHAT"] = "/rpm chat - вывести минуса в чат"
L["HELP_LINE_ADD_PLUS"] = "/rpm add plus Ник [значение] [заметка]"
L["HELP_LINE_ADD_MINUS"] = "/rpm add minus Ник [значение] [заметка]"
L["HELP_LINE_DEFAULTS"] = "(значение и заметка необязательны, по умолчанию значение = 1)"
L["HELP_LINE_STATUS"] = "/rpm status - показать, какие права видит аддон"
