-- Facts for the close angle: where I stopped (with and without a subzone),
-- late finishes, levels gained or not, one zone or several.
return {
    angle = "close",
    n = 1000,
    gen = function(P)
        local gained = P.pick({ 0, 0, 1, 1, 2, 3 })
        local start = P.int(5, 60 - gained)
        local page = P.page({
            levelStart = start, levelEnd = start + gained, levelsGained = gained, levelCap = 60,
            solo = P.chance(0.4),
        })
        page.seen = P.int(0, 40)
        page.newFaces = page.solo and 0 or P.int(0, 4)
        page.diaryMet = P.int(0, 2)
        page.myDeaths = P.pick({ 0, 0, 0, 1, 2, 4 })
        -- After midnight only for a session that began in the evening or at
        -- night and ran long enough to cross it.
        local late = (page.part == "night" or (page.part == "evening" and page.seconds >= 7200))
            and P.chance(0.75) or false
        return {
            lateEnd = late,
            endZone = page.zoneLast,
            endSubZone = P.maybe(0.6, P.pick(P.SUBZONES)),
        }, page
    end,
}
