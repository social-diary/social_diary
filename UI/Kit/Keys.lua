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

-- The key `action` is on, as the key bindings write it, or nil.
function Keys.Bound(action)
    local key = GetBindingKey and GetBindingKey(action)
    if not key then return nil end
    return GetBindingText and GetBindingText(key) or key
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
    local shown = GetBindingText and GetBindingText(key) or key
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

-- One binding's keycap, with "Choose one" or "Change" beside it, one line
-- KEYCAP.h tall. `status` is where it answers (what the key did before, a
-- refusal): a font string of the caller's, or else its own, under the
-- keycap, for the caller to size and to anchor what follows to.
-- `.listening` while it waits for a key; `.catcher` takes the keyboard
-- then. `onBound`, if set, runs after a key is bound. A key something else
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
            self.keycap:SetKey("press a key", FONT.headingRubric)
            self.hint:SetText("Escape to cancel")
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
        catcher:Hide()
        self:Refresh()
    end

    -- A key or button pressed while listening: refused, or bound (asked
    -- first if something else has it).
    local function Pressed(key)
        if Keys.Refused(key) then
            s.status:SetText(Keys.REFUSED)
            return
        end
        local combo = Keys.Combo(key)
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
