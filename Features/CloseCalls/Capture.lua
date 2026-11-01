-- Close calls' capture (JRN-25): a fight judged once combat is over, and
-- kept on the logged-in character's route (Kind.lua's Added) while it is
-- kept (Journey.Kept).
--
-- The player's health is secret always (probes, 11 Oct), so a fight is
-- judged by the damage it did, less the healing that came in: the
-- client's damage meter, read once combat is over, when its numbers are
-- plain, against the maximum health. Healing received is no meter type;
-- it is each healer's spells by the unit healed, as PrephDamageMeter's
-- "Targets healed" reads them. What was fought comes off the units while
-- they last: every creature that can attack the user and has them
-- targeted, off the user's target or a nameplate, counted by kind. Being
-- the user's target does not make a foe: a creature tabbed to is not
-- fighting them (as Features/Witnesses/Capture.lua's Mine).
--
-- Every fight judged is told as SD_FIGHT_SURVIVED (Core/Events.lua's
-- header), close or not, before a close call is kept: the witnesses keep
-- who pulled the user through it (Features/Witnesses/Capture.lua).
-- A duel's fight (SD_DUEL_FINISHED) is neither: a lost duel leaves the
-- user at 1 hp by the rules (probe, 15 Oct: it was kept as a close call).
--
-- Moved out of Capture/Combat.lua (15 Oct), which kept the hunts
-- (Features/Hunts/Capture.lua since). The two shared nothing but small client reads (the user's level, a unit's
-- name, written again here) and the route's gate, which is
-- Journey.Kept here (Combat's Live, the same test). The judge shares no
-- event with the hunts; its own (PLAYER_REGEN_DISABLED,
-- PLAYER_TARGET_CHANGED, PLAYER_REGEN_ENABLED) it now hears from the
-- features' block, before Capture/, rather than after Capture/Journey.lua.
-- Checked handler by handler, nothing it does is read by one it now runs
-- before: the route's FightStart and FightEnd (Capture/Journey.lua) mark
-- the open stop's fight, which the judge never reads, and it writes
-- nothing they read (the creature names, j.names, and the meter's
-- reading, j.meter); on the target, Capture/Nearby.lua and
-- Capture/Sightings.lua take players only, the judge creatures only
-- (ns.NpcID); at combat's end the judge's timer is still queued after
-- Deaths' (Features/Deaths/Capture.lua, before it in the TOC) and before
-- the witnesses' (after Capture/), as it was.

local addonName, ns = ...

local CloseCalls = ns.CloseCalls
local Journey = ns.Journey

local RANKS = { elite = true, rare = true, rareelite = true, worldboss = true }

-- Seconds: how long after combat the damage meter is read, and read again
-- while it does not read yet (`tries` times in all, Meter.Wait's, none of
-- them while it is busy), and how long it may stay busy (`deadline`).
local WAIT = { meter = 1, tries = 5, deadline = 5 * 60 }

-- The session a fight went unread in: what it holds next is two fights.
local unread

local function Level()
    local level = ns.Plain(UnitLevel("player"))
    return type(level) == "number" and level or nil
end

local function Name(unit)
    local name = ns.Plain((UnitName(unit)))
    return type(name) == "string" and name ~= "" and name or nil
end

-- The fight under way: { started, seen = { [guid] = true }, foes, kinds =
-- { [npcID] = { n, name, rank } } }.
local fight

local function Foe(unit)
    if not fight or not ns.Plain(UnitExists(unit)) or not ns.Plain(UnitCanAttack("player", unit)) then return end
    if ns.Plain(UnitGUID(unit .. "target")) ~= ns.ownGUID then return end
    local guid = ns.Plain(UnitGUID(unit))
    local npcID = ns.NpcID(guid)
    if not npcID or fight.seen[guid] then return end
    fight.seen[guid] = true
    fight.foes = fight.foes + 1
    local kind = fight.kinds[npcID]
    if not kind then
        kind = { n = 0 }
        fight.kinds[npcID] = kind
    end
    kind.n = kind.n + 1
    kind.name = kind.name or Name(unit)
    -- Kept a while, to put right a recap that gives it a surname.
    if kind.name then ns.CreatureNames.Note(npcID, kind.name) end
    -- Its level as it showed: -1 is the skull, a level not told.
    local level = ns.Plain(UnitLevel(unit))
    if type(level) == "number" and level ~= 0 then kind.level = level end
    local rank = UnitClassification and ns.Plain(UnitClassification(unit))
    if RANKS[rank] then kind.rank = rank end
end

-- The kind fought most: the most of them on the user, ties to the lower id.
local function Main(kinds)
    local best, npcID
    for id, kind in pairs(kinds) do
        if not best or kind.n > best.n or (kind.n == best.n and id < npcID) then best, npcID = kind, id end
    end
    return npcID, best
end

local Meter = ns.Meter
local Table = Meter.Table

-- The damage the user took in session `session`, and its id; nil while it
-- does not read. No row for the user is none taken.
local function Taken(session)
    local sources, id = Meter.Session("DamageTaken", session)
    if not sources then return nil end
    for _, src in ipairs(sources) do
        src = Table(src)
        if src and ns.Plain(src.isLocalPlayer) == true then
            local amount = ns.Plain(src.totalAmount)
            if type(amount) ~= "number" then return nil end
            return amount, id
        end
    end
    return 0, id
end

-- Whether the meter's unit name is the user's: by the first name, the
-- realm and any surname aside (the meter's own spelling is untested).
local function Mine(name)
    name = ns.Plain(name)
    local me = ns.Plain((UnitName("player")))
    if type(name) ~= "string" or type(me) ~= "string" then return false end
    local first = me:match("^[^%s%-]+")
    return first ~= nil and name:match("^[^%s%-]+") == first
end

-- A spell row's targets: combatSpellDetails is one or a list of them
-- (as PrephDamageMeter reads it). With one, the row is all theirs, and its
-- total is the sounder number.
local function Targets(spell)
    local d = Table(spell.combatSpellDetails)
    if not d then return {} end
    if d.unitName ~= nil or d.amount ~= nil then d = { d } end
    return d
end

local function Amount(spell, d, alone)
    local first, second = ns.Plain(d.amount), ns.Plain(spell.totalAmount)
    if alone then first, second = second, first end
    if type(first) == "number" and first ~= 0 then return first end
    return type(second) == "number" and second or first
end

-- The healing the user received in session `session`, from every healer
-- the meter lists (the user, their group): each healer's spells, broken
-- down by the unit healed. Nil while any of it does not read.
local function Received(session)
    local sources, id, which = Meter.Session("HealingDone", session)
    if not sources then return nil end
    local total = 0
    for _, src in ipairs(sources) do
        src = Table(src)
        if not src then return nil end
        local guid, creature = ns.Plain(src.sourceGUID), ns.Plain(src.sourceCreatureID)
        local spells = Meter.Spells(id, which, guid, creature)
        if not spells then return nil end
        for _, spell in ipairs(spells) do
            spell = Table(spell)
            if not spell then return nil end
            local targets = Targets(spell)
            for _, d in ipairs(targets) do
                d = Table(d)
                if not d then return nil end
                if ns.IsSecret(d.unitName) then return nil end
                if Mine(d.unitName) then
                    local amount = Amount(spell, d, #targets == 1)
                    if type(amount) ~= "number" then return nil end
                    total = total + amount
                end
            end
        end
    end
    return total, id
end

-- What the meter added since it was last read: a session that carries on
-- across fights counts from where it was (j.meter, saved, so a /reload
-- does not count it again); a new one, or one that started over, whole.
local function Since(j, kind, amount, id)
    j.meter = j.meter or {}
    local last = j.meter[kind]
    j.meter[kind] = { id = id, amount = amount }
    if last and last.id == id and amount >= last.amount then return amount - last.amount end
    return amount
end

-- Whether the fight is dealt with: false while the meter does not read.
local function Judge(f, now)
    local j = Journey.Kept()
    if not j then return true end
    local max = ns.Plain(UnitHealthMax("player"))
    local taken, id = Taken(f.session)
    local healed, hid = Received(f.session)
    if type(max) ~= "number" or not taken or not healed then
        ns.Debug("close call: the damage meter does not read yet")
        return false
    end
    -- The healing that kept the user up, theirs and their group's, is
    -- taken off: what is left is how far the fight brought them down.
    taken = Since(j, "taken", taken, id)
    healed = Since(j, "received", healed, hid)
    -- A fight went unread in this session: this reading holds both, so it
    -- only sets where the next one counts from.
    local mixed = unread == id
    unread = nil
    if mixed then
        ns.Debug("close call: an unread fight in the same session, left")
        return true
    end
    -- A fight the user died in is no close call, and a duel ends at 1 hp by
    -- the rules, alive: no close call, and no fight survived. The meter is
    -- still read first, so the next fight in the same session counts only
    -- its own damage.
    if f.died or f.duel then
        ns.Debug("close call: %s, left", f.died and "the user died" or "a duel's fight")
        return true
    end
    ns.Debug("close call: %d damage taken, %d healing received", taken, healed)
    taken = math.max(0, taken - healed)
    local npcID, kind = Main(f.kinds)
    -- Told to whoever keeps who pulled them through it (SD_FIGHT_SURVIVED,
    -- Core/Events.lua's header), before the close call is kept.
    ns.Fire("SD_FIGHT_SURVIVED", f.started, now, taken, max,
        npcID and { npcID = npcID, name = kind.name, rank = kind.rank } or nil)
    ns.Debug("close call: fight over, took %d of %d health, %d foe(s), most %s", taken, max, f.foes,
        tostring(kind and kind.name))
    local call = CloseCalls.Added({ t = now, level = Level(), taken = taken, max = max,
        seconds = math.max(0, now - f.started), npcID = npcID, name = kind and kind.name,
        rank = kind and kind.rank, foeLevel = kind and kind.level, foes = f.foes })
    -- Its creature's display, looked up as a killer's is (Deaths'
    -- capture), for its card's picture.
    if call and call.npcID and ns.Deaths then ns.Deaths.LookUp(call) end
    return true
end

ns.On("PLAYER_REGEN_DISABLED", function()
    if not Journey.Kept() then return end
    fight = { started = ns.Now(), seen = {}, foes = 0, kinds = {} }
    Foe("target")
    for _, unit in ipairs(ns.Units.Plates) do Foe(unit) end
end)

ns.On("PLAYER_TARGET_CHANGED", function()
    Foe("target")
end)

-- A creature turning on the user: it may not have them targeted yet as
-- the fight starts.
ns.On("UNIT_TARGET", function(_, unit)
    if type(unit) == "string" and (unit == "target" or unit:match("^nameplate%d+$")) then Foe(unit) end
end)

ns.On("NAME_PLATE_UNIT_ADDED", function(_, unit)
    Foe(unit)
end)

-- A duel's fight (SD_DUEL_FINISHED, Core/Events.lua's header): one still
-- open when the result comes (a knockout's comes before combat ends), or
-- one that ends while a duel is on (a flight's can come long after). A
-- duel with mobs joining in goes with it.
ns.On("SD_DUEL_FINISHED", function()
    if fight then fight.duel = true end
end)

ns.On("PLAYER_REGEN_ENABLED", function()
    local f = fight
    fight = nil
    if f and ns.Duelling() then f.duel = true end
    if f and Journey.Kept() then
        local now = ns.Now()
        f.session = Meter.Pin()
        -- The meter takes the last blows in a moment after, and the death
        -- is told by then. Dead now is dead in this fight; dead later, with
        -- the meter still busy, is the next one's.
        ns.After(WAIT.meter, function()
            f.died = ns.Plain(UnitIsDeadOrGhost("player")) == true
            Meter.Wait(function() return Judge(f, now) end, { every = WAIT.meter, tries = WAIT.tries,
                deadline = WAIT.deadline, gaveUp = function()
                    ns.Debug("close call: the damage meter never read, given up")
                    unread = f.session or Meter.Pin()
                end })
        end)
    end
end)

-- The meter started over, and its ids may too: nothing to count from.
ns.On("DAMAGE_METER_RESET", function()
    unread = nil
    local j = Journey.Kept()
    if j then j.meter = nil end
end)
