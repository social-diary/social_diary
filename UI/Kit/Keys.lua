-- Choosing a key for one of the addon's bindings (Bindings.xml), on the
-- page: the key drawn as a keycap, a link to change it, and the page
-- listening for the next key pressed. The empty People page binds Remember
-- this with it (UI/Journal/Empty.lua), Settings both bindings
-- (UI/Settings/Sections/Shortcuts.lua).
--
-- ns.UI.Keys.Setter(parent, action, status) builds one; the rest is what it
-- is made of, for the tests and for a page that needs only a piece.

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT

local Keys = {}
ns.UI.Keys = Keys

-- The key, drawn as a keycap.
local KEYCAP = { h = 24, min = 46, pad = 8, edge = 0.65 }
Keys.KEYCAP = KEYCAP

local MODIFIER_KEYS = {
    LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true,
    LALT = true, RALT = true, LMETA = true, RMETA = true,
}

--------------------------------------------------------------------------
-- The pad's buttons (.claude/controller-plan.md, step 7c)
--------------------------------------------------------------------------
--
-- A pad button binds as a key does ("PAD3"), with the modifiers its
-- stand-in buttons hold ("SHIFT-PAD3" while the button set as Shift is
-- held: the GamePadEmulate* CVars, read each time, never assumed). A
-- stand-in itself is never bound (a modifier fires no binding of its own,
-- and Escape's is the game's), and B cancels as Escape does, so it is
-- never bound either.

local function CVar(name)
    local get = (C_CVar and C_CVar.GetCVar) or GetCVar
    return get and get(name) or nil
end

-- The stand-ins, and the client's own defaults where a CVar is not there.
local STAND_IN = {
    { role = "ALT", cvar = "GamePadEmulateAlt", default = "none" },
    { role = "CTRL", cvar = "GamePadEmulateCtrl", default = "PADLSHOULDER" },
    { role = "SHIFT", cvar = "GamePadEmulateShift", default = "PADLTRIGGER" },
    { role = "ESCAPE", cvar = "GamePadEmulateEsc", default = "PADBACK" },
}

-- The pad button standing in for `role` ("ALT", "CTRL", "SHIFT" or
-- "ESCAPE"), or nil when none is.
function Keys.StandIn(role)
    for _, s in ipairs(STAND_IN) do
        if s.role == role then
            local button = CVar(s.cvar)
            if button == nil then button = s.default end
            if button == "" or button == "none" then return nil end
            return button
        end
    end
end

-- What `button` stands in for, or nil.
function Keys.RoleOf(button)
    for _, s in ipairs(STAND_IN) do
        if Keys.StandIn(s.role) == button then return s.role end
    end
end

-- Whether `key` (bare or with modifiers) is a pad button.
function Keys.IsPad(key)
    local base = key and key:match("([^-]+)$")
    return base ~= nil and base:sub(1, 3) == "PAD"
end

-- The pad button pressed, with the modifiers held (the keyboard's, or the
-- pad's stand-ins), as the bindings write it.
function Keys.PadCombo(button)
    local function Held(role, down)
        if down() then return true end
        local b = Keys.StandIn(role)
        return b ~= nil and IsKeyDown ~= nil and IsKeyDown(b) and true or false
    end
    local mods = ""
    if Held("ALT", IsAltKeyDown) then mods = mods .. "ALT-" end
    if Held("CTRL", IsControlKeyDown) then mods = mods .. "CTRL-" end
    if Held("SHIFT", IsShiftKeyDown) then mods = mods .. "SHIFT-" end
    return mods .. button
end

Keys.PAD_ESCAPE = "That button is the pad's Escape. Choose another."
Keys.PAD_MODIFIER = "That button is the pad's %s. Hold it while you press another."
Keys.PAD_CANCEL = "%s cancels. Choose another."
local MODIFIER_NAME = { ALT = "Alt", CTRL = "Ctrl", SHIFT = "Shift" }

-- What is said of a stand-in pressed while listening; nil for any other
-- button.
function Keys.PadRefused(button)
    local role = Keys.RoleOf(button)
    if role == "ESCAPE" then return Keys.PAD_ESCAPE end
    if role then return Keys.PAD_MODIFIER:format(MODIFIER_NAME[role]) end
end

-- The glyphs' size on a keycap.
local GLYPH = 18

-- A key as it is shown: a pad button as the player's pad draws it (and a
-- modifier as the button standing in for it, else its name), any other key
-- in the key bindings' words.
function Keys.Text(key)
    local Glyphs = ns.UI.Pad and ns.UI.Pad.Glyphs
    if not (Glyphs and Keys.IsPad(key)) then
        return GetBindingText and GetBindingText(key) or key
    end
    local parts = {}
    for mod in key:gmatch("(%u+)%-") do
        local button = Keys.StandIn(mod)
        parts[#parts + 1] = button and Glyphs.Text(button, GLYPH) or MODIFIER_NAME[mod] or mod
    end
    parts[#parts + 1] = Glyphs.Text(key:match("([^-]+)$"), GLYPH)
    return table.concat(parts, " + ")
end

-- The key `action` is on, as it is shown, or nil.
function Keys.Bound(action)
    local key = GetBindingKey and GetBindingKey(action)
    if not key then return nil end
    return Keys.Text(key)
end

-- What the key did before, in the words of the key bindings; nil when it
-- did nothing, or already did `action`.
local function ActionName(before, action)
    if not before or before == "" or before == action then return nil end
    return _G["BINDING_NAME_" .. before] or before
end

-- The keys that are never bound, with a modifier or without: Enter and
-- Backspace (the chat's), and the left and right mouse buttons (every
-- click). What else to bind is the user's to choose. Modifiers alone never
-- bind, and Escape cancels.
local NEVER = { ENTER = true, BACKSPACE = true, BUTTON1 = true, BUTTON2 = true }

-- Whether `key` (the bare key, as the bindings write it) is never bound.
function Keys.Refused(key)
    return NEVER[key] == true
end
Keys.REFUSED = "That key stays with the game. Choose another."

-- The mouse's buttons as the bindings write them; the left and right are
-- BUTTON1 and BUTTON2.
local BUTTONS = { LeftButton = "BUTTON1", RightButton = "BUTTON2", MiddleButton = "BUTTON3" }
function Keys.Button(button)
    return BUTTONS[button] or button:upper()
end
Keys.COMBAT = "Not during a fight. Try again after it."

-- What the setter asks before it takes `key` from what has it; nil when the
-- key is free, or already `action`'s, and there is nothing to ask.
function Keys.Question(action, key)
    local taken = ActionName(GetBindingAction(key), action)
    if not taken then return nil end
    local shown = Keys.Text(key)
    return ("%s is set to %s.\n\nUse it for %s instead?"):format(shown, taken, ActionName(action))
end
Keys.TAKE = "Use it"

-- Binds `key` to `action` in place of whatever had it, and of the key
-- `action` had. Saved with the character's or the account's bindings,
-- whichever are in use. Out of combat only: the client refuses it there.
function Keys.Bind(action, key)
    if InCombatLockdown() then return false, Keys.COMBAT end
    local before = ActionName(GetBindingAction(key), action)
    local old = { GetBindingKey(action) }
    for _, k in ipairs(old) do SetBinding(k) end
    SetBinding(key, action)
    SaveBindings(GetCurrentBindingSet())
    return true, before and ("It was " .. before .. " until now.") or ""
end

-- The key pressed, with its modifiers, as the bindings write it.
function Keys.Combo(key)
    local mods = ""
    if IsAltKeyDown() then mods = mods .. "ALT-" end
    if IsControlKeyDown() then mods = mods .. "CTRL-" end
    if IsShiftKeyDown() then mods = mods .. "SHIFT-" end
    if IsMetaKeyDown and IsMetaKeyDown() then mods = mods .. "META-" end
    return mods .. key
end

--------------------------------------------------------------------------
-- The keycap
--------------------------------------------------------------------------

-- A key drawn in ink: a faint face, a hairline round it and a thicker edge
-- along the bottom for its front. SetKey(text, font) writes on it and
-- sizes it to fit.
function Keys.Keycap(parent)
    local K, INK = KEYCAP, Style.INK
    local cap = CreateFrame("Frame", nil, parent)
    cap:SetHeight(K.h)
    local face = cap:CreateTexture(nil, "BACKGROUND")
    face:SetAllPoints()
    Style.Gradient(face, "VERTICAL", { INK[1], INK[2], INK[3], 0.08 }, { 1, 0.97, 0.88, 0.22 })
    Style.Hairline(cap, "BORDER", 0, K.edge)
    -- The key's front, below its face: a thicker edge along the bottom.
    local front = cap:CreateTexture(nil, "BORDER", nil, 1)
    front:SetHeight(2)
    front:SetPoint("BOTTOMLEFT")
    front:SetPoint("BOTTOMRIGHT")
    front:SetColorTexture(INK[1], INK[2], INK[3], K.edge)

    cap.text = Style.Text(cap, FONT.body)
    cap.text:SetPoint("CENTER", 0, 1)
    cap.text:SetJustifyH("CENTER")
    function cap:SetKey(text, font)
        self.text:SetFontObject(font or FONT.strong)
        self.text:SetText(text)
        self:SetWidth(math.max(K.min, (self.text:GetUnboundedStringWidth() or 0) + 2 * K.pad))
    end
    return cap
end

--------------------------------------------------------------------------
-- The setter: keycap, link, and listening
--------------------------------------------------------------------------

-- The one listening, if any: starting another stops it, so two keycaps on
-- a page never both take the keyboard.
local listening

-- The pad in hand (Forever's Gamepad UI on, the pad used last): the
-- setter then asks for a button, and says B cancels.
local function PadInHand()
    local Pad = ns.UI.Pad
    return Pad ~= nil and Pad.Input ~= nil and Pad.Input.Active() and true or false
end

-- One binding's keycap, with "Choose one" or "Change" beside it, one line
-- KEYCAP.h tall. `status` is where it answers (what the key did before, a
-- refusal): a font string of the caller's, or else its own, under the
-- keycap, for the caller to size and to anchor what follows to.
-- `.listening` while it waits for a key; `.catcher` takes the keyboard
-- then, and the pad's buttons (whichever hand clicked: a pad button pressed
-- after a click binds too). While it listens the pad's own focus steps
-- aside (Pad.Aside), so every button but the stand-ins comes here. `onBound`, if set, runs after a key is bound. A key something else
-- has is asked about first, with the listening over and the keyboard given
-- back: bound on yes, nothing touched otherwise.
function Keys.Setter(parent, action, status)
    local s = CreateFrame("Frame", nil, parent)
    s.action = action
    s:SetHeight(KEYCAP.h)

    s.keycap = Keys.Keycap(s)
    s.keycap:SetPoint("TOPLEFT")
    s.bind = Style.Link(s, FONT.body, function() s:Listen() end)
    s.bind:SetPoint("LEFT", s.keycap, "RIGHT", 10, 0)
    s.hint = Style.Text(s, FONT.faded)
    s.hint:SetPoint("LEFT", s.keycap, "RIGHT", 10, 0)
    if not status then
        status = Style.Text(s, FONT.small)
        status:SetPoint("TOPLEFT", s.keycap, "BOTTOMLEFT", 0, -4)
        status:SetSpacing(2)
    end
    s.status = status

    function s:Refresh()
        local key = Keys.Bound(self.action)
        self.bind:SetShown(not self.listening)
        self.hint:SetShown(self.listening == true)
        if self.listening then
            local pad = PadInHand()
            self.keycap:SetKey(pad and "press a button" or "press a key", FONT.headingRubric)
            local B = pad and ns.UI.Pad.Glyphs.Text("PAD2", 16)
            self.hint:SetText(pad and (B .. " to cancel") or "Escape to cancel")
        elseif key then
            self.keycap:SetKey(key)
            self.bind:SetText("Change")
        else
            self.keycap:SetKey("no key", FONT.faded)
            self.bind:SetText("Choose one")
        end
    end

    -- Listening for the key: it takes the keyboard, and the mouse over the
    -- whole screen, until a key, button or turn of the wheel that is not
    -- only a modifier. Escape, or a left or right click, cancels. Never in
    -- a fight, and never past the page closing (the caller stops it then).
    local catcher = CreateFrame("Frame", nil, s)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    catcher:Hide()
    s.catcher = catcher

    function s:Stop()
        if not self.listening then return end
        self.listening = false
        if listening == self then listening = nil end
        catcher:EnableKeyboard(false)
        catcher:EnableMouse(false)
        catcher:EnableMouseWheel(false)
        catcher:SetScript("OnKeyDown", nil)
        catcher:SetScript("OnMouseDown", nil)
        catcher:SetScript("OnMouseWheel", nil)
        catcher:SetScript("OnGamePadButtonDown", nil)
        catcher:EnableGamePadButton(false)
        catcher:Hide()
        if ns.UI.Pad then ns.UI.Pad.Aside(self, nil) end
        self:Refresh()
    end

    -- A key or button pressed while listening: refused, or bound (asked
    -- first if something else has it).
    local function Pressed(key, combo)
        if Keys.Refused(key) then
            s.status:SetText(Keys.REFUSED)
            return
        end
        combo = combo or Keys.Combo(key)
        s:Stop()
        local question = Keys.Question(s.action, combo)
        if question then
            s.status:SetText("")
            ns.UI.Dialog.Confirm(question, function() s:Take(combo) end, Keys.TAKE)
        else
            s:Take(combo)
        end
    end

    function s:Listen()
        if InCombatLockdown() then
            self.status:SetText(Keys.COMBAT)
            return
        end
        if listening and listening ~= self then listening:Stop() end
        listening = self
        self.listening = true
        self.status:SetText("")
        catcher:Show()
        catcher:EnableKeyboard(true)
        catcher:SetPropagateKeyboardInput(false)
        catcher:EnableMouse(true)
        catcher:EnableMouseWheel(true)
        catcher:SetScript("OnKeyDown", function(_, key)
            if MODIFIER_KEYS[key] then return end
            if key == "ESCAPE" then
                self:Stop()
                return
            end
            Pressed(key)
        end)
        catcher:SetScript("OnMouseDown", function(_, button)
            local key = Keys.Button(button)
            if key == "BUTTON1" or key == "BUTTON2" then
                self:Stop()
                return
            end
            Pressed(key)
        end)
        catcher:SetScript("OnMouseWheel", function(_, delta)
            Pressed(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
        end)
        -- A pad button: a stand-in refused (a modifier's press goes on to
        -- the game, which holds it as the modifier), B cancels, any other
        -- binds with the modifiers held. Taken on the press, as a key is.
        catcher:SetScript("OnGamePadButtonDown", function(_, button)
            local refused = Keys.PadRefused(button)
            if refused then
                self.status:SetText(refused)
                return Keys.RoleOf(button) ~= "ESCAPE"
            end
            if button == "PAD2" then
                self:Stop()
                return false
            end
            Pressed(button, Keys.PadCombo(button))
            return false
        end)
        catcher:EnableGamePadButton(true)
        -- (the pad's focus aside meanwhile: its catchers off, its box gone)
        if ns.UI.Pad then ns.UI.Pad.Aside(self, true) end
        if PadInHand() then
            self.status:SetText(Keys.PAD_CANCEL:format(ns.UI.Pad.Glyphs.Text("PAD2", 16)))
        end
        self:Refresh()
    end

    -- Binds and says so. Bind refuses in a fight itself, and the question may
    -- be answered in one: nothing is bound then, and the line says why.
    function s:Take(key)
        local bound, said = Keys.Bind(self.action, key)
        self.status:SetText(said or "")
        self:Refresh()
        if bound and self.onBound then self.onBound(self) end
    end

    s:SetScript("OnHide", function(self) self:Stop() end)
    ns.On("PLAYER_REGEN_DISABLED", function() s:Stop() end)
    ns.On("UPDATE_BINDINGS", function() if s:IsVisible() then s:Refresh() end end)

    s:Refresh()
    return s
end
