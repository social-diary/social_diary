-- World PvP capture (Kind.lua): kills by the user or their group, and the
-- user killed by a player.
--
-- Kills: PARTY_KILL gives plain attacker and victim GUIDs, even under
-- combat lockdown (prd.md, Session 1). It fires for kills by the user and
-- by their group, so a kill by a group member counts too: the number is
-- "kills", and the timeline says who landed the blow.
--
-- Open world only. A battleground or arena kill is not a meeting with
-- anyone, and forty of them a match would bury the buffer; their GUIDs come
-- back secret there anyway, which SafeGUID drops (ns.InBattleground). The
-- user's deaths there never reach this file: Deaths' capture tells none
-- inside one, as its recap names players by plain GUIDs once combat is over
-- and each death became a lost fight here (8 Nov).
--
-- Rares' capture (once Capture/Together.lua's, now Features/Rares/
-- Capture.lua, listed after this file) and Capture/Combat.lua (the hunts',
-- now Features/Hunts/Capture.lua, listed at its line) listen to PARTY_KILL
-- too. This file loads before them, so its handler runs first; Rares' takes
-- only creatures and this only players, and Combat's ran after it before
-- as well, so nothing changes.
--
-- Deaths: Deaths' capture (Features/Deaths/Capture.lua) watches every
-- death and reads the recap; it tells the user's own as SD_YOU_DIED
-- (death) at the moment, with its guess (death.guess, a player or a
-- creature or nil), and SD_DEATH_RECAP (death, killer) when the recap
-- names who did it (Core/Events.lua's header). Both
-- are dispatched straight away, inside Deaths' own handlers, so the row and
-- the mark are written where the calls into this feature used to be, before
-- the route's death record and its killer. Only a player is a fight.

local addonName, ns = ...

local WorldPvP = ns.WorldPvP

-- Unit tokens that may still point at the victim, to read what the GUID
-- alone cannot (level, faction). The plates last.
local UNITS = { "target", "focus", "mouseover" }

local function Observe(guid)
    local function On(unit)
        if UnitExists(unit) and ns.Plain(UnitGUID(unit)) == guid then return unit end
    end
    local unit = ns.Units.Each(UNITS, On) or ns.Units.Each(ns.Units.Plates, On)
    if unit then
        ns.Characters.ObserveUnit(unit)
    else
        ns.Characters.ObserveGUID(guid)
    end
end

ns.On("PARTY_KILL", function(_, attacker, victim)
    attacker, victim = ns.SafeGUID(attacker), ns.SafeGUID(victim)
    if not attacker or not victim or victim == ns.ownGUID then return end

    local mine = attacker == ns.ownGUID
    if not mine and not ns.Roster.Has(attacker) then return end
    -- One of your own group, mind-controlled or otherwise: not a fight.
    if ns.Roster.Has(victim) then return end

    if ns.InBattleground() then return end

    Observe(victim)
    WorldPvP.Kill(victim, not mine and attacker or nil)
    ns.Debug("pvp: %s killed %s", mine and "you" or attacker, victim)
end)

-- What Died wrote for each of the user's deaths still waiting for its
-- recap, by Deaths' table for it; weak, so a death given up on goes with it.
local fights = setmetatable({}, { __mode = "k" })

ns.On("SD_YOU_DIED", function(_, death)
    fights[death] = WorldPvP.Died(death.guess, death.time, death.where)
end)

ns.On("SD_DEATH_RECAP", function(_, death, killer)
    local fight = fights[death]
    fights[death] = nil
    WorldPvP.Resolve(fight, killer, death.time, death.where)
end)
