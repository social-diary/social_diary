-- The pad's buttons as the player's pad draws them: Cross on a
-- PlayStation pad, A on an Xbox one, B on a Switch (whose letters sit the
-- other way round). The key is always the binding key ("PAD1", "PADDUP"),
-- never the printed label (.claude/controller_api_reference.md, §4, §11).
--
--   Glyphs.Style()          "Shapes", "Letters", "Reverse" or "Generic"
--   Glyphs.Atlas(key)       the button's atlas, or nil
--   Glyphs.Size(atlas, h)   its width and height drawn h px tall
--   Glyphs.Text(key, size)  the button inline in a text: its icon, else its name
--   Glyphs.Name(key)        its printed name ("Cross", "A", "LB")
--   Glyphs.OnChange(fn)     fn() when the pad's style may have changed
--
-- The buttons are shown as the pad's own prompts show them, in their real
-- colours (the client, 8 Nov 2026: inked dark on the slip, their letters
-- were nearly as dark as the button). So the client's modern full-colour
-- atlases of each style (MODERN, "gamepad-xbox1-buttona-normal" ...) are
-- read first, each checked with C_Texture.GetAtlasInfo; then the atlas of
-- Forever's KEY_* markup for the style (KEY_PAD1_SHP ...); then the older
-- per-style set (Gamepad_Shp_Cross_64 ...). Nothing is tinted: whoever
-- draws an atlas draws it as it is (UI/Pad/Look.lua, Glyph).

local addonName, ns = ...

local Pad = ns.UI.Pad

local Glyphs = {}
Pad.Glyphs = Glyphs

local SUFFIX = { Letters = "_LTR", Shapes = "_SHP", Reverse = "_REV" }

-- The client's modern atlases, by style and key: what the game's own
-- prompts draw (the names as Blizzard_SharedXML's InputIconTexture and the
-- ImprovedForever addon use them, ref/). "Generic" (a pad SDL does not
-- name) shows Xbox's, as the game does. Nintendo's letters sit the other
-- way round: its bottom button (PAD1) is B.
local MODERN = {
    Letters = {
        PAD1 = "gamepad-xbox1-buttona-normal", PAD2 = "gamepad-xbox1-buttonb-normal",
        PAD3 = "gamepad-xbox1-buttonx-normal", PAD4 = "gamepad-xbox1-buttony-normal",
        PADLSHOULDER = "gamepad-xbox1-trigger-lb-normal", PADRSHOULDER = "gamepad-xbox1-trigger-rb-normal",
        PADLTRIGGER = "gamepad-xbox1-trigger-lt-normal", PADRTRIGGER = "gamepad-xbox1-trigger-rt-normal",
        PADLSTICK = "gamepad-xbox1-stick-l3-normal", PADRSTICK = "gamepad-xbox1-stick-r3-normal",
        PADDUP = "gamepad-xbox1-dpadup-normal", PADDDOWN = "gamepad-xbox1-dpaddown-normal",
        PADDLEFT = "gamepad-xbox1-dpadleft-normal", PADDRIGHT = "gamepad-xbox1-dpadright-normal",
        PADBACK = "gamepad-xbox1-view-normal", PADFORWARD = "gamepad-xbox1-menu-normal",
    },
    Shapes = {
        PAD1 = "gamepad-ps-buttoncrox-normal", PAD2 = "gamepad-ps-buttoncircle-normal",
        PAD3 = "gamepad-ps-buttonsquare-normal", PAD4 = "gamepad-ps-buttontriangle-normal",
        PADLSHOULDER = "gamepad-ps-triggerl1-normal", PADRSHOULDER = "gamepad-ps-triggerr1-normal",
        PADLTRIGGER = "gamepad-ps-triggerl2-normal", PADRTRIGGER = "gamepad-ps-triggerr2-normal",
        PADLSTICK = "gamepad-ps-stickl3-normal", PADRSTICK = "gamepad-ps-stickr3-normal",
        PADDUP = "gamepad-ps-dpadup-normal", PADDDOWN = "gamepad-ps-dpaddown-normal",
        PADDLEFT = "gamepad-ps-dpadleft-normal", PADDRIGHT = "gamepad-ps-dpadright-normal",
        PADBACK = "gamepad-ps-touchpad-normal", PADFORWARD = "gamepad-ps-options-normal",
    },
    Reverse = {
        PAD1 = "gamepad-switch-128x-face-b-normal", PAD2 = "gamepad-switch-128x-face-a-normal",
        PAD3 = "gamepad-switch-128x-face-y-normal", PAD4 = "gamepad-switch-128x-face-x-normal",
        PADLSHOULDER = "gamepad-switch-128x-shoulder-l-normal", PADRSHOULDER = "gamepad-switch-128x-shoulder-r-normal",
        PADLTRIGGER = "gamepad-switch-128x-zl-normal", PADRTRIGGER = "gamepad-switch-128x-zr-normal",
        PADLSTICK = "gamepad-switch-128x-stick-l3-normal", PADRSTICK = "gamepad-switch-128x-stick-r3-normal",
        PADDUP = "gamepad-switch-128x-dpad-up-normal", PADDDOWN = "gamepad-switch-128x-dpad-down-normal",
        PADDLEFT = "gamepad-switch-128x-dpad-left-normal", PADDRIGHT = "gamepad-switch-128x-dpad-right-normal",
        PADBACK = "gamepad-switch-128x-minus-normal", PADFORWARD = "gamepad-switch-128x-plus-normal",
    },
}
MODERN.Generic = MODERN.Letters
Glyphs.MODERN = MODERN

-- The atlases of the older per-style set, by key.
local ATLAS_NAME = {
    PAD1 = { Letters = "A", Shapes = "Cross", Reverse = "B" },
    PAD2 = { Letters = "B", Shapes = "Circle", Reverse = "A" },
    PAD3 = { Letters = "X", Shapes = "Square", Reverse = "Y" },
    PAD4 = { Letters = "Y", Shapes = "Triangle", Reverse = "X" },
    PADLSHOULDER = "LShoulder", PADRSHOULDER = "RShoulder",
    PADLTRIGGER = "LTrigger", PADRTRIGGER = "RTrigger",
    PADLSTICK = "LStickIn", PADRSTICK = "RStickIn",
    PADDUP = "Up", PADDDOWN = "Down", PADDLEFT = "Left", PADDRIGHT = "Right",
    PADBACK = "View", PADFORWARD = "Menu",
}
local ATLAS_PREFIX = { Letters = "Ltr", Shapes = "Shp", Reverse = "Rev", Generic = "Gen" }

-- What each pad prints on its buttons, for text without icons.
local NAMES = {
    Letters = { PAD1 = "A", PAD2 = "B", PAD3 = "X", PAD4 = "Y", PADLSHOULDER = "LB", PADRSHOULDER = "RB",
        PADLTRIGGER = "LT", PADRTRIGGER = "RT", PADBACK = "View", PADFORWARD = "Menu" },
    Shapes = { PAD1 = "Cross", PAD2 = "Circle", PAD3 = "Square", PAD4 = "Triangle", PADLSHOULDER = "L1",
        PADRSHOULDER = "R1", PADLTRIGGER = "L2", PADRTRIGGER = "R2", PADBACK = "Touchpad", PADFORWARD = "Options" },
    Reverse = { PAD1 = "B", PAD2 = "A", PAD3 = "Y", PAD4 = "X", PADLSHOULDER = "L", PADRSHOULDER = "R",
        PADLTRIGGER = "ZL", PADRTRIGGER = "ZR", PADBACK = "-", PADFORWARD = "+" },
}
local COMMON = { PADDUP = "Up", PADDDOWN = "Down", PADDLEFT = "Left", PADDRIGHT = "Right",
    PADLSTICK = "L3", PADRSTICK = "R3" }

local style   -- cached until the pad changes

function Glyphs.Style()
    if style then return style end
    style = "Generic"
    if C_GamePad and C_GamePad.GetDeviceMappedState then
        local ok, state = pcall(C_GamePad.GetDeviceMappedState)
        if ok and type(state) == "table" and SUFFIX[state.labelStyle] then style = state.labelStyle end
    end
    return style
end

local function HasAtlas(name)
    if not (name and C_Texture and C_Texture.GetAtlasInfo) then return false end
    local ok, info = pcall(C_Texture.GetAtlasInfo, name)
    return ok and info ~= nil
end

-- The game's markup for the key in this style, or plain.
local function Markup(key)
    local suffix = SUFFIX[Glyphs.Style()]
    local text = (suffix and _G["KEY_" .. key .. suffix]) or _G["KEY_" .. key]
    if type(text) == "string" and text:find("|A:", 1, true) then return text end
end

function Glyphs.Atlas(key)
    local s = Glyphs.Style()
    local modern = MODERN[s] and MODERN[s][key]
    if HasAtlas(modern) then return modern end
    local markup = Markup(key)
    local atlas = markup and markup:match("|A:([^:|]+)")
    if atlas then return atlas end
    local name = ATLAS_NAME[key]
    if type(name) == "table" then name = name[s] or name.Letters end
    if not name then return nil end
    atlas = ("Gamepad_%s_%s_64"):format(ATLAS_PREFIX[s], name)
    if HasAtlas(atlas) then return atlas end
    -- (the generic set lacks the face letters' names: Xbox's stand in)
    atlas = ("Gamepad_Ltr_%s_64"):format(name)
    return HasAtlas(atlas) and atlas or nil
end

function Glyphs.Name(key)
    local names = NAMES[Glyphs.Style()] or NAMES.Letters
    return names[key] or COMMON[key] or key
end

-- An atlas `size` px tall: its width by its own shape (a shoulder button
-- is wider than it is tall), square where the client does not say.
function Glyphs.Size(atlas, size)
    if atlas and C_Texture and C_Texture.GetAtlasInfo then
        local ok, info = pcall(C_Texture.GetAtlasInfo, atlas)
        local w, h = ok and info and info.width, ok and info and info.height
        if type(w) == "number" and type(h) == "number" and w > 0 and h > 0 then
            return math.floor(size * w / h + 0.5), size
        end
    end
    return size, size
end

function Glyphs.Text(key, size)
    local atlas = Glyphs.Atlas(key)
    if atlas then
        size = size or 16
        local w, h = Glyphs.Size(atlas, size)
        return ("|A:%s:%d:%d|a"):format(atlas, h, w)
    end
    return Glyphs.Name(key)
end

local listeners = {}
function Glyphs.OnChange(fn)
    listeners[#listeners + 1] = fn
end

local function Changed()
    style = nil
    for _, fn in ipairs(listeners) do fn() end
end
Glyphs.Changed = Changed

local watch = CreateFrame("Frame")
for _, event in ipairs({ "GAME_PAD_ACTIVE_CHANGED", "GAME_PAD_CONNECTED", "GAME_PAD_DISCONNECTED",
    "GAME_PAD_CONFIGS_CHANGED", "UPDATE_BINDINGS" }) do
    pcall(watch.RegisterEvent, watch, event)
end
watch:SetScript("OnEvent", Changed)
