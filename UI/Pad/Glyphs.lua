-- The pad's buttons as the player's pad draws them: Cross on a
-- PlayStation pad, A on an Xbox one, B on a Switch (whose letters sit the
-- other way round). The key is always the binding key ("PAD1", "PADDUP"),
-- never the printed label (.claude/controller_api_reference.md, §4, §11).
--
--   Glyphs.Style()          "Shapes", "Letters", "Reverse" or "Generic"
--   Glyphs.Atlas(key)       the button's atlas, or nil
--   Glyphs.Text(key, size)  the button inline in a text: its icon, else its name
--   Glyphs.Name(key)        its printed name ("Cross", "A", "LB")
--   Glyphs.OnChange(fn)     fn() when the pad's style may have changed
--
-- Forever writes its gamepad KEY_* strings as atlas markup, one per style
-- (KEY_PAD1_SHP ...), so those are read first; the atlases listed below
-- stand in where a client has none.

local addonName, ns = ...

local Pad = ns.UI.Pad

local Glyphs = {}
Pad.Glyphs = Glyphs

local SUFFIX = { Letters = "_LTR", Shapes = "_SHP", Reverse = "_REV" }

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
    local markup = Markup(key)
    local atlas = markup and markup:match("|A:([^:|]+)")
    if atlas then return atlas end
    local s = Glyphs.Style()
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

function Glyphs.Text(key, size)
    local atlas = Glyphs.Atlas(key)
    if atlas then
        size = size or 16
        return ("|A:%s:%d:%d|a"):format(atlas, size, size)
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
