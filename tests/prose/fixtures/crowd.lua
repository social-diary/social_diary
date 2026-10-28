-- Facts for the crowd angle: from a handful of players to a crowd, with
-- and without strangers grouped with, the other faction about or not, one
-- zone or several.
return {
    angle = "crowd",
    n = 1200,
    gen = function(P)
        local seen = P.pick({ P.int(2, 6), P.int(7, 14), P.int(15, 30), P.int(15, 30), P.int(31, 90), P.int(100, 180) })
        local solo = P.chance(0.4)
        local grouped = solo and 0 or math.min(seen, P.pick({ 0, 1, 1, 2, 3, 4, 6 }))
        local faces = math.min(seen, grouped + P.pick({ 0, 0, 1, 2 }))
        local zones = {}
        local nz = P.pick({ 1, 2, 2, 3 })
        while #zones < nz do
            local z = P.pick(P.ZONES)
            local dup = false
            for i = 1, #zones do if zones[i] == z then dup = true end end
            if not dup then zones[#zones + 1] = z end
        end
        local busiest = P.pick(zones)
        local busiestSeen = #zones == 1 and seen or math.max(2, math.floor(seen * (0.4 + P.float() * 0.5)))
        local page = P.page({
            zones = zones, zoneFirst = zones[1], zoneLast = zones[#zones],
            solo = solo,
            seen = seen,
            newFaces = faces,
            diaryMet = P.pick({ 0, 0, 1 }),
        })
        return {
            seen = seen,
            newFaces = faces,
            groupedWith = grouped,
            busiestZone = busiest,
            busiestSeen = busiestSeen,
            hostileSeen = P.chance(0.4) and P.pick({ 1, P.int(1, math.max(1, math.floor(seen / 2))) }) or 0,
        }, page
    end,
}
