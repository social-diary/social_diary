-- Fishing: what the player fished up, each where they stood. A feature in a
-- folder of its own (.claude/skills/new-feature/folder.md):
--
--   Kind.lua     what a catch is to the diary: the route's list and the
--                recap's moment
--   Text.lua     its words: the mark's tooltip
--   Mark.lua     its mark on the plates (a fish)
--   Capture.lua  the loot window of a catch, and a catch written down
--   Dev.lua      its part of /sd testdata (never packaged)
--
-- Everything is registered into the core's and the UI's registries, so no
-- file outside this folder names a catch. Its own names are on ns.Fishing,
-- made here, the first of its files the TOC loads.
--
-- A catch is a loot window that is fishing loot (Capture.lua), not a cast:
-- most casts catch nothing, and only the loot says there was a fish.
--
-- This file: the route's list of catches, and the moment that puts them on
-- the plates.

local addonName, ns = ...

local Fishing = {}
ns.Fishing = Fishing

--------------------------------------------------------------------------
-- The route's list: a catch
--------------------------------------------------------------------------
--
-- j.catches holds each, oldest first: { t, mapID, x, y, name }. `name` is
-- the first item the loot held, as the client called it ("Raw Spotted
-- Yellowtail"), kept as it was said so a diary read in another language
-- still says what was fished up; nil where the loot held no item. The spot
-- is where the player stood (the bobber's own place is not given). A shore
-- gives many catches on one spot, so the list is long: the newest 300 are
-- kept a character, a list of its own so that a long day's fishing never
-- crowds out the herbs and ore (Gathering's `nodes`).

local Journey = ns.Journey
Journey.RegisterList("catches", { cap = 300 })

-- The longest name kept, in bytes: a guard on what a record may hold.
local NAME = 60

-- A catch on route `j`, here and now unless `where` says otherwise (in
-- ns.Where's shape). `rec` is { name, t }.
function Fishing.Add(j, rec, where)
    if not j then return nil end
    local name = type(rec.name) == "string" and rec.name ~= "" and ns.CutBytes(rec.name, NAME) or nil
    return Journey.Append(j, "catches", { t = rec.t, name = name }, where)
end

-- One on the logged-in character's route, while it is kept.
function Fishing.Added(rec, where)
    local j = Journey.Kept()
    if not j then return nil end
    return Fishing.Add(j, rec, where)
end

-- A character's catches, oldest first.
function Fishing.List(j)
    return Journey.List(j, "catches")
end

--------------------------------------------------------------------------
-- The recap's moment
--------------------------------------------------------------------------

-- A catch, where the player stood. Filler, like the gathered nodes: it opens
-- a plate only where nothing better does, after them (6.6) and before the
-- road (7), and last of the features' marks. Light: a plate of catches and
-- a place is a small print, with no note in the margin.
ns.JourneyRecap.RegisterMoment("fished", { order = 96, list = "catches", field = "catch", rank = 6.7, light = true })
