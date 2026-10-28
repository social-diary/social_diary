-- Crowd: people in numbers (no who). Counts of players turned into the
-- texture of the session ("a busy evening in the Barrens: I saw twenty-odd
-- players and grouped with three of them"), never a list of them.
--
-- others facts (page.* plus)
--   seen              players I saw nearby
--   newFaces          strangers I dealt with (grouped, traded, talked)
--   groupedWith       strangers I grouped with (part of newFaces)
--   busiestZone       the zone where I saw the most players
--   busiestSeen       players seen there
--   hostileSeen       players of the other faction seen
--
-- Seen counts come from sightings, and are rounded in the words ("twenty-
-- odd", "a dozen or so") rather than claimed exactly. Every clause, fragment
-- and whole says "crowd.others", the point of the move. Tags said through
-- page facts are shared with the opener, the closer and the quiet line.
--
-- Slots declared here
--   {crowd_about:f}   a seen count as a reader rounds it, before a plural
--                     noun: "a couple of", "a handful of", "a dozen or so",
--                     "twenty-odd", "over a hundred"
--   {crowd_n:f}       the same, standing alone ("a couple of them", "a
--                     handful", "twenty-odd")
--   {crowd_some:f}    a guard: f (a count of strangers) was fewer than seen
--   {crowd_some2} {crowd_all}   guards: grouped with fewer than all the new
--                     faces / with all of them (two or more)
--   {crowd_bz}        busiestZone, when the session had more than one zone
--                     (in a one-zone session it is simply where I was)

local addonName, ns = ...

local Pages = ns.Pages
local Words = Pages.Words

Pages.Angle("crowd", { order = { "others" },
    about = "people in numbers: how busy the session was" })

--------------------------------------------------------------------------
-- Slots
--------------------------------------------------------------------------

-- A seen count as a reader rounds it, standing alone: "a couple", "a
-- handful", "a dozen or so", "twenty-odd", "over a hundred".
local function Rough(n)
    local L = Pages.Lang
    if type(n) ~= "number" or n < 2 then return nil end
    if n == 2 then return "a couple" end
    if n <= 4 then return L.Num(n) end
    if n <= 7 then return "a handful" end
    if n <= 9 then return "eight or nine" end
    if n <= 14 then return "a dozen or so" end
    if n <= 17 then return "fifteen or so" end
    if n < 100 then
        local tens = math.floor(n / 10) * 10
        if n % 10 >= 7 then return "nearly " .. L.Num(tens + 10) end
        return L.Num(tens) .. "-odd"
    end
    if n < 150 then return "over a hundred" end
    return "well over a hundred"
end

-- The same before a plural noun: "a couple of players", "twenty-odd players".
local function About(n)
    local r = Rough(n)
    if r == "a couple" or r == "a handful" then return r .. " of" end
    return r
end

Pages.Format("crowd_about", function(v) return About(v) end)
Pages.Format("crowd_n", function(v) return Rough(v) end)

-- Guards on the strangers: grouped with fewer than all the new faces, or
-- all of them.
local function Faces(name, test)
    Pages.Slot(name, {
        needs = function() return { "groupedWith", "newFaces" } end,
        says = function() return {} end,
        fn = function(env)
            local g, n = env.f.groupedWith, env.f.newFaces
            if type(g) == "number" and type(n) == "number" and test(g, n) then return "" end
        end,
    })
end
Faces("crowd_some2", function(g, n) return g < n end)
Faces("crowd_all", function(g, n) return g == n and n >= 2 end)

-- A guard: writes nothing, and lets "...and grouped with three of them"
-- through only when that was fewer than all the players I saw.
Pages.Slot("crowd_some", {
    needs = function(args) return { args[1], "seen" } end,
    says = function() return {} end,
    fn = function(env, args)
        local n, seen = env.f[args[1]], env.f.seen
        if type(n) == "number" and type(seen) == "number" and n < seen then return "" end
    end,
})

Pages.Slot("crowd_bz", {
    needs = function() return { "busiestZone", "page.zones" } end,
    says = function() return { "busiestZone" } end,
    fn = function(env)
        local z = env.f.page and env.f.page.zones
        if type(z) ~= "table" or #z < 2 then return nil end
        return env.f.busiestZone
    end,
})

--------------------------------------------------------------------------
-- Tags
--------------------------------------------------------------------------
--
-- Adds the move's tag to every clause, fragment and whole, the hour for
-- {today}, and makes each count say its page twin (seen is page.seen,
-- newFaces is page.newFaces), so the crowd and the quiet line never both
-- count heads. A guard on a count ("seen>=20") says nothing: a "busy"
-- stem can still go with a clause that gives the number.

local KINDS = { "stems", "clauses", "fragments", "tails", "wholes" }
local CORE = { clauses = true, fragments = true, wholes = true }
local TWINS = { seen = "page.seen", newFaces = "page.newFaces" }
local NEED_TAGS = { ["page.solo"] = "page.solo" }

-- Feeling words said once per page, whichever angle says them: "glad of
-- the evening" in the closer after "glad of the quiet" in the quiet line.
local MOODS = { "glad", "enjoy", "content", "pleased", "lovely" }
local function Moods(text, says)
    local lower = text:lower()
    for _, w in ipairs(MOODS) do
        if lower:find(w, 1, true) then says[#says + 1] = "page.mood." .. w end
    end
end

local function Crowd(spec)
    for _, kind in ipairs(KINDS) do
        local list = spec[kind] or {}
        for i = 1, #list do
            local p = list[i]
            if type(p) == "string" then p = { p }; list[i] = p end
            local says = {}
            if CORE[kind] then says[1] = "crowd.others" end
            for _, t in ipairs(p.says or {}) do says[#says + 1] = t end
            local text = p[1]
            if text:find("{today", 1, true) then says[#says + 1] = "page.part" end
            if text:find("{part", 1, true) then says[#says + 1] = "crowd.part" end
            for fact, twin in pairs(TWINS) do
                if text:find(":" .. fact .. "}", 1, true) or text:find(":" .. fact .. ":", 1, true) then
                    says[#says + 1] = twin
                end
            end
            for _, need in ipairs(p.needs or {}) do
                if NEED_TAGS[need] then says[#says + 1] = NEED_TAGS[need] end
            end
            -- Roles (see below): a clause or fragment that isn't a head
            -- count says "crowd.nsc", and so does a stem or tail that wants
            -- one; the same for "crowd.ng" and a clause about grouping.
            local core = CORE[kind] and kind ~= "wholes"
            local edge = kind == "stems" or kind == "tails"
            if (core and not p.sc) or (edge and p.sc) then says[#says + 1] = "crowd.nsc" end
            if (core and not p.grp) or (edge and p.grp) then says[#says + 1] = "crowd.ng" end
            p.sc, p.grp = nil, nil
            Moods(text, says)
            p.says = says
        end
    end
    return spec
end

-- How busy. The seen counts are the planner's; "busy" wants a real crowd.
local BUSY = { "seen>=20" }
local QUIETISH = { "seen<=6" }
local GROUPED = { "groupedWith" }
-- The busiest zone is worth naming only with a few players in it, and
-- called crowded or busy only with a crowd.
local BZN = { "busiestSeen>=5" }
local BZC = { "busiestSeen>=10" }

-- Roles, so the pieces of one sentence agree:
--   sc = true    on a clause or fragment: it counts the players seen, so
--                "them" after it means those players. On a stem or tail: it
--                needs such a clause ("..., most of them in Ashenvale").
--   grp = true   on a clause or fragment: it is about grouping or dealing
--                with strangers. On a stem or tail: it needs one ("In good
--                company, ...").
--   D            a stem or tail that wants "I" as the subject, or a clause
--                that doesn't start with it
--   GROUP        says whom I grouped with or dealt with
--   SOLO         says I kept to myself, or that I dealt with some of them
--                (the two don't go together)
local D, GROUP, SOLO = "crowd.dangle", "crowd.group", "crowd.solo"

--------------------------------------------------------------------------
-- others: the crowd
--------------------------------------------------------------------------

Words("crowd", "others", Crowd({
    must = { "crowd.others" },

    stems = {
        "{today.cap}, ",
        "All told, ",
        "Over the {part}, ",
        { "Counting heads, ", sc = true },
        { "On a busy {part}, ", needs = BUSY, says = { "crowd.busy" } },
        { "On a crowded {part} in {v:busiestZone}, ", needs = { "busiestSeen>=15" }, says = { "crowd.busy", "crowd.part", "busiestZone" } },
        { "With the world out in force, ", needs = BUSY, says = { "crowd.busy", "crowd.out" } },
        { "Though I played alone, ", needs = { "seen>=5", "page.solo" }, says = { D, SOLO }, sc = true },
        { "With plenty of company about, ", needs = { "seen>=10" }, says = { D }, grp = true, voice = "warm" },
        { "In good company, ", needs = GROUPED, says = { D }, grp = true, voice = "warm" },
        { "Being sociable for once, ", needs = GROUPED, says = { D }, grp = true, voice = "wry" },
        { "Headcount: ", sc = true, voice = "terse" },
        { "Busy {today}: ", needs = BUSY, says = { "crowd.busy" }, voice = "terse" },
        { "For once in good company, ", needs = GROUPED, says = { D }, grp = true, voice = "wry" },
        { "Among so many strangers, ", needs = { "seen>=15", "page.diaryMet==0" }, says = { D, "page.diaryMet" }, grp = true, voice = "warm" },
    },

    clauses = {
        -- the crowd seen
        { "I saw {crowd_about:seen} other players", sc = true },
        { "I saw {crowd_about:seen} players about", sc = true },
        { "I passed {crowd_about:seen} players along the way", sc = true },
        { "there were {crowd_about:seen} other players about", says = { D }, sc = true },
        { "{crowd_about:seen} players crossed my path", says = { D }, sc = true },
        { "{crowd_about:seen} other players were out", says = { D, "crowd.out" }, sc = true },
        { "the world was busy: {crowd_about:seen} players", needs = BUSY, says = { "crowd.busy", D }, final = true },
        { "it was a busy {part}, with {crowd_about:seen} players about", needs = BUSY, says = { "crowd.busy", D }, sc = true },
        { "I was rarely alone, with {crowd_about:seen} players around", needs = BUSY, says = { "crowd.busy" }, sc = true },
        { "I was never short of company: {crowd_about:seen} players, near enough", needs = BUSY, says = { "crowd.busy" }, final = true },
        { "the roads were full", needs = BUSY, says = { "crowd.busy", D } },
        { "it was only me and {crowd_about:seen} others", needs = QUIETISH, says = { D }, sc = true },
        { "I saw just {crowd_about:seen} other players", needs = QUIETISH, sc = true },
        -- where it was busiest
        { "{crowd_bz} was the busiest, with {crowd_about:busiestSeen} players", needs = BZN, says = { D } },
        { "{crowd_bz} was where the crowd was", needs = BZC, says = { D } },
        { "most of the traffic was in {crowd_bz}", needs = BZC, says = { D } },
        { "{crowd_bz} was busier than the rest, with {crowd_about:busiestSeen} players", needs = BZN, says = { D, "crowd.busy" }, final = true },
        { "I saw {crowd_about:busiestSeen} players in {crowd_bz} alone", needs = BZN },
        { "{v:busiestZone} was crowded", needs = { "busiestSeen>=15" }, says = { "crowd.busy", D } },
        -- new faces and groups
        { "I dealt with {count:newFaces:stranger}", says = { GROUP }, grp = true },
        { "I had dealings with {count:newFaces:new face}", says = { GROUP }, grp = true },
        { "I <groupedWith> {count:groupedWith:stranger}", says = { GROUP }, grp = true },
        { "I <groupedWith> {crowd_about:groupedWith} strangers along the way", needs = { "groupedWith>=2" }, says = { GROUP }, grp = true },
        { "{count:groupedWith:stranger} joined my group at one point or another", needs = { "groupedWith>=2" }, says = { D, GROUP }, grp = true },
        { "a stranger joined my group for a while", needs = { "groupedWith==1" }, says = { D, GROUP, "groupedWith" }, grp = true },
        { "I made {counta:newFaces:new acquaintance}", says = { GROUP }, grp = true, voice = "warm" },
        { "I <groupedWith> {count:groupedWith:stranger}, and was glad of them", says = { GROUP }, grp = true, voice = "warm", final = true },
        { "I found myself grouping with {count:groupedWith:stranger}", says = { GROUP }, grp = true, voice = "wry" },
        { "I shared the road with {crowd_about:seen} other players", sc = true, voice = "warm" },
        { "the world felt full {today}, with {crowd_about:seen} players about", needs = { "seen>=15" }, says = { D }, voice = "warm", final = true },
        { "I fell in with {count:groupedWith:stranger} and was the better for it", says = { GROUP }, grp = true, voice = "warm", final = true },
        { "I was briefly sociable: {count:groupedWith:stranger}", says = { GROUP }, grp = true, voice = "wry", final = true },
        { "{crowd_about:seen} other players were out, which is a crowd by my standards", needs = { "seen>=8" }, says = { D, "crowd.out" }, voice = "wry", final = true },
        { "I saw {crowd_about:seen} players", sc = true, voice = "terse" },
        { "I grouped with {counta:groupedWith:stranger}", says = { GROUP }, grp = true, voice = "terse" },
        -- alone in a crowd
        { "I kept to myself among {crowd_about:seen} other players", needs = { "seen>=3", "page.solo" }, says = { SOLO }, sc = true },
        { "I played alone, though hardly in solitude", needs = { "seen>=10", "page.solo" }, says = { SOLO, "crowd.busy" }, final = true },
        -- the other faction
        { "{crowd_about:hostileSeen} players from the other faction were about too", needs = { "hostileSeen>=2" }, says = { D } },
        { "I saw {crowd_about:hostileSeen} players from the other side", needs = { "hostileSeen>=2" } },
        { "I saw a single player from the other faction", needs = { "hostileSeen==1" }, says = { "hostileSeen" }, bonus = 0.5 },
        { "the other faction was out in numbers, {crowd_n:hostileSeen} of them", needs = { "hostileSeen>=8" }, says = { D }, final = true },
        { "I kept an eye on {crowd_about:hostileSeen} enemy players", needs = { "hostileSeen>=2" }, voice = "wry", bonus = 0.5 },
        { "I kept a wary eye on the one enemy player I saw", needs = { "hostileSeen==1" }, says = { "hostileSeen" }, voice = "wry" },
        { "I counted {crowd_about:hostileSeen} hostiles", needs = { "hostileSeen>=2" }, voice = "terse" },
    },

    fragments = {
        { "{crowd_about.cap:seen} players about", sc = true },
        { "{crowd_about.cap:seen} other players, give or take", needs = { "seen>=8" }, final = true },
        { "{crowd_about.cap:seen} faces, none of them familiar", needs = { "page.diaryMet==0" }, says = { "page.diaryMet" } },
        { "Plenty of company, {crowd_about:seen} players in all", needs = { "seen>=10" } },
        { "A busy {part}", needs = BUSY, says = { "crowd.busy" } },
        { "A busy {part} in {v:busiestZone}", needs = BUSY, says = { "crowd.busy" } },
        { "Crowds in {v:busiestZone}", needs = { "busiestSeen>=15" }, says = { "crowd.busy" } },
        { "Busiest in {crowd_bz}", needs = BZN },
        { "Grouped with {count:groupedWith:stranger}", says = { GROUP }, grp = true },
        { "{count.cap:newFaces:new face}", says = { GROUP }, grp = true },
        { "{count.cap:newFaces:new face}, {num:groupedWith} of them in my group{crowd_some2}", says = { GROUP }, grp = true, final = true },
        { "Solo, despite the company", needs = { "seen>=8", "page.solo" }, says = { SOLO } },
        { "Alone among {crowd_n:seen}", needs = { "seen>=5", "page.solo" }, says = { SOLO }, sc = true },
        { "Only {crowd_about:seen} other players about", needs = QUIETISH, sc = true },
        { "{crowd_about.cap:hostileSeen} players from the other faction", needs = { "hostileSeen>=2" } },
        { "Good company {today}", needs = GROUPED, says = { GROUP, "crowd.company" }, grp = true, voice = "warm" },
        { "No shortage of company, {crowd_about:seen} players in all", needs = { "seen>=10" }, voice = "warm" },
        { "Half the realm, apparently", needs = BUSY, says = { "crowd.busy" }, voice = "wry", final = true },
        { "Standing room only in {v:busiestZone}", needs = { "busiestSeen>=20" }, says = { "crowd.busy" }, voice = "wry", bonus = 0.5 },
        { "{crowd_about.cap:seen} players. Busy", needs = BUSY, says = { "crowd.busy" }, voice = "terse", final = true },
        { "Players seen: {crowd_n:seen}", needs = { "seen>=5" }, voice = "terse", final = true },
        { "Grouped: {num:groupedWith}", says = { GROUP }, grp = true, voice = "terse" },
        { "{crowd_bz} busiest", needs = BZN, voice = "terse" },
        { "Plenty of company on the road", needs = { "seen>=10" }, voice = "warm" },
        { "Strangers everywhere, {crowd_about:seen} of them", needs = { "seen>=10", "page.diaryMet==0" }, says = { "page.diaryMet" }, voice = "wry" },
        { "Me and {crowd_about:seen} others, and not much elbow room", needs = { "seen>=15" }, voice = "wry", final = true },
        { "A sociable {part}", needs = GROUPED, says = { GROUP }, grp = true, voice = "warm" },
    },

    tails = {
        { ", most of them in {crowd_bz}", needs = BZN, sc = true },
        { ", {crowd_n:busiestSeen} of them in {crowd_bz}", needs = BZN, sc = true },
        { ", {crowd_n:hostileSeen} of them from the other faction", needs = { "hostileSeen>=2" }, sc = true },
        { ", the other faction among them", needs = { "hostileSeen>=2" }, says = { "hostileSeen" }, sc = true },
        { ", and grouped with {num:groupedWith} of them{crowd_some:groupedWith}", says = { GROUP, D, SOLO }, sc = true },
        { ", and fell in with {num:groupedWith} of them for a while{crowd_some:groupedWith}", says = { GROUP, D, SOLO }, sc = true },
        { ", and had dealings with {num:newFaces} of them{crowd_some:newFaces}", says = { GROUP, D, SOLO }, sc = true },
        { ", though I kept to myself", needs = { "seen>=3", "page.solo" }, says = { SOLO }, sc = true },
        { ", none of whom I grouped with", needs = { "seen>=3", "page.solo" }, says = { SOLO }, sc = true },
        { ", none of them anyone I knew", needs = { "page.diaryMet==0" }, says = { "page.diaryMet" }, sc = true },
        { ", and I was glad of the company", says = { D, "crowd.company" }, grp = true, voice = "warm" },
        { ", which made the {part} feel lived in", needs = { "seen>=8" }, sc = true, voice = "warm" },
        { ", which is about my limit", sc = true, voice = "wry" },
        { ", not that I was counting", sc = true, voice = "wry" },
        { ", more than I'd have guessed", needs = { "seen>=20" }, sc = true },
        { ", fewer than I'm used to", needs = QUIETISH, sc = true, voice = "wry" },
        { ", strangers every one, and that was fine", needs = { "page.diaryMet==0", "seen>=5" }, says = { "page.diaryMet" }, sc = true, voice = "warm" },
        { ", which is a lot of company for me", needs = { "seen>=15" }, sc = true, voice = "wry" },
        { ", every one of them a stranger", needs = { "page.diaryMet==0", "newFaces==0", "seen>=5" }, says = { "page.diaryMet" }, sc = true },
        { ", most of whom I never spoke to", needs = { "seen>=10", "newFaces<=3" }, sc = true },
    },

    wholes = {
        "I saw {crowd_about:seen} players {today}.",
        "{crowd_about.cap:seen} other players crossed my path {today}.",
        "There were {crowd_about:seen} other players about {today}.",
        { "I saw {crowd_about:seen} players {today}, most of them in {crowd_bz}.", needs = BZN },
        { "{crowd_bz} was the busy one: {crowd_about:busiestSeen} players there.", needs = BZC },
        { "The busiest place was {crowd_bz}, with {crowd_about:busiestSeen} players.", needs = BZN },
        { "Most of the company was in {crowd_bz}.", needs = BZC },
        { "A busy {part} in {v:busiestZone}: I saw {crowd_about:seen} players and grouped with {num:groupedWith} of them{crowd_some:groupedWith}.", needs = BUSY, says = { "crowd.busy" } },
        { "A busy {part}: {crowd_about:seen} players about, most of them in {crowd_bz}.", needs = BUSY, says = { "crowd.busy" } },
        { "It was busy {today}. I saw {crowd_about:seen} players, {crowd_n:busiestSeen} of them in {crowd_bz} alone.", needs = BUSY, says = { "crowd.busy" } },
        { "{v:busiestZone} was crowded {today}: {crowd_about:busiestSeen} players, by my count.", needs = { "busiestSeen>=15" }, says = { "crowd.busy" } },
        { "I saw {crowd_about:seen} other players {today}, and dealt with {num:newFaces} of them{crowd_some:newFaces}." },
        { "{crowd_about.cap:seen} players about; {count:newFaces:stranger} I had dealings with." },
        { "I grouped with {count:groupedWith:stranger} {today}, out of {crowd_about:seen} players I saw." },
        { "I <groupedWith> {count:groupedWith:stranger} {today}." },
        { "{count.cap:groupedWith:stranger} came through my group {today}." },
        { "{count.cap:newFaces:new face} {today}, and {num:groupedWith} of them in my group{crowd_some2}." },
        { "{count.cap:newFaces:new face} {today}, all of them in my group at some point{crowd_all}.", says = { "groupedWith" } },
        { "Of the {crowd_about:seen} players I saw, I grouped with {num:groupedWith}{crowd_some:groupedWith}." },
        { "Plenty of company {today}: {crowd_about:seen} players, {count:groupedWith:stranger} in my group at one time or another.", needs = { "seen>=10" } },
        { "I played alone, but not in an empty world: {crowd_about:seen} players about.", needs = { "seen>=5", "page.solo" } },
        { "{crowd_about.cap:seen} players about, and I didn't group with any of them.", needs = { "seen>=3", "page.solo" } },
        { "I kept to myself {today}, though {crowd_about:seen} other players were out.", needs = { "seen>=3", "page.solo" } },
        { "A quiet {part} for company: just {crowd_about:seen} other players.", needs = QUIETISH },
        { "Only {crowd_about:seen} other players crossed my path {today}.", needs = QUIETISH },
        { "{crowd_about.cap:hostileSeen} players from the other faction were about {today}.", needs = { "hostileSeen>=2" } },
        { "I saw {crowd_about:seen} players {today}, {crowd_n:hostileSeen} of them from the other faction.", needs = { "hostileSeen>=2" } },
        { "One of the players I saw {today} was from the other faction.", needs = { "hostileSeen==1" }, says = { "hostileSeen" } },
        { "The other faction was out in force: {crowd_n:hostileSeen} of them.", needs = { "hostileSeen>=10" }, bonus = 0.5 },
        -- warm
        { "It felt like the world was out {today}: {crowd_about:seen} players, and {count:groupedWith:stranger} in my group.", needs = BUSY, says = { "crowd.busy" }, voice = "warm" },
        { "Good company {today}. I grouped with {count:groupedWith:stranger}, and saw {crowd_about:seen} players about.", voice = "warm" },
        { "{v:busiestZone} was full of life {today}, with {crowd_about:busiestSeen} players about.", needs = { "busiestSeen>=12" }, voice = "warm" },
        { "I met {count:newFaces:new face} {today}. Not bad for one session.", needs = { "newFaces>=2" }, voice = "warm" },
        { "{crowd_about.cap:seen} players about {today}, and the place felt the better for it.", needs = { "seen>=8" }, voice = "warm" },
        -- wry
        { "{crowd_about.cap:seen} players about {today}, and I managed to group with none of them.", needs = { "seen>=5", "page.solo" }, voice = "wry" },
        { "{crowd_about.cap:seen} other players out {today}, and I steered clear of every one.", needs = { "seen>=5", "page.solo" }, voice = "wry" },
        { "Half the realm was in {v:busiestZone} {today}, or {crowd_n:busiestSeen} of it, anyway.", needs = { "busiestSeen>=15" }, voice = "wry" },
        { "I grouped with {count:groupedWith:stranger} {today}. Practically a social butterfly.", voice = "wry" },
        { "{crowd_about.cap:seen} players about, and elbow room in short supply.", needs = BUSY, says = { "crowd.busy" }, voice = "wry" },
        { "I saw {crowd_about:hostileSeen} players from the other faction and kept my head down.", needs = { "hostileSeen>=2" }, voice = "wry" },
        -- terse
        { "{crowd_about.cap:seen} players. {count.cap:groupedWith:stranger} grouped.", voice = "terse" },
        { "Busy. {crowd_about.cap:seen} players, mostly in {crowd_bz}.", needs = BUSY, says = { "crowd.busy" }, voice = "terse" },
        { "{v:busiestZone}: {crowd_about:busiestSeen} players.", needs = BZN, voice = "terse" },
        { "Seen: {crowd_n:seen}. Grouped: {num:groupedWith}.", voice = "terse" },
        { "{crowd_about.cap:hostileSeen} hostiles about.", needs = { "hostileSeen>=2" }, voice = "terse" },
        { "{crowd_about.cap:seen} players. Busiest: {crowd_bz}.", needs = BZN, voice = "terse" },
        { "Grouped with {count:groupedWith:stranger}. {crowd_about.cap:seen} seen.", voice = "terse" },
        { "Solo, among {crowd_n:seen}.", needs = { "seen>=5", "page.solo" }, voice = "terse" },
        { "I like a busy {part}, and this was one: {crowd_about:seen} players about.", needs = BUSY, says = { "crowd.busy" }, voice = "warm" },
        { "I fell in with {count:groupedWith:stranger} {today}, and the {part} was better for it.", voice = "warm" },
        { "Strangers all, but good company: {count:groupedWith:stranger} in my group {today}.", needs = { "page.diaryMet==0" }, voice = "warm" },
        { "{crowd_bz} was heaving {today}. I counted {crowd_about:busiestSeen} players and lost track after that.", needs = { "busiestSeen>=20" }, voice = "wry" },
        { "{crowd_about.cap:seen} players about {today}. I nodded at none of them, metaphorically speaking.", needs = { "seen>=5", "page.solo" }, voice = "wry" },
        { "Only {crowd_about:seen} other players {today}; I had the place nearly to myself.", needs = QUIETISH, voice = "wry" },
    },
}))
