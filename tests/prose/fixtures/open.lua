-- Facts for the open angle: one zone or several, short sessions and long,
-- solo or not, zones new today and old haunts returned to; levels from
-- none (climb skipped) to several, with round levels crossed or landed on
-- and the cap reached.
return {
    angle = "open",
    n = 1000,
    gen = function(P)
        local CAP = 60
        local start, gained
        local r = P.float()
        if r < 0.10 then
            gained = 0
            start = P.int(5, 59)
        elseif r < 0.34 then
            -- around a round level: land on it, or pass it
            local mile = P.pick({ 10, 20, 30, 40, 50 })
            gained = P.pick({ 1, 1, 2, 3 })
            start = mile - P.int(1, gained)
        elseif r < 0.48 then
            -- the cap
            gained = P.pick({ 1, 1, 2 })
            start = CAP - gained
        else
            gained = P.pick({ 1, 1, 1, 2, 2, 3, 4 })
            start = P.int(5, CAP - 1 - gained)
        end
        local finish = math.min(CAP, start + gained)
        gained = finish - start

        local zones = {}
        local nz = P.pick({ 1, 1, 2, 2, 3, 4 })
        while #zones < nz do
            local z = P.pick(P.ZONES)
            local dup = false
            for i = 1, #zones do if zones[i] == z then dup = true end end
            if not dup then zones[#zones + 1] = z end
        end

        local page = P.page({
            levelStart = start, levelEnd = finish, levelsGained = gained, levelCap = CAP,
            zones = zones, zoneFirst = zones[1], zoneLast = zones[#zones],
            -- more levels take longer: three or more never in under ninety minutes
            seconds = (gained >= 3 and P.int(90, 320) or P.pick({ P.int(15, 44), P.int(45, 179), P.int(45, 179), P.int(180, 320) })) * 60,
            solo = P.chance(0.4),
        })
        page.seen = P.int(0, 40)
        page.newFaces = page.solo and 0 or P.int(0, 4)
        page.diaryMet = P.int(0, 2)
        page.myDeaths = P.pick({ 0, 0, 0, 1, 2 })

        -- New zones: some of today's zones, occasionally all of them.
        local newZones
        if P.chance(0.25) then
            newZones = {}
            for i = 1, #zones do
                if P.chance(0.5) then newZones[#newZones + 1] = zones[i] end
            end
            if #newZones == 0 then newZones[1] = zones[#zones] end
        end
        -- A returned-to zone: one of today's that isn't new.
        local returnZone
        if P.chance(0.2) then
            local pool = {}
            for i = 1, #zones do
                local new = false
                for j = 1, #(newZones or {}) do if newZones[j] == zones[i] then new = true end end
                if not new then pool[#pool + 1] = zones[i] end
            end
            if #pool > 0 then returnZone = P.pick(pool) end
        end

        local milestone
        for lvl = start + 1, finish do
            if lvl % 10 == 0 then milestone = lvl end
        end

        return {
            newZones = newZones,
            returnZone = returnZone,
            returnDays = returnZone and P.pick({ 30, 34, 45, 60, 90, 150, 400 }) or nil,
            milestone = milestone,
            reachedCap = gained > 0 and finish == CAP,
            levelsToCap = finish < CAP and (CAP - finish) or nil,
        }, page
    end,
}
