-- Facts for the witness angle: someone near me when I died, for a second
-- or a few minutes, sometimes fighting too. The foe is missing now and
-- then (a death the log can't pin on a creature); the pointed tags are rare.
return {
    angle = "witness",
    n = 1000,
    gen = function(P)
        local who = P.person()
        local r = P.float()
        if r < 0.06 then
            who.tags.foe = true
        elseif r < 0.12 then
            who.tags.avoid = true
        elseif r < 0.2 and who.diary then
            who.tags.friend = true
        end
        return {
            who = who,
            watched = P.pick({ 1, 2, 3, 4, 5, 6, 8, 10, 12, 15, 20, 25, 30, 40, 50, 60, 90, 150, 200 }),
            foe = P.maybe(0.9, P.foe()),
            zone = P.pick(P.ZONES),
            subZone = P.maybe(0.6, P.pick(P.SUBZONES)),
            alsoHelped = P.chance(0.25),
        }
    end,
}
