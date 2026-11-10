-- World PvP: who you killed, and who killed you (prd.md, "Killed them, or
-- killed by them"). A feature in a folder of its own
-- (.claude/skills/new-feature/folder.md): People rows, like
-- Chat, Trade and Level-ups, and a fight mark on the user's own route for
-- each.
--
--   Kind.lua     what a fight is to the diary: its two row kinds, their
--                words and icons on the timeline, and the writing of a
--                fight (row and route mark), its correction by the recap
--   Capture.lua  kills by the user or their group (PARTY_KILL), and the
--                user's deaths as Deaths' capture tells them
--                (Features/Deaths/Capture.lua: SD_YOU_DIED, SD_DEATH_RECAP)
--   Dev.lua      its part of /sd testdata: the made-up route's two fight
--                marks (never packaged)
--
-- Everything is registered into the core's and the UI's registries, or
-- reached through a core message, so no file outside this folder names the
-- fight rows. Its own names are on ns.WorldPvP, made here, the first of
-- its files the TOC loads.
--
-- Each fight is an interaction row on the other player, so a stranger's
-- fights live in the buffer under its usual retention and come along when
-- they are added (flow 5, the ganker), like any other row:
--
--   pvp_kill    they died to you or your group. context.by is the group
--               member who landed the killing blow; nil when it was you.
--               Both count as a kill; the timeline tells them apart.
--   pvp_death   they killed you. context.probable while it rests on the
--               guess at the moment of death (your target); the death recap
--               confirms it, moves it to the real killer, or takes it back
--               when no player killed you. context.spell, from the recap.
--
-- What stays core, because it is the diary's substrate and not this
-- feature's detection:
--   - the route's fight marks (JRN-10; Core/Journey.lua's Fight, Fought,
--     Refight, FightWho, FightIndex, kind "fight" on j.marks), which the
--     plates draw as people marks and Your Diary's words tell ("beat
--     Tullus", UI/Journey/Text/Prose.lua): this file writes them through
--     ns.Journey.Fought / Refight. FightIndex finds a stranger's name by
--     the time of a row whose kind sets Core/Rows.lua's `fight`, which
--     both kinds here do, so the route never names them;
--   - the score with someone (ns.Interactions.Fights, Core/Interactions.lua:
--     kills, yours, deaths, the latest's time and zone, counted by the same
--     flag), which the profile, the foe's reunion card and
--     ns.UI.Format.FightsText (UI/Words/Format.lua) read;
--   - the "hostile" and "death" art (UI/Style/Art.lua), shared with others;
--   - the foe tag and its toasts (Core/Reunions.lua, the settings' "World
--     PvP" heading), which are about a person, not a fight.
-- The user's deaths are Deaths' (Features/Deaths/), which tell this
-- feature of each with a message rather than a call (Capture.lua).
--
-- This file: the kinds, whole (Core/Rows.lua's spec in one call each,
-- words and icon included), and the writing.

local addonName, ns = ...

local WorldPvP = {}
ns.WorldPvP = WorldPvP

local KILL, DEATH = "pvp_kill", "pvp_death"

--------------------------------------------------------------------------
-- The People rows
--------------------------------------------------------------------------
--
-- Always a line, never an activity, as TLN-2 has it for PvP kills. Each a
-- fight (`fight`): the route's mark of it finds the stranger by the row's
-- time (Journey.FightIndex), and the score counts it (Interactions.Fights,
-- reading context.by on a kill). The picker says why it offers them.
--
-- Their words: "You killed Bram", "Your group killed Bram (Koko's killing
-- blow)", "Bram killed you with Ambush", "Bram probably killed you", each
-- "in Hillsbrad Foothills". The name is the profile's.

local Place = ns.UI.TimelineText.Place
local L, Fmt = ns.L, ns.Fmt

local function Always() return true end

-- Each sentence whole, with its place ("##zone", the zone's phrase) and
-- without (no zone, or the plate's tooltip, which leaves it to the map).
local KILLED = {
    alone = { [true] = L["{You} killed %1$s %2$s##zone"], [false] = L["{You} killed %s"] },
    blow = { [true] = L["{Your} group killed %1$s %2$s (%3$s's killing blow)##zone"],
        [false] = L["{Your} group killed %1$s (%2$s's killing blow)"] },
    group = { [true] = L["{Your} group killed %1$s %2$s##zone"], [false] = L["{Your} group killed %s"] },
}

ns.Rows.Register(KILL, { fight = "kill", plate = 1, moment = Always, reason = L["you killed them"],
    text = function(row, guid, unplaced)
        local them = guid and ns.Characters.Name(guid) or L["them##killed"]
        local by = row.context and row.context.by
        local place = Place(row, unplaced)
        local blow = by and ns.Characters.Name(by)
        local template = KILLED[not by and "alone" or blow and "blow" or "group"][place ~= nil]
        local values = { them }
        if place then values[#values + 1] = place end
        if blow then values[#values + 1] = blow end
        return ns.UI.Format.You(row.me, Fmt(template, unpack(values)))
    end,
    icon = "hostile" })

-- By who (named or "They"), whether the diary is sure, whether the spell
-- is known, and the place: one template each. Values in that order.
local KILLED_YOU = {
    named = {
        sure = {
            plain = { [true] = L["%1$s killed {you} %2$s##zone"], [false] = L["%s killed {you}"] },
            spell = { [true] = L["%1$s killed {you} with %2$s %3$s##zone"], [false] = L["%1$s killed {you} with %2$s"] },
        },
        probable = {
            plain = { [true] = L["%1$s probably killed {you} %2$s##zone"], [false] = L["%s probably killed {you}"] },
            spell = { [true] = L["%1$s probably killed {you} with %2$s %3$s##zone"],
                [false] = L["%1$s probably killed {you} with %2$s"] },
        },
    },
    they = {
        sure = {
            plain = { [true] = L["They killed {you} %s##zone"], [false] = L["They killed {you}"] },
            spell = { [true] = L["They killed {you} with %1$s %2$s##zone"], [false] = L["They killed {you} with %s"] },
        },
        probable = {
            plain = { [true] = L["They probably killed {you} %s##zone"], [false] = L["They probably killed {you}"] },
            spell = { [true] = L["They probably killed {you} with %1$s %2$s##zone"],
                [false] = L["They probably killed {you} with %s"] },
        },
    },
}

ns.Rows.Register(DEATH, { fight = "death", plate = 1, moment = Always, reason = L["they killed you"],
    text = function(row, guid, unplaced)
        local c = row.context or {}
        local them = guid and ns.Characters.Name(guid)
        local place = Place(row, unplaced)
        local template = KILLED_YOU[them and "named" or "they"][c.probable and "probable" or "sure"]
            [c.spell and "spell" or "plain"][place ~= nil]
        local values = {}
        if them then values[#values + 1] = them end
        if c.spell then values[#values + 1] = c.spell end
        if place then values[#values + 1] = place end
        return ns.UI.Format.You(row.me, Fmt(template, unpack(values)))
    end,
    icon = "death" })

--------------------------------------------------------------------------
-- Writing
--------------------------------------------------------------------------

-- `victim` died to the user, or to group member `by`.
-- Each fight is also a mark on the user's own route (JRN-10), which keeps
-- the outcome after a stranger's row has gone.
function WorldPvP.Kill(victim, by)
    local row = ns.Interactions.Add(victim, KILL, { hostile = true, context = { by = ns.SafeGUID(by) } })
    if row then ns.Journey.Fought("won", victim, row.time) end
    return row
end

-- The user died. `killer` is the guess Deaths' capture
-- (Features/Deaths/Capture.lua) made at that moment; only a player is a
-- fight. Returns what Resolve needs to correct it later, or nil.
function WorldPvP.Died(killer, time, where)
    if not (killer and killer.player and killer.guid) then return nil end
    local row = ns.Interactions.Add(killer.guid, DEATH,
        { hostile = true, time = time, where = where, session = false, context = { probable = true } })
    if not row then return nil end
    return { guid = killer.guid, row = row, mark = ns.Journey.Fought("lost", killer.guid, row.time, where) }
end

-- The death recap came: `killer` is who it says, `fight` what Died wrote
-- (or nil). The row is confirmed, moved to the player the recap names, or
-- taken back when the recap names a creature or nothing.
function WorldPvP.Resolve(fight, killer, time, where)
    local guid = killer and killer.player and killer.guid

    if fight and fight.guid == guid then
        fight.row.context = fight.row.context or {}
        fight.row.context.probable = nil
        fight.row.context.spell = killer.spell
        ns.Touch()
        return fight
    end

    if fight then ns.Interactions.Remove(fight.guid, fight.row) end
    local mark = fight and fight.mark
    if not guid then
        if mark then ns.Journey.Refight(ns.Journey.Mine(), mark, false) end
        return nil
    end

    ns.Characters.ObserveGUID(guid)
    local row = ns.Interactions.Add(guid, DEATH,
        { hostile = true, time = time, where = where, session = false, context = { spell = killer.spell } })
    if not row then return nil end
    -- The mark moves with the row: same fight, the player the recap names.
    if mark then
        mark.t = row.time
        ns.Journey.Refight(ns.Journey.Mine(), mark, guid)
    else
        mark = ns.Journey.Fought("lost", guid, row.time, where)
    end
    return { guid = guid, row = row, mark = mark }
end
