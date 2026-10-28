-- Facts for the together angle: grouped sessions and nearby-only ones,
-- short and long, one zone or several, with and without quests, others in
-- the group (as a count or as people), the whole session or part of it, and
-- now and then a rare or some deaths.
return {
    angle = "together",
    n = 800,
    gen = function(P)
        local page = P.page()
        local grouped = P.chance(0.65)
        local whole = P.chance(0.2)
        local seconds
        if whole then
            seconds = page.seconds
        else
            seconds = math.floor(page.seconds * P.pick({ 0.1, 0.25, 0.3, 0.5, 0.5, 0.7, 0.8 }))
            seconds = math.max(120, seconds)
        end

        -- The zones we shared: one or more of the session's own.
        local zones = {}
        local nz = P.pick({ 1, 1, 1, 2, 2, 3 })
        if seconds < 1800 then nz = 1 elseif seconds < 3600 then nz = math.min(nz, 2) end
        for i = 1, math.min(nz, #page.zones) do zones[i] = page.zones[i] end
        local zone = zones[P.int(1, #zones)]

        local quests, others
        if grouped then
            -- No more than a quest every five minutes or so.
            quests = P.pick({ 0, 0, 1, 2, 3, 4, 5, 6, 8, 11, 14 })
            quests = math.min(quests, math.floor(seconds / 300))
            if P.chance(0.4) then
                if P.chance(0.5) then
                    others = P.pick({ 1, 1, 2, 3, 3 })
                else
                    others = {}
                    for i = 1, P.int(1, 3) do
                        others[i] = P.person({ diary = false, named = P.chance(0.2), hostile = false })
                    end
                end
            end
        end

        local f = {
            who = P.person({ diary = P.chance(0.8), named = true, hostile = false }),
            seconds = seconds,
            grouped = grouped,
            zones = zones,
            zone = zone,
            quests = quests,
            others = others,
            wholeSession = whole,
        }

        if P.chance(0.55) then
            local count = P.pick({ 1, 1, 1, 1, 2, 2, 3, 4 })
            f.rare = P.pick(P.RARES)
            f.rareCount = count
            f.rareKilled = P.chance(0.7)
        end

        if P.chance(0.6) then
            local theirs = P.pick({ 0, 0, 1, 1, 1, 2, 2, 3, 5 })
            local mine = P.pick({ 0, 0, 1, 1, 1, 2, 3, 4 })
            if theirs + mine == 0 then
                if P.chance(0.5) then theirs = 1 else mine = 1 end
            end
            f.theirDeaths = theirs
            f.myDeaths = mine
            page.myDeaths = math.max(page.myDeaths or 0, mine)
        end

        return f, page
    end,
}
