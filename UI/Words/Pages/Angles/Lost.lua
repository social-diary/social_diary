-- Lost: a gentle coda about someone not met in a long time. It says how
-- long it has been and nothing about why. Never "she quit", never "he must
-- be busy", never a guess at where they are or what they are doing.
--
-- lost facts (the planner's)
--   who           the person (usually a diary entry)
--   lastDays      days since we last met (a together-session)
--   lastZone      where we last met
--   timesMet      meetings with them, all told
--   usualGapDays  their usual gap between meetings
--   longest       (bool) this absence is the longest yet
--   seenDays      days since I last saw them nearby without meeting, when
--                 that is more recent than lastDays (may be 0: today)
--   heardDays     days since their last whisper, when more recent
--
-- Honesty: "no sign", "not a word", "nothing at all" need both seenDays
-- and heardDays absent. "I haven't seen" needs no seenDays; "I haven't heard
-- from" needs no heardDays. "Met" is a together-session, so "I haven't met
-- her" stays true even when I saw her nearby, and the pieces that mention
-- the sighting or the whisper say so plainly. The present perfect suits a
-- coda ("it's been"), so clauses keep to it.

local addonName, ns = ...

local Pages = ns.Pages
local Words = Pages.Words

Pages.Angle("lost", { order = { "touch" }, about = "someone not met in a long time" })

local SEX = "who.sex>1"
local DIARY = "who.diary==true"
-- Absent, not just zero: seenDays 0 means I saw them today.
local NOSEEN = "!seenDays ~= __nil"
local NOHEARD = "!heardDays ~= __nil"
local SEEN = "seenDays ~= __nil"
local HEARD = "heardDays ~= __nil"

-- Tags read from the wording, so two pieces that make the same point, or
-- lean on the same word, never meet in one sentence.
local RULES = {
    { "lost:sign", { "no sign", "not a word", "nothing at all", "not a whisper", "no word", "nothing from", "silence", "still nothing", "nothing since" } },
    { "lost:miss", { "miss", "empty", "quieter", "notice", "half expect", "look for", "thinking of", "think of", "wonder" } },
    { "lost:count", { "counting", "count" } },
    { "lost:long", { "a long time", "too long", "long while", "getting long", "a while", "longer" } },
    { "lost:still", { "%f[%a]still%f[%A]" } },
    { "lost:place", { "page", "place", "diary", "these pages" } },
    { "lost:hope", { "hope", "wish", "one day", "some day", "next time", "again soon" } },
    { "lost:met", { "last met", "haven't met", "not met", "didn't meet", "haven't properly met", "meeting", "met since", "met in", "met up", "crossed" } },
    { "lost:now", { "%f[%a]now%f[%A]" } },
    { "lost:since", { "%f[%a]since%f[%A]" } },
    { "lost:though", { "though", ", but" } },
}

local KINDS = { "stems", "clauses", "fragments", "tails", "wholes" }

local function Tagged(spec)
    for _, kind in ipairs(KINDS) do
        local list = spec[kind] or {}
        for i = 1, #list do
            local piece = list[i]
            if type(piece) == "string" then
                piece = { piece }
                list[i] = piece
            end
            local bare = piece[1]:gsub("{[^}]*}", ""):gsub("<[^>]*>", ""):lower()
            piece.says = piece.says or {}
            for _, rule in ipairs(RULES) do
                for _, pattern in ipairs(rule[2]) do
                    if bare:find(pattern) then
                        piece.says[#piece.says + 1] = rule[1]
                        break
                    end
                end
            end
            -- A span inside the piece ("in two months") is never doubled by
            -- " in two months" or "not since Ashenvale" after it.
            if piece[1]:find("in {days:lastDays}", 1, true) or bare:find(", though") or bare:find(", but") then
                piece.says[#piece.says + 1] = "lost:in"
            end
            if piece[1]:find("lastZone", 1, true) then
                piece.says[#piece.says + 1] = "lastZone"
            end
            -- " in two months", "not since Ashenvale" and "Since we last met,"
            -- only go with a negative ("hasn't turned up", "still no
            -- Brennick"), never with "I miss her".
            if (kind == "clauses" or kind == "fragments")
                and (bare:find("%f[%a]still%f[%A]") or not (bare:find("n't") or bare:find("^%s*no "))) then
                piece.says[#piece.says + 1] = "lost:in"
            end
            -- A clause in the simple past ("I last met her in May") doesn't
            -- follow a stem that wants the present perfect ("For two months
            -- now,", "As the page closes,").
            if kind == "clauses" and (bare:find("^%s*the last") or bare:find("^%s*my last") or bare:find("last met")
                or bare:find("%f[%a]saw%f[%A]") or bare:find("whispered") or bare:find("%f[%a]was%f[%A]")) then
                piece.says[#piece.says + 1] = "lost:past"
            end
            -- One "and" to join: a stem ending in one never meets a tail
            -- that starts with one.
            if (kind == "stems" and bare:find("and%s*$")) or (kind == "tails" and bare:find("^, and ")) then
                piece.says[#piece.says + 1] = "lost:and"
            end
            -- A clause that already turns on "though" or "but" takes no tail.
            if (kind == "clauses" or kind == "fragments") and (bare:find(", though") or bare:find(", but"))
                and piece[1]:find("lastDays", 1, true) then
                piece.final = true
            end
            -- One colon a sentence.
            if (kind == "stems" and bare:find(":%s*$")) or (kind ~= "stems" and kind ~= "wholes" and bare:find(":")) then
                piece.says[#piece.says + 1] = "lost:colon"
            end
        end
    end
    return spec
end

--------------------------------------------------------------------------
-- touch: how long it has been
--------------------------------------------------------------------------

Words("lost", "touch", Tagged({
    must = { "lastDays" },

    stems = {
        { "{days.cap:lastDays} since we last met, and ", says = { "lost:past" } },
        { "It's been {days:lastDays}, and ", says = { "lost:past" } },
        { "For {days:lastDays} now, ", says = { "lost:in", "lost:past" } },
        { "{days.cap:lastDays} on from {v:lastZone}, and ", says = { "lost:past" } },
        { "As the page closes, ", says = { "lost:past" } },
        "One more thing before I stop: ",
        { "Still nothing: ", needs = { NOSEEN, NOHEARD }, says = { "lost:past" } },
        { "{count.cap:timesMet:meeting} all told, and ", needs = { "timesMet>=4" } },
        { "{days.cap:lastDays} and counting: ", says = { "lost:past" }, voice = "wry" },
        { "Not that I'm counting, but ", voice = "wry" },
        { "For the diary's sake, ", voice = "wry" },
        { "I keep thinking of {ref.obj}: ", voice = "warm" },
        { "Quietly, at the end of the page, ", says = { "lost:past" }, voice = "warm" },
        { "{days.cap:lastDays}: ", says = { "lost:past" }, voice = "terse" },
    },

    clauses = {
        -- the span itself
        "it's been {days:lastDays} since {ref} and I last met",
        "it's been {days:lastDays} since I last met {ref.obj}",
        "{ref} and I haven't met in {days:lastDays}",
        "I haven't met {ref.obj} in {days:lastDays}",
        "the last time I met {ref.obj} was {ago:lastDays}",
        "my last meeting with {ref.obj} was {ago:lastDays}",
        "I last met {ref.obj} {ago:lastDays}, {in:lastZone}",
        "{ref} and I last met {in:lastZone}, {ago:lastDays}",
        { "the last I saw of {ref.obj} was {in:lastZone}, {ago:lastDays}", needs = { NOSEEN } },
        { "the last I saw of {ref.obj} was {ago:lastDays}", needs = { NOSEEN } },
        { "{ref} and I haven't crossed paths in {days:lastDays}", needs = { NOSEEN } },
        { "I haven't seen {ref.obj} in {days:lastDays}", needs = { NOSEEN } },
        { "there's been no sign of {ref.obj} in {days:lastDays}", needs = { NOSEEN, NOHEARD } },
        { "I've had nothing from {ref.obj} in {days:lastDays}", needs = { NOSEEN, NOHEARD } },
        { "it's been {days:lastDays} since I last saw {ref.obj}", needs = { NOSEEN } },
        { "{ref} hasn't crossed my path in {days:lastDays}", needs = { NOSEEN } },

        -- no span (a stem or tail gives it)
        { "I still haven't met {ref.obj}", bonus = -0.5 },
        { "{ref} and I still haven't met", bonus = -0.5 },
        { "{ref} hasn't turned up", needs = { NOSEEN } },
        { "{ref} and I haven't crossed paths", needs = { NOSEEN } },
        { "there's been no sign of {ref.obj}", needs = { NOSEEN, NOHEARD } },
        { "I haven't heard a word from {ref.obj}", needs = { NOHEARD } },
        { "{ref} hasn't come my way", needs = { NOSEEN } },

        -- the honest exceptions
        { "I haven't met {ref.obj} in {days:lastDays}, though I saw {him} near me {ago:seenDays}", needs = { "seenDays", SEX } },
        { "{ref} and I haven't met in {days:lastDays}, though I did see {him} nearby {ago:seenDays}", needs = { "seenDays", SEX } },
        { "I saw {ref.obj} near me {ago:seenDays}, but we haven't met in {days:lastDays}", needs = { "seenDays" } },
        { "I saw {ref.obj} near me {today}, but we haven't met in {days:lastDays}", needs = { "seenDays==0" }, says = { "seenDays" } },
        { "I haven't met {ref.obj} in {days:lastDays}, though a whisper came {ago:heardDays}", needs = { "heardDays" } },
        { "{ref} and I haven't met in {days:lastDays}, though I heard from {him} {ago:heardDays}", needs = { "heardDays", SEX } },
        { "{ref} whispered me {ago:heardDays}, but we haven't met in {days:lastDays}", needs = { "heardDays" } },

        -- the longest
        { "{ref} and I have never gone this long without meeting", needs = { "longest" } },
        { "this is the longest {ref} and I have gone without meeting", needs = { "longest" } },

        -- warm, wry, terse
        { "I miss {ref.obj}", voice = "warm", bonus = -0.5, final = true },
        { "I find I miss {ref.obj}", voice = "warm", final = true },
        { "I still half expect to see {ref.obj} around the next corner", needs = { NOSEEN }, voice = "warm", final = true },
        { "{ref.poss} absence is getting long", voice = "warm", final = true },
        { "{ref} is still missing from my {part}s", voice = "warm", final = true },
        { "{ref} has a page in this diary that could do with a new line", needs = { DIARY }, voice = "warm", final = true },
        { "{ref} remains conspicuously absent from my {part}s", voice = "wry", final = true },
        { "I'm keeping {ref.poss} place in the diary warm", needs = { DIARY }, voice = "wry", final = true },
        { "{ref} and I are overdue a meeting", voice = "wry", final = true },
        { "no {ref.short}", needs = { NOSEEN, NOHEARD }, voice = "terse" },
        { "still no {ref.short}", needs = { NOSEEN, NOHEARD }, voice = "terse" },
    },

    fragments = {
        "{days.cap:lastDays} since I last met {ref.obj}",
        "{days.cap:lastDays} since {ref.short} and I last met",
        "Haven't met {ref.obj} since {v:lastZone}, {ago:lastDays}",
        "Not a meeting with {ref.obj} in {days:lastDays}",
        "Still no meeting with {ref.obj}",
        { "No sign of {ref.short} for {days:lastDays}", needs = { NOSEEN, NOHEARD } },
        { "No sign of {ref.short}", needs = { NOSEEN, NOHEARD } },
        { "Still no {ref.short}", needs = { NOSEEN, NOHEARD } },
        { "{days.cap:lastDays} without {ref.obj}", needs = { NOSEEN, NOHEARD } },
        { "{days.cap:lastDays} without seeing {ref.obj}", needs = { NOSEEN } },
        { "{ref.short} glimpsed near me {ago:seenDays}, but not met in {days:lastDays}", needs = { "seenDays" } },
        { "A whisper from {ref.obj} {ago:heardDays}, but no meeting in {days:lastDays}", needs = { "heardDays" } },
        { "The longest gap yet with {ref.obj}: {days:lastDays}", needs = { "longest" } },
        { "{ref.short}, missed", voice = "warm" },
        { "Thinking of {ref.obj} at the end of the page", voice = "warm" },
        { "{ref.short}, still on my mind", voice = "warm" },
        { "{ref.short}, still absent from these pages", voice = "wry" },
        { "{ref.short}, overdue", voice = "wry" },
        { "{ref.short}: {days:lastDays}", voice = "terse" },
        { "{ref.short}: last met {in:lastZone}, {ago:lastDays}", voice = "terse" },
        { "No {ref.short}. {days.cap:lastDays} now", needs = { NOSEEN, NOHEARD }, voice = "terse" },
    },

    tails = {
        ", {days:lastDays} since we last met",
        ", {days:lastDays} now",
        { ", not since {v:lastZone}, {ago:lastDays}", says = { "lost:in" } },
        { ", not since we last met {in:lastZone}", says = { "lost:in" } },
        { " since we last met {in:lastZone}, {ago:lastDays}", says = { "lost:in" } },
        { " in {days:lastDays}", says = { "lost:in" }, bonus = -0.5 },
        { ", though I saw {him} near me {ago:seenDays}", needs = { "seenDays", SEX } },
        { ", though I did see {him} nearby {ago:seenDays}", needs = { "seenDays", SEX } },
        { ", though {he} was near me {today}", needs = { "seenDays==0", SEX }, says = { "seenDays" } },
        { ", though a whisper came from {him} {ago:heardDays}", needs = { "heardDays", SEX } },
        { ", though I heard from {him} {ago:heardDays}", needs = { "heardDays", SEX } },
        { ", the longest we've gone yet", needs = { "longest" } },
        { ", longer than we've ever gone", needs = { "longest" } },
        { ", our longest gap so far", needs = { "longest" } },
        { ", when we used to meet every few days", needs = { "usualGapDays<=4", "lastDays>=14" }, says = { "usualGapDays" } },
        { ", when a week apart used to be a lot for us", needs = { "usualGapDays<=7", "lastDays>=28" }, says = { "usualGapDays" } },
        { ", a long time for us", needs = { "lastDays>@usualGapDays", "lastDays>=21" }, says = { "usualGapDays" } },
        { ", and we've met {times:timesMet} in all", needs = { "timesMet>=3" } },
        { ", and I miss {him}", needs = { SEX }, voice = "warm" },
        { ", and I notice it", voice = "warm" },
        { ", and the pages are quieter for it", voice = "warm" },
        { ", which feels longer than it is", voice = "warm" },
        { ", not that I'm counting", voice = "wry" },
        { ", and yes, I've been counting", voice = "wry" },
        { ", which is a long time in Azeroth", voice = "wry" },
        { ", for the record", voice = "terse" },
    },

    wholes = {
        -- plain
        "It's been {days:lastDays} since {ref} and I last met.",
        "I haven't met {ref.obj} in {days:lastDays}.",
        "{ref} and I last met {in:lastZone}, {ago:lastDays}.",
        "The last time I met {ref.obj} was {ago:lastDays}, {in:lastZone}.",
        "{days.cap:lastDays} now since I last met {ref.obj}.",
        "My last meeting with {ref.obj} was {in:lastZone}, {ago:lastDays}. Nothing since.",
        "{v:lastZone}, {ago:lastDays}: that's the last time {ref} and I met.",
        "Still no meeting with {ref.obj}. It's been {days:lastDays}.",
        "It's {days:lastDays} since I last met {ref.obj}, and the page ends without {him} again.",
        { "No sign of {ref.obj} {today} either. It's been {days:lastDays}.", needs = { NOSEEN, NOHEARD } },
        { "No sign of {ref.obj} in {days:lastDays}, not since {v:lastZone}.", needs = { NOSEEN, NOHEARD } },
        { "I haven't seen {ref.obj} since we last met {in:lastZone}, {ago:lastDays}.", needs = { NOSEEN } },
        { "{days.cap:lastDays}, and not a word from {ref.obj}.", needs = { NOSEEN, NOHEARD } },
        { "Nothing from {ref.obj} in {days:lastDays}: no meeting, no whisper.", needs = { NOSEEN, NOHEARD } },
        { "{ref} hasn't crossed my path since {v:lastZone}, {ago:lastDays}.", needs = { NOSEEN } },
        { "It's been {days:lastDays} since I last saw {ref.obj}.", needs = { NOSEEN } },

        -- the sighting
        { "I haven't met {ref.obj} in {days:lastDays}, though I saw {him} near me {ago:seenDays}.", needs = { "seenDays", SEX } },
        { "{days.cap:lastDays} since {ref} and I last met. I did see {him} nearby {ago:seenDays}, but we didn't meet.", needs = { "seenDays", SEX } },
        { "I saw {ref.obj} near me {ago:seenDays}, but we haven't met since {v:lastZone}, {ago:lastDays}.", needs = { "seenDays" } },
        { "{ref} was near me {ago:seenDays}, though we haven't properly met in {days:lastDays}.", needs = { "seenDays" } },
        { "No meeting with {ref.obj} in {days:lastDays}, just a glimpse near me {ago:seenDays}.", needs = { "seenDays" } },
        { "I saw {ref.obj} near me {today}, but we didn't meet. It's {days:lastDays} since we did.", needs = { "seenDays==0" }, says = { "seenDays" } },

        -- the whisper
        { "I haven't met {ref.obj} in {days:lastDays}, though {he} whispered me {ago:heardDays}.", needs = { "heardDays", SEX } },
        { "{days.cap:lastDays} since {ref} and I last met, but a whisper came {ago:heardDays}.", needs = { "heardDays" } },
        { "No meeting with {ref.obj} since {v:lastZone}, {ago:lastDays}. I did hear from {him} {ago:heardDays}.", needs = { "heardDays" } },
        { "A whisper from {ref.obj} {ago:heardDays}, but no meeting in {days:lastDays}.", needs = { "heardDays" } },
        { "I saw {ref.obj} near me {ago:seenDays} and heard from {him} {ago:heardDays}, but we haven't met in {days:lastDays}.", needs = { "seenDays", "heardDays", SEX } },

        -- the longest, the usual
        { "It's been {days:lastDays} since {ref} and I last met, the longest we've ever gone.", needs = { "longest" } },
        { "{ref} and I have never gone {days:lastDays} without meeting before.", needs = { "longest" } },
        { "This is the longest stretch yet without {ref.obj}: {days:lastDays}, not since {v:lastZone}.", needs = { "longest", NOSEEN, NOHEARD } },
        { "We used to meet every few days, {ref} and I. It's been {days:lastDays}.", needs = { "usualGapDays<=4", "lastDays>=14" }, says = { "usualGapDays" } },
        { "{ref} and I usually meet every few days. This time it's been {days:lastDays}.", needs = { "usualGapDays<=4", "lastDays>=14" }, says = { "usualGapDays" } },
        { "After {count:timesMet:meeting}, it's been {days:lastDays} since the last one, with {ref.obj} {in:lastZone}.", needs = { "timesMet>=4" } },
        { "{count.cap:timesMet:meeting} with {ref.obj}, and the last was {ago:lastDays}.", needs = { "timesMet>=3" } },

        -- warm
        { "I miss {ref.obj}. It's been {days:lastDays} since we last met.", voice = "warm" },
        { "{days.cap:lastDays} since I last met {ref.obj}, and I notice it.", voice = "warm" },
        { "Thinking of {ref.obj} {today}. We last met {in:lastZone}, {ago:lastDays}.", voice = "warm" },
        { "It's been {days:lastDays} since {ref} and I last met. The pages are quieter without {him}.", needs = { SEX }, voice = "warm" },
        { "Part of me still expects to run into {ref.obj} whenever I'm back in {v:lastZone}. {days.cap:lastDays} now.", needs = { NOSEEN }, voice = "warm" },
        { "{ref} has a place in this diary, and it's been empty for {days:lastDays}.", needs = { DIARY }, voice = "warm" },
        { "I hope {ref} and I meet again soon. It's been {days:lastDays}.", voice = "warm" },
        { "{days.cap:lastDays} without meeting {ref.obj}. Some days I mind more than others.", voice = "warm" },
        { "A whisper from {ref.obj} {ago:heardDays}, and I was glad of it, but it's been {days:lastDays} since we met.", needs = { "heardDays" }, voice = "warm" },

        -- wry
        { "{days.cap:lastDays} since I last met {ref.obj}. Not that I'm counting.", voice = "wry" },
        { "{ref} and I last met {ago:lastDays}. I have, apparently, been counting.", voice = "wry" },
        { "Still no {ref.short}, {days:lastDays} on. The diary keeps a page open, just in case.", needs = { NOSEEN, NOHEARD, DIARY }, voice = "wry" },
        { "{ref} remains at large: {days:lastDays} since we last met.", voice = "wry" },
        { "{days.cap:lastDays} since {v:lastZone}, and {ref} and I are well overdue a meeting.", voice = "wry" },
        { "I saw {ref.obj} near me {ago:seenDays} and still managed not to meet {him}. {days.cap:lastDays} now.", needs = { "seenDays", SEX }, voice = "wry" },
        { "{ref} whispered me {ago:heardDays}, which counts for something, though not as a meeting. {days.cap:lastDays} now.", needs = { "heardDays" }, voice = "wry" },
        { "I've stopped pretending I'm not counting: {days:lastDays} since {ref} and I last met.", voice = "wry" },

        -- terse
        { "{ref.short}: not met in {days:lastDays}.", voice = "terse" },
        { "{ref.short}: not met since {v:lastZone}. {days.cap:lastDays}.", voice = "terse" },
        { "No {ref.short}. {days.cap:lastDays}.", needs = { NOSEEN, NOHEARD }, voice = "terse" },
        { "{ref.short}. Last met {in:lastZone}, {ago:lastDays}.", voice = "terse" },
        { "{ref.short}: seen {ago:seenDays}, not met in {days:lastDays}.", needs = { "seenDays" }, voice = "terse" },
        { "{ref.short}: a whisper {ago:heardDays}. No meeting in {days:lastDays}.", needs = { "heardDays" }, voice = "terse" },
        { "Still no {ref.short}. {days.cap:lastDays}, the longest yet.", needs = { NOSEEN, NOHEARD, "longest" }, voice = "terse" },
    },
}))

--------------------------------------------------------------------------
-- More voices
--------------------------------------------------------------------------

Words("lost", "touch", Tagged({
    stems = {
        { "Before I close the book, ", says = { "lost:past" }, voice = "warm" },
        { "For the record, and not that it matters, ", says = { "lost:past" }, voice = "wry" },
    },
    clauses = {
        { "I'd like to see {ref.obj} again", voice = "warm", final = true },
        { "my path and {ref.poss.noun} haven't crossed in {days:lastDays}", needs = { NOSEEN }, voice = "wry" },
    },
    fragments = {
        { "{ref.short}, still in my thoughts, {days:lastDays} on", voice = "warm" },
        { "{ref.short}: whereabouts unknown, to me at least", needs = { NOSEEN, NOHEARD }, voice = "wry" },
        { "{ref.short}: {days:lastDays}, no meeting", voice = "terse" },
        { "Not met since {v:lastZone}: {ref.short}", voice = "terse" },
    },
    tails = {
        { ", and the diary feels the gap", voice = "warm" },
        { ", which I mention only in passing", voice = "wry" },
        { ", for anyone keeping score", voice = "wry" },
    },
    wholes = {
        { "{days.cap:lastDays} since {ref} and I last met. I'd be glad of another {part} in {his} company.", needs = { SEX }, voice = "warm" },
        { "Every so often I think of {ref.obj}. We last met {in:lastZone}, {ago:lastDays}.", voice = "warm" },
        { "Still no meeting with {ref.obj}, {days:lastDays} on. I'll keep a seat by the fire.", voice = "warm" },
        { "{days.cap:lastDays} since I last met {ref.obj}. Azeroth is big, but not that big.", voice = "wry" },
        { "The diary would like a word with {ref.obj}. It's been {days:lastDays}.", needs = { DIARY }, voice = "wry" },
        { "{days.cap:lastDays} since {ref} and I last met. If this were a quest, it would be overdue.", voice = "wry" },
        { "{ref} and I seem to keep missing each other: {days:lastDays} now since we last met.", needs = { "seenDays" }, voice = "wry" },
        { "{ago.cap:lastDays}, {in:lastZone}: the last entry with {ref.obj} in it, and it's getting dusty.", needs = { DIARY }, voice = "wry" },
        { "It's been {days:lastDays} since I last met {ref.obj}, which is not a complaint, merely an observation.", voice = "wry" },
        { "{ref.short}. {days.cap:lastDays}. Nothing.", needs = { NOSEEN, NOHEARD }, voice = "terse" },
        { "Last met {ref.short}: {v:lastZone}, {ago:lastDays}.", voice = "terse" },
        { "{ref.short}: still not met. {days.cap:lastDays}.", voice = "terse" },
        { "{ref.short}: whisper {ago:heardDays}, last met {ago:lastDays}.", needs = { "heardDays" }, voice = "terse" },
    },
}))

