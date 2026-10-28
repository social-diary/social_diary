-- Misfortune (PAGE-11): someone and I died close together.
--
-- shared facts (the planner's, from the combat log)
--   who            the person who died near me
--   foe            what killed me, { name, rank }, when it was a creature;
--                  with sameKiller, what killed us both
--   sameKiller     the same creature killed us both
--   within         seconds between the two deaths (0: the same moment)
--   iDiedFirst     I went down first
--   theyDiedFirst  they went down first (never both; neither when within
--                  is 0)
--   zone, subZone  where I died
--   grouped        we were in a group
--
-- Plain, a little rueful, never mocking: the joke, if any, is on the two
-- of us or on me. Places are mine ("I died at Lake Falathim"), never
-- where they fell. Without sameKiller, {foe} is only what killed me.
--
-- Tags these words say beyond their slots (prefixed "misfortune." when
-- declared, so another angle's tags can't block them):
--   theirs  their death: every sentence must say it
--   mine    my death: every sentence must say it
--   order   who went first
--   killer  whether the same thing got us both
--   gap     how close together, in words ("moments apart"); says
--           `within` too, so it never sits beside the seconds
--   pair    the two deaths as one ("apart", "of each other"); an opening
--           that tells my death on its own says it, so a clause about
--           theirs alone can't end in "of each other"
--   react   my own reaction
--   rank    a remark on an elite or a rare

local addonName, ns = ...

local Pages = ns.Pages
local Words = Pages.Words

Pages.Angle("misfortune", { order = { "shared" },
    about = "someone and I died close together" })

local LOCAL = {
    ["and"] = true, though = true, both = true, sodid = true, place = true, foefirst = true, wentdown = true,
    theirs = true, mine = true, order = true, killer = true, gap = true, pair = true,
    react = true, rank = true,
}
local function Tag(t)
    return LOCAL[t] and ("misfortune." .. t) or t
end

-- Copies the pieces of `list`, each saying `add` as well; this file's own
-- tags get their prefix.
local function Prep(list, add)
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
        if text:find("close together", 1, true) then has.gap = true end
        if text:find("went down", 1, true) then has.wentdown = true end
        -- An opening about the two of us can't lead into a clause about the foe.
        if text:find("^{foe:foe}") then has.foefirst = true end
        -- "both" once a sentence.
        if text:find("%f[%a]both%f[%A]") then has.both = true end
        if has.gap then has.within = true end
        local says = {}
        for t in pairs(has) do says[#says + 1] = Tag(t) end
        q.says = says
        for _, c in ipairs(p.needs or {}) do
            if c == "!who.familiar" then q[1] = "{misfortune_first}" .. q[1] end
        end
        out[i] = q
    end
    return out
end

-- {misfortune_first}: writes nothing when the person hasn't come up in an earlier
-- sentence of the page, and fails otherwise. A line that calls them a stranger starts
-- with it (Prep adds it to every piece that needs !who.familiar), so "a
-- stranger lent a hand: the warrior" can't follow an earlier mention.
Pages.Slot("misfortune_first", {
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

local function N(...)
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

-- Guards rather than flags, so a line about who went first or what killed
-- us is preferred a little, not to the exclusion of everything else.
local SAME = { "sameKiller==true" }
local DIFF = { "!sameKiller" }
local ME1 = { "iDiedFirst==true" }
local THEY1 = { "theyDiedFirst==true" }
local TOGETHER = { "within==0" }
local CLOSE = { "within>=1", "within<=10" }
-- "within twenty seconds of each other" reads; "within most of a minute"
-- doesn't.
local WITHIN = { "within<=25" }
local NAMED_FOE = { "foe.rank~=rare", "foe.rank~=rareelite", "foe.rank~=worldboss" }

-- Someone nobody named and I don't know by sight.
local STRANGER = { "!who.diary", "!who.named", "!who.familiar" }

-- Who went first matters when it's known.
local ORDER = 0.75
-- Remarks about who they are: in the draw, not crowding it.
local WHO = -0.5

--------------------------------------------------------------------------
-- shared: we died close together
--------------------------------------------------------------------------

Words("misfortune", "shared", {
    must = { Tag("theirs"), Tag("mine") },
    needs = { "within ~= __nil" },

    stems = Join(Prep({
        -- openings that set the scene
        { "{today.cap}, ", bonus = -0.5 },
        "{in.cap:zone}, ",
        "{at.cap:subZone}, ",
        { "Within {secs:within} of each other, ", needs = N("within>=2", WITHIN), says = { "pair" } },
        { "{secs.cap:within} apart, ", needs = { "within>=2" }, says = { "pair" } },
        { "In the space of {secs:within}, ", needs = { "within>=2" }, says = { "pair" } },
        { "In a single moment, ", needs = TOGETHER, says = { "gap", "pair" } },
        { "Moments apart, ", needs = CLOSE, says = { "gap", "pair" } },
        { "Against {foe:foe}, ", needs = SAME, says = { "killer" } },
        { "Grouped as we were, ", needs = { "grouped" }, says = { "foefirst" }, bonus = -0.5 },
        { "Sadly, ", says = { "react" } },
        { "As luck would have it, ", says = { "react" }, voice = "wry" },
        { "Misery loves company: ", says = { "react" }, voice = "wry" },
        { "Rough {part}. ", says = { "react" }, voice = "terse" },
        { "It went wrong for both of us: ", says = { "react" }, voice = "warm" },
        { "The {foename:foe} was elite, and ", needs = N(SAME, "foe.rank==elite"), says = { "rank", "killer" } },
        { "{foe.cap:foe}, a rare, was too much for us, and ", needs = N(SAME, "foe.rank==rare"), says = { "rank", "killer" } },
        { "{foe.cap:foe}, a rare elite, was too much for us, and ", needs = N(SAME, "foe.rank==rareelite"), says = { "rank", "killer" } },
    }), Prep({
        -- openings that say I died, before a clause about them
        "I died {at:subZone}, and ",
        "I died to {foe:foe} {in:zone}, and ",
        { "When I died {at:subZone}, ", says = { "sodid" } },
        { "When {foe:foe} killed me, ", says = { "sodid" } },
        { "I went down {today}, and ", bonus = -0.5 },
        { "{foe.cap:foe} killed me, and ", needs = DIFF },
        { "Just before I went down, ", needs = N(THEY1, CLOSE), says = { "order", "gap", "sodid" }, bonus = ORDER },
        { "Just after I went down, ", needs = N(ME1, CLOSE), says = { "order", "gap", "sodid" }, bonus = ORDER },
        { "{secs.cap:within} after I died, ", needs = ME1, says = { "order", "sodid" }, bonus = ORDER },
        { "{secs.cap:within} before I died, ", needs = THEY1, says = { "order", "sodid" }, bonus = ORDER },
        { "I died, and ", voice = "terse" },
        { "I wasn't the only casualty {today}: ", says = { "sodid", "react" }, voice = "wry" },
        { "I didn't die alone {today}: ", says = { "sodid", "react" }, voice = "warm" },
    }, { "mine", "pair" })),

    clauses = Join(Prep({
        -- both of us, no order
        "{ref} and I died close together",
        "{ref} and I both died",
        "{ref} and I both went down",
        { "{ref} and I died within moments of each other", needs = { "within<=10" }, says = { "gap" } },
        "{ref} and I died {secs:within} apart",
        "{ref} and I went down {secs:within} apart",
        { "{ref} and I died within {secs:within} of each other", needs = WITHIN },
        { "{ref} and I both died {in:zone}", bonus = -0.25 },
        { "{ref} and I both ended up dead", bonus = -0.25 },
        { "{ref} and I died together", needs = TOGETHER, says = { "gap" } },
        { "{ref} and I went down at the same moment", needs = TOGETHER, says = { "gap" } },
        { "{ref} and I died at almost the same moment", needs = { "within>=1", "within<=3" }, says = { "gap" } },
        { "{ref} and I went down within a few seconds of each other", needs = { "within>=2", "within<=6" }, says = { "gap" } },
        { "{ref} and I died moments apart", needs = CLOSE, says = { "gap" } },
        { "{ref} and I died within a minute of each other", needs = { "within>=20", "within<=60" }, says = { "gap" } },
        { "{ref} and I died close together, though not quite at once", needs = { "within>=10" }, says = { "gap" }, final = true },
        { "the two of us went down together, {ref} and I", needs = TOGETHER, says = { "gap" }, final = true, voice = "warm" },
        { "{ref} and I both came off worse", voice = "wry" },
        { "{ref} and I made a matching pair of corpses", voice = "wry" },
        { "{ref} and I both died", voice = "terse" },

        -- the same killer
        { "{foe:foe} killed us both", needs = SAME, says = { "killer" } },
        { "{foe:foe} killed {ref.obj} and me", needs = SAME, says = { "killer" } },
        { "{foe:foe} got both of us", needs = SAME, says = { "killer" } },
        { "{foe:foe} got both {ref.obj} and me", needs = SAME, says = { "killer" } },
        { "{ref} and I both died to {foe:foe}", needs = SAME, says = { "killer" } },
        { "{ref} and I both went down to {foe:foe}", needs = SAME, says = { "killer" } },
        { "{foe:foe} killed us both, {secs:within} apart", needs = SAME, says = { "killer", "pair" } },
        { "{foe:foe} was too much for {ref.obj} and me", needs = SAME, says = { "killer" } },
        { "{foe:foe} had the better of both of us", needs = SAME, says = { "killer" }, voice = "wry" },
        { "{foe:foe} made short work of us both", needs = N(SAME, "within<=10"), says = { "killer", "gap" }, voice = "wry" },
        { "{foe:foe} took us both", needs = SAME, says = { "killer" }, voice = "terse" },

        -- who went first
        { "{ref} went down first, and I followed {secs:within} later", needs = THEY1, says = { "order" }, bonus = ORDER },
        { "{ref} died first, and I wasn't far behind", needs = N(THEY1, "within<=20"), says = { "order", "gap" }, bonus = ORDER },
        { "I died {secs:within} after {ref.obj}", needs = THEY1, says = { "order" }, bonus = ORDER },
        { "I followed {ref.obj} down {secs:within} later", needs = THEY1, says = { "order" }, bonus = ORDER },
        { "I went down {secs:within} after {ref.obj}", needs = THEY1, says = { "order" }, bonus = ORDER },
        { "{ref} fell {secs:within} before I did", needs = THEY1, says = { "order" }, bonus = ORDER },
        { "{ref} went down, and {secs:within} later so did I", needs = THEY1, says = { "order" }, bonus = ORDER, final = true },
        { "I went down first, and {ref} followed {secs:within} later", needs = ME1, says = { "order" }, bonus = ORDER },
        { "I died first, and {ref} wasn't far behind", needs = N(ME1, "within<=20"), says = { "order", "gap" }, bonus = ORDER },
        { "{ref} died {secs:within} after me", needs = ME1, says = { "order" }, bonus = ORDER },
        { "{ref} went down {secs:within} after I did", needs = ME1, says = { "order" }, bonus = ORDER },
        { "I fell {secs:within} before {ref.obj}", needs = ME1, says = { "order" }, bonus = ORDER },
        { "I went down, and {secs:within} later so did {ref}", needs = ME1, says = { "order" }, bonus = ORDER, final = true },
        { "{foe:foe} killed {ref.obj}, then me", needs = N(SAME, THEY1), says = { "killer", "order" }, bonus = ORDER },
        { "{foe:foe} killed {ref.obj} first and me {secs:within} later", needs = N(SAME, THEY1), says = { "killer", "order" }, bonus = ORDER },
        { "{foe:foe} killed me, then {ref.obj}", needs = N(SAME, ME1), says = { "killer", "order" }, bonus = ORDER },
        { "{foe:foe} killed me first and {ref.obj} {secs:within} later", needs = N(SAME, ME1), says = { "killer", "order" }, bonus = ORDER },
        { "{ref} beat me to it by {secs:within}", needs = N(THEY1, "within<=20"), says = { "order" }, bonus = ORDER, voice = "wry" },
        { "I beat {ref.obj} to it by {secs:within}", needs = N(ME1, "within<=20"), says = { "order" }, bonus = ORDER, voice = "wry" },
        { "I led the way, and {ref} followed", needs = ME1, says = { "order" }, bonus = ORDER, voice = "wry" },
        { "{ref} went first; I followed", needs = THEY1, says = { "order" }, bonus = ORDER, voice = "terse", final = true },
        { "I went first; {ref} followed", needs = ME1, says = { "order" }, bonus = ORDER, voice = "terse", final = true },

        -- different killers
        { "{ref} and I died {secs:within} apart, to different things", needs = DIFF, says = { "killer", "pair" } },
        { "{ref} and I both died, though not to the same thing", needs = DIFF, says = { "killer" } },
        { "I died to {foe:foe}, and {ref} went down to something else", needs = DIFF, says = { "killer" } },
        { "{foe:foe} killed me, and something else got {ref.obj}", needs = DIFF, says = { "killer" } },
        { "{ref} and I died near each other, each to our own trouble", needs = DIFF, says = { "killer" }, voice = "wry" },

        -- who they are
        { "{ref} and I were grouped, and we both went down", needs = { "grouped" }, bonus = -0.5 },
        { "{ref} and I weren't even grouped, but we went down together", needs = N("!grouped", "who.diary", CLOSE), says = { "grouped", "gap" }, bonus = -1 },
        { "a stranger and I died within {secs:within} of each other: {ref.noun}", needs = N(STRANGER, WITHIN), says = { "pair" }, final = true, bonus = WHO },
        { "{ref}, enemy colours and all, went down near me", needs = { "who.hostile" }, bonus = WHO - 0.5 },
    }, { "theirs", "mine" }), Prep({
        -- their death only, after an opening that says mine
        "{ref} went down too",
        "{ref} died as well",
        { "so did {ref}", says = { "sodid" }, bonus = 0.5 },
        { "{ref} wasn't far behind", needs = N(ME1, "within<=20"), says = { "gap", "order" }, bonus = ORDER },
        { "{ref} died within {secs:within} of me", needs = WITHIN },
        { "{ref} went down within {secs:within}", needs = WITHIN },
        { "{ref} went down at the same moment", needs = TOGETHER, says = { "gap" } },
        { "{ref} went down moments later", needs = N(ME1, CLOSE), says = { "order", "gap" }, bonus = ORDER },
        { "{ref} had already gone down", needs = THEY1, says = { "order" }, bonus = ORDER },
        { "{ref} was already dead", needs = THEY1, says = { "order" }, bonus = ORDER, voice = "terse" },
        { "{ref} followed me {secs:within} later", needs = ME1, says = { "order" }, bonus = ORDER },
        { "{foe:foe} got {ref.obj} as well", needs = SAME, says = { "killer" } },
        { "the {foename:foe} that killed me got {ref.obj} too", needs = N(SAME, NAMED_FOE), says = { "killer" } },
        { "something else got {ref.obj}", needs = DIFF, says = { "killer" } },
        { "{ref} went down to something else", needs = DIFF, says = { "killer" } },
        { "{ref} met the same end", needs = SAME, says = { "killer" }, voice = "wry" },
        { "{ref} kept me company in that too", voice = "warm" },
        { "{ref} was in the same sorry state", voice = "wry" },
        { "a stranger, {desc.a}, went down too", needs = N(STRANGER, "who.class ~= __nil"), bonus = WHO - 0.5 },
    }, { "theirs" })),

    fragments = Prep({
        { "Both dead, {ref.short} and I", says = { "place" } },
        { "Two deaths, {secs:within} apart: {ref.poss} and mine", says = { "pair" } },
        { "Dead within {secs:within} of {ref.obj}", needs = WITHIN },
        { "Dead within moments of {ref.obj}", needs = { "within<=10" }, says = { "gap" } },
        { "Down together with {ref.obj}", needs = TOGETHER, says = { "gap" } },
        { "Both killed by {foe:foe}, {ref.short} and I", needs = SAME, says = { "killer" } },
        { "Killed by {foe:foe}, and {ref.short} with me", needs = SAME, says = { "killer" } },
        { "Two for {foe:foe}: {ref.short} and me", needs = SAME, says = { "killer" }, voice = "wry" },
        { "{ref.short} first, then me", needs = THEY1, says = { "order", "place" }, bonus = ORDER, voice = "terse" },
        { "Me first, then {ref.short}", needs = ME1, says = { "order", "place" }, bonus = ORDER, voice = "terse" },
        { "{ref.short} down, then me, {secs:within} apart", needs = THEY1, says = { "order", "pair" }, bonus = ORDER, voice = "terse" },
        { "Down {secs:within} after {ref.obj}", needs = THEY1, says = { "order" }, bonus = ORDER },
        { "Dead {secs:within} before {ref.obj}", needs = ME1, says = { "order" }, bonus = ORDER },
        { "Not the only one to die {today}: {ref.noun} went down too", final = true, voice = "wry" },
        { "Died alongside {ref.obj}", voice = "warm" },
        { "Both of us dead, {ref.short} and me", says = { "place" }, voice = "terse" },
        { "Dead, as was {ref.short}", voice = "terse" },
    }, { "theirs", "mine" }),

    tails = Prep({
        { ", {secs:within} apart", says = { "pair" } },
        { ", within {secs:within} of each other", needs = WITHIN, says = { "pair" } },
        { ", moments apart", needs = CLOSE, says = { "gap", "pair" } },
        { ", at the same moment", needs = TOGETHER, says = { "gap", "pair" } },
        { ", one after the other", needs = { "within>=1" }, says = { "gap", "pair", "order" } },
        { " in quick succession", needs = { "within>=1", "within<=15" }, says = { "gap", "pair" } },
        { ", though not quite together", needs = { "within>=15" }, says = { "gap", "pair" } },
        { " {at:subZone}", bonus = -0.25 },
        { " {in:zone}", bonus = -0.5 },
        { ", both to {foe:foe}", needs = SAME, says = { "killer", "pair", "order" } },
        { ", the same {foename:foe} getting us both", needs = N(SAME, NAMED_FOE), says = { "killer", "pair" } },
        { ", though not to the same thing", needs = DIFF, says = { "killer", "pair" } },
        { ", each to something different", needs = DIFF, says = { "killer", "pair" } },
        { ", and {ref} went first", needs = THEY1, says = { "order" }, bonus = ORDER },
        { ", with {ref.obj} going first", needs = THEY1, says = { "order" }, bonus = ORDER },
        { ", and {ref} went down a little ahead of me", needs = N(THEY1, "within<=20"), says = { "order", "gap" }, bonus = ORDER },
        { ", me first", needs = ME1, says = { "order" }, bonus = ORDER },
        { ", with me going first", needs = ME1, says = { "order" }, bonus = ORDER },
        { ", and {ref} went down just after me", needs = N(ME1, "within<=20"), says = { "order", "gap" }, bonus = ORDER },
        { ", grouped as we were", needs = { "grouped" }, bonus = -0.5 },
        { ", though we weren't grouped", needs = { "!grouped", "who.diary" }, says = { "grouped" }, bonus = -1 },
        { ", and at least I had company", says = { "react" }, voice = "warm" },
        { ", and I was sorry for both of us", says = { "react" }, voice = "warm" },
        { ", which at least meant I wasn't alone", says = { "react" }, voice = "warm" },
        { ", which I can't say was the plan", says = { "react" }, voice = "wry" },
        { ", which was a poor showing all round", says = { "react" }, voice = "wry" },
        { ", for what it's worth", says = { "react" }, bonus = -0.5 },
    }),

    wholes = Prep({
        { "{ref} and I died within {secs:within} of each other {today}.", needs = WITHIN, lead = true },
        "{ref} and I both went down {today}, {secs:within} apart.",
        "I died {at:subZone} {today}, and {ref} went down within {secs:within} of me.",
        "{ref} and I died close together {in:zone}.",
        "Two deaths {today}, {secs:within} apart: mine and {ref.poss}.",
        { "We went down together {today}, {ref} and I.", needs = { "within<=10" } },
        { "{ref} and I both died {today}. It was that sort of fight.", bonus = -0.5 },
        { "{foe.cap:foe} killed us both {today}, {ref} and me.", needs = SAME, says = { "killer" }, lead = true },
        { "{foe.cap:foe} got {ref.obj}, and {secs:within} later it got me too.", needs = N(SAME, THEY1), says = { "killer", "order" }, bonus = ORDER },
        { "{foe.cap:foe} got me, and {secs:within} later it got {ref.obj} too.", needs = N(SAME, ME1), says = { "killer", "order" }, bonus = ORDER },
        { "{foe.cap:foe} was too much for either of us. {ref} and I went down {secs:within} apart.", needs = SAME, says = { "killer" } },
        { "{ref} and I both died to {foe:foe} {at:subZone}.", needs = SAME, says = { "killer" } },
        { "{foe.cap:foe} accounted for both of us {today}: {ref.noun} first, then me.", needs = N(SAME, THEY1), says = { "killer", "order" }, bonus = ORDER },
        { "{foe.cap:foe} accounted for both of us {today}: me first, then {ref.noun}.", needs = N(SAME, ME1), says = { "killer", "order" }, bonus = ORDER },
        { "{foe.cap:foe} killed {ref.obj} and me at the same moment.", needs = N(SAME, TOGETHER), says = { "killer", "gap" } },
        { "{ref} went down first. I lasted another {secs:within}.", needs = N(THEY1, "within<=20"), says = { "order" }, bonus = ORDER },
        { "I outlasted {ref.obj} by {secs:within}, and then I went down too.", needs = N(THEY1, "within<=20"), says = { "order" }, bonus = ORDER },
        { "I went down first, and {ref} followed {secs:within} later.", needs = ME1, says = { "order" }, bonus = ORDER },
        { "{ref} outlasted me by {secs:within}, and no more.", needs = N(ME1, "within<=20"), says = { "order" }, bonus = ORDER },
        { "{ref} died, and {secs:within} later so did I.", needs = THEY1, says = { "order" }, bonus = ORDER },
        { "I died, and {secs:within} later so did {ref}.", needs = ME1, says = { "order" }, bonus = ORDER },
        { "{ref} and I went down at the same moment {today}.", needs = TOGETHER, says = { "gap" } },
        { "I died to {foe:foe}, and {ref} went down to something else within {secs:within}.", needs = N(DIFF, WITHIN), says = { "killer" } },
        { "{ref} and I both died {today}, though different things got us.", needs = DIFF, says = { "killer" } },
        { "{ref} and I died {secs:within} apart, each to our own trouble.", needs = DIFF, says = { "killer" } },
        { "{foe.cap:foe} got me {today}. Something else got {ref.obj} within {secs:within}.", needs = N(DIFF, WITHIN), says = { "killer" } },
        { "{ref} and I were grouped, and we went down within {secs:within} of each other.", needs = N("grouped", WITHIN), bonus = -0.5 },
        { "{ref} and I weren't even grouped, but we died within {secs:within} of each other.", needs = N("!grouped", "who.diary", WITHIN), says = { "grouped" }, bonus = -1 },
        { "A stranger, {ref}, died within {secs:within} of me {today}.", needs = N(STRANGER, WITHIN), bonus = WHO },
        { "The {foename:foe} was elite, and it got the both of us.", needs = N(SAME, "foe.rank==elite"), says = { "killer", "rank" } },
        { "{foe.cap:foe} is a rare for good reason. It killed {ref.obj} and me {secs:within} apart.", needs = N(SAME, "foe.rank==rare"), says = { "killer", "rank" } },
        { "{foe.cap:foe}, a rare elite, got {ref.obj} and me both.", needs = N(SAME, "foe.rank==rareelite"), says = { "killer", "rank" } },
        { "{ref} and I died {secs:within} apart {today}. At least I wasn't alone.", says = { "react" }, voice = "warm" },
        { "We went down together, {ref} and I. There are worse people to die beside.", needs = { "who.diary", "!who.tags.avoid", "!who.tags.foe", "within<=10" }, says = { "react" }, voice = "warm" },
        { "{ref} and I died close together {today}. I was sorry about that, for both of us.", says = { "react" }, voice = "warm" },
        { "{ref} and I both died {today}. A bad {part} for the two of us.", says = { "react" }, voice = "warm" },
        { "{ref} and I died {secs:within} apart. Neither of us covered ourselves in glory.", says = { "react" }, voice = "wry" },
        { "{ref} went down, and I followed {secs:within} later, as if I'd been waiting my turn.", needs = THEY1, says = { "order", "react" }, bonus = ORDER, voice = "wry" },
        { "I died first, and {ref} followed {secs:within} later. I'd like to think I set the trend.", needs = ME1, says = { "order", "react" }, bonus = ORDER, voice = "wry" },
        { "{foe.cap:foe} took {ref.obj} and me in one go. Not our finest moment.", needs = N(SAME, "within<=5"), says = { "killer", "gap", "react" }, voice = "wry" },
        { "Misery loves company. {ref} and I died {secs:within} apart.", says = { "react" }, voice = "wry" },
        { "Two of us dead {today}: {ref.noun} and me. Not a great showing.", says = { "react" }, voice = "wry" },
        { "{ref.short} and I died. {secs.cap:within} apart.", voice = "terse" },
        { "{foe.cap:foe} killed us both.", needs = SAME, says = { "killer" }, voice = "terse" },
        { "Died with {ref.short}. {secs.cap:within} apart.", voice = "terse" },
        { "{ref.short} first. Me {secs:within} later.", needs = THEY1, says = { "order" }, bonus = ORDER, voice = "terse" },
        { "Me first. {ref.short} {secs:within} later.", needs = ME1, says = { "order" }, bonus = ORDER, voice = "terse" },
        { "Died together, {ref.short} and I.", needs = TOGETHER, says = { "gap" }, voice = "terse" },
        { "{ref} and I went down near each other {today}, and I'm glad at least it was a friend.", needs = { "who.tags.friend" }, says = { "react" }, bonus = WHO, voice = "warm" },
        { "Of all the people to die beside, it was {ref.noun}.", needs = { "who.tags.avoid" }, bonus = WHO, voice = "wry" },
        { "{ref}, whom I'd marked as a foe, died within {secs:within} of me {today}. Same fate, at least.", needs = N("who.tags.foe", WITHIN), bonus = WHO },
        { "{ref} and I died {secs:within} apart. Opposite sides, same bad luck.", needs = { "who.hostile" }, bonus = WHO },
    }, { "theirs", "mine" }),
})

--------------------------------------------------------------------------
-- More in each voice
--------------------------------------------------------------------------

Words("misfortune", "shared", {
    stems = Join(Prep({
        { "Together to the last, ", needs = { "within<=10" }, says = { "gap" }, voice = "warm" },
        { "It was a hard fight for us both, and ", voice = "warm" },
        { "In a fine show of teamwork, ", says = { "react" }, voice = "wry" },
        { "Not our finest hour: ", says = { "react" }, voice = "wry" },
        { "Bad luck all round: ", says = { "react" }, voice = "terse" },
    }), Prep({
        { "I fell, and ", voice = "warm" },
        { "I died, and, not to be outdone, ", needs = ME1, says = { "order" }, bonus = ORDER, voice = "wry" },
    }, { "mine", "pair" })),

    clauses = Join(Prep({
        { "{ref} and I went down side by side", needs = { "within<=10" }, says = { "gap" }, voice = "warm" },
        { "{ref} and I fell together, more or less", needs = { "within<=15" }, says = { "gap" }, voice = "warm" },
        { "{ref} and I stood together, and fell together", needs = { "within<=10", "grouped" }, says = { "gap" }, voice = "warm" },
        { "{ref} and I died in step", needs = { "within<=5" }, says = { "gap" }, voice = "wry" },
        { "{ref} and I found the same end at much the same time", voice = "wry" },
        { "{ref} and I went down together, to nobody's credit", needs = { "within<=10" }, says = { "gap", "react" }, voice = "wry" },
        { "{ref} and I died, one, two", needs = { "within<=5", "within>=1" }, says = { "gap" }, voice = "terse" },
        { "{foe:foe} got us both, {secs:within} apart", needs = SAME, says = { "killer", "pair" }, voice = "terse" },
        { "{ref} died, then I did", needs = THEY1, says = { "order" }, bonus = ORDER, voice = "terse" },
        { "I died, then {ref} did", needs = ME1, says = { "order" }, bonus = ORDER, voice = "terse" },
    }, { "theirs", "mine" }), Prep({
        { "{ref} wasn't spared either", voice = "warm" },
        { "{ref} kept me company there too", voice = "wry" },
        { "{ref} too", says = { "sodid" }, bonus = 0.5, voice = "terse" },
    }, { "theirs" })),

    fragments = Prep({
        { "Fell together, {ref.short} and I", needs = { "within<=10" }, says = { "gap", "place" }, voice = "warm" },
        { "Side by side to the end, {ref.short} and I", needs = { "within<=10" }, says = { "gap", "place" }, voice = "warm" },
        { "Two corpses, {ref.poss} and mine", says = { "place" }, voice = "wry" },
        { "{ref.short} and me, both dead", says = { "place" }, voice = "terse" },
    }, { "theirs", "mine" }),

    tails = Prep({
        { ", and I was glad not to be alone in it", says = { "react" }, voice = "warm" },
        { ", which was a sorry sight", says = { "react" }, voice = "warm" },
        { ", neither of us any help to the other", says = { "react" }, voice = "wry" },
        { ", in a fine display of teamwork", says = { "react" }, voice = "wry" },
        { ". Unlucky", says = { "react" }, voice = "terse" },
    }),

    wholes = Prep({
        { "{ref} and I went down together {today}. If I had to die, I'd rather it was in company.", needs = { "within<=10" }, says = { "react" }, voice = "warm" },
        { "{ref} and I died {secs:within} apart {today}. I was sorry to see {him} fall.", says = { "react" }, voice = "warm" },
        { "We fought {foe:foe} together and fell together, {ref} and I.", needs = N(SAME, "grouped", "within<=10"), says = { "killer", "gap" }, voice = "warm" },
        { "{ref} went down {secs:within} before me. I was sorry for both of us.", needs = THEY1, says = { "order", "react" }, bonus = ORDER, voice = "warm" },
        { "I went down first, and {ref} followed {secs:within} later. I wish it had gone better for {him}.", needs = ME1, says = { "order", "react" }, bonus = ORDER, voice = "warm" },
        { "At least {ref} and I went down together.", needs = { "within<=10" }, says = { "gap", "react" }, voice = "warm" },
        { "{ref} and I both died to {foe:foe}, {secs:within} apart. Not a fight either of us will brag about.", needs = SAME, says = { "killer", "react" }, voice = "wry" },
        { "{ref} and I made a poor job of {foe:foe} {today}, and it made a good job of us.", needs = SAME, says = { "killer", "react" }, voice = "wry" },
        { "Teamwork, of a sort: {ref} and I died {secs:within} apart.", says = { "react" }, voice = "wry" },
        { "Dead, with {ref.obj} for company. {secs.cap:within} apart.", voice = "terse" },
        { "{foe.cap:foe} took us both. {ref.short} first.", needs = N(SAME, THEY1), says = { "killer", "order" }, bonus = ORDER, voice = "terse" },
        { "{foe.cap:foe} took us both. Me first.", needs = N(SAME, ME1), says = { "killer", "order" }, bonus = ORDER, voice = "terse" },
    }, { "theirs", "mine" }),
})
