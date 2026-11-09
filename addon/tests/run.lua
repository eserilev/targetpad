-- The Targetpad tests. Run from the repo root: luajit addon/tests/run.lua
package.path = "addon/tests/?.lua;" .. package.path
local Wow = require("wow")

local FILES = { "Core.lua", "Secure.lua", "Arrow.lua", "Options.lua", "Test.lua", "Showcase.lua" }
local DIR = "addon/Targetpad"

local passed, failed = 0, 0
local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL " .. name .. "\n  " .. tostring(err))
  end
end
local function eq(a, b, what)
  if a ~= b then
    error((what or "value") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2)
  end
end
local function clean(W)
  eq(#W.blocked, 0, "blocked: " .. table.concat(W.blocked, ", "))
  eq(#W.errors, 0, "errors: " .. table.concat(W.errors, " | "))
end

-- Three enemies nearest first, the hold button on LB, the d-pad navigates.
local function game(opts)
  opts = opts or {}
  local W = Wow.new()
  W.units.player = { name = "Me", hp = 90, max = 100 }
  W.normalBinds.PADLSHOULDER = "CLICK TargetpadHold:LeftButton"
  W.normalBinds.PADDRIGHT = "ACTIONBUTTON5"
  local ns = W.load(DIR, FILES, opts.saved or { nav = opts.nav or "dpad" })
  if opts.enemies ~= false then
    W.addEnemy(
      "nameplate1",
      { name = "Defias Pillager", level = 18, hp = 72, max = 100, onYou = true, casting = "Fireball" }
    )
    W.addEnemy("nameplate2", { name = "Defias Thug", level = 17, hp = 100, max = 100 })
    W.addEnemy("nameplate3", { name = "Defias Highwayman", level = 19, hp = 100, max = 100, class = "elite" })
  end
  return W, ns
end
local function targetName(W)
  return W.units.target and W.units.target.name
end

test("hold: the press targets the nearest enemy; the d-pad steps; letting go keeps it", function()
  local W, ns = game()
  W.combat = true
  W.key("PADLSHOULDER", true)
  eq(targetName(W), "Defias Pillager", "nearest on the press")
  W.tap("PADDRIGHT")
  eq(targetName(W), "Defias Thug", "next")
  W.tap("PADDRIGHT")
  eq(targetName(W), "Defias Highwayman", "next again")
  W.tap("PADDLEFT")
  eq(targetName(W), "Defias Thug", "previous")
  W.tap("RIGHT")
  eq(targetName(W), "Defias Highwayman", "the arrow keys step too")
  W.key("PADLSHOULDER", false)
  eq(targetName(W), "Defias Highwayman", "kept")
  eq(W.secureBinds.PADDRIGHT, nil, "the d-pad is given back")
  W.tap("PADDRIGHT")
  eq(W.barPresses[#W.barPresses].command, "ACTIONBUTTON5", "the d-pad does what you bound")
  eq(ns.isHeld(), false)
  clean(W)
end)

test("a living enemy target stays on the press; a dead one is replaced", function()
  local W = game()
  W.units.target = W.units.nameplate3
  W.key("PADLSHOULDER", true)
  eq(targetName(W), "Defias Highwayman", "kept")
  W.key("PADLSHOULDER", false)
  W.units.nameplate3.dead = true
  W.key("PADLSHOULDER", true)
  eq(targetName(W), "Defias Pillager", "a dead target is replaced")
  W.key("PADLSHOULDER", false)
  clean(W)
end)

test("nav: the right stick, the left stick; a modifier held still steps", function()
  local W, ns = game({ nav = "rstick" })
  W.combat = true
  W.key("PADLSHOULDER", true)
  W.tap("PADRSTICKRIGHT")
  eq(targetName(W), "Defias Thug", "right stick")
  eq(W.secureBinds.PADDRIGHT, nil, "the d-pad isn't taken")
  W.tap("SHIFT-PADRSTICKRIGHT")
  eq(targetName(W), "Defias Highwayman", "with Shift held")
  W.key("PADLSHOULDER", false)
  W.combat = false
  ns.db.nav = "lstick"
  ns.applyNav()
  W.key("PADLSHOULDER", true)
  W.tap("PADLSTICKLEFT")
  eq(targetName(W), "Defias Thug", "left stick")
  W.key("PADLSHOULDER", false)
  clean(W)
end)

test("arrow: only while held, over the target's nameplate; it follows the target, and fades on release", function()
  local W, ns = game()
  W.combat = true
  W.update(0.5)
  eq(ns.arrow:IsShown(), false, "no arrow before the hold")
  W.key("PADLSHOULDER", true)
  W.update(0.3)
  eq(ns.arrow:IsShown(), true, "the arrow while held")
  eq(ns.arrow.anchor, W.plates.nameplate1, "over the target's plate")
  W.tap("PADDRIGHT")
  W.update(0.2)
  eq(ns.arrow.anchor, W.plates.nameplate2, "it moves with the target")
  W.key("PADLSHOULDER", false)
  W.update(1)
  eq(ns.arrow:IsShown(), false, "gone after the fade")
  clean(W)
end)

test("arrow: the target's plate leaves the screen, the arrow goes too", function()
  local W, ns = game()
  W.key("PADLSHOULDER", true)
  W.update(0.3)
  W.plates.nameplate1 = nil
  W.fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
  W.update(0.1)
  eq(ns.arrow:IsShown(), false)
  W.key("PADLSHOULDER", false)
  clean(W)
end)

test("settings: arrow size and color; a live arrow beside the window while it's open", function()
  local W, ns = game({ enemies = false })
  ns.openOptions()
  W.update(0.2)
  eq(ns.arrow:IsShown(), true, "a preview arrow while the window is open")
  local d = ns.optionsDebug()
  d.ui.plus:Click("LeftButton", true)
  d.ui.plus:Click("LeftButton", true)
  eq(ns.db.arrowScale, 1.2, "bigger")
  eq(ns.arrow.scale, 1.2, "the arrow grew")
  for _ = 1, 20 do
    d.ui.minus:Click("LeftButton", true)
  end
  eq(ns.db.arrowScale, 0.6, "smallest is 60%")
  d.ui.swatches[3]:Click("LeftButton", true)
  eq(ns.db.arrowColor, "green")
  eq(d.ui.swatches[3].ring:IsShown(), true, "the green swatch is marked")
  eq(d.ui.swatches[1].ring:IsShown(), false, "gold is not")
  eq(d.ui.size:GetText(), "60%", "the size shows")
  eq(ns.arrow.anchor ~= nil, true, "the preview arrow sits beside the window")
  W.G.TargetpadOptions:Hide()
  W.update(1)
  eq(ns.arrow:IsShown(), false, "the preview goes with the window")
  clean(W)
end)

test("settings: Set takes the next key or pad button into the game's bindings; Clear unbinds", function()
  local W, ns = game()
  ns.openOptions()
  local d = ns.optionsDebug()
  eq(d.ui.key:GetText(), "LB", "shows the bound key")
  W.click(d.ui.key, true)
  eq(d.capturing(), true, "waits for a button")
  eq(d.ui.key:GetText(), "Press a button")
  d.panel.scripts.OnGamePadButtonDown(d.panel, "PADRSHOULDER")
  eq(W.normalBinds.PADRSHOULDER, ns.HOLD, "bound in the game")
  eq(W.normalBinds.PADLSHOULDER, nil, "the old key let go")
  assert(W.saves > 0, "saved")
  eq(d.ui.key:GetText(), "RB")
  W.click(d.ui.key, true)
  W.mods.shift = true
  d.panel.scripts.OnKeyDown(d.panel, "Q")
  W.mods.shift = false
  eq(W.normalBinds["SHIFT-Q"], ns.HOLD, "a key with a modifier")
  eq(d.ui.key:GetText(), "Shift+Q")
  W.click(d.ui.key, true)
  d.panel.scripts.OnKeyDown(d.panel, "ESCAPE")
  eq(d.capturing(), false, "Escape stops waiting")
  eq(W.normalBinds["SHIFT-Q"], ns.HOLD, "and changes nothing")
  W.click(d.ui.clear, true)
  eq(ns.holdKey(), nil, "cleared")
  eq(d.ui.key:GetText(), "Not set")
  clean(W)
end)

test("settings: Navigate with picks the keys the next hold borrows", function()
  local W, ns = game()
  ns.openOptions()
  local d = ns.optionsDebug()
  W.click(d.ui.navs[2], true)
  eq(ns.db.nav, "rstick")
  W.key("PADLSHOULDER", true)
  eq(W.secureBinds.PADRSTICKRIGHT and W.secureBinds.PADRSTICKRIGHT.command, "TARGETNEARESTENEMY")
  eq(W.secureBinds.PADDRIGHT, nil)
  W.key("PADLSHOULDER", false)
  clean(W)
end)

test("settings: Esc closes; the window closes in combat and won't open in it", function()
  local W, ns = game()
  ns.openOptions()
  W.tap("ESCAPE")
  eq(W.G.TargetpadOptions:IsShown(), false, "Esc")
  eq(W.overrides.ESCAPE, nil, "Esc is the game's again")
  ns.openOptions()
  W.fire("PLAYER_REGEN_DISABLED")
  eq(W.G.TargetpadOptions:IsShown(), false, "closed at the pull")
  W.combat = true
  ns.openOptions()
  eq(W.G.TargetpadOptions:IsShown(), false, "not in combat")
  clean(W)
end)

test("a nav change in combat waits for the end of combat", function()
  local W, ns = game()
  W.combat = true
  ns.db.nav = "lstick"
  ns.applyNav()
  eq(#W.blocked, 0, "nothing protected changed in combat")
  W.key("PADLSHOULDER", true)
  eq(W.secureBinds.PADDRIGHT ~= nil, true, "still the d-pad")
  W.key("PADLSHOULDER", false)
  W.combat = false
  W.fire("PLAYER_REGEN_ENABLED")
  W.key("PADLSHOULDER", true)
  eq(W.secureBinds.PADLSTICKRIGHT ~= nil, true, "the left stick after combat")
  W.key("PADLSHOULDER", false)
  clean(W)
end)

test("/tp test runs in the game and logs no failure", function()
  local W, ns = game()
  W.G.SlashCmdList.TARGETPAD("test")
  local log = table.concat(ns.db.log, "\n")
  eq(log:find("TEST FAIL") == nil, true, log)
  eq(log:find("LUA ERROR") == nil, true, log)
  eq(log:find("TEST done: %d+ ok, 0 failed") ~= nil, true, log)
  eq(ns.isHeld(), false, "let go after")
  clean(W)
end)

test("/tp shots: you hold and step; a screenshot per target, then the settings; the UI comes back", function()
  local W, ns = game()
  W.G.SlashCmdList.TARGETPAD("shots")
  eq(W.shots, 0, "nothing until you hold")
  W.key("PADLSHOULDER", true)
  eq(W.G.UIParent:IsShown(), false, "the interface hides while you hold")
  W.runTimers()
  eq(W.shots, 1, "the first target")
  W.tap("PADDRIGHT")
  W.runTimers()
  W.tap("PADDRIGHT")
  W.runTimers()
  eq(W.shots, 3, "one per target")
  W.key("PADLSHOULDER", false)
  W.runTimers()
  eq(W.shots, 4, "and the settings window")
  eq(W.G.UIParent:IsShown(), true, "the UI is back")
  eq(W.G.TargetpadOptions:IsShown(), false, "the window closed")
  -- a hold without /tp shots takes none
  W.key("PADLSHOULDER", true)
  W.runTimers()
  W.key("PADLSHOULDER", false)
  W.runTimers()
  eq(W.shots, 4, "no shots outside /tp shots")
  clean(W)
end)

test("/tp shots: combat puts the interface back", function()
  local W, ns = game()
  W.G.SlashCmdList.TARGETPAD("shots")
  W.key("PADLSHOULDER", true)
  W.fire("PLAYER_REGEN_DISABLED")
  eq(W.G.UIParent:IsShown(), true)
  W.key("PADLSHOULDER", false)
  clean(W)
end)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
