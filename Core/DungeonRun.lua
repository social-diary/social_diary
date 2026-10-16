-- A dungeon run's moments, placed on its map (.claude/dungeon-visits-prd.md
-- §18.2): the bosses with their kills, tries, wipes, deaths and loot; the
-- deaths between bosses on the route's legs; and what could not be placed.
-- Worked out when asked, from the visit and the dungeon's data, never
-- stored, so older runs follow any change to these rules.
--
-- Notes(visit) = {
--   bosses = { { boss, killed, inferred, at, tries, wipes, deaths = { death },
--             loot = { entry }, client } }, `inferred` when only its loot told of the
--             kill, `client` the client's name for it when the data's differs;
--             kills first in the order they fell, then those still standing;
--   legs = { { death, after = boss|nil, before = boss|nil, frac = 0..1|nil } },
--   wipes = { { after, before, frac, deaths = { death }, killer = name } },
--             wipes to trash on the way, at the leg of their first death;
--   ranBack = n,       -- times out as a ghost and back (MAP-12)
--   unplaced = { deaths = { death }, loot = { entry } },
-- }
-- `boss` is the dungeon's record (Core/Dungeons.lua); `death` and `entry`
-- the visit's own (Core/Instances.lua).

local addonName, ns = ...

local DungeonRun = {}
ns.DungeonRun = DungeonRun

-- Deaths this close together are a wipe when no pull says so: at a boss,
-- or to trash on the way (MAP-17).
local WIPE_WINDOW = 60

-- The group at `t` (members who had joined and not yet left), or
-- everyone who was ever in it.
local function Group(visit, t)
    local seen, n = {}, 0
    for _, m in ipairs(visit.members or {}) do
        local there = not t or ((m.joined or 0) <= t and (not m.left or m.left > t))
        if there and not seen[m.guid] then seen[m.guid], n = true, n + 1 end
    end
    if visit.me and not seen[visit.me] then n = n + 1 end
    return math.max(n, 1)
end

-- Half the group, at least one.
local function Half(visit, t)
    return math.max(1, math.ceil(Group(visit, t) / 2))
end
DungeonRun.Half = Half

-- The boss that killed, by name: the dungeon's data has no npcIDs.
local function Killer(visit, death)
    local k = death.killer
    return k and k.name and ns.Dungeons.Boss(visit.instanceID, k.name) or nil
end

function DungeonRun.Notes(visit)
    local out = { bosses = {}, legs = {}, ranBack = 0, unplaced = { deaths = {}, loot = {} } }
    if not visit then return out end
    local id = visit.instanceID
    local D = ns.Dungeons
    local byName = {}

    local function Entry(boss)
        local e = byName[boss.name]
        if not e then
            e = { boss = boss, tries = 0, wipes = 0, deaths = {}, loot = {} }
            byName[boss.name] = e
        end
        return e
    end

    -- Pulls: tries, kills and when.
    local pullBoss = {}
    for i, pull in ipairs(visit.pulls or {}) do
        local boss = D.Boss(id, pull.id) or D.Boss(id, pull.name)
        if boss then
            pullBoss[i] = boss
            local e = Entry(boss)
            -- What the client called it, when the data names it otherwise.
            if pull.name and pull.name ~= boss.name then e.client = pull.name end
            e.tries = e.tries + 1
            if pull.killed then e.killed, e.at = true, e.at or pull.stop end
        end
    end
    -- Kills the pulls don't hold (test data, a missed event).
    for _, name in ipairs(visit.bossesKilled or {}) do
        local boss = D.Boss(id, name)
        if boss then
            local e = Entry(boss)
            e.killed = true
        end
    end

    -- Every boss that counts, standing or not; rares and the rest only
    -- when something happened at them.
    for _, boss in ipairs(D.Bosses(id, visit.difficultyID, visit.wing)) do
        if D.Counts(id, boss) then Entry(boss) end
    end

    -- Loot (MAP-11): an item is a boss's only when that boss's loot table
    -- holds it; anything else was found on the way, and a boss's table
    -- never guesses from the time. An item off a boss's table proves the
    -- kill, also one the pull events missed (MAP-16): it fell no later
    -- than the loot.
    for _, entry in ipairs(visit.loot or {}) do
        local boss = D.LootBoss(id, entry.itemID)
        if boss and not D.IsTrash(boss) then
            local e = Entry(boss)
            e.loot[#e.loot + 1] = entry
            if not e.killed then e.killed, e.inferred = true, true end
            if e.inferred or not e.at then
                e.at = math.min(e.at or entry.time, entry.time)
            end
        else
            out.unplaced.loot[#out.unplaced.loot + 1] = entry
        end
    end
    for name in pairs(visit.inferred or {}) do
        if byName[name] then byName[name].inferred = true end
    end

    -- Kills in time order, for the legs.
    local kills = {}
    for _, e in pairs(byName) do
        if e.killed and e.at then kills[#kills + 1] = e end
    end
    table.sort(kills, function(a, b) return a.at < b.at end)

    -- Deaths (MAP-8, MAP-9).
    local inPull = {}
    for _, death in ipairs(visit.deathLog or {}) do
        local boss = death.pull and pullBoss[death.pull] or Killer(visit, death)
        if boss then
            local e = Entry(boss)
            e.deaths[#e.deaths + 1] = death
            if death.pull then
                inPull[death.pull] = (inPull[death.pull] or 0) + 1
            end
        elseif #kills == 0 then
            out.legs[#out.legs + 1] = { death = death }
        else
            local after, before
            for _, k in ipairs(kills) do
                if k.at <= death.time then after = k elseif not before then before = k end
            end
            local frac
            if after and before then
                frac = (death.time - after.at) / math.max(1, before.at - after.at)
            elseif before then
                frac = 1 - math.min(1, (before.at - death.time) / math.max(1, before.at - visit.startedAt))
            end
            out.legs[#out.legs + 1] = { death = death, after = after and after.boss,
                before = before and before.boss, frac = frac }
        end
    end

    -- Wipes (MAP-10): a pull that ended without a kill and with half the
    -- group dead in it; without pulls, half the group dead at one boss
    -- within WIPE_WINDOW.
    local half = Half(visit)
    for i, pull in ipairs(visit.pulls or {}) do
        local boss = pullBoss[i]
        if boss and pull.stop and not pull.killed and (inPull[i] or 0) >= Half(visit, pull.start) then
            Entry(boss).wipes = Entry(boss).wipes + 1
        end
    end
    for _, e in pairs(byName) do
        if e.tries == 0 and #e.deaths >= half then
            local list = {}
            for _, d in ipairs(e.deaths) do list[#list + 1] = d end
            table.sort(list, function(a, b) return a.time < b.time end)
            local i = 1
            while i <= #list do
                local j, guids, n = i, {}, 0
                while j <= #list and list[j].time - list[i].time <= WIPE_WINDOW do
                    if not guids[list[j].guid] then guids[list[j].guid], n = true, n + 1 end
                    j = j + 1
                end
                if n >= half then
                    e.wipes = e.wipes + 1
                    i = j
                else
                    i = i + 1
                end
            end
        end
    end

    -- Wipes on the way (MAP-17): half the group dead to trash within
    -- WIPE_WINDOW, on the leg its first death is on.
    out.wipes = {}
    local legs = {}
    for _, l in ipairs(out.legs) do legs[#legs + 1] = l end
    table.sort(legs, function(a, b) return a.death.time < b.death.time end)
    local i = 1
    while i <= #legs do
        local j, guids, n = i, {}, 0
        while j <= #legs and legs[j].death.time - legs[i].death.time <= WIPE_WINDOW do
            if not guids[legs[j].death.guid] then guids[legs[j].death.guid], n = true, n + 1 end
            j = j + 1
        end
        if n >= Half(visit, legs[i].death.time) then
            local deaths = {}
            for k = i, j - 1 do deaths[#deaths + 1] = legs[k].death end
            local killer = legs[i].death.killer
            out.wipes[#out.wipes + 1] = { after = legs[i].after, before = legs[i].before,
                frac = legs[i].frac, deaths = deaths, killer = killer and killer.name }
            i = j
        else
            i = i + 1
        end
    end

    -- Ghost runs (MAP-12): out as a ghost, and back in after.
    local spans = visit.spans or {}
    for i = 1, #spans - 1 do
        if spans[i].ghost then out.ranBack = out.ranBack + 1 end
    end

    -- Kills first, in the order they fell, then the rest in the dungeon's.
    local order = {}
    for i, name in ipairs(visit.bossesKilled or {}) do order[name] = i end
    for _, e in pairs(byName) do out.bosses[#out.bosses + 1] = e end
    table.sort(out.bosses, function(a, b)
        local ka, kb = a.killed and 1 or 0, b.killed and 1 or 0
        if ka ~= kb then return ka > kb end
        if a.killed then
            -- When they fell; the kill list's order for kills with no time
            -- (its names may be the client's, which the data's may not be).
            if a.at and b.at and a.at ~= b.at then return a.at < b.at end
            if (a.at ~= nil) ~= (b.at ~= nil) then return a.at ~= nil end
            local oa, ob = order[a.boss.name] or 999, order[b.boss.name] or 999
            if oa ~= ob then return oa < ob end
        end
        return (a.boss.order or 0) < (b.boss.order or 0)
    end)
    return out
end

-- How many times the run wiped: at its bosses and on the way. What the card
-- says ("10 deaths  ·  2 wipes"); the count kept on the record (bosses
-- only, at the time) when there is nothing to work it out from.
function DungeonRun.Wipes(visit)
    if not visit then return 0 end
    if not visit.deathLog or #visit.deathLog == 0 then return visit.wipes or 0 end
    local notes = DungeonRun.Notes(visit)
    local n = #notes.wipes
    for _, e in ipairs(notes.bosses) do n = n + (e.wipes or 0) end
    return math.max(n, visit.wipes or 0)
end
