-- Ding: they levelled while I was there. The small joy of being around for
-- someone else's level, with special words for round levels, the level cap
-- and levelling together.
--
-- level facts
--   who               the person
--   level             their new level
--   from              the level before (level - levels)
--   together          we were grouped (else just nearby: no "in my group")
--   round             level is a multiple of ten
--   cap               level is the level cap
--   alsoMe            I levelled within minutes of them
--   levels            levels they gained while with me (1+)
--
-- The move must say `level`. Words for a single ding ("hit 33", "a level
-- up from 32") need "levels==1"; with two or more the pieces say so
-- ({levels:levels}, "twice", "from 31 to 33"). A plain level line doesn't
-- do for the cap, so those need "!cap"; round levels may be told plainly or
-- with their own words, which are preferred.
--
-- Slots declared here
--   {ding_prev:level}  the level before the new one, for two dings: "33"
--   {ding_bare:level}  the level, saying nothing (see the cap tails)
--
-- Tags of this file's own, so one sentence never says a thing twice
--   ding.there        that I was there or with them ("in my group", "right
--                     in front of me", "I was there when")
--   ding.when         where in the session it fell ("Along the way, ")
--   ding.joy          the narrator's pleasure at it
--   ding.span         how far they climbed ({lvl:from}, {levels:levels}):
--                     "from 31 to 33" and "two levels" say the same thing

local addonName, ns = ...

local Pages = ns.Pages
local Words = Pages.Words

Pages.Angle("ding", { order = { "level" },
    about = "they levelled while I was there" })

local ONE = "levels==1"
local MANY = "levels>=2"
local G = "together==true"
local NEAR = "!together"
local NOCAP = "!cap"
local THERE = "ding.there"
local WHEN = "ding.when"
local JOY = "ding.joy"
local SPAN = "ding.span"

-- Joins lists of needs: N(ROUND, ONE).
-- The level they passed through on the way, for two dings: "hit 33, then
-- 34". Reads `level`, so it says it.
Pages.Format("ding_prev", function(v)
    if type(v) ~= "number" or v < 2 then return nil end
    return tostring(v - 1)
end)

-- The new level as digits, saying nothing: a plain line about reaching the
-- cap uses it, so the sentence is only complete with a tail that names the
-- cap (those tails say `level`).
Pages.Format("ding_bare", function(v)
    if type(v) ~= "number" then return nil end
    return tostring(v)
end, { says = false })

local function N(...)
    local out = {}
    for _, part in ipairs({ ... }) do
        if type(part) == "table" then
            for _, c in ipairs(part) do out[#out + 1] = c end
        else
            out[#out + 1] = part
        end
    end
    return out
end

-- Round but not the cap: the cap has its own words.
local ROUND = { "round", NOCAP }

Words("ding", "level", {
    must = { "level" },
    needs = { "level" },

    stems = {
        { "Along the way, ", says = { WHEN } },
        { "Somewhere in there, ", says = { WHEN } },
        { "At one point, ", says = { WHEN } },
        { "While we were grouped, ", needs = { G }, says = { "together", THERE, WHEN } },
        { "While I was nearby, ", needs = { NEAR }, says = { "together", THERE, WHEN } },
        { "Right in front of me, ", needs = { NEAR }, says = { "together", THERE } },
        { "Then the big one: ", needs = N(ROUND, "!alsoMe"), says = { "milestone" } },
        { "And then, at last, ", needs = { "cap==true" }, says = { "ding.atlast" } },
        { "Best of all, ", voice = "warm" },
        { "To my delight, ", says = { JOY }, voice = "warm" },
        { "With no ceremony whatsoever, ", needs = { ONE, "!alsoMe" }, voice = "wry" },
        { "Within minutes of my own ding, ", needs = { "alsoMe", ONE }, says = { "alsoMe", THERE } },
        { "Ding: ", voice = "terse" },
        { "Without so much as a warning, ", needs = { ONE }, voice = "wry" },
    },

    clauses = {
        -- one level
        { "{ref} hit {lvl:level}", needs = { ONE, NOCAP } },
        { "{ref} reached level {lvl:level}", needs = { ONE, NOCAP } },
        { "{ref} dinged {lvl:level}", needs = { ONE, NOCAP } },
        { "{ref} made level {lvl:level}", needs = { ONE, NOCAP } },
        { "{ref} levelled to {lvl:level}", needs = { ONE, NOCAP } },
        { "{ref} ticked over to {lvl:level}", needs = { ONE, NOCAP } },
        { "{ref} went from {lvl:from} to {lvl:level}", needs = { ONE, NOCAP }, says = { SPAN } },
        { "{ref} levelled up to {lvl:level} in my group", needs = { ONE, G, NOCAP }, says = { "together", THERE } },
        { "{ref} hit {lvl:level} with me close by", needs = { ONE, NEAR, NOCAP }, says = { "together", THERE } },
        { "I was there when {ref} hit {lvl:level}", needs = { ONE, NOCAP }, says = { THERE, WHEN } },
        { "I got to see {ref.obj} reach {lvl:level}", needs = { ONE, NOCAP }, says = { THERE } },
        { "I saw {ref.obj} ding {lvl:level}", needs = { ONE, NEAR, NOCAP }, says = { THERE } },
        { "{ref} picked up a level, {lvl:level} now", needs = { ONE, NOCAP, "!round" }, says = { SPAN }, bonus = -0.5, final = true },

        -- several
        { "{ref} gained {levels:levels} while we were together, reaching {lvl:level}", needs = { MANY, NOCAP }, says = { SPAN, THERE, WHEN } },
        { "{ref} went from {lvl:from} to {lvl:level} with me", needs = { MANY, NOCAP }, says = { SPAN, THERE } },
        { "{ref} climbed {levels:levels}, to {lvl:level}", needs = { MANY, NOCAP }, says = { SPAN } },
        { "{ref} levelled {times:levels}, all the way to {lvl:level}", needs = { MANY, NOCAP }, says = { SPAN } },
        { "{ref} got {levels:levels} in my group, ending on {lvl:level}", needs = { MANY, G, NOCAP }, says = { "together", SPAN, THERE } },
        { "{ref} dinged {times:levels} in my company, up to {lvl:level}", needs = { MANY, NOCAP }, says = { SPAN, THERE } },
        { "I was there for {levels:levels} of {ref.poss}, {lvl:from} to {lvl:level}", needs = { MANY, NOCAP }, says = { SPAN, THERE } },
        { "{ref} hit {lvl:level}, the second ding I'd seen from {him} {today}", needs = { "levels==2", NOCAP }, says = { SPAN, THERE }, final = true },
        { "{ref} went up {levels:levels} in my company, to {lvl:level}, as if it were nothing", needs = { MANY, NOCAP }, says = { SPAN, THERE }, voice = "wry", final = true },

        -- round levels
        { "{ref} reached level {lvl:level}, a big one", needs = N(ROUND, ONE), says = { "milestone" }, final = true },
        { "{ref} hit {lvl:level}, one of the big round numbers", needs = ROUND, says = { "milestone" }, final = true },
        { "{ref} crossed into the {lvl:level}s", needs = N(ROUND, "level>=20"), says = { "milestone" } },
        { "{ref} made it to {lvl:level}, which is a milestone", needs = ROUND, says = { "milestone" }, final = true },
        { "{ref} reached the {lvl:level} mark", needs = ROUND, says = { "milestone" } },
        { "{ref} hit {lvl:level}, and round numbers always feel like something", needs = ROUND, says = { "milestone" }, final = true },

        -- the cap
        { "{ref} hit the level cap", needs = { "cap" }, says = { "level", "capWord" } },
        { "{ref} reached {lvl:level}, as high as it goes", needs = { "cap" }, says = { "capWord" }, final = true },
        { "{ref} reached max level", needs = { "cap" }, says = { "level", "capWord" } },
        { "{ref} hit {lvl:level}, the end of the road for levelling", needs = { "cap" }, says = { "capWord" }, final = true },
        { "{ref} finished levelling, {lvl:level} at last", needs = { "cap" }, says = { "capWord", "ding.atlast" }, final = true },
        { "{ref} made {lvl:level}, the cap", needs = { "cap" }, says = { "capWord" }, final = true },
        { "{ref} hit {lvl:level}, and that's as far as levels go", needs = { "cap" }, says = { "capWord" }, final = true },
        -- plain words for the cap, only ever drawn with a tail that names it
        { "{ref} made it to {ding_bare:level}", needs = { "cap==true" } },
        { "I watched {ref.obj} ding {ding_bare:level}", needs = { "cap==true", NEAR }, says = { THERE } },
        { "{ref} dinged {ding_bare:level} in my group", needs = { "cap==true", G }, says = { "together", THERE } },

        -- both of us
        { "{ref} and I levelled within minutes of each other, {he} to {lvl:level}", needs = { "alsoMe", ONE, NOCAP }, says = { THERE } },
        { "{ref} hit {lvl:level} and I levelled right after", needs = { "alsoMe", ONE, NOCAP }, says = { THERE }, final = true },
        { "{ref} dinged {lvl:level} just as I dinged too", needs = { "alsoMe", ONE, NOCAP }, says = { THERE }, final = true },
        { "{ref.short} and I both levelled, {he} to {lvl:level}", needs = { "alsoMe", NOCAP }, says = { THERE } },
        { "{ref} reached {lvl:level}, and I levelled minutes later", needs = { "alsoMe", NOCAP }, says = { THERE }, final = true },

        { "{ref} hit {lvl:level}, and I was glad to be there for it", needs = { ONE, NOCAP }, says = { JOY, THERE }, voice = "warm", final = true },
        { "I had a front-row seat when {ref} hit {lvl:level}", needs = { ONE, NOCAP }, says = { JOY, THERE, WHEN }, voice = "warm", bonus = 0.5 },
        { "{ref} reached {lvl:level} and I got to share it", needs = { ONE, G, NOCAP }, says = { JOY, THERE }, voice = "warm", final = true, bonus = 0.5 },
        { "{ref} levelled to {lvl:level}, and I was absurdly pleased about it", needs = { ONE, NOCAP }, says = { JOY }, voice = "warm", final = true },
        { "{ref} hit {lvl:level} while I watched, which I'm counting as helping", needs = { ONE, NEAR, NOCAP }, says = { THERE }, voice = "wry", final = true, bonus = 0.5 },
        { "{ref} hit {lvl:level} and I didn't, for once", needs = { ONE, "!alsoMe", NOCAP }, voice = "wry", final = true },
        { "{ref} dinged {lvl:level}, which is more than I managed", needs = { "!alsoMe", NOCAP }, voice = "wry", final = true },
        { "{ref} dinged {lvl:level}", needs = { ONE, NOCAP }, voice = "terse" },
        { "{ref} got {lvl:level}", needs = { ONE, NOCAP }, voice = "terse" },
        { "{ref} reached {lvl:level}, and I couldn't have been happier for {him}", needs = { NOCAP }, says = { JOY }, voice = "warm", final = true },
        { "{ref} levelled to {lvl:level} under my expert supervision", needs = { ONE, NOCAP }, voice = "wry", final = true },
        { "{ref} hit {lvl:level} while I contributed nothing in particular", needs = { ONE, NEAR, NOCAP }, says = { THERE }, voice = "wry", final = true },
        { "{ref} levelled, {lvl:level}", needs = { ONE, NOCAP }, voice = "terse", final = true },
    },

    fragments = {
        { "A level for {ref.obj}: {lvl:level}", needs = { ONE, NOCAP }, says = { SPAN } },
        { "Level {lvl:level} for {ref.obj}", needs = { ONE, NOCAP } },
        { "{lvl:level} for {ref.obj}, right in front of me", needs = { ONE, NEAR, NOCAP }, says = { THERE } },
        { "{ref.noun.short} to {lvl:level}", needs = { ONE, NOCAP } },
        { "There for {ref.poss} {lvl:level}", needs = { ONE, NOCAP }, says = { THERE } },
        { "{levels.cap:levels} for {ref.obj}, {lvl:from} to {lvl:level}", needs = { MANY, NOCAP }, says = { SPAN } },
        { "{ref.noun.short} from {lvl:from} to {lvl:level}", needs = { MANY, NOCAP }, says = { SPAN } },
        { "{ref.noun.short} up to {lvl:level}, {levels:levels} on", needs = { MANY, NOCAP }, says = { SPAN }, final = true },
        { "{lvl:level} for {ref.obj}, a round number", needs = ROUND, says = { "milestone" }, final = true },
        { "A milestone for {ref.obj}: level {lvl:level}", needs = ROUND, says = { "milestone" } },
        { "Max level for {ref.obj}", needs = { "cap" }, says = { "level", "capWord" } },
        { "{ref.noun.short} at the cap, {lvl:level}", needs = { "cap" }, says = { "capWord" }, final = true },
        { "{ding_bare:level} for {ref.obj}", needs = { "cap==true" } },
        { "The level cap for {ref.obj}, at last", needs = { "cap" }, says = { "level", "capWord", "ding.atlast" }, final = true },
        { "A level each for {ref.obj} and me", needs = { "alsoMe", ONE }, says = { "level", THERE } },
        { "{ref.noun.short} and me, both a level up, {he} to {lvl:level}", needs = { "alsoMe", ONE, NOCAP }, says = { THERE } },
        { "A good moment, {ref.poss} {lvl:level}, and I got to see it", needs = { ONE, NOCAP }, says = { JOY, THERE }, voice = "warm", final = true, bonus = 0.5 },
        { "{lvl:level} for {ref.obj}, and I was glad to see it", needs = { ONE }, says = { JOY, THERE }, voice = "warm", final = true },
        { "{ref.noun.short} to {lvl:level}, and no sign of stopping", needs = { MANY, NOCAP }, says = { SPAN }, voice = "wry", final = true, bonus = 0.5 },
        { "Another level for {ref.obj}, {lvl:level}", needs = { ONE, NOCAP }, says = { SPAN }, voice = "wry" },
        { "{ref.noun.short}: {lvl:level}", needs = { NOCAP }, voice = "terse", final = true },
        { "Ding for {ref.obj}, {lvl:level}", needs = { ONE, NOCAP }, voice = "terse" },
        { "{ref.noun.short} {lvl:from} to {lvl:level}", needs = { MANY }, says = { SPAN }, voice = "terse" },
        { "{ref.noun.short} at the cap", needs = { "cap" }, says = { "level", "capWord" }, voice = "terse" },
        { "{ref.poss} {lvl:level}, and I was there", needs = { ONE, NOCAP }, says = { THERE }, voice = "warm", final = true, bonus = 0.5 },
        { "Another ding for {ref.obj}, {lvl:level} now, and I'm keeping count", needs = { NOCAP }, voice = "wry", final = true },
        { "{ref.poss} {lvl:level}, witnessed by yours truly", needs = { ONE, NOCAP }, says = { THERE }, voice = "wry", final = true, bonus = 0.5 },
        { "{ref.noun.short}, level {lvl:level}", needs = { ONE, NOCAP }, voice = "terse" },
    },

    tails = {
        { " while we were grouped", needs = { G }, says = { "together", THERE } },
        { " in my group", needs = { G }, says = { "together", THERE } },
        { " with me close by", needs = { NEAR }, says = { "together", THERE } },
        { " right in front of me", needs = { NEAR }, says = { "together", THERE } },
        { ", {levels:levels} in one sitting", needs = { MANY }, says = { SPAN } },
        { ", {levels:levels} while I was around", needs = { MANY }, says = { SPAN, THERE } },
        { ", one of the round ones", needs = ROUND, says = { "milestone" } },
        { ", a milestone", needs = ROUND, says = { "milestone" } },
        { ", a proper milestone", needs = ROUND, says = { "milestone" } },
        { ", and that's the cap", needs = { "cap" }, says = { "capWord", "level" } },
        { ", as high as levels go", needs = { "cap" }, says = { "capWord", "level" } },
        { ", the level cap", needs = { "cap" }, says = { "capWord", "level" } },
        { ", the top of the ladder", needs = { "cap" }, says = { "capWord", "level" } },
        { ", and I levelled within minutes", needs = { "alsoMe" } },
        { ", and I wasn't far behind with a level of my own", needs = { "alsoMe" } },
        { ", minutes before I did", needs = { "alsoMe" } },
        { ", which was nice to see", says = { JOY } },
        { ", and I was there for it", says = { JOY, THERE } },
        { ", and I was glad to be there for it", says = { JOY, THERE }, voice = "warm" },
        { ", and I'm glad I didn't miss it", says = { JOY, THERE }, voice = "warm" },
        { ", which made my {part}", says = { JOY }, voice = "warm" },
        { ", and I was as pleased for {him} as I'd have been for myself", needs = { "!alsoMe" }, says = { JOY }, voice = "warm" },
        { ", and good for {him}", says = { JOY }, voice = "warm" },
        { ", not that I was keeping track", voice = "wry" },
        { ", while I stayed exactly where I was", needs = { "!alsoMe" }, voice = "wry" },
        { ", and I'm only slightly jealous", needs = { "!alsoMe" }, voice = "wry" },
        { ", and I made a note of it", voice = "wry" },
        { ", grouped", needs = { G }, says = { "together", THERE }, voice = "terse" },
        { ", and I'll remember that one", needs = { "round" }, voice = "warm" },
        { ", and I've been at my level for what feels like weeks", needs = { "!alsoMe" }, voice = "wry" },
        { ", with me as witness", says = { THERE }, voice = "wry" },
        { ", me too", needs = { "alsoMe" }, voice = "terse" },
    },

    wholes = {
        { "{ref} hit {lvl:level} while we were together.", needs = { ONE, NOCAP }, says = { THERE }, lead = true },
        { "{ref} reached level {lvl:level}, and I was there to see it.", needs = { ONE, NOCAP }, says = { JOY }, lead = true },
        { "I was there when {ref} reached {lvl:level}.", needs = { ONE, NOCAP }, lead = true },
        { "{ref} dinged {lvl:level} in my group.", needs = { ONE, G, NOCAP }, says = { "together" }, lead = true },
        { "{ref} hit {lvl:level} right in front of me.", needs = { ONE, NEAR, NOCAP }, says = { "together" }, lead = true },
        { "{ref} went from {lvl:from} to {lvl:level} while I was around.", needs = { ONE, NOCAP } },
        { "Level {lvl:level} for {ref.obj}, and I was there for it.", needs = { ONE, NOCAP }, says = { JOY } },
        { "{ref} picked up a level, {lvl:level} now.", needs = { ONE, NOCAP, "!round" }, bonus = -0.5 },
        { "{ref} gained {levels:levels} while we were together, from {lvl:from} to {lvl:level}.", needs = { MANY, NOCAP }, lead = true },
        { "{ref} levelled {times:levels} in my company, ending on {lvl:level}.", needs = { MANY, NOCAP } },
        { "I saw {ref.obj} go from {lvl:from} to {lvl:level}.", needs = { MANY, NEAR, NOCAP } },
        { "{ref} hit {ding_prev:level}, and then {lvl:level} not long after.", needs = { "levels==2", NOCAP }, says = { "levels", SPAN } },
        { "{ref} hit {ding_prev:level} while I was there, and then the cap.", needs = { "levels==2", "cap" }, says = { "levels", SPAN, "capWord", THERE } },
        { "{ref} climbed {levels:levels} with me, to {lvl:level}.", needs = { MANY, G, NOCAP }, says = { "together" } },
        { "{ref} reached {lvl:level}. Round numbers always feel like something.", needs = N(ROUND, ONE), says = { "milestone" } },
        { "{ref} hit {lvl:level}, one of the big ones, and I was there.", needs = ROUND, says = { "milestone", JOY } },
        { "Level {lvl:level} for {ref.obj}: a milestone, and I got to see it.", needs = ROUND, says = { "milestone", JOY } },
        { "{ref} crossed into the {lvl:level}s while we were together.", needs = N(ROUND, "level>=20"), says = { "milestone" } },
        { "{ref} hit the level cap: {lvl:level}, as high as it goes.", needs = { "cap" } },
        { "{ref} reached {lvl:level}, the level cap, and I was there.", needs = { "cap" }, says = { JOY } },
        { "{ref} finished levelling {today}. {lvl:level}, the end of the climb.", needs = { "cap" } },
        { "No more levels for {ref}: {he} hit {lvl:level} with me there.", needs = { "cap" } },
        { "{ref} reached max level, {lvl:level}, and I got to see it happen.", needs = { "cap" }, says = { JOY } },
        { "{ref} hit {lvl:level} and I levelled within minutes. A good {part} for both of us.", needs = { "alsoMe", ONE, NOCAP } },
        { "{ref} and I levelled within minutes of each other, {he} to {lvl:level}.", needs = { "alsoMe", ONE, NOCAP } },
        { "{ref} hit {lvl:level}; I levelled a few minutes later.", needs = { "alsoMe", NOCAP } },
        { "{ref.short} reached {lvl:level}, and I levelled within minutes of {him}.", needs = { "alsoMe", NOCAP } },
        { "{ref} and I dinged almost together, {he} to {lvl:level}.", needs = { "alsoMe", ONE, G }, says = { "together" } },
        { "{ref} hit the cap, and I levelled within minutes of {him}. Two dings, one of them final.", needs = { "alsoMe", "cap" }, says = { "level" } },

        { "{ref} hit {lvl:level}, and I was glad to be there for it.", needs = { ONE, NOCAP }, says = { JOY }, voice = "warm" },
        { "I got to see {ref.obj} reach {lvl:level}. Small thing, but it made my {part}.", needs = { ONE, NOCAP }, says = { JOY }, voice = "warm" },
        { "{ref} reached {lvl:level} in my group. Well earned.", needs = { ONE, G, NOCAP }, says = { "together" }, voice = "warm" },
        { "{ref} hit {lvl:level}, and I'm as pleased as if it were mine.", needs = N(ROUND, "!alsoMe"), says = { "milestone", JOY }, voice = "warm" },
        { "{ref} reached the cap. {lvl:level}. I was there, and I'm glad I was.", needs = { "cap" }, says = { JOY }, voice = "warm" },
        { "{ref} hit {lvl:level} and I levelled right after. Good to do it together.", needs = { "alsoMe", ONE, NOCAP }, says = { JOY }, voice = "warm" },
        { "{ref} went from {lvl:from} to {lvl:level} with me, and I enjoyed every ding.", needs = { MANY, NOCAP }, says = { JOY }, voice = "warm" },
        { "All those levels, and now {ref} is {lvl:level}. I'm glad I was there for the last one.", needs = { "cap" }, says = { JOY }, voice = "warm" },
        { "{ref} hit {lvl:level}. I hit nothing of note.", needs = { ONE, "!alsoMe", NOCAP }, voice = "wry" },
        { "{ref} dinged {lvl:level} while I was busy not levelling.", needs = { ONE, "!alsoMe", NOCAP }, voice = "wry" },
        { "{ref} went up {levels:levels} in my company, to {lvl:level}. I went up none.", needs = { MANY, "!alsoMe", NOCAP }, voice = "wry" },
        { "{ref} reached {lvl:level}. One of us is making progress.", needs = { ONE, "!alsoMe", NOCAP }, voice = "wry" },
        { "{ref} hit the cap, {lvl:level}, and is now officially done. Unlike me.", needs = { "cap", "!alsoMe" }, voice = "wry" },
        { "{ref} and I levelled within minutes of each other. I'm not saying who was first.", needs = { "alsoMe" }, says = { "level" }, voice = "wry" },
        { "{ref} hit {lvl:level}. Round numbers make me feel old.", needs = ROUND, says = { "milestone" }, voice = "wry" },
        { "{ref.noun.short}: {lvl:level}.", needs = { NOCAP }, voice = "terse" },
        { "{ref.noun.short} dinged {lvl:level}.", needs = { ONE, NOCAP }, voice = "terse" },
        { "{ref.noun.short}, {lvl:from} to {lvl:level}.", needs = { MANY, NOCAP }, voice = "terse" },
        { "{ref.noun.short} hit the cap.", needs = { "cap" }, says = { "level" }, voice = "terse" },
        { "{ref.noun.short} {lvl:level}. Me a level too, minutes later.", needs = { "alsoMe", NOCAP }, voice = "terse", bonus = 0.5 },
        { "{ref} hit {lvl:level} with me there. Those are the moments I keep this diary for.", needs = { NOCAP }, says = { JOY }, voice = "warm" },
        { "{ref} reached the cap with me there. I'll miss levelling alongside {him}.", needs = { "cap", G }, says = { "level" }, voice = "warm" },
        { "Seeing someone level never gets old. {ref} hit {lvl:level} {today}.", needs = { ONE, NOCAP }, voice = "warm" },
        { "{ref} hit {lvl:level}. I helped, in the sense that I was there.", needs = { ONE, NOCAP }, voice = "wry" },
        { "{ref} reached {lvl:level}. I'd have levelled too, but I was busy watching.", needs = { "!alsoMe", NOCAP }, voice = "wry" },
        { "{ref.noun.short} levelled. {lvl:level}.", needs = { NOCAP }, voice = "terse" },
        { "{lvl:level} for {ref.noun.short}. Round number.", needs = ROUND, says = { "milestone" }, voice = "terse" },
        { "{ref.noun.short} capped. {lvl:level}.", needs = { "cap" }, voice = "terse" },
    },
})
