-- While you hold, a big gold arrow bobs over your target's nameplate. It is
-- the only thing Targetpad draws, so it sits with any nameplate addon. A
-- plain frame: it shows and moves in combat. No target, or its plate is off
-- screen: no arrow.
local _, ns = ...

-- The arrow sits on one holder, so /tp shots can lift it.
local holder = CreateFrame("Frame", "TargetpadArrowHolder", UIParent)
holder:SetAllPoints(UIParent)
ns.plateHolder = holder

local SIZE, BAR, BOB = 46, 11, 7
local arrow = CreateFrame("Frame", "TargetpadArrow", holder)
arrow:SetSize(SIZE, SIZE)
arrow:SetFrameStrata("HIGH")
arrow:Hide()
ns.arrow = arrow

-- A chevron pointing down: two bars at 45 degrees meeting at the bottom,
-- over a darker copy for an edge and a soft gold copy for a glow.
local tinted = {} -- the glow and the face take the chosen color
local function chevron(layer, sub, grow, r, g, b, a, blend)
  for _, side in ipairs({ -1, 1 }) do
    local t = arrow:CreateTexture(nil, layer, nil, sub)
    t:SetTexture("Interface\\Buttons\\WHITE8X8")
    -- The game wants four numbers: the tinted parts start gold.
    t:SetVertexColor(r or 1, g or 0.82, b or 0, a)
    if blend then
      t:SetBlendMode(blend)
    end
    t:SetSize(SIZE * 0.78 + grow, BAR + grow)
    t:SetPoint("CENTER", arrow, "CENTER", side * SIZE * 0.25, 0)
    pcall(t.SetRotation, t, side * math.pi / 4)
    if r == nil then
      table.insert(tinted, { t, a })
    end
  end
end
chevron("BACKGROUND", 0, 14, nil, nil, nil, 0.25, "ADD")
chevron("ARTWORK", 0, 4, 0.08, 0.05, 0, 1)
chevron("ARTWORK", 1, 0, nil, nil, nil, 1)

-- Size and color from the settings.
function ns.styleArrow()
  local db = ns.db or {}
  arrow:SetScale(db.arrowScale or 1)
  local c = ns.COLOR and ns.COLOR[db.arrowColor or "gold"] or { 1, 0.82, 0 }
  for _, it in ipairs(tinted) do
    it[1]:SetVertexColor(c[1], c[2], c[3], it[2])
  end
end
ns.on("PLAYER_LOGIN", ns.styleArrow)

local held = false
local fade, t = 0, 0
local anchor -- the plate the arrow sits over

local function targetPlate()
  local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, "target")
  return ok and plate or nil
end

function ns.redrawArrow()
  anchor = (held or fade > 0) and targetPlate() or nil
  if ns.stagedAt then
    anchor = ns.stagedAt
  end
  arrow:SetShown(anchor ~= nil and fade > 0)
end

local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(_, elapsed)
  if held or ns.stagedAt then
    fade = math.min(1, fade + elapsed * 8)
  elseif fade > 0 then
    fade = math.max(0, fade - elapsed * 5)
  else
    if arrow:IsShown() then
      arrow:Hide()
    end
    return
  end
  t = t + elapsed
  ns.redrawArrow()
  if anchor then
    arrow:ClearAllPoints()
    arrow:SetPoint("BOTTOM", anchor, "TOP", 0, 6 + BOB * math.abs(math.sin(t * 4)))
    arrow:SetAlpha(fade * (0.85 + 0.15 * math.abs(math.sin(t * 4))))
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
  ns.redrawArrow()
end)

function ns.isHeld()
  return held
end

-- /tp shots with no enemy around: the arrow over an example spot in the
-- middle of the screen. The settings window puts it beside itself (at).
local example = CreateFrame("Frame", nil, holder)
example:SetSize(120, 20)
function ns.stageExamples(on, at)
  example:ClearAllPoints()
  if at then
    example:SetPoint("LEFT", at, "RIGHT", 40, 0)
  else
    example:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
  end
  ns.stagedAt = on and example or nil
  if on then
    fade = 1
  end
  ns.redrawArrow()
end

ns.on("PLAYER_TARGET_CHANGED", ns.redrawArrow)
ns.on("NAME_PLATE_UNIT_REMOVED", ns.redrawArrow)
ns.on("NAME_PLATE_UNIT_ADDED", ns.redrawArrow)
