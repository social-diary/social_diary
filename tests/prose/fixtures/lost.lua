-- Facts for the lost angle: someone not met in a long while. Sometimes I
-- saw them nearby since (seenDays, more recent than lastDays, 0 for today),
-- sometimes they whispered (heardDays), often neither. `longest` only when
-- the gap is well past their usual one.
return {
    angle = "lost",
    n = 1200,
    gen = function(P)
        local usual = P.pick({ 1, 2, 3, 3, 4, 5, 7, 10, 14 })
        local last = P.int(math.max(14, usual * 3), 200)
        local who = P.person({ diary = P.chance(0.85), named = true, hostile = false })
        local seen, heard
        if P.chance(0.3) then seen = P.pick({ 0, P.int(1, math.floor(last * 0.6)), P.int(1, 10) }) end
        if P.chance(0.25) then heard = P.pick({ P.int(1, math.floor(last * 0.6)), P.int(1, 6) }) end
        return {
            who = who,
            lastDays = last,
            lastZone = P.pick(P.ZONES),
            timesMet = P.pick({ 1, 2, 3, 5, 8, 12, 20, 35, 60 }),
            usualGapDays = usual,
            longest = P.chance(0.4),
            seenDays = seen,
            heardDays = heard,
        }
    end,
}
