-- Targetpad: hold a button, step through nearby enemies with the d-pad or a
-- stick, let go. While you hold, each enemy nameplate gets a frame and your
-- target stands out; the rest of the time the d-pad does what you bound.
local ADDON, ns = ...

ns.HOLD = "CLICK TargetpadHold:LeftButton" -- the binding of the hold button
ns.NAVS = { "dpad", "rstick", "lstick" }
ns.NAV_LABEL = { dpad = "D-pad", rstick = "Right stick", lstick = "Left stick" }

BINDING_HEADER_TARGETPAD = "Targetpad"
_G["BINDING_NAME_" .. ns.HOLD] = "Hold to target"

local PREFIX = "|cffff6b5aTargetpad|r: "
function ns.say(msg)
  print(PREFIX .. msg)
end

-- A log kept in the saved variables (written on /reload or logout).
local early = {}
function ns.log(msg)
  local ok, line = pcall(function()
    return string.format(
      "%s %.1f %s%s",
      date("%H:%M:%S"),
      GetTime(),
      InCombatLockdown() and "[combat] " or "",
      tostring(msg)
    )
  end)
  if not ok then
    line = "(unprintable log line)"
  end
  local db = ns.db
  if not db then
    table.insert(early, line)
    return
  end
  db.log = db.log or {}
  table.insert(db.log, line)
  while #db.log > 400 do
    table.remove(db.log, 1)
  end
end

-- Runs fn after combat if combat locks protected changes now.
local pending = {}
function ns.afterCombat(key, fn)
  if InCombatLockdown() then
    pending[key] = fn
  else
    fn()
  end
end

local DEFAULTS = { nav = "dpad" }

function ns.setupDB()
  TargetpadDB = TargetpadDB or {}
  local db = TargetpadDB
  for k, v in pairs(DEFAULTS) do
    if db[k] == nil then
      db[k] = v
    end
  end
  ns.db = db
  for _, line in ipairs(early) do
    ns.log(line)
  end
  wipe(early)
end

-- A thin outline around a frame: four lines, nothing inside.
function ns.outline(parent, anchor, pad, size)
  local o = CreateFrame("Frame", nil, parent)
  o:SetPoint("TOPLEFT", anchor, "TOPLEFT", -pad, pad)
  o:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", pad, -pad)
  o.lines = {}
  local sides = {
    { "TOPLEFT", "TOPRIGHT", "h" },
    { "BOTTOMLEFT", "BOTTOMRIGHT", "h" },
    { "TOPLEFT", "BOTTOMLEFT", "w" },
    { "TOPRIGHT", "BOTTOMRIGHT", "w" },
  }
  for i, side in ipairs(sides) do
    local t = o:CreateTexture(nil, "OVERLAY")
    t:SetPoint(side[1])
    t:SetPoint(side[2])
    if side[3] == "h" then
      t:SetHeight(size)
    else
      t:SetWidth(size)
    end
    o.lines[i] = t
  end
  function o.SetColor(_, r, g, b, a)
    for _, t in ipairs(o.lines) do
      t:SetColorTexture(r, g, b, a or 1)
    end
  end
  o:Hide()
  return o
end

ns.events = CreateFrame("Frame")
local handlers = {}
function ns.on(event, fn)
  if not handlers[event] then
    handlers[event] = {}
    pcall(ns.events.RegisterEvent, ns.events, event)
  end
  table.insert(handlers[event], fn)
end
ns.events:SetScript("OnEvent", function(_, event, ...)
  for _, fn in ipairs(handlers[event] or {}) do
    local ok, err = pcall(fn, ...)
    if not ok then
      ns.log("ERROR in " .. event .. ": " .. tostring(err))
      geterrorhandler()(err)
    end
  end
end)

ns.on("ADDON_LOADED", function(name)
  if name == ADDON then
    ns.setupDB()
  end
end)

ns.on("PLAYER_REGEN_ENABLED", function()
  local todo = pending
  pending = {}
  for _, fn in pairs(todo) do
    fn()
  end
end)
