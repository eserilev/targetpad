-- The secure parts: the hold button and the controller that borrows the
-- nav keys.
--
-- Press the hold button: with no living enemy targeted, its macro targets
-- the nearest one, and while you hold, the nav keys step through enemies
-- with the game's own next and previous enemy commands. Let go: the nav keys
-- go back to what you bound, and you keep the target. All of it runs in
-- secure snippets, so it works in combat.
local _, ns = ...

local ctl = CreateFrame("Frame", "TargetpadCtl", UIParent, "SecureHandlerBaseTemplate")
ns.ctl = ctl

local hold = CreateFrame("Button", "TargetpadHold", UIParent, "SecureActionButtonTemplate")
hold:RegisterForClicks("AnyDown", "AnyUp")
hold:SetAttribute("useOnKeyDown", true)
hold:SetAttribute("type", "macro")
hold:SetAttribute("macrotext", "/targetenemy [noharm][dead]")
ns.hold = hold

-- Back: the previous enemy, or with no living enemy targeted, the nearest
-- one, as Tab does.
local back = CreateFrame("Button", "TargetpadBack", UIParent, "SecureActionButtonTemplate")
back:RegisterForClicks("AnyDown")
back:SetAttribute("useOnKeyDown", true)
back:SetAttribute("type", "macro")
back:SetAttribute("macrotext", "/targetenemy [harm,nodead] 1; 0")

-- Press: borrow the nav keys, then let the macro run. Release: give them
-- back, and do nothing else.
ns.HOLD_SNIPPET = [[
  if down then
    owner:ClearBindings()
    for i = 1, owner:GetAttribute("nk-n") or 0 do
      local key, command = owner:GetAttribute("nk" .. i), owner:GetAttribute("nc" .. i)
      if command == "BACK" then
        owner:SetBindingClick(true, key, "TargetpadBack")
      else
        owner:SetBinding(true, key, command)
      end
    end
    owner:SetAttribute("state", "held")
    return
  end
  owner:ClearBindings()
  owner:SetAttribute("state", "idle")
  return false
]]
SecureHandlerWrapScript(hold, "OnClick", ctl, ns.HOLD_SNIPPET)

-- The keys the controller borrows while you hold, and the game command each
-- one runs (BACK clicks the back button). The arrow keys always step too.
function ns.navKeys()
  local base = ({ dpad = "PADD", rstick = "PADRSTICK", lstick = "PADLSTICK" })[ns.db and ns.db.nav] or "PADD"
  local list = {}
  local function add(key, command)
    table.insert(list, { key, command })
    for _, m in ipairs({ "SHIFT-", "CTRL-", "ALT-" }) do
      table.insert(list, { m .. key, command })
    end
  end
  add(base .. "RIGHT", "TARGETNEARESTENEMY")
  add(base .. "LEFT", "BACK")
  add("RIGHT", "TARGETNEARESTENEMY")
  add("LEFT", "BACK")
  return list
end

-- The game sends a stick's pushes as button presses (PADRSTICKRIGHT...)
-- only with GamePadStickAxisButtons on: with a stick to step, it goes on.
-- Unbound, those presses do nothing, so the stick still works as before.
local function cvar(k)
  local ok, v = pcall(C_CVar.GetCVar, k)
  return ok and v or nil
end
local function setCVar(k, v)
  local ok, err = pcall(C_CVar.SetCVar, k, v)
  ns.log("cvar " .. k .. " = " .. tostring(v) .. (ok and "" or (" failed: " .. tostring(err))))
  return ok
end
local function stickButtons()
  if ns.db and ns.db.nav ~= "dpad" and cvar("GamePadStickAxisButtons") ~= "1" then
    setCVar("GamePadStickAxisButtons", "1")
  end
end

-- While you hold with the right stick, it doesn't turn the camera: its
-- speeds go to 0 and come back when you let go (or at the next login, after
-- a reload in the middle of a hold).
local CAMERA = { "GamePadCameraYawSpeed", "GamePadCameraPitchSpeed" }
local function freeCamera()
  local saved = ns.db and ns.db.cameraSaved
  if not saved then
    return
  end
  ns.db.cameraSaved = nil
  for _, k in ipairs(CAMERA) do
    if saved[k] then
      setCVar(k, saved[k])
    end
  end
end
local function stillCamera()
  if not (ns.db and ns.db.nav == "rstick") or ns.db.cameraSaved then
    return
  end
  local saved = {}
  for _, k in ipairs(CAMERA) do
    saved[k] = cvar(k)
  end
  if not saved[CAMERA[1]] then
    return
  end
  ns.db.cameraSaved = saved
  for _, k in ipairs(CAMERA) do
    setCVar(k, "0")
  end
end
ns.freeCamera = freeCamera
hold:HookScript("PreClick", function(_, _, down)
  if down then
    stillCamera()
  else
    freeCamera()
  end
end)
ns.on("PLAYER_LOGIN", freeCamera)

-- Out of combat: tell the controller which keys to borrow.
function ns.applyNav()
  ns.afterCombat("nav", function()
    stickButtons()
    local list = ns.navKeys()
    for i, k in ipairs(list) do
      ctl:SetAttribute("nk" .. i, k[1])
      ctl:SetAttribute("nc" .. i, k[2])
    end
    ctl:SetAttribute("nk-n", #list)
  end)
end

-- The key the hold button is bound to in the game's Key Bindings, or nil.
function ns.holdKey()
  local ok, key = pcall(GetBindingKey, ns.HOLD)
  return ok and key or nil
end

-- Binds the hold button to key (nil clears it), saved in your game bindings.
function ns.setHoldKey(key)
  if InCombatLockdown() then
    return false
  end
  local ok, a, b = pcall(GetBindingKey, ns.HOLD)
  if ok then
    for _, old in ipairs({ a, b }) do
      if old then
        SetBinding(old, nil)
      end
    end
  end
  if key then
    SetBinding(key, ns.HOLD)
  end
  pcall(SaveBindings, GetCurrentBindingSet())
  return true
end

ns.on("PLAYER_LOGIN", ns.applyNav)
