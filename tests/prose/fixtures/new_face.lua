-- Facts for the new_face angle: every way of meeting, with and without a
-- group's time and quests, guildmates, and those written into the diary
-- today (some tagged, some not).
local HOWS = {
    group = "viaGroup", trade = "viaTrade", duel = "viaDuel", campfire = "viaCampfire",
    chat = "viaChat", rescue = "viaRescue", say = "viaSay",
}
local ORDER = { "group", "group", "group", "trade", "trade", "duel", "duel", "campfire", "campfire",
    "chat", "chat", "rescue", "rescue", "say", "say" }
local TAGS = { "friend", "friend", "friend", "healer", "tank", "crafter", "guild", "funny", "avoid", "foe" }

return {
    angle = "new_face",
    n = 1500,
    gen = function(P)
        local how = P.pick(ORDER)
        local added = P.chance(0.45)
        local tag = added and P.maybe(0.6, P.pick(TAGS)) or nil
        -- Someone written into the diary today goes by name from then on;
        -- a whisper always brings a name, and others are named only sometimes.
        local named = added or how == "chat" or P.chance(0.3)
        local who = P.person({
            diary = added,
            named = (not added) and named or nil,
            hostile = false,
        })
        if not who.diary and not who.named then
            who.familiar = nil
        end
        -- A relationship is something I'd set on the day I added them, if at all.
        local wary = tag == "avoid" or tag == "foe"
        who.relationship = who.diary and not wary and P.maybe(0.25, P.pick({ "levelling buddy", "friend", "guild healer", "fishing partner" })) or nil
        who.tags = {}
        if tag then who.tags[tag] = true end

        local zone = P.pick(P.ZONES)
        local grouped = how == "group"
        local f = {
            who = who,
            how = how,
            zone = zone,
            subZone = P.maybe(0.65, P.pick(P.SUBZONES)),
            seconds = grouped and P.pick({ 300, 600, 900, 1500, 2400, 3600, 5400, 7200, 10800, P.int(5, 240) * 60 }) or nil,
            quests = grouped and P.pick({ 0, 1, 1, 2, 3, 4, 5, 7, 12 }) or nil,
            guildmate = P.chance(0.2),
            theirLevel = P.maybe(0.85, P.int(5, 60)),
            addedToday = added,
            tag = tag,
        }
        f[HOWS[how]] = true
        for _, flag in pairs(HOWS) do
            if f[flag] == nil then f[flag] = false end
        end
        return f
    end,
}
