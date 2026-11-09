-- /tp shots: screenshots for the addon's page, taken while you play it.
-- An addon can't pick a target, so you do: after /tp shots, hold your
-- Targetpad button near enemies and step through them. Holding hides the
-- game's interface (the arrow stays) and takes a screenshot; each new target
-- takes another. Letting go brings the interface back and takes one of the
-- settings window, then puts everything back. Combat or an error ends it,
-- with everything put back.
local _, ns = ...

local function eff(f)
  local ok, v = pcall(f.GetEffectiveScale, f)
  return (ok and type(v) == "number" and v > 0) and v or 1
end

-- Lifted onto WorldFrame at the same size while UIParent is hidden.
local moved = {}
local function lift(f)
  if not f or moved[f] then
    return
  end
  moved[f] = f:GetScale() or 1
  local k = eff(UIParent) / eff(WorldFrame)
  f:SetParent(WorldFrame)
  f:SetScale(moved[f] * k)
end

local armed, shooting, count = false, false, 0

local function restore()
  local panel = ns.optionsPanel and ns.optionsPanel()
  if panel then
    panel:Hide()
  end
  for f, scale in pairs(moved) do
    f:SetParent(UIParent)
    f:SetScale(scale)
  end
  for f in pairs(moved) do
    moved[f] = nil
  end
  UIParent:Show()
  armed, shooting = false, false
end

local function shot()
  count = count + 1
  pcall(Screenshot)
end

-- A moment after a change, so the arrow is drawn where it now belongs. Two
-- changes at once (the hold picks a target as it starts) make one shot.
local pending = 0
local function shotSoon()
  pending = pending + 1
  local mine = pending
  C_Timer.After(0.35, function()
    if shooting and mine == pending then
      shot()
    end
  end)
end

local function finish()
  shooting = false
  UIParent:Show()
  local ok = pcall(function()
    ns.openOptions()
    lift(ns.optionsPanel())
    UIParent:Hide()
  end)
  C_Timer.After(0.6, function()
    if ok then
      shot()
    end
    restore()
    ns.say("done: " .. count .. " screenshots in your Screenshots folder.")
  end)
end

function ns.showcase()
  if InCombatLockdown() then
    ns.say("after combat.")
    return
  end
  if not ns.holdKey() then
    ns.say("set a hold button in /tp first.")
    return
  end
  armed, shooting, count = true, false, 0
  ns.say(
    "hold "
      .. ns.keyLabel(ns.holdKey())
      .. " near enemies and step through them: each target is a screenshot. Let go to finish."
  )
end

-- The hold starts and ends the shoot; each target change while held is a shot.
ns.ctl:HookScript("OnAttributeChanged", function(_, name, value)
  if name ~= "state" or not armed then
    return
  end
  if value == "held" and not shooting then
    local ok = pcall(function()
      lift(ns.plateHolder)
      UIParent:Hide()
    end)
    if not ok then
      restore()
      return
    end
    shooting = true
    shotSoon()
  elseif value ~= "held" and shooting then
    finish()
  end
end)

ns.on("PLAYER_TARGET_CHANGED", function()
  if shooting then
    shotSoon()
  end
end)

-- Combat ends it at once, with the interface back.
ns.on("PLAYER_REGEN_DISABLED", function()
  if armed or shooting then
    restore()
  end
end)
