-- Quiet: the whole page when little happened (no who). An uneventful
-- session told as a calm, honest entry: where, how long, who wasn't
-- there. It never pads the page with things the facts don't hold.
--
-- line facts (page.* plus)
--   nobodyKnown       no diary entry met
--   seen              players seen nearby (0 or more)
--   gained            levels gained (= page.levelsGained, may be 0)
--
-- Every clause, fragment and whole says "quiet.line", the point of the
-- move. Tags said through page facts are shared with the opener, the
-- closer and the crowd, so the zones or the hour the opener named aren't
-- named again here; the plain "a quiet evening" lines cover that page.
--
-- Slots declared here
--   {quiet_zone}      the session's zone, when there was only one
--   {quiet_zones}     the session's zones as a list, when there were several
--   {quiet_two} {quiet_many}   guards: exactly two zones / three or more

local addonName, ns = ...

local Pages = ns.Pages
local Words = Pages.Words

Pages.Angle("quiet", { order = { "line" },
    about = "the whole page when little happened" })

local function ZoneSlot(name, fn)
    Pages.Slot(name, {
        needs = function() return { "page.zones" } end,
        says = function() return { "page.zones", "page.zoneFirst", "page.zoneLast" } end,
        fn = function(env)
            local z = env.f.page and env.f.page.zones
            if type(z) == "table" and #z > 0 then return fn(z) end
        end,
    })
end
ZoneSlot("quiet_zone", function(z) if #z == 1 then return z[1] end end)
ZoneSlot("quiet_zones", function(z) if #z >= 2 then return Pages.Lang.List(z) end end)

-- Guards: write nothing, and drop the sentence unless the zone count fits.
local function Guard(name, test)
    Pages.Slot(name, {
        needs = function() return { "page.zones" } end,
        says = function() return {} end,
        fn = function(env)
            local z = env.f.page and env.f.page.zones
            if type(z) == "table" and test(#z) then return "" end
        end,
    })
end
Guard("quiet_two", function(n) return n == 2 end)
Guard("quiet_many", function(n) return n >= 3 end)

-- Adds the move's tag to every clause, fragment and whole, and the page
-- tags a piece says without a slot saying them: the hour ({today}), my
-- levels (`gained` is page.levelsGained), the players seen, and guards
-- that are also claims ("on my own").
local KINDS = { "stems", "clauses", "fragments", "tails", "wholes" }
local CORE = { clauses = true, fragments = true, wholes = true }
local NEED_TAGS = {
    ["page.solo"] = "page.solo", ["page.myDeaths==0"] = "page.myDeaths",
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

local DEFAULT = { ["nobodyKnown"] = true, ["page.solo"] = true }

local function Line(spec)
    for _, kind in ipairs(KINDS) do
        local list = spec[kind] or {}
        for i = 1, #list do
            local p = list[i]
            if type(p) == "string" then p = { p }; list[i] = p end
            local says = {}
            if CORE[kind] then says[1] = "quiet.line" end
            for _, t in ipairs(p.says or {}) do says[#says + 1] = t end
            local text = p[1]
            if text:find("{today", 1, true) then says[#says + 1] = "page.part" end
            -- the part of the day named twice in one sentence reads as a repeat
            if text:find("{today", 1, true) or text:find("{part", 1, true) then says[#says + 1] = "quiet.part" end
            local gained, seen = text:find(":gained}", 1, true), text:find(":seen", 1, true)
            for _, need in ipairs(p.needs or {}) do
                if NEED_TAGS[need] then says[#says + 1] = NEED_TAGS[need] end
                if need:find("^gained") then gained = true end
                if need:find("^seen") then seen = true end
                -- nobody seen at all says nobody I knew, too
                if need == "seen==0" then says[#says + 1] = "nobodyKnown" end
            end
            -- a level, after the opener's climb, would be said twice
            if gained then says[#says + 1] = "gained"; says[#says + 1] = "page.levelsGained"; says[#says + 1] = "open.climb" end
            Moods(text, says)
            if seen then says[#says + 1] = "seen"; says[#says + 1] = "page.seen" end
            if text:find("all {part}", 1, true) or text:find("All {part}", 1, true) then says[#says + 1] = "page.seconds" end
            p.says = says
            -- On a quiet page, nobody I knew and playing alone are the
            -- usual case, not news: they shouldn't push the plain lines out.
            for _, need in ipairs(p.needs or {}) do
                if DEFAULT[need] then p.bonus = (p.bonus or 0) - 0.75 end
            end
        end
    end
    return spec
end

-- Guards on the numbers. "A few" is two to six.
local NOBODY = { "seen==0" }
local NOLEVEL = { "gained==0" }
local ONE = { "gained==1" }

-- Roles, so the pieces of one sentence agree with each other:
--   D        a stem that wants "I" next, or a clause that doesn't start with it
--   V        a verdict: a fact about people or levels, or how I felt about
--            the session. One per sentence, so a mood never trails a fact
--            ("I didn't gain a level, and I liked it that way") and moods
--            don't stack.
--   NOSTEM   a clause that stands at the start of its sentence
--   LITTLE   says that little happened
local D, V, NOSTEM, LITTLE = "quiet.dangle", "quiet.verdict", "quiet.stem", "quiet.little"

--------------------------------------------------------------------------
-- line: the page
--------------------------------------------------------------------------

Words("quiet", "line", Line({
    must = { "quiet.line" },

    stems = {
        -- the hour and the place: these go with anything
        { "{today.cap}, ", says = { NOSTEM } },
        { "For {dur:page.seconds}, ", says = { NOSTEM } },
        { "In {zones}, ", says = { NOSTEM } },
        { "Out in {zones} {today}, ", says = { NOSTEM } },
        { "For most of the {part}, ", needs = { "page.seconds>=3600" }, says = { NOSTEM } },
        -- company and mood: only before a plain account of the session
        { "With nobody from the diary about, ", needs = { "nobodyKnown" }, says = { NOSTEM, V } },
        { "Without a single familiar face, ", needs = { "nobodyKnown" }, says = { NOSTEM, V, D } },
        { "On my own {today}, ", needs = { "page.solo" }, says = { NOSTEM, V, D } },
        { "Unhurried, ", says = { NOSTEM, V, D }, voice = "warm" },
        { "At an easy pace, ", says = { NOSTEM, V, D, "pace" }, voice = "warm" },
        { "With the {part} to myself, ", needs = { "page.solo" }, says = { NOSTEM, V, D }, voice = "warm" },
        { "For the record, ", says = { NOSTEM }, voice = "wry" },
        { "In news that will shock no one, ", says = { NOSTEM }, voice = "wry" },
        { "Brace yourself: ", says = { NOSTEM }, voice = "wry" },
        { "To nobody's surprise, ", says = { NOSTEM }, voice = "wry" },
        { "Quiet {part}: ", says = { NOSTEM }, voice = "terse" },
        { "{dur.cap:page.seconds}, {zones}: ", says = { NOSTEM }, voice = "terse" },
    },

    clauses = {
        -- the session as a whole
        { "it was a quiet {part}", says = { D } },
        { "it was a quiet {part} in {zones}", says = { D } },
        { "nothing much happened", says = { D, LITTLE } },
        { "not a great deal happened in {zones}", says = { D, LITTLE } },
        { "the {part} passed quietly", says = { D } },
        { "the {part} went by without much to report", says = { D, LITTLE } },
        { "{quiet_zone} was quiet {today}", says = { D } },
        { "{quiet_zones} were both quiet {today}{quiet_two}", says = { D } },
        { "{quiet_zones} were all quiet {today}{quiet_many}", says = { D } },
        { "I kept to myself in {zones}", needs = { "page.solo" } },
        { "I spent {dur:page.seconds} in {zones} without much to show for it", needs = NOLEVEL, says = { LITTLE } },
        { "I had little to write about {today}", says = { LITTLE, NOSTEM }, final = true },
        { "I pottered about in {zones}", bonus = -0.25 },
        { "I took my time in {zones}", voice = "warm" },
        { "I enjoyed {zones} at my own pace", says = { "pace" }, voice = "warm" },
        { "the {part} drifted by pleasantly", says = { D }, voice = "warm" },
        { "the diary and I had a slow {part}", says = { D }, voice = "wry" },
        { "I spent {dur:page.seconds} doing nothing worth writing down, and here I am writing it down", says = { LITTLE, NOSTEM }, voice = "wry", final = true },
        { "I was glad of the peace", says = { V, NOSTEM }, voice = "warm" },
        { "the highlight was logging on", says = { D, NOSTEM }, voice = "wry" },
        { "it was quiet", says = { D }, voice = "terse" },
        -- people
        { "I played alone, and quietly", needs = { "page.solo" }, says = { V } },
        { "I didn't group with anyone", needs = { "page.solo" }, says = { V } },
        { "I didn't meet anyone I knew", needs = { "nobodyKnown" }, says = { V } },
        { "nobody from the diary turned up", needs = { "nobodyKnown" }, says = { D, V } },
        { "I didn't see a single other player", needs = NOBODY, says = { V }, bonus = 0.5 },
        { "I saw nobody at all", needs = NOBODY, says = { V }, bonus = 0.5 },
        { "I had {quiet_zone} to myself", needs = NOBODY, says = { V }, bonus = 0.5 },
        { "I had {quiet_zone} more or less to myself", needs = { "seen<=3" }, says = { V } },
        { "I saw {count:seen:other player}, none of them anyone I knew", needs = { "nobodyKnown", "seen>=2" }, says = { V }, final = true },
        { "the only players I saw were strangers", needs = { "nobodyKnown", "seen>=2" }, says = { D, V } },
        { "the only other player I saw was a stranger", needs = { "nobodyKnown", "seen==1" }, says = { D, V } },
        { "I saw a fair few players, but nobody I knew", needs = { "nobodyKnown", "seen>=12" }, says = { V }, bonus = 0.5 },
        -- levels
        { "I picked up {levels:gained} and not much else", says = { V, LITTLE, NOSTEM } },
        { "the one bit of news was a level", needs = ONE, says = { D, V, NOSTEM }, final = true },
        { "I gained a level, quietly", needs = ONE, says = { V, NOSTEM } },
        { "I didn't gain a level", needs = NOLEVEL, says = { V, NOSTEM } },
        { "I stayed level {lvl:page.levelEnd}", needs = NOLEVEL, says = { V, NOSTEM } },
        { "I didn't die once", needs = { "page.myDeaths==0" }, says = { V } },
        { "I achieved very little, and did it thoroughly", needs = NOLEVEL, says = { V, NOSTEM, LITTLE }, voice = "wry", final = true },
        { "nothing happened", says = { D, LITTLE }, voice = "terse" },
        -- how it felt
        { "I had a peaceful {part} in {zones}", says = { V }, voice = "warm" },
        { "I enjoyed the quiet", says = { V, NOSTEM }, voice = "warm" },
        { "I was glad of {part.a} without fuss", says = { V, NOSTEM }, voice = "warm" },
        { "even the diary struggled to find something to say", says = { D, V, LITTLE }, voice = "wry" },
    },

    fragments = {
        "A quiet {part}",
        "A quiet {part} in {zones}",
        "A quiet one {today}",
        { "Not much to report", says = { LITTLE } },
        { "Not much to tell {today}", says = { LITTLE } },
        { "{dur.cap:page.seconds} in {zones}, and not much to say about it", says = { LITTLE }, final = true },
        "A slow {part} in {zones}",
        { "A short, quiet session", needs = { "page.seconds<2700" } },
        { "A long, quiet {part}", needs = { "page.seconds>=10800" } },
        { "No familiar faces", needs = { "nobodyKnown" }, says = { V } },
        { "Nobody I knew, all {part}", needs = { "nobodyKnown", "page.seconds>=3600" }, says = { V } },
        { "Not a soul about", needs = NOBODY, says = { V }, bonus = 0.5 },
        { "Not another player in sight", needs = NOBODY, says = { V }, bonus = 0.5 },
        { "{quiet_zone} all to myself", needs = NOBODY, says = { V }, bonus = 0.5 },
        { "A few strangers about, nobody I knew", needs = { "nobodyKnown", "seen>=2", "seen<=6" }, says = { V }, final = true },
        { "Plenty of players about, none I knew", needs = { "nobodyKnown", "seen>=12" }, says = { V }, final = true, bonus = 0.5 },
        { "A level, and not much else", needs = ONE, says = { V, LITTLE }, final = true },
        { "One level, quietly earned", needs = ONE, says = { V } },
        { "No levels and no company", needs = { "gained==0", "page.solo", "nobodyKnown" }, says = { V }, final = true },
        { "Solo, and quiet", needs = { "page.solo" }, says = { V } },
        { "A peaceful {part}", says = { V }, voice = "warm" },
        { "A gentle {part} in {zones}", says = { V }, voice = "warm" },
        { "A calm {part}, and a welcome one", says = { V }, voice = "warm", final = true },
        { "Just me and {quiet_zone}", needs = { "page.solo", "seen<=4" }, says = { V }, voice = "warm" },
        { "{part.a.cap} of small things", says = { V }, voice = "warm" },
        { "Another thrilling instalment", says = { V }, voice = "wry" },
        { "Not exactly an epic", says = { V }, voice = "wry" },
        { "Stop the presses: nothing", says = { V, LITTLE }, voice = "wry", final = true },
        { "{dur.cap:page.seconds} of very little", says = { LITTLE }, voice = "wry" },
        { "Quiet", voice = "terse" },
        { "Quiet {part}", voice = "terse" },
        { "Nothing to report", says = { LITTLE }, voice = "terse" },
        { "{zones}, quiet", voice = "terse" },
        { "Nobody I knew", needs = { "nobodyKnown" }, says = { V }, voice = "terse" },
        { "Nobody from the diary", needs = { "nobodyKnown" }, says = { V }, voice = "terse" },
    },

    tails = {
        -- what little there was
        { ", and that was about it", says = { V, LITTLE } },
        { " in {zones}", bonus = -0.5 },
        { " in {dur:page.seconds} of play", says = { D } },
        -- company (an I-subject tail can't follow a clause that doesn't
        -- start with I: "nothing much happened, on my own")
        { ", on my own", needs = { "page.solo" }, says = { D } },
        { ", with nobody I knew about", needs = { "nobodyKnown" }, says = { V } },
        { ", with no sign of anyone from the diary", needs = { "nobodyKnown" }, says = { V } },
        { ", with not another player in sight", needs = NOBODY, says = { V }, bonus = 0.5 },
        { ", though I saw {count:seen:other player}, none I knew", needs = { "nobodyKnown", "seen>=2", "seen<=8" }, says = { V } },
        { ", among plenty of players, none I knew", needs = { "nobodyKnown", "seen>=12" }, says = { V }, bonus = 0.5 },
        -- levels, against the grain of the rest
        { ", though I did pick up a level", needs = ONE },
        { ", though I did gain {levels:gained}", needs = { "gained>=2" } },
        { ", with a level to show for it", needs = ONE },
        { ", and I stayed level {lvl:page.levelEnd}", needs = NOLEVEL },
        { ", without dying once", needs = { "page.myDeaths==0" }, says = { D, V } },
        -- how it felt
        { ", which was just what I wanted", says = { V }, voice = "warm" },
        { ", and I liked it that way", says = { V }, voice = "warm" },
        { ", and none the worse for it", says = { V, D }, voice = "warm" },
        { ", if you can call that news", says = { V }, voice = "wry" },
        { ", in case anyone's keeping track", says = { V }, voice = "wry" },
        { ", and I'm choosing to call it restful", says = { V }, voice = "wry" },
        { ", give or take a level", needs = ONE, voice = "wry" },
        { ", solo", needs = { "page.solo" }, says = { D }, voice = "terse" },
        { ", one level", needs = ONE, voice = "terse" },
        { ", no deaths", needs = { "page.myDeaths==0" }, voice = "terse" },
    },

    wholes = {
        "A quiet {part} in {zones}.",
        "Not much happened {today}. I spent {dur:page.seconds} in {zones}.",
        "{today.cap} was quiet: {dur:page.seconds} in {zones}, and not much more to say.",
        "I spent {dur:page.seconds} in {zones} {today}. Nothing much happened.",
        "A quiet one. {dur.cap:page.seconds} in {zones}.",
        "There isn't much to write about {today}.",
        { "Some entries are short. This is one of them.", bonus = 0.25 },
        "{dur.cap:page.seconds} in {zones}, and the diary has little to show for it.",
        "Nothing much to report from {zones} {today}.",
        "{today.cap} I was in {zones}, and that's most of the story.",
        { "I was in {quiet_zone} {today}, and it was a quiet {part}." },
        { "{quiet_zones}, {today}. Quiet in all of them{quiet_many}.", bonus = 0.25 },
        { "{quiet_zones} {today}, and quiet in both{quiet_two}.", bonus = 0.25 },
        { "A short, quiet session in {zones}.", needs = { "page.seconds<2700" } },
        { "A long, quiet {part} in {zones}: {dur:page.seconds}, and not much to tell.", needs = { "page.seconds>=10800" } },
        -- nobody I knew
        { "I didn't meet anyone I knew {today}.", needs = { "nobodyKnown" } },
        { "It was a quiet {part}, and nobody from the diary turned up.", needs = { "nobodyKnown" } },
        { "No familiar faces {today}, in {quiet_zone} or anywhere else.", needs = { "nobodyKnown" } },
        { "I saw {count:seen:other player} {today}, but none of them anyone I knew.", needs = { "nobodyKnown", "seen>=2" } },
        { "A few strangers about, nobody I knew. Quiet.", needs = { "nobodyKnown", "seen>=2", "seen<=6" } },
        { "Plenty of other players in {zones}, but nobody from these pages.", needs = { "nobodyKnown", "seen>=12" }, bonus = 0.5 },
        { "The only other player I saw {today} was a stranger.", needs = { "nobodyKnown", "seen==1" } },
        -- nobody at all
        { "I didn't see another player all {part}.", needs = { "seen==0", "page.seconds>=3600" }, bonus = 0.5 },
        { "Not another soul in {zones} {today}, as far as I saw.", needs = NOBODY, bonus = 0.5 },
        { "I had {quiet_zone} to myself {today}.", needs = NOBODY, bonus = 0.5 },
        { "Nobody else about {today}; just me in {zones}.", needs = NOBODY, bonus = 0.5 },
        -- alone
        { "I played alone {today}, in {zones}. Nothing much came of it.", needs = { "page.solo" } },
        { "A solo {part} in {zones}, and a quiet one.", needs = { "page.solo" } },
        { "I didn't group with anyone {today}, and nothing much happened.", needs = { "page.solo" } },
        -- levels
        { "One level {today}, {lvl:page.levelStart} to {lvl:page.levelEnd}. That was the news.", needs = ONE },
        { "The only news {today} was a level: I'm {lvl:page.levelEnd} now.", needs = ONE },
        { "I gained {levels:gained} {today}, and that's about all there is to say.", needs = { "gained>=1" } },
        { "{levels.cap:gained} {today}, quietly, and nothing else worth writing down.", needs = { "gained>=2" } },
        { "No levels {today}; I'm still {lvl:page.levelEnd}.", needs = NOLEVEL },
        { "I didn't gain a level {today}, and nothing else happened either.", needs = NOLEVEL },
        { "No deaths, no drama: {dur:page.seconds} in {zones}.", needs = { "page.myDeaths==0" } },
        -- warm
        { "A quiet {part} in {zones}, and I didn't mind at all.", voice = "warm", bonus = 0.25 },
        { "Nothing much happened {today}, and that was fine by me.", voice = "warm" },
        { "A peaceful {part}. {dur.cap:page.seconds} in {zones}, at my own pace.", voice = "warm" },
        { "Not every {part} needs a story. {today.cap} was just {zones}, and I enjoyed it.", voice = "warm" },
        { "I had {quiet_zone} to myself for a while {today}, which was lovely.", needs = NOBODY, voice = "warm", bonus = 0.5 },
        { "Just me and {quiet_zone} {today}. I liked it.", needs = { "page.solo", "seen<=4" }, voice = "warm" },
        { "No familiar faces {today}, but a pleasant {part} all the same.", needs = { "nobodyKnown" }, voice = "warm" },
        { "A level, a quiet {part} in {zones}, and no complaints.", needs = ONE, voice = "warm" },
        { "Quiet {today}, and I was glad of it.", voice = "warm" },
        -- wry
        { "Nothing to report. I'm reporting it anyway.", voice = "wry" },
        { "{today.cap}'s entry, in full: {zones}, {dur:page.seconds}, nothing.", voice = "wry", bonus = 0.25 },
        { "{part.a.cap} so uneventful I nearly didn't write it down.", voice = "wry" },
        { "If anything happened in {zones} {today}, it happened without me.", voice = "wry", bonus = 0.25 },
        { "{dur.cap:page.seconds} in {zones} and nothing to show for it. Character-building, I'm told.", needs = NOLEVEL, voice = "wry" },
        { "Nobody I knew, nothing of note. Riveting.", needs = { "nobodyKnown" }, voice = "wry" },
        { "I had {quiet_zone} entirely to myself {today}. Either I'm early or everyone else has better things to do.", needs = NOBODY, voice = "wry", bonus = 0.5 },
        { "One level. Hold the celebrations.", needs = ONE, voice = "wry" },
        { "Still level {lvl:page.levelEnd}. Some days the world just doesn't cooperate.", needs = NOLEVEL, voice = "wry" },
        -- terse
        { "Quiet. {zones}.", voice = "terse" },
        { "{zones}. {dur.cap:page.seconds}. Nothing much.", voice = "terse" },
        { "Quiet {part}. Nobody I knew.", needs = { "nobodyKnown" }, voice = "terse" },
        { "Solo. Quiet. {zones}.", needs = { "page.solo" }, voice = "terse" },
        { "Nothing to report.", voice = "terse" },
        { "One level. Otherwise nothing.", needs = ONE, voice = "terse", bonus = 0.25 },
        { "No one about. {zones}.", needs = NOBODY, voice = "terse", bonus = 0.25 },
    },
}))
