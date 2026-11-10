-- Campfires' words on Your Diary's plates: the slip's (Slip.lua), the
-- mark's and the slip's tooltip, and the caption's words where the slip
-- found no room (Text.RegisterCaption, UI/Journey/Text/Caption.lua). Copy
-- changes go through the copywriter skill, as every player-read word does.

local addonName, ns = ...

local Campfire = ns.Campfire
local Text = ns.UI.JourneyText
local Capital, List, MapName = Text.Capital, Text.List, Text.MapName
local L, Fmt = ns.L, ns.Fmt

-- The margin's slip for a campfire on a plate (Slip.lua): the user's own
-- words (14 Oct), exactly, lower case and all, however many fires the
-- plate has. Not to be reworded.
Campfire.WORDS = L["sat by a campfire"]

-- The subzone a plate's campfires (records { t, subZone, ... }) all share,
-- or nil where they differ, where one has none, or where it is only the
-- zone's own name (`zone`).
function Campfire.At(fires, zone)
    local at
    for _, fire in ipairs(fires) do
        local sub = fire.subZone
        if type(sub) ~= "string" or sub == "" or (at and sub ~= at) then return nil end
        at = sub
    end
    if at == zone then return nil end
    return at
end

-- When the sittings were, and at what level, as every mark's tooltip on the
-- plates ends (the core's Text.Foot and Text.Moments, UI/Journey/Text/
-- Tips.lua): each time, a day said once for the times on it, past four
-- the first to the last, then the levels after a comma, "Today at 12:47
-- and 15:10, level 20", "Today from 12:47 to 19:02, levels 19 to 20".
-- The tames' tooltip says its times the same way, without the level.
local function Foot(ts, lo, hi, now)
    return Text.Foot({ times = ts, levelFrom = lo, levelTo = hi }, now)
end

-- The fire's mark and the slip, under the mouse: one account of every
-- sitting it stands for (a list of one for a fire sat by once). "Sat by a
-- campfire", or how often, "Sat by a campfire twice", "... 3 times"; where,
-- each place once ("In Lushwater Oasis", "In Lushwater Oasis and The
-- Stagnant Oasis", only a subzone that is not its zone's name); then the
-- times and the level: "Yesterday at 21:40 and today at 08:10, levels 11
-- to 12". (9 Nov: a fire sat by three times told "Sat by a campfire" and
-- its place three times over.)
function Campfire.Tips(fires, now)
    local places, seen = {}, {}
    local ts, lo, hi = {}, nil, nil
    local j = ns.Journey.For and ns.Journey.For(ns.ownGUID)
    for _, fire in ipairs(fires) do
        local sub = fire.subZone
        if type(sub) == "string" and sub ~= "" and sub ~= MapName(fire.mapID) and not seen[sub] then
            seen[sub] = true
            places[#places + 1] = sub
        end
        ts[#ts + 1] = fire.t or 0
        local level = j and ns.JourneyRecap and ns.JourneyRecap.LevelAt(j, fire.t or 0) or nil
        if level then
            lo = (not lo or level < lo) and level or lo
            hi = (not hi or level > hi) and level or hi
        end
    end
    local lines = {}
    if places[1] then lines[1] = Capital(ns.ZonesIn(places, "in", List)) end
    lines[#lines + 1] = Foot(ts, lo, hi, now)
    local title = Capital(Campfire.WORDS)
    if #fires > 1 then title = Fmt(L["Sat by a campfire %s##times"], ns.UI.Format.Times(#fires)) end
    return title, lines
end

-- One sitting's tooltip, as its fire's alone (Campfire.Tips).
function Campfire.Tip(fire, now)
    return Campfire.Tips({ fire }, now)
end

-- A line of a menu, where a spot merges several fires or one is hidden (the
-- form's `describe`, Kind.lua): a fire sat by twice is the one place twice, so
-- only the time tells its sittings apart. "Lushwater Oasis, yesterday, 21:40",
-- or "A campfire, yesterday, 21:40" with no place to name.
function Campfire.Describe(fire)
    local sub = fire.subZone
    local place = type(sub) == "string" and sub ~= "" and sub or L["A campfire"]
    return Fmt(L["%1$s, %2$s"], place, ns.UI.Format.At(fire.t or 0, ns.Now()))
end

-- The caption's words. `said.campfire` (true): the plate's slip ("sat by a
-- campfire") found no room in the margin, so the words say it, last of
-- everything and as short as the rest of the list (", and a campfire"),
-- or lead where nothing else does ("By a campfire in Lushwater Oasis.").
-- With the slip beside the plate the words say nothing of it, but where
-- the fire is all there is they name its place ("Lushwater Oasis.") for
-- the slip to finish. "A campfire", sat by once or more at one place;
-- "campfires" at several: as short as the deaths and close calls beside
-- them, as FL's print has two lines for its words (14 Oct, rasterised:
-- "and a rest by a campfire" ran a third line past the page's foot).
-- Where they were: the subzone they share, if it is not the zone's own
-- name.
--
-- Its lead (`at` 140) comes after a long stay (120) and the company (130),
-- before a level's pin (150); its tail (`at` 90) after every other kind's.
local function One(fires)
    return #fires == 1 or Campfire.At(fires) ~= nil
end

local function Camped(fires)
    return One(fires) and L["a campfire"] or L["campfires"]
end

-- The lead where the words say it and there is no place: "By a campfire",
-- "By campfires", whole, as a translation's case goes with its noun.
local function By(fires)
    return One(fires) and L["By a campfire"] or L["By campfires"]
end

Text.RegisterCaption("campfire", {
    moment = "campfire",
    take = function(m) return m.campfire end,
    lead = { at = 140, say = function(fires, c)
        local spot = Campfire.At(fires, MapName(c.plate.mapID))
        -- The place is a subzone (no id): its phrase is ns.ZoneIn's, by
        -- the client's name. "By a campfire in Lushwater Oasis".
        if c.said.campfire then
            if not spot then return By(fires) end
            local place = ns.ZoneIn(nil, spot)
            return One(fires) and Fmt(L["By a campfire %s##zone"], place) or Fmt(L["By campfires %s##zone"], place)
        end
        return spot
    end },
    tail = { at = 90, say = function(fires, c) return c.said.campfire and Camped(fires) or nil end },
})
