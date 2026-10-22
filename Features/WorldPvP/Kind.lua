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

local function Always() return true end

ns.Rows.Register(KILL, { fight = "kill", plate = 1, moment = Always, reason = "you killed them",
    text = function(row, guid)
        local them = guid and ns.Characters.Name(guid) or "them"
        local by = row.context and row.context.by
        local You = ns.UI.Format.You
        if not by then return You(row.me, "{You} killed ") .. them .. Place(row) end
        local blow = ns.Characters.Name(by)
        return You(row.me, "{Your} group killed ") .. them .. Place(row) .. (blow and (" (" .. blow .. "'s killing blow)") or "")
    end,
    icon = "hostile" })

ns.Rows.Register(DEATH, { fight = "death", plate = 1, moment = Always, reason = "they killed you",
    text = function(row, guid)
        local c = row.context or {}
        local them = guid and ns.Characters.Name(guid) or "They"
        local with = c.spell and (" with " .. c.spell) or ""
        local killed = c.probable and " probably killed {you}" or " killed {you}"
        return them .. ns.UI.Format.You(row.me, killed) .. with .. Place(row)
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
