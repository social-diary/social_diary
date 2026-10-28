-- Facts for the misfortune angle: two deaths close together. within 0 is
-- the same moment, and then neither went first; otherwise usually one did.
-- With sameKiller there is always a foe; without it, foe is what killed me.
return {
    angle = "misfortune",
    n = 1000,
    gen = function(P)
        local who = P.person()
        local r = P.float()
        if r < 0.05 then
            who.tags.foe = true
        elseif r < 0.10 then
            who.tags.avoid = true
        elseif r < 0.18 and who.diary then
            who.tags.friend = true
        end
        local within = P.pick({ 0, 0, 1, 1, 2, 3, 4, 5, 7, 10, 14, 20, 30, 45, 60 })
        local iFirst, theyFirst = false, false
        if within > 0 and P.chance(0.9) then
            iFirst = P.chance(0.5)
            theyFirst = not iFirst
        end
        local same = P.chance(0.6)
        return {
            who = who,
            foe = (same or P.chance(0.8)) and P.foe() or nil,
            sameKiller = same,
            within = within,
            iDiedFirst = iFirst,
            theyDiedFirst = theyFirst,
            zone = P.pick(P.ZONES),
            subZone = P.maybe(0.6, P.pick(P.SUBZONES)),
            grouped = P.chance(0.5),
        }
    end,
}
