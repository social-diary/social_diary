-- Facts for the ding angle: one level or several, grouped or nearby, round
-- levels and the cap more often than chance would give them, and now and
-- then my own level within minutes of theirs.
return {
    angle = "ding",
    n = 1000,
    gen = function(P)
        local cap = 60
        local levels = P.pick({ 1, 1, 1, 1, 1, 1, 2, 2, 3 })
        local level
        local roll = P.float()
        if roll < 0.15 then
            level = cap
        elseif roll < 0.35 then
            level = P.pick({ 10, 20, 30, 40, 50 })
        else
            level = P.int(3, cap - 1)
        end
        level = math.max(level, levels + 1)
        local from = level - levels
        local together = P.chance(0.65)
        local alsoMe = P.chance(0.25)

        local page = P.page()
        if alsoMe then
            page.levelsGained = math.max(1, page.levelsGained)
            page.levelEnd = math.min(cap, page.levelStart + page.levelsGained)
            page.levelsGained = page.levelEnd - page.levelStart
            if page.levelsGained == 0 then
                page.levelStart = page.levelEnd - 1
                page.levelsGained = 1
            end
        end

        return {
            who = P.person({ diary = P.chance(0.8), named = true, hostile = false }),
            level = level,
            from = from,
            together = together,
            round = level % 10 == 0,
            cap = level == cap,
            alsoMe = alsoMe,
            levels = levels,
        }, page
    end,
}
