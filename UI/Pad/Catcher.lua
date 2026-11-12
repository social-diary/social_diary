-- Who has the pad: the scopes (a window, a page, a popup over it) and the
-- one frame per window that takes the pad's buttons for them
-- (.claude/controller-plan.md, the catcher).
--
--   Pad.RegisterScope(key, {
--       host   = function() return frame end,  the window it lives on (nil:
--                                               not made yet)
--       active = function() return bool end,   it wants the pad now
--       layer  = 10,          of the active scopes, the highest has the pad
--       parent = "journal",   optional: what it does not take goes on to its
--                             parent (the book turns its ribbons whatever page)
--       build  = function(focus, scope),  optional: fills its focus model
--                             (UI/Pad/Focus.lua) each time it is refreshed
--       keys   = { PADLSHOULDER = function(scope) end, ... },  presses it
--                             takes (false back: it did not after all)
--       back   = function(scope) return handled end,  B, on its release
--       legend = function(scope) return { { "PAD1", "Choose" }, ... } end,
--       stick  = function(scope, stick, x, y, len, elapsed) return taken end,
--                             optional: a stick (its config name, "Right" or
--                             "Camera" for the right one), past the deadzone
--                             and measured from it (x, y, len 0..1). Asked
--                             with elapsed 0 when it leaves the deadzone
--                             (true: it is this scope's, nothing moves yet),
--                             then every frame it is held, with the seconds
--                             since the last one, to move by. Only a top
--                             scope (or a parent of it) with `stick` gets
--                             the sticks turned on at all; a scope may
--                             set or clear it in `build` (the sticks follow
--                             at that refresh), to ask only on one page.
--       slip   = function(scope, w) return { frame, x, y, level } end,
--                             optional: where the prompts' slip (w wide)
--                             lies, if not under the host's foot (a host
--                             that is the whole screen: the run's table,
--                             UI/Dungeon/Pad.lua). Pad.Look's Legend `under`
--   })
--   Pad.Refresh()   after anything that may change which scope has the pad
--                   or what is on it (a page turned, a section shown)
--   Pad.Top()       the scope that has the pad, or nil
--
-- The D-pad moves the focus and A presses it, for the top scope with a
-- focus model; its parents' keys come after its own. A catcher that is on
-- takes EVERY press and stick, and never passes one on (the handler never
-- returns true): a press passed on from our handler runs the game's
-- binding tainted by us (the client, 12 Nov 2026: GAMEPADACTIONBUTTON6 and
-- GAMEPADRIGHTTARGETMODIFIER ran tainted, wrote tainted values into the
-- target markers and the buff frame, and the game errored on secret values
-- until /reload; the Escape stand-in passed on got SetPreferredGamepad-
-- InteractTarget forbidden). So with the book holding the pad, the pad
-- does not move the character or use the action bars. In combat the pad
-- is the game's: every catcher is off (the book stays open for the mouse),
-- and it comes back to the book when combat ends. The button that stands
-- in for Escape (GamePadEmulateEsc) is taken too, and on its release our
-- windows in UISpecialFrames are hidden from here, as the game's Escape
-- would. A button set up as Shift, Ctrl or Alt does something only for a
-- scope that names it in `keys`.
--
-- Only path B of the API guide (§6): EnableGamePadButton on frames of our
-- own, which are not protected, so it is allowed in combat; no override
-- bindings, and nothing of Blizzard's Gamepad UI is called (the plan's
-- override rule: it taints window closing).

local addonName, ns = ...

local Pad = ns.UI.Pad
local Input, Focus, Look = Pad.Input, Pad.Focus, Pad.Look

local scopes = ns.Registry.New({
    what = "Pad.RegisterScope(key, { host, active, layer, parent, build, keys, back, legend })",
    order = "layer",
    default = 0,
    check = function(key, spec)
        return type(spec.host) == "function" and type(spec.active) == "function"
            and (spec.build == nil or type(spec.build) == "function")
            and (spec.keys == nil or type(spec.keys) == "table")
            and (spec.back == nil or type(spec.back) == "function")
            and (spec.legend == nil or type(spec.legend) == "function")
            and (spec.parent == nil or type(spec.parent) == "string")
            and (spec.stick == nil or type(spec.stick) == "function")
            and (spec.slip == nil or type(spec.slip) == "function")
    end,
})

local DIRS = { PADDUP = "UP", PADDDOWN = "DOWN", PADDLEFT = "LEFT", PADDRIGHT = "RIGHT" }
Pad.DIRS = DIRS
local BACK = "PAD2"
local REPEAT_FIRST, REPEAT_EVERY = 0.35, 0.2
-- A stick nearer its middle than this is let go (the API guide's §6: about
-- 0.2 unless the pad's config says); what a scope is given is measured from
-- here, so its slowest is just past it, not a jump to a fifth of the way.
local DEADZONE = 0.2
Pad.DEADZONE = DEADZONE

function Pad.RegisterScope(key, spec)
    scopes:Add(key, spec)
end

-- Something laid on a page that is not the page's own (a hint's slip, the
-- introduction's example strip, step 7b): each join is asked, after the
-- top scope has filled its focus and before the pad goes back where it
-- was, whether it has something to add (Pad.JoinAside). It never moves
-- the pad by itself: what it adds is reached by going right off the edge
-- of the page's groups, as it lies at the book's fore-edge.
--   Pad.RegisterJoin(key, { join = function(focus, top) end })
local joins = ns.Registry.New({
    what = "Pad.RegisterJoin(key, { join = function(focus, top) end })",
    check = function(_, spec) return type(spec.join) == "function" end,
})
function Pad.RegisterJoin(key, spec)
    joins:Add(key, spec)
end

-- An item of its own (`item`) in group `name` of focus `f`, joined at the
-- right edge: every group of the page that has no way right goes right to
-- it, and left from it (or B, unless the item says `back`) goes back to
-- the group the pad came from. While the pad stands on it, it is the
-- item's alone: the D-pad moves, A is its `press`, B its `back`, its
-- prompts its `legend()`; the page's own keys and prompts wait (its
-- parents' still count: the shoulders turn the page). The page's opts
-- are copied, never written into.
function Pad.JoinAside(f, name, item)
    item.own = true
    for _, other in ipairs(f.order) do
        local g = f.groups[other]
        if other ~= name and other ~= "title" and #g.items > 0 and g.opts.right == nil then
            local opts = {}
            for k, v in pairs(g.opts) do opts[k] = v end
            opts.right = name
            g.opts = opts
        end
    end
    f:Group(name, { mode = "list", left = function(m) return m.from end })
    f:Add(name, item)
    f.asides = f.asides or {}
    f.asides[name] = true
    return item
end

-- The pad put on aside `name` (asked for by the player's own press, never
-- by the aside coming): its way back the group it was in, else the
-- page's first that has anything.
function Pad.LandAside(f, name)
    local from = f.group ~= name and f.group or f.from
    if not (from and f.groups[from] and #f.groups[from].items > 0) then
        from = nil
        for _, other in ipairs(f.order) do
            if other ~= name and other ~= "title" and #f.groups[other].items > 0 then
                from = other
                break
            end
        end
    end
    f.from = from
    f:Within(name)
end

-- The item of its own the pad stands on in `scope`, if it does.
local function Aside(scope)
    local at = scope and scope.focus and scope.focus:Current()
    return at and at.own and at or nil
end

function Pad.Scope(key) return scopes:Get(key) end

local function Host(scope)
    local host = scope.host()
    return host
end

local function Wants(scope)
    local host = Host(scope)
    return host ~= nil and host:IsVisible() and scope.active(scope) and true or false
end

-- Something not ours has the pad (a Blizzard popup asked from the book,
-- which Forever's Gamepad UI drives itself): while any owner says so, no
-- scope has the pad and every catcher is off, so its presses reach it.
local aside = {}
function Pad.Aside(owner, on)
    aside[owner] = on and true or nil
    Pad.Refresh()
end

-- (Unused since 8 Nov 2026: Forever's Gamepad UI did not drive such a
-- menu in the client, so the pad opens its own instead, Pad.Menu in
-- UI/Pad/Menu.lua. Kept for anything that must still open Blizzard's.)
-- A Blizzard menu (MenuUtil's context menu: the People page's sort and
-- filter, the map sheet's "Show map") opened by an A press: the pad steps
-- aside while it is open, so Forever's Gamepad UI (or the Escape stand-in)
-- has it, and comes back as it closes. Blizzard's menu manager is only
-- read, never called into otherwise (the plan's override rule); without it
-- (an older client, the tests' mock) nothing steps aside.
local function MenuOpen()
    local menu = _G.Menu
    local manager = menu and menu.GetManager and menu.GetManager()
    return manager ~= nil and manager.GetOpenMenu ~= nil and manager:GetOpenMenu() ~= nil
end
local menuWatch
function Pad.MenuAside()
    if not MenuOpen() then return false end
    menuWatch = menuWatch or CreateFrame("Frame")
    Pad.menuWatch = menuWatch   -- (for the tests)
    menuWatch:SetScript("OnUpdate", function(self)
        if MenuOpen() then return end
        self:SetScript("OnUpdate", nil)
        Pad.Aside("menu", nil)
    end)
    Pad.Aside("menu", true)
    return true
end

-- A window outside the book that the player opened, or that opened from
-- their action (the Remember key, a menu's line, /sd pick, a pick in the
-- picker): it may take the pad while it is shown, and gives it back the
-- moment it hides (UI/Windows/Pad.lua, step 7a). A window shown any other
-- way (a toast, something the game or another addon did) never takes it:
-- its scope asks Pad.Owns. Of several such windows shown, the one opened
-- last has the pad; it put away, the one before has it again.
--   Pad.Opened(frame)  call after showing it, from the player's path
--   Pad.Owns(frame)    it is shown, the player opened it, and none opened
--                      since is still shown
local opened, openings = setmetatable({}, { __mode = "k" }), 0
function Pad.Opened(frame)
    if not frame then return end
    if opened[frame] == nil then
        frame:HookScript("OnHide", function(self) opened[self] = false end)
    end
    openings = openings + 1
    opened[frame] = openings
    Pad.Refresh()
end

function Pad.Owns(frame)
    local n = frame and opened[frame]
    if not (n and frame:IsShown()) then return false end
    for other, m in pairs(opened) do
        if other ~= frame and m and m > n and other:IsShown() then return false end
    end
    return true
end

-- Which opening of `frame` is shown (a number, new each time it is opened),
-- or nil: a scope lands afresh when it changes.
function Pad.Opening(frame) return frame and opened[frame] or nil end

-- The top active scope: the highest layer, the last registered of equals.
function Pad.Top()
    if next(aside) then return nil end
    local list = scopes:Ordered()
    for i = #list, 1, -1 do
        if Wants(list[i]) then return list[i] end
    end
end

-- The scope, then its parents.
local function Chain(scope)
    local out, seen = {}, {}
    while scope and not seen[scope] do
        seen[scope] = true
        out[#out + 1] = scope
        scope = scope.parent and scopes:Get(scope.parent)
    end
    return out
end

local function Claims(scope, key)
    for _, s in ipairs(Chain(scope)) do
        if s.keys and s.keys[key] then return true end
    end
    return false
end

-- The buttons set up as modifiers, and as Escape.
local function Emulated(key)
    for _, name in ipairs({ "GamePadEmulateShift", "GamePadEmulateCtrl", "GamePadEmulateAlt" }) do
        if Pad.CVar(name) == key then return true end
    end
    return false
end
local function IsEscape(key)
    local esc = Pad.CVar("GamePadEmulateEsc")
    if esc == nil then esc = "PADBACK" end
    return esc == key
end

local function FocusOf(scope)
    if not scope.build then return nil end
    if not scope.focus then
        scope.focus = Focus.New({
            -- (marked during a press: the pen draws the box in)
            mark = function(item) Look.Mark(Host(scope), item, Pad.pressing) end,
            unmark = function(item) Look.Unmark(Host(scope), item) end,
            step = function(item, dir) Look.Step(Host(scope), item, dir) end,
        })
    end
    return scope.focus
end

--------------------------------------------------------------------------
-- What a press does
--------------------------------------------------------------------------

-- The chain's prompts, the top scope's first; a key a scope above has
-- already named is not named again (B is "Back" on a page that takes it,
-- not "Close the book" as well).
local function Legend(scope)
    local entries, named = {}, {}
    local own = Aside(scope)
    for i, s in ipairs(Chain(scope)) do
        local fn = s.legend
        -- (an item of its own speaks for the top scope)
        if own and i == 1 then fn = own.legend and function() return own.legend() end end
        if fn then
            for _, e in ipairs(fn(s) or {}) do
                local key = type(e[1]) == "table" and e[1][1] or e[1]
                if not named[key] then
                    named[key] = true
                    entries[#entries + 1] = e
                end
            end
        end
    end
    return entries
end
Pad.Legend = Legend

local function ShowLegend(scope)
    if not (scope and Input.Active()) then return end
    local under = scope.slip and function(w) return scope.slip(scope, w) end
    Look.Legend(Host(scope), Legend(scope), under)
end

-- A press down: true when a scope took it.
local function Dispatch(scope, key)
    local own = Aside(scope)
    if own then
        if DIRS[key] then
            scope.focus:Move(DIRS[key])
            return true
        end
        if key == "PAD1" then
            scope.focus:Press()
            return true
        end
    end
    for i, s in ipairs(Chain(scope)) do
        local fn = not (own and i == 1) and s.keys and s.keys[key]
        if fn and fn(s) ~= false then return true end
        -- (a focus with nothing on it takes nothing: the press goes on)
        local focus = s.focus and s.focus:Current() and s.focus
        if focus and DIRS[key] then
            focus:Move(DIRS[key])
            return true
        end
        if focus and key == "PAD1" and focus:Press() then return true end
    end
    return false
end
Pad.Dispatch = Dispatch

-- The scope of the chain that takes sticks, if any.
local function Sticky(scope)
    for _, s in ipairs(Chain(scope)) do
        if s.stick then return s end
    end
end

local function Back(scope)
    local own = Aside(scope)
    if own then
        if not (own.back and own.back()) then
            local f = scope.focus
            if f.from then f:EnterGroup(f.from) end
        end
        return true
    end
    for _, s in ipairs(Chain(scope)) do
        if s.back and s.back(s) then return true end
    end
    return false
end
Pad.Back = Back

--------------------------------------------------------------------------
-- The catchers: one frame per window
--------------------------------------------------------------------------

local catchers = setmetatable({}, { __mode = "k" })

-- In combat the pad is the game's (see the header): set from the events,
-- as InCombatLockdown is still false while PLAYER_REGEN_DISABLED is heard.
local fighting = false
local function Combat()
    return fighting or (InCombatLockdown ~= nil and InCombatLockdown()) and true or false
end
Pad.Combat = Combat

-- The Escape stand-in, on its release: our windows in UISpecialFrames
-- hidden, as the game's Escape does them (CloseSpecialWindows), but from
-- here, so no binding of the game's runs from our handler. Gone through as
-- the list stood at the press: a window that stands in for another
-- (UI/Dungeon/Spread.lua's StandIn) closes alone, as with the keyboard.
local function CloseOurs()
    local names = {}
    for i, name in ipairs(UISpecialFrames or {}) do names[i] = name end
    for _, name in ipairs(names) do
        local frame = type(name) == "string" and name:find("^SocialDiary") and _G[name]
        if frame and frame:IsShown() then frame:Hide() end
    end
end
Pad.CloseOurs = CloseOurs

-- (Never returns true: see the header. Every return is a press taken;
-- `acted` says whether anything was done with it, for the tests.)
local function Down(self, key)
    self.acted = false
    local scope = Pad.Top()
    if not (scope and Input.Active() and Host(scope) == self.host) or Combat() then return false end
    self.downs[key] = true
    -- (B and Escape act on their release: closing on the press would leave
    -- the release to whatever is under the book)
    if key == BACK or IsEscape(key) then
        self.acted = true
        return false
    end
    if Emulated(key) and not Claims(scope, key) then return false end
    Pad.pressing = true
    local taken = Dispatch(scope, key)
    Pad.pressing = false
    if not taken then return false end
    self.acted = true
    if DIRS[key] then self:Repeat(key) end
    ShowLegend(Pad.Top())
    return false
end

local function Up(self, key)
    if self.repeatKey == key then self:Repeat(nil) end
    -- (only a release whose press we took acts: a button held as the book
    -- opened is the game's to the end, and its release never comes here)
    self.acted = self.downs[key] == true
    if not self.downs[key] then return false end
    self.downs[key] = nil
    if Combat() then return false end
    if IsEscape(key) then
        CloseOurs()
    elseif key == BACK then
        local scope = Pad.Top()
        if scope then Back(scope) end
        ShowLegend(Pad.Top())
    end
    return false
end

-- A direction held repeats, as the game's own lists do.
local function RepeatUpdate(self, elapsed)
    self.wait = self.wait - elapsed
    if self.wait > 0 then return end
    if not (IsKeyDown and IsKeyDown(self.repeatKey)) then return self:Repeat(nil) end
    self.wait = REPEAT_EVERY
    local scope = Pad.Top()
    if scope and Host(scope) == self.host then
        Pad.pressing = true
        Dispatch(scope, self.repeatKey)
        Pad.pressing = false
    end
end

-- A stick moved (the client says when it changes, not every frame: the
-- guide's §6). Past the deadzone and taken by the scope, it is held and
-- moved by on each frame (StickUpdate); back in the deadzone, let go. A
-- stick no scope takes is taken all the same (see the header: nothing is
-- passed on); sticks are on only for a scope that asks for them.
local function StickUpdate(ticker, elapsed)
    local c = ticker.catcher
    local scope = Pad.Top()
    local s = scope and Input.Active() and Host(scope) == c.host and Sticky(scope)
    if not s then
        wipe(c.sticks)
        ticker:SetScript("OnUpdate", nil)
        return
    end
    for stick, v in pairs(c.sticks) do s.stick(s, stick, v[1], v[2], v[3], elapsed or 0) end
end

local function Stick(self, stick, x, y, len)
    x, y = x or 0, y or 0
    len = len or math.sqrt(x * x + y * y)
    local held = self.sticks[stick]
    self.acted = held ~= nil
    if len < DEADZONE then
        self.sticks[stick] = nil
        if not next(self.sticks) then self.ticker:SetScript("OnUpdate", nil) end
        return false
    end
    local scope = Pad.Top()
    local s = scope and Input.Active() and Host(scope) == self.host and not Combat() and Sticky(scope)
    if not s then return false end
    -- (measured from the deadzone's edge: 0 there, 1 pushed all the way)
    local k = math.min(1, (len - DEADZONE) / (1 - DEADZONE)) / len
    local sx, sy, sl = x * k, y * k, len * k
    if not held and not s.stick(s, stick, sx, sy, sl, 0) then return false end
    self.acted = true
    self.sticks[stick] = { sx, sy, sl }
    self.ticker:SetScript("OnUpdate", StickUpdate)
    return false
end

-- The sticks on or off for a catcher; off lets go of any held.
local function SetSticks(c, on)
    if not c.EnableGamePadStick then return end
    if c:IsGamePadStickEnabled() ~= on then c:EnableGamePadStick(on) end
    if not on then
        wipe(c.sticks)
        c.ticker:SetScript("OnUpdate", nil)
    end
end

local function Catcher(host)
    local c = catchers[host]
    if c then return c end
    c = CreateFrame("Frame", nil, host)
    c:SetAllPoints(host)
    c.host, c.downs = host, {}
    c:SetScript("OnGamePadButtonDown", Down)
    c:SetScript("OnGamePadButtonUp", Up)
    -- (setting the handler turns the pad's input on by itself)
    c:EnableGamePadButton(false)
    -- Sticks only for a scope that asks (SetSticks, from Refresh); held
    -- ones move on the ticker's frames, apart from the D-pad's repeat.
    c.sticks = {}
    c.ticker = CreateFrame("Frame", nil, c)
    c.ticker.catcher = c
    c:SetScript("OnGamePadStick", Stick)
    if c.EnableGamePadStick then c:EnableGamePadStick(false) end
    function c:Repeat(key)
        self.repeatKey, self.wait = key, REPEAT_FIRST
        self:SetScript("OnUpdate", key and RepeatUpdate or nil)
    end
    catchers[host] = c
    host:HookScript("OnShow", function() Pad.Refresh() end)
    host:HookScript("OnHide", function() Pad.Refresh() end)
    return c
end
Pad.Catcher = Catcher

--------------------------------------------------------------------------
-- Refresh
--------------------------------------------------------------------------

-- The pad put down (or never there): every catcher off, nothing marked.
-- Nothing is made here, so a book that never meets a pad has no catcher.
local function PutDown()
    for host, c in pairs(catchers) do
        if c:IsGamePadButtonEnabled() then
            c:EnableGamePadButton(false)
            wipe(c.downs)
            c:Repeat(nil)
        end
        SetSticks(c, false)
        Look.Hide(host)
    end
    for _, s in ipairs(scopes:Ordered()) do
        if s.focus then s.focus:Show(false) end
    end
end

-- Whether a window of ours is open: the input watcher only runs then
-- (Input.Watch). A host seen open is hooked once, so its closing is heard
-- even before the pad ever made it a catcher.
local hooked = setmetatable({}, { __mode = "k" })
local function Watch()
    local open = false
    for _, s in ipairs(scopes:Ordered()) do
        local host = Host(s)
        if host and host:IsVisible() then
            open = true
            if not hooked[host] then
                hooked[host] = true
                host:HookScript("OnHide", function() Pad.Refresh() end)
            end
        end
    end
    Input.Watch(open)
end

function Pad.Refresh()
    Watch()
    -- (in combat the pad is the game's: everything put down, the book open)
    local active = Input.Active() and not Combat()
    if not active then return PutDown() end
    local top = Pad.Top()
    local topHost = top and Host(top)

    -- The top scope's focus filled again, where it was by key.
    local focus = top and FocusOf(top)
    if focus then
        focus:Clear()
        top.build(focus, top)
        for _, j in ipairs(joins:Ordered()) do j.join(focus, top) end
        -- (an aside gone with the pad on it: back where it came from)
        local g = focus.asides and focus.asides[focus.group] and focus.groups[focus.group]
        if g and #g.items == 0 and focus.from then focus:Within(focus.from) end
        focus:Done()
    end
    for _, s in ipairs(scopes:Ordered()) do
        if s.focus then s.focus:Show(active and s == top) end
    end

    -- Each window's catcher on while it has the top scope and the pad is
    -- in hand; off otherwise, so a closed or idle book takes nothing.
    for _, s in ipairs(scopes:Ordered()) do
        local host = Host(s)
        if host then
            local c = Catcher(host)
            local on = active and host == topHost and host:IsVisible()
            if c:IsGamePadButtonEnabled() ~= on then
                c:EnableGamePadButton(on)
                if not on then
                    wipe(c.downs)
                    c:Repeat(nil)
                end
            end
            SetSticks(c, on and Sticky(top) ~= nil)
            if not on then Look.Hide(host) end
        end
    end
    if active and top then ShowLegend(top) end
end

Input.OnChange(function() Pad.Refresh() end)
ns.On("PLAYER_REGEN_DISABLED", function()
    fighting = true
    Pad.Refresh()
end)
ns.On("PLAYER_REGEN_ENABLED", function()
    fighting = false
    Pad.Refresh()
end)
Pad.Glyphs.OnChange(function() ShowLegend(Pad.Top()) end)
