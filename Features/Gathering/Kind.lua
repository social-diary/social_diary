-- Gathering: the herbs picked and the ore mined on the road, each where it
-- was gathered. A feature in a folder of its own
-- (.claude/skills/new-feature/folder.md):
--
--   Kind.lua     what a gathered node is to the diary: the route's list and
--                the recap's moment
--   Text.lua     its words: the mark's tooltip
--   Mark.lua     its marks on the plates (a sprig for a herb, a pickaxe for ore)
--   Capture.lua  the player's own gathering casts, and a node gathered
--                written down
--   Dev.lua      its part of /sd testdata (never packaged)
--
-- Everything is registered into the core's and the UI's registries, so no
-- file outside this folder names a gathered node. Its own names are on
-- ns.Gathering, made here, the first of its files the TOC loads.
--
-- Only what the player gathered themselves is kept: the diary never
-- knows of a node it was not at, and ships no list of where nodes are.
--
-- This file: the route's list of nodes gathered, and the moment that puts
-- them on the plates.

local addonName, ns = ...

local Gathering = {}
ns.Gathering = Gathering

--------------------------------------------------------------------------
-- The route's list: a node gathered
--------------------------------------------------------------------------
--
-- j.nodes holds each, oldest first: { t, mapID, x, y, kind, name }. `kind`
-- is "herb" or "ore", from the spell that was cast (the client's id, the
-- same in every language); `name` is how the client called the node when it
-- was gathered ("Copper Vein"), kept as it was said, as a zone's name is, so
-- a diary read in another language still says what was mined. Each is one
-- node gathered, so a field of veins is a record for every vein. The newest
-- 400 are kept a character.

local Journey = ns.Journey
Journey.RegisterList("nodes", { cap = 400 })

-- The longest name kept, in bytes: the client's names are short, this is
-- only a guard on what a record may hold.
local NAME = 60

Gathering.KINDS = { herb = true, ore = true }

-- A node gathered on route `j`, here and now unless `where` says otherwise
-- (in ns.Where's shape). `rec` is { kind, name, t }. nil for a kind the
-- feature does not know.
function Gathering.Add(j, rec, where)
    if not j or not Gathering.KINDS[rec.kind] then return nil end
    local name = type(rec.name) == "string" and rec.name ~= "" and ns.CutBytes(rec.name, NAME) or nil
    return Journey.Append(j, "nodes", { t = rec.t, kind = rec.kind, name = name }, where)
end

-- One gathered on the logged-in character's route, while it is kept.
function Gathering.Added(rec, where)
    local j = Journey.Kept()
    if not j then return nil end
    return Gathering.Add(j, rec, where)
end

-- A character's nodes, oldest first.
function Gathering.List(j)
    return Journey.List(j, "nodes")
end

--------------------------------------------------------------------------
-- The recap's moment
--------------------------------------------------------------------------

-- A node gathered, where it was. Filler, as a campfire is: it opens a plate
-- only where nothing better does, after a duel (6.5) and before the road
-- (7), and last of the features' marks. Light: a plate of nodes and a place
-- is a small print, with no note in the margin.
ns.JourneyRecap.RegisterMoment("gathered", { order = 95, list = "nodes", field = "node", rank = 6.6, light = true })
