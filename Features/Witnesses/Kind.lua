-- Witnesses: strangers around the user's fights, who stood by while the
-- user died, who waded in, and who pulled them through a fight they only
-- just survived (14 Oct). A feature in a folder of its own
-- (.claude/skills/new-feature/folder.md):
--
--   Kind.lua     what a witness is to the diary: its three row kinds,
--                their words and icons on the timeline, and the finding of
--                a moment's witnesses by time
--   Text.lua     its words on Your Diary's plates: the card's (the name,
--                the deed, the creature), its tooltip, and the caption's
--                sentence where the card has no room
--   Card.lua     the witness card in the plate's margin (in place of the
--                killer card, or the close call's for a rescue), its pass
--                over the plate that chooses the plate's one witness, and
--                its note in the margin
--   Capture.lua  the fights watched: who looked on, who fought the user's
--                foes, who finished one off, judged at the death or when
--                the close-call judge says the fight was survived
--                (SD_FIGHT_SURVIVED)
--   Dev.lua      its part of /sd testdata: the made-up route's witnesses,
--                strangers with a row each (never packaged)
--
-- Everything is registered into the core's and the UI's registries, or
-- reached through a core message, so no file outside this folder names
-- the witness rows or the card. Its own names are on ns.Witnesses, made
-- here, the first of its files the TOC loads.
--
-- What stays core, because it is the diary's substrate and not this
-- feature's detection:
--   - the index of the buffer's witness rows by time (Journey.WitnessIndex,
--     Core/Journey.lua), built once a page as the fights' is: it reads
--     Core/Rows.lua's `witness` flag, which the three kinds here set, so
--     the route never names them (the joining of a moment to its
--     witnesses, At below, is this feature's);
--   - the death crosses the card's leader goes to (UI/Journey/Plate.lua),
--     or the close calls' marks (Features/CloseCalls/Mark.lua,
--     plate.closeMarks), and
--     the deaths matched to a cross (cross.deaths, Deaths' pass, which
--     runs before this feature's);
--   - a creature's name in a sentence (Text.KillerName) and the timeline's
--     shared row words (ns.UI.TimelineText.Foe, Place);
--   - the "around" and "together" art (UI/Style/Art.lua), shared with
--     others.
--
-- This file: the kinds, whole (Core/Rows.lua's spec in one call each,
-- words and icon included), and At.

local addonName, ns = ...

local Witnesses = {}
ns.Witnesses = Witnesses

local WATCHED, HELPED, SAVED = "watched_death", "tried_to_help", "saved_you"
Witnesses.WATCHED, Witnesses.HELPED, Witnesses.SAVED = WATCHED, HELPED, SAVED

-- Seconds an onlooker watched the user die (the timeline's words below,
-- the card's, Text.lua's Look): under `saw` they only saw it; from
-- `merciless` on, they watched mercilessly. A look is unbroken while no
-- reading in between finds them looking elsewhere, or in combat, and
-- readings are no more than `gap` apart (the scan's beat, and some:
-- Capture.lua).
local WATCHING = { saw = 1.5, merciless = 5, gap = 2.5 }
Witnesses.WATCHING = WATCHING

--------------------------------------------------------------------------
-- The People rows
--------------------------------------------------------------------------
--
-- Rows on the other player (Interactions.Add), for strangers on the
-- user's side only, each at the death's or the close call's own time
-- (Capture.lua says what each takes):
--
--   watched_death  they looked on as the user died. context.watched is for
--                  how long, unbroken, up to the death (WATCHING), and
--                  context.subZone where
--   tried_to_help  they fought one of the user's foes in the fight the user
--                  died in, or finished one off
--   saved_you      the same, in a fight the user survived with little of
--                  their health left; context.pct is what was left
--
-- Each carries the creature ({ npcID, name, rank } in context) where one
-- was known. Always a line (`moment`); the picker says why it offers them.
-- Each sets Core/Rows.lua's `witness`, what the witness did ("watched" or
-- "helped"): the core's index of witnesses reads it (Journey.WitnessIndex),
-- and the card and the plate's choice go by it (who acted before who
-- watched).
--
-- Their words: "Bram watched you die to a Sunscale Lashtail", "Bram tried
-- to save you from a Sunscale Lashtail", "Bram saved you at 6% health",
-- each "in Hillsbrad Foothills". The creature as Your Diary names a killer
-- (ns.UI.TimelineText.Foe).

local Foe, Place = ns.UI.TimelineText.Foe, ns.UI.TimelineText.Place

local function Always() return true end

-- "Bram mercilessly watched you die to a Kobold Vermin in Coldridge
-- Valley": by how long they watched (WATCHING), under 1.5 s only "saw you
-- die", from 5 s on "mercilessly". In the subzone where there is one; a
-- row kept before the watching was timed is plain "watched".
ns.Rows.Register(WATCHED, { witness = "watched", plate = 3, moment = Always, reason = "they watched you die",
    text = function(row, guid)
        local them = guid and ns.Characters.Name(guid) or "They"
        local c = row.context or {}
        local watching = Witnesses.WATCHING
        local verb = " watched {you} die"
        if c.watched and c.watched < watching.saw then
            verb = " saw {you} die"
        elseif c.watched and c.watched >= watching.merciless then
            verb = " mercilessly watched {you} die"
        end
        local foe = Foe(row)
        local place = c.subZone or row.zone
        return them .. ns.UI.Format.You(row.me, verb) .. (foe and (" to " .. foe) or "") .. (place and (" in " .. place) or "")
    end,
    icon = "around" })

ns.Rows.Register(HELPED, { witness = "helped", plate = 3, moment = Always, reason = "they tried to save you",
    text = function(row, guid)
        local them = guid and ns.Characters.Name(guid) or "They"
        local foe = Foe(row)
        return them .. ns.UI.Format.You(row.me, " tried to save {you}") .. (foe and (" from " .. foe) or "") .. Place(row)
    end,
    icon = "together" })

ns.Rows.Register(SAVED, { witness = "helped", plate = 3, moment = Always, reason = "they saved you",
    text = function(row, guid)
        local them = guid and ns.Characters.Name(guid) or "They"
        local foe = Foe(row)
        local pct = row.context and row.context.pct
        local health = pct and (" at " .. pct .. "%\194\160health") or ""
        return them .. ns.UI.Format.You(row.me, " saved {you}") .. (foe and (" from " .. foe) or "") .. health .. Place(row)
    end,
    icon = "together" })

--------------------------------------------------------------------------
-- A moment's witnesses
--------------------------------------------------------------------------
--
-- Capture.lua writes each row at the death's or the close call's own time:
-- the same PLAYER_DEAD, the same close-call judge. So a death or a close
-- call on the route finds its witnesses by time, as fights find their
-- strangers (Journey.FightIndex), and the route keeps no names (forgetting
-- someone takes their rows, and with them their part on the plates).

-- Seconds a row's time may be from its moment's: both are read in the same
-- second, so this is only leeway.
local SLACK = 3

-- The witnesses (Journey.WitnessIndex's) to a moment at `t` whose row type
-- is in `types` ({ [type] = true }), best first: who acted before who
-- watched, the longer watcher first, then by GUID so a drawing is the
-- same each time.
function Witnesses.At(index, t, types)
    local found = {}
    if type(t) ~= "number" then return found end
    for _, w in ipairs(index or {}) do
        if w.t > t + SLACK then break end
        if w.t >= t - SLACK and types[w.row.type] then found[#found + 1] = w end
    end
    local Get = ns.Rows.Get
    table.sort(found, function(a, b)
        local ha, hb = Get(a.row.type).witness == "helped", Get(b.row.type).witness == "helped"
        if ha ~= hb then return ha end
        local wa = a.row.context and a.row.context.watched or 0
        local wb = b.row.context and b.row.context.watched or 0
        if wa ~= wb then return wa > wb end
        return a.guid < b.guid
    end)
    return found
end
