-- Together: time spent with someone, the rares we found and the deaths we
-- took along the way. A together beat usually follows a reunion or a new
-- face about the same person, so most pieces read well as a second sentence:
-- {ref} turns into a pronoun when the person was just mentioned, and
-- {together_we} into "we".
--
-- time facts
--   who               the person
--   seconds           how long we were together
--   grouped           we were in a group (else just nearby: then nothing
--                     claims grouping or questing together)
--   zones             the zones we were together in (a list)
--   zone              the main one
--   quests            quests completed together (only when grouped)
--   others            the non-diary members of the group besides us: a
--                     count, or a list of people
--   wholeSession      together for the whole session
--
-- rares facts
--   rare              the name of a rare found together
--   rareCount         rares found together (1+)
--   rareKilled        we killed it (false when we found it but didn't)
--
-- deaths facts
--   theirDeaths       their deaths while we were together (0 counts)
--   myDeaths          mine
--
-- Slots declared here
--   {together_we}          "we" when the person was the last one mentioned,
--                          else "Brennick and I"; .obj gives "us" / "Brennick
--                          and me"
--   {together_zone:list}   two or more zones: "Ashenvale and Duskwood"
--   {together_zone:count}  the same as a count: "two zones"
--   {together_zone:main}   the main zone, only when there were others
--   {together_zone:one}    the zone, only when it was the only one
--   {together_others}      "two others" / "one other"
--   {together_others:list} the others by name or look, when the planner sends
--                          people and there are three or fewer
--   {together_others:size} the whole group, us included: "four"
--   {together_deaths}      both sides' deaths added up: "three deaths"
--   {together_each}        when we died as often as each other: "twice each"
--
-- Grouping is a mode, not news, so pieces guard it with "grouped==true" or
-- "!grouped" and declare says = { "grouped" } when the words state it.
--
-- Deaths must tell both sides (must = theirDeaths, myDeaths). A piece that
-- only speaks of one side can still stand alone when the other side had no
-- deaths: it needs "!myDeaths" (or "!theirDeaths") and says that tag.

local addonName, ns = ...

local Pages = ns.Pages
local Words = Pages.Words

Pages.Angle("together", { order = { "time", "rares", "deaths" },
    about = "time spent with someone" })

--------------------------------------------------------------------------
-- Slots
--------------------------------------------------------------------------

local function Key(p)
    return p.id or p.name or tostring(p)
end

-- "we" right after the person was mentioned, "Brennick and I" otherwise.
Pages.Slot("together_we", {
    needs = function() return { "who" } end,
    fn = function(env, args, mods)
        local p = env.f.who
        if type(p) ~= "table" then return nil end
        local last = env.staged.last
        if last == nil then last = env.ctx.last end
        if last == Key(p) then return mods.obj and "us" or "we" end
        local case = mods.obj and "obj" or "subj"
        return Pages.Refer(env, p, case, mods) .. (mods.obj and " and me" or " and I")
    end,
})

local function ZoneCount(f)
    return type(f.zones) == "table" and #f.zones or 0
end

Pages.Slot("together_zone", {
    needs = function(args)
        local mode = args[1]
        if mode == "list" or mode == "count" then return { "zones" } end
        return { "zone" }
    end,
    says = function(args)
        local mode = args[1]
        if mode == "count" then return { "zones" } end
        if mode == "main" then return { "zone" } end
        return { "zone", "zones" }
    end,
    fn = function(env, args)
        local f, mode = env.f, args[1]
        local n = ZoneCount(f)
        local L = Pages.Lang
        if mode == "list" then return n >= 2 and L.List(f.zones) or nil end
        if mode == "count" then return n >= 2 and L.Count(n, "zone") or nil end
        if mode == "main" then return n >= 2 and f.zone or nil end
        if mode == "one" then return n <= 1 and f.zone or nil end
        return nil
    end,
})

local function OthersCount(v)
    if type(v) == "number" then return v end
    if type(v) == "table" then return #v end
    return nil
end

Pages.Slot("together_others", {
    needs = function() return { "others" } end,
    says = function() return { "others" } end,
    fn = function(env, args)
        local v = env.f.others
        local n = OthersCount(v)
        if not n or n < 1 then return nil end
        local L = Pages.Lang
        if args[1] == "list" then
            if type(v) ~= "table" or n > 3 then return nil end
            local parts = {}
            for i = 1, n do
                if type(v[i]) ~= "table" then return nil end
                parts[i] = Pages.Refer(env, v[i], "obj", { short = true })
            end
            return L.List(parts)
        end
        if args[1] == "size" then return L.Num(n + 2) end
        return L.Count(n, "other")
    end,
})

local function Deaths(env)
    local a, b = env.f.theirDeaths, env.f.myDeaths
    if type(a) ~= "number" or type(b) ~= "number" then return nil end
    return a, b
end

Pages.Slot("together_deaths", {
    needs = function() return { "theirDeaths", "myDeaths" } end,
    says = function() return { "theirDeaths", "myDeaths" } end,
    fn = function(env)
        local a, b = Deaths(env)
        if not a then return nil end
        return Pages.Lang.Count(a + b, "death")
    end,
})

Pages.Slot("together_each", {
    needs = function() return { "theirDeaths", "myDeaths" } end,
    says = function() return { "theirDeaths", "myDeaths" } end,
    fn = function(env)
        local a, b = Deaths(env)
        if not a or a ~= b then return nil end
        return Pages.Lang.Times(a) .. " each"
    end,
})

--------------------------------------------------------------------------
-- time: how we spent the session together
--------------------------------------------------------------------------

local G = "grouped==true"
local NEAR = "!grouped"
-- "Spent the night together" says something else entirely.
local DAY = "page.part~=night"

Words("together", "time", {
    must = { "seconds" },
    needs = { "seconds" },

    stems = {
        "For {share:seconds}, ",
        "For {dur:seconds}, ",
        { "From start to finish, ", needs = { "wholeSession" }, says = { "seconds" }, bonus = 0.5 },
        { "From the moment I logged in, ", needs = { "wholeSession" }, says = { "seconds" }, bonus = 0.5 },
        { "All {part} long, ", needs = { "wholeSession" }, says = { "seconds" }, bonus = 0.5 },
        { "Across {together_zone:list}, ", bonus = 0.3 },
        { "[Through|Across] {together_zone:count}, ", bonus = 0.3 },
        { "In {together_zone:one}, ", bonus = -0.5 },
        { "In a group of {together_others:size}, ", needs = { G }, says = { "grouped" } },
        { "Quest after quest, ", needs = { G, "quests>=4" }, says = { "quests" } },
        { "Without ever grouping, ", needs = { NEAR }, says = { "grouped" } },
        { "It was a long session: ", needs = { "seconds>=7200" } },
        { "Only briefly, but ", needs = { "seconds<1200" }, says = { "seconds" }, bonus = 0.5 },
        { "Happily, ", voice = "warm", says = { "together.joy" } },
        { "The good news: ", voice = "warm", says = { "together.joy" } },
        { "For better or worse, ", voice = "wry" },
        { "Socially speaking, ", voice = "wry", says = { "social" } },
        { "No group, but ", needs = { NEAR }, says = { "grouped" }, voice = "terse" },
        { "To my delight, ", voice = "warm", says = { "together.joy" } },
        { "Against all odds, ", needs = { G }, voice = "wry" },
        { "{dur.cap:seconds} together: ", voice = "terse" },
    },

    clauses = {
        -- grouped or not
        { "{together_we} spent {share:seconds} together", needs = { DAY } },
        { "I spent {share:seconds} in {ref.poss} company", needs = { DAY }, says = { "company" } },
        { "I had {ref.poss} company for {share:seconds}", needs = { DAY }, says = { "company" } },
        "{together_we} were together for {dur:seconds}",
        { "{together_we} spent {dur:seconds} in each other's company", says = { "company" } },
        { "{together_we} spent {dur:seconds} across {together_zone:list}", bonus = 0.3 },
        { "{ref} was never far from me", bonus = -0.5 },
        { "{together_we} [stuck together|kept each other company]", needs = { G }, bonus = -0.5, says = { "company" } },

        -- grouped
        { "{together_we} grouped for {share:seconds}", needs = { G }, says = { "grouped" } },
        { "{together_we} were grouped for {dur:seconds}", needs = { G }, says = { "grouped" } },
        { "I <groupedWith> {ref.obj} for {share:seconds}", needs = { G }, says = { "grouped" } },
        { "{ref} was in my group for {share:seconds}", needs = { G }, says = { "grouped" } },
        { "{together_we} quested together for {share:seconds}", needs = { G, "quests>=1" }, says = { "grouped" } },
        { "{together_we} grouped", needs = { G }, says = { "grouped" }, bonus = -0.5 },
        { "I <groupedWith> {ref.obj}", needs = { G }, says = { "grouped" }, bonus = -0.5 },
        { "{ref} was in my group", needs = { G }, says = { "grouped" }, bonus = -0.5 },
        { "{together_we} quested together", needs = { G, "quests>=1" }, says = { "grouped" }, bonus = -0.5 },
        { "{together_we} spent {dur:seconds} working through {count:quests:quest}", needs = { G, "quests>=2" } },
        { "{together_we} finished {count:quests:quest} together in {dur:seconds}", needs = { G, "seconds>=900", "quests>=2" } },
        { "I cleared {count:quests:quest} out of my log in {dur:seconds} with {ref.obj}", needs = { G, "quests>=2" } },
        { "{together_we} kept a group going for {share:seconds}", needs = { G }, says = { "grouped" } },
        { "{together_we} stuck together through {together_zone:list}", needs = { G }, says = { "grouped" }, bonus = 0.3 },
        { "{together_we} worked our way across {together_zone:list}", needs = { G }, bonus = 0.3 },
        { "{together_we} grouped up with {together_others}", needs = { G }, says = { "grouped" } },
        { "{together_we} grouped with {together_others:list}", needs = { G }, says = { "grouped" }, bonus = 0.5 },
        { "{together_we} had {together_others} along for {share:seconds}", needs = { G }, bonus = 0.5 },
        { "{together_we} teamed up for {dur:seconds}", needs = { G }, says = { "grouped" } },
        { "{ref} was with me for {share:seconds}", needs = { G, DAY } },
        { "{ref} kept me company for {share:seconds}", needs = { G, DAY }, says = { "company" } },
        { "{together_we} quested in {together_zone:one} for {share:seconds}", needs = { G, "quests>=1" }, says = { "grouped" } },

        -- just nearby
        { "{ref} was near me for {share:seconds}", needs = { NEAR } },
        { "{ref} was somewhere near me", needs = { NEAR }, bonus = -0.5 },
        { "{together_we} were near each other without ever grouping", needs = { NEAR }, says = { "grouped" }, bonus = -0.5 },
        { "{together_we} were in a group of {together_others:size} for {share:seconds}", needs = { G }, says = { "grouped" } },
        { "{ref} was close by for {dur:seconds}", needs = { NEAR } },
        { "I had {ref.obj} nearby for {share:seconds}", needs = { NEAR } },
        { "{ref} was around for {share:seconds}", needs = { NEAR } },
        { "{ref} was near me in {together_zone:one} for {share:seconds}", needs = { NEAR } },
        { "{together_we} were near each other for {dur:seconds} without grouping", needs = { NEAR }, says = { "grouped" }, final = true },
        { "{together_we} never grouped, but {ref} was close by for {share:seconds}", needs = { NEAR }, says = { "grouped", "together.joy" } },
        { "{ref} was nearby for {share:seconds}, though we never grouped", needs = { NEAR }, says = { "grouped" }, final = true },

        -- the whole session
        { "{together_we} were together from start to finish", needs = { "wholeSession" }, says = { "seconds" } },
        { "{ref} was with me from the moment I logged in", needs = { "wholeSession", G }, says = { "seconds" }, bonus = 0.5, final = true },
        { "{together_we} grouped at the start and never split up", needs = { "wholeSession", G }, says = { "seconds", "grouped" }, final = true },
        { "{ref} was near me the whole time I was on", needs = { "wholeSession", NEAR }, says = { "seconds" } },

        { "{together_we} made a good team for {share:seconds}", needs = { G }, voice = "warm" },
        { "I got to spend {share:seconds} with {ref.obj}", needs = { DAY }, voice = "warm" },
        { "{together_we} ticked off {count:quests:quest} side by side in {dur:seconds}", needs = { G, "quests>=2" }, voice = "warm" },
        { "{ref} was good company for {share:seconds}", needs = { DAY }, voice = "warm", says = { "company" } },
        { "{together_we} were joined at the hip for {share:seconds}", needs = { G }, voice = "wry", final = true, bonus = 0.5 },
        { "{together_we} somehow stayed grouped for {dur:seconds}", needs = { G }, says = { "grouped" }, voice = "wry" },
        { "{together_we} kept within shouting distance for {share:seconds}", needs = { NEAR }, voice = "wry" },
        { "{ref} was near me for {dur:seconds}", needs = { NEAR }, voice = "terse" },
        { "I had the pleasure of {ref.poss} company for {share:seconds}", needs = { DAY }, says = { "company", "together.joy" }, voice = "warm" },
        { "{together_we} quested together for {dur:seconds}, the way it ought to be", needs = { G, "quests>=1" }, says = { "grouped" }, voice = "warm", final = true },
        { "{ref} was at my side for {share:seconds}", needs = { G, DAY }, voice = "warm" },
        { "I let {ref.obj} keep me company for {share:seconds}", needs = { G, DAY }, says = { "company" }, voice = "wry" },
        { "{together_we} kept bumping into each other for {share:seconds}", needs = { NEAR }, voice = "wry" },
        { "I had {ref.obj} for company for {dur:seconds}, whether {he} knew it or not", needs = { NEAR }, says = { "company" }, voice = "wry", final = true },
        { "{ref} was nearby, {dur:seconds}", needs = { NEAR }, voice = "terse" },
    },

    fragments = {
        { "{share.cap:seconds} with {ref.obj}", needs = { DAY } },
        "{dur.cap:seconds} with {ref.obj}",
        { "{dur.cap:seconds} of {ref.poss} company", says = { "company" } },
        { "In {ref.poss} company for {share:seconds}", needs = { DAY }, says = { "company" } },
        { "Side by side with {ref.obj} for {share:seconds}", needs = { G, DAY } },
        { "Grouped with {ref.obj} for {share:seconds}", needs = { G }, says = { "grouped" } },
        { "Questing with {ref.obj} for {share:seconds}", needs = { G, "quests>=1" }, says = { "grouped" } },
        { "{count.cap:quests:quest} with {ref.obj}", needs = { G } },
        { "Through {together_zone:list} with {ref.obj}", needs = { G }, bonus = 0.3 },
        { "Grouped up with {ref.obj} and {together_others}", needs = { G }, says = { "grouped" } },
        { "Grouped with {ref.obj}, plus {together_others:list}", needs = { G }, says = { "grouped" }, bonus = 0.5 },
        { "{ref.noun.short} nearby for {share:seconds}", needs = { NEAR } },
        { "{ref.noun.short} near me for {share:seconds}, never grouped", needs = { NEAR }, says = { "grouped" }, final = true },
        { "The whole {part} with {ref.obj}", needs = { "wholeSession", DAY }, says = { "seconds" } },
        { "With {ref.obj} from start to finish", needs = { "wholeSession" }, says = { "seconds" } },
        { "{ref.noun.short} at my side for {share:seconds}", needs = { G, DAY }, voice = "warm" },
        { "{share.cap:seconds} in good company: {ref.noun.short}", needs = { DAY }, voice = "warm", final = true },
        { "{dur.cap:seconds} grouped with {ref.obj}, and no regrets", needs = { G }, says = { "grouped" }, voice = "wry", final = true },
        { "{ref.noun.short} for company, {dur:seconds} of it", voice = "wry", says = { "company" } },
        { "{ref.noun.short} for {dur:seconds}", voice = "terse" },
        { "{ref.noun.short}, {dur:seconds}, grouped", needs = { G }, says = { "grouped" }, voice = "terse" },
        { "{ref.noun.short} and me: {count:quests:quest}, {dur:seconds}", needs = { G }, voice = "terse" },
        { "{ref.noun.short} and me, {share:seconds}", needs = { DAY }, voice = "terse" },
        { "{ref.noun.short} nearby, {dur:seconds}", needs = { NEAR }, voice = "terse" },
        { "{dur.cap:seconds} well spent with {ref.obj}", voice = "warm" },
        { "Good company for {dur:seconds}: {ref.noun.short}", says = { "company" }, voice = "warm", final = true },
        { "{dur.cap:seconds} near {ref.obj}, and no group to show for it", needs = { NEAR }, says = { "grouped" }, voice = "wry", final = true },
        { "{count.cap:quests:quest} in {dur:seconds} with {ref.obj}, to my quest log's relief", needs = { G, "quests>=2" }, voice = "wry", final = true },
        { "{ref.noun.short}: {count:quests:quest} in {dur:seconds}", needs = { G }, voice = "terse" },
        { "{ref.noun.short}, all {part}", needs = { "wholeSession" }, says = { "seconds" }, voice = "terse" },
    },

    tails = {
        " for {share:seconds}",
        " for {dur:seconds}",
        ", {dur:seconds} in all",
        { " all {part}", needs = { "wholeSession" }, says = { "seconds" }, bonus = 0.5 },
        { " the whole time I was on", needs = { "wholeSession" }, says = { "seconds" }, bonus = 0.5 },
        { ", [from start to finish|from the first minute to the last]", needs = { "wholeSession" }, says = { "seconds" }, bonus = 0.5 },
        { ", mostly in {together_zone:main}", bonus = 0.3 },
        { ", much of it in {together_zone:main}", bonus = 0.3 },
        ", all of it in {together_zone:one}",
        { " in {together_zone:one}", bonus = -0.5 },
        { ", across {together_zone:list}", bonus = 0.3 },
        { ", taking in {together_zone:list}", bonus = 0.3 },
        { ", [across|through] {together_zone:count}", bonus = 0.3 },
        { ", with {count:quests:quest} done between us", needs = { G } },
        { ", long enough for {count:quests:quest}", needs = { G, "quests>=2" } },
        { ", with {count:quests:quest} to show for it", needs = { G } },
        { ", along with {together_others}", needs = { G } },
        { ", with {together_others} in the group", needs = { G }, says = { "grouped" } },
        { ", with {together_others:list} along", needs = { G } },
        { ", [grouped the whole time|in the same group throughout]", needs = { G }, says = { "grouped" } },
        { ", though we never grouped", needs = { NEAR }, says = { "grouped" } },
        { ", without ever grouping", needs = { NEAR }, says = { "grouped" } },
        { ", never in the same group", needs = { NEAR }, says = { "grouped" } },
        { ", and I was glad of the company", voice = "warm", says = { "company", "together.joy" } },
        { ", which suited me fine", voice = "warm", says = { "together.joy" } },
        { ", and the time [flew|went far too quickly]", needs = { "seconds>=2700" }, voice = "warm", says = { "together.joy" } },
        { ", which is a lot of socialising for me", needs = { "seconds>=3600", G }, voice = "wry", says = { "social" } },
        { ", which I'll count as a social life", voice = "wry", says = { "social" } },
        { ", grouped", needs = { G }, says = { "grouped" }, voice = "terse", bonus = 0.5 },
        { ", and I'd do it again tomorrow", voice = "warm", says = { "together.joy" } },
        { ", the best part of my {part}", needs = { "!wholeSession" }, voice = "warm", says = { "together.joy" } },
        { ", which for me is practically a party", needs = { G }, voice = "wry", says = { "social" } },
        { ", and somehow it worked", needs = { G }, voice = "wry" },
        { ", no group", needs = { NEAR }, says = { "grouped" }, voice = "terse" },
    },

    wholes = {
        { "{together_we} spent {share:seconds} together.", needs = { DAY }, lead = true },
        { "I spent {share:seconds} in {ref.poss} company.", needs = { DAY }, lead = true },
        "{together_we} were together for {dur:seconds} in the end.",
        "{dur.cap:seconds} with {ref.obj}, all told.",
        { "{dur.cap:seconds} with {ref.obj}, much of it in {together_zone:main}.", bonus = 0.3 },
        { "{together_we} spent {dur:seconds} across {together_zone:list}.", bonus = 0.3 },
        { "{together_we} grouped for {share:seconds}.", needs = { G }, says = { "grouped" }, lead = true },
        { "{ref} kept me company for {share:seconds}.", needs = { G, DAY }, lead = true },
        { "{together_we} were grouped for {dur:seconds} and got through {count:quests:quest}.", needs = { G, "quests>=2" }, says = { "grouped" } },
        { "{together_we} quested together for {dur:seconds}, mostly in {together_zone:main}.", needs = { G, "quests>=1" }, says = { "grouped" }, bonus = 0.3 },
        { "{together_we} finished {count:quests:quest} together in {dur:seconds}.", needs = { G, "seconds>=900", "quests>=2" }, lead = true },
        { "{count.cap:quests:quest} and {dur:seconds} with {ref.obj}.", needs = { G } },
        { "{together_we} got {count:quests:quest} done, and it took {dur:seconds}.", needs = { G, "seconds>=1200", "quests>=2" } },
        { "{together_we} worked through {count:quests:quest}, {dur:seconds} in all.", needs = { G, "quests>=2" } },
        { "{together_we} covered {together_zone:list} in {dur:seconds}.", needs = { G, "seconds>=1800" }, bonus = 0.3 },
        { "{together_we} stuck together through {together_zone:count} and {dur:seconds}.", needs = { G }, says = { "grouped" }, bonus = 0.3 },
        { "{ref} was with me in {together_zone:one} for {share:seconds}.", needs = { G, DAY } },
        { "{ref} was in my group for {share:seconds}. We finished {count:quests:quest}.", needs = { G }, says = { "grouped" } },
        { "{together_we} grouped with {together_others} for {dur:seconds}.", needs = { G }, says = { "grouped" } },
        { "{together_we} had {together_others} along for {dur:seconds}, and we finished {count:quests:quest}.", needs = { G } },
        { "{together_we} grouped with {together_others:list} for {dur:seconds}.", needs = { G }, says = { "grouped" } },
        { "{ref} was there from the moment I logged in until I logged off.", needs = { "wholeSession" }, says = { "seconds" } },
        { "From the moment I logged in to the moment I logged out, {ref} was with me.", needs = { "wholeSession", G }, says = { "seconds" } },
        { "{together_we} grouped at the start and never split up.", needs = { "wholeSession", G }, says = { "seconds", "grouped" } },
        { "{together_we} were together the whole time I was on.", needs = { "wholeSession" }, says = { "seconds" } },
        { "{ref} was near me for {share:seconds}, though we never grouped.", needs = { NEAR }, says = { "grouped" } },
        { "{together_we} never grouped, but {ref} was close by for {share:seconds}.", needs = { NEAR }, says = { "grouped" } },
        { "{together_we} were near each other for {dur:seconds} without ever grouping.", needs = { NEAR }, says = { "grouped" } },
        { "I had {ref.obj} nearby for {share:seconds}: never in my group, never far off.", needs = { NEAR }, says = { "grouped" } },
        { "For {share:seconds}, {ref} was never far away.", needs = { NEAR }, lead = true },
        { "{ref} was around for {share:seconds}, all of it in {together_zone:one}.", needs = { NEAR } },

        { "{together_we} grouped for {share:seconds}, and I enjoyed every minute of it.", needs = { G }, says = { "grouped" }, voice = "warm" },
        { "I spent {share:seconds} with {ref.obj}, and I'd happily have stayed longer.", needs = { "!wholeSession", DAY }, voice = "warm" },
        { "{ref} was with me for {share:seconds}. Good company, as ever.", needs = { G, DAY, "who.diary" }, voice = "warm" },
        { "{dur.cap:seconds} with {ref.obj}, and it went far too quickly.", needs = { "seconds>=1800" }, voice = "warm" },
        { "{together_we} were near each other for {share:seconds}. We never grouped, but I liked having {ref.obj} close.", needs = { NEAR }, says = { "grouped" }, voice = "warm" },
        { "{together_we} quested side by side for {dur:seconds}. I'd missed that.", needs = { G, "quests>=1", "who.diary" }, voice = "warm" },
        { "Every minute I was on, {ref} was there. I couldn't ask for better.", needs = { "wholeSession" }, says = { "seconds" }, voice = "warm" },
        { "{dur.cap:seconds} grouped with {ref.obj}. That's my kind of {part}.", needs = { G, "seconds>=2400" }, says = { "grouped" }, voice = "warm" },
        { "{together_we} grouped for {share:seconds}, which is more socialising than I usually manage.", needs = { G }, says = { "grouped" }, voice = "wry" },
        { "{ref} was near me for {share:seconds}, and somehow we never got round to grouping.", needs = { NEAR }, says = { "grouped" }, voice = "wry" },
        { "{together_we} spent {share:seconds} within shouting distance and never grouped. Very sociable of us.", needs = { NEAR }, says = { "grouped" }, voice = "wry" },
        { "{count.cap:quests:quest} with {ref.obj} in {dur:seconds}. We didn't hang about.", needs = { G, "quests>=8", "seconds<=5400" }, voice = "wry" },
        { "{dur.cap:seconds} grouped with {ref.obj}, and a single quest to show for it.", needs = { G, "quests==1", "seconds>=1800" }, says = { "grouped", "quests" }, voice = "wry" },
        { "{together_we} were joined at the hip all {part}.", needs = { "wholeSession", G }, says = { "seconds" }, voice = "wry" },
        { "{count.cap:quests:quest} in {dur:seconds} with {ref.obj}. Somebody had to do them.", needs = { G, "quests>=3", "seconds>=900" }, voice = "wry" },
        { "{ref.noun.short}: {share:seconds}, grouped.", needs = { G }, says = { "grouped" }, voice = "terse" },
        { "{ref.noun.short}. {dur.cap:seconds}. {count.cap:quests:quest}.", needs = { G }, voice = "terse" },
        { "With {ref.obj}, {dur:seconds}.", voice = "terse" },
        { "{ref.noun.short} nearby, {share:seconds}. No group.", needs = { NEAR }, says = { "grouped" }, voice = "terse" },
        { "{ref.noun.short}, start to finish.", needs = { "wholeSession" }, says = { "seconds" }, voice = "terse" },
        { "{together_we} grouped for {share:seconds}. It felt like old times.", needs = { G, "who.diary" }, says = { "grouped" }, voice = "warm" },
        { "{dur.cap:seconds} in {ref.poss} company, and not a minute of it wasted.", voice = "warm" },
        { "I had {ref.obj} nearby for {share:seconds}, and that was company enough.", needs = { NEAR }, voice = "warm" },
        { "{together_we} quested together for {dur:seconds}. The best part of my {part}.", needs = { G, "quests>=1", "!wholeSession" }, says = { "grouped" }, voice = "warm" },
        { "{dur.cap:seconds} grouped with {ref.obj}. My solo career is in tatters.", needs = { G, "seconds>=2700" }, says = { "grouped" }, voice = "wry" },
        { "{ref} was near me for {share:seconds}. We may as well have grouped.", needs = { NEAR }, says = { "grouped" }, voice = "wry" },
        { "{count.cap:quests:quest} with {ref.obj} in {dur:seconds}. My quest log thanks {him}.", needs = { G, "quests>=4" }, voice = "wry" },
        { "{ref.noun.short}. {dur.cap:seconds}, grouped.", needs = { G }, says = { "grouped" }, voice = "terse" },
        { "{ref.noun.short}, nearby. {dur.cap:seconds}.", needs = { NEAR }, voice = "terse" },
    },
})

--------------------------------------------------------------------------
-- rares: a rare found together, a small highlight
--------------------------------------------------------------------------

local KILLED = "rareKilled"
local SPARED = "rareKilled==false"

Words("together", "rares", {
    must = { "rare" },
    needs = { "rare" },
    rel = "also",

    stems = {
        "Along the way, ",
        "At one point, ",
        "Somewhere in there, ",
        "In the middle of it all, ",
        { "The highlight: ", says = { "highlight" } },
        "As luck would have it, ",
        { "Out of nowhere, ", bonus = -0.5 },
        { "Best of all, ", voice = "warm", says = { "highlight" } },
        { "Better still, ", voice = "warm", says = { "highlight" } },
        { "Of all things, ", voice = "wry", says = { "aside" } },
        { "To top it off, ", voice = "wry" },
        { "Rare: ", voice = "terse" },
    },

    clauses = {
        "{together_we} found {v:rare}",
        "{together_we} [came across|came upon|happened on] {v:rare}",
        "{together_we} ran into {v:rare}",
        "{v:rare} turned up while {together_we} were together",
        "{v:rare} crossed paths with {together_we.obj}",
        "{together_we} found ourselves face to face with {v:rare}",
        { "{together_we} had a brush with {v:rare}", needs = { "!rareKilled" } },
        { "{v:rare} showed itself while {ref} was with me", needs = { "grouped==true" } },
        { "I came across {v:rare} with {ref.obj} at my side", needs = { "grouped==true" } },
        { "I found {v:rare} with {ref.obj} close by", needs = { "!grouped" } },
        { "{together_we} killed {v:rare}", needs = { KILLED } },
        { "{together_we} took down {v:rare}", needs = { KILLED } },
        { "{together_we} brought {v:rare} down", needs = { KILLED } },
        { "{v:rare} fell to {together_we.obj}", needs = { KILLED } },
        { "{together_we} put an end to {v:rare}", needs = { KILLED } },
        { "{together_we} found {v:rare}, but didn't kill it", needs = { SPARED }, says = { "rareKilled" }, final = true },
        { "{together_we} found {num:rareCount} rares, {v:rare} among them", needs = { "rareCount>=2" } },
        { "{v:rare} was one of {num:rareCount} rares {together_we} found", needs = { "rareCount>=2" } },
        { "{together_we} turned up {count:rareCount:rare}", needs = { "rareCount>=2" } },
        { "{together_we} stumbled on {v:rare}", voice = "wry" },
        { "{v:rare} met {together_we.obj} and came off worse", needs = { KILLED }, voice = "wry", final = true },
        { "{together_we} found not one rare but {num:rareCount}, {v:rare} among them", needs = { "rareCount>=2" }, voice = "wry" },
        { "{together_we} got to see {v:rare}", voice = "warm" },
        { "{together_we} found {v:rare} together", voice = "warm" },
        { "{together_we} got {v:rare}", needs = { KILLED }, voice = "terse" },
        { "{together_we} had the luck to find {v:rare}", voice = "warm" },
        { "{together_we} tripped over {v:rare}", voice = "wry" },
    },

    fragments = {
        "A rare with {ref.obj}: {v:rare}",
        "{v:rare}, found with {ref.obj}",
        "Found {v:rare} with {ref.obj}",
        "The rare of the {part}, with {ref.obj}: {v:rare}",
        { "Killed {v:rare} with {ref.obj}", needs = { KILLED } },
        { "{v:rare}, killed with {ref.obj}", needs = { KILLED } },
        { "{ref.noun.short} and me against {v:rare}, and {v:rare} lost", needs = { KILLED }, final = true },
        { "{num.cap:rareCount} rares with {ref.obj}, {v:rare} among them", needs = { "rareCount>=2" } },
        { "{count.cap:rareCount:rare} with {ref.obj}", needs = { "rareCount>=2" } },
        { "A lucky find with {ref.obj}: {v:rare}", voice = "warm", bonus = 0.5 },
        { "{v:rare}, of all things, found with {ref.obj}", voice = "wry", says = { "aside" } },
        { "{v:rare}. With {ref.obj}, no less", voice = "wry", final = true },
        { "{v:rare}, with {ref.obj}", voice = "terse", final = true },
        { "{v:rare} down, with {ref.obj}", needs = { KILLED }, voice = "terse" },
        { "Rare: {v:rare}", voice = "terse" },
        { "A rare and good company: {v:rare}, with {ref.obj}", voice = "warm", final = true, bonus = 0.5 },
        { "Found {v:rare}. Killed it", needs = { KILLED, "rareCount<2" }, voice = "terse", final = true },
    },

    tails = {
        { ", and [we killed it|between us we killed it]", needs = { KILLED, "rareCount<2" } },
        { ", and down it went", needs = { KILLED, "rareCount<2" } },
        { ", and the kill was ours", needs = { KILLED, "rareCount<2" } },
        { ", though we didn't kill it", needs = { SPARED, "rareCount<2" }, says = { "rareKilled" } },
        ", which doesn't happen every day",
        { ", a small highlight", says = { "highlight" } },
        { ", the high point of the {part}", says = { "highlight" } },
        { " in {together_zone:one}", bonus = -0.5 },
        { ", one of {num:rareCount} rares {today}", needs = { "rareCount>=3" } },
        { ", and another rare besides", needs = { "rareCount==2" }, says = { "rareCount" } },
        { ", {v:rare} among them", needs = { "rareCount>=2" } },
        { ", which made the {part}", voice = "warm", says = { "highlight" } },
        { ", a nice surprise", voice = "warm", says = { "highlight" } },
        { ", and I was glad of the company for it", voice = "warm", says = { "gladCompany" } },
        { ", of all things", voice = "wry", says = { "aside" } },
        { ", no less", voice = "wry", says = { "aside" } },
        { ", which I'll take", voice = "wry" },
        { ", and it didn't survive the meeting", needs = { KILLED, "rareCount<2" }, voice = "wry" },
        { ", but no kill", needs = { SPARED, "rareCount<2" }, says = { "rareKilled" }, voice = "terse" },
        { ", killed", needs = { KILLED, "rareCount<2" }, voice = "terse" },
        { ", and I'm glad it was with {him}", voice = "warm", says = { "together.joy" } },
        { ", and we killed {v:rare}", needs = { KILLED, "rareCount>=2" } },
        { ", though we didn't kill {v:rare}", needs = { SPARED, "rareCount>=2" }, says = { "rareKilled" } },
    },

    wholes = {
        { "Along the way, {together_we} found {v:rare}." },
        "{v:rare} turned up while {together_we} were together.",
        "There was a rare, too: {together_we} found {v:rare}.",
        { "The {part}'s highlight was {v:rare}, which {together_we} found together.", says = { "highlight" } },
        "{v:rare}, found with {ref.obj}. A good find.",
        "{together_we} came across {v:rare} in {together_zone:one}.",
        "Not every {part} brings a rare. This one brought {v:rare}, and {ref} was there for it.",
        { "{v:rare} turned up while {ref} was with me, and that was a bit of luck.", needs = { "grouped==true" } },
        { "I found {v:rare} with {ref.obj} close by.", needs = { "!grouped" } },
        { "{together_we} came across {v:rare}, and we killed it.", needs = { KILLED }, lead = true },
        { "{v:rare} turned up, and {together_we} killed it.", needs = { KILLED } },
        { "There was even a rare: {v:rare}, which {together_we} killed between us.", needs = { KILLED } },
        { "At one point {v:rare} turned up, and {together_we} took it down.", needs = { KILLED } },
        { "{together_we} found {v:rare} but didn't kill it.", needs = { SPARED }, says = { "rareKilled" }, lead = true },
        { "We found {v:rare}. Neither of us killed it.", needs = { SPARED }, says = { "rareKilled" } },
        { "{together_we} found {v:rare}. We didn't kill it, but it was something to see.", needs = { SPARED }, says = { "rareKilled" } },
        { "{together_we} found {num:rareCount} rares, {v:rare} among them.", needs = { "rareCount>=2" }, lead = true },
        { "Two rares in one {part}, {v:rare} among them, and {ref} was there for both.", needs = { "rareCount==2" }, says = { "rareCount" } },
        { "Rares don't turn up often, so finding {v:rare} with {ref.obj} was a treat.", voice = "warm" },
        { "We found {v:rare} together, {ref} and I. A good moment.", voice = "warm" },
        { "Finding {v:rare} with {ref.obj} made the {part}.", voice = "warm" },
        { "{together_we} found {v:rare}, and I'm glad I wasn't alone for it.", voice = "warm" },
        { "{together_we} killed {v:rare}. I'll take that.", needs = { KILLED }, voice = "wry" },
        { "{v:rare} picked the wrong {part} to cross {together_we.obj}.", needs = { KILLED }, voice = "wry" },
        { "{together_we} found {v:rare}. It didn't survive us.", needs = { KILLED }, voice = "wry" },
        { "{together_we} came away from {v:rare} the winners.", needs = { KILLED }, voice = "wry" },
        { "{v:rare}. Found with {ref.obj}.", voice = "terse" },
        { "{v:rare}, with {ref.obj}. Dead.", needs = { KILLED }, voice = "terse" },
        { "Rare: {v:rare}. {together_we.cap} killed it.", needs = { KILLED }, voice = "terse" },
        { "{num.cap:rareCount} rares, {ref.noun.short} and me. {v:rare} was one.", needs = { "rareCount>=2" }, voice = "terse" },
        { "{together_we} found {v:rare}. Sharing a find like that is half the fun.", voice = "warm" },
        { "{v:rare} turned up while {together_we} were together, which made a good {part} better.", voice = "warm" },
        { "{v:rare} turned up, and {together_we} gave it our full attention.", voice = "wry" },
        { "{v:rare}. {together_we.cap} found it.", voice = "terse" },
    },
})

--------------------------------------------------------------------------
-- deaths: told plainly and kindly
--------------------------------------------------------------------------

-- A piece that only tells my deaths stands alone when they had none, and
-- the other way round.
local ONLY_MINE = "!theirDeaths"
local ONLY_THEIRS = "!myDeaths"

-- A kill is ours only in a group. When we were just near each other the
-- diary can't say who killed it, so every "we killed" line above needs a
-- group, and these say it without crediting anyone.
do
    local rares = Pages.ANGLES.together.moves.rares
    local grouped = Pages.ParseCond("grouped==true")
    for _, kind in ipairs({ "stems", "clauses", "fragments", "tails", "wholes" }) do
        for _, p in ipairs(rares[kind]) do
            for _, cond in ipairs(p.conds) do
                if cond.path == "rareKilled" and not cond.op and not cond.neg then
                    p.conds[#p.conds + 1] = grouped
                    break
                end
            end
        end
    end
end

Words("together", "rares", {
    clauses = {
        { "{v:rare} went down while {ref} was nearby", needs = { KILLED, "!grouped" } },
        { "{v:rare} was killed with {ref.obj} close by", needs = { KILLED, "!grouped" } },
        { "{v:rare} died with the two of us in the same patch of ground", needs = { KILLED, "!grouped" } },
        { "{v:rare} didn't survive the afternoon, and {ref} was there for it", needs = { KILLED, "!grouped", "page.part==afternoon" }, voice = "wry" },
        { "{v:rare} came and went, {ref.short} and I both nearby", needs = { KILLED, "!grouped" }, voice = "terse" },
    },
    fragments = {
        { "{v:rare} down, {ref.short} nearby", needs = { KILLED, "!grouped" }, voice = "terse" },
        { "{v:rare} dead, with {ref.obj} not far off", needs = { KILLED, "!grouped" } },
    },
    wholes = {
        { "{v:rare} turned up and went down, with {ref.obj} nearby the whole time.", needs = { KILLED, "!grouped" } },
        { "We weren't grouped, but {ref} was close by when {v:rare} went down.", needs = { KILLED, "!grouped" } },
        { "{v:rare} died somewhere between {ref.obj} and me. Who gets the credit, I couldn't say.", needs = { KILLED, "!grouped" }, voice = "wry" },
        { "{v:rare} went down, and {ref} was there to see it. So was I.", needs = { KILLED, "!grouped" }, voice = "warm" },
    },
})

Words("together", "deaths", {
    must = { "theirDeaths", "myDeaths" },

    stems = {
        "It wasn't all smooth: ",
        "Not everything went our way: ",
        "For the record, ",
        "On the downside, ",
        "Not without cost, though: ",
        { "Sadly, ", bonus = -0.5 },
        { "Not that it matters, but ", voice = "warm" },
        { "There were casualties: ", voice = "wry" },
        { "Inevitably, ", voice = "wry" },
        { "In the interests of honesty, ", voice = "wry" },
    },

    clauses = {
        -- one side, to be finished by a tail
        "{ref} died {times:theirDeaths}",
        "{ref} went down {times:theirDeaths}",
        "I died {times:myDeaths}",
        { "{ref} had a rough time of it, dying {times:theirDeaths}", needs = { "theirDeaths>=2" } },
        { "{ref.poss} deaths came to {num:theirDeaths}", needs = { "theirDeaths>=2" } },
        { "{ref} died {times:theirDeaths} while we were grouped", needs = { "grouped==true" }, says = { "grouped" } },
        { "I managed to die {times:myDeaths}", voice = "wry" },
        { "I found {num:myDeaths} separate ways to die", needs = { "myDeaths>=2" }, voice = "wry" },

        -- both sides
        "{ref} [died|went down] {times:theirDeaths}[ and|;] I [died|went down] {times:myDeaths}",
        "{together_we} died {together_each}",
        "between {ref.obj} and me there were {together_deaths}",
        { "the deaths came out at {num:theirDeaths} for {ref.obj} and {num:myDeaths} for me" },
        { "{together_we} each had our share of deaths, {num:theirDeaths} for {ref.obj} and {num:myDeaths} for me", needs = { "theirDeaths>=1", "myDeaths>=1" }, final = true },
        { "{ref} died {times:theirDeaths}, and I came through without dying", needs = { "myDeaths==0" }, says = { "myDeaths" }, final = true },
        { "I died {times:myDeaths}, and {ref} not at all", needs = { "theirDeaths==0" }, says = { "theirDeaths" }, final = true },
        { "{ref} stayed on {his} feet while I died {times:myDeaths}", needs = { "theirDeaths==0" }, says = { "theirDeaths" } },
        { "{together_we} racked up {together_deaths} between us", voice = "wry" },

        -- one side, when the other had none
        { "I died {times:myDeaths} in {ref.poss} company", needs = { ONLY_MINE }, says = { "theirDeaths" } },
        { "I died {times:myDeaths} with {ref.obj} close by", needs = { "!grouped", ONLY_MINE }, says = { "theirDeaths" } },
        { "{ref} died {times:theirDeaths}, which happens", needs = { ONLY_THEIRS }, says = { "myDeaths" }, final = true },
        { "{ref} died {times:theirDeaths}, and I was sorry to see it", needs = { ONLY_THEIRS }, says = { "myDeaths" }, voice = "warm", final = true },
        { "{ref} died {times:theirDeaths}, through no fault of {his} own that I could see", needs = { ONLY_THEIRS }, says = { "myDeaths" }, voice = "warm", final = true },
        { "I died {times:myDeaths}, for my sins", needs = { ONLY_MINE }, says = { "theirDeaths" }, voice = "wry", final = true },
        { "{ref} was dead {times:theirDeaths} before we were done", needs = { ONLY_THEIRS }, says = { "myDeaths" }, voice = "terse" },
        { "I died {times:myDeaths}, and {ref} was there every time", needs = { ONLY_MINE }, says = { "theirDeaths" }, voice = "warm", final = true },
    },

    fragments = {
        "{count.cap:theirDeaths:death} for {ref.obj}",
        "{count.cap:myDeaths:death} for me, {num:theirDeaths} for {ref.obj}",
        "{together_deaths.cap} between {ref.obj} and me",
        { "Not a clean {part}: {count:theirDeaths:death} for {ref.obj}", needs = { ONLY_THEIRS }, says = { "myDeaths" } },
        { "{count.cap:myDeaths:death} for me in {ref.poss} company", needs = { ONLY_MINE }, says = { "theirDeaths" } },
        { "{count.cap:theirDeaths:death} for {ref.obj}, none for me", needs = { "myDeaths==0" }, says = { "myDeaths" } },
        { "{count.cap:myDeaths:death} for me, none for {ref.obj}", needs = { "theirDeaths==0" }, says = { "theirDeaths" } },
        { "A death apiece for {ref.obj} and me", needs = { "theirDeaths==1", "myDeaths==1" }, says = { "theirDeaths", "myDeaths" } },
        { "{count.cap:theirDeaths:death} for {ref.obj}, and I was sorry for each", needs = { "theirDeaths>=2", ONLY_THEIRS }, says = { "myDeaths" }, voice = "warm", final = true },
        { "Dead {times:myDeaths} myself, for my sins, with {ref.obj} close by", needs = { "!grouped", ONLY_MINE }, says = { "theirDeaths" }, voice = "wry", final = true },
        { "{ref.noun.short} dead {times:theirDeaths}, me {times:myDeaths}", voice = "terse" },
        { "Died {times:myDeaths} myself, {ref.noun.short} {times:theirDeaths}", voice = "terse" },
        { "Deaths: {ref.noun.short} {num:theirDeaths}, me {num0:myDeaths}", voice = "terse" },
        { "Deaths: me {num:myDeaths}, {ref.noun.short} {num0:theirDeaths}", needs = { "theirDeaths==0" }, voice = "terse" },
    },

    tails = {
        ", which happens",
        ", no lasting harm done",
        ", none of it serious",
        ", which could have been worse",
        ", and {ref} died {times:theirDeaths}",
        ", and I died {times:myDeaths}",
        { ", to my {num:myDeaths}", needs = { "myDeaths>=2", "theirDeaths>=3" } },
        { ", while I came through without dying", needs = { "myDeaths==0" }, says = { "myDeaths" } },
        { ", and I didn't die at all", needs = { "myDeaths==0" }, says = { "myDeaths" } },
        { ", while {ref} stayed on {his} feet", needs = { "theirDeaths==0" }, says = { "theirDeaths" } },
        { " with {ref.obj} close by", needs = { "!grouped", ONLY_MINE }, says = { "theirDeaths" }, bonus = 0.5 },
        { " in {ref.poss} company", needs = { ONLY_MINE }, says = { "theirDeaths" } },
        { ", and I was sorry to see it", needs = { ONLY_THEIRS }, says = { "myDeaths" }, voice = "warm" },
        { ", but it didn't spoil the {part}", voice = "warm" },
        { ", not that it spoiled anything", voice = "warm" },
        { ", not that I'm counting", voice = "wry" },
        { ", which I'm choosing not to dwell on", voice = "wry" },
        { ", each one honestly earned", needs = { ONLY_MINE, "myDeaths>=2" }, says = { "theirDeaths" }, voice = "wry", bonus = 0.5 },
        { ", entirely my own doing", needs = { ONLY_MINE }, says = { "theirDeaths" }, voice = "wry" },
        { ", nothing worse", voice = "terse" },
        { ", not that it dimmed the {part}", voice = "warm" },
    },

    wholes = {
        "{ref} died {times:theirDeaths} and I died {times:myDeaths}. Not a tidy {part}.",
        "It cost us {together_deaths}: {num:theirDeaths} for {ref.obj} and {num:myDeaths} for me.",
        "{count.cap:theirDeaths:death} for {ref.obj}, {count:myDeaths:death} for me. Neither of us came through clean.",
        "{together_we} died {together_each}.",
        "We died {together_each}, {ref} and I.",
        { "One death apiece for {ref.obj} and me.", needs = { "theirDeaths==1", "myDeaths==1" }, says = { "theirDeaths", "myDeaths" } },
        { "I died {times:myDeaths}; {ref} didn't die at all.", needs = { "theirDeaths==0" }, says = { "theirDeaths" } },
        { "{ref} died {times:theirDeaths}; I came through without dying.", needs = { "myDeaths==0" }, says = { "myDeaths" } },
        { "{ref} died {times:theirDeaths}. It happens.", needs = { ONLY_THEIRS }, says = { "myDeaths" } },
        { "There were deaths, too: {ref} died {times:theirDeaths}.", needs = { "theirDeaths>=2", ONLY_THEIRS }, says = { "myDeaths" } },
        { "There was a death, too: {ref} went down once.", needs = { "theirDeaths==1", ONLY_THEIRS }, says = { "theirDeaths", "myDeaths" } },
        { "{ref} died {times:theirDeaths} while we were grouped.", needs = { "grouped==true", ONLY_THEIRS }, says = { "grouped", "myDeaths" } },
        { "Not every fight went our way: {ref} died {times:theirDeaths}.", needs = { ONLY_THEIRS }, says = { "myDeaths" } },
        { "I died {times:myDeaths} while {ref} was close by.", needs = { "!grouped", ONLY_MINE }, says = { "theirDeaths" } },
        { "I died {times:myDeaths} in {ref.poss} company.", needs = { ONLY_MINE }, says = { "theirDeaths" }, bonus = -0.5 },
        { "{ref} died {times:theirDeaths}; it didn't spoil my {part} with {him}.", needs = { ONLY_THEIRS }, says = { "myDeaths" }, voice = "warm" },
        { "{ref} died {times:theirDeaths}, and I was sorry to see it each time.", needs = { "theirDeaths>=2", ONLY_THEIRS }, says = { "myDeaths" }, voice = "warm" },
        { "Between {ref.obj} and me there were {together_deaths}, and it was still a good {part}.", voice = "warm" },
        { "{ref} died {times:theirDeaths}. No shame in that.", needs = { ONLY_THEIRS }, says = { "myDeaths" }, voice = "warm" },
        { "{together_we} died {together_each}, and picked ourselves up {together_each}.", voice = "warm" },
        { "Between us, {ref} and I managed {together_deaths}.", voice = "wry" },
        { "I died {times:myDeaths} with {ref.obj} about. Embarrassing, but there it is.", needs = { ONLY_MINE }, says = { "theirDeaths" }, voice = "wry" },
        { "I'd like to blame the zone for my {count:myDeaths:death}, but {ref} was in it too and didn't die.", needs = { "theirDeaths==0", "myDeaths>=2" }, says = { "theirDeaths" }, voice = "wry" },
        { "I died {times:myDeaths}. A menace, mostly to myself.", needs = { ONLY_MINE }, says = { "theirDeaths" }, voice = "wry" },
        { "I died {times:myDeaths}; {ref} stayed on {his} feet throughout. Make of that what you will.", needs = { "theirDeaths==0" }, says = { "theirDeaths" }, voice = "wry" },
        { "{ref} died {times:theirDeaths}. I somehow didn't, which I'll put down to luck.", needs = { "myDeaths==0" }, says = { "myDeaths" }, voice = "wry" },
        { "Deaths: {ref.noun.short} {num:theirDeaths}, me {num:myDeaths}.", voice = "terse" },
        { "{ref} died {times:theirDeaths}. Not me.", needs = { ONLY_THEIRS }, says = { "myDeaths" }, voice = "terse" },
        { "I died {times:myDeaths}. {ref} didn't.", needs = { "theirDeaths==0" }, says = { "theirDeaths" }, voice = "terse" },
        { "{together_deaths.cap} between us. {ref.noun.short} {num:theirDeaths}, me {num:myDeaths}.", voice = "terse" },
        { "{together_deaths.cap} between {ref.obj} and me, and none of them mattered much.", voice = "warm" },
        { "Died {times:myDeaths}. {ref} {times:theirDeaths}.", voice = "terse" },
    },
})
