return {
    angle = "regular",
    n = 300,
    gen = function(P)
        return {
            who = P.person({ diary = true }),
            streakDays = P.int(2, 12),
            zone = P.maybe(0.6, P.pick(P.ZONES)),
        }
    end,
}
