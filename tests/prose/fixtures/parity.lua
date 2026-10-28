-- Facts for the parity angle: me ahead, them ahead or level; small gaps
-- and big; with a last meeting to compare against (the lead changing hands,
-- the gap closing, widening or holding) and without one.
return {
    angle = "parity",
    n = 1000,
    gen = function(P)
        local function Sign(x)
            if x > 0 then return 1 elseif x < 0 then return -1 end
            return 0
        end

        local diff = P.pick({ 0, 0, 0, 0, 1, -1, 1, -1, 2, -2, 3, -3, 4, -5, 5, -7, 8, -12, 15 })
        local mine = P.int(math.max(5, 5 + diff), math.min(60, 60 + diff))
        local theirs = mine - diff

        local diffThen
        if P.chance(0.8) then
            local kind = P.pick({ "same", "closer", "wider", "cross", "cross", "wider", "closer" })
            if kind == "same" then
                diffThen = diff
            elseif kind == "closer" then
                -- The gap was bigger, on the same side (or either side when
                -- we're level now).
                local side = Sign(diff) ~= 0 and Sign(diff) or P.pick({ 1, -1 })
                diffThen = side * (math.abs(diff) + P.int(1, 4))
            elseif kind == "wider" then
                -- The gap was smaller, on the same side, or nothing.
                if diff == 0 then
                    diffThen = P.pick({ 1, -1, 2, -2 })
                else
                    diffThen = Sign(diff) * P.int(0, math.abs(diff) - 1)
                end
            else
                -- The other side led.
                if diff == 0 then
                    diffThen = P.pick({ 1, -2, 3 })
                else
                    diffThen = -Sign(diff) * P.int(1, 6)
                end
            end
        end

        local f = {
            who = P.person({ diary = P.chance(0.8), named = true, hostile = false }),
            myLevel = mine,
            theirLevel = theirs,
            levelDiff = diff,
            absLevelDiff = math.abs(diff),
            sameLevel = diff == 0,
            aheadMe = diff > 0,
            aheadThem = diff < 0,
            diffThen = diffThen,
        }
        if diffThen then
            f.crossed = Sign(diff) ~= 0 and Sign(diffThen) ~= 0 and Sign(diff) ~= Sign(diffThen)
            f.closed = math.abs(diff) < math.abs(diffThen)
            f.widened = math.abs(diff) > math.abs(diffThen)
        else
            f.crossed, f.closed, f.widened = false, false, false
        end
        return f, P.page({ levelStart = mine, levelEnd = mine, levelsGained = 0 })
    end,
}
