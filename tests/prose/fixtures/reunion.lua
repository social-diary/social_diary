-- Facts for the reunion angle, across the shapes the planner can send:
-- record gaps and ordinary ones, long absences, same zone or new, with and
-- without the optional history.
return {
    angle = "reunion",
    n = 600,
    gen = function(P)
        local usual = P.int(1, 10)
        local gap = P.int(math.max(3, usual * 2), 90)
        local record = P.chance(0.35)
        local first = gap + P.int(1, 200)
        local zone = P.pick(P.ZONES)
        local same = P.chance(0.3)
        local who = P.person({ diary = P.chance(0.85), named = true })
        local f = {
            who = who,
            gapDays = gap,
            usualGapDays = usual,
            longAbsence = gap >= usual * 3,
            isRecordGap = record,
            prevRecordDays = record and P.int(2, gap - 1) or nil,
            lastWhen = P.now - gap * P.DAY - P.int(0, 20000),
            lastZone = same and zone or P.pick(P.ZONES),
            lastGrouped = P.chance(0.6),
            sameZoneAsLast = same,
            zone = zone,
            subZone = P.maybe(0.6, P.pick(P.SUBZONES)),
            zoneNewForUs = (not same) and P.chance(0.3),
            timesMet = P.int(2, 60),
            firstZone = P.pick(P.ZONES),
            firstMetDays = first,
            addedWhen = P.maybe(0.7, P.now - (first - P.int(0, 3)) * P.DAY),
        }
        return f
    end,
}
