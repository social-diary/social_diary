-- Facts for the duel angle: single duels and long series, wins, losses,
-- sweeps both ways and level scores, first duels and old rivalries whose
-- all-time tally leans either way (or has never gone one way at all).
return {
    angle = "duel",
    n = 1200,
    gen = function(P)
        local total = P.pick({ 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 6, 7 })
        local won
        local r = P.float()
        if total >= 2 and r < 0.15 then
            won = total                       -- a sweep
        elseif total >= 2 and r < 0.3 then
            won = 0                           -- swept
        elseif total % 2 == 0 and r < 0.6 then
            won = total / 2                   -- level
        else
            won = P.int(0, total)
        end
        local lost = total - won

        -- Who took the last one: it has to be someone who won a duel.
        local lastWon
        if won == 0 then lastWon = false
        elseif lost == 0 then lastWon = true
        else lastWon = P.chance(won / total) end

        local first = P.chance(0.3)
        local priorWon, priorLost = 0, 0
        if not first then
            local shape = P.float()
            if shape < 0.05 then
                priorWon, priorLost = 0, P.int(3, 10)       -- never beaten them...
                if total >= 2 and won ~= 1 then
                    won = 1                                 -- ...until a first win today
                    lost = total - 1
                    lastWon = P.chance(0.4)
                end
            elseif shape < 0.12 then
                priorWon, priorLost = P.int(2, 12), 0       -- never lost to them
            elseif shape < 0.24 then
                priorWon, priorLost = 0, P.int(2, 12)       -- never beaten them
            elseif shape < 0.34 then
                priorWon = P.int(1, 10)
                priorLost = priorWon + P.pick({ -1, 0, 1 })  -- neck and neck
                if priorLost < 0 then priorLost = 0 end
            else
                priorWon, priorLost = P.int(0, 25), P.int(0, 25)
            end
            if priorWon + priorLost == 0 then priorWon = 1 end
        end

        local who = P.person({ hostile = false, named = P.chance(0.5) })
        -- Someone I've duelled before is someone I'd know again.
        if not first and not who.diary and not who.named then who.familiar = true end
        return {
            who = who,
            won = won,
            lost = lost,
            total = total,
            lastWon = lastWon,
            lastLost = not lastWon,
            swept = lost == 0 and won >= 2,
            wasSwept = won == 0 and lost >= 2,
            even = won == lost,
            first = first,
            allWon = won + priorWon,
            allLost = lost + priorLost,
            zone = P.pick(P.ZONES),
            subZone = P.maybe(0.7, P.pick(P.SUBZONES)),
        }
    end,
}
