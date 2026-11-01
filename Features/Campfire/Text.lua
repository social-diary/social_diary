-- Campfires' words on Your Diary's plates: the slip's (Slip.lua), the
-- mark's and the slip's tooltip, and the caption's words where the slip
-- found no room (Text.RegisterCaption, UI/Journey/Text/Caption.lua). Copy
-- changes go through the copywriter skill, as every player-read word does.

local addonName, ns = ...

local Campfire = ns.Campfire
local Text = ns.UI.JourneyText
local Capital, MapName, When = Text.Capital, Text.MapName, Text.When

-- The margin's slip for a campfire on a plate (Slip.lua): the user's own
-- words (14 Oct), exactly, lower case and all, however many fires the
-- plate has. Not to be reworded.
Campfire.WORDS = "sat by a campfire"

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

-- The fire's mark and its slip, under the mouse: "Sat by a campfire", then
-- where ("In Lushwater Oasis", where there is a subzone that is not the
-- zone's name) and when ("Yesterday, 21:40, at level 12").
function Campfire.Tip(fire, now)
    local lines = {}
    local sub = fire.subZone
    if type(sub) == "string" and sub ~= "" and sub ~= MapName(fire.mapID) then lines[#lines + 1] = "In " .. sub end
    local j = ns.Journey.For and ns.Journey.For(ns.ownGUID)
    local level = j and ns.JourneyRecap and ns.JourneyRecap.LevelAt(j, fire.t or 0) or nil
    lines[#lines + 1] = When(fire.t or 0, level, now)
    return Capital(Campfire.WORDS), lines
end

-- A line of a menu, where a spot merges several fires or one is hidden (the
-- form's `describe`, Kind.lua): a fire sat by twice is the one place twice, so
-- only the time tells its sittings apart. "Lushwater Oasis, yesterday, 21:40",
-- or "A campfire, yesterday, 21:40" with no place to name.
function Campfire.Describe(fire)
    local sub = fire.subZone
    local place = type(sub) == "string" and sub ~= "" and sub or "A campfire"
    return place .. ", " .. ns.UI.Format.At(fire.t or 0, ns.Now())
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
local function Camped(fires)
    if #fires == 1 or Campfire.At(fires) then return "a campfire" end
    return "campfires"
end

Text.RegisterCaption("campfire", {
    moment = "campfire",
    take = function(m) return m.campfire end,
    lead = { at = 140, say = function(fires, c)
        local spot = Campfire.At(fires, MapName(c.plate.mapID))
        if c.said.campfire then return "By " .. Camped(fires) .. (spot and (" in " .. spot) or "") end
        return spot
    end },
    tail = { at = 90, say = function(fires, c) return c.said.campfire and Camped(fires) or nil end },
})
