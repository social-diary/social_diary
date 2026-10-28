-- Facts for the trade angle. Each sample is one trade, in one direction:
-- a gift (they gave), given (I gave) or a swap (both ways), so only the
-- matching move can say anything and the other two are skipped. Amounts
-- run from a few coppers to hundreds of gold; item lists from a single
-- item to several stacks; people from old diary friends to strangers.
return {
    angle = "trade",
    n = 2400,
    gen = function(P)
        -- Copper on a rough log scale, 5 copper to 300 gold, with the round
        -- sums people actually hand over.
        local function Copper()
            if P.chance(0.3) then
                return P.pick({ 5, 10, 50, 100, 500, 1000, 5000, 10000, 20000, 50000,
                    100000, 250000, 500000, 1000000, 3000000 })
            end
            local exp = 0.7 + P.float() * 5.78
            return math.max(5, math.floor(10 ^ exp))
        end

        -- P.items, with no link twice in one trade: a repeated stack reads
        -- as a mistake ("ten [Silk Cloth] and a [Silk Cloth]").
        local used = {}
        local function Items(max)
            local list = {}
            for _, e in ipairs(P.items(max)) do
                if not used[e.link] then
                    used[e.link] = true
                    list[#list + 1] = e
                end
            end
            if #list == 0 then
                for _, link in ipairs(P.ITEMS) do
                    if not used[link] then
                        used[link] = true
                        list[1] = { link = link, count = P.pick({ 1, 2, 5 }) }
                        break
                    end
                end
            end
            return list
        end

        local diary = P.chance(0.45)
        local who = P.person({ diary = diary, hostile = false })
        if diary and P.chance(0.35) then who.tags.friend = true end
        if P.chance(0.05) then who.tags.avoid = true end

        -- A stranger is more often a first trade; a diary entry less so.
        local first = P.chance(diary and 0.15 or 0.5)
        local f = { who = who, first = first }

        local kind = P.pick({ "gift", "gift", "gift", "given", "given", "swap", "swap" })
        local function Back(f)
            if not first and P.chance(0.4) then
                f.returned = true
                f.returnDays = P.maybe(0.75, P.pick({ 1, 2, 3, 5, 7, 9, 12, 16, 21, 30, 45, 80 }))
            end
        end

        if kind == "gift" or kind == "given" then
            local itemsKey = kind == "gift" and "received" or "given"
            local moneyKey = kind == "gift" and "moneyReceived" or "moneyGiven"
            local r = P.float()
            if r < 0.55 then
                f[itemsKey] = Items(P.pick({ 1, 1, 2, 3, 4 }))
            elseif r < 0.85 then
                f[moneyKey] = Copper()
            else
                f[itemsKey] = Items(P.pick({ 1, 2, 3 }))
                f[moneyKey] = Copper()
            end
            Back(f)
        else
            local r = P.float()
            if r < 0.35 then
                f.received = Items(P.pick({ 1, 1, 2, 3 }))
                f.given = Items(P.pick({ 1, 1, 2, 3 }))
            elseif r < 0.62 then
                f.received = Items(P.pick({ 1, 1, 2 }))
                f.moneyGiven = Copper()
            elseif r < 0.89 then
                f.given = Items(P.pick({ 1, 1, 2, 3 }))
                f.moneyReceived = Copper()
            elseif r < 0.95 then
                f.received = Items(2)
                f.given = Items(2)
                f.moneyGiven = Copper()
            else
                f.received = Items(2)
                f.given = Items(2)
                f.moneyReceived = Copper()
            end
        end
        return f
    end,
}
