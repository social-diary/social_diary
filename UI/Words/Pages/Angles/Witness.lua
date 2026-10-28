-- Witness (PAGE-11): someone was near me when I died.
--
-- watched facts (the planner's, from the combat log and the people nearby)
--   who          the person who was there
--   watched      seconds they were near me during the fight that killed me
--   foe          what killed me, { name, rank }, when it was a creature
--   zone         where I died
--   subZone      where I died, more closely, if known
--   alsoHelped   they fought it too
--
-- The data says they were near me, not what they saw, thought or meant.
-- So they were "there", "nearby", "close by", "near me"; never "watched
-- me die", "saw it", "did nothing" or "let me die". The default is
-- neutral, and the narrator may feel things about it (glad of company, a
-- little embarrassed). Lines with an edge need who.tags.foe or
-- who.tags.avoid, and even then stay dry: they say what I make of it,
-- not what they meant.
--
-- Tags these words say beyond their slots (prefixed "witness." when the
-- words are declared, so another angle's tags can't block them):
--   act      they were there: every sentence must say it
--   died     I died: every sentence must say it
--   me       a clause or fragment with me (or the foe) as its subject;
--            tails that only fit after a clause about them say it too
--   sub      a when / as / while clause, so there's only one
--   dur      how long they were near me, in words or in seconds
--   had      a clause in the past perfect ("had been near me"), which an
--            "As I went down, " opening can't take
--   react    my own reaction
--   company  "I wasn't alone" and its kind
--   rank     a remark on an elite or a rare
--   edge     a pointed remark (tagged people only)
--   helped   says they fought too

local addonName, ns = ...

local Pages = ns.Pages
local Words = Pages.Words

Pages.Angle("witness", { order = { "watched" },
    about = "someone was near me when I died" })

local LOCAL = {
    ["and"] = true, though = true, place = true,
    act = true, died = true, me = true, sub = true, dur = true, had = true, react = true,
    company = true, rank = true, edge = true, helped = true,
}
local function Tag(t)
    return LOCAL[t] and ("witness." .. t) or t
end

-- Copies the pieces of `list`, each saying `add` as well, with extra
-- `needs` and `bonus`; this file's own tags get their prefix.
local function Prep(list, add, needs, bonus)
    local out = {}
    for i, raw in ipairs(list) do
        local p = type(raw) == "string" and { raw } or raw
        local q = {}
        for k, v in pairs(p) do q[k] = v end
        local has = {}
        for _, t in ipairs(p.says or {}) do has[t] = true end
        for _, t in ipairs(add or {}) do has[t] = true end
        -- "..., and " meeting ", and ..." reads as a list: one per sentence.
        local text = p[1]
        if text:find(", and ", 1, true) or text:find(" and $") or text:find("^, and ") then has["and"] = true end
        if text:find("%f[%a]though%f[%A]") then has.though = true end
        -- One place per sentence: "in Darkshore at Sentinel Hill" says it twice.
        if text:find("{in", 1, true) or text:find("{at", 1, true) then has.place = true end
        local says = {}
        for t in pairs(has) do says[#says + 1] = Tag(t) end
        q.says = says
        local n = {}
        for _, c in ipairs(p.needs or {}) do n[#n + 1] = c end
        for _, c in ipairs(needs or {}) do n[#n + 1] = c end
        q.needs = n
        for _, c in ipairs(n) do
            if c == "!who.familiar" then q[1] = "{witness_first}" .. q[1] end
        end
        if bonus then q.bonus = (q.bonus or 0) + bonus end
        out[i] = q
    end
    return out
end

-- {witness_first}: writes nothing when the person hasn't come up in an earlier
-- sentence of the page, and fails otherwise. A line that calls them a stranger starts
-- with it (Prep adds it to every piece that needs !who.familiar), so "a
-- stranger lent a hand: the warrior" can't follow an earlier mention.
Pages.Slot("witness_first", {
    needs = function() return { "who" } end,
    fn = function(env)
        local p = env.f.who
        if type(p) ~= "table" then return nil end
        local key = p.id or p.name or tostring(p)
        if env.ctx.mentioned[key] then return nil end
        return ""
    end,
})

local function Join(...)
    local out = {}
    for _, list in ipairs({ ... }) do
        for _, p in ipairs(list) do out[#out + 1] = p end
    end
    return out
end

-- The pointed lines, each once for someone tagged a foe and once for
-- someone I avoid. In the draw for them, without pushing out the neutral
-- lines.
local EDGE = -0.4
local function Pointed(list)
    return Join(Prep(list, { "edge" }, { "who.tags.foe" }, EDGE),
        Prep(list, { "edge" }, { "who.tags.avoid", "!who.tags.foe" }, EDGE))
end

local function Words2(spec)
    local s = { must = { Tag("act"), Tag("died") }, needs = spec.needs }
    for _, kind in ipairs({ "stems", "clauses", "fragments", "tails", "wholes" }) do s[kind] = spec[kind] end
    Words("witness", "watched", s)
end

-- Someone nobody named and I don't know by sight.
local STRANGER = { "!who.diary", "!who.named", "!who.familiar" }
-- "the last {secs:watched}" reads only for "the last twelve seconds".
local LAST = { "watched>=2", "watched<=20" }
-- Not with someone I've tagged unkindly: lines glad of their company.
local KIND = { "!who.tags.foe", "!who.tags.avoid" }
-- Who they are, as a remark: in the draw, not crowding it.
local WHO = -0.5
-- They fought too: worth saying more often than not.
local HELPED = -0.2

--------------------------------------------------------------------------
-- watched: someone was there when I went down
--------------------------------------------------------------------------

Words2({
    needs = { "watched" },

    stems = Join(Prep({
        -- openings that say I died, before a clause that says who was there
        "When {foe:foe} killed me, ",
        "When I died {at:subZone}, ",
        "When I went down {in:zone}, ",
        "When I died {today}, ",
        { "As {foe:foe} finished me off, ", says = { "had" } },
        { "As I went down, ", says = { "had" } },
        "When I lost to {foe:foe}, ",
        { "I died {today}, and ", bonus = -0.25 },
        "I died to {foe:foe}, and ",
        "{foe.cap:foe} got me {in:zone}, and ",
        "{foe.cap:foe} killed me {at:subZone}, and ",
        { "I died {at:subZone}, and ", bonus = -0.25 },
        { "In my last moments against {foe:foe}, ", says = { "had" }, voice = "warm" },
        { "{foe.cap:foe} won, and ", voice = "wry" },
        { "My fight with {foe:foe} went the wrong way, and ", voice = "wry" },
        { "Dead to {foe:foe}. ", voice = "terse" },
        { "Died {at:subZone}. ", voice = "terse" },
        { "I lost to {foe:foe}, an elite, and ", needs = { "foe.rank==elite" }, says = { "rank" } },
        { "I lost to {foe:foe}, a rare, and ", needs = { "foe.rank==rare" }, says = { "rank" } },
        { "I lost to {foe:foe}, a rare elite, and ", needs = { "foe.rank==rareelite" }, says = { "rank" } },
        { "I didn't die alone {today}: ", says = { "company" } },
        { "I had company when I died: ", says = { "company" } },
        { "I had company at the end: ", needs = KIND, says = { "company" }, voice = "warm" },
        { "I died {today}, though not alone: ", says = { "company" } },
    }, { "died", "me" }), Prep({
        -- openings that set the scene, before a clause that says it all
        { "{today.cap}, ", bonus = -0.5 },
        "{at.cap:subZone}, ",
        { "{in.cap:zone}, ", bonus = -0.5 },
        { "For what it's worth, ", says = { "react" }, bonus = -0.5 },
        { "As it happens, ", says = { "react" }, voice = "wry" },
    })),

    clauses = Join(Prep({
        -- they were there, and I died
        { "{ref} was nearby when I died", says = { "died", "sub" } },
        { "{ref} was there when I went down", says = { "died", "sub" } },
        { "{ref} was close by when {foe:foe} killed me", says = { "died", "sub" } },
        { "{ref} was near me when I died {at:subZone}", says = { "died", "sub" } },
        { "{ref} was near me when I went down {in:zone}", says = { "died", "sub" } },
        { "{ref} was right there when {foe:foe} got me", says = { "died", "sub" } },
        { "{ref} was around when I died", says = { "died", "sub" } },
        { "{ref} was on hand when I died", says = { "died", "sub" }, voice = "wry" },
        { "{ref} was near me for the last {secs:watched} of my fight with {foe:foe}", needs = LAST, says = { "died", "dur" } },
        { "{ref} was near me for {secs:watched} of my last fight", says = { "died", "dur" } },
        { "{ref} was close by for {secs:watched} before I went down", says = { "died", "sub", "dur" } },
        { "{ref} was near me for {secs:watched} as {foe:foe} wore me down", says = { "died", "sub", "dur" }, needs = { "watched>=10" } },
        { "{ref} was there for the end of my fight with {foe:foe}", says = { "died", "dur" } },
        { "{ref} was in the area when I died", says = { "died", "sub" }, bonus = -0.5 },
        { "{ref} was near when I went down {today}", says = { "died", "sub" }, bonus = -0.5 },
        { "{ref} was there at the end", says = { "died", "dur" }, voice = "warm" },
        { "{ref} was nearby for {secs:watched}, and then I died", says = { "died", "dur" }, final = true, voice = "terse" },

        -- they were there, waiting for an opening or tail that says I died
        "{ref} was nearby",
        "{ref} was close by",
        "{ref} was near me",
        "{ref} was there",
        "{ref} was right there",
        { "{ref} had been near me for {secs:watched}", says = { "dur", "had" } },
        { "{ref} had been close by for {secs:watched}", says = { "dur", "had" } },
        { "{ref} had been near me for most of the fight", needs = { "watched>=20" }, says = { "dur", "had" } },
        { "{ref} had been near me for only a moment", needs = { "watched<=4" }, says = { "dur", "had" } },
        { "{ref} was about", voice = "terse" },

        -- they fought too
        { "{ref} was in the fight with me", needs = { "alsoHelped" }, says = { "helped" }, bonus = HELPED },
        { "{ref} was there, fighting alongside me", needs = { "alsoHelped" }, says = { "helped", "sub" }, bonus = HELPED },
        { "{ref} joined in, but I died anyway", needs = { "alsoHelped" }, says = { "died", "helped" }, bonus = HELPED, final = true },
        { "{ref} fought {foe:foe} too, and I still went down", needs = { "alsoHelped" }, says = { "died", "helped" }, bonus = HELPED, final = true },
        { "{ref} was in the fight with me when {foe:foe} got me", needs = { "alsoHelped" }, says = { "died", "sub", "helped" }, bonus = HELPED },
        { "{ref} had joined the fight, and I died anyway", needs = { "alsoHelped" }, says = { "died", "helped", "had" }, bonus = HELPED, final = true },
        { "{ref} had my back, and I still died", needs = { "alsoHelped" }, says = { "died", "helped" }, bonus = HELPED, voice = "warm", final = true },
        { "{ref} joined in, for all the good it did me", needs = { "alsoHelped" }, says = { "died", "helped" }, bonus = HELPED, voice = "wry", final = true },

        -- who they are
        { "a stranger, {desc.a}, was near me when I died", needs = { "who.class ~= __nil", "!who.diary", "!who.named", "!who.familiar" }, says = { "died", "sub" }, bonus = WHO - 0.5 },
        { "{ref}, enemy colours and all, was near me when I died", needs = { "who.hostile" }, says = { "died", "sub" }, bonus = WHO },
    }, { "act" }), Prep({
        -- me as the subject, and they're in it
        { "I died with {ref.obj} nearby", says = { "died" } },
        { "I died {at:subZone} with {ref.obj} close by", says = { "died" } },
        { "I went down with {ref.obj} close by", says = { "died" } },
        { "I died to {foe:foe} with {ref.obj} nearby", says = { "died" } },
        { "{foe:foe} killed me with {ref.obj} nearby", says = { "died" } },
        { "{foe:foe} got me while {ref} was near", says = { "died", "sub" } },
        { "{foe:foe} killed me, and {ref} was there for it", says = { "died", "dur" }, final = true },
        { "I wasn't alone when I died: {ref} was close by", says = { "died", "company" }, final = true },
        { "I didn't die alone, at least: {ref} was there", needs = KIND, says = { "died", "company", "react" }, final = true, voice = "warm" },
        { "I had {ref.obj} for company at the end", needs = KIND, says = { "died", "company", "dur" }, voice = "warm" },
        { "my death wasn't a private affair: {ref} was close by", says = { "died", "company" }, final = true, voice = "wry" },
    }, { "act", "me" }), Prep({
        -- my side of it, waiting for a tail that says who was there
        { "I died {at:subZone}", says = { "died" } },
        { "I died {in:zone}", says = { "died" }, bonus = -0.25 },
        { "I died to {foe:foe}", says = { "died" } },
        { "I went down to {foe:foe} {at:subZone}", says = { "died" } },
        { "{foe:foe} killed me", says = { "died" } },
        { "{foe:foe} got me {in:zone}", says = { "died" } },
        { "{foe:foe} was the end of me", says = { "died" } },
        { "I died {today}", says = { "died" }, bonus = -0.5 },
        { "I lost a fight to {foe:foe}", says = { "died" }, voice = "wry" },
        { "{foe:foe} finished me off", says = { "died" }, voice = "terse" },
        { "I lost to {foe:foe}, an elite", needs = { "foe.rank==elite" }, says = { "died", "rank" } },
        { "I lost to {foe:foe}, a rare", needs = { "foe.rank==rare" }, says = { "died", "rank" } },
        { "I lost to {foe:foe}, a rare elite", needs = { "foe.rank==rareelite" }, says = { "died", "rank" } },
    }, { "me" })),

    fragments = Join(Prep({
        { "Died with {ref.obj} nearby", says = { "died" } },
        { "Died to {foe:foe}, with {ref.obj} close by", says = { "died" } },
        { "Killed by {foe:foe}, {ref.short} nearby", says = { "died" }, voice = "terse" },
        { "Dead {at:subZone}, {ref.short} nearby", says = { "died" }, voice = "terse" },
        { "Dead, and {ref.short} right there", says = { "died" }, voice = "terse" },
        { "Not alone at the end: {ref.noun} was there", says = { "died", "company" }, final = true },
        { "Company at the end: {ref.noun}", needs = KIND, says = { "died", "company" }, final = true, voice = "warm" },
        { "Lost to {foe:foe}, with {ref.short} there", says = { "died" } },
        { "{ref.short} nearby", voice = "terse" },
        { "{ref.short} close by for {secs:watched}", says = { "dur" }, voice = "terse" },
        { "{ref.short} in the fight too", needs = { "alsoHelped" }, says = { "helped" }, bonus = HELPED, voice = "terse" },
        { "Helped by {ref.obj}, and dead anyway", needs = { "alsoHelped" }, says = { "died", "helped" }, bonus = HELPED },
        { "Dead despite {ref.poss} help", needs = { "alsoHelped" }, says = { "died", "helped" }, bonus = HELPED },
    }, { "act", "me" }), Prep({
        { "Died {at:subZone}", says = { "died" } },
        { "Died to {foe:foe}", says = { "died" } },
        { "Killed by {foe:foe}", says = { "died" } },
        { "Killed by {foe:foe} {in:zone}", says = { "died" } },
        { "Dead {today}", says = { "died" }, bonus = -0.5, voice = "terse" },
    }, { "me" })),

    tails = Join(Prep({
        -- who was there, after my side of it
        ", with {ref.obj} nearby",
        ", with {ref.obj} close by",
        ", and {ref} was there",
        { " while {ref} was near me", says = { "sub" } },
        { ", {ref.short} close by", voice = "terse" },
        ", and {ref} was right there",
        { ", with {ref.obj} near me for the last {secs:watched} of it", needs = LAST, says = { "dur" } },
        { ", and {ref} had been near me for {secs:watched}", says = { "dur" } },
        { ", and I wasn't alone: {ref} was there", says = { "company" }, final = true },
        { ", with {ref.obj} for company", says = { "company" }, voice = "wry" },
        { ", with {ref.obj} fighting alongside me", needs = { "alsoHelped" }, says = { "helped" }, bonus = HELPED },
        { ", and {ref} had joined in", needs = { "alsoHelped" }, says = { "helped" }, bonus = HELPED },
        { ", though {ref} had joined the fight", needs = { "alsoHelped" }, says = { "helped" }, bonus = HELPED },
        { ", {ref.short} in the fight with me", needs = { "alsoHelped" }, says = { "helped" }, bonus = HELPED, voice = "terse" },
    }, { "act" }), Prep({
        -- that I died, after who was there
        { " when I died", says = { "sub" } },
        { " when I went down", says = { "sub" } },
        { " when {foe:foe} killed me", says = { "sub" } },
        { " when {foe:foe} got me", says = { "sub" } },
        { " as I went down", says = { "sub" } },
        { " when I died {at:subZone}", says = { "sub" } },
        { " when I went down {in:zone}", says = { "sub" } },
        { " as {foe:foe} finished me off", says = { "sub" } },
        { " before I went down", says = { "sub" } },
        { " before {foe:foe} killed me", says = { "sub" } },
        { " when I died {today}", says = { "sub" }, bonus = -0.5 },
        { " at the end", says = { "dur" }, voice = "warm" },
        { " for my last moments", says = { "dur" }, voice = "warm" },
        { " for my undignified end", says = { "dur" }, voice = "wry" },
    }, { "died" }), Prep({
        -- either way
        { ", which was not my finest moment", says = { "react" }, voice = "wry" },
        { ", which was a little embarrassing", says = { "react" }, voice = "wry" },
        { ", which was [some comfort|a small comfort|a comfort of sorts]", needs = KIND, says = { "react" }, bonus = -0.25, voice = "warm" },
        { ", and I was glad of the company", needs = KIND, says = { "react", "company" }, bonus = -0.25, voice = "warm" },
        { ", for what that's worth", says = { "react" }, bonus = -0.75 },
        { ", and had joined the fight", needs = { "alsoHelped" }, says = { "me", "helped" }, bonus = HELPED },
        { ", having joined in against {foe:foe}", needs = { "alsoHelped" }, says = { "me", "helped" }, bonus = HELPED },
        { ", not that either of us could stop it", needs = { "alsoHelped" }, says = { "react" }, voice = "wry" },
        { ", enemy colours and all", needs = { "who.hostile" }, says = { "me" }, bonus = WHO },
        { ", a stranger to me", needs = STRANGER, says = { "me" }, bonus = WHO - 0.5 },
    })),

    wholes = Prep({
        { "I died to {foe:foe} {today}. {ref} was nearby.", lead = true },
        "{ref} was near me when {foe:foe} killed me.",
        "I wasn't alone when I died {today}: {ref} was close by.",
        "When I went down {in:zone}, {ref} was there.",
        "{foe.cap:foe} killed me {at:subZone}. {ref} was close by at the time.",
        "{ref} was there when I died {at:subZone}.",
        "I died {at:subZone} {today}, and {ref} was near me when it happened.",
        { "{foe.cap:foe} got me {today}, with {ref} nearby for the last {secs:watched}.", needs = LAST, lead = true },
        "{ref} had been near me for {secs:watched} when {foe:foe} finished me off.",
        { "For the last {secs:watched} of my fight with {foe:foe}, {ref} was close by.", needs = LAST },
        "My fight with {foe:foe} ended badly {today}. {ref} was there for it.",
        "I died {in:zone} {today}. {ref} was nearby when I went down.",
        { "{ref} was there when I died. That's all, really.", bonus = -0.5 },
        "I didn't die alone {today}. {ref} was near me at the end.",
        "There was someone near me when I went down {today}: {ref.noun}.",
        "{foe.cap:foe} won {today}. When I went down, {ref} was close by.",
        { "{ref} was near me for {secs:watched} before I went down, which isn't long.", needs = { "watched<=6" } },
        { "{ref} was near me for {secs:watched} as {foe:foe} wore me down.", needs = { "watched>=20" } },
        { "{ref} was close by for most of my fight with {foe:foe}, and I died anyway.", needs = { "watched>=30" } },
        { "{ref} turned up only moments before {foe:foe} got me.", needs = { "watched<=3" } },
        { "The {foename:foe} was elite and I was outmatched. {ref} was nearby when I went down.", needs = { "foe.rank==elite" }, says = { "rank" } },
        { "{foe.cap:foe}, a rare, got the better of me {today}. {ref} was close by.", needs = { "foe.rank==rare" }, says = { "rank" } },
        { "{foe.cap:foe}, a rare elite, killed me {at:subZone}. {ref} was near me at the time.", needs = { "foe.rank==rareelite" }, says = { "rank" } },
        { "{ref} joined the fight against {foe:foe}, but I died anyway.", needs = { "alsoHelped" }, bonus = HELPED },
        { "{ref} was there when I died, and had joined in against {foe:foe}.", needs = { "alsoHelped" }, bonus = HELPED },
        { "{foe.cap:foe} got me even with {ref.obj} in the fight.", needs = { "alsoHelped" }, bonus = HELPED },
        { "Two of us against {foe:foe}, and I still went down. {ref} was the other.", needs = { "alsoHelped" }, bonus = HELPED },
                { "{ref} joined in and I still died. Not for want of help.", needs = { "alsoHelped" }, bonus = HELPED, voice = "wry" },
        { "{ref.short} joined in. Died anyway.", needs = { "alsoHelped" }, bonus = HELPED, voice = "terse" },
        { "At least I didn't die alone. {ref} was there.", needs = KIND, voice = "warm" },
        { "It was some comfort that {ref} was near me when I went down.", needs = KIND, voice = "warm" },
        { "I died {today}, but {ref} was near me at the end, and that counted for something.", needs = KIND, voice = "warm" },
        { "Of all the people to have nearby, I was glad it was {ref.noun}.", needs = { "who.diary", "!who.tags.foe", "!who.tags.avoid" }, voice = "warm" },
        { "{ref} was close by when {foe:foe} got me. I'd rather have met {him} some other way.", needs = STRANGER, voice = "warm" },
        { "I died to {foe:foe} {today}, with {ref} right there. Embarrassing.", voice = "wry" },
        { "Nothing like dying with company. {ref} was nearby when {foe:foe} got me.", voice = "wry" },
        { "If I'd known I'd have company, I'd have died more gracefully. {ref} was nearby.", voice = "wry" },
        { "{foe.cap:foe} killed me {today}, and {ref} was there for it. Not my best moment.", voice = "wry" },
        { "I died, and not privately: {ref} was close by.", voice = "wry" },
        { "{ref} was near me for {secs:watched} of my last fight. It wasn't my finest work.", voice = "wry" },
        { "Died to {foe:foe}. {ref.short} nearby.", voice = "terse" },
        { "Died. {ref.short} was there.", voice = "terse" },
        { "{foe.cap:foe}. Dead. {ref.short} close by.", voice = "terse" },
        { "Died {at:subZone}. {ref.short} nearby for {secs:watched}.", voice = "terse" },
        { "{ref.short} was there when I died.", voice = "terse" },
        { "A stranger was near me when I died {today}: {ref.noun}.", needs = STRANGER, bonus = WHO },
        { "I died near someone I didn't know, {ref.noun}.", needs = STRANGER, bonus = WHO, voice = "wry" },
        { "{ref} was near me when I died {today}, enemy colours and all.", needs = { "who.hostile" }, bonus = WHO },
        { "{ref} was near me when I went down. Of everyone, I was glad it was a friend.", needs = { "who.tags.friend" }, bonus = WHO, voice = "warm" },
        { "{ref} was there when I died, and I was glad it was {him}.", needs = { "who.tags.friend" }, bonus = WHO, voice = "warm" },
    }, { "act", "died" }),
})

-- The pointed lines: someone I've marked as a foe, or avoid. Dry, never
-- cruel; they say what I make of it, not what they meant.
Words2({
    clauses = Prep(Pointed({
        { "{ref}, of all people, was there when I died", says = { "sub" } },
        { "{ref} was near me when I died, which figures", says = { "sub" }, final = true },
        { "{ref} was close by for {secs:watched} as I went down, and kept out of it", needs = { "!alsoHelped" }, says = { "sub", "dur" }, final = true },
        { "{ref} was nearby when I died, and I can't say I expected help from that quarter", needs = { "!alsoHelped" }, says = { "sub" }, final = true },
        { "{ref} joined in against {foe:foe}, of all things, and I still died", needs = { "alsoHelped" }, says = { "helped" }, final = true },
    }), { "act", "died" }),

    tails = Prep(Pointed({
        { ", with {ref.obj}, of all people, nearby", says = { "company" } },
        { ", {ref} keeping well out of it", needs = { "!alsoHelped" } },
    }), { "act" }),

    wholes = Prep(Pointed({
        "{ref} was nearby when I died. Not the company I'd have chosen.",
        "Of all the people to be near me when I went down, it was {ref.noun}.",
        { "{ref} was near me for {secs:watched} while {foe:foe} finished me off. I didn't expect help from that quarter, and got none.", needs = { "!alsoHelped" } },
        { "{ref} was close by when {foe:foe} got me, and stayed out of it. I'm not surprised.", needs = { "!alsoHelped" } },
        { "I died {at:subZone} {today}, with {ref} nearby. I can't say {he} made it any easier.", needs = { "!alsoHelped" } },
        { "{ref} joined in against {foe:foe} before I went down. I'll grant {him} that.", needs = { "alsoHelped" } },
        { "{ref} was there when I died. I'd have preferred company I like better.", voice = "wry" },
        { "Died. {ref.short} was there. Of course.", voice = "terse" },
    }), { "act", "died" }),
})

--------------------------------------------------------------------------
-- More in each voice
--------------------------------------------------------------------------

Words2({
    stems = Join(Prep({
        { "At the very end, ", says = { "had" }, voice = "warm" },
        { "In my last seconds, ", says = { "had" }, voice = "warm" },
        { "{foe.cap:foe} had the last word, and ", voice = "wry" },
    }, { "died", "me" })),

    clauses = Join(Prep({
        { "{ref} was a friendly face at the end", needs = KIND, says = { "died", "dur", "react" }, voice = "warm" },
        { "{ref} was close by for the worst of it", says = { "died", "dur" }, voice = "wry" },
        { "{ref} was close by for my last {secs:watched}", needs = LAST, says = { "died", "dur" }, voice = "terse" },
    }, { "act" }), Prep({
        { "I went down with a friendly face nearby, {ref.noun}", needs = Join(KIND, { "who.diary" }), says = { "died", "company" }, final = true, voice = "warm" },
        { "I died, as people do, with {ref.obj} close by", says = { "died" }, voice = "wry" },
        { "I picked a bad moment to die, with {ref.obj} right there", says = { "died", "react" }, final = true, voice = "wry" },
    }, { "act", "me" })),

    fragments = Prep({
        { "A familiar face nearby at the end: {ref.noun}", needs = Join(KIND, { "who.diary" }), says = { "died", "company" }, final = true, voice = "warm" },
        { "{ref.short} there at the end", says = { "died", "dur" }, voice = "terse" },
        { "Died in company, {ref.short} close by", says = { "died", "company" }, voice = "wry" },
    }, { "act", "me" }),

    tails = Join(Prep({
        { ", with {ref.obj} nearby, which I was glad of", needs = KIND, says = { "react" }, voice = "warm" },
        { ", and {ref} was nearby, sadly for my pride", says = { "react" }, voice = "wry" },
        { ". {ref.short} nearby", voice = "terse" },
    }, { "act" }), Prep({
        { " at the last", says = { "dur" }, voice = "warm" },
    }, { "died" }), Prep({
        { ", which did nothing for my pride", says = { "react" }, voice = "wry" },
    })),

    wholes = Prep({
        { "Dying is easier with company. {ref} was near me when {foe:foe} got me.", needs = KIND, voice = "warm" },
        { "{ref} was there when I went down {at:subZone}. I'm glad someone was.", voice = "warm" },
        { "{foe.cap:foe} got me {today}. I was glad {ref} was nearby, even so.", needs = KIND, voice = "warm" },
        { "Of all the ways to die, with {ref.obj} nearby is not the worst.", needs = Join(KIND, { "who.diary" }), voice = "warm" },
        { "{ref} fought {foe:foe} alongside me until I went down. I won't forget that.", needs = { "alsoHelped" }, bonus = HELPED, voice = "warm" },
        { "{ref} was there for my last {secs:watched}. It helped, somehow.", needs = Join(KIND, LAST), voice = "warm" },
        { "A stranger, {ref.noun}, was there when I went down. Oddly, that was a comfort.", needs = STRANGER, bonus = WHO, voice = "warm" },
        { "{ref} was nearby when I went down. Good to have a friend close, even then.", needs = { "who.tags.friend" }, bonus = WHO, voice = "warm" },
        { "I died {today}, and {ref} was nearby. I'd hoped to do that sort of thing in private.", voice = "wry" },
        { "{foe.cap:foe} beat me {today}, and in company: {ref} was close by.", voice = "wry" },
        { "{ref} was near me for {secs:watched} as I lost to {foe:foe}. Not my most impressive {secs:watched}.", needs = LAST, voice = "wry" },
        { "{ref} joined in, and I still died, which says more about me than about {him}.", needs = { "alsoHelped" }, bonus = HELPED, voice = "wry" },
        { "{foe.cap:foe} got me {today}. {ref} was nearby, and I'd like to think I went down fighting.", voice = "wry" },
        { "Dying is bad enough without company. {ref} was close by when {foe:foe} got me.", voice = "wry" },
        { "{foe.cap:foe} won. {ref.short} nearby.", voice = "terse" },
        { "Dead {at:subZone}. {ref.short} there.", voice = "terse" },
    }, { "act", "died" }),
})
