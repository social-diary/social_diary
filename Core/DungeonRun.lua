-- A dungeon run's moments, placed on its map (.claude/dungeon-visits-prd.md
-- §18.2): the bosses with their kills, tries, wipes, deaths and loot; the
-- deaths between bosses on the route's legs; and what could not be placed.
-- Worked out when asked, from the visit and the dungeon's data, never
-- stored, so older runs follow any change to these rules.
--
-- Notes(visit) = {
--   bosses = { { boss, killed, inferred, at, tries, wipes, near, deaths = { death },
--             loot = { entry }, client, fight = { from, to }, share } },
--             `near` the kills nearly lost (NEAR) and `nearDeaths` the most
--             that went down in one; `inferred` when only its loot told of the kill, `client` the
--             client's name for it when the data's differs; `fight` from its
--             first pull to its kill (else its last pull's end), wipes and
--             all, and `share` that of the run's time inside (`inside`);
--             kills first in the order they fell, then those still standing;
--   legs = { { death, after = boss|nil, before = boss|nil, frac = 0..1|nil } },
--   wipes = { { after, before, frac, deaths = { death }, killer = name } },
--             wipes to trash on the way, at the leg of their first death;
--   near = { { after, before, frac, deaths = { death } } },
--             near wipes to trash on the way (NEAR), as `wipes`; a boss's
--             own are its entry's `near` (a count of kills nearly lost);
--   levels = { { guid, level, time, after, before, frac } },
--             level-ups during the run, the user's and the group's, on the
--             leg they happened on, as a death on the way is (LevelUps);
--   inside = seconds,  -- the run's time inside (its spans), for `share`
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
-- A near wipe (from deaths alone): a boss killed in a pull that cost the
-- group at least half of it less one (`less`), and never fewer than
-- `least`; or deaths to trash within WIPE_WINDOW that came as near
-- without reaching half (a wipe).
local NEAR = { less = 1, least = 2 }
DungeonRun.WIPE_WINDOW, DungeonRun.NEAR = WIPE_WINDOW, NEAR

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

-- How many dead in a pull, or a cluster, come near a wipe at `t`.
local function Nearly(visit, t)
    return math.max(NEAR.least, Half(visit, t) - NEAR.less)
end
DungeonRun.Nearly = Nearly

-- Where a moment at time `t` lies between the kills (`kills`, in time
-- order): the kill before it, the one after, and how far along between
-- them (from the start of the run before the first).
local function Between(visit, kills, t)
    local after, before
    for _, k in ipairs(kills) do
        if k.at <= t then after = k elseif not before then before = k end
    end
    local frac
    if after and before then
        frac = (t - after.at) / math.max(1, before.at - after.at)
    elseif before then
        frac = 1 - math.min(1, (before.at - t) / math.max(1, before.at - (visit.startedAt or t)))
    end
    return after and after.boss, before and before.boss, frac
end

-- Level-ups during `visit`, { { guid, level, time } } by time: the user's
-- own (their route's levels, Core/Journey.lua) and the group's (the
-- level-up rows on its members, Features/LevelUps), each once.
function DungeonRun.LevelUps(visit)
    local out, seen = {}, {}
    local from, to = visit.startedAt or 0, visit.endedAt or math.huge
    local function Add(guid, level, time)
        local key = tostring(guid) .. ":" .. tostring(level)
        if type(level) == "number" and type(time) == "number" and time >= from and time <= to and not seen[key] then
            seen[key] = true
            out[#out + 1] = { guid = guid, level = level, time = time }
        end
    end
    local me = visit.me or ns.ownGUID
    local journey = ns.Journey and ns.Journey.For(me)
    for level, rec in pairs(journey and journey.levels or {}) do Add(me, level, rec.at) end
    for _, m in ipairs(visit.members or {}) do
        if m.guid ~= me then
            for _, row in ipairs(ns.Interactions.For(m.guid) or {}) do
                if row.type == "level_up" then Add(m.guid, row.context and row.context.level, row.time) end
            end
        end
    end
    table.sort(out, function(a, b) return a.time < b.time end)
    return out
end

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
            local after, before, frac = Between(visit, kills, death.time)
            out.legs[#out.legs + 1] = { death = death, after = after, before = before, frac = frac }
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
        -- A kill nearly lost (NEAR).
        if boss and pull.killed and (inPull[i] or 0) >= Nearly(visit, pull.start) then
            local e = Entry(boss)
            e.near = (e.near or 0) + 1
            e.nearDeaths = math.max(e.nearDeaths or 0, inPull[i])
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
    -- And the near wipes there: as near as NEAR, short of half.
    out.near = {}
    local i = 1
    while i <= #legs do
        local j, guids, n = i, {}, 0
        while j <= #legs and legs[j].death.time - legs[i].death.time <= WIPE_WINDOW do
            if not guids[legs[j].death.guid] then guids[legs[j].death.guid], n = true, n + 1 end
            j = j + 1
        end
        local t = legs[i].death.time
        local deaths = {}
        for k = i, j - 1 do deaths[#deaths + 1] = legs[k].death end
        if n >= Half(visit, t) then
            local killer = legs[i].death.killer
            out.wipes[#out.wipes + 1] = { after = legs[i].after, before = legs[i].before,
                frac = legs[i].frac, deaths = deaths, killer = killer and killer.name }
            i = j
        elseif n >= Nearly(visit, t) then
            out.near[#out.near + 1] = { after = legs[i].after, before = legs[i].before, frac = legs[i].frac,
                deaths = deaths }
            i = j
        else
            i = i + 1
        end
    end

    -- Each boss's fight, from its first pull to its kill (or its last
    -- pull's end), wipes and all, as a share of the run's time inside.
    local inside = 0
    for _, span in ipairs(visit.spans or {}) do
        if span.from and span.to and span.to > span.from then inside = inside + span.to - span.from end
    end
    if inside == 0 and visit.startedAt and visit.endedAt then inside = math.max(0, visit.endedAt - visit.startedAt) end
    out.inside = inside
    for k, pull in ipairs(visit.pulls or {}) do
        local boss = pullBoss[k]
        if boss and pull.start then
            local e = Entry(boss)
            e.fight = e.fight or { from = pull.start }
            e.fight.from = math.min(e.fight.from, pull.start)
            if not e.fight.done then e.fight.to = math.max(e.fight.to or pull.start, pull.stop or pull.start) end
            if pull.killed then e.fight.done = true end
        end
    end
    for _, e in pairs(byName) do
        if e.fight and inside > 0 then e.share = (e.fight.to - e.fight.from) / inside end
    end

    -- Level-ups, on the leg they happened on.
    out.levels = {}
    for _, up in ipairs(DungeonRun.LevelUps(visit)) do
        local after, before, frac = Between(visit, kills, up.time)
        out.levels[#out.levels + 1] = { guid = up.guid, level = up.level, time = up.time, after = after,
            before = before, frac = frac }
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

-- Where a moment at time `t` lies on the run's way, between its kills
-- (`notes`, DungeonRun.Notes'): { after, before, frac } as a death on the
-- way's leg is (a drop found on the way, rolled for: the map's strips).
function DungeonRun.When(visit, notes, t)
    local kills = {}
    for _, e in ipairs(notes and notes.bosses or {}) do
        if e.killed and e.at then kills[#kills + 1] = e end
    end
    table.sort(kills, function(a, b) return a.at < b.at end)
    local after, before, frac = Between(visit, kills, t or visit.startedAt or 0)
    return { after = after, before = before, frac = frac }
end

--------------------------------------------------------------------------
-- Rolls (pass B, untested in the client)
--------------------------------------------------------------------------

-- The user's rules (16 Oct), Need rolls only: an item rare or better
-- (`snagQuality`) the user needed and lost by `snag` or less was snagged
-- from them; a Need roll of `bad` or less is a bad roll worth a strip, on
-- green or better (`badQuality`), anyone's in the run.
local ROLLS = { snag = 15, snagQuality = 3, bad = 3, badQuality = 2 }
DungeonRun.ROLLS = ROLLS

-- How often `itemID` dropped in front of the user on a run: each drop
-- once, whether its loot line, its roll or both were kept.
local function DropsOf(visit, itemID)
    local looted, rolled = 0, 0
    for _, entry in ipairs(visit.loot or {}) do
        if entry.itemID == itemID then looted = looted + 1 end
    end
    for _, drop in ipairs(visit.rolls or {}) do
        if drop.itemID == itemID then rolled = rolled + 1 end
    end
    return math.max(looted, rolled)
end

-- Whether the user needed `itemID` on an earlier run and lost it.
local function LostBefore(earlier, me, itemID)
    for _, visit in ipairs(earlier) do
        for _, drop in ipairs(visit.rolls or {}) do
            if drop.itemID == itemID and drop.need and drop.need[me] and drop.winner and drop.winner ~= me then
                return true
            end
        end
    end
    return false
end

-- A run's rolls, as the map tells them: { snagged = { { drop, boss, mine,
-- theirs, winner } }, bad = { { drop, boss, guid, roll } }, finally = {
-- { item, itemID, time, boss, before, total } } }. `boss` is the one whose
-- table holds the item, or nil (found on the way). `finally`: an item the
-- user got on this run that they needed and lost on an earlier one,
-- `before` its drops in front of them on the user's earlier runs (every
-- drop seen, the user's rule) and `total` with this one.
function DungeonRun.Rolls(visit)
    local out = { snagged = {}, bad = {}, finally = {} }
    if not visit then return out end
    local D, Quality = ns.Dungeons, ns.Timeline.Quality
    local me = visit.me
    local function Boss(itemID)
        local boss = D.LootBoss(visit.instanceID, itemID)
        return boss and not D.IsTrash(boss) and boss or nil
    end

    for _, drop in ipairs(visit.rolls or {}) do
        local quality = Quality(drop.item) or 0
        local mine = drop.need and drop.need[me]
        if type(mine) == "number" and drop.winner and drop.winner ~= me and drop.winNeed
            and drop.winRoll and drop.winRoll >= mine and drop.winRoll - mine <= ROLLS.snag
            and quality >= ROLLS.snagQuality then
            out.snagged[#out.snagged + 1] = { drop = drop, boss = Boss(drop.itemID), mine = mine,
                theirs = drop.winRoll, winner = drop.winner }
        end
        if quality >= ROLLS.badQuality then
            for guid, roll in pairs(drop.need or {}) do
                if type(roll) == "number" and roll <= ROLLS.bad then
                    out.bad[#out.bad + 1] = { drop = drop, boss = Boss(drop.itemID), guid = guid, roll = roll }
                end
            end
        end
    end
    table.sort(out.bad, function(a, b)
        if a.roll ~= b.roll then return a.roll < b.roll end
        return (a.drop.time or 0) < (b.drop.time or 0)
    end)

    -- What the user got here, by loot line or by a roll won.
    local got, seen = {}, {}
    for _, entry in ipairs(visit.loot or {}) do
        if entry.guid == me and entry.itemID and not seen[entry.itemID] then
            seen[entry.itemID] = true
            got[#got + 1] = { item = entry.item, itemID = entry.itemID, time = entry.time }
        end
    end
    for _, drop in ipairs(visit.rolls or {}) do
        if drop.winner == me and drop.itemID and not seen[drop.itemID] then
            seen[drop.itemID] = true
            got[#got + 1] = { item = drop.item, itemID = drop.itemID, time = drop.time }
        end
    end
    if #got == 0 then return out end
    local earlier = {}
    for _, other in ipairs(ns.Instances.All()) do
        if other ~= visit and other.me == me and (other.startedAt or 0) < (visit.startedAt or 0) then
            earlier[#earlier + 1] = other
        end
    end
    for _, g in ipairs(got) do
        if LostBefore(earlier, me, g.itemID) then
            local before = 0
            for _, other in ipairs(earlier) do before = before + DropsOf(other, g.itemID) end
            g.boss, g.before, g.total = Boss(g.itemID), before, before + 1
            out.finally[#out.finally + 1] = g
        end
    end
    return out
end

--------------------------------------------------------------------------
-- A person's run (the party's cards, step 4)
--------------------------------------------------------------------------

-- What a member's card says of them, at most two of it (the map's cards,
-- UI/Dungeon/Cards.lua): facts only, never a judgement. In this order:
--   snagged   an item they snagged from the user ({ item })
--   won       the best item they got (a loot line, or a roll won), rare
--             or better ({ item, quality })
--   died      how often they died in the run ({ n })
--   rolled    a Need roll of ROLLS.bad or less ({ roll })
--   reached   a level they reached in the run ({ level })
--   late      joined `late` seconds or more after the run began
--   early     left `late` seconds or more before it ended
--   won       an item below rare ({ item, quality })
--   together  the how-manyth run of the user's with them this was ({ n },
--             from the second; diary people only)
-- `visit.me`'s own card has no snagged, late, early or together.
local PERSON = { late = 120 }
DungeonRun.PERSON = PERSON

function DungeonRun.Person(visit, guid)
    local out = {}
    if not (visit and guid) then return out end
    local me = visit.me or ns.ownGUID
    local isMe = guid == me
    local rolls = DungeonRun.Rolls(visit)
    local Quality = ns.Timeline.Quality

    if not isMe then
        for _, sn in ipairs(rolls.snagged) do
            if sn.winner == guid then out[#out + 1] = { kind = "snagged", item = sn.drop.item } end
        end
    end
    -- What they got: by loot line or a roll won, each item once, best first.
    local got, seen = {}, {}
    local function Got(item, itemID)
        local key = itemID or item
        if item and not seen[key] then
            seen[key] = true
            got[#got + 1] = { item = item, quality = Quality(item) or 0 }
        end
    end
    for _, entry in ipairs(visit.loot or {}) do
        if entry.guid == guid then Got(entry.item, entry.itemID) end
    end
    for _, drop in ipairs(visit.rolls or {}) do
        if drop.winner == guid then Got(drop.item, drop.itemID) end
    end
    table.sort(got, function(a, b) return a.quality > b.quality end)
    local best = got[1]
    if best and best.quality >= ROLLS.snagQuality and not (out[1] and out[1].item == best.item) then
        out[#out + 1] = { kind = "won", item = best.item, quality = best.quality }
    end
    local deaths = 0
    for _, death in ipairs(visit.deathLog or {}) do
        if death.guid == guid then deaths = deaths + 1 end
    end
    if deaths > 0 then out[#out + 1] = { kind = "died", n = deaths } end
    local low
    for _, b in ipairs(rolls.bad) do
        if b.guid == guid and (not low or b.roll < low) then low = b.roll end
    end
    if low then out[#out + 1] = { kind = "rolled", roll = low } end
    local reached
    for _, up in ipairs(DungeonRun.LevelUps(visit)) do
        if up.guid == guid then reached = math.max(reached or 0, up.level) end
    end
    if reached then out[#out + 1] = { kind = "reached", level = reached } end
    if not isMe then
        for _, m in ipairs(visit.members or {}) do
            if m.guid == guid then
                if m.joined and visit.startedAt and m.joined - visit.startedAt >= PERSON.late then
                    out[#out + 1] = { kind = "late" }
                end
                if m.left and visit.endedAt and visit.endedAt - m.left >= PERSON.late then
                    out[#out + 1] = { kind = "early" }
                end
                break
            end
        end
    end
    if best and best.quality < ROLLS.snagQuality then
        out[#out + 1] = { kind = "won", item = best.item, quality = best.quality }
    end
    if not isMe and ns.Diary.IsDiary(guid) then
        local n = 0
        for _, other in ipairs(ns.Instances.For(guid)) do
            if (other.me or me) == me and (other.startedAt or 0) <= (visit.startedAt or 0) then n = n + 1 end
        end
        if n >= 2 then out[#out + 1] = { kind = "together", n = n } end
    end
    return out
end
