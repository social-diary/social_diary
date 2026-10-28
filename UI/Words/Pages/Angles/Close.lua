-- Close: a page's last sentence (no who). Where I stopped, the level I
-- ended at, the hour. It ends the entry and nothing more: no plans for
-- tomorrow, no hearthstone, no bed, nothing the facts don't hold.
--
-- coda facts (page.* plus)
--   lateEnd           the session ended after midnight
--   endZone           where I stopped (= page.zoneLast)
--   endSubZone        where I stopped, more closely, if known
--
-- Every clause, fragment and whole says "close.coda", the point of the
-- move. Tags said through page facts are shared with the opener, the quiet
-- line and the crowd: naming endZone also says page.zoneLast, so a zone the
-- opener already named isn't named again here (a subzone is new, and may).
--
-- Slots declared here (guards: they write nothing and drop the sentence
-- when untrue)
--   {close_stayed}    I ended in the zone I started in
--   {close_moved}     I ended somewhere other than where I started

local addonName, ns = ...

local Pages = ns.Pages
local Words = Pages.Words

Pages.Angle("close", { order = { "coda" },
    about = "a page's last sentence: where I stopped, and when" })

local function Guard(name, needs, test)
    Pages.Slot(name, {
        needs = function() return needs end,
        says = function() return {} end,
        fn = function(env)
            if test(env.f, env.f.page or {}) then return "" end
        end,
    })
end

Guard("close_stayed", { "page.zoneFirst", "page.zoneLast" }, function(f, page) return page.zoneFirst == page.zoneLast end)
Guard("close_moved", { "page.zoneFirst", "page.zoneLast" }, function(f, page) return page.zoneFirst ~= page.zoneLast end)

-- Adds the tags a piece says through page facts that its slots don't say
-- for it: the hour ({today}, {part}), the end zone (page.zoneLast), and
-- the move's own tag.
local KINDS = { "stems", "clauses", "fragments", "tails", "wholes" }
local CORE = { clauses = true, fragments = true, wholes = true }
local NEED_TAGS = {
    ["page.solo"] = "page.solo", ["page.levelsGained==0"] = "page.levelsGained",
    ["page.seconds>=10800"] = "page.seconds", ["page.seconds<2700"] = "page.seconds",
}

-- Feeling words said once per page, whichever angle says them: "glad of
-- the evening" in the closer after "glad of the quiet" in the quiet line.
local MOODS = { "glad", "enjoy", "content", "pleased", "lovely" }
local function Moods(text, says)
    local lower = text:lower()
    for _, w in ipairs(MOODS) do
        if lower:find(w, 1, true) then says[#says + 1] = "page.mood." .. w end
    end
end

local function Coda(spec)
    for _, kind in ipairs(KINDS) do
        local list = spec[kind] or {}
        for i = 1, #list do
            local p = list[i]
            if type(p) == "string" then p = { p }; list[i] = p end
            local says = {}
            if CORE[kind] then says[1] = "close.coda" end
            for _, t in ipairs(p.says or {}) do says[#says + 1] = t end
            local text = p[1]
            -- "tonight" twice on a page reads as a repeat; "the evening" as
            -- the thing that ended does not, so only {today} says the hour.
            if text:find("{today", 1, true) then says[#says + 1] = "page.part" end
            if text:find("endZone}", 1, true) then says[#says + 1] = "page.zoneLast" end
            -- "the evening" once per sentence: "I left the evening there,
            -- glad of the evening" is a stutter
            if text:find("{part", 1, true) then says[#says + 1] = "close.part" end
            for _, need in ipairs(p.needs or {}) do
                if NEED_TAGS[need] then says[#says + 1] = NEED_TAGS[need] end
                if need:find("^page%.levelsGained") then says[#says + 1] = "open.climb" end
            end
            -- levels gained, after the opener's climb, would be said twice
            if text:find("levelsGained}", 1, true) then says[#says + 1] = "open.climb" end
            Moods(text, says)
            p.says = says
        end
    end
    return spec
end

local LATE = { "lateEnd" }
local EVE = { "page.part==evening" }  -- "called it a night" wants an evening or later

--------------------------------------------------------------------------
-- coda: the last sentence
--------------------------------------------------------------------------

Words("close", "coda", Coda({
    must = { "close.coda" },

    stems = {
        { "In the end, ", says = { "close.end" } },
        { "At the end of it all, ", says = { "close.end" } },
        { "After a long session, ", needs = { "page.seconds>=10800" } },
        { "After a short session, ", needs = { "page.seconds<2700" } },
        "After {dur:page.seconds}, ",
        { "With {levels:page.levelsGained} more to my name, ", says = { "close.dangle" } },
        { "Still level {lvl:page.levelEnd}, ", needs = { "page.levelsGained==0" }, says = { "close.dangle" } },
        { "Well after midnight, ", needs = LATE },
        { "Some time after midnight, ", needs = LATE },
        { "Content, ", says = { "close.dangle", "close.feel" }, voice = "warm" },
        { "Happy with my lot, ", says = { "close.dangle", "close.feel" }, voice = "warm" },
        { "Eventually, ", says = { "close.late" }, voice = "wry" },
        { "At some unreasonable hour, ", needs = LATE, voice = "wry" },
        { "Having run out of excuses, ", says = { "close.dangle" }, voice = "wry" },
        { "End: ", voice = "terse" },
        { "After midnight: ", needs = LATE, voice = "terse" },
    },

    clauses = {
        "I logged off {at:endSubZone}",
        "I logged off {in:endZone}",
        "I stopped {at:endSubZone}, {in:endZone}",
        "I left my character {at:endSubZone}",
        "I left off {in:endZone}",
        "I finished up {at:endSubZone}",
        { "I called it a night {at:endSubZone}", needs = { "page.part~=morning", "page.part~=afternoon" } },
        { "I called it a night {in:endZone}", needs = { "page.part~=morning", "page.part~=afternoon" } },
        { "I called it a day {in:endZone}", needs = { "page.part~=evening", "page.part~=night" } },
        "I logged off at level {lvl:page.levelEnd}",
        "I logged out at level {lvl:page.levelEnd}, {in:endZone}",
        { "I ended the {part} at level {lvl:page.levelEnd}", says = { "close.end" } },
        { "the {part} ended {at:endSubZone}", says = { "close.end", "close.dangle" } },
        { "the session ended {in:endZone}", says = { "close.end", "close.dangle" } },
        { "{v.cap:endSubZone} is where I left off", says = { "close.dangle" } },
        { "I was still level {lvl:page.levelEnd} when I logged off", needs = { "page.levelsGained==0" } },
        { "I logged off a few levels higher than I'd started", needs = { "page.levelsGained>=3" }, says = { "page.levelsGained" } },
        { "it was past midnight when I logged off", needs = LATE, says = { "close.dangle" } },
        { "I didn't log off until after midnight", needs = LATE },
        { "the clock had gone past midnight by the time I stopped", needs = LATE, says = { "close.dangle" } },
        { "I logged off {at:endSubZone}, content", voice = "warm", final = true },
        { "I logged off {at:endSubZone}, a good place to stop", voice = "warm", final = true },
        { "I left the {part} there, {at:endSubZone}", says = { "close.part" }, voice = "warm" },
        { "I finally dragged myself away {at:endSubZone}", voice = "wry" },
        { "I tore myself away from {v:endZone}", voice = "wry" },
        { "the {part} simply ran out {in:endZone}", says = { "close.dangle" }, voice = "wry" },
        { "I parked myself {at:endSubZone} and logged off", voice = "wry" },
        { "I logged off", voice = "terse", bonus = -0.5, final = true },
    },

    fragments = {
        "Logged off {at:endSubZone}",
        "Logged off {in:endZone}, level {lvl:page.levelEnd}",
        "Stopped {at:endSubZone}",
        { "Level {lvl:page.levelEnd} at the close", says = { "close.end" } },
        { "Ended the {part} {at:endSubZone}", says = { "close.end" } },
        { "Ended the {part} at level {lvl:page.levelEnd}", says = { "close.end" } },
        "Finished up {at:endSubZone}",
        { "Done for the night {at:endSubZone}", needs = { "page.part~=morning", "page.part~=afternoon" } },
        { "Done for the day {in:endZone}", needs = { "page.part~=evening", "page.part~=night" } },
        { "Still level {lvl:page.levelEnd} at the end", needs = { "page.levelsGained==0" }, says = { "close.end" } },
        { "Past midnight by the time I stopped", needs = LATE },
        { "Logged off in the small hours", needs = LATE },
        { "A good place to leave off, {v:endSubZone}", voice = "warm", final = true },
        { "Level {lvl:page.levelEnd}, and content with it", voice = "warm", final = true },
        { "Logged off {at:endSubZone}, eventually", says = { "close.late" }, voice = "wry", final = true },
        { "Past midnight, somehow", needs = LATE, voice = "wry" },
        { "End: {v:endSubZone}", voice = "terse" },
        { "Off at level {lvl:page.levelEnd}", voice = "terse" },
        { "Logged off, {v:endZone}", voice = "terse" },
        { "Level {lvl:page.levelEnd}, {v:endZone}, after midnight", needs = LATE, voice = "terse", final = true },
    },

    tails = {
        ", at level {lvl:page.levelEnd}",
        { ", still level {lvl:page.levelEnd}", needs = { "page.levelsGained==0" } },
        { ", {levels:page.levelsGained} higher than I'd started" },
        ", {in:endZone}",
        ", after {dur:page.seconds}",
        ", {dur:page.seconds} after I'd logged on",
        { ", well after midnight", needs = LATE },
        { ", some time after midnight", needs = LATE },
        { ", in the small hours", needs = LATE },
        { ", and that was the {part}", says = { "close.part", "close.and" } },
        { ", and that was that", says = { "close.and" }, bonus = -0.5 },
        { ", on my own to the end", needs = { "page.solo" }, says = { "close.dangle" } },
        { ", content with the {part}", says = { "close.dangle", "close.feel", "close.part" }, voice = "warm" },
        { ", glad of the {part}", says = { "close.dangle", "close.feel", "close.part" }, voice = "warm" },
        { ", happy enough with how it went", says = { "close.dangle", "close.feel" }, voice = "warm" },
        { ", and no complaints", says = { "close.feel", "close.and" }, voice = "warm" },
        { ", with a good {part} behind me", needs = { "page.myDeaths<2" }, says = { "close.dangle", "close.feel", "close.part" }, voice = "warm" },
        { ", and no regrets", says = { "close.feel", "close.and" }, voice = "warm" },
        { ", eventually", says = { "close.late" }, voice = "wry" },
        { ", a little later than was sensible", needs = LATE, voice = "wry" },
        { ", which was as far as I got", voice = "wry" },
        { ", not a moment too soon", says = { "close.late" }, voice = "wry" },
        { ", having done roughly what I set out to do, or close enough", voice = "wry" },
        { ", past midnight", needs = LATE, voice = "terse" },
    },

    wholes = {
        "I logged off {at:endSubZone}.",
        "I logged off {at:endSubZone} {today}.",
        "I stopped {in:endZone}, at level {lvl:page.levelEnd}.",
        "That was where I logged off: {v:endSubZone}, {in:endZone}.",
        "I left my character {at:endSubZone} and logged off.",
        { "The {part} ended {in:endZone}, at level {lvl:page.levelEnd}.", says = { "close.end" } },
        { "Level {lvl:page.levelEnd} at the end of it.", says = { "close.end" } },
        "I logged off {at:endSubZone}. Level {lvl:page.levelEnd}.",
        "I ended the {part} {at:endSubZone}, level {lvl:page.levelEnd}.",
        "{v.cap:endSubZone} is where I stopped.",
        "{v.cap:endZone} is where I left off.",
        { "Then I logged off.", bonus = -0.5 },
        { "And that was the {part}.", bonus = -0.5 },
        { "That was enough for one session.", bonus = -1 },
        { "I left it at that.", bonus = -1 },
        { "That was where I stopped.", bonus = -1 },
        { "I ended the {part} where I'd started it, in {v:endZone}{close_stayed}.", says = { "page.zoneFirst" } },
        { "I'd started in {v:page.zoneFirst}; I finished {at:endSubZone}, {in:endZone}{close_moved}." },
        { "I finished {in:endZone}, a fair way from {v:page.zoneFirst}, where the {part} began{close_moved}." },
        { "It was after midnight when I finally logged off.", needs = LATE },
        { "I logged off well after midnight, {at:endSubZone}.", needs = LATE },
        { "By the time I logged off it was past midnight.", needs = LATE },
        { "Midnight came and went, and I logged off {at:endSubZone} some time after.", needs = LATE },
        { "I logged off at level {lvl:page.levelEnd}, a good while after midnight.", needs = LATE },
        { "Still level {lvl:page.levelEnd} when I logged off.", needs = { "page.levelsGained==0" } },
        { "I logged off at level {lvl:page.levelEnd}, the same level I'd started at.", needs = { "page.levelsGained==0" } },
        { "I logged off {levels:page.levelsGained} higher than I'd logged on, {at:endSubZone}." },
        { "A solo {part}, start to finish; I logged off {at:endSubZone}.", needs = { "page.solo" } },
        { "I logged off {in:endZone} after {dur:page.seconds} on my own.", needs = { "page.solo" } },
        { "A long session; I logged off {at:endSubZone} at level {lvl:page.levelEnd}.", needs = { "page.seconds>=10800" } },
        { "A short one {today}; I logged off {at:endSubZone}.", needs = { "page.seconds<2700" }, bonus = 0.5 },
        -- warm
        { "I logged off {at:endSubZone}, glad of the {part}.", voice = "warm" },
        { "I left my character {at:endSubZone}, as good a place to leave off as any.", voice = "warm" },
        { "Level {lvl:page.levelEnd}, {v:endZone}, and {part.a} I enjoyed.", needs = { "page.myDeaths<2" }, voice = "warm" },
        { "A good {part}. I logged off {at:endSubZone} content with it.", needs = { "page.myDeaths<2" }, voice = "warm" },
        { "I logged off {in:endZone}, happy with how the {part} went.", needs = { "page.myDeaths<2" }, voice = "warm" },
        { "That was the {part}, and a good one.", needs = { "page.myDeaths<2" }, voice = "warm" },
        { "I stopped {at:endSubZone}, which felt like the right place for it.", voice = "warm" },
        { "Still level {lvl:page.levelEnd}, and I don't mind in the least.", needs = { "page.levelsGained==0" }, voice = "warm" },
        { "It was past midnight when I logged off, and worth it.", needs = LATE, voice = "warm" },
        { "It was late when I logged off, and I didn't mind.", needs = LATE, voice = "warm" },
        -- wry
        { "It was well past midnight when I logged off, which is nobody's fault but mine.", needs = LATE, voice = "wry" },
        { "I logged off {at:endSubZone}, having run out of {part}.", voice = "wry" },
        { "I logged off {at:endSubZone}. The world will have to manage without me.", voice = "wry" },
        { "Still level {lvl:page.levelEnd}. Progress is relative.", needs = { "page.levelsGained==0" }, voice = "wry" },
        { "I'd meant to stop earlier. It was after midnight when I logged off.", needs = LATE, voice = "wry" },
        { "{v.cap:endSubZone}, level {lvl:page.levelEnd}, and a sensible bedtime long gone.", needs = LATE, voice = "wry" },
        { "I logged off {in:endZone}, which is as good a place as any to leave a character standing about.", voice = "wry" },
        { "And so, after {dur:page.seconds}, I logged off {at:endSubZone}. Riveting stuff.", voice = "wry" },
        -- terse
        { "Logged off {at:endSubZone}.", voice = "terse" },
        { "Logged off {at:endSubZone}. Past midnight.", needs = LATE, voice = "terse" },
        { "Level {lvl:page.levelEnd}. {v.cap:endZone}. Done.", voice = "terse" },
        { "Stopped {at:endSubZone}, level {lvl:page.levelEnd}.", voice = "terse" },
        { "Done {today}.", voice = "terse" },
        { "Off after midnight.", needs = LATE, voice = "terse" },
        { "Still {lvl:page.levelEnd}. Logged off.", needs = { "page.levelsGained==0" }, voice = "terse" },
    },
}))
