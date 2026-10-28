-- Facts for the quiet angle: uneventful sessions, mostly with nobody from
-- the diary, sometimes nobody at all; no levels or a few; short and long.
return {
    angle = "quiet",
    n = 1000,
    gen = function(P)
        local gained = P.pick({ 0, 0, 0, 1, 1, 2 })
        local start = P.int(5, 60 - gained)
        local seen = P.pick({ 0, 0, 0, 1, P.int(2, 6), P.int(2, 6), P.int(7, 11), P.int(12, 40) })
        local nobody = P.chance(0.8)
        local zones = {}
        local nz = P.pick({ 1, 1, 1, 2, 2, 3 })
        while #zones < nz do
            local z = P.pick(P.ZONES)
            local dup = false
            for i = 1, #zones do if zones[i] == z then dup = true end end
            if not dup then zones[#zones + 1] = z end
        end
        local page = P.page({
            levelStart = start, levelEnd = start + gained, levelsGained = gained, levelCap = 60,
            zones = zones, zoneFirst = zones[1], zoneLast = zones[#zones],
            solo = P.chance(0.7),
            -- quiet sessions run short more often than most
            seconds = P.pick({ P.int(15, 44), P.int(15, 44), P.int(45, 179), P.int(45, 179), P.int(180, 300) }) * 60,
            seen = seen,
            diaryMet = nobody and 0 or 1,
            newFaces = 0,
            myDeaths = P.pick({ 0, 0, 0, 1 }),
        })
        return {
            nobodyKnown = nobody,
            seen = seen,
            gained = gained,
        }, page
    end,
}
