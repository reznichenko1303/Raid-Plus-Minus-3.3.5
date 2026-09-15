RaidPlusMinusLocale = RaidPlusMinusLocale or {}
local L = RaidPlusMinusLocale

-- UI labels
L["EMPTY_TEXT"] = "You are not in a raid/party"
L["HEADER_PLAYER"] = "Player"
L["HEADER_SCORE"] = "Score"
L["ADD_NAME_LABEL"] = "Name:"
L["SORT_BY_SCORE"] = "Sort: score"
L["SORT_BY_NAME"] = "Sort: name"
L["TOOLTIP_NO_NOTES"] = "No notes"

-- Buttons
L["BTN_RESET"] = "Reset"
L["BTN_SYNC"] = "Sync"
L["BTN_CHAT"] = "Chat"
L["BTN_EXPORT"] = "Export"
L["BTN_IMPORT"] = "Import"
L["BTN_CANCEL"] = "Cancel"
L["ACTION_ADD_PLUS"] = "Add plus"
L["ACTION_ADD_MINUS"] = "Add minus"

-- Input dialog
L["INPUT_VALUE_LABEL"] = "Value:"
L["INPUT_NOTE_LABEL"] = "Note:"
L["ERR_VALUE_POSITIVE"] = "Enter a value greater than zero"
L["ERR_ENTER_NAME"] = "Enter a player name"

-- Popups
L["POPUP_EXPORT_TEXT"] = "Export scores (Ctrl+C to copy):"
L["POPUP_IMPORT_TEXT"] = "Paste the import string:"
L["POPUP_RESET_TEXT"] = "Reset all scores and history? This will be broadcast to everyone in the raid."

-- Permission / dialog / chat errors
L["ERR_RESET_PERM"] = "Reset is available only to the raid leader/assistant"
L["ERR_SYNC_PERM"] = "Only the leader/assistant can trigger a sync"
L["ERR_EDIT_PERM"] = "Only the leader/assistant can change scores"
L["MSG_NO_PERMISSION"] = "no permission (not leader/assistant)"
L["ERR_NO_DATA"] = "No data to display"
L["ERR_GENERIC"] = "Error: %s"
L["MSG_RESET_DONE"] = "All scores have been reset."
L["MSG_RESET_ERR"] = "Reset error: %s"
L["MSG_BROADCAST_FAILED"] = "Broadcast failed: %s"
L["ERR_ADD_USAGE"] = "Use plus or minus: /rpm add plus Name [value] [note]"

-- Sync/status text
L["SYNC_SENT"] = "Sent: %s"
L["SYNC_UPDATED"] = "Updated: %s"
L["SYNC_SYNCED"] = "Synced: %s"
L["SYNC_RESET_BY"] = "Reset (%s): %s"

-- Chat report
L["CHAT_REPORT_HEADER"] = "{skull}{skull}{skull}MINUSES{skull}{skull}{skull}"

-- Slash command output (status/help)
L["STATUS_HEADER"] = "status:"
L["STATUS_NAME"] = "Name: %s"
L["STATUS_GROUP"] = "In raid: %s (%d), in party: %s (%d)"
L["STATUS_LEADER"] = "UnitIsGroupLeader: %s"
L["STATUS_ASSISTANT"] = "UnitIsGroupAssistant: %s"
L["STATUS_ERROR_PREFIX"] = "ERROR: %s"
L["STATUS_RANK"] = "Rank from GetRaidRosterInfo: %s"
L["STATUS_RANK_LEGEND"] = "%s (0=member,1=assistant,2=leader)"
L["STATUS_CANEDIT"] = "CanEdit() result: %s"
L["HELP_HEADER"] = "commands:"
L["HELP_LINE_TOGGLE"] = "/rpm - open/close window"
L["HELP_LINE_CHAT"] = "/rpm chat - post minuses to chat"
L["HELP_LINE_ADD_PLUS"] = "/rpm add plus Name [value] [note]"
L["HELP_LINE_ADD_MINUS"] = "/rpm add minus Name [value] [note]"
L["HELP_LINE_DEFAULTS"] = "(value and note are optional, default value = 1)"
L["HELP_LINE_STATUS"] = "/rpm status - show what permissions the addon sees"
