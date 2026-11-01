-- Deaths: what killed you, kept on your route and drawn as a card beside
-- the plate it happened on (JRN-21), and the deaths in a together session
-- (SES-4). A feature in a folder of its own
-- (.claude/skills/new-feature/folder.md):
--
--   Kind.lua     what a death is to the route: its list of the user's
--                deaths with their killers, and the writing of it
--   Text.lua     its words: the card's ("killed you twice"), the card's
--                and the death cross's tooltips, the caption's deaths
--   Card.lua     the killer card (option A, "Cut in ink"), its pass over
--                the plate's death crosses (the killer chosen) and its
--                note in the margin; other features may wear the card
--                with a face of their own (RegisterFace: the close
--                calls', Features/CloseCalls/Card.lua)
--   Capture.lua  the deaths watched: the guess at the moment, the death
--                recap after combat, the killer's rank and display
--   Dev.lua      its part of /sd testdata: the made-up route's deaths with
--                their killers (never packaged)
--
-- Everything is registered into the core's and the UI's registries, or
-- reached through a core message, so no file outside this folder names the
-- killer card or the deaths list. Its own names are on ns.Deaths, made
-- here, the first of its files the TOC loads.
--
-- What stays core, because it is the diary's substrate and not this
-- feature's detection:
--   - the route's count of deaths where they happened (act.deaths,
--     Capture/Journey.lua's PLAYER_DEAD), the death crosses the plates draw
--     from it (their shape and place, UI/Journey/Plate.lua; the moment kind
--     "death" and its RANK, Core/JourneyRecap.lua), and which segment
--     counted a death (Journey.CountedOn), which this feature's pass reads
--     to find a death's cross;
--   - the session's deaths (Sessions.Death, SetKiller, DeathCount, the
--     session's deathLog, the timeline's death lines): Capture.lua writes
--     them, as World PvP writes the route's fight marks;
--   - the creature names read off units for a while (Core/
--     CreatureNames.lua: Note, Of, Clean, j.names): close calls and hunts
--     note and read them too. This list is registered `named`, so the
--     cache puts a recap's surname right on it (CreatureNames' Mend);
--   - a creature's name in a sentence (Text.KillerName: close calls,
--     witnesses and the timeline say theirs with it);
--   - the user's death told to whoever keeps it (SD_YOU_DIED,
--     SD_DEATH_RECAP, Core/Events.lua's header: World PvP's fights);
--   - the "death" art (UI/Style/Art.lua), shared with others.
--
-- This file: the route's list of the user's deaths, and its writers.

local addonName, ns = ...

local Deaths = {}
ns.Deaths = Deaths

--------------------------------------------------------------------------
-- The user's deaths, and what killed them
--------------------------------------------------------------------------
--
-- A death on the route is only a count where it happened (act.deaths).
-- This keeps each one too: when, where on the zone map, and the creature
-- or the world that did it, as Capture.lua tells it -- the NPC id, the
-- name, the killing spell, and the display the creature wore, so the
-- diary can draw it after the creature cache has forgotten it, and its
-- rank when above the common run ("elite", "rare", "rareelite",
-- "worldboss"). `probable` while it rests on the guess at the moment of
-- death.
--
-- A player who killed you is a fight (marks), where whom stays under the
-- diary's rules; here that death keeps no killer. Nothing here names a
-- person, so forgetting has nothing to take.
--
-- j.deaths, oldest first, the newest 500 kept a character. `named`: a
-- recap's made-up surname on a killer is put right once the creature's
-- name is read off a unit (Core/Journey.lua's name cache).

local LIST = "deaths"
ns.Journey.RegisterList(LIST, { cap = 500, named = true })

local KILLER = { "npcID", "name", "spell", "display", "environment", "rank", "probable" }

-- A death of the user's, here and now (`where` in ns.Where's shape, as
-- Journey.Fought takes it). Returns the record Killer and Display fill in,
-- or nil while the route is not kept.
function Deaths.Died(t, where)
    return ns.Journey.Append(ns.Journey.Kept(), LIST, { t = t or ns.Now() }, where)
end

-- What killed `death`: Capture.lua's killer, a creature or the world; a
-- player or nothing leaves it without one. A display already read stays
-- while the creature is the same.
function Deaths.Killer(death, killer)
    if not death then return end
    local display = death.display
    local same = killer and killer.npcID and killer.npcID == death.npcID
    for _, key in ipairs(KILLER) do death[key] = nil end
    if killer and not killer.player then
        death.npcID, death.name, death.spell = killer.npcID, killer.name, killer.spell
        death.environment, death.rank = killer.environment, killer.rank
        death.probable = killer.source ~= "recap" or nil
        if same then death.display = display end
    end
    ns.Journey.Touch()
end

-- The display creature `npcID` wore, once it has been read (Capture.lua's
-- LookUp; a close call's record takes its creature's the same way).
-- Dropped when the record has been put down to another creature since.
function Deaths.Display(death, npcID, display)
    if not (death and npcID and death.npcID == npcID) then return end
    death.display = display
    ns.Journey.Touch()
end

-- A character's deaths, oldest first.
function Deaths.List(j)
    return ns.Journey.List(j, LIST)
end

--------------------------------------------------------------------------
-- What the player says happened (Core/Custom.lua)
--------------------------------------------------------------------------

-- A detected death as the page reads it: as the player left it, nil when
-- hidden. Its name emptied on the form is its detected creature again, picture
-- and all, where a close call's would be a cross with no card. A close call's
-- cross is its own mark and still opens the form; a detected death's is the
-- route's, so its card is the only way back to the form, and a death with no
-- name has no card. Without this the player could lose the way to their own edit.
function Deaths.Read(rec)
    local read = ns.Custom.Read(rec)
    if read and read ~= rec and not read.name and rec.name then
        read.name, read.npcID, read.display = rec.name, rec.npcID, rec.display
    end
    return read
end

-- A death the player inserted, or the card of one detected that they changed.
-- A moment of its own rather than the core's "death" because a death's cross
-- comes of the route's count (act.deaths, Journey.CountedOn) and the moment of
-- that kind is its segment: an inserted one on that road would be counted by
-- what reads the route. So `killedBy` has only the inserted cards in its entry
-- (Gather adds them to e.killedBy, from j.custom), its own mark in the death's
-- shape (Card.lua), and writes nothing to the route. Its rank is a death's,
-- though Rank puts any custom card above everything anyway.
--
-- The detected deaths stay on their list and on the route's crosses: the killer
-- pass (Card.lua) reads the list itself, through Deaths.Read, so Gather's list
-- branch would only put them on the page twice. That leaves this gather one job,
-- the one the list branch would have done: to list those hidden, which have no
-- card left to open them by, so the map's menu can bring them back.
--
-- The fields are all the card shows: the creature (with its picture, where this
-- character's records know the name), its type (which its name's article and
-- the tooltip go by) and what it killed you with (the tooltip). No level: the
-- killer's card has no tag, unlike the close call's. No count: "killed you
-- twice" is the plate's merging of detected deaths, and an inserted card is
-- one death.
ns.JourneyRecap.RegisterMoment("killedBy", { order = 15, entry = "killedBy", field = "killedBy", rank = 3,
    gather = function(j, a, b, e)
        for _, rec in ipairs(Deaths.List(j)) do
            if rec.t >= a and rec.t < b and rec.custom and rec.custom.hidden then
                e.hidden[#e.hidden + 1] = { kind = "killedBy", rec = rec }
            end
        end
    end,
    custom = {
        creature = "name",
        label = "Death",
        heading = "A death",
        group = "combat",
        -- A line of a menu, as the cross's tooltip says it.
        describe = function(d)
            if not d.name then return "A death" end
            return d.name .. (d.spell and (", with " .. d.spell) or "")
        end,
        fields = {
            { key = "name", type = "text", label = "Creature" },
            -- The close call's two, for the same reason (Features/CloseCalls/Kind.lua).
            { key = "rank", type = "choice", values = { "rare", "elite" }, label = "Type",
                names = { rare = "Rare", elite = "Elite" } },
            { key = "spell", type = "text", label = "Killed with" },
        },
    } })
