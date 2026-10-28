-- Facts for the campfire angle: someone sat at my campfire. Usually a
-- stranger (sometimes a familiar face, sometimes a diary entry), alone or
-- with others; sometimes not their first time at my fire.
return {
    angle = "campfire",
    n = 1000,
    gen = function(P)
        local diary = P.chance(0.25)
        local who = P.person({ diary = diary, hostile = false })
        if not diary then
            who.named = P.chance(0.1)
            who.familiar = (not who.named) and P.chance(0.25) or nil
        end
        local page = P.page()
        who.level = P.pick({ P.int(5, 60), page.levelEnd, page.levelEnd + P.int(1, 4), math.max(1, page.levelEnd - P.int(1, 10)) })
        who.level = math.min(60, who.level)
        local first = P.chance(0.7)
        if not diary and not who.familiar and not who.named then first = P.chance(0.9) end
        return {
            who = who,
            zone = P.pick(P.ZONES),
            subZone = P.maybe(0.6, P.pick(P.SUBZONES)),
            theirLevel = who.level,
            strangers = P.pick({ 0, 0, 0, 1, 1, 2, 3, 5 }),
            firstTime = first,
        }, page
    end,
}
