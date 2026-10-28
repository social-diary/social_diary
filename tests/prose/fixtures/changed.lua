-- Facts for the changed angle: a new name, a guild joined, left or
-- switched, and levels gained since we last met, alone or together. The
-- flags agree with the guilds: joined only from no guild to one, left only
-- from one to none, switched only between two different ones. When a thing
-- didn't change, its facts say so (same guild or none, gained 0, no names).
local GUILDS = {
    "Dawnwatch", "Ironforge Irregulars", "Knights of the Ember", "Moonglade Wardens",
    "Last Light", "Tidewalkers", "Hearth and Hammer", "The Silver Covenant",
    "Order of the Quiet Blade", "Stormwind Night Watch", "Crimson Lantern", "Barrens Chat Survivors",
    "Wolves of Ashenvale", "Unseen Hand", "Goldshire Gentlemen's Club",
}
local NEW_NAMES = {
    "Brenna", "Ilyriel", "Thandris", "Kaeli", "Mortis", "Sylwyn", "Grubby", "Tess",
    "Orwyn", "Zulrik", "Maelith", "Dorrin", "Fenwick", "Ashkara", "Veluna", "Hobbes",
}

return {
    angle = "changed",
    n = 1000,
    gen = function(P)
        local who = P.person({ diary = P.chance(0.8), named = true })
        local days = P.pick({ 1, 2, 3, 4, 6, 7, 9, 12, 15, 19, 24, 30, 38, 45, 60, 75, 100, 140 })
        local f = { who = who, daysSince = days }

        local doName, doGuild, doLevels = P.chance(0.5), P.chance(0.6), P.chance(0.7)
        if not (doName or doGuild or doLevels) then
            local which = P.int(1, 3)
            doName, doGuild, doLevels = which == 1, which == 2, which == 3
        end

        if doName then
            local new = P.pick(NEW_NAMES)
            f.oldName = who.name
            f.newName = new
            who.name = new
        end

        f.joined, f.left, f.switched = false, false, false
        if doGuild then
            local kind = P.pick({ "joined", "left", "switched", "switched" })
            if kind == "joined" then
                f.newGuild = P.pick(GUILDS)
                f.joined = true
            elseif kind == "left" then
                f.oldGuild = P.pick(GUILDS)
                f.left = true
            else
                f.oldGuild = P.pick(GUILDS)
                repeat f.newGuild = P.pick(GUILDS) until f.newGuild ~= f.oldGuild
                f.switched = true
            end
        else
            local same = P.maybe(0.6, P.pick(GUILDS))
            f.oldGuild, f.newGuild = same, same
        end

        -- Levels: more days, room for more levels; never past the cap.
        local cap = 60
        local reach = math.max(1, math.min(15, math.floor(days / 2) + 2))
        local wantCap = doLevels and P.chance(0.12)
        local start = P.int(5, 58)
        local gained = 0
        if doLevels then
            if wantCap then
                gained = P.int(1, math.min(reach, 8))
                start = cap - gained
            else
                gained = P.int(1, reach)
                start = math.min(start, cap - 1 - gained)
            end
        end
        f.theirLevelThen = start
        f.theirLevel = start + gained
        f.gained = gained
        f.myGained = P.pick({ 0, 0, 1, 1, 2, 3, 4, gained, gained, math.max(0, gained - 1), gained + 2 })
        who.level = f.theirLevel

        return f
    end,
}
