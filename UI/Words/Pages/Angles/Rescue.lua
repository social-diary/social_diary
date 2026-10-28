-- Rescue (PAGE-11): someone stepped into my fight.
--
-- saved facts (the planner's, from the combat log)
--   who          the person who stepped in
--   pct          my health when they stepped in, 1-60: the drama is banded
--                by it (under 5 a sliver, under 15, under 35, the rest)
--   foe          what I was fighting, { name, rank }; {foe:foe} gives "a
--                Thistlefur Shaman", or a rare's own name
--   timesSaved   times they have saved me, this one included (1+)
--   firstByThem  timesSaved is 1
--   grouped      we were in a group at the time
--
-- helped facts (a beat is one or the other: helped never has pct)
--   who, foe, grouped
--   died         I died anyway
--
-- The log shows that they fought what I was fighting, not how: no heals,
-- no damage, and nothing about the foe dying. So they "stepped in",
-- "joined the fight", "came to my aid", "pulled me out of it"; never
-- "healed me" or "killed it".
--
-- Tags these words say beyond their slots (prefixed "rescue." when the
-- words are declared, so another angle's tags about the same person on the
-- same page can't block these):
--   act      the rescue or the help itself: every sentence must say it
--   they     a clause with them as its subject ("{ref} stepped in")
--   me       a clause with me (or the foe) as its subject ("I was down to
--            6% when ..."). An opening that only reads before one of the
--            two says the other: "With my health at 6%, " says `me`, so it
--            never dangles in front of "I was losing ..."
--   scene    a clause that sets the scene and waits for a tail to say who
--            stepped in; openings that would repeat it say it too
--   low      words for how bad it was; `pct` as well when they describe my
--            health, so they don't sit next to the number
--   timing   "just in time" and its kind
--   sub      a when / until / before clause, so there's only one
--   react    my own reaction
--   rank     a remark on an elite or a rare
--   stranger says they were a stranger
--   two      "two against one" and its kind
--   extra    a remark about them (grouped, a stranger, a foe...), which an
--            opening about a repeat rescue would muddle
--   finish   says how it ended for me (helped)

local addonName, ns = ...

local Pages = ns.Pages
local Words = Pages.Words

Pages.Angle("rescue", { order = { "saved", "helped" },
    about = "someone stepped into my fight" })

local LOCAL = {
    act = true, they = true, me = true, scene = true, low = true, timing = true, sub = true,
    react = true, rank = true, stranger = true, two = true, extra = true, finish = true,
    ["and"] = true, though = true, before = true,
}
local function Tag(t)
    return LOCAL[t] and ("rescue." .. t) or t
end

-- Copies the pieces in `list`, adding `add` to what each says and, when a
-- piece says neither `me` nor `they`, `side`; this file's own tags get
-- their prefix.
local function Prep(list, add, side)
    local out = {}
    for i, raw in ipairs(list or {}) do
        local p = type(raw) == "string" and { raw } or raw
        local q = {}
        for k, v in pairs(p) do q[k] = v end
        local has = {}
        for _, t in ipairs(p.says or {}) do has[t] = true end
        for _, t in ipairs(add or {}) do has[t] = true end
        if side and not has.me and not has.they then has[side] = true end
        -- "..., and " meeting ", and ..." reads as a list: one per sentence.
        local text = p[1]
        if text:find(", and ", 1, true) or text:find(" and $") or text:find("^, and ") then has["and"] = true end
        if text:find("%f[%a]though%f[%A]") then has.though = true end
        if text:find("%f[%a]before%f[%A]") then has.before = true end
        local says = {}
        for t in pairs(has) do says[#says + 1] = Tag(t) end
        q.says = says
        for _, c in ipairs(p.needs or {}) do
            if c == "!who.familiar" then q[1] = "{rescue_first}" .. q[1] end
        end
        out[i] = q
    end
    return out
end

local function Add(move, spec)
    local s = { needs = spec.needs }
    if spec.must then
        s.must = {}
        for i, t in ipairs(spec.must) do s.must[i] = Tag(t) end
    end
    for _, kind in ipairs({ "stems", "clauses", "fragments", "tails", "wholes" }) do
        if spec[kind] then s[kind] = spec[kind] end
    end
    Words("rescue", move, s)
end

local function Needs(...)
    local out = {}
    for _, part in ipairs({ ... }) do
        if type(part) == "string" then
            out[#out + 1] = part
        else
            for _, c in ipairs(part) do out[#out + 1] = c end
        end
    end
    return out
end

-- {rescue_known}: writes nothing when the person goes by name or is
-- familiar, and fails otherwise. Lines about a repeat rescue start with
-- it, so "a night elf hunter bailed me out again" can't read as someone
-- new; the "same {desc} as before" lines cover the rest.
Pages.Slot("rescue_known", {
    needs = function() return { "who" } end,
    fn = function(env)
        local p = env.f.who
        if type(p) == "table" and (p.diary or p.named or p.familiar) then return "" end
        return nil
    end,
})

-- {rescue_first}: writes nothing when the person hasn't come up in an earlier
-- sentence of the page, and fails otherwise. A line that calls them a stranger starts
-- with it (Prep adds it to every piece that needs !who.familiar), so "a
-- stranger lent a hand: the warrior" can't follow an earlier mention.
Pages.Slot("rescue_first", {
    needs = function() return { "who" } end,
    fn = function(env)
        local p = env.f.who
        if type(p) ~= "table" then return nil end
        local key = p.id or p.name or tostring(p)
        if env.ctx.mentioned[key] then return nil end
        return ""
    end,
})

-- {rescue_down}: "down to" before a low health, "at" before one that
-- isn't ("I was down to 6%", "I was at 52%").
Pages.Slot("rescue_down", {
    needs = function() return { "pct" } end,
    fn = function(env)
        local pct = env.f.pct
        if type(pct) ~= "number" then return nil end
        return pct < 35 and "down to" or "at"
    end,
})

-- My own reaction to being pulled out of it, as a short sentence.
Pages.Bank("rescue.relief", {
    { "That was close.", needs = { "pct<15" } },
    { "Too close for comfort.", needs = { "pct<15" } },
    { "I was lucky.", needs = { "pct<10" } },
    "I was glad of it.",
    "I'll not complain.",
    { "I won't forget that one.", needs = { "pct<35" }, voice = "warm" },
    { "I was very glad to see {him}.", voice = "warm" },
    { "I'll take it.", voice = "wry" },
    { "Not my proudest moment.", voice = "wry" },
    { "Close.", needs = { "pct<15" }, voice = "terse" },
})

-- Someone nobody named and I don't know by sight.
local STRANGER = { "!who.diary", "!who.named", "!who.familiar" }
-- ...who has never saved me before.
local STRANGER_ONCE = Needs(STRANGER, "timesSaved<2")
-- ...and has a race or class to describe.
local DESCRIBED = "who.class ~= __nil"
-- A repeat rescue; the text starts with {rescue_known}.
local AGAIN = { "timesSaved>=2" }
-- A repeat rescue by someone known only by how they look.
local AGAIN_DESC = { "timesSaved>=2", "!who.diary", "!who.named" }
-- The first time a diary entry has had to.
local FIRST = { "firstByThem", "who.diary" }

-- How much a repeat rescue counts: enough that it's nearly always said.
local REPEAT = 2.5
-- Grouped or not is worth saying now and then, not every time.
local GROUPED = -0.9
local UNGROUPED = -1.1
local FIRSTB = -1.7
-- Remarks about who they are: in the draw, not crowding it.
local WHO = -0.5

--------------------------------------------------------------------------
-- saved: they stepped in when I was low, and I lived
--------------------------------------------------------------------------

Add("saved", {
    must = { "act" },
    needs = { "pct" },

    stems = Prep({
        { "With my health at {pct:pct}, ", says = { "me" } },
        { "With {pct:pct} of my health left, ", says = { "me" } },
        { "With me at {pct:pct} and falling, ", says = { "me" } },
        { "I was {rescue_down} {pct:pct}, and ", says = { "me" } },
        { "I was {rescue_down} {pct:pct} against {foe:foe}, and ", says = { "me" } },
        { "{foe.cap:foe} had me {rescue_down} {pct:pct}, and ", says = { "me", "low" } },
        "In the middle of my fight with {foe:foe}, ",
        { "Against {foe:foe}, ", bonus = -0.5 },
        { "{today.cap}, ", bonus = -0.5 },
        { "Just when I thought I was done for, ", needs = { "pct<15" }, says = { "low", "me" } },
        { "{foe.cap:foe} had me on the ropes, and ", needs = { "pct<15" }, says = { "low", "me" } },
        { "I was a hit or two from dead, and ", needs = { "pct<5" }, says = { "low", "pct", "me" } },
        { "With me on a sliver of health, ", needs = { "pct<5" }, says = { "low", "pct", "me" } },
        { "I was hanging on by a thread against {foe:foe}, and ", needs = { "pct<5" }, says = { "low", "pct", "me" } },
        { "I was losing to {foe:foe}, and ", needs = { "pct<35" }, says = { "low", "me" } },
        { "Things had got out of hand with {foe:foe}, and ", needs = { "pct<35" }, says = { "low", "me" } },
        { "It was going wrong against {foe:foe}, and ", needs = { "pct>=15" }, says = { "low", "me" } },
        { "The fight with {foe:foe} was turning against me, and ", needs = { "pct>=35" }, says = { "low", "me" } },
        { "Not for the first time, {rescue_known}", needs = AGAIN, says = { "timesSaved", "me", "extra" }, bonus = REPEAT },
        { "For the {nth:timesSaved} time, {rescue_known}", needs = AGAIN, says = { "me", "extra" }, bonus = REPEAT },
        { "Once again, {rescue_known}", needs = AGAIN, says = { "timesSaved", "me", "extra" }, bonus = REPEAT },
        { "Good thing I was in a group: ", needs = { "grouped" }, bonus = GROUPED },
        { "Out of nowhere, ", needs = { "!grouped" }, says = { "grouped", "me" } },
        { "Luckily for me, ", says = { "react", "me" } },
        { "Thankfully, ", says = { "react", "me" }, voice = "warm" },
        { "When I needed it most, ", needs = { "pct<15" }, says = { "low", "me" }, voice = "warm" },
        { "I'd bitten off more than I could chew with {foe:foe}, and ", needs = { "pct<35" }, says = { "low", "me" }, voice = "wry" },
        { "The {foename:foe} was elite, and it showed: ", needs = { "foe.rank==elite" }, says = { "rank", "they", "foe" }, bonus = 0.5 },
        { "I'd picked a fight with an elite {foename:foe}, and ", needs = { "foe.rank==elite" }, says = { "rank", "me", "foe" }, bonus = 0.5, voice = "wry" },
        { "{foe.cap:foe} isn't a rare for nothing: ", needs = { "foe.rank==rare" }, says = { "rank", "they" }, bonus = 0.5, voice = "wry" },
        { "{foe.cap:foe}, a rare, had me {rescue_down} {pct:pct}, and ", needs = { "foe.rank==rare" }, says = { "rank", "me" }, bonus = 0.5 },
        { "{foe.cap:foe}, a rare elite, had me {rescue_down} {pct:pct}, and ", needs = { "foe.rank==rareelite" }, says = { "rank", "me" }, bonus = 0.5 },
        { "{pct.cap:pct} left. ", says = { "me" }, voice = "terse" },
        { "Low and losing: ", needs = { "pct<35" }, says = { "low", "me" }, voice = "terse" },
    }),

    clauses = Prep({
        "{ref} stepped in",
        "{ref} came to my aid",
        "{ref} pulled me out of it",
        "{ref} bailed me out",
        "{ref} got me out of trouble",
        "{ref} joined the fight",
        "{ref} stepped in against {foe:foe}",
        "{ref} came to my aid against {foe:foe}",
        "{ref} joined my fight with {foe:foe}",
        "{ref} pulled me out of a fight with {foe:foe}",
        "{ref} got me out from under {foe:foe}",
        "{ref} rescued me from {foe:foe}",
        { "{ref} stepped in when I was {rescue_down} {pct:pct}", says = { "sub" } },
        "{ref} came to my aid with my health at {pct:pct}",
        "{ref} got stuck in with me on {pct:pct}",
        "help came from {ref.obj}",
        "it was {ref.noun} who pulled me out of it",
        { "I was {rescue_down} {pct:pct} when {ref} stepped in", says = { "sub", "me" } },
        { "I had {pct:pct} of my health left when {ref} came to my aid", says = { "sub", "me" } },
        { "{foe:foe} had me {rescue_down} {pct:pct} before {ref} stepped in", says = { "sub", "me", "low" } },
        { "{foe:foe} nearly had me, but {ref} stepped in", needs = { "pct<15" }, says = { "low", "me" } },
        { "{foe:foe} was winning until {ref} joined in", needs = { "pct<35" }, says = { "low", "sub", "me" } },
        { "I was losing until {ref} got involved", needs = { "pct<35" }, says = { "low", "sub", "me" } },
        { "{ref} stepped into a fight I was losing", needs = { "pct<35" }, says = { "low" } },
        { "{ref} got me out of a fight I was losing", needs = { "pct<35" }, says = { "low" } },
        { "{ref} came to my aid with me hanging on by a thread", needs = { "pct<5" }, says = { "low", "pct" } },
        { "{ref} stepped in with me a hit or two from dead", needs = { "pct<5" }, says = { "low", "pct" } },
        { "{ref} pulled me back from the brink", needs = { "pct<5" }, says = { "low" } },
        { "{ref} stepped in just in time", needs = { "pct<15" }, says = { "timing" } },
        { "{ref} had my back", voice = "warm" },
        { "{ref} came to my rescue", voice = "warm" },
        { "{ref} was there when I needed it", voice = "warm" },
        { "{ref} saved my skin", voice = "wry" },
        { "{ref} saved my bacon against {foe:foe}", voice = "wry" },
        { "{ref} probably spared me a walk back from the graveyard", needs = { "pct<10" }, says = { "react" }, voice = "wry" },
        { "rescue came in the shape of {ref.obj}", voice = "wry" },
        { "it took {ref.obj} to get me out of that one", voice = "wry" },
        { "{ref} pulled me out", voice = "terse" },
        { "{ref} got involved", voice = "terse" },
        { "{ref} was in my group, and stepped in", needs = { "grouped" }, says = { "extra" }, bonus = GROUPED },
        { "{ref} stepped in, which is what groups are for", needs = { "grouped" }, says = { "extra" }, voice = "wry", final = true, bonus = GROUPED },
        { "{ref} wasn't even in my group, but stepped in all the same", needs = { "!grouped", "who.diary" }, says = { "grouped", "extra" }, bonus = UNGROUPED },
        { "a stranger, {desc.a}, stepped in", needs = Needs(STRANGER_ONCE, DESCRIBED), says = { "stranger", "extra" }, bonus = WHO - 0.25 },
        { "a stranger came to my aid: {ref.noun}", needs = STRANGER_ONCE, says = { "stranger", "extra" }, final = true, bonus = WHO },
        { "{rescue_known}{ref} pulled me out of trouble <again>", needs = AGAIN, says = { "timesSaved" }, bonus = REPEAT },
        { "{rescue_known}{ref} came to my rescue for the {nth:timesSaved} time", needs = AGAIN, bonus = REPEAT },
        { "{rescue_known}{ref} bailed me out once more", needs = AGAIN, says = { "timesSaved" }, bonus = REPEAT, voice = "wry" },
        { "{rescue_known}{ref} stepped in again, as {he} has before", needs = AGAIN, says = { "timesSaved" }, bonus = REPEAT, final = true, voice = "warm" },
        { "the same {desc} as before stepped in", needs = AGAIN_DESC, says = { "timesSaved" }, bonus = REPEAT - 0.5 },
        { "that {desc} pulled me out of trouble again", needs = AGAIN_DESC, says = { "timesSaved" }, bonus = REPEAT - 0.5 },
        { "{ref} pulled me out of trouble for the first time", needs = FIRST, bonus = FIRSTB },
        { "{ref} got me out from under {foe:foe}, an elite I'd underestimated", needs = { "foe.rank==elite" }, says = { "rank", "extra" }, bonus = 0.5, voice = "wry", final = true },
        { "{ref} stepped in against {foe:foe}, which was more than I could handle", needs = { "foe.rank~=normal", "pct<35" }, says = { "rank", "low", "extra" }, bonus = 0.25, final = true },
        { "{ref.short}, of all people, stepped in", needs = { "who.tags.avoid" }, says = { "extra" }, bonus = WHO, voice = "wry" },
        { "{ref} stepped in, enemy colours and all", needs = { "who.hostile" }, says = { "extra" }, bonus = WHO },
    }, { "act" }, "they"),

    fragments = Prep({
        "Saved by {ref.obj}",
        "Saved by {ref.obj} at {pct:pct}",
        "Bailed out by {ref.obj}",
        "Bailed out by {ref.obj} against {foe:foe}",
        "Pulled out of a fight with {foe:foe} by {ref.obj}",
        "Rescued by {ref.obj}, with {pct:pct} of my health left",
        "{rescue_down.cap} {pct:pct} and saved by {ref.obj}",
        "Out of trouble, thanks to {ref.obj}",
        { "Hauled out of a losing fight by {ref.obj}", needs = { "pct<35" }, says = { "low" } },
        { "A narrow escape, thanks to {ref.obj}", needs = { "pct<15" }, says = { "low" } },
        { "In trouble with {foe:foe} until {ref.noun.short} stepped in", needs = { "pct<35" }, says = { "low", "sub" } },
        { "Nearly dead, then {ref.noun.short}", needs = { "pct<15" }, says = { "low", "pct" }, voice = "terse" },
        { "{pct.cap:pct} left, and then {ref.noun.short}", voice = "terse" },
        { "{foe.cap:foe}, {pct:pct} left, {ref.noun.short} to the rescue", voice = "terse" },
        { "{ref.noun.short} to the rescue", voice = "wry" },
        { "Saved, and not by my own efforts: {ref.noun} stepped in", voice = "wry", final = true },
        { "Saved again by {rescue_known}{ref.obj}", needs = AGAIN, says = { "timesSaved" }, bonus = REPEAT },
        { "Another rescue from {rescue_known}{ref.obj}", needs = AGAIN, says = { "timesSaved" }, bonus = REPEAT },
        { "Rescue number {num:timesSaved} from {rescue_known}{ref.obj}", needs = AGAIN, bonus = REPEAT, voice = "wry" },
        { "Saved by {rescue_known}{ref.obj} for the {nth:timesSaved} time", needs = AGAIN, bonus = REPEAT },
        { "Saved by the same {desc} as before", needs = AGAIN_DESC, says = { "timesSaved" }, bonus = REPEAT - 0.5 },
        { "First rescue by {ref.obj}", needs = FIRST, bonus = FIRSTB, voice = "terse" },
        { "Saved by a stranger: {ref.noun}", needs = STRANGER_ONCE, says = { "stranger" }, final = true, bonus = WHO },
        { "Grateful to {ref.obj} for stepping in", says = { "react" }, voice = "warm" },
    }, { "act" }),

    wholes = Prep({
        { "{ref} stepped in when I was {rescue_down} {pct:pct}. <rescue.relief>", says = { "react" }, lead = true },
        "I was {rescue_down} {pct:pct} against {foe:foe} when {ref} stepped in.",
        "{foe.cap:foe} had me {rescue_down} {pct:pct}. Then {ref} stepped in.",
        { "{ref} pulled me out of a fight with {foe:foe} {today}. I had {pct:pct} left.", lead = true },
        "I had {pct:pct} of my health left when {ref} came to my aid.",
        "Rescued {today}: {foe:foe} had me {rescue_down} {pct:pct}, and {ref} stepped in.",
        { "{ref} came to my aid against {foe:foe} {today}.", lead = true, bonus = -0.5 },
        "My health read {pct:pct} when {ref} joined the fight against {foe:foe}.",
        { "{pct.cap:pct}. That's how low I was when {ref} stepped in.", needs = { "pct<15" }, says = { "low" } },
        { "A sliver of health, {pct:pct}, and {foe:foe} still on me. Then {ref} stepped in.", needs = { "pct<5" }, says = { "low" } },
        { "{foe.cap:foe} nearly had me {today}. {ref} stepped in at {pct:pct}.", needs = { "pct<15" }, says = { "low" } },
        { "Without {ref.obj}, I think {foe:foe} would have had me.", needs = { "pct<15" }, says = { "low" } },
        { "I came out of a fight with {foe:foe} alive, thanks to {ref.obj}.", needs = { "pct<35" } },
        { "It was going badly with {foe:foe}, {pct:pct} and falling, until {ref} joined in.", needs = { "pct<35" }, says = { "low" } },
        { "{ref} stepped in with my health at {pct:pct}. It hadn't been going well.", needs = { "pct>=15" }, says = { "low" } },
        { "Things were getting uncomfortable with {foe:foe}, my health at {pct:pct}, when {ref} joined the fight.", needs = { "pct>=35" }, says = { "low" } },
        { "It wasn't desperate yet at {pct:pct}, but I was glad when {ref} joined my fight with {foe:foe}.", needs = { "pct>=35" }, says = { "low", "react" } },
        { "{today.cap} nearly ended badly. {ref} stepped in when I was {rescue_down} {pct:pct}.", needs = { "pct<15" }, says = { "low" } },
        { "My fight with {foe:foe} was slipping away from me when {ref} stepped in.", needs = { "pct>=15", "pct<35" }, says = { "low" }, lead = true },
        { "Help came from {ref.obj} {today}, with {foe:foe} getting the better of me.", needs = { "pct<35" }, says = { "low" } },
        { "One more hit and I'd have been dead, or near enough. {ref} stepped in at {pct:pct}.", needs = { "pct<5" }, says = { "low" } },
        { "I owe {ref.obj} one: {he} stepped in when I was {rescue_down} {pct:pct}.", voice = "warm" },
        { "{ref} had my back against {foe:foe} {today}. I was {rescue_down} {pct:pct}, and glad of the help.", says = { "react" }, voice = "warm" },
        { "{ref} came to my aid {today} with my health at {pct:pct}. I won't forget it.", needs = { "pct<35" }, says = { "react" }, voice = "warm" },
        { "Some days you need rescuing. {today.cap}, {ref} did the honours.", voice = "warm" },
        { "I was {rescue_down} {pct:pct} and out of ideas when {ref} stepped in. Thank goodness.", needs = { "pct<15" }, says = { "low", "react" }, voice = "warm" },
        { "{foe.cap:foe} had me, or very nearly. {ref} stepped in, and I'm grateful.", needs = { "pct<15" }, says = { "low", "react" }, voice = "warm" },
        { "Saved by {ref.obj} at {pct:pct}. Not my finest fight.", voice = "wry" },
        { "{foe.cap:foe} had me {rescue_down} {pct:pct} before {ref} got involved. I'll take the help.", voice = "wry" },
        { "If {ref} hadn't stepped in, I'd probably have been walking back from the graveyard.", needs = { "pct<5" }, says = { "low" }, voice = "wry" },
        { "{ref} stepped in. I was at {pct:pct}, and not proud of it.", voice = "wry" },
        { "I'd like to say I had {foe:foe} under control. I was at {pct:pct} when {ref} stepped in.", voice = "wry" },
        { "{foe.cap:foe} and I disagreed about who should win, and I was losing the argument at {pct:pct}. Then {ref} joined in.", voice = "wry" },
        { "The {foename:foe} was elite and I was not. {ref} stepped in at {pct:pct}.", needs = { "foe.rank==elite" }, says = { "rank", "foe" }, bonus = 0.5, voice = "wry" },
        { "{foe.cap:foe} is a rare for a reason. {ref} pulled me out of that fight at {pct:pct}.", needs = { "foe.rank==rare" }, says = { "rank" }, bonus = 0.5, voice = "wry" },
        { "{pct.cap:pct} left. {ref.short} stepped in.", voice = "terse" },
        { "Close call with {foe:foe}. {ref.short} pulled me out.", needs = { "pct<15" }, says = { "low" }, voice = "terse" },
        { "{rescue_down.cap} {pct:pct}. {ref.short} stepped in. Lived.", voice = "terse" },
        { "{foe.cap:foe}. {pct.cap:pct}. Saved by {ref.short}.", voice = "terse" },
        { "Bad fight. {ref.short} got me out of it.", needs = { "pct<35" }, says = { "low" }, voice = "terse" },
        { "{rescue_known}{ref} bailed me out again {today}. That's {times:timesSaved} now.", needs = AGAIN, bonus = REPEAT, lead = true },
        { "For the {nth:timesSaved} time, {rescue_known}{ref} stepped in when I needed it.", needs = AGAIN, bonus = REPEAT },
        { "{rescue_known}{ref} stepped in when I was {rescue_down} {pct:pct}, and not for the first time.", needs = AGAIN, says = { "timesSaved" }, bonus = REPEAT },
        { "This time it was {foe:foe}, and I was {rescue_down} {pct:pct}. {rescue_known}{ref} stepped in, as {he} has before.", needs = AGAIN, says = { "timesSaved" }, bonus = REPEAT },
        { "{rescue_known}{ref} pulled me out of trouble again {today}. That makes {times:timesSaved}, and I'm starting to count on it.", needs = { "timesSaved>=3" }, bonus = REPEAT, voice = "warm" },
        { "{rescue_known}{ref} has now saved me {times:timesSaved}. I should probably just follow {him} around.", needs = { "timesSaved>=3" }, bonus = REPEAT, voice = "wry" },
        { "{rescue_known}{ref} again, {rescue_down} {pct:pct} again. I'm making a habit of this.", needs = AGAIN, says = { "timesSaved" }, bonus = REPEAT, voice = "wry" },
        { "Saved by {rescue_known}{ref.short} again. {times.cap:timesSaved} now.", needs = AGAIN, bonus = REPEAT, voice = "terse" },
        { "The same {desc} as before pulled me out of trouble {today}.", needs = AGAIN_DESC, says = { "timesSaved" }, bonus = REPEAT - 0.5 },
        { "It was that {desc} again who stepped in, with me {rescue_down} {pct:pct}.", needs = AGAIN_DESC, says = { "timesSaved" }, bonus = REPEAT - 0.5 },
        { "{ref} pulled me out of trouble {today}, the first time {he} has had to.", needs = FIRST, bonus = FIRSTB, voice = "wry" },
        { "It was the first time {ref} had ever had to bail me out.", needs = FIRST, bonus = FIRSTB },
        { "Good thing {ref} was in my group: {he} stepped in when I was {rescue_down} {pct:pct}.", needs = { "grouped" }, bonus = GROUPED },
        { "{ref} and I were grouped, which was lucky: I was {rescue_down} {pct:pct} when {he} stepped in.", needs = { "grouped" }, bonus = GROUPED },
        { "{ref} wasn't even in my group, but {he} stepped in when I was {rescue_down} {pct:pct}.", needs = { "!grouped", "who.diary" }, says = { "grouped" }, bonus = UNGROUPED },
        { "A stranger saved me {today}: {ref} stepped in when I was {rescue_down} {pct:pct}.", needs = STRANGER_ONCE, says = { "stranger" }, bonus = WHO },
        { "I don't know {ref.obj}, but {he} stepped in against {foe:foe} when I needed it.", needs = STRANGER_ONCE, says = { "stranger" }, bonus = WHO, voice = "warm" },
        { "Tangling with {foe:foe} was ambitious. I was {rescue_down} {pct:pct} when {ref} stepped in.", needs = { "foe.rank==rareelite" }, says = { "rank" }, bonus = 0.5 },
        { "{foe.cap:foe}, a rare elite, was more than I could manage alone. {ref} pulled me out of it.", needs = { "foe.rank==rareelite", "!grouped" }, says = { "rank" }, bonus = 0.5 },
        { "{foe.cap:foe} is no pushover. It had me at {pct:pct} when {ref} came to my aid.", needs = { "foe.rank==rare" }, says = { "rank" }, bonus = 0.5 },
        { "The {foename:foe} was elite, and it had me {rescue_down} {pct:pct} before {ref} stepped in.", needs = { "foe.rank==elite" }, says = { "rank", "foe" }, bonus = 0.5 },
        { "{ref.short}, of all people, pulled me out of a fight with {foe:foe}. I may have to think again about {him}.", needs = { "who.tags.avoid" }, bonus = WHO },
        { "{ref} is in my diary as a foe, and yet {he} stepped in when I was {rescue_down} {pct:pct}.", needs = { "who.tags.foe" }, bonus = WHO },
        { "Of course it was {ref.noun} who stepped in. I was {rescue_down} {pct:pct}.", needs = { "who.tags.friend" }, bonus = WHO, voice = "warm" },
        { "{ref} stepped in {today}, enemy colours and all, when I was {rescue_down} {pct:pct}.", needs = { "who.hostile" }, bonus = WHO },
    }, { "act" }),
})

-- My side of it first, then who stepped in, as whole clauses.
Add("saved", {
    clauses = Prep({
        { "I was losing to {foe:foe} until {ref} stepped in", needs = { "pct<35" }, says = { "low", "sub" } },
        { "I had a sliver of health left when {ref} stepped in", needs = { "pct<5" }, says = { "low", "pct", "sub" } },
        { "{foe:foe} had me on the ropes until {ref} joined the fight", needs = { "pct<15" }, says = { "low", "sub" } },
        { "I was nearly done for against {foe:foe} when help came from {ref.obj}", needs = { "pct<15" }, says = { "low", "sub" } },
        { "my fight with {foe:foe} was going badly, and then {ref} stepped in", needs = { "pct>=15" }, says = { "low" } },
        { "{foe:foe} had me {rescue_down} {pct:pct}, at which point {ref} joined the fight", says = { "low" } },
        { "I was {rescue_down} {pct:pct} against {foe:foe}, and {ref} bailed me out" },
        { "I was in trouble with {foe:foe} before {ref} came to my aid", needs = { "pct<35" }, says = { "low", "sub" } },
        { "I was nearly done for when {ref} stepped in, just in time", needs = { "pct<15" }, says = { "low", "sub", "timing" }, final = true },
        { "I was {rescue_down} {pct:pct}, and {ref} came to my rescue", voice = "warm" },
        { "I was trading blows with {foe:foe}, and losing, when {ref} got stuck in", needs = { "pct<35" }, says = { "low", "sub" }, voice = "wry" },
        { "I was on {pct:pct}, then {ref} was in it too", voice = "terse" },
    }, { "act", "me" }),

    fragments = Prep({
        { "On my last legs against {foe:foe} until {ref.noun.short} stepped in", needs = { "pct<5" }, says = { "low", "pct", "sub" } },
        { "{rescue_down.cap} {pct:pct} against {foe:foe} when {ref.noun.short} stepped in", needs = { "pct<35" }, says = { "sub" } },
        { "Losing to {foe:foe}, and then {ref.noun.short} got involved", needs = { "pct<35" }, says = { "low" }, voice = "wry" },
    }, { "act" }),

    tails = Prep({
        -- after the rescue itself
        ", with me {rescue_down} {pct:pct}",
        ", with my health at {pct:pct}",
        { " when I was {rescue_down} {pct:pct}", says = { "sub" } },
        ", with {pct:pct} of my health left",
        { " when {foe:foe} had me {rescue_down} {pct:pct}", says = { "sub" } },
        { ", just in time", needs = { "pct<15" }, says = { "timing" } },
        { " in the nick of time", needs = { "pct<15" }, says = { "timing" } },
        { ", and not a moment too soon", needs = { "pct<5" }, says = { "timing" } },
        { ", with me on a sliver of health", needs = { "pct<5" }, says = { "low", "pct" } },
        { " when I was about to go down", needs = { "pct<5" }, says = { "low", "pct", "sub" } },
        { " before {foe:foe} could finish me", needs = { "pct<15" }, says = { "low", "sub" } },
        { ", with {foe:foe} getting the better of me", needs = { "pct<35" }, says = { "low" } },
        { ", which I appreciated", says = { "react" } },
        { ", which was a relief", says = { "react" } },
        { ", and I was glad of it", says = { "react" }, voice = "warm" },
        { ", and I'm grateful", says = { "react" }, voice = "warm" },
        { ", and I won't forget it", needs = { "pct<35" }, says = { "react" }, voice = "warm" },
        { ", so I lived to write this", says = { "react" }, voice = "wry" },
        { ", probably sparing me a walk from the graveyard", needs = { "pct<10" }, says = { "react" }, voice = "wry" },
        { ", which was humbling", says = { "react" }, voice = "wry" },
        { ", me on {pct:pct}", voice = "terse" },
        { ", the {nth:timesSaved} time {rescue_known}{he} has done that", needs = AGAIN, says = { "timesSaved" }, bonus = REPEAT },
        { ", which makes {rescue_known}{count:timesSaved:rescue} now", needs = AGAIN, says = { "timesSaved" }, bonus = REPEAT },
        { ", not for the first time{rescue_known}", needs = AGAIN, says = { "timesSaved" }, bonus = REPEAT },
        { ", as before{rescue_known}", needs = AGAIN, says = { "timesSaved" }, bonus = REPEAT },
        { ", again{rescue_known}", needs = AGAIN, says = { "timesSaved" }, bonus = REPEAT, voice = "wry" },
        { ", which is becoming a habit{rescue_known}", needs = { "timesSaved>=3" }, says = { "timesSaved" }, bonus = REPEAT, voice = "wry" },
        { ", the first time {he} has had to", needs = FIRST, bonus = FIRSTB, voice = "wry" },
        { ", the first time {he} has bailed me out", needs = FIRST, bonus = FIRSTB },
        { ", grouped as we were", needs = { "grouped" }, bonus = GROUPED - 0.25 },
        { ", which is what groupmates are for", needs = { "grouped" }, bonus = GROUPED, voice = "wry" },
        { ", though we weren't even grouped", needs = { "!grouped", "who.diary" }, says = { "grouped" }, bonus = UNGROUPED },
        { ", a stranger doing me a good turn", needs = STRANGER_ONCE, says = { "stranger" }, bonus = WHO, voice = "warm" },
        { " against {foe:foe}, an elite I had no business taking on alone", needs = { "foe.rank==elite", "!grouped" }, says = { "rank" }, bonus = 0.5, voice = "wry" },
        { " against {foe:foe}, a rare that nearly had me", needs = { "foe.rank==rare", "pct<15" }, says = { "rank", "low" }, bonus = 0.5 },
        { " against {foe:foe}, a rare elite", needs = { "foe.rank==rareelite" }, says = { "rank" }, bonus = 0.5 },
    }),
})

--------------------------------------------------------------------------
-- helped: they fought my foe with me; sometimes I died anyway
--------------------------------------------------------------------------
--
-- When I died, the sentence must say so: every piece that does gets a
-- bonus big enough that a sentence leaving it out falls out of the draw.
-- Pieces that say I died, or came through, say `finish`.

local DIED = 2

Add("helped", {
    must = { "act" },
    needs = { "!pct" },

    stems = Prep({
        "Against {foe:foe}, ",
        "In my fight with {foe:foe}, ",
        "With {foe:foe} on me, ",
        { "{today.cap}, ", bonus = -0.5 },
        { "Mid-fight, ", says = { "scene", "me", "foe" } },
        { "Before I went down, ", needs = { "died" }, says = { "scene", "me", "finish" }, bonus = DIED },
        { "Before {foe:foe} finished me off, ", needs = { "died" }, says = { "scene", "me", "finish" }, bonus = DIED },
        { "I lost in the end, but not for want of help: ", needs = { "died" }, says = { "scene", "me", "finish" }, bonus = DIED },
        { "Not that it saved me, but ", needs = { "died" }, says = { "scene", "finish" }, bonus = DIED },
        { "For all the good it did, ", needs = { "died" }, says = { "scene", "finish" }, bonus = DIED, voice = "wry" },
        { "Though not in my group, ", needs = { "!grouped", "who.diary" }, says = { "grouped", "scene", "me" }, bonus = UNGROUPED },
        { "Out of the blue, ", needs = { "!grouped" }, says = { "grouped", "scene", "me" } },
        { "To my surprise, ", needs = { "!grouped" }, says = { "grouped", "react", "scene", "me" }, voice = "wry" },
        { "Happily, ", needs = { "!died" }, says = { "react", "scene", "me" }, voice = "warm" },
        { "I was glad of the company: ", says = { "react", "scene", "me" }, voice = "warm" },
        { "The {foename:foe} was elite, and ", needs = { "foe.rank==elite" }, says = { "rank", "foe" }, bonus = 0.15 },
        { "With a rare like {foe:foe} on me, ", needs = { "foe.rank==rare" }, says = { "rank" }, bonus = 0.15 },
        { "With a rare elite like {foe:foe} on me, ", needs = { "foe.rank==rareelite" }, says = { "rank" }, bonus = 0.15 },
        { "I'd taken on {foe:foe}, and ", voice = "wry" },
        { "{foe.cap:foe}. ", voice = "terse" },
    }),

    clauses = Prep({
        "{ref} joined in",
        "{ref} lent a hand",
        "{ref} pitched in",
        "{ref} joined in against {foe:foe}",
        "{ref} lent a hand against {foe:foe}",
        "{ref} gave me a hand with {foe:foe}",
        "{ref} joined my fight with {foe:foe}",
        "{ref} fought {foe:foe} alongside me",
        "{ref} and I fought {foe:foe} together",
        "{ref} helped me with {foe:foe}",
        "{ref} got stuck in",
        { "{ref} made it two against one", says = { "two" } },
        { "I had help with {foe:foe} from {ref.obj}", says = { "me" } },
        { "{foe:foe} suddenly had {ref.obj} to deal with as well", says = { "me", "two" } },
        { "{ref} had a go at {foe:foe} as well", voice = "wry" },
        { "{foe:foe} had two of us to deal with once {ref} joined in", says = { "me", "sub", "two" }, voice = "wry" },
        { "{ref} evened the odds against {foe:foe}", needs = { "foe.rank==elite" }, says = { "rank", "two" }, bonus = 0.15 },
        { "{ref} had my back against {foe:foe}", voice = "warm" },
        { "{ref} stood with me against {foe:foe}", voice = "warm" },
        { "{ref} weighed in", voice = "terse" },
        { "{ref} helped", voice = "terse" },
        { "{ref} joined in, but {foe:foe} killed me anyway", needs = { "died" }, says = { "finish" }, bonus = DIED, final = true },
        { "{ref} joined in against {foe:foe}, and I died anyway", needs = { "died" }, says = { "finish" }, bonus = DIED, final = true },
        { "{ref} lent a hand, not that it saved me", needs = { "died" }, says = { "finish" }, bonus = DIED, final = true },
        { "I died to {foe:foe} despite {ref.obj} joining in", needs = { "died" }, says = { "me", "finish" }, bonus = DIED },
        { "even with {ref.obj} fighting alongside, I went down", needs = { "died" }, says = { "me", "finish" }, bonus = DIED },
        { "I went down to {foe:foe} even with {ref.poss} help", needs = { "died" }, says = { "me", "finish" }, bonus = DIED },
        { "{ref.poss} help wasn't enough, and {foe:foe} got me", needs = { "died" }, says = { "me", "finish" }, bonus = DIED, final = true },
        { "{ref} fought {foe:foe} with me, and it still got me", needs = { "died" }, says = { "finish" }, bonus = DIED, final = true },
        { "{ref} pitched in, and I died all the same", needs = { "died" }, says = { "finish" }, bonus = DIED, final = true },
        { "{ref} and I took on {foe:foe} together, and I still lost", needs = { "died" }, says = { "finish" }, bonus = DIED, voice = "wry", final = true },
        { "{ref} joined in, which only delayed things a little", needs = { "died" }, says = { "finish" }, bonus = DIED, voice = "wry", final = true },
        { "{ref} joined in, and I came out of it in one piece", needs = { "!died" }, says = { "finish" }, final = true },
        { "{ref} helped me through a fight with {foe:foe}", needs = { "!died" }, says = { "finish" } },
        { "{ref} joined in, though I'd like to think I'd have managed", needs = { "!died" }, says = { "finish" }, voice = "wry", final = true },
        { "with {ref.poss} help, I got through a fight with {foe:foe}", needs = { "!died" }, says = { "me", "finish" } },
        { "{ref} was in my group and joined in against {foe:foe}", needs = { "grouped" }, bonus = GROUPED },
        { "{ref} did what groupmates do and joined in", needs = { "grouped" }, bonus = GROUPED, voice = "wry" },
        { "{ref} wasn't in my group, but joined in all the same", needs = { "!grouped", "who.diary" }, says = { "grouped" }, bonus = UNGROUPED },
        { "a stranger, {desc.a}, joined in", needs = Needs(STRANGER, DESCRIBED), says = { "stranger" }, bonus = WHO - 0.5 },
        { "a stranger lent a hand: {ref.noun}", needs = STRANGER, says = { "stranger" }, bonus = WHO - 0.25, final = true },
        { "{ref.short}, of all people, joined in against {foe:foe}", needs = { "who.tags.avoid" }, bonus = WHO, voice = "wry" },
        { "{ref} joined in, enemy colours and all", needs = { "who.hostile" }, bonus = WHO },
    }, { "act" }, "they"),

    fragments = Prep({
        "Help from {ref.obj} against {foe:foe}",
        "Joined by {ref.obj} against {foe:foe}",
        "Joined by {ref.obj}",
        { "Two against {foe:foe}, thanks to {ref.obj}", says = { "two" } },
        "Backed up by {ref.obj}",
        "A hand from {ref.obj}",
        { "{ref.noun.short} and me against {foe:foe}", says = { "two" }, voice = "terse" },
        { "Helped by {ref.obj}, killed anyway", needs = { "died" }, says = { "finish" }, bonus = DIED, voice = "terse" },
        { "Joined by {ref.obj}, and dead regardless", needs = { "died" }, says = { "finish" }, bonus = DIED, voice = "wry" },
        { "Help from {ref.obj}, for all the good it did", needs = { "died" }, says = { "finish" }, bonus = DIED, voice = "wry" },
        { "Dead to {foe:foe} despite {ref.poss} help", needs = { "died" }, says = { "finish" }, bonus = DIED },
        { "Killed by {foe:foe}, even with {ref.obj} alongside", needs = { "died" }, says = { "finish" }, bonus = DIED },
        { "Out of it alive, with a hand from {ref.obj}", needs = { "!died" }, says = { "finish" } },
        { "Through a fight with {foe:foe}, with {ref.obj} alongside", needs = { "!died" }, says = { "finish" } },
        { "A hand from a stranger, {ref.noun}", needs = STRANGER, says = { "stranger" }, bonus = WHO - 0.25, voice = "warm" },
        { "Glad of {ref.poss} help against {foe:foe}", needs = { "!died" }, says = { "react" }, voice = "warm" },
    }, { "act" }),

    wholes = Prep({
        { "{ref} joined in against {foe:foe} {today}.", lead = true, bonus = -0.5 },
        "I had help with {foe:foe} {today}: {ref} joined in.",
        { "{ref} lent me a hand with {foe:foe}.", lead = true },
        "I was fighting {foe:foe} when {ref} joined in.",
        "{foe.cap:foe} had me to itself until {ref} joined in.",
        "Two against one: {ref} joined my fight with {foe:foe}.",
        { "{ref} fought {foe:foe} alongside me {today}, and very welcome it was.", says = { "react" }, voice = "warm" },
        { "{ref} joined in against {foe:foe}, but I died anyway.", needs = { "died" }, bonus = DIED },
        { "Even with {ref.obj} fighting alongside, {foe:foe} killed me.", needs = { "died" }, bonus = DIED },
        { "{ref} pitched in against {foe:foe}. I died anyway, but I appreciated it.", needs = { "died" }, says = { "react" }, bonus = DIED },
        { "I went down to {foe:foe} {today}, though not for lack of help: {ref} had joined in.", needs = { "died" }, bonus = DIED },
        { "{ref.poss} help against {foe:foe} wasn't enough; I went down anyway.", needs = { "died" }, bonus = DIED },
        { "I lost to {foe:foe} {today} even with {ref.obj} on my side.", needs = { "died" }, bonus = DIED },
        { "{foe.cap:foe} got me in the end, despite {ref.poss} help.", needs = { "died" }, bonus = DIED },
        { "Two of us against {foe:foe}, and I still died. {ref} had joined in; it wasn't enough.", needs = { "died" }, bonus = DIED },
        { "{ref} joined in, and I still died, but I won't forget the help.", needs = { "died" }, says = { "react" }, bonus = DIED, voice = "warm" },
        { "{ref} fought {foe:foe} with me, and I went down anyway. I was glad not to be alone in it.", needs = { "died" }, says = { "react" }, bonus = DIED, voice = "warm" },
        { "{ref} and I against {foe:foe}, and I still died.", needs = { "died" }, bonus = DIED, voice = "wry" },
        { "Some fights are lost however many join in. {ref} joined mine with {foe:foe}, and I died anyway.", needs = { "died" }, bonus = DIED, voice = "wry" },
        { "{ref.short} joined in. Died anyway.", needs = { "died" }, bonus = DIED, voice = "terse" },
        { "Help from {ref.short}. Dead all the same.", needs = { "died" }, bonus = DIED, voice = "terse" },
        { "{ref} joined in against {foe:foe}, and I came out of it in one piece.", needs = { "!died" } },
        { "With {ref.poss} help, I got through a fight with {foe:foe}.", needs = { "!died" } },
        { "{ref} lent a hand against {foe:foe} {today}. I was glad of it.", needs = { "!died" }, says = { "react" }, voice = "warm" },
        { "It's good to have someone fight beside you. {today.cap}, that was {ref.noun}.", needs = { "!died" }, voice = "warm" },
        { "{ref} had my back against {foe:foe} {today}.", voice = "warm" },
        { "{ref} joined in against {foe:foe}. I like to think I'd have managed alone. I'll never know.", needs = { "!died" }, voice = "wry" },
        { "{foe.cap:foe} found itself outnumbered when {ref} joined in.", voice = "wry" },
        { "{foe.cap:foe} picked on me and got {ref.obj} as well.", voice = "wry" },
        { "{ref.short} joined in against {foe:foe}.", voice = "terse" },
        { "{foe.cap:foe}. {ref.short} helped.", voice = "terse" },
        { "Fought {foe:foe}. {ref.short} joined in. Lived.", needs = { "!died" }, voice = "terse" },
        { "{ref} and I were grouped, and {he} joined in against {foe:foe}.", needs = { "grouped" }, bonus = GROUPED },
        { "{ref} wasn't in my group, but joined in against {foe:foe} all the same.", needs = { "!grouped", "who.diary" }, says = { "grouped" }, bonus = UNGROUPED },
        { "A stranger lent a hand {today}: {ref} joined in against {foe:foe}.", needs = STRANGER, says = { "stranger" }, bonus = WHO - 0.25 },
        { "The {foename:foe} was elite, and {ref} joined in against it.", needs = { "foe.rank==elite" }, says = { "rank", "foe" }, bonus = 0.15 },
        { "Elites are easier with two. {ref} joined in against {foe:foe}.", needs = { "foe.rank==elite", "!died" }, says = { "rank" }, bonus = -0.1, voice = "wry" },
        { "{ref} joined in against {foe:foe}, a rare, and I wasn't sorry.", needs = { "foe.rank==rare" }, says = { "rank", "react" }, bonus = 0.15 },
        { "{ref} joined in against {foe:foe}, a rare elite, which I was glad of.", needs = { "foe.rank==rareelite" }, says = { "rank", "react" }, bonus = 0.15 },
        { "{ref.short}, of all people, joined in against {foe:foe}.", needs = { "who.tags.avoid" }, bonus = WHO, voice = "wry" },
        { "{ref} joined in against {foe:foe}, which I didn't expect from someone I've marked as a foe.", needs = { "who.tags.foe" }, bonus = WHO },
        { "{ref} joined in against {foe:foe}, as a friend would.", needs = { "who.tags.friend" }, bonus = WHO, voice = "warm" },
        { "{ref} joined in against {foe:foe}, enemy colours and all.", needs = { "who.hostile" }, bonus = WHO },
    }, { "act" }),
})

-- My side of it first, then who joined in, as whole clauses.
Add("helped", {
    clauses = Prep({
        { "I was fighting {foe:foe} when {ref} pitched in", says = { "sub" } },
        { "I was in a scrap with {foe:foe}, and {ref} got stuck in" },
        { "{foe:foe} and I were going at it when {ref} joined in", says = { "sub" }, voice = "wry" },
        { "I was fighting {foe:foe} when {ref} joined in, but I died anyway", needs = { "died" }, says = { "sub", "finish" }, bonus = DIED, final = true },
        { "I was in a scrap with {foe:foe}, and {ref} lent a hand, not that it saved me", needs = { "died" }, says = { "finish" }, bonus = DIED, final = true },
        { "I was holding my own against {foe:foe} when {ref} joined in", needs = { "!died" }, says = { "sub", "finish" } },
    }, { "act", "me" }),

    fragments = Prep({
        { "In a scrap with {foe:foe} when {ref.noun.short} joined in", says = { "sub" } },
        { "Fighting {foe:foe}, then {ref.noun.short} joined in", voice = "terse" },
    }, { "act" }),

    tails = Prep({
        { " against {foe:foe}", bonus = -0.25 },
        { ", which made it two against {foe:foe}", says = { "two" } },
        { ", which I appreciated", says = { "react" } },
        { ", and I was glad of the company", needs = { "!died" }, says = { "react" }, voice = "warm" },
        { ", and I was grateful", says = { "react" }, voice = "warm" },
        { ", but I died anyway", needs = { "died" }, says = { "finish" }, bonus = DIED },
        { ", not that it saved me", needs = { "died" }, says = { "finish" }, bonus = DIED },
        { ", but {foe:foe} got me all the same", needs = { "died" }, says = { "finish" }, bonus = DIED },
        { ", though I still went down", needs = { "died" }, says = { "finish" }, bonus = DIED },
        { ", for all the good it did me", needs = { "died" }, says = { "finish" }, bonus = DIED, voice = "wry" },
        { ", which didn't stop me dying", needs = { "died" }, says = { "finish" }, bonus = DIED, voice = "wry" },
        { ", and I still died", needs = { "died" }, says = { "finish" }, bonus = DIED, voice = "terse" },
        { ", and I came through it", needs = { "!died" }, says = { "finish" } },
        { ", and I came out of it in one piece", needs = { "!died" }, says = { "finish" } },
        { ", grouped as we were", needs = { "grouped" }, bonus = GROUPED },
        { ", which is what groups are for", needs = { "grouped", "!died" }, bonus = GROUPED, voice = "wry" },
        { ", though we weren't grouped", needs = { "!grouped", "who.diary" }, says = { "grouped" }, bonus = UNGROUPED },
        { ", a stranger lending a hand", needs = STRANGER, says = { "stranger" }, bonus = WHO - 0.25, voice = "warm" },
        { " against {foe:foe}, an elite", needs = { "foe.rank==elite" }, says = { "rank" }, bonus = 0.15 },
        { " against {foe:foe}, an elite I'd underestimated", needs = { "foe.rank==elite" }, says = { "rank" }, bonus = 0.15, voice = "wry" },
    }),
})

--------------------------------------------------------------------------
-- More in the warm and terse voices
--------------------------------------------------------------------------

Add("saved", {
    stems = Prep({
        { "To my great relief, ", says = { "react", "me" }, voice = "warm" },
        { "Just as I was losing heart, ", needs = { "pct<35" }, says = { "low", "me" }, voice = "warm" },
        { "When it mattered, ", says = { "me" }, voice = "warm" },
        { "{foe.cap:foe}, {pct:pct}: ", says = { "me" }, voice = "terse" },
    }),

    clauses = Prep({
        { "{ref} stepped in at just the right moment", needs = { "pct<15" }, says = { "timing" }, voice = "warm" },
        { "{ref} was a welcome sight against {foe:foe}", says = { "react" }, voice = "warm" },
        { "{ref} got me out of a tight spot", voice = "warm" },
        { "{ref} stepped in, and I could have hugged {him}", says = { "react" }, final = true, voice = "warm" },
        { "{ref} saved me", voice = "terse" },
        { "{ref} bailed me out at {pct:pct}", voice = "terse" },
    }, { "act" }, "they"),

    fragments = Prep({
        { "Rescued by {ref.obj}, and very glad of it", says = { "react" }, voice = "warm" },
        { "Never so glad of the help as when {ref.noun} stepped in", needs = { "pct<15" }, says = { "react", "sub" }, voice = "warm" },
        { "Pulled through by {ref.obj}", voice = "warm" },
        { "{ref.short}. {pct.cap:pct}. Saved", voice = "terse" },
        { "Rescued at {pct:pct} by {ref.short}", voice = "terse" },
    }, { "act" }),

    tails = Prep({
        { ", and I was very glad to see {him}", says = { "react" }, voice = "warm" },
        { ", which I'll remember", says = { "react" }, voice = "warm" },
        { ", when I needed it most", needs = { "pct<15" }, says = { "timing" }, voice = "warm" },
        { ". {pct.cap:pct} left", voice = "terse" },
        { ". Close one", needs = { "pct<15" }, says = { "react" }, voice = "terse" },
    }),

    wholes = Prep({
        { "I'll remember that {ref} stepped in {today}. I was {rescue_down} {pct:pct}.", voice = "warm" },
        { "Thank goodness for {ref.obj}. {foe.cap:foe} had me {rescue_down} {pct:pct}.", says = { "react" }, voice = "warm" },
        { "{foe.cap:foe} had me {rescue_down} {pct:pct}, and I was glad, very glad, when {ref} stepped in.", needs = { "pct<35" }, says = { "react" }, voice = "warm" },
        { "{ref} got me out of a fight with {foe:foe} {today}. It's good to have people like that about.", voice = "warm" },
        { "{rescue_known}{ref} came through for me again {today}. I'm lucky to have {him} about.", needs = AGAIN, says = { "timesSaved" }, bonus = REPEAT, voice = "warm" },
        { "A stranger, {ref.noun}, came to my aid {today}. I hope I get the chance to return the favour.", needs = STRANGER_ONCE, says = { "stranger" }, bonus = WHO, voice = "warm" },
        { "Nearly died. {ref.short} stepped in.", needs = { "pct<15" }, says = { "low" }, voice = "terse" },
        { "{rescue_known}{ref.short} again. {rescue_down.cap} {pct:pct}. Saved.", needs = AGAIN, says = { "timesSaved" }, bonus = REPEAT, voice = "terse" },
        { "In trouble against {foe:foe}. {ref.short} joined in. I lived.", needs = { "pct<35" }, says = { "low" }, voice = "terse" },
    }, { "act" }),
})

Add("helped", {
    clauses = Prep({
        { "{ref} joined in, and I was glad of it", says = { "react" }, final = true, voice = "warm" },
        { "{ref} lent a welcome hand against {foe:foe}", says = { "react" }, voice = "warm" },
        { "{ref} chipped in", voice = "terse" },
    }, { "act" }, "they"),

    fragments = Prep({
        { "A welcome hand from {ref.obj}", says = { "react" }, voice = "warm" },
        { "{foe.cap:foe}, with {ref.short}", voice = "terse" },
    }, { "act" }),

    tails = Prep({
        { ", and very welcome it was", says = { "react" }, voice = "warm" },
        { ", and I didn't feel so alone in it", says = { "react" }, voice = "warm" },
        { ". Died anyway", needs = { "died" }, says = { "finish" }, bonus = DIED, voice = "terse" },
    }),

    wholes = Prep({
        { "Good of {ref.obj} to join in against {foe:foe} {today}.", says = { "react" }, voice = "warm" },
        { "{ref} joined my fight with {foe:foe}, and I was grateful for it.", says = { "react" }, voice = "warm" },
        { "I died to {foe:foe} {today}, but not alone: {ref} had joined in. That meant something.", needs = { "died" }, says = { "react" }, bonus = DIED, voice = "warm" },
        { "{ref} joined in against {foe:foe}, and I came through it, glad of the help.", needs = { "!died" }, says = { "react" }, voice = "warm" },
        { "A stranger, {ref.noun}, joined my fight with {foe:foe}. I'd like to return the favour one day.", needs = STRANGER, says = { "stranger" }, bonus = WHO - 0.25, voice = "warm" },
        { "{foe.cap:foe}. {ref.short} and me. Still died.", needs = { "died" }, bonus = DIED, voice = "terse" },
        { "{ref.short} helped against {foe:foe}. Lived.", needs = { "!died" }, voice = "terse" },
    }, { "act" }),
})
