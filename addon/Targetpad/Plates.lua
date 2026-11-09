-- A frame over each enemy's nameplate, shown only while you hold: level
-- (a skull for elites and bosses), name, health, a cast bar, and a red dot
-- when it's attacking you. Your target stands out; the rest dim. Plain
-- frames, so they show and move in combat. Health and the like may be
-- secret in combat: they go straight into bars, and nothing compares them.
local _, ns = ...

local GOLD = { 1, 0.82, 0, 1 }
local EDGE = { 0.29, 0.23, 0.16, 1 }
local W, H = 190, 34

-- Every frame sits on one holder, so /tp shots can lift them all at once.
local holder = CreateFrame("Frame", "TargetpadPlates", UIParent)
holder:SetAllPoints(UIParent)
ns.plateHolder = holder

local units = {} -- nameplate unit -> true while its plate is up
local frames = {} -- nameplate unit -> our frame
local spare = {}
local held = false
local fade = 0 -- the alpha of everything, for the fade on release

local function solid(f, r, g, b, a)
  local t = f:CreateTexture(nil, "BACKGROUND")
  t:SetAllPoints()
  t:SetColorTexture(r, g, b, a)
  return t
end

local function make()
  local f = table.remove(spare)
  if f then
    return f
  end
  f = CreateFrame("Frame", nil, holder)
  f:SetSize(W, H)
  f:SetFrameStrata("MEDIUM")
  solid(f, 0.07, 0.05, 0.04, 0.92)
  f.edge = ns.outline(f, f, 0, 1)
  f.edge:SetColor(unpack(EDGE))
  f.edge:Show()
  f.mark = ns.outline(f, f, 1, 2)
  f.mark:SetColor(unpack(GOLD))
  f.level = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.level:SetPoint("TOPLEFT", 6, -5)
  f.level:SetWidth(22)
  f.name = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.name:SetPoint("TOPLEFT", 30, -4)
  f.name:SetPoint("TOPRIGHT", -18, -4)
  f.name:SetJustifyH("LEFT")
  f.name:SetWordWrap(false)
  f.name:SetTextColor(1, 0.42, 0.35)
  f.dot = f:CreateTexture(nil, "OVERLAY")
  f.dot:SetSize(8, 8)
  f.dot:SetPoint("TOPRIGHT", -6, -7)
  f.dot:SetColorTexture(1, 0.23, 0.19, 1)
  f.health = CreateFrame("StatusBar", nil, f)
  f.health:SetPoint("BOTTOMLEFT", 6, 9)
  f.health:SetPoint("BOTTOMRIGHT", -6, 9)
  f.health:SetHeight(9)
  f.health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  f.health:SetStatusBarColor(0.8, 0.1, 0.08)
  solid(f.health, 0.16, 0.02, 0.02, 1)
  f.cast = CreateFrame("StatusBar", nil, f)
  f.cast:SetPoint("TOPLEFT", f.health, "BOTTOMLEFT", 0, -2)
  f.cast:SetPoint("TOPRIGHT", f.health, "BOTTOMRIGHT", 0, -2)
  f.cast:SetHeight(4)
  f.cast:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  f.cast:SetStatusBarColor(1, 0.75, 0.1)
  f.cast:SetMinMaxValues(0, 1)
  f.cast:SetValue(1)
  return f
end

local function release(unit)
  local f = frames[unit]
  if not f then
    return
  end
  f:Hide()
  f:ClearAllPoints()
  frames[unit] = nil
  table.insert(spare, f)
end

local function hostile(unit)
  local ok, yes = pcall(UnitCanAttack, "player", unit)
  return ok and yes == true
end

local function isTarget(unit)
  local ok, yes = pcall(UnitIsUnit, unit, "target")
  return ok and yes == true
end

local function draw(unit)
  if not hostile(unit) then
    release(unit)
    return
  end
  local plate = C_NamePlate.GetNamePlateForUnit(unit)
  if not plate then
    release(unit)
    return
  end
  local f = frames[unit] or make()
  frames[unit] = f
  f:ClearAllPoints()
  f:SetPoint("BOTTOM", plate, "TOP", 0, 2)
  if not pcall(f.name.SetText, f.name, UnitName(unit)) then
    f.name:SetText("")
  end
  local okC, class = pcall(UnitClassification, unit)
  local elite = okC and (class == "elite" or class == "rareelite" or class == "worldboss")
  local SKULL = "|TInterface\\TargetingFrame\\UI-TargetingFrame-Skull:14|t"
  local okL, lvl = pcall(function()
    local l = UnitLevel(unit)
    return l > 0 and tostring(l) or SKULL
  end)
  if elite then
    f.level:SetText(SKULL)
  elseif okL then
    f.level:SetText(lvl)
  elseif not pcall(f.level.SetFormattedText, f.level, "%d", UnitLevel(unit)) then
    f.level:SetText("")
  end
  if
    not (
      pcall(f.health.SetMinMaxValues, f.health, 0, UnitHealthMax(unit))
      and pcall(f.health.SetValue, f.health, UnitHealth(unit))
    )
  then
    f.health:SetMinMaxValues(0, 1)
    f.health:SetValue(1)
  end
  local okCast, casting = pcall(function()
    return UnitCastingInfo(unit) ~= nil
  end)
  f.cast:SetShown(okCast and casting == true)
  local okOn, onYou = pcall(UnitIsUnit, unit .. "target", "player")
  f.dot:SetShown(okOn and onYou == true)
  local target = isTarget(unit)
  f.mark:SetShown(target)
  f:SetScale(target and 1.15 or 1)
  f:SetAlpha((target and 1 or 0.6) * fade)
  f.target = target
  f:Show()
end

function ns.redrawPlates()
  for unit in pairs(units) do
    if fade > 0 then
      draw(unit)
    else
      release(unit)
    end
  end
end
ns.plateFrames = frames

local pulse, since = 0, 0
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(_, elapsed)
  if held then
    fade = math.min(1, fade + elapsed * 8)
  elseif fade > 0 then
    fade = math.max(0, fade - elapsed * 5)
  else
    return
  end
  pulse = pulse + elapsed
  since = since + elapsed
  if since > 0.1 or not held then
    since = 0
    ns.redrawPlates()
  end
  for _, f in pairs(frames) do
    if f.target then
      f.mark:SetAlpha(0.6 + 0.4 * math.abs(math.sin(pulse * 3)))
    end
  end
end)

ns.ctl:HookScript("OnAttributeChanged", function(_, name, value)
  if name ~= "state" then
    return
  end
  held = value == "held"
  if held then
    fade = math.max(fade, 0.01)
  end
  ns.redrawPlates()
end)

function ns.isHeld()
  return held
end

-- Example frames in the middle of the screen, for /tp shots when no enemy
-- is around: level 60 enemies, the second one your target.
local examples = {}
function ns.stageExamples(on)
  for _, f in ipairs(examples) do
    f:Hide()
  end
  if not on then
    return
  end
  local spots = { { -260, 60 }, { 0, 120 }, { 250, 40 }, { -120, -60 }, { 150, -80 } }
  for i, at in ipairs(spots) do
    local f = examples[i] or make()
    examples[i] = f
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", at[1], at[2])
    f.name:SetText("Enemy")
    f.level:SetText("60")
    f.health:SetMinMaxValues(0, 1)
    f.health:SetValue(({ 0.72, 0.45, 1, 0.9, 0.6 })[i])
    f.cast:SetShown(i == 1)
    f.dot:SetShown(i == 1 or i == 2)
    local target = i == 2
    f.mark:SetShown(target)
    f:SetScale(target and 1.15 or 1)
    f:SetAlpha(target and 1 or 0.6)
    f:Show()
  end
end

ns.on("NAME_PLATE_UNIT_ADDED", function(unit)
  units[unit] = true
  if fade > 0 then
    draw(unit)
  end
end)
ns.on("NAME_PLATE_UNIT_REMOVED", function(unit)
  units[unit] = nil
  release(unit)
end)
ns.on("PLAYER_TARGET_CHANGED", function()
  if fade > 0 then
    ns.redrawPlates()
  end
end)
