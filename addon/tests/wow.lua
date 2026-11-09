-- A fake WoW Forever client for the Targetpad tests. Run with LuaJIT (Lua 5.1).
--
-- It runs the secure snippets in a restricted table that has only the
-- names the real restricted environment gives, and it enforces the combat
-- rule: addon code must not change a secure frame in combat (W.blocked).
-- Health and the like are secret in combat: a compare or a sum with one is
-- an error, as in the client.

local M = {}

local Secret = {}
local function refuse()
  error("attempt to use a secret value", 2)
end
for _, mm in ipairs({
  "__lt",
  "__le",
  "__add",
  "__sub",
  "__mul",
  "__div",
  "__mod",
  "__unm",
  "__concat",
  "__len",
  "__eq",
}) do
  Secret[mm] = refuse
end
local function secret(v)
  return setmetatable({ value = v }, Secret)
end
function M.isSecret(v)
  return type(v) == "table" and getmetatable(v) == Secret
end
local function plain(v)
  if M.isSecret(v) then
    return v.value
  end
  return v
end

function M.new()
  local W = {
    combat = false,
    blocked = {},
    errors = {},
    printed = {},
    casts = {},
    secureBinds = {},
    overrides = {},
    downTarget = {},
    frames = {},
    mods = { shift = false, ctrl = false, alt = false },
    units = {},
    raid = nil,
    book = {},
    talentGroup = 1,
    inSecure = false,
    rangeOut = {},
    now = 100,
    bar = "p1",
    drivers = {},
    actions = {},
    bindList = {},
    barPresses = {},
    cvars = {},
  }
  local G = {}
  W.G = G
  setmetatable(G, { __index = _G })

  local function protectedChange(f, what)
    if W.combat and f.protected and not W.inSecure then
      table.insert(W.blocked, (f.name or "?") .. ":" .. what)
    end
  end

  -- Frames ------------------------------------------------------------
  local Frame = {}
  Frame.__index = function(t, k)
    local m = Frame[k]
    if m then
      return m
    end
    -- A widget method this fake doesn't model is a no-op; fields are nil.
    if type(k) == "string" and k:match("^%u") then
      return function() end
    end
    return nil
  end

  local function newRegion(parent)
    local r = setmetatable({ shown = true, alpha = 1, attrs = {}, scripts = {}, hooks = {}, parent = parent }, Frame)
    return r
  end

  function Frame:GetName()
    return self.name
  end
  function Frame:GetFrameLevel()
    return self._level or 1
  end
  function Frame:SetFrameLevel(l)
    self._level = l
  end
  function Frame:CreateMaskTexture()
    return newRegion(self)
  end
  function Frame:SetFormattedText(fmt, ...)
    local args = {}
    for i = 1, select("#", ...) do
      args[i] = plain((select(i, ...)))
    end
    self.text = fmt:format(unpack(args))
  end
  function Frame:Show()
    protectedChange(self, "Show")
    local was = self.shown
    self.shown = true
    if not was then
      self:RunScript("OnShow")
    end
  end
  function Frame:Hide()
    protectedChange(self, "Hide")
    local was = self.shown
    self.shown = false
    if was then
      self:RunScript("OnHide")
    end
  end
  function Frame:SetShown(v)
    if v then
      self:Show()
    else
      self:Hide()
    end
  end
  function Frame:IsShown()
    return self.shown
  end
  function Frame:IsVisible()
    return self.shown
  end
  function Frame:Click(_, down)
    W.click(self, down)
  end
  function Frame:SetAlpha(a)
    self.alpha = plain(a)
  end
  function Frame:GetAlpha()
    return self.alpha
  end
  function Frame:SetText(t)
    self.text = t
  end
  function Frame:GetText()
    return self.text
  end
  function Frame:SetChecked(v)
    self.checked = v
  end
  function Frame:GetChecked()
    return self.checked
  end
  function Frame:SetPoint(_, rel)
    protectedChange(self, "SetPoint")
    if type(rel) == "table" then
      self.anchor = rel
    end
  end
  function Frame:ClearAllPoints()
    protectedChange(self, "ClearAllPoints")
  end
  function Frame:SetScale(s)
    self.scale = s
  end
  function Frame:SetBackdropBorderColor(r, g, b, a)
    self.border = { r, g, b, a }
  end
  function Frame:SetMinMaxValues(lo, hi)
    self.min, self.max = lo, hi
  end
  function Frame:SetValue(v)
    self.value = v
  end
  function Frame:GetStatusBarTexture()
    self.tex = self.tex or newRegion(self)
    return self.tex
  end
  function Frame:CreateFontString()
    return newRegion(self)
  end
  function Frame:CreateTexture()
    return newRegion(self)
  end
  function Frame:SetScript(name, fn)
    self.scripts[name] = fn
  end
  function Frame:GetScript(name)
    return self.scripts[name]
  end
  function Frame:HookScript(name, fn)
    self.hooks[name] = self.hooks[name] or {}
    table.insert(self.hooks[name], fn)
  end
  function Frame:RegisterEvent(e)
    self.events = self.events or {}
    self.events[e] = true
  end
  function Frame:RegisterForClicks(...)
    self.clicks = { ... }
  end
  function Frame:EnableKeyboard(v)
    self.keyboard = v
  end
  function Frame:RunScript(name, ...)
    if self.scripts[name] then
      self.scripts[name](self, ...)
    end
    for _, fn in ipairs(self.hooks[name] or {}) do
      fn(self, ...)
    end
  end
  function Frame:SetAttribute(k, v)
    protectedChange(self, "SetAttribute " .. tostring(k))
    self.attrs[k] = v
    self:RunScript("OnAttributeChanged", k, v)
  end
  function Frame:GetAttribute(k)
    return self.attrs[k]
  end
  -- Restricted handle methods, used only from snippets.
  function Frame:GetFrameRef(label)
    return self.refs and self.refs[label]
  end
  function Frame:ClearBindings()
    for key, b in pairs(W.secureBinds) do
      if b.owner == self then
        W.secureBinds[key] = nil
      end
    end
  end
  function Frame:ClearBinding(key)
    assert(W.inSecure, "ClearBinding outside a snippet")
    if W.secureBinds[key] and W.secureBinds[key].owner == self then
      W.secureBinds[key] = nil
    end
  end
  function Frame:SetBinding(priority, key, action)
    assert(W.inSecure, "SetBinding outside a snippet")
    W.secureBinds[key] = { owner = self, command = action, priority = priority }
  end
  function Frame:SetBindingClick(priority, key, name)
    assert(W.inSecure, "SetBindingClick outside a snippet")
    W.secureBinds[key] = { owner = self, target = name, priority = priority }
  end

  G.CreateFrame = function(kind, name, parent, template)
    local f = newRegion(parent)
    f.kind, f.name, f.template = kind, name, template or ""
    f.protected = f.template:find("Secure") ~= nil
    if name then
      G[name] = f
    end
    table.insert(W.frames, f)
    return f
  end
  G.UIParent = G.CreateFrame("Frame", "UIParent")
  G.WorldFrame = G.CreateFrame("Frame", "WorldFrame")
  function Frame:SetParent(p)
    self.parent = p
  end
  function Frame:GetScale()
    return self.scale or 1
  end
  G.UISpecialFrames = {}
  G.SlashCmdList = {}

  -- Snippets -------------------------------------------------------------
  local RESTRICTED = {
    tostring = tostring,
    tonumber = tonumber,
    type = type,
    UnitExists = function(u)
      return G.UnitExists(u)
    end,
    UnitIsDead = function(u)
      return G.UnitIsDeadOrGhost(u)
    end,
    SecureCmdOptionParse = function(s)
      if s:find("bonusbar", 1, true) then
        return W.bar
      end
      local u = s:match("^%[@([%w]+),help,nodead%] yes; no$")
      if u then
        local t = W.units[u]
        if u == "target" then
          return (t and t.friendly and not t.dead) and "yes" or "no"
        end
        return (t and t.friendly ~= false and not t.dead) and "yes" or "no"
      end
      error("fake SecureCmdOptionParse doesn't know " .. s)
    end,
  }
  G.SecureCmdOptionParse = function(s)
    return RESTRICTED.SecureCmdOptionParse(s)
  end
  local function runSnippetAs(args, body, env, ...)
    local fn = assert(loadstring("local " .. args .. " = ...\n" .. body))
    setfenv(
      fn,
      setmetatable(env, {
        __index = function(_, k)
          if RESTRICTED[k] ~= nil then
            return RESTRICTED[k]
          end
          error("snippet uses " .. tostring(k) .. ", which the restricted environment lacks", 2)
        end,
        __newindex = function(_, k)
          error("snippet sets global " .. tostring(k), 2)
        end,
      })
    )
    W.inSecure = true
    local out = (function(...)
      return { n = select("#", ...), ... }
    end)(pcall(fn, ...))
    W.inSecure = false
    if not out[1] then
      error(out[2], 0)
    end
    return unpack(out, 2, out.n)
  end
  local function runSnippet(body, env, ...)
    return runSnippetAs("self, button, down", body, env, ...)
  end
  W.runSnippet = runSnippet

  G.SecureHandlerWrapScript = function(frame, script, header, pre, post)
    assert(script == "OnClick")
    if W.combat then
      table.insert(W.blocked, "SecureHandlerWrapScript")
    end
    frame.wrap = { header = header, pre = pre, post = post }
  end
  G.SecureHandlerExecute = function(frame, body)
    if W.combat then
      table.insert(W.blocked, "SecureHandlerExecute")
    end
    runSnippet(body, {}, frame)
  end
  G.RegisterStateDriver = function(frame, name, cond)
    table.insert(W.drivers, { frame = frame, name = name, cond = cond })
    W.inSecure = true
    frame:SetAttribute("state-" .. name, G.SecureCmdOptionParse(cond))
    W.inSecure = false
  end
  -- The bar changes (a form, a page): drivers update and their snippets run.
  function W.setBar(state)
    W.bar = state
    for _, d in ipairs(W.drivers) do
      W.inSecure = true
      d.frame:SetAttribute("state-" .. d.name, G.SecureCmdOptionParse(d.cond))
      W.inSecure = false
      local body = d.frame.attrs["_onstate-" .. d.name]
      if body then
        runSnippet(body, {}, d.frame)
      end
    end
  end
  G.SecureHandlerSetFrameRef = function(frame, label, ref)
    frame.refs = frame.refs or {}
    frame.refs[label] = ref
  end

  -- A click from a binding: the wrap, the template action, then the hooks.
  W.keyDownCvar = true -- the game's ActionButtonUseKeyDown
  function W.click(f, down)
    local message
    if f.wrap then
      local res, msg = runSnippet(f.wrap.pre, { owner = f.wrap.header }, f, "LeftButton", down)
      if res == false then
        for _, fn in ipairs(f.hooks.OnClick or {}) do
          fn(f, "LeftButton", down)
        end
        return
      end
      message = msg
    end
    if f.template:find("SecureActionButtonTemplate") then
      local onDown = f.attrs.useOnKeyDown
      if onDown == nil then
        onDown = W.keyDownCvar
      end
      if (down and onDown) or (not down and not onDown) then
        if f.attrs.type == "macro" then
          W.macro(f.attrs.macrotext)
        else
          local unit = f.attrs.unit
          if unit and unit ~= "none" and not G.UnitExists(unit) then
            return
          end
          table.insert(W.casts, { spell = f.attrs.spell, unit = unit, combat = W.combat })
        end
      end
    elseif f.template:find("SecureHandlerClickTemplate") and down then
      runSnippet(f.attrs._onclick, {}, f, "LeftButton", down)
    elseif not f.template:find("Secure") and down and f.scripts.OnClick then
      f.scripts.OnClick(f, "LeftButton", down) -- a plain button: clicks on the press
    end
    if f.wrap and f.wrap.post and message ~= nil then
      runSnippetAs(
        "self, message, button, down",
        f.wrap.post,
        { owner = f.wrap.header },
        f,
        message,
        "LeftButton",
        down
      )
    end
    for _, fn in ipairs(f.hooks.OnClick or {}) do
      fn(f, "LeftButton", down)
    end
  end

  -- A key press: the controller's bindings first, then the override bindings.
  -- The release goes where the press went.
  function W.key(key, down)
    local target
    if down then
      local b = W.secureBinds[key] or W.overrides[key]
      target = b and b.target
      -- A plain binding to a click: the game clicks that button.
      if not b and W.normalBinds[key] then
        target = W.normalBinds[key]:match("^CLICK (.-):")
      end
      W.downTarget[key] = target
    else
      target = W.downTarget[key]
      W.downTarget[key] = nil
    end
    local b = down and (W.secureBinds[key] or W.overrides[key])
    if b and b.command then
      W.command(b.command)
    elseif target then
      W.click(G[target], down)
    elseif down and W.normalBinds[key] then
      table.insert(W.barPresses, { key = key, command = W.normalBinds[key] })
    end
    return target
  end
  function W.tap(key)
    W.key(key, true)
    W.key(key, false)
  end

  G.SetOverrideBindingClick = function(owner, priority, key, name)
    if W.combat then
      table.insert(W.blocked, "SetOverrideBindingClick " .. key)
    end
    W.overrides[key] = { owner = owner, target = name, priority = priority }
  end
  G.ClearOverrideBindings = function(owner)
    if W.combat then
      table.insert(W.blocked, "ClearOverrideBindings")
    end
    for key, b in pairs(W.overrides) do
      if b.owner == owner then
        W.overrides[key] = nil
      end
    end
  end
  W.normalBinds = {}
  G.GetBindingAction = function(key, override)
    local o = override and (W.secureBinds[key] or W.overrides[key])
    if o then
      return o.command or ("CLICK " .. o.target .. ":LeftButton")
    end
    return W.normalBinds[key] or ""
  end
  G.GetBindingText = function(key)
    return key
  end
  -- W.bindList: { { command, key1, key2 } }; W.normalBinds follows it.
  function W.bind(command, ...)
    table.insert(W.bindList, { command, ... })
    for _, k in ipairs({ ... }) do
      W.normalBinds[k] = command
    end
  end
  G.GetNumBindings = function()
    return #W.bindList
  end
  G.GetBinding = function(i)
    local b = W.bindList[i]
    return b[1], "BINDING_HEADER_X", unpack(b, 2)
  end
  G.GetActionInfo = function(slot)
    local a = W.actions[slot]
    if a then
      return a[1], a[2]
    end
  end
  G.GetMacroSpell = function()
    return nil
  end
  G.C_CVar = {
    GetCVar = function(k)
      return W.cvars[k]
    end,
  }

  -- Units ---------------------------------------------------------------
  local function hidden(v)
    if W.combat then
      return secret(v)
    end
    return v
  end
  G.UnitExists = function(u)
    return u ~= nil and W.units[u] ~= nil
  end
  G.UnitName = function(u)
    local x = W.units[u]
    return x and x.name
  end
  G.UnitIsUnit = function(a, b)
    local base = a ~= "target" and a:match("^(.+)target$")
    if base then
      local x = W.units[base]
      return x ~= nil and x.onYou == true and b == "player"
    end
    return W.units[a] ~= nil and W.units[a] == W.units[b]
  end
  G.UnitCanAttack = function(_, u)
    return W.units[u] ~= nil and W.units[u].hostile == true
  end
  G.UnitClassification = function(u)
    return W.units[u] and W.units[u].class or "normal"
  end
  G.UnitCastingInfo = function(u)
    local x = W.units[u]
    if x and x.casting then
      return hidden(x.casting)
    end
  end
  G.C_NamePlate = {
    -- Any unit token works, as in the game ("target" finds its plate).
    GetNamePlateForUnit = function(u)
      if W.plates[u] then
        return W.plates[u]
      end
      for k, p in pairs(W.plates) do
        if W.units[u] ~= nil and W.units[k] == W.units[u] then
          return p
        end
      end
      return nil
    end,
  }
  -- Enemies nearest first, by nameplate unit; the game's next and previous
  -- enemy commands step along them.
  W.enemies, W.plates, W.commands, W.macros = {}, {}, {}, {}
  function W.addEnemy(unit, data)
    data.hostile = true
    W.units[unit] = data
    table.insert(W.enemies, unit)
    W.plates[unit] = G.CreateFrame("Frame", nil, G.UIParent)
    W.fire("NAME_PLATE_UNIT_ADDED", unit)
  end
  local function targetIndex()
    for i, u in ipairs(W.enemies) do
      if W.units.target ~= nil and W.units[u] == W.units.target then
        return i
      end
    end
  end
  local function setTarget(u)
    W.units.target = u and W.units[u] or nil
    W.fire("PLAYER_TARGET_CHANGED")
  end
  function W.command(c)
    table.insert(W.commands, c)
    local n = #W.enemies
    if n == 0 then
      return
    end
    local i = targetIndex()
    if c == "TARGETNEARESTENEMY" then
      setTarget(W.enemies[i and (i % n + 1) or 1])
    elseif c == "TARGETPREVIOUSENEMY" then
      setTarget(W.enemies[i and ((i - 2) % n + 1) or n])
    end
  end
  function W.macro(text)
    table.insert(W.macros, text)
    if text == "/targetenemy [noharm][dead]" then
      local t = W.units.target
      if not (t and t.hostile and not t.dead) then
        W.command("TARGETNEARESTENEMY")
      end
    end
  end
  -- The player's own bindings (the game's Key Bindings menu).
  W.saves = 0
  G.SetBinding = function(key, action)
    if W.combat then
      table.insert(W.blocked, "SetBinding " .. key)
    end
    W.normalBinds[key] = action
    W.fire("UPDATE_BINDINGS")
  end
  G.GetBindingKey = function(action)
    local keys = {}
    for k, a in pairs(W.normalBinds) do
      if a == action then
        table.insert(keys, k)
      end
    end
    table.sort(keys)
    return unpack(keys)
  end
  G.SaveBindings = function()
    W.saves = W.saves + 1
  end
  G.GetCurrentBindingSet = function()
    return 2
  end
  G.UnitHealth = function(u)
    return hidden(W.units[u] and W.units[u].hp or 0)
  end
  G.UnitHealthMax = function(u)
    return hidden(W.units[u] and W.units[u].max or 1)
  end
  G.UnitGetIncomingHeals = function(u)
    return hidden(W.units[u] and W.units[u].incoming or 0)
  end
  G.UnitGroupRolesAssigned = function(u)
    return W.units[u] and W.units[u].role or "NONE"
  end
  G.UnitIsConnected = function(u)
    return not (W.units[u] and W.units[u].offline)
  end
  G.UnitIsDeadOrGhost = function(u)
    return W.units[u] and W.units[u].dead or false
  end
  G.GetPartyAssignment = function(what, u)
    return what == "MAINTANK" and W.units[u] and W.units[u].mainTank or false
  end
  G.UnitLevel = function(u)
    return W.units[u] and (W.units[u].level or 60) or 0
  end
  G.UnitPower = function(u)
    return hidden(W.units[u] and W.units[u].power or 50)
  end
  G.UnitPowerMax = function(u)
    return hidden(100)
  end
  G.UnitPowerType = function()
    return 0, "MANA"
  end
  G.PowerBarColor = { MANA = { r = 0, g = 0, b = 1 } }
  G.SetPortraitTexture = function(tex, unit)
    tex.portrait = unit
  end
  G.IsInRaid = function()
    return W.raid ~= nil
  end
  G.IsInGroup = function()
    return W.raid ~= nil or W.units.party1 ~= nil
  end
  G.GetNumGroupMembers = function()
    return W.raid and #W.raid or 0
  end
  G.GetNumSubgroupMembers = function()
    local n = 0
    for i = 1, 4 do
      if W.units["party" .. i] then
        n = i
      end
    end
    return n
  end
  G.GetRaidRosterInfo = function(i)
    local r = W.raid[i]
    return r.name, 0, r.group
  end

  -- Spells ----------------------------------------------------------------
  G.Enum =
    { SpellBookSpellBank = { Player = 0 }, SpellBookItemType = { Spell = 1, Flyout = 4 }, LuaCurveType = { Step = 1 } }
  G.C_SpellBook = {
    GetNumSpellBookSkillLines = function()
      return 1
    end,
    GetSpellBookSkillLineInfo = function()
      return { itemIndexOffset = 0, numSpellBookItems = #W.book, shouldHide = false }
    end,
    GetSpellBookItemInfo = function(slot)
      local s = W.book[slot]
      return { spellID = s.id, actionID = s.id, itemType = s.kind or 1, name = s.name, subName = s.sub or "" }
    end,
    IsSpellBookItemHelpful = function(slot)
      return W.book[slot].helpful == true
    end,
  }
  local function spell(id)
    for _, s in ipairs(W.book) do
      if s.id == id then
        return s
      end
    end
  end
  G.C_Spell = {
    GetSpellName = function(id)
      local s = spell(id)
      return s and s.name
    end,
    GetSpellSubtext = function(id)
      local s = spell(id)
      return s and s.sub
    end,
    GetSpellTexture = function()
      return 136041
    end,
    IsSpellHelpful = function(id)
      local s = spell(id)
      return s and s.helpful or false
    end,
    SpellHasRange = function(id)
      local s = spell(id)
      return s ~= nil and s.selfOnly ~= true
    end,
    GetSpellInfo = function(name)
      for _, s in ipairs(W.book) do
        if s.name == name then
          return { spellID = s.id }
        end
      end
    end,
    IsSpellInRange = function(_, unit)
      if W.rangeOut[unit] then
        return hidden(false)
      end
      return hidden(true)
    end,
  }
  G.C_UnitAuras = {
    GetAuraDataByIndex = function(unit)
      local d = W.units[unit] and W.units[unit].debuff
      return d and { auraInstanceID = 7, dispelName = d } or nil
    end,
    GetAuraDispelTypeColor = function()
      return {
        GetRGBA = function()
          return 0.2, 0.6, 1, 1
        end,
      }
    end,
  }
  G.C_CurveUtil = {
    CreateColorCurve = function()
      return { SetType = function() end, AddPoint = function() end }
    end,
  }
  G.CreateColor = function(r, g, b, a)
    return {
      GetRGBA = function()
        return r, g, b, a
      end,
    }
  end

  -- The rest -----------------------------------------------------------------
  G.InCombatLockdown = function()
    return W.combat
  end
  G.GetTime = function()
    return W.now
  end
  G.C_SpecializationInfo = {
    GetActiveSpecGroup = function()
      return W.talentGroup
    end,
  }
  G.IsShiftKeyDown = function()
    return W.mods.shift
  end
  G.IsControlKeyDown = function()
    return W.mods.ctrl
  end
  G.IsAltKeyDown = function()
    return W.mods.alt
  end
  G.print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    table.insert(W.printed, table.concat(parts, " "))
  end
  G._G = G
  W.timers, W.shots, W.reloaded = {}, 0, false
  G.C_Timer = {
    After = function(_, fn)
      table.insert(W.timers, fn)
    end,
  }
  function W.runTimers()
    while #W.timers > 0 do
      table.remove(W.timers, 1)()
    end
  end
  G.Screenshot = function()
    W.shots = W.shots + 1
  end
  G.ReloadUI = function()
    W.reloaded = true
  end
  G.GetBuildInfo = function()
    return "1.60.1"
  end
  G.date = os.date
  local handler = function(e)
    table.insert(W.errors, e)
  end
  G.geterrorhandler = function()
    return handler
  end
  G.seterrorhandler = function(fn)
    handler = fn
  end
  G.wipe = function(t)
    for k in pairs(t) do
      t[k] = nil
    end
    return t
  end

  function W.fire(event, ...)
    for _, f in ipairs(W.frames) do
      if f.events and f.events[event] and f.scripts.OnEvent then
        f.scripts.OnEvent(f, event, ...)
      end
    end
  end
  function W.update(elapsed)
    W.now = W.now + elapsed
    for _, f in ipairs(W.frames) do
      if f.scripts.OnUpdate then
        f.scripts.OnUpdate(f, elapsed)
      end
    end
  end

  function W.load(dir, files, saved)
    local ns = {}
    G.TargetpadDB = saved
    for _, file in ipairs(files) do
      local fn = assert(loadfile(dir .. "/" .. file))
      setfenv(fn, G)
      fn("Targetpad", ns)
    end
    W.ns = ns
    W.fire("ADDON_LOADED", "Targetpad")
    W.fire("PLAYER_LOGIN")
    return ns
  end
  return W
end

return M
