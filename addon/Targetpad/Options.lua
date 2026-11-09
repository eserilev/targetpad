-- The settings: /tp or /targetpad. Two things: the hold button, and what
-- steps through enemies while you hold (the d-pad, or a stick). The hold
-- button is a normal game binding, so the game's Key Bindings menu shows
-- the same key under Targetpad. Out of combat only; the window closes in combat.
local _, ns = ...

local W, H, PAD = 440, 270, 18
local GOLD, WHITE = { 1, 0.82, 0 }, { 1, 1, 1 }
local PAD_NAME = {
  PAD1 = "A",
  PAD2 = "B",
  PAD3 = "X",
  PAD4 = "Y",
  PAD5 = "P5",
  PAD6 = "P6",
  PADLSHOULDER = "LB",
  PADRSHOULDER = "RB",
  PADLTRIGGER = "LT",
  PADRTRIGGER = "RT",
  PADLSTICK = "L3",
  PADRSTICK = "R3",
  PADDUP = "Up",
  PADDDOWN = "Down",
  PADDLEFT = "Left",
  PADDRIGHT = "Right",
  PADFORWARD = "Menu",
  PADBACK = "View",
  PADPADDLE1 = "P1",
  PADPADDLE2 = "P2",
  PADPADDLE3 = "P3",
  PADPADDLE4 = "P4",
}
local MODIFIER = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, UNKNOWN = true }

local panel
local ui = {}
local capturing = false

-- "SHIFT-PAD3" -> "Shift+X"; a keyboard key by the game's own name.
function ns.keyLabel(key)
  if not key then
    return "Not set"
  end
  local mods, base = key:match("^(.-%-?)([^%-]+)$")
  local name = PAD_NAME[base]
  if not name then
    local ok, t = pcall(GetBindingText, base)
    name = (ok and t and t ~= "") and t or base
  end
  mods = (mods or ""):gsub("%-$", "")
  local out = {}
  for m in mods:gmatch("[^%-]+") do
    table.insert(out, m:sub(1, 1) .. m:sub(2):lower())
  end
  table.insert(out, name)
  return table.concat(out, "+")
end

local function modifiers()
  return (IsAltKeyDown() and "ALT-" or "")
    .. (IsControlKeyDown() and "CTRL-" or "")
    .. (IsShiftKeyDown() and "SHIFT-" or "")
end

local function redButton(parent, w, h, label)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w, h)
  b:SetText(label)
  return b
end
local function setChosen(b, on)
  if on then
    b:LockHighlight()
  else
    b:UnlockHighlight()
  end
  local fs = b.GetFontString and b:GetFontString()
  if fs then
    fs:SetTextColor(unpack(on and WHITE or GOLD))
  end
end

local function refresh()
  if not panel or not panel:IsShown() then
    return
  end
  ui.key:SetText(capturing and "Press a button" or ns.keyLabel(ns.holdKey()))
  setChosen(ui.key, capturing)
  for i, k in ipairs(ns.NAVS) do
    setChosen(ui.navs[i], ns.db.nav == k)
  end
end
ns.refreshOptions = refresh

local function stopCapture()
  capturing = false
  if panel then
    panel:EnableKeyboard(false)
    pcall(panel.EnableGamePadButton, panel, false)
    ui.key:SetAlpha(1)
  end
  refresh()
end

local function captured(key)
  if not capturing then
    return
  end
  if InCombatLockdown() then
    stopCapture()
    return
  end
  ns.setHoldKey(key)
  ns.log("hold key = " .. tostring(key))
  stopCapture()
end

local function startCapture()
  if InCombatLockdown() then
    return
  end
  capturing = true
  panel:EnableKeyboard(true)
  pcall(panel.SetPropagateKeyboardInput, panel, false)
  pcall(panel.EnableGamePadButton, panel, true)
  refresh()
end

local function takeKeys()
  if InCombatLockdown() then
    return
  end
  SetOverrideBindingClick(panel, true, "ESCAPE", "TargetpadClose")
end
local function giveKeys()
  if InCombatLockdown() then
    return
  end
  ClearOverrideBindings(panel)
end

local function build()
  panel = CreateFrame("Frame", "TargetpadOptions", UIParent, "ButtonFrameTemplate")
  panel:SetSize(W, H)
  panel:SetPoint("CENTER")
  panel:SetFrameStrata("DIALOG")
  panel:SetToplevel(true)
  panel:EnableMouse(true)
  panel:SetClampedToScreen(true)
  panel:Hide()
  if ButtonFrameTemplate_HideButtonBar then
    ButtonFrameTemplate_HideButtonBar(panel)
  end
  if panel.SetTitle then
    panel:SetTitle("Targetpad")
  end
  if panel.SetPortraitToUnit then
    panel:SetPortraitToUnit("player")
  end
  local inset = type(panel.Inset) == "table" and panel.Inset or nil
  local body = inset or panel
  if inset then
    inset:ClearAllPoints()
    inset:SetPoint("TOPLEFT", 4, -60)
    inset:SetPoint("BOTTOMRIGHT", -6, 6)
  end

  local h1 = body:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  h1:SetText("Hold")
  h1:SetPoint("TOPLEFT", PAD, -PAD)
  ui.key = redButton(body, 170, 32, "")
  ui.key:SetPoint("TOPLEFT", PAD, -PAD - 26)
  ui.key:SetScript("OnClick", function()
    if capturing then
      stopCapture()
    else
      startCapture()
    end
  end)
  ui.clear = redButton(body, 90, 26, "Clear")
  ui.clear:SetPoint("LEFT", ui.key, "RIGHT", 10, 0)
  ui.clear:SetScript("OnClick", function()
    if InCombatLockdown() then
      return
    end
    stopCapture()
    ns.setHoldKey(nil)
    refresh()
  end)

  local h2 = body:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  h2:SetText("Navigate with")
  h2:SetPoint("TOPLEFT", PAD, -PAD - 80)
  ui.navs = {}
  local bw = (W - 10 - 2 * PAD - 20) / 3
  for i, k in ipairs(ns.NAVS) do
    local b = redButton(body, bw, 40, ns.NAV_LABEL[k])
    b:SetPoint("TOPLEFT", PAD + (i - 1) * (bw + 10), -PAD - 106)
    b:SetScript("OnClick", function()
      if InCombatLockdown() then
        return
      end
      ns.db.nav = k
      ns.applyNav()
      refresh()
    end)
    ui.navs[i] = b
  end

  -- While it waits for a button: the next key or pad button pressed.
  panel:SetScript("OnKeyDown", function(_, key)
    if not capturing then
      return
    end
    if key == "ESCAPE" then
      stopCapture()
      return
    end
    if MODIFIER[key] then
      return
    end
    captured(modifiers() .. key)
  end)
  panel:SetScript("OnGamePadButtonDown", function(_, button)
    if capturing then
      captured(modifiers() .. button)
    end
  end)
  local t = 0
  panel:SetScript("OnUpdate", function(_, elapsed)
    if not capturing then
      return
    end
    t = t + elapsed
    ui.key:SetAlpha(0.55 + 0.45 * math.abs(math.sin(t * 4)))
  end)

  local close = CreateFrame("Button", "TargetpadClose", UIParent)
  close:SetScript("OnClick", function()
    panel:Hide()
  end)

  panel:SetScript("OnShow", takeKeys)
  panel:SetScript("OnHide", function()
    stopCapture()
    giveKeys()
  end)
  table.insert(UISpecialFrames, "TargetpadOptions")
end

function ns.openOptions()
  if InCombatLockdown() then
    ns.say("after combat.")
    return
  end
  if not panel then
    build()
  end
  panel:Show()
  refresh()
end
function ns.optionsPanel()
  return panel
end
function ns.optionsDebug()
  return {
    panel = panel,
    ui = ui,
    capturing = function()
      return capturing
    end,
  }
end

SLASH_TARGETPAD1 = "/tp"
SLASH_TARGETPAD2 = "/targetpad"
SlashCmdList.TARGETPAD = function(msg)
  local cmd = (msg or ""):lower():match("^%s*(%S*)")
  if cmd == "test" then
    if ns.selfTest then
      ns.selfTest()
    end
    return
  end
  if cmd == "shots" then
    if ns.showcase then
      ns.showcase()
    end
    return
  end
  if panel and panel:IsShown() then
    panel:Hide()
  else
    ns.openOptions()
  end
end

ns.on("PLAYER_REGEN_DISABLED", function()
  if panel and panel:IsShown() then
    panel:Hide()
  end
end)
ns.on("UPDATE_BINDINGS", function()
  refresh()
end)

ns.on("PLAYER_LOGIN", function()
  if not ns.holdKey() then
    ns.say("type /tp to pick your hold button.")
  end
end)
