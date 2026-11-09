-- /tp test: checks Targetpad inside the real game, out of combat. Reports
-- the hold binding, runs a hold and a release through the real secure
-- snippet (an addon can't click a secure button, so it runs the snippet as
-- the game would), and records what it found and any Lua error in the saved
-- log. The game writes the log on /reload.
local _, ns = ...

local results
local function check(name, ok, detail)
  table.insert(results, ok and true or false)
  ns.log(
    string.format("TEST %s: %s%s", ok and "ok  " or "FAIL", name, detail and (" (" .. tostring(detail) .. ")") or "")
  )
end

local function bound(key)
  local ok, action = pcall(GetBindingAction, key, true)
  return ok and action or "?"
end

-- The hold snippet's two halves, run as the controller (self).
ns.TEST_PRESS = [[
  local owner = self
  owner:ClearBindings()
  for i = 1, owner:GetAttribute("nk-n") or 0 do
    owner:SetBinding(true, owner:GetAttribute("nk" .. i), owner:GetAttribute("nc" .. i))
  end
  owner:SetAttribute("state", "held")
]]
ns.TEST_RELEASE = [[
  self:ClearBindings()
  self:SetAttribute("state", "idle")
]]

function ns.selfTest()
  if InCombatLockdown() then
    ns.say("after combat.")
    return
  end
  results = {}
  ns.db.log = {}
  local oldHandler = geterrorhandler()
  seterrorhandler(function(err)
    ns.log("LUA ERROR " .. tostring(err))
    return oldHandler(err)
  end)
  local ok, err = pcall(function()
    ns.log("REPORT build " .. tostring((GetBuildInfo())) .. ", nav " .. tostring(ns.db.nav))
    local key = ns.holdKey()
    ns.log("REPORT hold key " .. tostring(key) .. " = " .. tostring(key and bound(key)))
    if key then
      check("the hold button has a key", true, key)
    else
      ns.log("TEST note: no hold key yet; set one in /tp")
    end
    local navs = ns.navKeys()
    SecureHandlerExecute(ns.ctl, ns.TEST_PRESS)
    check("holding shows the arrow", ns.isHeld())
    check(
      "next steps to the next enemy",
      bound(navs[1][1]) == "TARGETNEARESTENEMY",
      navs[1][1] .. "=" .. bound(navs[1][1])
    )
    check("previous steps back", bound(navs[5][1]) == "TARGETPREVIOUSENEMY", navs[5][1] .. "=" .. bound(navs[5][1]))
    check("the arrow keys step too", bound("RIGHT") == "TARGETNEARESTENEMY", bound("RIGHT"))
    SecureHandlerExecute(ns.ctl, ns.TEST_RELEASE)
    check("letting go hides the arrow", not ns.isHeld())
    check("letting go gives the keys back", bound(navs[1][1]) ~= "TARGETNEARESTENEMY", bound(navs[1][1]))
  end)
  if not ok then
    ns.log("LUA ERROR " .. tostring(err))
  end
  seterrorhandler(oldHandler)
  local bad = 0
  for _, r in ipairs(results) do
    if not r then
      bad = bad + 1
    end
  end
  ns.log(string.format("TEST done: %d ok, %d failed", #results - bad, bad))
  ns.say(string.format("test done: %d ok, %d failed. Type /reload so the log is saved.", #results - bad, bad))
end
