-- Deaths capture (Kind.lua): deaths in a together session or a dungeon run,
-- and what killed them (SES-4, INS-30); and the user's own, on their route.
--
-- PLAYER_DEAD and UNIT_DIED say who died and nothing more: the combat log
-- that used to say who did it is closed to addons since 12.0. Two sources
-- are left, so a death is recorded with the first and improved by the second:
--
--   at the moment  The victim's target, when it is something that can attack
--                  them. Usually the killer, never certain: it shows as
--                  "probably".
--   after combat   The client's own death recap (C_DeathRecap). Readable once
--                  combat is over (probe, 8 Oct): the killing blow's source
--                  GUID and name, the spell, and everyone who hit in the last
--                  moments. The user's own death is the latest recap; a group
--                  member's needs the recap ID the damage meter lists for
--                  them, if it lists them at all (untested).
--
-- A recap is only used when its killing blow landed on the victim within a
-- few seconds of the recorded death, so a stale or unrelated one never is.
-- Whatever cannot be read leaves the guess, or no killer, in place.
--
-- The user's own death is told as SD_YOU_DIED at the moment, with the
-- guess, and SD_DEATH_RECAP when the recap names the killer (Core/
-- Events.lua's header), in a session or not, for whatever keeps it: a
-- player who killed you is a fight (the ganker finds you alone), written
-- down at once and corrected by the recap.
--
-- And every death of the user's goes on their route (Kind.lua's list),
-- with the creature or the world that did it and the creature's display,
-- read off a model frame, for the diary to draw it later. A session's
-- deaths are the session's (Sessions.Death, SetKiller: core).
--
-- This file loads before Capture/ now (features come first), so its
-- handlers run before any there on the same event: Capture/Journey.lua
-- (PLAYER_DEAD, PLAYER_REGEN_ENABLED), Features/CloseCalls/Capture.lua
-- (after this folder in the TOC; the judge was in Capture/Combat.lua,
-- since the hunts' alone, Features/Hunts/Capture.lua) and
-- Features/Witnesses/Capture.lua (listed after Capture/ in the TOC, where
-- its file was) all registered after it before as well, and
-- Capture/Menus.lua, Group.lua and Together.lua, which came before it,
-- listen to none of PLAYER_DEAD, UNIT_DIED or PLAYER_REGEN_ENABLED; the UI's
-- PLAYER_REGEN_ENABLED handlers (UI/Settings/Macro.lua,
-- UI/Windows/Reunion/Queue.lua, UI/Windows/Intro/Parcel.lua) still run
-- before it. So the order is what it was.
--
-- Features/CloseCalls/Capture.lua and Features/Hunts/Capture.lua (the
-- hunts, listed after Capture/) reach LookUp (below) at call time for a close call's or a hunt's
-- creature's display, guarded by `ns.Deaths`.

local addonName, ns = ...

local Deaths = ns.Deaths

-- How far the killing blow may be from the death as recorded.
local RECAP_SLACK = 10

-- After a death: a try every few seconds once combat is over, a limited
-- number of them, and none past the deadline however long the fight runs.
local RETRY_SECONDS = 3
local MAX_TRIES = 10
local DEADLINE = 10 * 60

--------------------------------------------------------------------------
-- The guess at the moment of death
--------------------------------------------------------------------------

-- Who a GUID is, as a killer: a player (kept by GUID) or a creature (by NPC
-- id). Neither for anything else.
local function Identify(killer, guid)
    local player = ns.SafeGUID(guid)
    if player then
        killer.guid, killer.player = player, true
    else
        killer.npcID = ns.NpcID(guid)
    end
    return killer
end

-- The token the victim is on: the user, or a group member.
local function UnitFor(guid)
    if guid == ns.ownGUID then return "player" end
    return ns.Units.Each(ns.Units.Group(), function(unit)
        if ns.Plain(UnitGUID(unit)) == guid then return unit end
    end)
end

-- What the victim was fighting, if anything.
local function Guess(guid)
    local unit = UnitFor(guid)
    if not unit then return nil end

    local target = unit == "player" and "target" or (unit .. "target")
    if not ns.Plain(UnitExists(target)) or not ns.Plain(UnitCanAttack(unit, target)) then return nil end

    local name = ns.Plain((UnitName(target)))
    if type(name) ~= "string" or name == "" then return nil end
    local killer = Identify({ source = "target", name = name }, UnitGUID(target))
    if killer.npcID then ns.CreatureNames.Note(killer.npcID, name) end
    -- A player: everything readable about them, while the token still
    -- points at them.
    if killer.player then ns.Characters.ObserveUnit(target) end
    return killer
end

--------------------------------------------------------------------------
-- The death recap
--------------------------------------------------------------------------

local function Field(event, key, kind)
    local value = ns.Plain(event[key])
    if type(value) == kind then return value end
    return nil
end

-- The recap names one mob differently from hit to hit ("Plainstrider
-- Thunderhoof", "Plainstrider Wrathlete" for one GUID) while its nameplate
-- says "Plainstrider". The words all its names start with are its name.
local function CommonName(names)
    local words
    for _, name in ipairs(names) do
        local these = {}
        for word in name:gmatch("%S+") do these[#these + 1] = word end
        if not words then
            words = these
        else
            local n = 0
            while n < #words and n < #these and words[n + 1] == these[n + 1] do n = n + 1 end
            for i = #words, n + 1, -1 do words[i] = nil end
        end
    end
    if not words or #words == 0 then return names[1] end
    return table.concat(words, " ")
end

-- The killer from a list of recap events, or nil when the list is unreadable
-- or is not this death's: its killing blow must have hit `victim` within
-- RECAP_SLACK of `at`.
function Deaths.FromRecap(events, victim, at)
    events = ns.Plain(events)
    if type(events) ~= "table" then return nil end

    local plain = {}
    for i = 1, #events do
        local event = ns.Plain(events[i])
        if type(event) == "table" then plain[#plain + 1] = event end
    end

    -- The killing blow is the latest hit: first in the list as the client
    -- hands it over, but taken by time rather than trusted to the order.
    local blow, blowTime
    for _, event in ipairs(plain) do
        local time = Field(event, "timestamp", "number")
        if time and (not blowTime or time > blowTime) then blow, blowTime = event, time end
    end
    if not blow or Field(blow, "destGUID", "string") ~= victim then return nil end
    if math.abs(blowTime - at) > RECAP_SLACK then return nil end

    local killer = { source = "recap" }
    local source = Field(blow, "sourceGUID", "string")
    if source then Identify(killer, source) end
    killer.spell = Field(blow, "spellName", "string")
    killer.environment = Field(blow, "environmentalType", "string")

    -- Everyone who hit in the recap, and every name the killer went by.
    local attackers, names = {}, {}
    for _, event in ipairs(plain) do
        local from = Field(event, "sourceGUID", "string")
        if from then attackers[from] = true end
        local name = Field(event, "sourceName", "string")
        if name and from and (from == source or (killer.npcID and ns.NpcID(from) == killer.npcID)) then
            names[#names + 1] = name
        end
    end
    killer.attackers = ns.CountKeys(attackers)
    if killer.player then
        killer.name = Field(blow, "sourceName", "string")
    elseif #names > 0 then
        killer.name = CommonName(names)
    end

    if not (killer.name or killer.environment) then return nil end
    return killer
end

-- The recap ID the damage meter keeps for a victim's latest death, if it
-- lists them. Only read outside combat, where its fields are plain.
local function MeterRecapID(guid)
    local meter = C_DamageMeter
    local types = Enum and Enum.DamageMeterType
    if not (meter and meter.GetAvailableCombatSessions and types and types.Deaths) then return nil end

    local ok, sessions = pcall(meter.GetAvailableCombatSessions)
    sessions = ok and ns.Plain(sessions)
    if type(sessions) ~= "table" then return nil end

    -- Any level of this can come back secret, so each is checked on the way.
    local function Table(value)
        value = ns.Plain(value)
        return type(value) == "table" and value or nil
    end

    local best
    for i = 1, #sessions do
        local entry = Table(sessions[i])
        local okS, session = pcall(meter.GetCombatSessionFromID, entry and ns.Plain(entry.sessionID), types.Deaths)
        session = okS and Table(session)
        for _, src in ipairs(session and Table(session.combatSources) or {}) do
            src = Table(src)
            local recapID = src and ns.Plain(src.deathRecapID)
            if src and ns.Plain(src.sourceGUID) == guid and type(recapID) == "number"
                and (not best or recapID > best) then
                best = recapID
            end
        end
    end
    return best
end

local function RecapFor(item)
    local recap = C_DeathRecap
    if not (recap and recap.GetRecapEvents) then return nil end

    -- The user's own death is the latest recap; anyone else's has to be found.
    local id
    if item.guid ~= ns.ownGUID then
        id = MeterRecapID(item.guid)
        if not id then return nil end
    end

    local ok, events = pcall(recap.GetRecapEvents, id)
    if not ok then return nil end
    return Deaths.FromRecap(events, item.guid, item.time)
end

--------------------------------------------------------------------------
-- What the killer looked like
--------------------------------------------------------------------------
--
-- Its rank first: on a plate, a rare or an elite that killed you outranks
-- whatever killed you most. The recap names the killer only once combat
-- is over, when its nameplate has gone, so at the moment of death every
-- creature in sight that could attack is read, by NPC id.

local RANKS = { elite = true, rare = true, rareelite = true, worldboss = true }

local function Ranks()
    local ranks = {}
    local function Read(unit)
        if not ns.Plain(UnitExists(unit)) or not ns.Plain(UnitCanAttack("player", unit)) then return end
        local npcID = ns.NpcID(UnitGUID(unit))
        local rank = npcID and UnitClassification and ns.Plain(UnitClassification(unit))
        if rank and RANKS[rank] then ranks[npcID] = rank end
    end
    Read("target")
    ns.Units.Each(ns.Units.Plates, Read)
    return ranks
end

-- `killer` with the rank its creature was seen at, if one was.
local function Ranked(killer, ranks)
    if killer and killer.npcID then killer.rank = ranks[killer.npcID] end
    return killer
end

--
-- Then its display ID, from a model frame no one sees (probe, 10 Oct:
-- SetCreature(npcID) draws a creature from its id alone, through the
-- creature cache, and GetDisplayInfo gives its display a moment later; a
-- 1 px frame at no alpha loads it too). Not off the target: a model set
-- to a unit reads 0 (probe, 10 Oct), so a creature that comes in several
-- looks is kept as the cache shows it.

local LOOK_SECONDS, LOOK_TRIES = 1, 5

local frame

local function Model()
    if frame == nil then
        local ok, made = pcall(CreateFrame, "PlayerModel", nil, UIParent)
        frame = ok and made or false
        if frame then
            -- Drawn, so it loads, but a pixel off the screen's corner.
            frame:SetSize(1, 1)
            frame:SetPoint("TOPRIGHT", UIParent, "TOPLEFT", -10, 10)
            frame:SetAlpha(0)
        end
    end
    return frame or nil
end

local function SetCreature(model, npcID)
    return model and type(model.SetCreature) == "function" and pcall(model.SetCreature, model, npcID)
end

local function DisplayOf(model)
    if not (model and type(model.GetDisplayInfo) == "function") then return nil end
    local ok, display = pcall(model.GetDisplayInfo, model)
    display = ok and ns.Plain(display)
    if type(display) == "number" and display > 0 then return display end
    return nil
end

-- Deaths whose creature still wants its display: { death, npcID, tries }.
local looks = {}
local looking = false

local function Look()
    local item = looks[1]
    if not item then
        looking = false
        return
    end
    looking = true
    local death, model = item.death, Model()
    -- Read already, or put down to someone else since: nothing to do.
    if death.display or death.npcID ~= item.npcID or not model then
        table.remove(looks, 1)
        return Look()
    end

    if item.tries == 0 and not SetCreature(model, item.npcID) then item.tries = LOOK_TRIES end
    local display = item.tries > 0 and DisplayOf(model)
    if display or item.tries >= LOOK_TRIES then
        if display then Deaths.Display(death, item.npcID, display) end
        table.remove(looks, 1)
        return Look()
    end
    item.tries = item.tries + 1
    ns.After(LOOK_SECONDS, Look)
end

-- The display of the creature `death` is put down to, unless it has one.
function Deaths.LookUp(death)
    if not (death and death.npcID) or death.display then return end
    looks[#looks + 1] = { death = death, npcID = death.npcID, tries = 0 }
    if not looking then Look() end
end

--------------------------------------------------------------------------
-- Waiting for the recap
--------------------------------------------------------------------------

local pending = {}
local waiting = false

-- One pass over the deaths still waiting. Nothing is read in combat: the
-- recap and the meter are secret until it ends.
local function Try()
    if InCombatLockdown() then return end

    local now = ns.Now()
    for i = #pending, 1, -1 do
        local item = pending[i]
        local killer = RecapFor(item)
        item.tries = item.tries + 1

        if killer then
            -- The nameplate's name beats the recap's, for the same mob.
            local guess = item.guess
            -- Else its kind's name as read off a unit, for a recap that
            -- gave it a surname (CreatureNames.Clean).
            if guess and guess.npcID and guess.npcID == killer.npcID then
                killer.name = guess.name
            elseif killer.npcID and killer.name then
                killer.name = ns.CreatureNames.Clean(ns.Journey.Mine(), killer.npcID, killer.name)
            end
            if item.death then ns.Sessions.SetKiller(item.death, killer) end
            if item.run then ns.Instances.SetKiller(item.run, killer) end
            if item.guid == ns.ownGUID then
                ns.Fire("SD_DEATH_RECAP", item.told, killer)
                Deaths.Killer(item.slain, Ranked(killer, item.ranks))
                Deaths.LookUp(item.slain)
            end
            ns.Debug("death of %s: killed by %s (death recap)", item.guid, tostring(killer.name or killer.environment))
            table.remove(pending, i)
        elseif item.tries >= MAX_TRIES or now - item.time > DEADLINE then
            ns.Debug("death of %s: no death recap, keeping %s", item.guid,
                item.guess and "the guess" or "no killer")
            Deaths.LookUp(item.slain)
            table.remove(pending, i)
        end
    end
end

local function Step()
    Try()
    if #pending > 0 then
        ns.After(RETRY_SECONDS, Step)
    else
        waiting = false
    end
end

-- A death in a session is the session's, and one in a dungeon run the
-- run's (Core/Instances.lua, INS-30), with or without a session; the
-- user's own is told as well (SD_YOU_DIED), session or not. `told` is the
-- death as the messages carry it, the same table at the moment and with
-- the recap.
local function Died(guid)
    local death = ns.Sessions.Death(guid) or nil
    local run = ns.Instances.Death(guid) or nil
    local own = guid == ns.ownGUID
    if not death and not run and not own then return end

    local guess = Guess(guid)
    local item = { guid = guid, death = death, run = run, guess = guess, tries = 0,
        time = death and death.time or ns.Now(), where = ns.Where() }
    if death then ns.Sessions.SetKiller(death, guess) end
    if run then ns.Instances.SetKiller(run, guess) end
    if own then
        item.told = { guess = guess, time = item.time, where = item.where }
        ns.Fire("SD_YOU_DIED", item.told)
        item.slain = Deaths.Died(item.time, item.where)
        item.ranks = Ranks()
        Deaths.Killer(item.slain, Ranked(guess, item.ranks))
    end
    pending[#pending + 1] = item
    if not waiting then
        waiting = true
        ns.After(RETRY_SECONDS, Step)
    end
end

ns.On("PLAYER_DEAD", function()
    Died(ns.ownGUID)
end)

-- UNIT_DIED carries a readable GUID for group members (feasibility report
-- E5); a stranger's is secret in instances and SafeGUID drops it. The user's
-- own death is PLAYER_DEAD's, so it is not counted twice here.
ns.On("UNIT_DIED", function(_, guid)
    guid = ns.SafeGUID(guid)
    if guid and guid ~= ns.ownGUID then Died(guid) end
end)

-- Combat over: the earliest the recap can be read.
ns.On("PLAYER_REGEN_ENABLED", Try)

function ns._test.DeathsPending()
    return #pending
end
