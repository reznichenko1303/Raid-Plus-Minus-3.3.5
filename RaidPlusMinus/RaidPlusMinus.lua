local ADDON_NAME = "RaidPlusMinus"
local COMM_PREFIX = "RPM1"
local L = RaidPlusMinusLocale

------------------------------------------------------------
-- Forward declarations
------------------------------------------------------------
local ROW_HEIGHT = 20
local rows = {}

local BuildPlayerList
local GetRosterNames
local EnsurePlayer
local AddChange
local ApplyRemoteChange
local CanEdit
local IsOfficerName
local SerializeScores
local ImportScores
local GetRow
local SendComm
local BroadcastChange
local BroadcastFullSync
local BroadcastReset
local RequestSync
local OpenInputWindow
local FormatScore
local PostMinusesToChat
local RefreshRosterNameSet

local hasRequestedSync = false

------------------------------------------------------------
-- Main frame
------------------------------------------------------------
local frame = CreateFrame("Frame", "RaidPlusMinusFrame", UIParent)
frame:SetSize(300, 446)
frame:SetPoint("CENTER")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
frame:SetFrameStrata("HIGH")
frame:Hide()

tinsert(UISpecialFrames, "RaidPlusMinusFrame")

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -16)
title:SetText("Raid +/-")

local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -4, -4)

frame.syncStatus = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
frame.syncStatus:SetPoint("TOPLEFT", 20, -20)
frame.syncStatus:SetText("")

frame.emptyText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.emptyText:SetPoint("CENTER", 0, 20)
frame.emptyText:SetText(L["EMPTY_TEXT"])
frame.emptyText:Hide()

local headerName = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
headerName:SetPoint("TOPLEFT", 24, -64)
headerName:SetText(L["HEADER_PLAYER"])

local headerScore = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
headerScore:SetPoint("LEFT", headerName, "RIGHT", 122, 0)
headerScore:SetText(L["HEADER_SCORE"])

------------------------------------------------------------
-- Manual add by nickname (no need to be in a raid/see the player
-- in the list — useful if right-click/menu doesn't work)
------------------------------------------------------------
local addNameLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
addNameLabel:SetPoint("TOPLEFT", 24, -42)
addNameLabel:SetText(L["ADD_NAME_LABEL"])

local addNameBox = CreateFrame("EditBox", "RaidPlusMinusAddNameBox", frame, "InputBoxTemplate")
addNameBox:SetSize(110, 20)
addNameBox:SetPoint("LEFT", addNameLabel, "RIGHT", 8, 0)
addNameBox:SetAutoFocus(false)
addNameBox:SetMaxLetters(24)

local addPlusBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
addPlusBtn:SetSize(24, 20)
addPlusBtn:SetText("+")
addPlusBtn:SetPoint("LEFT", addNameBox, "RIGHT", 6, 0)

local addMinusBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
addMinusBtn:SetSize(24, 20)
addMinusBtn:SetText("-")
addMinusBtn:SetPoint("LEFT", addPlusBtn, "RIGHT", 4, 0)

local function ManualAddClick(sign)
    local name = strtrim(addNameBox:GetText() or "")
    if name == "" then
        UIErrorsFrame:AddMessage(L["ERR_ENTER_NAME"], 1, 0.2, 0.2)
        return
    end
    OpenInputWindow(name, sign)
end

addPlusBtn:SetScript("OnClick", function() ManualAddClick(1) end)
addMinusBtn:SetScript("OnClick", function() ManualAddClick(-1) end)
addNameBox:SetScript("OnEnterPressed", function() ManualAddClick(1) end)
addNameBox:SetScript("OnEscapePressed", function() addNameBox:ClearFocus() end)

local scrollFrame = CreateFrame("ScrollFrame", "RaidPlusMinusScrollFrame", frame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 16, -80)
scrollFrame:SetPoint("BOTTOMRIGHT", -30, 70)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetSize(1, 1)
scrollFrame:SetScrollChild(content)

local sortBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
sortBtn:SetSize(74, 20)
sortBtn:SetPoint("BOTTOMLEFT", 16, 40)
sortBtn:SetText(L["SORT_BY_SCORE"])
sortBtn:SetScript("OnClick", function(self)
    if RaidPlusMinusDB.sort == "score" then
        RaidPlusMinusDB.sort = "name"
        self:SetText(L["SORT_BY_NAME"])
    else
        RaidPlusMinusDB.sort = "score"
        self:SetText(L["SORT_BY_SCORE"])
    end
    BuildPlayerList()
end)

local resetBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
resetBtn:SetSize(52, 20)
resetBtn:SetPoint("LEFT", sortBtn, "RIGHT", 6, 0)
resetBtn:SetText(L["BTN_RESET"])
resetBtn:SetScript("OnClick", function()
    if not CanEdit() then
        UIErrorsFrame:AddMessage(L["ERR_RESET_PERM"], 1, 0.2, 0.2)
        return
    end
    StaticPopup_Show("RPM_RESET")
end)

local syncBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
syncBtn:SetSize(62, 20)
syncBtn:SetPoint("LEFT", resetBtn, "RIGHT", 6, 0)
syncBtn:SetText(L["BTN_SYNC"])
syncBtn:SetScript("OnClick", function()
    if not CanEdit() then
        UIErrorsFrame:AddMessage(L["ERR_SYNC_PERM"], 1, 0.2, 0.2)
        return
    end
    BroadcastFullSync()
    frame.syncStatus:SetText(L["SYNC_SENT"]:format(date("%H:%M")))
end)

local chatBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
chatBtn:SetSize(46, 20)
chatBtn:SetPoint("LEFT", syncBtn, "RIGHT", 6, 0)
chatBtn:SetText(L["BTN_CHAT"])
chatBtn:SetScript("OnClick", function()
    PostMinusesToChat()
end)

local exportBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
exportBtn:SetSize(70, 20)
exportBtn:SetPoint("BOTTOMLEFT", 16, 14)
exportBtn:SetText(L["BTN_EXPORT"])
exportBtn:SetScript("OnClick", function()
    StaticPopup_Show("RPM_EXPORT")
end)

local importBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
importBtn:SetSize(70, 20)
importBtn:SetPoint("LEFT", exportBtn, "RIGHT", 6, 0)
importBtn:SetText(L["BTN_IMPORT"])
importBtn:SetScript("OnClick", function()
    StaticPopup_Show("RPM_IMPORT")
end)

------------------------------------------------------------
-- Input window (used for both "add plus" and "add minus")
------------------------------------------------------------
local inputFrame = CreateFrame("Frame", "RaidPlusMinusInputFrame", UIParent)
inputFrame:SetSize(260, 160)
inputFrame:SetPoint("CENTER")
inputFrame:SetFrameStrata("DIALOG")
inputFrame:SetMovable(true)
inputFrame:EnableMouse(true)
inputFrame:RegisterForDrag("LeftButton")
inputFrame:SetScript("OnDragStart", inputFrame.StartMoving)
inputFrame:SetScript("OnDragStop", inputFrame.StopMovingOrSizing)
inputFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
inputFrame:Hide()
tinsert(UISpecialFrames, "RaidPlusMinusInputFrame")

inputFrame.title = inputFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
inputFrame.title:SetPoint("TOP", 0, -16)
inputFrame.title:SetText(L["ACTION_ADD_PLUS"])

inputFrame.playerLabel = inputFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
inputFrame.playerLabel:SetPoint("TOP", 0, -42)

local valueLabel = inputFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
valueLabel:SetPoint("TOPLEFT", 24, -70)
valueLabel:SetText(L["INPUT_VALUE_LABEL"])

inputFrame.valueBox = CreateFrame("EditBox", "RaidPlusMinusValueBox", inputFrame, "InputBoxTemplate")
inputFrame.valueBox:SetSize(50, 20)
inputFrame.valueBox:SetPoint("LEFT", valueLabel, "RIGHT", 10, 0)
inputFrame.valueBox:SetAutoFocus(false)
inputFrame.valueBox:SetNumeric(true)
inputFrame.valueBox:SetMaxLetters(4)

local noteLabel = inputFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
noteLabel:SetPoint("TOPLEFT", 24, -100)
noteLabel:SetText(L["INPUT_NOTE_LABEL"])

inputFrame.noteBox = CreateFrame("EditBox", "RaidPlusMinusNoteBox", inputFrame, "InputBoxTemplate")
inputFrame.noteBox:SetSize(160, 20)
inputFrame.noteBox:SetPoint("LEFT", noteLabel, "RIGHT", 10, 0)
inputFrame.noteBox:SetAutoFocus(false)
inputFrame.noteBox:SetMaxLetters(60)

local okBtn = CreateFrame("Button", nil, inputFrame, "UIPanelButtonTemplate")
okBtn:SetSize(70, 20)
okBtn:SetPoint("BOTTOMLEFT", 30, 14)
okBtn:SetText("OK")
okBtn:SetScript("OnClick", function()
    local amount = tonumber(inputFrame.valueBox:GetText())
    if not amount or amount <= 0 then
        UIErrorsFrame:AddMessage(L["ERR_VALUE_POSITIVE"], 1, 0.2, 0.2)
        return
    end
    amount = math.floor(amount + 0.5)
    local delta = inputFrame.sign * amount
    local targetName, note = inputFrame.targetName, inputFrame.noteBox:GetText()
    -- Close the window and refresh the list BEFORE broadcasting, so a
    -- broadcast failure (SendComm already protects itself with pcall,
    -- but just in case) can't interfere with the visible result.
    local ok, err = pcall(AddChange, targetName, delta, note)
    BuildPlayerList()
    inputFrame:Hide()
    if not ok then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff3333Raid +/-:|r " .. L["ERR_GENERIC"]:format(tostring(err)))
    end
end)

local cancelBtn = CreateFrame("Button", nil, inputFrame, "UIPanelButtonTemplate")
cancelBtn:SetSize(70, 20)
cancelBtn:SetPoint("BOTTOMRIGHT", -30, 14)
cancelBtn:SetText(L["BTN_CANCEL"])
cancelBtn:SetScript("OnClick", function() inputFrame:Hide() end)

CreateFrame("Button", nil, inputFrame, "UIPanelCloseButton"):SetPoint("TOPRIGHT", -4, -4)

inputFrame.valueBox:SetScript("OnEnterPressed", function() inputFrame.noteBox:SetFocus() end)
inputFrame.valueBox:SetScript("OnEscapePressed", function() inputFrame:Hide() end)
inputFrame.noteBox:SetScript("OnEnterPressed", function() okBtn:Click() end)
inputFrame.noteBox:SetScript("OnEscapePressed", function() inputFrame:Hide() end)

OpenInputWindow = function(name, sign)
    if not name or not CanEdit() then return end
    inputFrame.targetName = name
    inputFrame.sign = sign
    inputFrame.title:SetText(sign > 0 and L["ACTION_ADD_PLUS"] or L["ACTION_ADD_MINUS"])
    inputFrame.playerLabel:SetText(name)
    inputFrame.valueBox:SetText("1")
    inputFrame.noteBox:SetText("")
    inputFrame:Show()
    inputFrame.valueBox:SetFocus()
    inputFrame.valueBox:HighlightText()
end

------------------------------------------------------------
-- Other popups
------------------------------------------------------------
StaticPopupDialogs["RPM_EXPORT"] = {
    text = L["POPUP_EXPORT_TEXT"],
    button1 = CLOSE,
    hasEditBox = true,
    editBoxWidth = 350,
    OnShow = function(self)
        self.editBox:SetText(SerializeScores())
        self.editBox:HighlightText()
        self.editBox:SetFocus()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["RPM_IMPORT"] = {
    text = L["POPUP_IMPORT_TEXT"],
    button1 = L["BTN_IMPORT"],
    button2 = CANCEL,
    hasEditBox = true,
    editBoxWidth = 350,
    OnAccept = function(self)
        ImportScores(self.editBox:GetText())
        BuildPlayerList()
        if CanEdit() then BroadcastFullSync() end
    end,
    EditBoxOnEnterPressed = function(self)
        local dialog = self:GetParent()
        ImportScores(self:GetText())
        BuildPlayerList()
        if CanEdit() then BroadcastFullSync() end
        dialog:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["RPM_RESET"] = {
    text = L["POPUP_RESET_TEXT"],
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        local ok, err = pcall(function()
            if not CanEdit() then
                error(L["MSG_NO_PERMISSION"])
            end
            RaidPlusMinusDB.players = {}
            BuildPlayerList()
            BroadcastReset()
        end)
        if ok then
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff33Raid +/-:|r " .. L["MSG_RESET_DONE"])
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff3333Raid +/-:|r " .. L["MSG_RESET_ERR"]:format(tostring(err)))
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

------------------------------------------------------------
-- Data functions
------------------------------------------------------------
-- Bounds for anything that can be populated from untrusted input
-- (remote sync messages from other clients, or a pasted import string),
-- so a malformed/hostile payload can't grow RaidPlusMinusDB without
-- limit or corrupt numeric fields with absurd values.
local MAX_NAME_LEN = 24
local MAX_NOTE_LEN = 60
local MAX_SCORE = 9999
local MAX_DELTA = 999
local MAX_PLAYERS = 300
local MAX_HISTORY = 30

-- Only reject what's actually unsafe: not a string, empty, too long, or
-- containing the wire-format delimiters (":", ";") which would corrupt
-- the sync/export protocol. Deliberately not restricted to ASCII letters,
-- since character names can be Cyrillic on many servers.
local function IsValidPlayerName(name)
    if type(name) ~= "string" then return false end
    local len = #name
    if len == 0 or len > MAX_NAME_LEN then return false end
    if name:find("[:;]") then return false end
    return true
end

local function ClampNumber(n, limit)
    n = tonumber(n)
    if not n then return 0 end
    if n > limit then return limit end
    if n < -limit then return -limit end
    return n
end

local function CountPlayers()
    local count = 0
    for _ in pairs(RaidPlusMinusDB.players) do count = count + 1 end
    return count
end

EnsurePlayer = function(name)
    if not IsValidPlayerName(name) then return nil end
    if not RaidPlusMinusDB.players[name] then
        if CountPlayers() >= MAX_PLAYERS then return nil end
        RaidPlusMinusDB.players[name] = { score = 0, history = {} }
    end
    return RaidPlusMinusDB.players[name]
end

local function RecordHistory(p, delta, reason, author, changeTime)
    reason = (reason or ""):sub(1, MAX_NOTE_LEN)
    table.insert(p.history, { delta = delta, reason = reason, time = changeTime, author = author })
    if #p.history > MAX_HISTORY then
        table.remove(p.history, 1)
    end
    return reason
end

AddChange = function(name, delta, reason)
    if not name or type(delta) ~= "number" then return end
    delta = ClampNumber(delta, MAX_DELTA)
    local p = EnsurePlayer(name)
    if not p then return end
    reason = (reason or ""):gsub("[:;]", " ")
    p.score = ClampNumber(p.score + delta, MAX_SCORE)
    local author = UnitName("player")
    local changeTime = time()
    reason = RecordHistory(p, delta, reason, author, changeTime)
    BroadcastChange(name, delta, reason, author, changeTime)
end

ApplyRemoteChange = function(name, delta, reason, author, changeTime)
    if not name or not delta then return end
    local p = EnsurePlayer(name)
    if not p then return end
    delta = ClampNumber(delta, MAX_DELTA)
    p.score = ClampNumber(p.score + delta, MAX_SCORE)
    RecordHistory(p, delta, reason, author, tonumber(changeTime) or time())
    if frame:IsShown() then BuildPlayerList() end
end

-- UnitIsGroupLeader/UnitIsGroupAssistant can throw an error on some
-- modified servers — wrap in pcall so it never breaks CanEdit()/
-- IsOfficerName() or anything that depends on them.
local function SafeUnitIsGroupLeader(unit)
    local ok, result = pcall(UnitIsGroupLeader, unit)
    if ok then return result end
    return false
end

local function SafeUnitIsGroupAssistant(unit)
    local ok, result = pcall(UnitIsGroupAssistant, unit)
    if ok then return result end
    return false
end

CanEdit = function()
    if GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0 then
        return true
    end
    -- Primary, reliable path — the raw rank field from GetRaidRosterInfo.
    if IsOfficerName(UnitName("player")) then
        return true
    end
    -- Fallback path for a party (not raid), where there's no rank.
    return SafeUnitIsGroupLeader("player") or SafeUnitIsGroupAssistant("player")
end

IsOfficerName = function(name)
    local numRaid = GetNumRaidMembers()
    if numRaid > 0 then
        for i = 1, numRaid do
            local n, rank = GetRaidRosterInfo(i)
            if n == name then
                return rank and rank >= 1
            end
        end
        return false
    end
    if name == UnitName("player") then
        return SafeUnitIsGroupLeader("player") or GetNumPartyMembers() == 0
    end
    for i = 1, GetNumPartyMembers() do
        local unit = "party" .. i
        if UnitExists(unit) and UnitName(unit) == name then
            return SafeUnitIsGroupLeader(unit)
        end
    end
    return false
end

GetRosterNames = function()
    local list = {}
    local numRaid = GetNumRaidMembers()
    if numRaid > 0 then
        for i = 1, numRaid do
            local name, _, _, _, _, fileName = GetRaidRosterInfo(i)
            if name then
                table.insert(list, { name = name, class = fileName })
            end
        end
    else
        local playerName = UnitName("player")
        local _, playerClass = UnitClass("player")
        table.insert(list, { name = playerName, class = playerClass })
        local numParty = GetNumPartyMembers()
        for i = 1, numParty do
            local unit = "party" .. i
            if UnitExists(unit) then
                local name = UnitName(unit)
                local _, class = UnitClass(unit)
                if name then
                    table.insert(list, { name = name, class = class })
                end
            end
        end
    end
    return list
end

SerializeScores = function()
    local parts = {}
    for name, data in pairs(RaidPlusMinusDB.players) do
        table.insert(parts, name .. ":" .. data.score)
    end
    table.sort(parts)
    return table.concat(parts, ";")
end

ImportScores = function(str)
    if not str then return end
    for entry in string.gmatch(str, "([^;]+)") do
        local name, score = string.match(entry, "^%s*([^:]+):(-?%d+)%s*$")
        if name and score then
            local p = EnsurePlayer(name)
            if p then
                p.score = ClampNumber(score, MAX_SCORE)
            end
        end
    end
end

FormatScore = function(score)
    if score > 0 then
        return "+" .. score
    elseif score < 0 then
        return tostring(score)
    else
        return "0"
    end
end

------------------------------------------------------------
-- Communication (sync)
------------------------------------------------------------
if RegisterAddonMessagePrefix then
    RegisterAddonMessagePrefix(COMM_PREFIX)
end

local function GetCommChannel()
    if GetNumRaidMembers() > 0 then
        return "RAID"
    elseif GetNumPartyMembers() > 0 then
        return "PARTY"
    end
    return nil
end

SendComm = function(msg)
    local channel = GetCommChannel()
    if not channel then return end
    -- Wrapped in pcall: if SendAddonMessage errors for some reason
    -- (e.g. on a cross-faction server), it shouldn't break the rest of
    -- the local logic (reset, adding scores, etc.) that runs after the broadcast.
    local ok, err = pcall(SendAddonMessage, COMM_PREFIX, msg, channel)
    if not ok then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff3333Raid +/-:|r " .. L["MSG_BROADCAST_FAILED"]:format(tostring(err)))
    end
end

BroadcastChange = function(name, delta, reason, author, changeTime)
    SendComm(string.format("C:%s:%d:%s:%s:%d", name, delta, reason, author, changeTime))
end

BroadcastReset = function()
    SendComm("R")
end

BroadcastFullSync = function()
    local names = {}
    for name in pairs(RaidPlusMinusDB.players) do table.insert(names, name) end
    table.sort(names)

    local CHUNK = 10
    local chunk = {}
    for _, name in ipairs(names) do
        table.insert(chunk, name .. ":" .. RaidPlusMinusDB.players[name].score)
        if #chunk >= CHUNK then
            SendComm("F:" .. table.concat(chunk, ";"))
            chunk = {}
        end
    end
    if #chunk > 0 then
        SendComm("F:" .. table.concat(chunk, ";"))
    end
end

RequestSync = function()
    SendComm("RQ")
end

------------------------------------------------------------
-- Chat report
------------------------------------------------------------
PostMinusesToChat = function()
    local channel = GetCommChannel()

    local names = {}
    for name, data in pairs(RaidPlusMinusDB.players) do
        if data.history and #data.history > 0 then
            table.insert(names, name)
        end
    end

    if #names == 0 then
        UIErrorsFrame:AddMessage(L["ERR_NO_DATA"], 1, 0.5, 0)
        return
    end

    table.sort(names, function(a, b)
        local sa = RaidPlusMinusDB.players[a].score
        local sb = RaidPlusMinusDB.players[b].score
        if sa == sb then return a < b end
        return sa > sb -- descending, highest first
    end)

    local function SendLine(text)
        if channel then
            SendChatMessage(text, channel)
        else
            -- SendChatMessage goes through the standard CHAT_MSG_* handler,
            -- which auto-converts {skull} etc. into raid-icon textures.
            -- AddMessage bypasses that pipeline, so do the same replacement
            -- ourselves for the "not in a group" fallback case.
            if ChatFrame_ReplaceIconAndGroupExpressions then
                text = ChatFrame_ReplaceIconAndGroupExpressions(text)
            end
            DEFAULT_CHAT_FRAME:AddMessage(text)
        end
    end

    SendLine(L["CHAT_REPORT_HEADER"])
    for _, name in ipairs(names) do
        local p = RaidPlusMinusDB.players[name]
        local line = name .. " - " .. FormatScore(p.score)

        local notes = {}
        for _, h in ipairs(p.history) do
            if h.reason and h.reason ~= "" then
                table.insert(notes, h.reason)
            end
        end
        if #notes > 0 then
            line = line .. " (" .. table.concat(notes, ", ") .. ")"
        end

        SendLine(line)
    end
end

------------------------------------------------------------
-- Row-level right-click menu (works regardless of the default
-- game raid frame / cross-faction quirks — fully self-contained)
------------------------------------------------------------
local rowDropDown = CreateFrame("Frame", "RaidPlusMinusRowDropDown", UIParent, "UIDropDownMenuTemplate")

local function AddPlusMinusMenuButtons(level, uName)
    local infoPlus = UIDropDownMenu_CreateInfo()
    infoPlus.text = L["ACTION_ADD_PLUS"]
    infoPlus.notCheckable = true
    infoPlus.func = function() OpenInputWindow(uName, 1) end
    UIDropDownMenu_AddButton(infoPlus, level)

    local infoMinus = UIDropDownMenu_CreateInfo()
    infoMinus.text = L["ACTION_ADD_MINUS"]
    infoMinus.notCheckable = true
    infoMinus.func = function() OpenInputWindow(uName, -1) end
    UIDropDownMenu_AddButton(infoMinus, level)
end

local function RowDropDown_Initialize(self, level)
    local uName = rowDropDown.targetName
    if not uName then return end
    AddPlusMinusMenuButtons(level, uName)
end
UIDropDownMenu_Initialize(rowDropDown, RowDropDown_Initialize, "MENU")

------------------------------------------------------------
-- Rows / UI list
------------------------------------------------------------
GetRow = function(i)
    if rows[i] then return rows[i] end

    local row = CreateFrame("Frame", nil, content)
    row:SetSize(250, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.name:SetPoint("LEFT", 4, 0)
    row.name:SetWidth(120)
    row.name:SetJustifyH("LEFT")

    row.score = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.score:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
    row.score:SetWidth(34)
    row.score:SetJustifyH("CENTER")

    row.minus = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.minus:SetSize(20, 18)
    row.minus:SetText("-")
    row.minus:SetPoint("LEFT", row.score, "RIGHT", 6, 0)

    row.plus = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.plus:SetSize(20, 18)
    row.plus:SetText("+")
    row.plus:SetPoint("LEFT", row.minus, "RIGHT", 4, 0)

    row.nameBtn = CreateFrame("Button", nil, row)
    row.nameBtn:SetAllPoints(row.name)
    row.nameBtn:SetScript("OnEnter", function(self)
        local pname = row.playerName
        if not pname then return end
        local p = RaidPlusMinusDB.players[pname]
        local score = p and p.score or 0

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if score > 0 then
            GameTooltip:AddLine(pname .. " - " .. FormatScore(score), 0.3, 1, 0.3)
        elseif score < 0 then
            GameTooltip:AddLine(pname .. " - " .. FormatScore(score), 1, 0.35, 0.35)
        else
            GameTooltip:AddLine(pname .. " - " .. FormatScore(score), 1, 1, 1)
        end

        if p and #p.history > 0 then
            local notes = {}
            for _, h in ipairs(p.history) do
                if h.reason and h.reason ~= "" then
                    table.insert(notes, h.reason)
                end
            end
            if #notes > 0 then
                GameTooltip:AddLine("(" .. table.concat(notes, ", ") .. ")", 0.9, 0.9, 0.6, true)
            end
        else
            GameTooltip:AddLine(L["TOOLTIP_NO_NOTES"], 0.6, 0.6, 0.6)
        end
        GameTooltip:Show()
    end)
    row.nameBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.nameBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.nameBtn:SetScript("OnClick", function(self, button)
        if button ~= "RightButton" then return end
        local name = row.playerName
        if not name or not CanEdit() then return end
        rowDropDown.targetName = name
        ToggleDropDownMenu(1, nil, rowDropDown, "cursor", 0, 0)
    end)

    row.minus:SetScript("OnClick", function()
        local name = row.playerName
        if not name or not CanEdit() then return end
        if IsShiftKeyDown() then
            OpenInputWindow(name, -1)
        else
            AddChange(name, -1)
            BuildPlayerList()
        end
    end)

    row.plus:SetScript("OnClick", function()
        local name = row.playerName
        if not name or not CanEdit() then return end
        if IsShiftKeyDown() then
            OpenInputWindow(name, 1)
        else
            AddChange(name, 1)
            BuildPlayerList()
        end
    end)

    rows[i] = row
    return row
end

BuildPlayerList = function()
    local roster = GetRosterNames()
    RefreshRosterNameSet(roster)
    local canEdit = CanEdit()

    local names = {}
    local classMap = {}
    for _, entry in ipairs(roster) do
        EnsurePlayer(entry.name)
        table.insert(names, entry.name)
        classMap[entry.name] = entry.class
    end

    if RaidPlusMinusDB.sort == "score" then
        table.sort(names, function(a, b)
            local sa = RaidPlusMinusDB.players[a] and RaidPlusMinusDB.players[a].score or 0
            local sb = RaidPlusMinusDB.players[b] and RaidPlusMinusDB.players[b].score or 0
            if sa == sb then return a < b end
            return sa > sb -- descending, highest first
        end)
    else
        table.sort(names)
    end

    for i, name in ipairs(names) do
        local row = GetRow(i)
        row.playerName = name

        local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classMap[name]]
        if classColor then
            row.name:SetTextColor(classColor.r, classColor.g, classColor.b)
        else
            row.name:SetTextColor(1, 1, 1)
        end
        row.name:SetText(name)

        local score = RaidPlusMinusDB.players[name] and RaidPlusMinusDB.players[name].score or 0
        row.score:SetText(FormatScore(score))
        if score > 0 then
            row.score:SetTextColor(0.3, 1, 0.3)
        elseif score < 0 then
            row.score:SetTextColor(1, 0.35, 0.35)
        else
            row.score:SetTextColor(1, 1, 1)
        end

        if canEdit then
            row.minus:Enable()
            row.plus:Enable()
        else
            row.minus:Disable()
            row.plus:Disable()
        end
        row:Show()
    end

    for i = #names + 1, #rows do
        rows[i]:Hide()
    end

    content:SetHeight(math.max(1, #names * ROW_HEIGHT))

    if #roster == 0 then
        frame.emptyText:Show()
    else
        frame.emptyText:Hide()
    end
end

------------------------------------------------------------
-- Right-click unit context menu integration
-- (standard Blizzard raid frame + a fallback path for
--  ElvUI / oUF-based frames that open the menu differently)
------------------------------------------------------------
-- Cached as a set (name -> true) and refreshed only on actual roster-change
-- events, instead of rescanning the whole raid on every dropdown menu opened
-- anywhere in the UI (see the ToggleDropDownMenu hook below, which is global).
local rosterNameSet = {}

RefreshRosterNameSet = function(roster)
    for k in pairs(rosterNameSet) do
        rosterNameSet[k] = nil
    end
    roster = roster or GetRosterNames()
    for _, entry in ipairs(roster) do
        rosterNameSet[entry.name] = true
    end
end

local function IsTrackedRosterName(uName)
    return uName ~= nil and rosterNameSet[uName] == true
end

-- Guard against adding the buttons twice if the same click goes through
-- both hooked paths at once (e.g. ElvUI internally also calls the
-- standard UnitPopup_ShowMenu).
local lastMenuName, lastMenuTime = nil, 0

local function TryInjectButtons(level, uName)
    if not uName or uName == "" then return end
    if not CanEdit() then return end
    if not IsTrackedRosterName(uName) then return end

    local now = GetTime()
    if lastMenuName == uName and (now - lastMenuTime) < 0.2 then
        return
    end
    lastMenuName, lastMenuTime = uName, now

    AddPlusMinusMenuButtons(level, uName)
end

-- Path 1: standard Blizzard menu (RAID_PLAYER/PARTY, etc.)
local function AddCustomMenuButtons(dropdownMenu, which, unit, name, userData)
    local uName = name
    if (not uName or uName == "") and unit then
        uName = UnitName(unit)
    end
    TryInjectButtons(UIDROPDOWNMENU_MENU_LEVEL or 1, uName)
end

if UnitPopup_ShowMenu then
    hooksecurefunc("UnitPopup_ShowMenu", AddCustomMenuButtons)
end

-- Path 2: a fallback, more generic hook — many oUF-based frameworks
-- (including ElvUI ports for 3.3.5) open the unit menu via
-- ToggleDropDownMenu, passing a dropdown frame with .unit or .name
-- fields (like the standard FriendsDropDown). This path catches those
-- cases even if UnitPopup_ShowMenu isn't called directly.
if ToggleDropDownMenu then
    hooksecurefunc("ToggleDropDownMenu", function(level, value, dropdownFrame)
        local ddFrame = dropdownFrame
        if type(ddFrame) == "string" then
            ddFrame = _G[ddFrame]
        end
        if type(ddFrame) ~= "table" then return end

        local uName = ddFrame.name
        if (not uName or uName == "") and ddFrame.unit and UnitExists(ddFrame.unit) then
            uName = UnitName(ddFrame.unit)
        end
        if not uName then return end

        TryInjectButtons(level or UIDROPDOWNMENU_MENU_LEVEL or 1, uName)
    end)
end

------------------------------------------------------------
-- Events
------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName ~= ADDON_NAME then return end
        if type(RaidPlusMinusDB) ~= "table" then
            RaidPlusMinusDB = {}
        end
        if type(RaidPlusMinusDB.players) ~= "table" then
            RaidPlusMinusDB.players = {}
        end
        if not RaidPlusMinusDB.sort then
            RaidPlusMinusDB.sort = "score"
        end
        sortBtn:SetText(RaidPlusMinusDB.sort == "score" and L["SORT_BY_SCORE"] or L["SORT_BY_NAME"])
        RefreshRosterNameSet()

    elseif event == "CHAT_MSG_ADDON" then
        local prefix, msg, channel, sender = ...
        if prefix ~= COMM_PREFIX then return end
        sender = string.match(sender, "^[^%-]+") or sender
        if sender == UnitName("player") then return end

        local msgType, rest = string.match(msg, "^(%a+):?(.*)$")
        if not msgType then return end

        if msgType == "C" then
            local name, delta, reason, author, changeTime =
                string.match(rest, "^([^:]+):(-?%d+):([^:]*):([^:]+):(%d+)$")
            if name and delta and IsOfficerName(sender) then
                ApplyRemoteChange(name, tonumber(delta), reason, author, tonumber(changeTime))
                if frame:IsShown() then frame.syncStatus:SetText(L["SYNC_UPDATED"]:format(date("%H:%M"))) end
            end
        elseif msgType == "F" then
            if IsOfficerName(sender) then
                for entry in string.gmatch(rest, "([^;]+)") do
                    local name, score = string.match(entry, "^([^:]+):(-?%d+)$")
                    if name and score then
                        local p = EnsurePlayer(name)
                        if p then
                            p.score = ClampNumber(score, MAX_SCORE)
                        end
                    end
                end
                if frame:IsShown() then BuildPlayerList() end
                frame.syncStatus:SetText(L["SYNC_SYNCED"]:format(date("%H:%M")))
            end
        elseif msgType == "R" then
            if IsOfficerName(sender) then
                RaidPlusMinusDB.players = {}
                if frame:IsShown() then BuildPlayerList() end
                frame.syncStatus:SetText(L["SYNC_RESET_BY"]:format(sender, date("%H:%M")))
            end
        elseif msgType == "RQ" then
            if IsOfficerName(UnitName("player")) then
                BroadcastFullSync()
            end
        end

    else
        local inGroup = (GetNumRaidMembers() > 0) or (GetNumPartyMembers() > 0)
        if inGroup and not hasRequestedSync then
            hasRequestedSync = true
            RequestSync()
        elseif not inGroup then
            hasRequestedSync = false
        end
        if frame:IsShown() then
            BuildPlayerList()
        else
            -- BuildPlayerList() also refreshes the roster cache, but skip
            -- the full rebuild (rows, colors, sort) when the window is hidden.
            RefreshRosterNameSet()
        end
    end
end)

------------------------------------------------------------
-- Slash commands
------------------------------------------------------------
SLASH_RAIDPLUSMINUS1 = "/rpm"
SLASH_RAIDPLUSMINUS2 = "/плюсы"
SlashCmdList["RAIDPLUSMINUS"] = function(msg)
    msg = strtrim(msg or "")
    local lowerMsg = msg:lower()

    if lowerMsg == "chat" or lowerMsg == "чат" or lowerMsg == "минус" or lowerMsg == "минусы" then
        PostMinusesToChat()
        return
    end

    -- /rpm add plus Nick [value] [note...]
    -- /rpm add minus Nick [value] [note...]
    -- value and note are optional: 1 is used if no value is given;
    -- if what follows the name isn't a number, the whole rest is treated as the note
    local cmd, signWord, name, rest =
        string.match(msg, "^(%a+)%s+(%S+)%s+(%S+)%s*(.*)$")

    if cmd and cmd:lower() == "add" then
        local sw = signWord:lower()
        local sign
        if sw == "plus" or sw == "+" or sw == "плюс" then
            sign = 1
        elseif sw == "minus" or sw == "-" or sw == "минус" then
            sign = -1
        end

        if not sign then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff3333Raid +/-:|r " .. L["ERR_ADD_USAGE"])
            return
        end

        if not CanEdit() then
            UIErrorsFrame:AddMessage(L["ERR_EDIT_PERM"], 1, 0.2, 0.2)
            return
        end

        rest = strtrim(rest or "")
        local valueStr, afterValue = string.match(rest, "^(%-?%d+%.?%d*)%s*(.*)$")

        local amount, note
        if valueStr then
            amount = tonumber(valueStr)
            note = afterValue or ""
        else
            amount = 1
            note = rest
        end

        if not amount or amount == 0 then
            amount = 1
        end
        amount = math.floor(math.abs(amount) + 0.5)
        local delta = sign * amount
        note = strtrim(note or "")

        local ok, err = pcall(AddChange, name, delta, note)
        BuildPlayerList()
        if ok then
            local noteSuffix = (note ~= "" and (" (" .. note .. ")") or "")
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff33Raid +/-:|r " .. name .. " " .. FormatScore(delta) .. noteSuffix)
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff3333Raid +/-:|r " .. L["ERR_GENERIC"]:format(tostring(err)))
        end
        return
    end

    if lowerMsg == "status" or lowerMsg == "статус" then
        local myName = UnitName("player")
        local numRaid = GetNumRaidMembers()
        local numParty = GetNumPartyMembers()
        local rosterRank = "-"
        if numRaid > 0 then
            for i = 1, numRaid do
                local n, rank = GetRaidRosterInfo(i)
                if n == myName then
                    rosterRank = L["STATUS_RANK_LEGEND"]:format(tostring(rank))
                end
            end
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Raid +/-|r " .. L["STATUS_HEADER"])
        DEFAULT_CHAT_FRAME:AddMessage(L["STATUS_NAME"]:format(tostring(myName)))
        DEFAULT_CHAT_FRAME:AddMessage(L["STATUS_GROUP"]:format(tostring(numRaid > 0), numRaid, tostring(numParty > 0), numParty))
        local leaderOk, leaderVal = pcall(UnitIsGroupLeader, "player")
        local assistOk, assistVal = pcall(UnitIsGroupAssistant, "player")
        DEFAULT_CHAT_FRAME:AddMessage(L["STATUS_LEADER"]:format(leaderOk and tostring(leaderVal) or L["STATUS_ERROR_PREFIX"]:format(tostring(leaderVal))))
        DEFAULT_CHAT_FRAME:AddMessage(L["STATUS_ASSISTANT"]:format(assistOk and tostring(assistVal) or L["STATUS_ERROR_PREFIX"]:format(tostring(assistVal))))
        DEFAULT_CHAT_FRAME:AddMessage(L["STATUS_RANK"]:format(rosterRank))
        DEFAULT_CHAT_FRAME:AddMessage(L["STATUS_CANEDIT"]:format(tostring(CanEdit())))
        return
    end

    if lowerMsg == "help" or lowerMsg == "помощь" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Raid +/-|r " .. L["HELP_HEADER"])
        DEFAULT_CHAT_FRAME:AddMessage(L["HELP_LINE_TOGGLE"])
        DEFAULT_CHAT_FRAME:AddMessage(L["HELP_LINE_CHAT"])
        DEFAULT_CHAT_FRAME:AddMessage(L["HELP_LINE_ADD_PLUS"])
        DEFAULT_CHAT_FRAME:AddMessage(L["HELP_LINE_ADD_MINUS"])
        DEFAULT_CHAT_FRAME:AddMessage(L["HELP_LINE_DEFAULTS"])
        DEFAULT_CHAT_FRAME:AddMessage(L["HELP_LINE_STATUS"])
        return
    end

    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        BuildPlayerList()
    end
end
