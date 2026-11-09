-- /tp shots: screenshots for the addon's page. Hides the game's interface,
-- keeps only Targetpad's frames, and takes a screenshot of the hold view
-- and of the settings window. Then puts everything back, even on an error.
-- Out of combat; stand near a few enemies, or it shows example frames.
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

local function anyEnemy()
  local ok, plates = pcall(C_NamePlate.GetNamePlates)
  if not ok or type(plates) ~= "table" then
    return false
  end
  for _, plate in ipairs(plates) do
    local unit = plate.namePlateUnitToken
    local okA, yes = pcall(UnitCanAttack, "player", unit)
    if unit and okA and yes then
      return true
    end
  end
  return false
end

local function restore()
  pcall(SecureHandlerExecute, ns.ctl, ns.TEST_RELEASE)
  ns.stageExamples(false)
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
end

function ns.showcase()
  if InCombatLockdown() then
    ns.say("after combat.")
    return
  end
  local function shot()
    pcall(Screenshot)
  end
  local scenes = {
    function()
      lift(ns.plateHolder)
      UIParent:Hide()
      if anyEnemy() then
        SecureHandlerExecute(ns.ctl, ns.TEST_PRESS)
      else
        ns.stageExamples(true)
      end
    end,
    shot,
    function()
      SecureHandlerExecute(ns.ctl, ns.TEST_RELEASE)
      ns.stageExamples(false)
      ns.openOptions()
      lift(ns.optionsPanel())
    end,
    shot,
  }
  ns.say("taking screenshots… hands off for a few seconds.")
  local i = 0
  local function step()
    i = i + 1
    local fn = scenes[i]
    if not fn then
      restore()
      ns.say("done: 2 screenshots in your Screenshots folder.")
      return
    end
    local ok, err = pcall(fn)
    if not ok then
      ns.log("SHOTS error: " .. tostring(err))
      restore()
      ns.say("screenshots stopped: " .. tostring(err))
      return
    end
    C_Timer.After(1.2, step)
  end
  step()
end
