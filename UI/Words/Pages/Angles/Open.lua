-- Open: a page's first sentences (no who). Where and when the session was,
-- and how far my own levels moved.
--
-- scene facts (page.* plus)
--   newZones          zones this character entered for the first time today
--                     (a list, a subset of page.zones)
--   returnZone        a zone I came back to after a long time away
--   returnDays        days since I was last there (30+)
--
-- climb facts (page.* plus)
--   page.levelsGained levels gained this session (1+)
--   milestone         a round level reached today (10, 20, ...)
--   reachedCap        I reached the level cap
--   levelsToCap       levels left to the cap (0 or nil at the cap)
--
-- Tags said through page facts are tracked per page, shared with the
-- closer, the quiet line and the crowd, so a fact the opener says (the
-- zones, the hour, the level I ended at) is not said again by them.
--
-- Slots declared here
--   {open_zone}       the session's zone, when there was only one
--   {open_zones}      the session's zones as a list, when there were several
--   {open_first}      the first zone, when there were several
--   {open_last}       the last zone, when there were several and it isn't
--                     the new or returned-to zone (those get their own words)
--   {open_nzones}     how many zones, in words, when there were three or more
--   {open_rest}       the zones that were neither new nor returned to
--   {open_decade:f}   a round level as its decade: thirties, forties
--   guards, which write nothing and drop the sentence when untrue:
--   {open_single} {open_multi}      one zone / several zones
--   {open_allnew} {open_somenew}    every zone was new / some, not all
--   {open_atmile} {open_pastmile}   levelEnd is the milestone / past it

local addonName, ns = ...

local Pages = ns.Pages
local Words = Pages.Words

Pages.Angle("open", { order = { "scene", "climb" },
    about = "a page's first sentences: where, when, and my levels" })

--------------------------------------------------------------------------
-- Slots
--------------------------------------------------------------------------

local function Zones(env)
    local page = env.f.page
    local z = page and page.zones
    if type(z) ~= "table" or #z == 0 then return nil end
    return z
end

local function Has(list, v)
    if type(list) ~= "table" then return false end
    for i = 1, #list do if list[i] == v then return true end end
    return false
end

local function ZoneSlot(name, says, fn)
    Pages.Slot(name, {
        needs = function() return { "page.zones" } end,
        says = function() return says end,
        fn = function(env)
            local z = Zones(env)
            if z then return fn(z, env.f) end
        end,
    })
end

local ALL = { "page.zones", "page.zoneFirst", "page.zoneLast" }

ZoneSlot("open_zone", ALL, function(z) if #z == 1 then return z[1] end end)
ZoneSlot("open_zones", ALL, function(z) if #z >= 2 then return Pages.Lang.List(z) end end)
ZoneSlot("open_first", { "page.zones", "page.zoneFirst" }, function(z) if #z >= 2 then return z[1] end end)
ZoneSlot("open_last", { "page.zoneLast" }, function(z, f)
    local last = z[#z]
    if #z < 2 or last == z[1] or last == f.returnZone or Has(f.newZones, last) then return nil end
    return last
end)
-- The zones that were neither new today nor the one I returned to.
ZoneSlot("open_rest", ALL, function(z, f)
    local rest = {}
    for i = 1, #z do
        if z[i] ~= f.returnZone and not Has(f.newZones, z[i]) then rest[#rest + 1] = z[i] end
    end
    if #rest > 0 then return Pages.Lang.List(rest) end
end)
ZoneSlot("open_nzones", { "open.nzones" }, function(z) if #z >= 3 then return Pages.Lang.Num(#z) end end)

local DECADES = { [20] = "twenties", [30] = "thirties", [40] = "forties", [50] = "fifties",
    [60] = "sixties", [70] = "seventies", [80] = "eighties", [90] = "nineties" }
Pages.Format("open_decade", function(v) return type(v) == "number" and DECADES[v] or nil end)

-- A guard writes nothing: it lets the sentence through when its test holds.
local function Guard(name, needs, test)
    Pages.Slot(name, {
        needs = function() return needs end,
        says = function() return {} end,
        fn = function(env)
            local ok = test(env.f, env.f.page or {})
            if ok then return "" end
        end,
    })
end

Guard("open_single", { "page.zones" }, function(f, page) return type(page.zones) == "table" and #page.zones == 1 end)
Guard("open_multi", { "page.zones" }, function(f, page) return type(page.zones) == "table" and #page.zones >= 2 end)
Guard("open_allnew", { "newZones", "page.zones" }, function(f, page)
    for _, z in ipairs(page.zones or {}) do if not Has(f.newZones, z) then return false end end
    return true
end)
Guard("open_somenew", { "newZones", "page.zones" }, function(f, page)
    local new, old = 0, 0
    for _, z in ipairs(page.zones or {}) do
        if Has(f.newZones, z) then new = new + 1 else old = old + 1 end
    end
    return new > 0 and old > 0
end)
Guard("open_atmile", { "milestone", "page.levelEnd" }, function(f, page) return f.milestone == page.levelEnd end)
Guard("open_pastmile", { "milestone", "page.levelEnd" }, function(f, page)
    return type(f.milestone) == "number" and type(page.levelEnd) == "number" and page.levelEnd > f.milestone
end)

--------------------------------------------------------------------------
-- Shared page tags
--------------------------------------------------------------------------
--
-- {today} and {part} say nothing of their own, so two pieces could both
-- name the hour ("Tonight, I spent the evening..."); and a guard such as
-- "page.solo" or "page.seconds<2700" says nothing either. Share() adds the
-- page tags these pieces express, so the same thing is never said twice
-- in a sentence, nor again by the closer.

local KINDS = { "stems", "clauses", "fragments", "tails", "wholes" }
local TEXT_TAGS = { ["{today"] = "page.part", ["{part"] = "page.part" }
-- Guards that are also claims ("a short session", "on my own"). A guard
-- that only keeps the wording true ("spent the evening" needs an hour)
-- is left out, so it doesn't block a duration elsewhere in the sentence.
local NEED_TAGS = {
    ["page.solo"] = "page.solo",
    ["page.seconds<2400"] = "page.seconds", ["page.seconds<2700"] = "page.seconds",
    ["page.seconds>=10800"] = "page.seconds", ["page.seconds>=5400"] = "page.seconds",
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

local function Share(spec)
    for _, kind in ipairs(KINDS) do
        local list = spec[kind] or {}
        for i = 1, #list do
            local p = list[i]
            if type(p) == "string" then p = { p }; list[i] = p end
            local says = {}
            for _, t in ipairs(p.says or {}) do says[#says + 1] = t end
            for find, tag in pairs(TEXT_TAGS) do
                if p[1]:find(find, 1, true) then says[#says + 1] = tag end
            end
            for _, need in ipairs(p.needs or {}) do
                if NEED_TAGS[need] then says[#says + 1] = NEED_TAGS[need] end
            end
            -- naming a new or returned-to zone counts as naming the zones,
            -- so the closer doesn't name the same one again
            if p[1]:find(":newZones}", 1, true) or p[1]:find(":returnZone}", 1, true) then
                says[#says + 1] = "page.zoneLast"
            end
            Moods(p[1], says)
            if #says > 0 then p.says = says end
        end
    end
    return spec
end

--------------------------------------------------------------------------
-- scene: where and when
--------------------------------------------------------------------------
--
-- New and returned-to zones are news, so their pieces carry a bonus that
-- keeps the plain lines out of the draw on those pages. "Spent the
-- evening" and "all evening" need an hour or more of play behind them.

local NEWS = 0.75
-- PUNCT: a stem that spans the session ("For two hours, ") and a clause
-- that happens at a moment ("I went back to Duskwood") don't meet.
-- NEG: a negative clause ("I didn't leave Duskwood") and a negative tail
-- (", without grouping once") don't either.
local PUNCT, NEG = "open.punct", "open.neg"

Words("open", "scene", Share({
    must = { "page.zones" },

    stems = {
        "{today.cap}, ",
        { "This {part}, ", needs = { "page.part~=night" } },
        { "Late {today}, ", needs = { "page.part==night" } },
        { "Early {today}, ", needs = { "page.part==morning" } },
        { "For {dur:page.seconds} {today}, ", says = { PUNCT } },
        { "{dur.cap:page.seconds} {today}: ", says = { PUNCT } },
        { "In {dur:page.seconds} of play, ", says = { PUNCT } },
        { "After logging on {today}, ", says = { "open.logon", "open.dangle" } },
        { "In a short session {today}, ", needs = { "page.seconds<2700" } },
        { "Over a long {part}, ", needs = { "page.seconds>=10800" }, says = { PUNCT } },
        { "On my own {today}, ", needs = { "page.solo" }, says = { "open.dangle" } },
        { "Alone for {dur:page.seconds}, ", needs = { "page.solo" }, says = { "open.dangle", PUNCT } },
        { "With the {part} to myself, ", needs = { "page.solo" }, says = { "open.dangle" }, voice = "warm" },
        { "Settling in for the {part}, ", needs = { "page.seconds>=3600" }, says = { "open.dangle" }, voice = "warm" },
        { "Short and sweet {today}: ", needs = { "page.seconds<2700" }, voice = "warm" },
        { "Another {part}, and ", voice = "wry" },
        { "Just {dur:page.seconds} {today}, and ", needs = { "page.seconds<2400" }, voice = "wry" },
        { "For better or worse, ", voice = "wry" },
        { "Out of sheer habit, ", voice = "wry" },
        { "Against my better judgement, ", needs = { "page.seconds>=10800" }, says = { "page.seconds" }, voice = "wry" },
        { "{part.cap}: ", voice = "terse" },
        { "{dur.cap:page.seconds}, solo: ", needs = { "page.solo" }, voice = "terse" },
        { "Long session {today}: ", needs = { "page.seconds>=10800" }, voice = "terse" },
    },

    clauses = {
        -- one zone
        { "I spent the {part} in {open_zone}", needs = { "page.seconds>=3600" } },
        { "I stayed in {open_zone} the whole time", says = { "open.whole" } },
        { "I didn't leave {open_zone}", says = { NEG } },
        "I kept to {open_zone}",
        { "it was {open_zone} from start to finish", says = { "open.whole", "open.dangle" } },
        "I put in {dur:page.seconds} in {open_zone}",
        { "{dur:page.seconds} went by in {open_zone}", says = { "open.dangle" } },
        { "I spent the {part} alone in {open_zone}", needs = { "page.solo", "page.seconds>=3600" } },
        { "I never made it out of {open_zone}", says = { NEG }, voice = "wry" },
        { "{open_zone} had me for the whole {part}", needs = { "page.seconds>=5400" }, says = { "open.whole", "open.dangle" }, voice = "wry" },
        { "I settled into {open_zone} for the {part}", needs = { "page.seconds>=3600" }, voice = "warm" },
        { "I gave the {part} over to {open_zone}", needs = { "page.seconds>=3600" }, voice = "warm" },
        { "it was {open_zone}, all of it", says = { "open.whole", "open.dangle" }, voice = "terse" },
        -- several zones
        { "I spent the {part} between {open_zones}", needs = { "page.seconds>=3600" } },
        "I went from {open_first} to {open_last}",
        "I worked my way from {open_first} to {open_last}",
        "I moved between {open_zones}",
        "I put in {dur:page.seconds} between {open_zones}",
        { "my {part} took in {open_nzones} zones: {open_zones}", says = { "open.dangle" }, final = true },
        { "I went solo from {open_first} to {open_last}", needs = { "page.solo" } },
        "I set out from {open_first}",
        { "I drifted from {open_first} to {open_last}", voice = "warm" },
        { "I wandered between {open_zones}", voice = "warm" },
        { "I bounced between {open_zones}", voice = "wry" },
        { "I got around: {open_zones}", voice = "wry", final = true },
        { "it was {open_zones}", says = { "open.dangle" }, voice = "terse" },
        -- new ground
        { "I set foot in {list:newZones} for the first time", needs = { "newZones" }, says = { PUNCT, "page.zones" }, bonus = NEWS },
        { "I got my first look at {list:newZones}", needs = { "newZones" }, says = { PUNCT, "page.zones" }, bonus = NEWS },
        { "I spent the {part} somewhere new to me: {list:newZones}", needs = { "newZones", "page.seconds>=3600" }, says = { "page.zones" }, bonus = NEWS, final = true },
        { "I wandered into {list:newZones}, which I'd never seen before", needs = { "newZones" }, says = { PUNCT, "page.zones" }, bonus = NEWS, final = true },
        { "besides {open_rest}, I got my first look at {list:newZones}", needs = { "newZones" }, says = { PUNCT }, bonus = NEWS },
        { "I finally saw {list:newZones} with my own eyes", needs = { "newZones" }, says = { PUNCT, "page.zones" }, bonus = NEWS, voice = "warm" },
        { "my map grew a little: {list:newZones}", needs = { "newZones" }, says = { PUNCT, "page.zones", "open.dangle" }, bonus = NEWS, voice = "wry", final = true },
        -- an old haunt
        { "I was back in {v:returnZone} for the first time in {days:returnDays}", needs = { "returnZone" }, says = { PUNCT, "page.zones" }, bonus = NEWS },
        { "I returned to {v:returnZone} after {days:returnDays} away", needs = { "returnZone" }, says = { PUNCT, "page.zones" }, bonus = NEWS },
        { "I went back to {v:returnZone}", needs = { "returnZone" }, says = { PUNCT, "page.zones" }, bonus = NEWS - 0.5 },
        { "I found my way back to {v:returnZone}", needs = { "returnZone" }, says = { PUNCT, "page.zones" }, bonus = NEWS, voice = "warm" },
        { "{v:returnZone} saw me again for the first time in {days:returnDays}", needs = { "returnZone" }, says = { PUNCT, "page.zones", "open.dangle" }, bonus = NEWS, voice = "wry" },
    },

    fragments = {
        "{part.a.cap} in {open_zone}",
        { "{open_zone}, all {part}", needs = { "page.seconds>=5400" }, says = { "open.whole" } },
        "{dur.cap:page.seconds} in {open_zone}",
        "{dur.cap:page.seconds} between {open_zones}",
        "From {open_first} to {open_last}",
        { "{open_zones}, in that order", final = true },
        "{open_first} to start, {open_last} by the end",
        { "{part.a.cap} on the move: {open_zones}", final = true },
        { "A long {part} in {open_zone}", needs = { "page.seconds>=10800" } },
        { "A short session in {open_zone}", needs = { "page.seconds<2700" } },
        { "A solo {part} between {open_zones}", needs = { "page.solo" } },
        { "First time in {list:newZones}", needs = { "newZones" }, says = { "page.zones" }, bonus = NEWS },
        { "Somewhere new {today}: {list:newZones}", needs = { "newZones" }, says = { "page.zones" }, bonus = NEWS, final = true },
        { "Back in {v:returnZone} after {days:returnDays}", needs = { "returnZone" }, says = { "page.zones" }, bonus = NEWS },
        { "Back to {v:returnZone}, at last", needs = { "returnZone" }, says = { "page.zones" }, bonus = NEWS, voice = "warm", final = true },
        { "{part.a.cap} well spent in {open_zone}", needs = { "page.seconds>=3600" }, voice = "warm" },
        { "{open_zone}, and nowhere else", says = { "open.whole" }, voice = "wry" },
        { "{open_zone}, start to finish", says = { "open.whole" }, voice = "terse" },
        { "Alone in {open_zone}", needs = { "page.solo" }, voice = "terse" },
        { "Solo, {open_first} to {open_last}", needs = { "page.solo" }, voice = "terse" },
        { "New ground: {list:newZones}", needs = { "newZones" }, says = { "page.zones" }, bonus = NEWS, voice = "terse", final = true },
    },

    tails = {
        ", {dur:page.seconds} in all",
        { " in {dur:page.seconds} of play", says = { PUNCT, NEG, "open.dangle", "open.whole" } },
        { ", all {part}", needs = { "page.seconds>=5400" }, says = { "open.whole" } },
        { ", on my own", needs = { "page.solo" } },
        { ", without grouping once", needs = { "page.solo" }, says = { NEG } },
        ", ending up in {open_last}",
        { " and finished in {open_last}" },
        { ", in a short session", needs = { "page.seconds<2700" } },
        { ", over a long session", needs = { "page.seconds>=10800" } },
        { ", all of it new ground to me{open_allnew}", needs = { "newZones" }, bonus = NEWS },
        { ", some of it ground I'd never covered before{open_somenew}", needs = { "newZones" }, bonus = NEWS },
        { ", my first time there{open_allnew}{open_single}", needs = { "newZones" }, bonus = NEWS },
        { ", a zone I'd never set foot in before{open_allnew}{open_single}", needs = { "newZones" }, bonus = NEWS },
        { ", my first time back there in {days:returnDays}{open_single}", needs = { "returnZone" }, bonus = NEWS },
        { ", back after {days:returnDays} away{open_single}", needs = { "returnZone" }, bonus = NEWS },
        { ", in no hurry at all", voice = "warm" },
        { ", at my own pace", voice = "warm" },
        { ", which suited me fine", voice = "warm" },
        { ", taking the long way where I could", needs = { "page.seconds>=3600" }, voice = "warm" },
        { ", for reasons that made sense at the time", voice = "wry" },
        { ", more or less on purpose", voice = "wry" },
        { ", solo", needs = { "page.solo" }, voice = "terse" },
    },

    wholes = {
        { "I spent {today} in {open_zone}.", needs = { "page.seconds>=3600" } },
        "{part.a.cap} in {open_zone}, {dur:page.seconds} of it.",
        "I logged on {today} and never left {open_zone}.",
        "{today.cap} took me from {open_first} to {open_last}.",
        "{today.cap} was spent between {open_zones}.",
        "I spent {dur:page.seconds} {today} between {open_zones}.",
        "It was {open_zone} {today}, start to finish.",
        "I started the {part} in {open_first} and finished it in {open_last}.",
        "{dur.cap:page.seconds} {today}, all of it in {open_zone}.",
        "I logged on in {open_first} {today}. By the end I was in {open_last}.",
        "{today.cap} I covered {open_nzones} zones: {open_zones}.",
        "{dur.cap:page.seconds} {today}, starting in {open_first} and ending in {open_last}.",
        "Where I was {today}: {open_zones}.",
        "One zone {today}, {open_zone}, and {dur:page.seconds} in it.",
        -- new ground
        { "{today.cap} I set foot in {list:newZones} for the first time.", needs = { "newZones" }, says = { "page.zones" }, bonus = NEWS },
        { "New ground {today}: {list:newZones}.", needs = { "newZones" }, says = { "page.zones" }, bonus = NEWS },
        { "I'd never been to {list:newZones} before {today}.", needs = { "newZones" }, says = { "page.zones" }, bonus = NEWS },
        { "I spent {today} in {open_zone}, a zone I'd never set foot in before{open_allnew}.", needs = { "newZones", "page.seconds>=3600" }, bonus = NEWS },
        { "Besides {open_rest}, {today} brought my first look at {list:newZones}.", needs = { "newZones" }, bonus = NEWS },
        { "{list:newZones}, for the first time ever, and {dur:page.seconds} of it{open_allnew}.", needs = { "newZones" }, says = { "page.zones" }, bonus = NEWS },
        { "{today.cap} I finally got to see {list:newZones}.", needs = { "newZones" }, says = { "page.zones" }, bonus = NEWS, voice = "warm" },
        { "Somewhere new {today}: {list:newZones}. I took my time over it.", needs = { "newZones", "page.seconds>=3600" }, says = { "page.zones" }, bonus = NEWS, voice = "warm" },
        { "I ran out of excuses and finally went to {list:newZones} {today}.", needs = { "newZones" }, says = { "page.zones" }, bonus = NEWS, voice = "wry" },
        { "New on the map {today}: {list:newZones}.", needs = { "newZones" }, says = { "page.zones" }, bonus = NEWS, voice = "terse" },
        -- an old haunt
        { "I went back to {v:returnZone} {today}, the first time in {days:returnDays}.", needs = { "returnZone" }, says = { "page.zones" }, bonus = NEWS },
        { "{days.cap:returnDays} since I was last in {v:returnZone}, and {today} I was back.", needs = { "returnZone" }, says = { "page.zones" }, bonus = NEWS },
        { "Back to {v:returnZone} {today}. The last time I was there was {ago:returnDays}.", needs = { "returnZone" }, says = { "page.zones" }, bonus = NEWS },
        { "Besides {open_rest}, {today} took me back to {v:returnZone}, where I hadn't been in {days:returnDays}.", needs = { "returnZone" }, bonus = NEWS },
        { "After {days:returnDays} away, I found myself back in {v:returnZone} {today}.", needs = { "returnZone" }, says = { "page.zones" }, bonus = NEWS, voice = "warm" },
        { "It was good to be back in {v:returnZone} {today}; it had been {days:returnDays}.", needs = { "returnZone" }, says = { "page.zones" }, bonus = NEWS, voice = "warm" },
        { "{v:returnZone} again, after {days:returnDays} away. I'd almost forgotten the place.", needs = { "returnZone" }, says = { "page.zones" }, bonus = NEWS, voice = "wry" },
        { "{v:returnZone} again, first time in {days:returnDays}.", needs = { "returnZone" }, says = { "page.zones" }, bonus = NEWS, voice = "terse" },
        -- the shape of the session
        { "I played alone {today}, in {open_zone}.", needs = { "page.solo" } },
        { "A solo {part} in {open_zone}.", needs = { "page.solo" } },
        { "A short session {today}: {dur:page.seconds} in {open_zone}.", needs = { "page.seconds<2700" } },
        { "A short session {today}, {open_first} and then {open_last}.", needs = { "page.seconds<2700" } },
        { "A long {part}: {dur:page.seconds}, from {open_first} to {open_last}.", needs = { "page.seconds>=10800" } },
        { "{today.cap} I settled into {open_zone} and stayed there.", voice = "warm" },
        { "I gave the whole {part} to {open_zone}, and didn't regret it.", needs = { "page.seconds>=3600" }, voice = "warm" },
        { "{today.cap} was a slow wander from {open_first} to {open_last}.", needs = { "page.seconds>=3600" }, voice = "warm" },
        { "{dur.cap:page.seconds} in {open_zone}, and I enjoyed it.", voice = "warm" },
        { "{part.a.cap} to myself in {open_zones}.", needs = { "page.solo" }, voice = "warm" },
        { "{open_zones} {today}. I do get around.", voice = "wry" },
        { "{open_zone} had me all {part}; I didn't try very hard to leave.", needs = { "page.seconds>=5400" }, voice = "wry" },
        { "{today.cap}'s grand tour: {open_zone}. Just {open_zone}.", voice = "wry" },
        { "Barely {dur:page.seconds} {today}, and I didn't make it past {open_zone}.", needs = { "page.seconds<2400" }, voice = "wry" },
        { "{today.cap} I set out from {open_first} and somehow ended up in {open_last}.", voice = "wry" },
        { "{part.cap}. {open_zone}. {dur.cap:page.seconds}.", voice = "terse" },
        { "{open_first} to {open_last}, {dur:page.seconds}.", voice = "terse" },
        { "{open_zones}. {dur.cap:page.seconds}.", voice = "terse" },
        { "{open_zone}, {today}.", voice = "terse" },
        { "Just me {today}, from {open_first} to {open_last}.", needs = { "page.solo" }, voice = "terse" },
    },
}))

--------------------------------------------------------------------------
-- climb: my levels
--------------------------------------------------------------------------
--
-- Every clause, fragment and whole says "open.climb", the point of the
-- move; stems and tails add to it. A milestone line names the round level,
-- so it isn't paired with a piece that names the same level again; at the
-- cap, the cap's own lines take over from the milestone's.

local function Climb(spec)
    for _, kind in ipairs({ "clauses", "fragments", "wholes" }) do
        for i, p in ipairs(spec[kind] or {}) do
            if type(p) == "string" then p = { p }; spec[kind][i] = p end
            local says = { "open.climb" }
            for _, t in ipairs(p.says or {}) do says[#says + 1] = t end
            p.says = says
        end
    end
    for _, kind in ipairs({ "stems", "clauses", "fragments", "tails", "wholes" }) do
        for i, p in ipairs(spec[kind] or {}) do
            if type(p) == "string" then p = { p }; spec[kind][i] = p end
            local says = p.says or {}
            local text = p[1]
            -- "up to 11, up from 10": one "up" per sentence
            if text:find("%f[%a][Uu]p%f[%A]") then says[#says + 1] = "open.up" end
            -- the cap and a decade both say the level I ended on
            local cap, decade = false, text:find("open_decade", 1, true)
            for _, n in ipairs(p.needs or {}) do if n == "reachedCap" then cap = true end end
            if cap or decade then says[#says + 1] = "page.levelEnd" end
            p.says = says
        end
    end
    return Share(spec)
end

local MILE = { "milestone", "!reachedCap" }
-- FEEL: one feeling per sentence. LW: "levels" said once ("As for levels,
-- I gained a level" reads as a stutter).
local FEEL, LW = "open.feel", "open.lw"
-- A milestone or the cap is the news of the move: with these bonuses a
-- plain line can't win on a page that has one.
local MB, CB = 0.5, 1
local AT = { "page.levelEnd", "milestone" }  -- what a line at the milestone says

Words("open", "climb", Climb({
    needs = { "page.levelsGained>=1" },
    must = { "open.climb" },

    stems = {
        "In the end, ",
        "Along the way, ",
        "Somewhere in all that, ",
        { "As for levels, ", says = { LW } },
        { "On the levelling front, ", says = { LW } },
        "In {dur:page.seconds}, ",
        "Before I stopped, ",
        { "From level {lvl:page.levelStart}, ", says = { "open.capword" } },
        { "{levels.cap:page.levelsGained} in all: ", needs = { "page.levelsGained>=2" } },
        { "On my own, ", needs = { "page.solo" } },
        { "In a productive session, ", needs = { "page.levelsGained>=3" } },
        { "[Bit by bit|Little by little], ", voice = "warm" },
        { "Happily, ", says = { FEEL }, voice = "warm" },
        { "To my quiet satisfaction, ", says = { FEEL }, voice = "warm" },
        { "And somewhere in the middle of it, ", voice = "warm" },
        { "Slowly but surely, ", needs = { "page.levelsGained==1", "!reachedCap" }, voice = "warm" },
        { "For the record, ", voice = "wry" },
        { "Not bad going: ", needs = { "page.levelsGained>=2" }, says = { FEEL }, voice = "wry" },
        { "Against all odds, ", needs = { "page.levelsGained>=3" }, says = { FEEL }, voice = "wry" },
        { "Progress: ", voice = "terse" },
        { "Solo: ", needs = { "page.solo" }, voice = "terse" },
    },

    clauses = {
        { "I gained {levels:page.levelsGained}", says = { LW } },
        { "I picked up {levels:page.levelsGained}", says = { LW } },
        "I went from {lvl:page.levelStart} to {lvl:page.levelEnd}",
        "I climbed from level {lvl:page.levelStart} to {lvl:page.levelEnd}",
        "I made level {lvl:page.levelEnd}",
        "I reached level {lvl:page.levelEnd}",
        { "I levelled up to {lvl:page.levelEnd}", says = { LW } },
        { "I finished {levels:page.levelsGained} higher than I started", says = { "page.levelStart" } },
        { "I'm level {lvl:page.levelEnd} now", bonus = -0.25, final = true },
        { "I gained {levels:page.levelsGained} and finished on {lvl:page.levelEnd}", says = { LW }, final = true },
        { "I edged up to level {lvl:page.levelEnd}", needs = { "page.levelsGained==1" } },
        { "I managed one more level", needs = { "page.levelsGained==1", "!reachedCap" }, says = { "page.levelsGained" } },
        { "the levels kept coming: {num:page.levelsGained} of them", needs = { "page.levelsGained>=3" }, final = true },
        { "I gained {levels:page.levelsGained} in one sitting", needs = { "page.levelsGained>=3" } },
        { "I gained {levels:page.levelsGained} without grouping once", needs = { "page.solo" } },
        { "level {lvl:page.levelEnd} came round", voice = "warm" },
        { "I eased my way up to {lvl:page.levelEnd}", voice = "warm" },
        { "the levels came gently, {num:page.levelsGained} of them", needs = { "page.levelsGained>=2" }, voice = "warm", final = true },
        { "I somehow gained {levels:page.levelsGained}", needs = { "page.levelsGained>=2" }, says = { LW }, voice = "wry" },
        { "my level went up, which is the general idea", voice = "wry", final = true },
        { "I crept up to {lvl:page.levelEnd}", needs = { "page.levelsGained==1" }, voice = "warm" },
        { "I scraped together one more level", needs = { "page.levelsGained==1" }, says = { "page.levelsGained" }, voice = "wry" },
        { "the experience bar filled {times:page.levelsGained}", needs = { "page.levelsGained>=2" }, voice = "wry" },
        { "I dinged {lvl:page.levelEnd}", voice = "wry" },
        { "I dinged {lvl:page.levelEnd}", voice = "terse" },
        { "I made {lvl:page.levelEnd}", voice = "terse" },
        { "I hit the cap", needs = { "reachedCap" }, says = { "open.capword" }, bonus = CB, voice = "terse" },
        -- a round number
        { "I reached level {lvl:milestone}{open_atmile}", needs = MILE, bonus = MB, says = AT },
        { "I hit {lvl:milestone}, a round number at last{open_atmile}", needs = MILE, bonus = MB, says = AT, final = true },
        { "I made it into the {open_decade:milestone}", needs = MILE, bonus = MB },
        { "I crossed {lvl:milestone} on the way to {lvl:page.levelEnd}{open_pastmile}", needs = MILE, bonus = MB },
        { "level {lvl:milestone} came and went{open_pastmile}", needs = MILE, bonus = MB },
        { "I passed {lvl:milestone}{open_pastmile} and kept going", needs = MILE, bonus = MB, final = true },
        { "level {lvl:milestone} finally came{open_atmile}", needs = MILE, bonus = MB, says = AT, voice = "warm" },
        { "I'm into my {open_decade:milestone}, so to speak", needs = MILE, bonus = MB, voice = "wry", final = true },
        { "I hit {lvl:milestone}{open_atmile}", needs = MILE, bonus = MB, says = AT, voice = "terse" },
        -- the cap
        { "I reached the level cap", needs = { "reachedCap" }, says = { "open.capword" }, bonus = CB },
        { "I hit {lvl:page.levelEnd}, the level cap", needs = { "reachedCap" }, says = { "open.capword" }, bonus = CB },
        { "I reached level {lvl:page.levelEnd}, as high as it goes", needs = { "reachedCap" }, bonus = CB, final = true },
        { "I made it all the way to {lvl:page.levelCap}", needs = { "reachedCap" }, says = { "open.capword" }, bonus = CB },
        { "I finally reached the cap", needs = { "reachedCap" }, says = { "open.capword" }, bonus = CB, voice = "warm" },
        { "I ran out of levels to gain", needs = { "reachedCap" }, bonus = CB, voice = "wry" },
    },

    fragments = {
        "Level {lvl:page.levelEnd} now",
        "From {lvl:page.levelStart} to {lvl:page.levelEnd}",
        "Up to {lvl:page.levelEnd}",
        "Up {levels:page.levelsGained}, to {lvl:page.levelEnd}",
        { "{levels.cap:page.levelsGained} gained", needs = { "page.levelsGained>=2", "!reachedCap" } },
        { "Another level: {lvl:page.levelEnd}", needs = { "page.levelsGained==1" }, final = true },
        { "One more level", needs = { "page.levelsGained==1", "!reachedCap" }, says = { "page.levelsGained" } },
        { "{levels.cap:page.levelsGained} closer to the cap", needs = { "levelsToCap", "levelsToCap<=10" } },
        { "{levels.cap:page.levelsGained} in a single session", needs = { "page.levelsGained>=3" } },
        { "{levels.cap:page.levelsGained} in {dur:page.seconds}", needs = { "page.levelsGained>=2" } },
        { "Level {lvl:milestone} at last{open_atmile}", needs = MILE, bonus = MB, says = AT },
        { "Into the {open_decade:milestone}", needs = MILE, bonus = MB },
        { "Past {lvl:milestone}{open_pastmile}", needs = MILE, bonus = MB },
        { "Level {lvl:page.levelEnd}, the cap", needs = { "reachedCap" }, says = { "open.capword" }, bonus = CB },
        { "The level cap, at last", needs = { "reachedCap" }, says = { "open.capword" }, bonus = CB },
        { "Level {lvl:page.levelEnd}, and nowhere higher to go", needs = { "reachedCap" }, bonus = CB, final = true },
        { "A level, and a welcome one", needs = { "page.levelsGained==1" }, says = { "page.levelsGained" }, voice = "warm", final = true },
        { "A good session for levels", needs = { "page.levelsGained>=2" }, voice = "warm", final = true },
        { "Level {lvl:page.levelEnd}, and very welcome", voice = "warm", final = true },
        { "Level {lvl:page.levelEnd}, against expectations", voice = "wry", final = true },
        { "A level, nothing more", needs = { "page.levelsGained==1" }, says = { "page.levelsGained" }, voice = "wry", final = true },
        { "Dinged {lvl:page.levelEnd}", voice = "wry" },
        { "Dinged {lvl:page.levelEnd}", voice = "terse" },
        { "Level {lvl:page.levelEnd}", voice = "terse" },
        { "Level {lvl:milestone}, finally{open_atmile}", needs = MILE, bonus = MB, says = AT, voice = "terse" },
        { "Cap reached", needs = { "reachedCap" }, says = { "open.capword" }, bonus = CB, voice = "terse" },
        { "Up {levels:page.levelsGained}", voice = "terse" },
    },

    tails = {
        ", from {lvl:page.levelStart} to {lvl:page.levelEnd}",
        ", which puts me at {lvl:page.levelEnd}",
        ", up from {lvl:page.levelStart}",
        { ", {levels:page.levelsGained} in all", needs = { "page.levelsGained>=2" } },
        { ", {levels:levelsToCap} short of the cap", needs = { "levelsToCap", "levelsToCap<=10" } },
        { ", with {levels:levelsToCap} left before the cap", needs = { "levelsToCap", "levelsToCap<=10" } },
        { ", and the cap is only {levels:levelsToCap} away now", needs = { "levelsToCap", "levelsToCap<=3" }, says = { "open.near" }, bonus = MB },
        { ", which leaves just one level to the cap", needs = { "levelsToCap==1" }, says = { "levelsToCap", "open.near" }, bonus = MB },
        { ", on my own", needs = { "page.solo" } },
        { ", which makes level {lvl:milestone}, a round number at last{open_atmile}", needs = MILE, bonus = MB, says = AT },
        { ", passing {lvl:milestone} on the way{open_pastmile}", needs = MILE, bonus = MB },
        { ", which takes me into the {open_decade:milestone}", needs = MILE, bonus = MB, says = { "page.levelEnd" } },
        { ", which puts me at the level cap", needs = { "reachedCap" }, bonus = CB, says = { "open.capword" } },
        { ", which I was glad of", says = { FEEL }, voice = "warm" },
        { ", and I'm pleased with that", says = { FEEL }, voice = "warm" },
        { ", and about time", says = { FEEL }, voice = "wry" },
        { ", not that I was counting", says = { FEEL }, voice = "wry" },
        { ", which I'll take", needs = { "page.levelsGained==1" }, says = { FEEL }, voice = "wry" },
        { ", slow going", needs = { "page.levelsGained==1", "page.seconds>=10800" }, says = { "page.seconds" }, voice = "terse" },
        { ", solo", needs = { "page.solo" }, voice = "terse" },
    },

    wholes = {
        "I gained {levels:page.levelsGained}, from {lvl:page.levelStart} to {lvl:page.levelEnd}.",
        "Level {lvl:page.levelEnd} by the end.",
        "I started at {lvl:page.levelStart} and finished at {lvl:page.levelEnd}.",
        "{levels.cap:page.levelsGained} along the way; I'm {lvl:page.levelEnd} now.",
        "I'm level {lvl:page.levelEnd} now, {levels:page.levelsGained} up on where I started.",
        "{levels.cap:page.levelsGained} more than when I logged on: level {lvl:page.levelEnd}.",
        "By the time I stopped I was level {lvl:page.levelEnd}.",
        "Levels came too: {lvl:page.levelStart} to {lvl:page.levelEnd}.",
        { "One level, {lvl:page.levelStart} to {lvl:page.levelEnd}.", needs = { "page.levelsGained==1" }, says = { "page.levelsGained" } },
        { "I gained {levels:page.levelsGained} in one sitting, which is a lot for me.", needs = { "page.levelsGained>=3" }, voice = "wry" },
        { "{levels.cap:page.levelsGained} in one go, which took me to {lvl:page.levelEnd}.", needs = { "page.levelsGained>=3" } },
        { "{levels.cap:page.levelsGained} in {dur:page.seconds}, and I'm {lvl:page.levelEnd} now.", needs = { "page.levelsGained>=2" } },
        { "I'm {lvl:page.levelEnd} now, with {levels:levelsToCap} to go before the cap.", needs = { "levelsToCap", "levelsToCap<=10" } },
        { "Level {lvl:page.levelEnd}. The cap is {levels:levelsToCap} away.", needs = { "levelsToCap", "levelsToCap<=10" } },
        { "Level {lvl:page.levelEnd}, and the cap is in sight now.", needs = { "levelsToCap", "levelsToCap<=3" }, says = { "open.near" }, bonus = MB },
        { "{levels.cap:page.levelsGained} closer to the cap, which is now only {levels:levelsToCap} off.", needs = { "levelsToCap", "levelsToCap<=5" }, says = { "open.near" }, bonus = MB },
        { "I gained {levels:page.levelsGained} on my own.", needs = { "page.solo" } },
        -- a round number
        { "I reached level {lvl:milestone}{open_atmile}.", needs = MILE, bonus = MB, says = AT },
        { "Level {lvl:milestone}, at last{open_atmile}.", needs = MILE, bonus = MB, says = AT },
        { "I hit {lvl:milestone}{open_atmile}. A round number is a round number.", needs = MILE, bonus = MB, says = AT },
        { "I passed {lvl:milestone}{open_pastmile} and finished on {lvl:page.levelEnd}.", needs = MILE, bonus = MB },
        { "I went from {lvl:page.levelStart} to {lvl:page.levelEnd}, past {lvl:milestone} on the way{open_pastmile}.", needs = MILE, bonus = MB },
        { "I'm in the {open_decade:milestone} now: level {lvl:page.levelEnd}.", needs = MILE, bonus = MB },
        { "Level {lvl:milestone}{open_atmile}. I'd been looking forward to that one.", needs = MILE, bonus = MB, says = AT, voice = "warm" },
        { "I reached {lvl:milestone}{open_atmile}, and it felt like an occasion.", needs = MILE, bonus = MB, says = AT, voice = "warm" },
        { "Level {lvl:milestone}{open_atmile}. I allowed myself a moment of smugness.", needs = MILE, bonus = MB, says = AT, voice = "wry" },
        { "I'm in my {open_decade:milestone} now, which sounds worse than it is.", needs = MILE, bonus = MB, voice = "wry" },
        { "Level {lvl:milestone}{open_atmile}. Round number.", needs = MILE, bonus = MB, says = AT, voice = "terse" },
        -- the cap
        { "I reached the level cap: {lvl:page.levelEnd}.", needs = { "reachedCap" }, says = { "open.capword" }, bonus = CB },
        { "Level {lvl:page.levelEnd}, the cap. There's nowhere higher to go.", needs = { "reachedCap" }, says = { "open.capword" }, bonus = CB },
        { "I made it to {lvl:page.levelEnd}, the highest level there is.", needs = { "reachedCap" }, bonus = CB },
        { "From {lvl:page.levelStart} to {lvl:page.levelEnd}, and {lvl:page.levelEnd} is the cap.", needs = { "reachedCap" }, says = { "open.capword" }, bonus = CB },
        { "I hit the cap. Level {lvl:page.levelEnd}, as far as it goes.", needs = { "reachedCap" }, says = { "open.capword" }, bonus = CB },
        { "Level {lvl:page.levelEnd}. The cap. I've wanted to write that for a long while.", needs = { "reachedCap" }, says = { "open.capword" }, bonus = CB, voice = "warm" },
        { "I reached the cap, {lvl:page.levelEnd}, and it hasn't quite sunk in.", needs = { "reachedCap" }, says = { "open.capword" }, bonus = CB, voice = "warm" },
        { "Every level from 1 to {lvl:page.levelEnd} is behind me now; I'm at the cap.", needs = { "reachedCap" }, says = { "open.capword" }, bonus = CB, voice = "warm" },
        { "Level {lvl:page.levelEnd}. No more levels to gain, so I suppose I'll have to find something else to complain about.", needs = { "reachedCap" }, bonus = CB, voice = "wry" },
        { "I reached the cap. The experience bar is gone, and I'm not sure what to do with my eyes.", needs = { "reachedCap" }, says = { "open.capword" }, bonus = CB, voice = "wry" },
        { "Level {lvl:page.levelEnd}. Cap.", needs = { "reachedCap" }, says = { "open.capword" }, bonus = CB, voice = "terse" },
        -- voice
        { "I gained {levels:page.levelsGained} along the way, and I'm glad of every one.", needs = { "page.levelsGained>=2" }, voice = "warm" },
        { "Level {lvl:page.levelEnd} now. It's coming along.", voice = "warm" },
        { "Level {lvl:page.levelEnd} came round, and I was pleased to see it.", voice = "warm" },
        { "I gained {levels:page.levelsGained}. Don't let it go to my head.", voice = "wry" },
        { "Somewhere in there I dinged {lvl:page.levelEnd}, which I'm counting as progress.", voice = "wry" },
        { "One level, up to {lvl:page.levelEnd}. I'll take it.", needs = { "page.levelsGained==1" }, says = { "page.levelsGained" }, voice = "wry" },
        { "From {lvl:page.levelStart} to {lvl:page.levelEnd}.", voice = "terse" },
        { "Up {levels:page.levelsGained}. Level {lvl:page.levelEnd} now.", voice = "terse" },
        { "Level {lvl:page.levelEnd}.", voice = "terse" },
    },
}))
