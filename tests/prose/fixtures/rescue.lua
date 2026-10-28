-- Facts for the rescue angle. A beat is either `saved` (someone stepped in
-- when I was low, and I lived: pct, timesSaved, firstByThem) or `helped`
-- (someone fought my foe with me: died, never pct), never both.
-- pct runs 1-60, skewed low; repeat rescuers are more often familiar.
return {
    angle = "rescue",
    n = 1600,
    gen = function(P)
        local who = P.person({ hostile = P.chance(0.05) })
        local r = P.float()
        if r < 0.05 then
            who.tags.avoid = true
        elseif r < 0.10 then
            who.tags.foe = true
        elseif r < 0.18 and who.diary then
            who.tags.friend = true
        end
        local foe = P.foe()
        if P.chance(0.62) then
            -- squared, so most rescues come low: 1, 2, 3 ... 60
            local pct = 1 + math.floor(59 * P.float() ^ 2 + 0.5)
            if P.chance(0.05) then pct = 1 end
            local times = P.pick({ 1, 1, 1, 1, 1, 2, 2, 3, 4, 6 })
            if times >= 2 and not who.diary and not who.named and P.chance(0.5) then
                who.familiar = true
            end
            return {
                who = who,
                pct = pct,
                foe = foe,
                timesSaved = times,
                firstByThem = times == 1,
                grouped = P.chance(0.4),
            }
        end
        return {
            who = who,
            foe = foe,
            died = P.chance(0.35),
            grouped = P.chance(0.4),
        }
    end,
}
