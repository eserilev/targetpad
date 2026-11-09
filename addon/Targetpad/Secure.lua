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

-- Press: borrow the nav keys, then let the macro run. Release: give them
-- back, and do nothing else.
ns.HOLD_SNIPPET = [[
  if down then
    owner:ClearBindings()
    for i = 1, owner:GetAttribute("nk-n") or 0 do
      owner:SetBinding(true, owner:GetAttribute("nk" .. i), owner:GetAttribute("nc" .. i))
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
-- one runs. The arrow keys always step too.
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
  add(base .. "LEFT", "TARGETPREVIOUSENEMY")
  add("RIGHT", "TARGETNEARESTENEMY")
  add("LEFT", "TARGETPREVIOUSENEMY")
  return list
end

-- Out of combat: tell the controller which keys to borrow.
function ns.applyNav()
  ns.afterCombat("nav", function()
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
