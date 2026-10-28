-- A WoW API mock, just big enough to load the addon and exercise it.
--
-- We cannot run the client, so this is the only thing standing between a
-- refactor and a live Lua error. It is deliberately dumb: every API returns
-- what Session 1 actually observed, so a test that passes here is a test
-- against a real observation rather than against an assumption.
--
-- Returns a control table; loading it installs the globals.

local M = {}

M.now = 1789680679          -- the T-C6 timestamp
M.realm = "Classic Beta PvE"
M.registered = {}
M.units, M.byGUID = {}, {}

--------------------------------------------------------------------------
-- Fake secret values
--------------------------------------------------------------------------
--
-- A real secret errors on ==, arithmetic, #, indexing and use as a table key.
-- Lua 5.1 only fires __eq when both operands share a metatable, so `secret ==
-- nil` cannot be made to error here; indexing, length and concat can, and
-- those catch the common mistakes. Treat a green run as necessary, not
-- sufficient: the == rule still has to hold by inspection.

local SECRET = {}

local function Forbidden(op)
    return function()
        error("secret value: " .. op .. " is not allowed", 2)
    end
end

local secretMeta = {
    __index = Forbidden("indexing"),
    __len = Forbidden("length"),
    __concat = Forbidden("concat"),
    __add = Forbidden("arithmetic"),
    __tostring = function() return "<SECRET value>" end,
}

function M.secret(value)
    return setmetatable({ [SECRET] = value }, secretMeta)
end

_G.issecretvalue = function(value)
    return getmetatable(value) == secretMeta
end

_G.scrubsecretvalues = function(value)
    if getmetatable(value) == secretMeta then return nil end
    return value
end

--------------------------------------------------------------------------
-- Units
--------------------------------------------------------------------------

-- def: { guid, name = {a, b}, fullName = {a, b}, class = {loc, token, id},
--        race = {loc, token, id}, sex, level, faction = {a, b},
--        isPlayer = true, info = { ... } as GetPlayerInfoByGUID returns }
function M.SetUnit(token, def)
    M.units[token] = def
    if def and def.guid then
        M.byGUID[def.guid] = def
    end
end

function M.ClearUnits()
    M.units, M.byGUID = {}, {}
end

-- The creature cache, as far as model frames read it: NPC id -> display.
M.creatureDisplays = {}

local function Unit(token)
    return M.units[token]
end

-- A secret is itself a table here, so it has to be checked before the
-- multi-return unpack tries to index it.
local function Unpack(def, key)
    local value = def and def[key]
    if issecretvalue(value) or type(value) ~= "table" then return value end
    return value[1], value[2], value[3]
end

_G.UnitExists = function(token) return Unit(token) ~= nil end
_G.UnitIsPlayer = function(token) local u = Unit(token); return u ~= nil and u.isPlayer ~= false end
_G.UnitIsVisible = function(token) local u = Unit(token); return u ~= nil and u.visible ~= false end
_G.UnitGUID = function(token) return Unpack(Unit(token), "guid") end
_G.UnitName = function(token) return Unpack(Unit(token), "name") end
_G.UnitFullName = function(token) return Unpack(Unit(token), "fullName") end
_G.UnitClass = function(token) return Unpack(Unit(token), "class") end
_G.UnitRace = function(token) return Unpack(Unit(token), "race") end
_G.UnitSex = function(token) return Unpack(Unit(token), "sex") end
_G.UnitLevel = function(token) return Unpack(Unit(token), "level") end
_G.UnitFactionGroup = function(token) return Unpack(Unit(token), "faction") end
_G.UnitClassification = function(token) return Unpack(Unit(token), "classification") or "normal" end
_G.UnitIsInMyGuild = function(token) local u = Unit(token); return u ~= nil and u.inGuild == true end
_G.UnitCanAttack = function(_, token) local u = Unit(token); return u ~= nil and u.hostile == true end

-- Returns localizedClass, englishClass, localizedRace, englishRace, sex,
-- name, realm.
--
-- The name is the first name only, for the user's own character as well as
-- for strangers -- Session 2 saw "Ulverston" for a character UnitName calls
-- "Ulverston Nye". The realm carries a trailing index for other players
-- ("ClassicBetaPvE2").
_G.GetPlayerInfoByGUID = function(guid)
    local def = M.byGUID[guid]
    if not def then return nil end
    if def.info then return unpack(def.info) end

    local locClass, class = Unpack(def, "class")
    local locRace, race = Unpack(def, "race")

    local first = Unpack(def, "name")
    if type(first) == "string" then first = first:match("^%S+") end

    local realm = (M.realm:gsub("%s+", ""))
    if guid ~= (M.units.player and M.units.player.guid) then realm = realm .. "2" end

    return locClass, class, locRace, race, def.sex, first, realm
end

--------------------------------------------------------------------------
-- The rest
--------------------------------------------------------------------------

_G.UNKNOWNOBJECT = "Unknown"
_G.UNKNOWN = "Unknown"

_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) print(msg) end }

--------------------------------------------------------------------------
-- Widgets
--------------------------------------------------------------------------
--
-- Layout is not modelled -- there is no way to check it without the client --
-- but construction and scripts are, and that is where addons actually break.
-- A widget method the addon calls that is not listed here raises on purpose:
-- the alternative is a silent no-op that hides a typo until you log in.

M.frames = {}

local NOOPS = {
    "SetSize", "SetWidth", "SetHeight", "SetPoint", "SetAllPoints", "ClearAllPoints",
    "SetFrameStrata", "SetFrameLevel", "SetToplevel", "Raise", "EnableMouse",
    "SetMovable", "RegisterForDrag", "StartMoving", "StopMovingOrSizing",
    "SetClampedToScreen", "SetClampRectInsets", "SetUserPlaced",
    "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor",
    "SetColorTexture", "SetTexture", "SetTexCoord", "SetVertexColor",
    "SetJustifyH", "SetJustifyV", "SetFontObject", "SetFont", "SetTextColor",
    "SetMultiLine", "SetAutoFocus", "SetMaxLetters", "SetCursorPosition",
    "HighlightText", "Insert",
    "LockHighlight", "UnlockHighlight", "Disable", "Enable", "SetAlpha",
    "RegisterForClicks", "SetNormalTexture", "SetHighlightTexture",
    "SetWordWrap", "SetMaxLines", "EnableMouseWheel",
    "SetOrientation", "SetValueStep", "SetObeyStepOnDrag", "SetThumbTexture",
    "SetNumeric", "SetSpacing", "SetClipsChildren", "SetBlendMode", "SetScale",
    "SetShadowOffset", "SetShadowColor", "SetGradient", "SetDesaturated",
    "SetAtlas", "AddMaskTexture", "SetRotation", "SetHitRectInsets",
    "SetSnapToPixelGrid", "SetTexelSnappingBias", "SetVertexOffset",
    "EnableKeyboard", "SetPropagateKeyboardInput", "SetHyperlinksEnabled", "SetFixedFrameStrata",
}

local ANCHORS = {}
for _, point in ipairs({ "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT",
    "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }) do
    ANCHORS[point] = true
end

-- What the layout calls left behind, for tests/uidump.lua's snapshot: the
-- last arguments of every no-op method, the anchors and the size, on
-- `w.recorded`. Recording only: nothing the addon or a test can read back
-- through the widget API changes.
local function Pack(...)
    return { n = select("#", ...), ... }
end

-- Calls are numbered, so the snapshot can tell which of two overriding
-- calls (SetTexture, SetColorTexture) came last.
local callCount = 0

local RECORDERS = {}
for i = 1, #NOOPS do
    local method = NOOPS[i]
    RECORDERS[method] = function(self, ...)
        if type(self) == "table" and self.recorded then
            callCount = callCount + 1
            local args = Pack(...)
            args.seq = callCount
            self.recorded.calls[method] = args
        end
    end
end

local function NewWidget(frameType, name, parent, template)
    local w = {
        frameType = frameType, name = name, parent = parent, template = template,
        scripts = {}, events = {}, shown = false, text = "",
    }
    -- The global name too: the addon is free to hang its own `name` on a
    -- frame (a font string, say).
    local rec = { calls = {}, points = {}, globalName = name }
    w.recorded = rec

    for i = 1, #NOOPS do
        w[NOOPS[i]] = RECORDERS[NOOPS[i]]
    end

    -- Anchors as the client keeps them: one per point, replaced by the same
    -- point again, all dropped by ClearAllPoints. SetAllPoints is two.
    local function Anchor(point, ...)
        local n = 0
        for i = 1, #rec.points do
            if rec.points[i].point == point then n = i end
        end
        local anchor = { point = point, args = Pack(...) }
        if n > 0 then rec.points[n] = anchor else rec.points[#rec.points + 1] = anchor end
    end
    function w:ClearAllPoints() rec.points = {} end
    function w:SetAllPoints(relative)
        rec.points = {}
        Anchor("TOPLEFT", relative or self.parent, "TOPLEFT")
        Anchor("BOTTOMRIGHT", relative or self.parent, "BOTTOMRIGHT")
    end

    -- Anchor names are strings the client checks and the mock otherwise
    -- would not: a typo'd point is a silent layout bug in game.
    function w:SetPoint(point, a, b, ...)
        assert(ANCHORS[point], "invalid anchor point: " .. tostring(point))
        if type(a) == "table" and type(b) == "string" then
            assert(ANCHORS[b], "invalid relative point: " .. b)
        elseif type(a) == "string" then
            assert(ANCHORS[a], "invalid relative point: " .. a)
        end
        Anchor(point, a, b, ...)
    end

    function w:SetScript(key, fn) self.scripts[key] = fn end
    function w:GetScript(key) return self.scripts[key] end
    function w:HookScript(key, fn)
        local previous = self.scripts[key]
        self.scripts[key] = function(...)
            if previous then previous(...) end
            fn(...)
        end
    end

    -- `shown` starts false here; in the client a region starts shown. The
    -- snapshot needs to know which it was told.
    function w:Show() self.shown, rec.toldShown = true, true end
    function w:Hide()
        self.shown, rec.toldShown = false, false
        if self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function w:IsShown() return self.shown end
    -- Whether the mouse is over it: what a test says (`mouseOver`).
    function w:IsMouseOver() return self.mouseOver == true end
    function w:IsVisible() return self.shown end
    function w:SetShown(value) if value then self:Show() else self:Hide() end end

    -- Focus, as the client tracks it. Losing focus does not fire
    -- OnEditFocusLost here; tests call the script when they mean it.
    function w:SetFocus() self.focused = true end
    function w:ClearFocus() self.focused = false end
    function w:HasFocus() return self.focused == true end

    -- Scroll frames.
    w.scroll = 0
    function w:SetScrollChild(child) self.child = child end
    function w:GetVerticalScroll() return self.scroll end
    function w:SetVerticalScroll(value) self.scroll = value end
    function w:GetVerticalScrollRange() return 0 end
    function w:UpdateScrollChildRect() end
    function w:GetHeight() return self.height or 0 end
    -- Where it lies on the screen, for code that reads a frame back after
    -- it was dragged. Nothing is laid out: a test sets `w.at` = { x, top }.
    -- `at[3]`, when given, is its middle's height (else 0).
    function w:GetCenter() return self.at and self.at[1], self.at and (self.at[3] or 0) end
    function w:GetEffectiveScale() return self.effectiveScale or 1 end
    -- Its scale, as last set (SetScale is recorded with the no-ops).
    function w:GetScale()
        local scale = rec.calls.SetScale
        return scale and scale[1] or 1
    end
    function w:GetTop() return self.at and self.at[2] end
    -- Its alpha, as last set (SetAlpha is recorded with the no-ops).
    function w:GetAlpha()
        local alpha = rec.calls.SetAlpha
        return alpha and alpha[1] or 1
    end

    -- A font string with no font refuses text in the client ("Font not
    -- set"): its font comes from a template, SetFont or SetFontObject.
    function w:SetText(value)
        if frameType == "FontString" and not (template or rec.calls.SetFont or rec.calls.SetFontObject) then
            error("FontString:SetText(): Font not set", 2)
        end
        self.text = value or ""
    end
    function w:GetText() return self.text end

    -- Sliders. Like the client, SetValue clamps and fires OnValueChanged
    -- only when the value actually moves.
    w.min, w.max, w.value = 0, 0, 0
    function w:SetMinMaxValues(lo, hi) self.min, self.max = lo, hi end
    function w:GetMinMaxValues() return self.min, self.max end
    function w:GetValue() return self.value end
    function w:SetValue(value)
        value = math.max(self.min, math.min(self.max, value))
        if value == self.value then return end
        self.value = value
        if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end
    end

    function w:CreateFontString(n, layer, t)
        local child = NewWidget("FontString", n, self, t)
        child.recorded.layer = layer
        return child
    end
    function w:CreateTexture(n, layer, t, sublevel)
        -- The client refuses a sublevel outside -8..7 (an error, not a clamp).
        assert(sublevel == nil or (sublevel >= -8 and sublevel <= 7), "Sublevel must be between -8 and 7")
        local child = NewWidget("Texture", n, self, t)
        child.recorded.layer, child.recorded.sublevel = layer, sublevel
        return child
    end
    function w:CreateMaskTexture(n) return NewWidget("MaskTexture", n, self) end
    -- The same limit when a region's layer is changed later.
    function w:SetDrawLayer(layer, sublevel)
        assert(sublevel == nil or (sublevel >= -8 and sublevel <= 7), "Sublevel must be between -8 and 7")
        self.recorded.layer, self.recorded.sublevel = layer, sublevel
    end

    -- No font metrics here: a rough width from the length keeps layout
    -- arithmetic honest about types, not about pixels. Colour codes take no
    -- room, as in the client.
    local function Shown(text)
        return ((text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:|]*:", ""):gsub("|H.-|h", ""):gsub("|h", "")
            :gsub("|r", ""))
    end
    function w:GetStringWidth() return #Shown(self.text) * 6 end
    function w:GetStringHeight() return self.text ~= "" and 14 or 0 end
    function w:GetUnboundedStringWidth() return #Shown(self.text) * 6 end
    function w:IsTruncated() return true end
    -- A frame's level: the one it was given, else one over its parent's,
    -- as the client gives a new frame.
    function w:GetFrameLevel()
        local level = rec.calls.SetFrameLevel
        if level then return level[1] end
        local parent = self.parent
        return parent and parent.GetFrameLevel and parent:GetFrameLevel() + 1 or 1
    end
    w.width = 0
    function w:GetWidth() return self.width end
    function w:SetWidth(value) self.width, rec.width = value, value end
    function w:SetHeight(value) rec.height = value end
    function w:SetSize(width, height) self.width, rec.width, rec.height = width, width, height end

    function w:RegisterEvent(event)
        self.events[event] = true
        M.registered[event] = true
    end

    -- The units are not kept: fire delivers to every frame, and a handler
    -- that asked for "player" checks its unit anyway.
    function w:RegisterUnitEvent(event)
        self:RegisterEvent(event)
    end

    function w:UnregisterEvent(event)
        self.events[event] = nil
        for i = 1, #M.frames do
            if M.frames[i].events[event] then return end
        end
        M.registered[event] = nil
    end

    function w:SetChecked(value) self.checked = value and true or false end
    function w:GetChecked() return self.checked == true end

    -- A model frame, as far as reading what it shows: a creature's display
    -- (M.creatureDisplays, by NPC id) on the second read, as the client
    -- takes a moment to load it; 0 for a creature not in the cache.
    -- M.models counts SetCreature calls.
    if frameType == "PlayerModel" then
        function w:SetCreature(npcID)
            M.models = (M.models or 0) + 1
            self.display, self.loading = M.creatureDisplays[npcID] or 0, true
        end
        function w:GetDisplayInfo()
            if self.loading then
                self.loading = false
                return 0
            end
            return self.display or 0
        end

        -- Drawing from a display (the killer card, Features/Deaths/Card.lua): none
        -- of it verified in the client, so each call is only recorded, on
        -- `w.model` (its last arguments by method), for the tests to read.
        -- A display in M.blankDisplays draws nothing (GetModelFileID 0, as
        -- one the client cannot find). A method named in M.modelLacks is
        -- left off every model made after, as a client without it would.
        local calls = {}
        w.model = calls
        local function Record(method, fn)
            if (M.modelLacks or {})[method] then return end
            w[method] = function(self, ...)
                calls[method] = Pack(...)
                if fn then return fn(self, ...) end
            end
        end
        Record("SetDisplayInfo", function(self, display) self.display, self.loading = display, false end)
        Record("GetModelFileID", function(self)
            if not self.display or self.display == 0 or (M.blankDisplays or {})[self.display] then return 0 end
            return 100000 + self.display
        end)
        for _, method in ipairs({ "SetFogColor", "SetFogNear", "SetFogFar", "SetFacing", "SetPortraitZoom",
            "SetCamDistanceScale", "SetViewTranslation", "FreezeAnimation", "SetAnimation", "SetPaused", "SetLight",
            "ClearModel" }) do
            Record(method)
        end
        Record("HasAnimation", function(_, id) return id == 0 end)
        Record("HasScript", function(_, script) return script == "OnModelLoaded" end)
    end

    -- Simulates a click on a button. A check button flips before OnClick,
    -- as in the client.
    function w:Click(...)
        if self.frameType == "CheckButton" then self.checked = not self.checked end
        if self.scripts.OnClick then self.scripts.OnClick(self, ...) end
    end

    -- Widget methods are UpperCamelCase without exception, so an unknown one
    -- is a mock gap worth raising on. Anything else is a field the addon hung
    -- on the frame and has not set yet, where nil is the honest answer.
    setmetatable(w, {
        __index = function(_, key)
            if type(key) == "string" and key:match("^%u") then
                error(("widget method not modelled in wowmock: %s (on a %s)")
                    :format(key, frameType), 2)
            end
            return nil
        end,
    })

    M.frames[#M.frames + 1] = w
    return w
end

M.NewWidget = NewWidget

-- The globals named frames and fonts went into, for Reset. Not w.name: the
-- addon is free to hang its own `name` (a font string, say) on a frame.
local named = {}

_G.CreateFrame = function(frameType, name, parent, template)
    local w = NewWidget(frameType or "Frame", name, parent, template)
    if name then _G[name], named[#named + 1] = w, name end
    return w
end

_G.CreateFont = function(name)
    local font = NewWidget("Font", name)
    if name then _G[name], named[#named + 1] = font, name end
    return font
end

_G.CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
_G.CreateVector3D = function(x, y, z) return { x = x, y = y, z = z } end

-- A creature display's 2D portrait onto a texture (the killer card's
-- print): recorded as the texture's `portrait`.
_G.SetPortraitTextureFromCreatureDisplayID = function(texture, display) texture.portrait = display end

-- Sounds: a few SOUNDKIT names, and what was played, in order, as
-- { id, channel }.
_G.SOUNDKIT = { IG_QUEST_LOG_OPEN = 844, IG_QUEST_LOG_CLOSE = 845, IG_SPELLBOOK_OPEN = 829,
    IG_SPELLBOOK_CLOSE = 830, IG_CHARACTER_INFO_TAB = 841, IG_ABILITY_PAGE_TURN = 836,
    IG_WRITE_QUEST = 3093, IG_QUEST_LIST_SELECT = 877, RAID_WARNING = 8959,
    IG_BACKPACK_OPEN = 862 }
M.sounds = {}
_G.PlaySound = function(id, channel) M.sounds[#M.sounds + 1] = { id, channel } end

-- Every art path exists, unless a test says otherwise.
M.missingFiles = {}
_G.GetFileIDFromPath = function(path)
    if M.missingFiles[path] then return nil end
    return 1
end

_G.UIParent = NewWidget("Frame", "UIParent")

-- Blizzard's callback registry, as far as Edit Mode's two events: a test
-- calls M.EditMode(true) to open it and M.EditMode(false) to close it.
local function NewEventRegistry()
    local registry = { callbacks = {} }
    function registry:RegisterCallback(event, fn, owner)
        local list = self.callbacks[event] or {}
        self.callbacks[event] = list
        list[#list + 1] = { fn = fn, owner = owner }
    end
    function registry:TriggerEvent(event, ...)
        for _, cb in ipairs(self.callbacks[event] or {}) do cb.fn(cb.owner, ...) end
    end
    return registry
end
_G.EventRegistry = NewEventRegistry()

function M.EditMode(open)
    _G.EventRegistry:TriggerEvent(open and "EditMode.Enter" or "EditMode.Exit")
end
_G.UISpecialFrames = {}

_G.C_AddOns = {
    GetAddOnMetadata = function(_, k) return k == "Version" and "1.0.0" or nil end,
    LoadAddOn = function() end,
}

_G.GetServerTime = function() return M.now end
_G.GetBuildInfo = function() return "1.60.1", "69893", "Sep 17 2026", 16001 end
_G.GetLocale = function() return "enUS" end
_G.GetRealmName = function() return M.realm end
_G.GetNormalizedRealmName = function() return (M.realm:gsub("%s+", "")) end
_G.SlashCmdList = {}

--------------------------------------------------------------------------
-- Where the player is (Mulgore, as Session 1 saw it)
--------------------------------------------------------------------------

M.zone, M.subZone = "Mulgore", ""
M.mapID = 1412
M.position = { x = 0.4213, y = 0.6157 }
M.inInstance, M.instanceName, M.instanceID = false, "The Deadmines", 36

_G.GetRealZoneText = function() return M.inInstance and M.instanceName or M.zone end
_G.GetZoneText = function() return M.zone end

-- "sanctuary", "friendly", "hostile", "contested" or nil.
M.pvpType = nil
_G.GetZonePVPInfo = function() return M.pvpType end
_G.GetSubZoneText = function() return M.subZone end

M.instanceType = "party"
_G.IsInInstance = function()
    if not M.inInstance then return false, "none" end
    return true, M.instanceType
end

_G.GetInstanceInfo = function()
    return M.instanceName, M.instanceType, 1, "Normal", 5, 0, 0, M.instanceID
end

-- Map art as a classic zone has it: one 1002 x 668 layer of 256-pixel tiles,
-- 4 x 3 of them. Maps not listed in M.mapArt have no art.
M.mapNames = { [1412] = "Mulgore", [1413] = "The Barrens", [1414] = "Kalimdor",
    [2000] = "Palemane Rock", [1454] = "Orgrimmar" }
M.mapArt = { [1412] = true, [1413] = true }
-- The areas explored on a map, as C_MapExplorationInfo hands them back.
M.explored = {}

-- The map tree, as Enum.UIMapType has it (2 continent, 3 zone, 5 micro):
-- a map not listed here is a zone, with no parent unless one is given.
-- 2000 is a cave in Mulgore, with its own 0..1 square.
M.mapTypes = { [1414] = 2, [2000] = 5 }
M.mapParents = { [2000] = 1412 }

-- Where each map lies in the world, in yards: left, top, width, height
-- (x right, y down; the C_Map world vectors turn these into the client's
-- (north, west)). A map not listed cannot be placed (GetWorldPosFromMapPos
-- returns nothing for it). Continent 1 for all of them.
M.mapRects = {
    [1412] = { 0, 0, 5000, 3333 },
    [1413] = { 5000, 0, 6000, 4000 },
    [2000] = { 1000, 1000, 200, 150 },
}

-- The player in the world, as UnitPosition hands it: { x, y, inst }, or nil
-- for no reading.
M.world = nil

_G.C_Map = {
    GetMapInfo = function(mapID)
        if not M.mapNames[mapID] then return nil end
        return { mapID = mapID, name = M.mapNames[mapID], mapType = M.mapTypes[mapID] or 3,
            parentMapID = M.mapParents[mapID] }
    end,
    -- The world vector as the client hands it: (north, west), so its
    -- first axis runs down the map, against y, and its second across it,
    -- against x (HereBeDragons: `local top, left = topleft:GetXY()`).
    GetWorldPosFromMapPos = function(mapID, pos)
        local r = M.mapRects[mapID]
        if not r then return nil end
        return 1, CreateVector2D(-(r[2] + pos.y * r[4]), -(r[1] + pos.x * r[3]))
    end,
    GetMapPosFromWorldPos = function(_, world, mapID)
        local r = M.mapRects[mapID]
        if not r then return nil end
        return mapID, CreateVector2D((-world.y - r[1]) / r[3], (-world.x - r[2]) / r[4])
    end,
    GetMapWorldSize = function(mapID)
        local r = M.mapRects[mapID]
        if not r then return 0, 0 end
        return r[3], r[4]
    end,
    GetMapArtLayers = function(mapID)
        if not M.mapArt[mapID] then return nil end
        return { { layerWidth = 1002, layerHeight = 668, tileWidth = 256, tileHeight = 256 } }
    end,
    GetMapArtLayerTextures = function(mapID)
        if not M.mapArt[mapID] then return nil end
        local files = {}
        for i = 1, 12 do files[i] = mapID * 100 + i end
        return files
    end,
    GetBestMapForUnit = function() return M.mapID end,
    GetPlayerMapPosition = function()
        if not M.position then return nil end
        -- A restricted map hands back the whole position secret (12.0.5).
        if issecretvalue(M.position) then return M.position end
        local p = M.position
        return { GetXY = function() return p.x, p.y end }
    end,
}

_G.C_MapExplorationInfo = {
    GetExploredMapTextures = function(mapID) return M.explored[mapID] end,
}

_G.CreateVector2D = function(x, y)
    return { x = x, y = y, GetXY = function(self) return self.x, self.y end }
end

-- y first, as the client hands it.
_G.UnitPosition = function()
    local w = M.world
    if not w then return nil end
    return w.y, w.x, 0, w.inst or 1
end

M.onTaxi, M.afk, M.dead, M.ghost, M.resting = false, false, false, false, false
M.maxLevel = 60
_G.UnitOnTaxi = function() return M.onTaxi end
_G.UnitIsAFK = function() return M.afk end
_G.UnitIsDeadOrGhost = function() return M.dead or M.ghost end
_G.UnitIsGhost = function() return M.ghost end
_G.IsResting = function() return M.resting end
_G.GetMaxPlayerLevel = function() return M.maxLevel end

-- JRN-25: the player's health. Secret in combat on the client (probe, 11
-- Oct); a test makes it so with M.secret.
M.health, M.healthMax = 100, 100
_G.UnitHealth = function() return M.health end
_G.UnitHealthMax = function() return M.healthMax end

-- JRN-26: the quest log, as the current API reads it. M.quests is a list
-- of { questID, title, objectives = { { text, type, numFulfilled,
-- numRequired, finished } } }.
M.quests = {}
_G.C_QuestLog = {
    GetNumQuestLogEntries = function() return #M.quests, #M.quests end,
    GetInfo = function(i)
        local q = M.quests[i]
        return q and { questID = q.questID, title = q.title, isHeader = false }
    end,
    GetQuestObjectives = function(questID)
        for _, q in ipairs(M.quests) do
            if q.questID == questID then return q.objectives end
        end
    end,
}

-- The loot window: M.loot is a list of { link, sources = { guid, n, ... } }.
M.loot = {}
_G.GetNumLootItems = function() return #M.loot end
_G.GetLootSlotLink = function(slot) return M.loot[slot] and M.loot[slot].link end
_G.GetLootSourceInfo = function(slot) return unpack(M.loot[slot] and M.loot[slot].sources or {}) end

--------------------------------------------------------------------------
-- Trade (T-E8). LE_GAME_ERR_* is deliberately left undefined so the capture
-- code's fallback to the observed message ids is what gets exercised.
--------------------------------------------------------------------------

_G.MAX_TRADE_ITEMS = 7
M.trade = { given = {}, received = {}, moneyGiven = 0, moneyReceived = 0 }

local function Slot(side, slot)
    return M.trade[side][slot]
end

_G.GetTradePlayerItemInfo = function(slot)
    local item = Slot("given", slot)
    if not item then return nil end
    return item.name, nil, item.count
end

_G.GetTradeTargetItemInfo = function(slot)
    local item = Slot("received", slot)
    if not item then return nil end
    return item.name, nil, item.count
end

_G.GetTradePlayerItemLink = function(slot)
    local item = Slot("given", slot)
    return item and item.link
end

_G.GetTradeTargetItemLink = function(slot)
    local item = Slot("received", slot)
    return item and item.link
end

_G.GetPlayerTradeMoney = function() return M.trade.moneyGiven end
_G.GetTargetTradeMoney = function() return M.trade.moneyReceived end

--------------------------------------------------------------------------
-- Bags and what is worn (Your Diary's firsts). M.bags[bag] = { size,
-- [slot] = { link, quality } }, bag 0 the backpack; a bag in a bag slot
-- is M.equipped[19 + bag]. M.itemInfo[itemID] = { equipLoc, classID,
-- subclassID }, what C_Item.GetItemInfoInstant reads without the cache.
--------------------------------------------------------------------------

_G.NUM_BAG_SLOTS = 4
M.bags = { [0] = { size = 16 } }
M.equipped = {}
M.itemInfo = {}

_G.C_Container = {
    GetContainerNumSlots = function(bag)
        local b = M.bags[bag]
        if b then return b.size end
        local worn = M.equipped[19 + bag]
        return worn and worn.size or 0
    end,
    GetContainerItemInfo = function(bag, slot)
        local b = M.bags[bag]
        local item = b and b[slot]
        if not item then return nil end
        return { hyperlink = item.link, quality = item.quality, itemID = tonumber(item.link:match("item:(%d+)")) }
    end,
    ContainerIDToInventoryID = function(bag) return 19 + bag end,
}

_G.GetInventoryItemLink = function(_, slot)
    local item = M.equipped[slot]
    return item and item.link
end

_G.GetInventoryItemQuality = function(_, slot)
    local item = M.equipped[slot]
    return item and item.quality
end

-- M.itemInfo[itemID].icon is its icon (134400, the question mark, else);
-- .quality what GetItemQualityByID says (nil, not cached, else).
_G.C_Item = {
    GetItemInfoInstant = function(id)
        local info = M.itemInfo[tonumber(id)]
        if not info then return id, "Miscellaneous", "Junk", "", 134400, 15, 0 end
        return id, nil, nil, info.equipLoc or "", info.icon or 134400, info.classID or 15, info.subclassID or 0
    end,
    GetItemIconByID = function(id)
        local info = M.itemInfo[tonumber(id)]
        return info and info.icon or 134400
    end,
    GetItemQualityByID = function(id)
        local info = M.itemInfo[tonumber(id)]
        return info and info.quality
    end,
}

--------------------------------------------------------------------------
-- Professions (Your Diary's skill caps): the modern API, as on Forever.
-- M.professions[slot] = { name, rank, max, line }; a slot left nil is one
-- GetProfessions gives as nil (no second profession, no fishing).
--------------------------------------------------------------------------

M.professions = {}

_G.GetProfessions = function()
    local p = M.professions
    return p[1] and 1, p[2] and 2, p[3] and 3, p[4] and 4, p[5] and 5
end

_G.GetProfessionInfo = function(index)
    local p = M.professions[index]
    if not p then return nil end
    return p.name, 136235, p.rank, p.max, 0, 0, p.line, 0, -1, 0, p.name
end

--------------------------------------------------------------------------
-- Timers
--------------------------------------------------------------------------

M.timers = {}
M.tickers = {}

-- Tickers are recorded, never run: tests drive the tick function directly,
-- with the clock where they want it.
_G.C_Timer = {
    After = function(delay, fn) M.timers[#M.timers + 1] = { delay = delay, fn = fn } end,
    NewTicker = function(interval, fn)
        local ticker = { interval = interval, fn = fn, Cancel = function() end }
        M.tickers[#M.tickers + 1] = ticker
        return ticker
    end,
}

-- Fires every pending timer regardless of its delay.
function M.RunTimers()
    local due = M.timers
    M.timers = {}
    for i = 1, #due do due[i].fn() end
end

--------------------------------------------------------------------------
-- The rest of the client the UI leans on
--------------------------------------------------------------------------

-- A clock that advances by `clockStep` ms on every read, so a test can make
-- work look expensive and watch the frame budget cut it off.
M.clock, M.clockStep = 0, 0
_G.debugprofilestop = function()
    M.clock = M.clock + M.clockStep
    return M.clock
end

M.cvars = { nameplateShowFriends = "0", nameplateShowEnemies = "1", nameplateMaxDistance = "41" }
_G.GetCVar = function(name) return M.cvars[name] end

_G.date = os.date
_G.CANCEL = "Cancel"

_G.RAID_CLASS_COLORS = {
    DRUID = { r = 1.00, g = 0.49, b = 0.04 },
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
    MAGE = { r = 0.41, g = 0.80, b = 0.94 },
}

M.guild = nil
_G.GetGuildInfo = function() return M.guild end

M.inRaid, M.groupSize = false, 0
_G.IsInRaid = function() return M.inRaid end
_G.IsInGroup = function() return M.groupSize > 0 end
_G.GetNumGroupMembers = function() return M.groupSize end

-- DIA-2a's unknown: whether this resolves in a build with no realm names.
M.locationGUID = nil
_G.C_PlayerInfo = {
    GetGUIDFromPlayerLocation = function() return M.locationGUID end,
}

M.popups = {}
_G.StaticPopupDialogs = {}
-- As the client's: two text arguments, then the data the buttons get.
_G.StaticPopup_Show = function(which, text1, text2, data)
    local popup = { which = which, args = { text1, text2 }, data = data }
    M.popups[#M.popups + 1] = popup
    return popup
end

-- Runs a button on the most recent popup: "accept", "cancel" or "alt".
function M.AnswerPopup(button)
    local popup = M.popups[#M.popups]
    if not popup then return false end

    local dialog = StaticPopupDialogs[popup.which]
    local handler = dialog and dialog[
        button == "alt" and "OnAlt" or button == "cancel" and "OnCancel" or "OnAccept"]
    if not handler then return false end

    handler(popup, popup.data)
    return true
end

-- /reload: counted, so a test can tell it was asked for. Nothing reloads.
M.reloads = 0
_G.ReloadUI = function() M.reloads = M.reloads + 1 end

-- Menu.ModifyMenu callbacks, so a right-click can be simulated.
M.menus = {}
_G.Menu = {
    ModifyMenu = function(tag, callback)
        M.menus[tag] = M.menus[tag] or {}
        M.menus[tag][#M.menus[tag] + 1] = callback
    end,
}

-- MenuUtil.CreateContextMenu, for the journal's sort and filter menus. The
-- generator runs against a recorder; MenuClick walks it by label text.
local function Description(text, kind, a, b)
    local d = { text = text, kind = kind, a = a, b = b, children = {} }
    local function Adder(childKind)
        return function(self, childText, x, y)
            local child = Description(childText, childKind, x, y)
            self.children[#self.children + 1] = child
            return child
        end
    end
    d.CreateTitle = Adder("title")
    d.CreateButton = Adder("button")
    d.CreateRadio = Adder("radio")
    d.CreateCheckbox = Adder("checkbox")
    d.CreateDivider = Adder("divider")
    return d
end

M.contextMenu = nil
_G.MenuUtil = {
    CreateContextMenu = function(owner, generator)
        local root = Description(nil, "root")
        generator(owner, root)
        M.contextMenu = root
        return root
    end,
}

-- M.MenuClick("Tag", "friend") picks the radio under the submenu. Returns
-- false when the path does not exist.
function M.MenuClick(...)
    local node = M.contextMenu
    for i = 1, select("#", ...) do
        local want, found = select(i, ...), nil
        for _, child in ipairs(node and node.children or {}) do
            if child.text == want then found = child break end
        end
        if not found then return false end
        node = found
    end

    if node.kind == "radio" or node.kind == "checkbox" then
        node.b()
    elseif node.kind == "button" and node.a then
        node.a()
    end
    return true
end

-- Whether a radio in the last context menu reads as selected.
function M.MenuSelected(...)
    local node = M.contextMenu
    for i = 1, select("#", ...) do
        local want, found = select(i, ...), nil
        for _, child in ipairs(node and node.children or {}) do
            if child.text == want then found = child break end
        end
        if not found then return nil end
        node = found
    end
    return node.a and node.a() or false
end

_G.wipe = function(t)
    for key in pairs(t) do t[key] = nil end
    return t
end

-- The canvas half of the Settings API, which is all the addon uses.
M.settingsCategories, M.openedCategory = {}, nil
_G.Settings = {
    RegisterCanvasLayoutCategory = function(frame, name)
        local category = { frame = frame, name = name, ID = #M.settingsCategories + 100 }
        function category:GetID() return self.ID end
        return category
    end,
    RegisterAddOnCategory = function(category)
        M.settingsCategories[#M.settingsCategories + 1] = category
    end,
    OpenToCategory = function(id)
        M.openedCategory = id
        for _, category in ipairs(M.settingsCategories) do
            if category.ID == id then category.frame:Show() end
        end
    end,
}

-- REU-2's combat check.
M.inCombat = false
_G.InCombatLockdown = function() return M.inCombat end
_G.UnitAffectingCombat = function() return M.inCombat end

-- Key bindings, for the empty People page's keycap: M.bindings is key to
-- command, as the client keeps them; SetBinding with no command unbinds,
-- and refuses in combat. M.bindingSaves counts SaveBindings. M.modifiers
-- says which of alt, ctrl and shift are held.
M.bindings, M.bindingSaves, M.modifiers = {}, 0, {}
_G.GetBindingKey = function(command)
    local keys = {}
    for key, bound in pairs(M.bindings) do
        if bound == command then keys[#keys + 1] = key end
    end
    table.sort(keys)
    return unpack(keys)
end
_G.GetBindingAction = function(key) return M.bindings[key] or "" end
_G.SetBinding = function(key, command)
    if M.inCombat then return false end
    M.bindings[key] = command
    return true
end
_G.SaveBindings = function(set) M.bindingSaves, M.bindingSet = M.bindingSaves + 1, set end
_G.GetCurrentBindingSet = function() return 2 end
_G.GetBindingText = function(key) return key end
_G.IsAltKeyDown = function() return M.modifiers.alt == true end
_G.IsControlKeyDown = function() return M.modifiers.ctrl == true end
_G.IsShiftKeyDown = function() return M.modifiers.shift == true end

-- The mouse on the screen, in the client's pixels (GetCursorPosition):
-- what a test says, M.pointer = { x, y }; scaled by a frame's
-- GetEffectiveScale (its `effectiveScale`, else 1).
M.pointer = { 0, 0 }
_G.GetCursorPosition = function() return M.pointer[1], M.pointer[2] end

-- Macros, for the book Settings puts on an action bar: M.macros holds the
-- account's, in order, as { name, icon, body }; the index is the position,
-- as the client numbers account macros from 1. M.maxMacros is how many fit
-- (the client's 120 unless a test says otherwise); CreateMacro past it,
-- or in combat, errors as the client does. M.cursor is what PickupMacro
-- put on the cursor, { "macro", index }, until ClearCursor.
M.macros, M.maxMacros, M.cursor = {}, 120, nil
_G.GetMacroIndexByName = function(name)
    for i, macro in ipairs(M.macros) do
        if macro.name == name then return i end
    end
    return 0
end
_G.GetNumMacros = function() return #M.macros, 0 end
_G.CreateMacro = function(name, icon, body, perCharacter)
    assert(not perCharacter, "the mock models account macros only")
    if M.inCombat then error("Cannot create macros in combat") end
    if #M.macros >= M.maxMacros then error("Too many macros") end
    M.macros[#M.macros + 1] = { name = name, icon = icon, body = body }
    return #M.macros
end
_G.PickupMacro = function(index)
    if M.macros[index] then M.cursor = { "macro", index } end
end
_G.GetCursorInfo = function()
    if M.cursor then return unpack(M.cursor) end
end
_G.ClearCursor = function() M.cursor = nil end

-- REU-4. M.UnitTooltip(guid) runs every registered unit post-call against a
-- fresh tooltip and returns the lines added.
_G.Enum = { TooltipDataType = { Unit = 2 } }
M.tooltipCalls = {}
_G.TooltipDataProcessor = {
    AddTooltipPostCall = function(kind, fn)
        M.tooltipCalls[kind] = M.tooltipCalls[kind] or {}
        table.insert(M.tooltipCalls[kind], fn)
    end,
}

function M.UnitTooltip(guid)
    local lines = {}
    local tooltip = { AddLine = function(_, text) lines[#lines + 1] = text end }
    for _, fn in ipairs(M.tooltipCalls[Enum.TooltipDataType.Unit] or {}) do
        fn(tooltip, { guid = guid, type = Enum.TooltipDataType.Unit })
    end
    return lines
end

-- What it was last told: `text`, `link` (SetHyperlink) and the `lines`
-- added since SetOwner, each { text, r, g, b, wrap }.
_G.GameTooltip = {
    SetOwner = function(self) self.lines, self.link = {}, nil end,
    SetText = function(self, text) self.text = text end,
    SetHyperlink = function(self, link) self.link = link end,
    AddLine = function(self, text, r, g, b, wrap)
        self.lines = self.lines or {}
        self.lines[#self.lines + 1] = { text, r, g, b, wrap }
    end,
    Show = function(self) self.shown = true end,
    Hide = function(self) self.shown = false end,
}

-- Returns the buttons the addon added to that menu.
function M.OpenMenu(tag, contextData)
    local buttons = {}
    local root = {
        CreateDivider = function() end,
        CreateButton = function(_, text, callback)
            buttons[#buttons + 1] = { text = text, Click = callback }
            return {}
        end,
    }

    for _, callback in ipairs(M.menus[tag] or {}) do
        callback(nil, root, contextData)
    end

    return buttons
end

--------------------------------------------------------------------------

function M.fire(event, ...)
    for i = 1, #M.frames do
        local frame = M.frames[i]
        if frame.events[event] and frame.scripts.OnEvent then
            frame.scripts.OnEvent(frame, event, ...)
        end
    end
end

-- Loads the addon exactly as the TOC does: one shared namespace, in order.
-- The TOC's SavedVariables are noted, so Reset can take them away again.
function M.LoadAddon(root)
    local ns = {}
    for line in io.lines(root .. "/social_diary.toc") do
        local saved = line:match("^##%s*SavedVariables[%w]*:%s*(.-)%s*$")
        for name in (saved or ""):gmatch("[%w_]+") do
            M.savedVariables[#M.savedVariables + 1] = name
        end

        local file = line:match("^([%w_]+/[%w_/]+%.lua)%s*$")
        if file then
            -- loadfile's own message names the line of a syntax error; a
            -- generic "cannot load" would hide it.
            local chunk, err = loadfile(root .. "/" .. file)
            assert(chunk, err)
            chunk("social_diary", ns)
        end
    end
    return ns
end

M.savedVariables = {}

--------------------------------------------------------------------------
-- A fresh client
--------------------------------------------------------------------------
--
-- Each test file loads its own copy of the addon. Without a reset the old
-- copy would still be listening: its frames stay in M.frames, so M.fire
-- would run both copies' handlers, and its timers, menus and tooltip hooks
-- would fire alongside the new ones. Reset puts every plain field above
-- back to its value at load and empties what the client keeps between
-- addons: frames, named globals, saved variables, slash commands, popups.

local function Copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = Copy(v) end
    return out
end

-- Frames hold widgets, and `registered` follows them; both start empty.
local initial = {}
for key, value in pairs(M) do
    if type(value) ~= "function" and key ~= "frames" and key ~= "registered" then
        initial[key] = Copy(value)
    end
end

function M.Reset()
    for i = 1, #named do _G[named[i]] = nil end
    wipe(named)
    for i = 1, #M.savedVariables do _G[M.savedVariables[i]] = nil end

    for key, value in pairs(M) do
        if type(value) ~= "function" then M[key] = nil end
    end
    for key, value in pairs(initial) do M[key] = Copy(value) end
    M.frames, M.registered, M.sounds = {}, {}, {}

    _G.UIParent = NewWidget("Frame", "UIParent")
    _G.EventRegistry = NewEventRegistry()
    _G.UISpecialFrames = {}
    _G.SlashCmdList = {}
    _G.StaticPopupDialogs = {}
    _G.ChatTypeInfo = nil
    GameTooltip.text, GameTooltip.shown, GameTooltip.link, GameTooltip.lines = nil, nil, nil, nil
end

return M
