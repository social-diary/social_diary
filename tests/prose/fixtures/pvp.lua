-- Facts for the pvp angle: deaths to hostile players (certain or probable,
-- with or without the spell, first-timers and repeat killers the diary has
-- told before, outlevelled or not) and kills, by a groupmate or by me,
-- some of them revenge.
return {
    angle = "pvp",
    n = 1600,
    gen = function(P, i)
        local who = P.person({ hostile = true, named = P.chance(0.55) })
        -- A hostile player is rarely a diary entry, and never "my brother".
        who.diary = P.chance(0.15)
        who.relationship = nil
        if not who.diary and who.named == nil then who.named = false end
        local zone = P.pick(P.ZONES)

        -- Deaths and kills alternate in runs of four pages, so each move gets
        -- half the pages in every voice (the voice turns with i). The death
        -- move needs timesKilledMe and the kill move timesKilledThem, so each
        -- page renders just one of them.
        if math.floor(i / 4) % 2 == 0 then
            local times = P.pick({ 1, 1, 1, 2, 2, 3, 4, 5, 7, 12 })
            local f = {
                who = who,
                probable = P.chance(0.4),
                spell = P.maybe(0.55, P.pick({ "Ambush", "Backstab", "Eviscerate", "Pyroblast",
                    "Frostbolt", "Aimed Shot", "Mortal Strike", "Shadow Bolt", "Chaos Bolt",
                    "Lightning Bolt", "Execute", "Starfire" })),
                timesKilledMe = times,
                lastDeathWhen = times >= 2 and (P.now - P.int(1, 40) * P.DAY - P.int(0, 20000)) or nil,
                toldBefore = times >= 2 and P.chance(0.6),
                zone = zone,
                subZone = P.maybe(0.7, P.pick(P.SUBZONES)),
                outlevelled = P.chance(0.3),
            }
            return f, P.page({ myDeaths = P.int(1, 4) })
        end

        local mine = P.chance(0.45)
        local by
        if not mine then
            by = P.person({ hostile = false, named = P.chance(0.6) })
            while by.name == who.name do by.name = P.pick(P.NAMES) end
        end
        local revenge = P.chance(0.4)
        local f = {
            who = who,
            by = by,
            mine = mine,
            timesKilledThem = P.pick({ 1, 1, 1, 2, 2, 3, 5, 8 }),
            revenge = revenge,
            zone = zone,
        }
        return f
    end,
}
