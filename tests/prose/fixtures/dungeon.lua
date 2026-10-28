-- Facts for the dungeon angle, across the shapes the planner can send: full
-- clears and partial runs (and the odd run with no boss at all), first
-- visits and first clears, groups with a friend or only strangers, clean
-- runs and wipes, loot for me, for the friend or both, and rolls won and
-- lost, close and not.
--
-- Kept consistent the way the game is: a wipe kills everyone, so it adds a
-- death per member and one of mine; whoever died most died at least as
-- more often than I did; a first visit that cleared the place is a first
-- clear.
-- When I won a roll, winRoll is the best roll I beat (see Dungeon.lua).

-- Item names are never pluralised by the formatter, so the fixture keeps to
-- singular names ("a [Robes of Arugal]" would be the formatter's problem).
local LOOT = {
    "[Cruel Barb]", "[Smite's Mighty Hammer]", "[Taming Rod]", "[Shadowfang]",
    "[Embrace of the Viper]", "[Cookie's Tenderizer]", "[Blackened Defias Belt]", "[Ironfoe]",
    "[Archaedic Stone]", "[Fang of the Crystal Spider]", "[Thrash Blade]", "[Corpsemaker]",
    "[Orb of Deception]", "[Stonemason Cloak]", "[Silkweb Belt]", "[Butcher's Slicer]",
}
local STACKS = { "[Silk Cloth]", "[Mageweave Cloth]", "[Runecloth]", "[Large Fang]" }

local function Loot(P, max)
    local list, seen = {}, {}
    for i = 1, P.int(1, max) do
        local entry
        if P.chance(0.2) then
            entry = { link = P.pick(STACKS), count = P.pick({ 2, 3, 4, 6 }) }
        else
            entry = { link = P.pick(LOOT), count = 1 }
        end
        if not seen[entry.link] then
            seen[entry.link] = true
            list[#list + 1] = entry
        end
    end
    return list
end

return {
    angle = "dungeon",
    n = 1000,
    gen = function(P)
        -- The group: me, maybe a friend from the diary (and more), strangers.
        local size = P.pick({ 5, 5, 5, 5, 5, 5, 4, 4, 3, 2 })
        local friend, friendCount
        if P.chance(0.65) then
            friend = P.person({ diary = true, hostile = false })
            local t = P.float()
            friend.tags = (t < 0.4 and { friend = true }) or (t < 0.45 and { avoid = true }) or {}
            friendCount = math.min(size - 1, P.pick({ 1, 1, 1, 1, 1, 2, 2, 3 }))
        end
        local strangers = size - 1 - (friendCount or 0)
        local function Other(diary)
            local p = P.person({ diary = diary, hostile = false })
            while friend and p.name == friend.name do p.name = P.pick(P.NAMES) end
            return p
        end

        -- How far we got.
        local total = P.maybe(0.92, P.pick({ 3, 4, 5, 5, 6, 6, 7, 8 }))
        local killed
        local r = P.float()
        if total then
            if r < 0.55 then killed = total
            elseif r < 0.95 then killed = P.int(1, total - 1)
            else killed = 0 end
        else
            killed = r < 0.95 and P.int(1, 6) or 0
        end
        local full
        if total then full = killed == total end
        local firstVisit = P.chance(0.25)
        local firstClear = full and (firstVisit or P.chance(0.2)) or false
        local seconds = P.pick({ P.int(15, 40), P.int(40, 90), P.int(60, 120), P.int(90, 180), P.int(150, 240) }) * 60

        -- Deaths.
        local wipes, deaths, myDeaths = 0, 0, 0
        local deadliest, deadliestCount
        if not P.chance(0.28) then
            wipes = P.pick({ 0, 0, 0, 1, 1, 1, 2, 2, 3, 4 })
            local extra = P.int(wipes == 0 and 1 or 0, 7)
            local mine = P.chance(0.3) and 0 or P.int(0, extra)
            deaths = wipes * size + extra
            myDeaths = wipes + mine
            local left = extra - mine
            if left > 0 then
                local theirs = wipes + P.int(math.max(1, math.ceil(left / 2)), left)
                if theirs >= 2 and theirs > myDeaths and P.chance(0.85) then
                    if friend and (strangers == 0 or P.chance(0.35)) then
                        deadliest = friend
                    else
                        deadliest = Other(strangers == 0)
                    end
                    deadliestCount = theirs
                end
            end
        end

        -- Loot.
        local myLoot = P.maybe(0.6, Loot(P, 3))
        local friendLoot = friend and P.maybe(0.6, Loot(P, 2)) or nil
        if not myLoot and not friendLoot then myLoot = Loot(P, 2) end

        -- A roll.
        local rollItem, iWon, winner, myRoll, winRoll, close
        if P.chance(0.85) then
            rollItem = { { link = P.pick(LOOT), count = 1 } }
            iWon = P.chance(0.45)
            local high = P.chance(0.08) and 100 or P.int(2, 100)
            local diff = P.chance(0.3) and P.int(1, 3) or P.int(1, high - 1)
            if diff > high - 1 then diff = high - 1 end
            local low = high - diff
            if not iWon and P.chance(0.05) then low = 1 end
            close = high - low <= 3
            if iWon then
                myRoll, winRoll = high, low
            else
                myRoll, winRoll = low, high
                winner = (friend and P.chance(0.25)) and friend or Other(false)
            end
        end

        local f = {
            instance = P.pick(P.INSTANCES),
            difficulty = P.pick({ "normal", "normal", "normal", "normal", "normal", "heroic" }),
            groupSize = size,
            friend = friend,
            friendCount = friendCount,
            strangers = strangers,
            seconds = seconds,
            bossesKilled = killed,
            bossesTotal = total,
            fullClear = full,
            firstClear = firstClear,
            firstVisit = firstVisit,
            wipes = wipes,
            deaths = deaths,
            myDeaths = myDeaths,
            noDeaths = deaths == 0,
            deadliest = deadliest,
            deadliestCount = deadliestCount,
            myLoot = myLoot,
            friendLoot = friendLoot,
            rollItem = rollItem,
            iWon = iWon,
            winner = winner,
            myRoll = myRoll,
            winRoll = winRoll,
            close = close,
        }
        local page = P.page()
        if page.seconds < seconds then page.seconds = seconds + P.int(0, 90) * 60 end
        return f, page
    end,
}
