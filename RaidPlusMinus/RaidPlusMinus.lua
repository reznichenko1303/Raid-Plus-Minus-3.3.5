local ADDON_NAME = "RaidPlusMinus"
local COMM_PREFIX = "RPM1"
local L = RaidPlusMinusLocale

------------------------------------------------------------
-- Forward declarations
------------------------------------------------------------
local ROW_HEIGHT = 20
local HISTORY_MINI_LIMIT = 5
local HISTORY_LINE_HEIGHT = 14
local TAB_BAR_HEIGHT = 24
local TITLE_GAP = 10   -- extra breathing room below the addon title
local TABS_GAP = 8     -- extra breathing room below the Players/History tabs
local rows = {}
local expandedPlayers = {}

local BuildPlayerList
local BuildHistoryList
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
local RefreshWindow
local SetActiveTab
local ToggleMainWindow
local UpdateMinimapButtonPosition

local hasRequestedSync = false

------------------------------------------------------------
-- Main frame
------------------------------------------------------------
local frame = CreateFrame("Frame", "RaidPlusMinusFrame", UIParent)
frame:SetSize(300, 446 + TAB_BAR_HEIGHT + TITLE_GAP + TABS_GAP)
frame:SetPoint("CENTER")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:SetBackdrop({
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true,
  tileSize = 32,
  edgeSize = 32,
  insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
frame:SetFrameStrata("HIGH")
frame:Hide()

tinsert(UISpecialFrames, "RaidPlusMinusFrame")

------------------------------------------------------------
-- Minimap button
------------------------------------------------------------
local minimapButton = CreateFrame("Button", "RaidPlusMinusMinimapButton", Minimap)
minimapButton:SetSize(31, 31)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetFrameLevel(8)
minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local minimapButtonIcon = minimapButton:CreateTexture(nil, "BACKGROUND")
minimapButtonIcon:SetTexture("Interface\\AddOns\\RaidPlusMinus\\Media\\raid_plus_minus")
minimapButtonIcon:SetSize(20, 20)
minimapButtonIcon:SetPoint("CENTER", 0, 0)
minimapButtonIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

local minimapButtonBorder = minimapButton:CreateTexture(nil, "OVERLAY")
minimapButtonBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
minimapButtonBorder:SetSize(54, 54)
minimapButtonBorder:SetPoint("TOPLEFT", 0, 0)

function UpdateMinimapButtonPosition()
  local angle = math.rad(RaidPlusMinusDB.minimap and RaidPlusMinusDB.minimap.angle or 200)
  local radius = 80
  minimapButton:ClearAllPoints()
  minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

minimapButton:RegisterForDrag("LeftButton")
minimapButton:RegisterForClicks("LeftButtonUp")

minimapButton:SetScript("OnDragStart", function(self)
  self:SetScript("OnUpdate", function(self)
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    px, py = px / scale, py / scale
    local angle = math.deg(math.atan2(py - my, px - mx))
    RaidPlusMinusDB.minimap.angle = angle
    UpdateMinimapButtonPosition()
  end)
end)

minimapButton:SetScript("OnDragStop", function(self)
  self:SetScript("OnUpdate", nil)
end)

minimapButton:SetScript("OnClick", function()
  ToggleMainWindow()
end)

minimapButton:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:AddLine("Raid +/-")
  GameTooltip:AddLine(L["MINIMAP_TOOLTIP_OPEN"] or "Left-click to open", 1, 1, 1)
  GameTooltip:AddLine(L["MINIMAP_TOOLTIP_MOVE"] or "Drag to move", 1, 1, 1)
  GameTooltip:Show()
end)

minimapButton:SetScript("OnLeave", function()
  GameTooltip:Hide()
end)

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -14)
title:SetText("Raid +/-")

local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -4, -4)

frame.syncStatus = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
frame.syncStatus:SetPoint("TOPLEFT", 20, -20)
frame.syncStatus:SetText("")

local tabPlayersBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
tabPlayersBtn:SetSize(90, 20)
tabPlayersBtn:SetPoint("TOPLEFT", 16, -20 - TAB_BAR_HEIGHT - TITLE_GAP)
tabPlayersBtn:SetText(L["TAB_PLAYERS"])

local tabHistoryBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
tabHistoryBtn:SetSize(90, 20)
tabHistoryBtn:SetPoint("LEFT", tabPlayersBtn, "RIGHT", 4, 0)
tabHistoryBtn:SetText(L["TAB_HISTORY"])

tabPlayersBtn:SetScript("OnClick", function() SetActiveTab("players") end)
tabHistoryBtn:SetScript("OnClick", function() SetActiveTab("history") end)

frame.emptyText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.emptyText:SetPoint("CENTER", 0, 20)
frame.emptyText:SetText(L["EMPTY_TEXT"])
frame.emptyText:Hide()

local headerName = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
headerName:SetPoint("TOPLEFT", 24, -64 - TAB_BAR_HEIGHT - TITLE_GAP - TABS_GAP)
headerName:SetText(L["HEADER_PLAYER"])

local headerScore = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
headerScore:SetPoint("LEFT", headerName, "RIGHT", 122, 0)
headerScore:SetText(L["HEADER_SCORE"])

------------------------------------------------------------
-- Manual add by nickname (no need to be in a raid/see the player
-- in the list — useful if right-click/menu doesn't work)
------------------------------------------------------------
local addNameLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
addNameLabel:SetPoint("TOPLEFT", 24, -42 - TAB_BAR_HEIGHT - TITLE_GAP - TABS_GAP)
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
scrollFrame:SetPoint("TOPLEFT", 16, -80 - TAB_BAR_HEIGHT - TITLE_GAP - TABS_GAP)
scrollFrame:SetPoint("BOTTOMRIGHT", -30, 70)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetSize(1, 1)
scrollFrame:SetScrollChild(content)

------------------------------------------------------------
-- History tab (global feed of who did what, when — separate
-- from the per-row "mini history" expand on the Players tab)
------------------------------------------------------------
local historyScrollFrame = CreateFrame("ScrollFrame", "RaidPlusMinusHistoryScrollFrame", frame,
  "UIPanelScrollFrameTemplate")
historyScrollFrame:SetPoint("TOPLEFT", 16, -80 - TAB_BAR_HEIGHT - TITLE_GAP - TABS_GAP)
historyScrollFrame:SetPoint("BOTTOMRIGHT", -30, 70)
historyScrollFrame:Hide()

local historyContent = CreateFrame("Frame", nil, historyScrollFrame)
historyContent:SetSize(1, 1)
historyScrollFrame:SetScrollChild(historyContent)

local historyEmptyText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
historyEmptyText:SetPoint("CENTER", 0, 20)
historyEmptyText:SetText(L["HISTORY_EMPTY"])
historyEmptyText:Hide()

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

-- Widgets that only make sense on the Players tab — hidden while History
-- tab is active (frame.emptyText / historyEmptyText are toggled separately).
local playersTabWidgets = {
  headerName, headerScore, addNameLabel, addNameBox, addPlusBtn, addMinusBtn,
  scrollFrame, sortBtn, resetBtn, syncBtn, chatBtn, exportBtn, importBtn,
}

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
  tile = true,
  tileSize = 32,
  edgeSize = 32,
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
  RefreshWindow()
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
    RefreshWindow()
    if CanEdit() then BroadcastFullSync() end
  end,
  EditBoxOnEnterPressed = function(self)
    local dialog = self:GetParent()
    ImportScores(self:GetText())
    RefreshWindow()
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
      RaidPlusMinusDB.globalLog = {}
      RefreshWindow()
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
local GLOBAL_LOG_LIMIT = 200

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

-- Appends to both the per-player history (capped at MAX_HISTORY, used by
-- the row tooltip/mini-history) and a single shared, already-newest-first
-- log (capped at GLOBAL_LOG_LIMIT, used by the History tab) so the tab
-- doesn't need to re-scan and sort every player's history on every render.
local function RecordHistory(name, p, delta, reason, author, changeTime)
  reason = (reason or ""):sub(1, MAX_NOTE_LEN)
  table.insert(p.history, { delta = delta, reason = reason, time = changeTime, author = author })
  if #p.history > MAX_HISTORY then
    table.remove(p.history, 1)
  end

  if type(RaidPlusMinusDB.globalLog) ~= "table" then
    RaidPlusMinusDB.globalLog = {}
  end
  table.insert(RaidPlusMinusDB.globalLog, 1,
    { name = name, delta = delta, reason = reason, time = changeTime, author = author })
  if #RaidPlusMinusDB.globalLog > GLOBAL_LOG_LIMIT then
    table.remove(RaidPlusMinusDB.globalLog)
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
  reason = RecordHistory(name, p, delta, reason, author, changeTime)
  BroadcastChange(name, delta, reason, author, changeTime)
end

ApplyRemoteChange = function(name, delta, reason, author, changeTime)
  if not name or not delta then return end
  local p = EnsurePlayer(name)
  if not p then return end
  delta = ClampNumber(delta, MAX_DELTA)
  p.score = ClampNumber(p.score + delta, MAX_SCORE)
  RecordHistory(name, p, delta, reason, author, tonumber(changeTime) or time())
  RefreshWindow()
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

-- Wrapped in pcall: GetNumRaidMembers/GetRaidRosterInfo have been observed
-- to throw on some modified/private servers, and a raw error here would
-- otherwise break every other addon's raid-frame right-click menu too
-- (see the ToggleDropDownMenu/UnitPopup_ShowMenu hooks below).
CanEdit = function()
  local ok, result = pcall(function()
    local numRaid = GetNumRaidMembers() or 0
    local numParty = GetNumPartyMembers() or 0
    if numRaid == 0 and numParty == 0 then
      return true
    end
    -- Primary, reliable path — the raw rank field from GetRaidRosterInfo.
    local myName = UnitName("player")
    if myName and IsOfficerName(myName) then
      return true
    end
    -- Fallback path for a party (not raid), where there's no rank.
    return SafeUnitIsGroupLeader("player") or SafeUnitIsGroupAssistant("player")
  end)
  if ok then return result end
  return false
end

IsOfficerName = function(name)
  if not name or name == "" then return false end
  local ok, result = pcall(function()
    local numRaid = GetNumRaidMembers() or 0
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
      return SafeUnitIsGroupLeader("player") or (GetNumPartyMembers() or 0) == 0
    end
    local numParty = GetNumPartyMembers() or 0
    for i = 1, numParty do
      local unit = "party" .. i
      if UnitExists(unit) and UnitName(unit) == name then
        return SafeUnitIsGroupLeader(unit)
      end
    end
    return false
  end)
  if ok then return result end
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
-- SendChatMessage calls fired back-to-back in a tight loop get silently
-- throttled/dropped by the server once a raid has more than a handful of
-- scored players, so lines are queued here and drained one at a time on
-- a short timer instead of all at once.
local chatQueue = {}
local CHAT_SEND_INTERVAL = 0.3
local chatQueueElapsed = 0
local chatQueueFrame = CreateFrame("Frame")
chatQueueFrame:Hide()
chatQueueFrame:SetScript("OnUpdate", function(self, elapsed)
  chatQueueElapsed = chatQueueElapsed + elapsed
  if chatQueueElapsed < CHAT_SEND_INTERVAL then return end
  chatQueueElapsed = 0

  local item = table.remove(chatQueue, 1)
  if not item then
    self:Hide()
    return
  end
  if item.channel then
    SendChatMessage(item.text, item.channel)
  else
    DEFAULT_CHAT_FRAME:AddMessage(item.text)
  end
end)

local function QueueChatLine(text, channel)
  table.insert(chatQueue, { text = text, channel = channel })
  chatQueueFrame:Show()
end

PostMinusesToChat = function()
  local channel = GetCommChannel()

  local names = {}
  for name, data in pairs(RaidPlusMinusDB.players) do
    -- Skip players whose changes net out to 0 — nothing meaningful to report.
    if data.history and #data.history > 0 and data.score ~= 0 then
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
    return sa > sb     -- descending, highest first
  end)

  QueueChatLine(L["CHAT_REPORT_LABEL"], channel)
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

    QueueChatLine(line, channel)
  end
end

------------------------------------------------------------
-- Row-level right-click menu (works regardless of the default
-- game raid frame / cross-faction quirks — fully self-contained)
------------------------------------------------------------
local rowDropDown = CreateFrame("Frame", "RaidPlusMinusRowDropDown", UIParent, "UIDropDownMenuTemplate")

local function AddPlusMinusMenuButtons(level, uName)
  -- Plain tables instead of the shared UIDropDownMenu_CreateInfo() table:
  -- on 3.3.5 that shared table gets wiped by CreateInfo() on every call,
  -- so the second button here could lose its text (or fail to appear at
  -- all) when another unit-frame addon (X-Perl etc.) touches it in between.
  local infoPlus = {
    text = L["ACTION_ADD_PLUS"],
    notCheckable = true,
    func = function() OpenInputWindow(uName, 1) end,
  }
  UIDropDownMenu_AddButton(infoPlus, level)

  local infoMinus = {
    text = L["ACTION_ADD_MINUS"],
    notCheckable = true,
    func = function() OpenInputWindow(uName, -1) end,
  }
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
  -- Positioned fresh on every BuildPlayerList() call instead of a fixed
  -- offset here, since rows can have variable height once a mini-history
  -- panel is expanded.
  row:SetPoint("TOPLEFT", 0, 0)

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

  -- Expand/collapse the mini-history panel for this player (hidden
  -- entirely when the player has no recorded history).
  row.expandBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  row.expandBtn:SetSize(18, 18)
  row.expandBtn:SetText(">")
  row.expandBtn:SetPoint("LEFT", row.plus, "RIGHT", 4, 0)
  row.expandBtn:SetScript("OnClick", function()
    local name = row.playerName
    if not name then return end
    expandedPlayers[name] = not expandedPlayers[name]
    RefreshWindow()
  end)
  row.historyLines = {}

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
      RefreshWindow()
    end
  end)

  row.plus:SetScript("OnClick", function()
    local name = row.playerName
    if not name or not CanEdit() then return end
    if IsShiftKeyDown() then
      OpenInputWindow(name, 1)
    else
      AddChange(name, 1)
      RefreshWindow()
    end
  end)

  rows[i] = row
  return row
end

-- Shows/hides and lays out the (up to HISTORY_MINI_LIMIT) mini-history
-- lines below a row, most-recent first. Returns the total height the row
-- should occupy (base row height, plus history lines if expanded).
local function UpdateRowHistoryPanel(row, name)
  local p = RaidPlusMinusDB.players[name]
  local history = p and p.history
  local total = history and #history or 0

  if total == 0 then
    row.expandBtn:Hide()
    for _, fs in ipairs(row.historyLines) do fs:Hide() end
    return ROW_HEIGHT
  end

  row.expandBtn:Show()
  local expanded = expandedPlayers[name] == true
  row.expandBtn:SetText(expanded and "v" or ">")

  if not expanded then
    for _, fs in ipairs(row.historyLines) do fs:Hide() end
    return ROW_HEIGHT
  end

  local shown = math.min(total, HISTORY_MINI_LIMIT)
  for slot = 1, shown do
    local entry = history[total - slot + 1]
    local fs = row.historyLines[slot]
    if not fs then
      fs = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
      fs:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -(slot - 1) * HISTORY_LINE_HEIGHT - 2)
      fs:SetWidth(230)
      fs:SetJustifyH("LEFT")
      row.historyLines[slot] = fs
    end
    local noteSuffix = (entry.reason and entry.reason ~= "") and (" (" .. entry.reason .. ")") or ""
    fs:SetText((entry.author or "?") .. " " .. FormatScore(entry.delta) .. noteSuffix)
    fs:Show()
  end
  for slot = shown + 1, #row.historyLines do
    row.historyLines[slot]:Hide()
  end

  return ROW_HEIGHT + shown * HISTORY_LINE_HEIGHT + 4
end

BuildPlayerList = function()
  local roster = GetRosterNames()
  RefreshRosterNameSet(roster)
  local canEdit = CanEdit()

  if canEdit then
    addPlusBtn:Show()
    addMinusBtn:Show()
  else
    addPlusBtn:Hide()
    addMinusBtn:Hide()
  end

  local names = {}
  local classMap = {}
  for _, entry in ipairs(roster) do
    local p = EnsurePlayer(entry.name)
    -- Only players with an actual plus/minus belong on the main list —
    -- everyone else is just clutter until they get their first change.
    if p and p.score ~= 0 then
      table.insert(names, entry.name)
      classMap[entry.name] = entry.class
    end
  end

  if RaidPlusMinusDB.sort == "score" then
    table.sort(names, function(a, b)
      local sa = RaidPlusMinusDB.players[a] and RaidPlusMinusDB.players[a].score or 0
      local sb = RaidPlusMinusDB.players[b] and RaidPlusMinusDB.players[b].score or 0
      if sa == sb then return a < b end
      return sa > sb       -- descending, highest first
    end)
  else
    table.sort(names)
  end

  local yOffset = 0
  for i, name in ipairs(names) do
    local row = GetRow(i)
    row:SetPoint("TOPLEFT", 0, -yOffset)
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
      row.minus:Show()
      row.plus:Show()
    else
      row.minus:Hide()
      row.plus:Hide()
    end

    local rowHeight = UpdateRowHistoryPanel(row, name)
    row:SetHeight(rowHeight)
    row:Show()
    yOffset = yOffset + rowHeight
  end

  for i = #names + 1, #rows do
    rows[i]:Hide()
  end

  content:SetHeight(math.max(1, yOffset))

  if #roster == 0 then
    frame.emptyText:SetText(L["EMPTY_TEXT"])
    frame.emptyText:Show()
  elseif #names == 0 then
    frame.emptyText:SetText(L["EMPTY_TEXT_NO_SCORES"])
    frame.emptyText:Show()
  else
    frame.emptyText:Hide()
  end
end

------------------------------------------------------------
-- History tab (global feed, newest first)
------------------------------------------------------------
local HISTORY_ROW_HEIGHT = 16
local historyRows = {}

local function GetHistoryRow(i)
  if historyRows[i] then return historyRows[i] end
  local fs = historyContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:SetPoint("TOPLEFT", 4, -(i - 1) * HISTORY_ROW_HEIGHT)
  fs:SetWidth(240)
  fs:SetJustifyH("LEFT")
  historyRows[i] = fs
  return fs
end

local function FormatRelativeTime(entryTime)
  local diff = time() - (tonumber(entryTime) or time())
  if diff < 0 then diff = 0 end
  if diff < 60 then
    return L["TIME_JUST_NOW"]
  elseif diff < 3600 then
    return L["TIME_MINUTES_AGO"]:format(math.floor(diff / 60))
  elseif diff < 86400 then
    return L["TIME_HOURS_AGO"]:format(math.floor(diff / 3600))
  else
    return L["TIME_DAYS_AGO"]:format(math.floor(diff / 86400))
  end
end

BuildHistoryList = function()
  local log = (type(RaidPlusMinusDB.globalLog) == "table") and RaidPlusMinusDB.globalLog or {}
  local count = #log

  for i = 1, count do
    local e = log[i]
    local row = GetHistoryRow(i)
    local noteSuffix = (e.reason and e.reason ~= "") and (" (" .. e.reason .. ")") or ""
    row:SetText(("%s: %s %s%s (%s)"):format(
      e.author or "?", e.name or "?", FormatScore(e.delta or 0), noteSuffix, FormatRelativeTime(e.time)))
    row:Show()
  end
  for i = count + 1, #historyRows do
    historyRows[i]:Hide()
  end

  historyContent:SetHeight(math.max(1, count * HISTORY_ROW_HEIGHT))

  if count == 0 then
    historyEmptyText:Show()
  else
    historyEmptyText:Hide()
  end
end

------------------------------------------------------------
-- Tab switching
------------------------------------------------------------
local currentTab = "players"

local function ApplyTabVisibility()
  local showPlayers = currentTab == "players"
  for _, widget in ipairs(playersTabWidgets) do
    if showPlayers then widget:Show() else widget:Hide() end
  end
  if showPlayers then
    historyScrollFrame:Hide()
    historyEmptyText:Hide()
  else
    frame.emptyText:Hide()
    historyScrollFrame:Show()
  end
end

SetActiveTab = function(tab)
  currentTab = tab
  ApplyTabVisibility()
  if tab == "history" then
    BuildHistoryList()
  else
    BuildPlayerList()
  end
end

-- Tab-aware "something changed" refresh: rebuilds whichever tab is
-- currently visible, or just keeps the roster cache warm if the window
-- is closed (avoids the cost of a full rebuild for a window nobody sees).
RefreshWindow = function()
  if not frame:IsShown() then
    RefreshRosterNameSet()
    return
  end
  if currentTab == "history" then
    RefreshRosterNameSet()
    BuildHistoryList()
  else
    BuildPlayerList()
  end
end

------------------------------------------------------------
-- Right-click unit context menu integration
-- (standard Blizzard raid frame + a careful fallback for
--  X-Perl / ElvUI / oUF-based frames that open the menu differently)
--
-- CRITICAL: the ToggleDropDownMenu hook is GLOBAL — it runs for every
-- dropdown in the UI. Any uncaught error here (or injecting buttons into
-- a menu that isn't ours) can break right-click menus on X-Perl raid
-- frames for everyone, not just this addon. Everything below is
-- therefore wrapped in pcall, and we only ever touch menus that clearly
-- belong to a raid/party unit.
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

-- True only for unit tokens we actually care about (raid1..40, party1..4,
-- player) — keeps us from reacting to random dropdowns that happen to
-- have a .unit field set for something unrelated.
local function IsUnitToken(unit)
  if type(unit) ~= "string" or unit == "" then return false end
  if unit == "player" then return true end
  if unit:match("^raid%d+$") then return true end
  if unit:match("^party%d+$") then return true end
  return false
end

-- Guard against adding the buttons twice if the same click goes through
-- both hooked paths at once (e.g. X-Perl/ElvUI internally also call the
-- standard UnitPopup_ShowMenu).
local lastMenuName, lastMenuTime = nil, 0

local function TryInjectButtons(level, uName)
  if not uName or uName == "" then return end
  -- Officers/RL only — never inject (and never risk the menu) otherwise.
  if not CanEdit() then return end
  if not IsTrackedRosterName(uName) then return end

  local now = GetTime()
  if lastMenuName == uName and (now - lastMenuTime) < 0.25 then
    return
  end
  lastMenuName, lastMenuTime = uName, now

  -- X-Perl and some other unit-frame addons finish building their menu
  -- slightly after ToggleDropDownMenu/UnitPopup_ShowMenu returns, which
  -- could wipe out buttons added synchronously. Waiting one frame and
  -- confirming the dropdown list is still open makes injection reliable
  -- there without affecting the default Blizzard menu (which is already
  -- open by the time this runs).
  level = level or UIDROPDOWNMENU_MENU_LEVEL or 1
  local waiter = CreateFrame("Frame")
  waiter:SetScript("OnUpdate", function(self)
    self:SetScript("OnUpdate", nil)
    local listFrame = _G["DropDownList" .. level]
    if listFrame and listFrame:IsShown() then
      pcall(AddPlusMinusMenuButtons, level, uName)
    end
  end)
end

-- Path 1: standard Blizzard menu (RAID_PLAYER/PARTY, etc.)
local function AddCustomMenuButtons(dropdownMenu, which, unit, name, userData)
  local ok, err = pcall(function()
    -- Narrow to group-related popup types when the game tells us the type.
    if which and which ~= "" then
      local w = which:upper()
      if not (w:find("RAID", 1, true) or w:find("PARTY", 1, true)
          or w == "SELF" or w == "PLAYER" or w == "FRIEND") then
        return
      end
    end
    local uName = name
    if (not uName or uName == "") and type(unit) == "string" and unit ~= "" then
      uName = UnitName(unit)
    end
    TryInjectButtons(UIDROPDOWNMENU_MENU_LEVEL or 1, uName)
  end)
  if not ok then
    -- Never let a menu-injection error break the original unit menu.
    DEFAULT_CHAT_FRAME:AddMessage("|cffff3333Raid +/-:|r " .. L["MSG_MENU_INJECT_ERROR"]:format(tostring(err)))
  end
end

if UnitPopup_ShowMenu then
  hooksecurefunc("UnitPopup_ShowMenu", AddCustomMenuButtons)
end

-- Path 2: a fallback, more generic hook — X-Perl and many oUF-based
-- frameworks (including ElvUI ports for 3.3.5) open the unit menu via
-- ToggleDropDownMenu, passing a dropdown frame with .unit or .name
-- fields (like the standard FriendsDropDown). This path catches those
-- cases even if UnitPopup_ShowMenu isn't called directly. We only ever
-- act on a real raid/party unit token, or a .name already in our roster,
-- so ordinary UI dropdowns (options, minimap, etc.) are never touched.
if ToggleDropDownMenu then
  hooksecurefunc("ToggleDropDownMenu", function(level, value, dropdownFrame)
    local ok, err = pcall(function()
      if not CanEdit() then return end

      local ddFrame = dropdownFrame
      if type(ddFrame) == "string" then
        ddFrame = _G[ddFrame]
      end
      if type(ddFrame) ~= "table" then return end

      local unit = ddFrame.unit
      local uName
      if IsUnitToken(unit) and UnitExists(unit) then
        uName = UnitName(unit)
      elseif type(ddFrame.name) == "string" and ddFrame.name ~= "" then
        if IsTrackedRosterName(ddFrame.name) then
          uName = ddFrame.name
        end
      end
      if not uName then return end

      TryInjectButtons(level or UIDROPDOWNMENU_MENU_LEVEL or 1, uName)
    end)
    if not ok then
      DEFAULT_CHAT_FRAME:AddMessage("|cffff3333Raid +/-:|r " .. L["MSG_MENU_INJECT_ERROR"]:format(tostring(err)))
    end
  end)
end

------------------------------------------------------------
-- RaidRoll integration (optional, only active if the separate
-- "RaidRoll" addon is also installed and loaded)
--
-- We never touch RaidRoll's own saved data or the roll value itself —
-- we hook RR_Display (its row-rendering function) with hooksecurefunc,
-- which always runs strictly AFTER RaidRoll has already finished
-- setting each row's text, and only append our own "(+N)"/"(-N)" to
-- the FontString that's already on screen.
------------------------------------------------------------
local raidRollHooked = false

local function RaidRoll_AppendScores(RR_DisplayID)
  -- RollerName and RR_ScrollOffset are RaidRoll's own globals
  -- (RaidRoll_OnLoad.lua), not ours — read-only access.
  if type(RollerName) ~= "table" or type(RR_ScrollOffset) ~= "number" then return end
  local nameRow = RollerName[RR_DisplayID]
  if type(nameRow) ~= "table" then return end
  if type(RaidPlusMinusDB) ~= "table" or type(RaidPlusMinusDB.players) ~= "table" then return end

  for i = 1, 5 do
    local rolledFS = _G["RR_Rolled" .. i]
    if rolledFS then
      local text = rolledFS:GetText()
      -- Empty text means RaidRoll intentionally hid this row (roll
      -- filtered out by its own settings) — leave it alone.
      if text and text ~= "" then
        local name = nameRow[i + RR_ScrollOffset]
        local p = name and RaidPlusMinusDB.players[name]
        if p and p.score and p.score ~= 0 then
          rolledFS:SetText(text .. " (" .. FormatScore(p.score) .. ")")
        end
      end
    end
  end
end

local function TryHookRaidRoll()
  if raidRollHooked then return end
  if type(RR_Display) ~= "function" then return end
  raidRollHooked = true
  hooksecurefunc("RR_Display", RaidRoll_AppendScores)
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
  if event ~= "CHAT_MSG_ADDON" then
    TryHookRaidRoll()
  end

  if event == "ADDON_LOADED" then
    local addonName = ...
    if addonName ~= ADDON_NAME then return end
    if type(RaidPlusMinusDB) ~= "table" then
      RaidPlusMinusDB = {}
    end
    if type(RaidPlusMinusDB.players) ~= "table" then
      RaidPlusMinusDB.players = {}
    end
    if type(RaidPlusMinusDB.globalLog) ~= "table" then
      RaidPlusMinusDB.globalLog = {}
    end
    if not RaidPlusMinusDB.sort then
      RaidPlusMinusDB.sort = "score"
    end
    if type(RaidPlusMinusDB.minimap) ~= "table" then
      RaidPlusMinusDB.minimap = { angle = 200 }
    end
    UpdateMinimapButtonPosition()
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
        RefreshWindow()
        frame.syncStatus:SetText(L["SYNC_SYNCED"]:format(date("%H:%M")))
      end
    elseif msgType == "R" then
      if IsOfficerName(sender) then
        RaidPlusMinusDB.players = {}
        RaidPlusMinusDB.globalLog = {}
        RefreshWindow()
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
    RefreshWindow()
  end
end)

------------------------------------------------------------
-- Window toggle
------------------------------------------------------------
function ToggleMainWindow()
  if frame:IsShown() then
    frame:Hide()
  else
    frame:Show()
    SetActiveTab(currentTab)
  end
end

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
    RefreshWindow()
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
    DEFAULT_CHAT_FRAME:AddMessage(L["STATUS_GROUP"]:format(tostring(numRaid > 0), numRaid, tostring(numParty > 0),
      numParty))
    local leaderOk, leaderVal = pcall(UnitIsGroupLeader, "player")
    local assistOk, assistVal = pcall(UnitIsGroupAssistant, "player")
    DEFAULT_CHAT_FRAME:AddMessage(L["STATUS_LEADER"]:format(leaderOk and tostring(leaderVal) or
    L["STATUS_ERROR_PREFIX"]:format(tostring(leaderVal))))
    DEFAULT_CHAT_FRAME:AddMessage(L["STATUS_ASSISTANT"]:format(assistOk and tostring(assistVal) or
    L["STATUS_ERROR_PREFIX"]:format(tostring(assistVal))))
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

  ToggleMainWindow()
end
