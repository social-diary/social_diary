-- Close calls (JRN-25): out of a fight alive, and only just. A feature in
-- a folder of its own (.claude/skills/new-feature/folder.md):
--
--   Kind.lua     what a close call is to the route: its list, the judging
--                of a fight by the damage it did, and the recap's moment
--   Text.lua     its words: the level's prose, the plates' caption, the
--                cross's and the card's tooltips, the card's heading, tag
--                and deed
--   Mark.lua     its mark on the plates (the death's cross in outline)
--   Card.lua     the creature that nearly got you, on the killer card
--                (Features/Deaths/Card.lua, worn as a face of its own:
--                the heading, the tag, the chart, VITALS), the pass that
--                chooses it over the plate and its note in the margin;
--                the witnesses' card charts a rescue with VITALS
--   Capture.lua  the fight judged once combat is over, off the client's
--                damage meter, less the healing received
--   Dev.lua      its part of /sd testdata: the made-up route's close
--                calls (never packaged)
--
-- Everything is registered into the core's and the UI's registries, or
-- worn on Deaths' card through its face (Deaths' Card.RegisterFace), so no
-- file outside this folder names a close call's list, words or card. Its
-- own names are on ns.CloseCalls, made here, the first of its files the
-- TOC loads.
--
-- What stays core, because it is the diary's substrate and not this
-- feature's detection:
--   - the creature names read off units for a while (Core/
--     CreatureNames.lua: Note, Of, j.names): the judge notes every foe it
--     reads, and this list is registered `readNames`, so CreatureNames.Of
--     takes a creature's name from it where none was read lately;
--   - a creature's name in a sentence (Text.KillerName) and the health
--     left held together (Text.Health): the witnesses say theirs with
--     them too;
--   - the fight's start and end on the route (Journey.FightStart/End,
--     Capture/Journey.lua) and the route's gate (Journey.Kept);
--   - the fight survived told to whoever keeps who pulled the user
--     through it (SD_FIGHT_SURVIVED, Core/Events.lua's header): fired by
--     Capture.lua here, heard by the witnesses;
--   - the card itself, Deaths' (Features/Deaths/Card.lua): this feature
--     wears it.
--
-- Besides its list, the route keeps the damage meter's last reading
-- (j.meter, Capture.lua's Since): written and read by this feature alone,
-- saved so a /reload does not count a session's damage twice.
--
-- This file: the route's list of close calls, its writers and readers,
-- and the moment that puts them on the plates.

local addonName, ns = ...

local CloseCalls = {}
ns.CloseCalls = CloseCalls

local Journey = ns.Journey

--------------------------------------------------------------------------
-- The route's list: out of a fight alive, and only just
--------------------------------------------------------------------------
--
-- The player's health is secret to addons always, in combat or not
-- (probes, 11 Oct), so how low it fell can never be read. What can is the
-- damage the fight did, off the client's own damage meter once combat is
-- over (plain then, probe 11 Oct), against the maximum health (plain):
-- a fight that took all but LEFT of it, less the healing the user
-- received, survived, was a close call. That reckons from full health, so
-- a fight begun half dead is missed; and a heal from a stranger, whom the
-- meter does not list, is not taken off.
--
-- j.closeCalls holds each, oldest first: { t, mapID, x, y, level, pct,
-- took, seconds, npcID, name, rank, foeLevel, foes, display }. `pct` is
-- the health that would be left from full, a whole percent, 1 to
-- LEFT's; `took` the damage as a percent of the maximum, more than
-- 100 when healing the meter does not list carried the user through; `seconds` how long the fight was; the
-- creature is the one fought most (the most of its kind targeted), `foes`
-- how many creatures were targeted in all. No creature is a fight whose
-- foe was never targeted. `display` read as a killer's is, by its NPC id
-- (the deaths' capture looks it up). The newest 300 are kept a character.
-- Its creatures' names are as read off their units (Capture.lua), so the
-- list is registered `readNames` (Core/CreatureNames.lua's Of asks it).

local LIST = "closeCalls"
Journey.RegisterList(LIST, { cap = 300, readNames = true })

-- Out of a fight alive with this much of your health or less.
local LEFT = 0.10
CloseCalls.LEFT = LEFT

-- Whether a fight that did `taken` damage, against `max` health, was a
-- close call.
function CloseCalls.Is(taken, max)
    if type(taken) ~= "number" or type(max) ~= "number" or max <= 0 then return false end
    return taken / max >= 1 - LEFT
end

-- A close call of the logged-in character's, while its route is kept,
-- here and now unless `where` says otherwise (ns.Where's shape). `rec` is
-- { t, level, taken, max, seconds, npcID, name, rank, foeLevel, foes }:
-- `taken` the damage the fight did, less the user's own healing.
function CloseCalls.Added(rec, where)
    local j = Journey.Kept()
    if not j or not CloseCalls.Is(rec.taken, rec.max) then return nil end
    local took = math.floor(rec.taken / rec.max * 100 + 0.5)
    return Journey.Append(j, LIST, { t = rec.t, level = rec.level,
        pct = math.min(math.floor(LEFT * 100), math.max(1, 100 - took)), took = took, seconds = rec.seconds,
        npcID = rec.npcID, name = rec.npcID and rec.name or nil, rank = rec.npcID and rec.rank or nil,
        foeLevel = rec.npcID and rec.foeLevel or nil,
        foes = (rec.foes or 0) > 1 and rec.foes or nil }, where)
end

-- A character's close calls, oldest first.
function CloseCalls.List(j)
    return Journey.List(j, LIST)
end

--------------------------------------------------------------------------
-- The recap's moment
--------------------------------------------------------------------------

-- JRN-25: a fight left with almost no health, where it ended. It ranks
-- with a death (3): the same fight, nearly lost, is worth a plate as much
-- as one lost. Full: its card goes in the margin. The player may change or
-- insert one (Core/Custom.lua), by everything its card shows: its creature,
-- its level (-1 the skull) and rank, how many it was against and the health
-- left, which need not be under LEFT: that is theirs to say.
ns.JourneyRecap.RegisterMoment("close", { order = 20, list = LIST, field = "call", rank = 3,
    custom = {
        creature = "name",
        label = "a close call",
        -- A line of a menu, where a spot merges several or one is hidden: the
        -- health tells apart two fights with one creature.
        describe = function(call)
            return ("%s, %d%% health"):format(call.name or "A close call", call.pct or 0)
        end,
        defaults = { pct = 5 },
        fields = {
            { key = "name", type = "text", label = "Creature" },
            { key = "foeLevel", type = "number", min = -1, max = 99, label = "Level", hint = "-1 for a skull" },
            { key = "rank", type = "choice", values = { "elite", "rare", "rareelite", "worldboss" }, label = "Rank",
                empty = "Common", names = { elite = "Elite", rare = "Rare", rareelite = "Rare elite",
                    worldboss = "Boss" } },
            { key = "foes", type = "number", min = 1, max = 99, label = "How many" },
            { key = "pct", type = "number", min = 0, max = 100, label = "Health left", hint = "%" },
        },
    } })
