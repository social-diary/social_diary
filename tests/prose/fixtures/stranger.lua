-- Facts for the stranger angle: a familiar stranger seen near me on three
-- or more days in a week or a month, usually unnamed (sometimes described
-- before, so "the night elf hunter"), levelling or not, and silent: never
-- spoken, never grouped, or both.
return {
    angle = "stranger",
    n = 800,
    gen = function(P)
        local week = P.chance(0.55)
        local window = week and 7 or 30
        local days = week and P.int(3, 7) or P.pick({ 3, 4, 5, 6, 8, 10, 12, 15, 19, 24, 28, 30 })
        local who = P.person({ diary = false, named = P.chance(0.12), hostile = P.chance(0.08) })
        who.relationship = nil
        local first = P.int(5, 58)
        local rise = P.pick({ 0, 0, 0, 1, 1, 2, 3, 5, 8 })
        if not week then rise = P.pick({ 0, 1, 2, 4, 6, 9, 12 }) end
        local now = math.min(60, first + rise)
        local silent = P.float()
        local f = {
            who = who,
            days = days,
            windowDays = window,
            zone = P.pick(P.ZONES),
            subZone = P.maybe(0.7, P.pick(P.SUBZONES)),
            sameSpot = P.chance(0.45),
            sameTime = P.chance(0.4),
            levelFirst = first,
            levelNow = now,
            levelRise = now - first,
            neverSpoke = silent < 0.85,
            neverGrouped = silent < 0.7 or silent >= 0.85,
        }
        return f
    end,
}
