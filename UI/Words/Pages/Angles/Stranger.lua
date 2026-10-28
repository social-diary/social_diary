-- The familiar stranger: someone I keep seeing near me, day after day,
-- without ever dealing with them. Observational and a little curious,
-- never more.
--
-- seen facts (the planner's)
--   who            the person, usually unnamed ({ref} describes them: "a
--                  night elf hunter", or "the night elf hunter" when the
--                  diary has described them before, `who.familiar`)
--   days           distinct days I saw them near me (3+)
--   windowDays     the stretch those days fall in (7 or 30)
--   zone, subZone  where I was for most of the sightings
--   sameSpot       most sightings were at the same spot (of mine)
--   sameTime       most sightings were around the same hour
--   levelFirst     their level the first day of the stretch
--   levelNow       their level now
--   levelRise      levelNow - levelFirst (0 when they haven't levelled)
--
-- silence facts
--   neverSpoke     we have never exchanged a word
--   neverGrouped   we have never grouped
--
-- The rules this file keeps: positions are mine ("near me at Astranaar",
-- "whenever I was at Astranaar"), never where they were; sightings are
-- hour buckets, so the words count days (or evenings, with sameTime),
-- never times; no guessing at what they want or why they are there; and
-- nothing that reads as watching or following. The curiosity is mine.
--
-- Slots declared here
--   {stranger_span:windowDays}   "week" or "month"
--   {stranger_parts:days}        days as parts of the day: "five evenings"
--                                (only with sameTime, when the hours match)
--   {stranger_tally}             days within the window, with "on": "on
--                                five of the last seven days", "every day
--                                this past week", "on eleven days in the
--                                past month", "on all but two days of the
--                                past month"
--
-- The seen move's clauses come in three tenses, and stems and tails say
-- which they fit (`fits`), so "Whenever I'm at Astranaar, it seems," never
-- meets "I saw him there":
--   E   today's sighting, past simple: "{ref} was near me again"
--   S   a summary of the days: "I've seen {ref.obj} near me on five days"
--   H   a habit, present: "I keep seeing {ref.obj} around"
--
-- Tags said beyond slots
--   days            (seen's point) any wording of how many days
--   silence         (silence's point) that we have kept to ourselves
--   st_stem_<t>, st_tail_<t>   tense (above): a clause of tense t says
--                   both; a stem or tail says those it doesn't fit
--   st_<move>_part  the time of day, once a sentence
--   st_<move>_place where I was, once a sentence
--   st_<move>_colon one colon to a sentence
--   st_<move>_again "again" or the like, once a sentence
--   st_curious      the narrator's curiosity, once
--   st_nonever      a silence clause without "never", kept from tails that
--                   lean on it (", not once")
--   st_state        a silence clause about how things stand ("we remain
--                   strangers"), kept from tails about all those days
--   st_gtail        a silence clause that can't take "nor grouped"
--   st_stail        a silence clause that can't take "or even spoken"

local addonName, ns = ...

local Pages = ns.Pages
local Words = Pages.Words
local Get = Pages.Get

local KINDS = { "stems", "clauses", "fragments", "tails", "wholes" }

--------------------------------------------------------------------------
-- Slots
--------------------------------------------------------------------------

local function Lang() return Pages.Lang end

Pages.Format("stranger_span", function(v)
    if type(v) ~= "number" then return nil end
    if v <= 7 then return "week" end
    if v <= 31 then return "month" end
    return nil
end)

-- "five evenings": only true when the sightings share their hours, so a
-- piece using it also needs sameTime.
Pages.Format("stranger_parts", function(v, env)
    local part = env.f.page and env.f.page.part
    if type(v) ~= "number" or not part then return nil end
    return Lang().Count(v, part)
end, { alsoNeeds = { "page.part" } })

Pages.Slot("stranger_tally", {
    needs = function() return { "days", "windowDays" } end,
    says = function() return { "days", "windowDays" } end,
    fn = function(env)
        local d, w = Get(env.f, "days"), Get(env.f, "windowDays")
        if type(d) ~= "number" or type(w) ~= "number" or d < 1 then return nil end
        local L = Lang()
        local span = w <= 7 and "week" or "month"
        if d >= w then return "every day this past " .. span end
        if w <= 7 then return "on " .. L.Num(d) .. " of the last " .. L.Num(w) .. " days" end
        if d >= w - 3 then
            return "on all but " .. L.Count(w - d, "day") .. " of the past month"
        end
        return "on " .. L.Num(d) .. " days in the past " .. span
    end,
})

--------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------

local function Add(list, v)
    for i = 1, #list do if list[i] == v then return end end
    list[#list + 1] = v
end

-- Pieces may share a needs or says table (needs = THEIRS); each gets its
-- own copy before anything is added to it.
local function Copy(list)
    local out = {}
    for i, v in ipairs(list or {}) do out[i] = v end
    return out
end

-- Described for the first time ("a night elf hunter"), and described
-- before ("the night elf hunter"). The guards keep the words true; their
-- weight in specificity is taken back off.
local FRESH = { "!who.familiar", "!who.named", "!who.diary" }
local KNOWN = { "who.familiar" }

local PLACES = { "{in:zone}", "{in.cap:zone}", "{at:subZone}", "{at.cap:subZone}", "{v:subZone}", "{v:zone}" }
local AGAIN = { "again", "once more", "not for the first time", "as so often", "as ever", "as before", "lately" }

local function Spec(spec, move)
    for _, kind in ipairs(KINDS) do
        for i, raw in ipairs(spec[kind] or {}) do
            local p = type(raw) == "string" and { raw } or raw
            local text = p[1]
            local bare = text:gsub("{[^}]*}", ""):lower()
            p.needs = Copy(p.needs)
            p.says = Copy(p.says)
            if p.fresh then
                for _, c in ipairs(FRESH) do Add(p.needs, c) end
                p.bonus = (p.bonus or 0) - 0.75
            end
            if p.known then
                for _, c in ipairs(KNOWN) do Add(p.needs, c) end
                p.bonus = (p.bonus or 0) - 0.25
            end
            if p.curious then Add(p.says, "st_curious") end
            -- Tense: a clause says "st_stem_<t>" and "st_tail_<t>" for its
            -- own; a stem or tail says those of the tenses it doesn't fit,
            -- so it never meets them (and a stem never blocks a tail).
            if p.t then
                Add(p.says, "st_stem_" .. p.t)
                Add(p.says, "st_tail_" .. p.t)
            end
            if p.fits then
                local k = kind == "stems" and "stem" or "tail"
                for _, t in ipairs({ "E", "S", "H" }) do
                    if not p.fits:find(t, 1, true) then Add(p.says, "st_" .. k .. "_" .. t) end
                end
            end
            -- An ordinal past twenty reads as a log ("the 24th day").
            if text:find("{nth", 1, true) then Add(p.needs, "days<=20") end
            if text:find("{today", 1, true) or text:find("{part", 1, true) or text:find("{stranger_parts", 1, true) then
                Add(p.says, "st_" .. move .. "_part")
            end
            for _, place in ipairs(PLACES) do
                if text:find(place, 1, true) then Add(p.says, "st_" .. move .. "_place") break end
            end
            if kind ~= "wholes" then
                if bare:find(":", 1, true) then Add(p.says, "st_" .. move .. "_colon") end
                local again = text:find("<again>", 1, true)
                for _, w in ipairs(AGAIN) do
                    if bare:find("%f[%a]" .. w .. "%f[%A]") then again = true end
                end
                if again then Add(p.says, "st_" .. move .. "_again") end
            end
            spec[kind][i] = p
        end
    end
    return spec
end

-- Every piece of a list says the move's point.
local function Point(list, tag)
    for i, raw in ipairs(list) do
        local p = type(raw) == "string" and { raw } or raw
        p.says = Copy(p.says)
        Add(p.says, tag)
        list[i] = p
    end
    return list
end

-- Every piece of a list has this tense.
local function Tense(t, list)
    for i, raw in ipairs(list) do
        local p = type(raw) == "string" and { raw } or raw
        p.t = p.t or t
        list[i] = p
    end
    return list
end

local function Concat(...)
    local out = {}
    for _, list in ipairs({ ... }) do
        for _, p in ipairs(list) do out[#out + 1] = p end
    end
    return out
end

Pages.Angle("stranger", { order = { "seen", "silence" },
    about = "a familiar stranger: seen near me on several days, never dealt with" })

--------------------------------------------------------------------------
-- seen: how often, and where I was
--------------------------------------------------------------------------

Words("stranger", "seen", Spec({
    must = { "days" },

    stems = {
        { "{today.cap}, ", fits = "E" },
        { "While I was {in:zone}, ", fits = "E" },
        { "While I was {at:subZone}, ", fits = "E" },
        { "Once again {today}, ", fits = "E" },
        { "Not for the first time, ", fits = "E" },
        { "As so often lately, ", fits = "E" },
        { "For the {nth:days} day in the past {stranger_span:windowDays}, ", fits = "E" },
        { "{count.cap:days:day} out of the last {num:windowDays}, and once again ", needs = { "days<@windowDays" }, fits = "E" },
        { "Every day this past {stranger_span:windowDays}, and once again ", needs = { "days>=@windowDays" }, fits = "E" },
        { "{nth.cap:days} day out of the last {num:windowDays}: ", needs = { "windowDays==7", "days<@windowDays" }, fits = "E" },
        { "For the {nth:days} {part} in the past {stranger_span:windowDays}, ", needs = { "sameTime" }, fits = "E" },
        { "Around the same hour as ever, ", needs = { "sameTime" }, fits = "E" },
        { "Same {part}, same place: ", needs = { "sameTime", "sameSpot" }, fits = "E" },
        { "Whenever I'm {at:subZone}, it seems, ", needs = { "sameSpot" }, fits = "H" },
        { "Lately, ", fits = "H" },
        { "Over the past {stranger_span:windowDays}, ", fits = "S" },
        { "Looking back over the past {stranger_span:windowDays}, ", fits = "S" },
        { "I can't explain it, but ", curious = true, fits = "EH", voice = "warm" },
        { "Somehow, not for the first time, ", fits = "E", voice = "warm" },
        { "I've noticed something: ", fits = "SH", curious = true, voice = "warm" },
        { "Like clockwork, ", needs = { "sameTime" }, fits = "E", voice = "wry" },
        { "As regular as the patrols, ", fits = "E", voice = "wry" },
        { "To my quiet satisfaction, ", fits = "E", voice = "warm" },
        { "Either the world is small or ", fits = "EH", voice = "wry" },
        { "Day {num:days}: ", fits = "E", voice = "terse" },
        { "Again {today}: ", fits = "E", voice = "terse" },
        { "{stranger_span.cap:windowDays} so far: ", fits = "S", voice = "terse" },
    },

    clauses = Concat(Tense("E", {
        "{ref} was near me {at:subZone}",
        "{ref} was near me {in:zone}",
        "{ref} was near me again",
        "{ref} was nearby again",
        "I <noticed> {ref.obj} near me <again>",
        "I <noticed> {ref.obj} near me {in:zone}",
        "I <noticed> {ref.obj} near me {at:subZone}",
        "{ref} turned up near me {at:subZone}",
        "{ref} was somewhere near me {in:zone}",
        "{ref} turned up near me again",
        "I <noticed> {ref.obj} for the {nth:days} day in the past {stranger_span:windowDays}",
        { "{ref} was near me for the {nth:days} day out of {num:windowDays}", needs = { "days<@windowDays" } },
        { "that {desc} was near me again", known = true },
        { "the same {desc} was near me again {at:subZone}", known = true },
        { "I <noticed> that {desc} again", known = true },
        { "I <noticed> the same {desc} near me again", known = true },
        { "{ref} was near me around the same hour as before", needs = { "sameTime" } },
        { "{ref} was near me {at:subZone}, the same spot as before", needs = { "sameSpot" } },
        { "{ref} was near me again, same place, same hour", needs = { "sameTime", "sameSpot" } },
        { "{ref.noun}, level {lvl:levelNow} now, was near me again" },
        { "{ref} was near me again, in my usual corner of {v:zone}", needs = { "sameSpot" } },
        { "{ref} was near me again, and I'm starting to look out for {him}", curious = true, voice = "warm", final = true },
        { "a familiar face turned up near me: {ref.noun}", voice = "warm", final = true },
        { "{ref} kept me company again, in a manner of speaking", voice = "warm", final = true },
        { "I found {ref.obj} near me again, which I've come to expect", voice = "warm", final = true },
        { "{ref} was near me again, as is apparently the custom", voice = "wry", final = true },
        { "{ref} and I kept our standing appointment {at:subZone}", needs = { "sameTime", "sameSpot" }, voice = "wry" },
        { "{ref} and I were, once again, neighbours of a sort", voice = "wry" },
        { "{ref} was near me again, right on schedule", needs = { "sameTime" }, voice = "wry" },
        { "it felt right to see {ref.obj} near me again", voice = "warm" },
        { "{ref} was near me {at:subZone} again, practically part of the furniture", needs = { "sameSpot" }, voice = "wry", final = true },
        { "I <noticed> {ref.obj} again", voice = "terse" },
    }), Tense("S", {
        "I saw {ref.obj} near me {stranger_tally}",
        "I've seen {ref.obj} near me {stranger_tally}",
        "I've seen {ref.obj} near me on {count:days:day} in the past {stranger_span:windowDays}",
        "{ref} has been near me on {count:days:day} now",
        "{ref} has turned up near me {stranger_tally}",
        { "I've had {ref.obj} near me on {count:days:day} out of the last {num:windowDays}", needs = { "days<@windowDays" } },
        { "I've had {ref.obj} near me every single day this {stranger_span:windowDays}", needs = { "days>=@windowDays" }, says = { "days" } },
        { "there's {ref} who's been near me on {count:days:day} now", fresh = true },
        { "that {desc} has been near me {stranger_tally}", known = true },
        { "I've counted {count:days:day} now with {ref.obj} somewhere near me", curious = true, voice = "warm" },
        { "{ref} has been part of my {stranger_span:windowDays}, near me on {count:days:day}", voice = "warm" },
        { "{ref} has been near me on {count:days:day}, which is more than some of my friends manage", needs = { "days>=5" }, voice = "wry", final = true },
        { "{ref.short}: {count:days:day} in the past {stranger_span:windowDays}", voice = "terse" },
    }), Tense("H", {
        "{ref} keeps turning up near me",
        { "{ref} keeps turning up whenever I'm {at:subZone}", needs = { "sameSpot" } },
        "I keep seeing {ref.obj} around",
        "I keep seeing {ref.obj} near me whenever I'm {in:zone}",
        "I keep seeing {ref.obj} near me",
        "{ref} is often somewhere near me {in:zone} these days",
        { "there's {ref} I keep seeing near me", fresh = true },
        { "there's {ref} who keeps turning up near me {in:zone}", fresh = true },
        { "I keep seeing that {desc}", known = true },
        { "I seem to see {ref.obj} near me wherever I go", voice = "wry" },
    })),

    fragments = Concat(Tense("E", {
        "{ref.short} again",
        "{ref.short} again, near me {at:subZone}",
        "{ref.short}, near me again",
        "{ref.short} around again",
        "{ref.short} nearby again {in:zone}",
        "{ref.short} near me, the {nth:days} day in the past {stranger_span:windowDays}",
        { "That {desc} again", known = true },
        { "The same {desc}, the same place", known = true, needs = { "sameSpot" } },
        { "A familiar stranger: {ref.noun}", fresh = true },
        { "Same {part}, same spot, same {desc}", known = true, needs = { "sameTime", "sameSpot" }, voice = "wry" },
        { "My regular stranger, {ref}", known = true, voice = "warm" },
        { "A familiar face, if not a name: {ref.noun}", needs = { "!who.named", "!who.diary" }, voice = "warm" },
        { "{ref.short}, my not-quite-acquaintance", voice = "wry" },
        { "{ref.short}, as reliable as the scenery", voice = "wry" },
        { "{ref.short}: day {num:days}", voice = "terse" },
        { "{ref.short} again, {v:subZone}", voice = "terse" },
        { "Seen: {ref.short}, again", voice = "terse" },
        { "{ref.short} near me again", voice = "terse" },
        { "{ref.short}, near me, same hour", needs = { "sameTime" }, voice = "terse" },
    }), Tense("S", {
        "{count.cap:days:day} now with {ref.obj} somewhere near me",
        { "{count.cap:days:day} out of {num:windowDays} with {ref.obj} near me", needs = { "days<@windowDays" } },
        { "{count.cap:days:day} of the same {desc}", known = true, voice = "terse" },
        { "{count.cap:days:day} in the company, more or less, of {ref.obj}", voice = "warm" },
    })),

    tails = {
        { ", the {nth:days} day in the past {stranger_span:windowDays}", fits = "E" },
        { ", the {nth:days} day out of {num:windowDays}", needs = { "days<@windowDays" }, fits = "E" },
        { ", every day this past {stranger_span:windowDays}", needs = { "days>=@windowDays" }, says = { "days" }, fits = "EH" },
        { " for the {nth:days} day in the past {stranger_span:windowDays}", fits = "E" },
        { ", {count:days:day} now in the past {stranger_span:windowDays}", fits = "EH" },
        { ", as {he} has been {stranger_tally}", fits = "E" },
        { ", which makes {count:days:day} now", fits = "E" },
        { ", which makes {count:days:day} out of the last {num:windowDays}", needs = { "days<@windowDays" }, fits = "E" },
        { ", always when I was {at:subZone}", needs = { "sameSpot" }, fits = "S" },
        { ", and always when I was in the same spot", needs = { "sameSpot" }, fits = "S" },
        { ", and always around the same hour", needs = { "sameTime" }, fits = "SH" },
        { ", always at about the same time of day", needs = { "sameTime" }, fits = "SH" },
        { ", and always in the {part}", needs = { "sameTime" }, fits = "SH" },
        { ", {stranger_parts:days} out of the last {num:windowDays} days", needs = { "sameTime", "windowDays==7", "days<@windowDays" }, fits = "EH" },
        { ", {stranger_parts:days} now in the past {stranger_span:windowDays}", needs = { "sameTime" }, fits = "EH" },
        { ", {count:days:day} in the past {stranger_span:windowDays}, same place and same hour", needs = { "sameTime", "sameSpot" }, fits = "EH" },
        { ", {count:days:day} in the past {stranger_span:windowDays}, level {lvl:levelNow} now", fits = "EH" },
        { ", level {lvl:levelNow} now", fits = "ESH" },
        { ", and up from level {lvl:levelFirst} to {lvl:levelNow} in that time", needs = { "levelRise>0" }, fits = "S" },
        { ", {count:days:day} now, and up from level {lvl:levelFirst} to {lvl:levelNow} in that time", needs = { "levelRise>0" }, fits = "EH" },
        { ", {count:days:day} now, and still level {lvl:levelNow}", needs = { "levelRise==0" }, fits = "EH" },
        { ", gaining {levels:levelRise} along the way", fits = "S" },
        { ", {count:days:day} now, and I'm starting to recognise {him}", curious = true, fits = "EH", voice = "warm" },
        { ", and I'm starting to recognise {him}", curious = true, fits = "S", voice = "warm" },
        { ", {count:days:day} now, which I've come to rather like", fits = "EH", voice = "warm" },
        { ", the {nth:days} day in the past {stranger_span:windowDays}, which I find oddly reassuring", fits = "E", voice = "warm" },
        { ", the {nth:days} day in the past {stranger_span:windowDays}, for reasons I can't explain", fits = "E", voice = "wry" },
        { ", {count:days:day} in the past {stranger_span:windowDays}, which is either coincidence or a very small world", fits = "EH", voice = "wry" },
        { ", which is either coincidence or a very small world", fits = "S", voice = "wry" },
        { ", {count:days:day} now, like a piece of the scenery", fits = "EH", voice = "wry" },
        { ", {count:days:day} now, and the place wouldn't feel the same without {him}", fits = "EH", voice = "warm" },
        { ", which at {count:days:day} feels like a standing arrangement", fits = "EH", voice = "wry" },
        { ", day {num:days}", fits = "E", voice = "terse" },
        { ", {num:days} of {num:windowDays} days", needs = { "days<@windowDays" }, fits = "E", voice = "terse" },
    },

    wholes = {
        "{ref} was near me again {today}, the {nth:days} day in the past {stranger_span:windowDays}.",
        "{count.cap:days:day} in the past {stranger_span:windowDays}, {ref} has been somewhere near me.",
        "{ref} was near me {at:subZone} {today}. That makes {count:days:day} in the past {stranger_span:windowDays}.",
        "Whenever I'm {in:zone} lately, {ref} seems to be near me. {count.cap:days:day} now.",
        "I keep seeing {ref.obj}. {count.cap:days:day} in the past {stranger_span:windowDays}, always somewhere near me.",
        "{ref.short} again {today}. That's {count:days:day} I've seen {him} near me {in:zone}.",
        { "{count.cap:days:day} out of the last {num:windowDays}, I've had {ref.obj} for a neighbour while I was {in:zone}.", needs = { "days<@windowDays" } },
        "{ref} was around again {today}. I make it {count:days:day} in the past {stranger_span:windowDays}.",
        "Another day, another sighting of {ref.obj} near me {at:subZone}: {count:days:day} now.",
        { "There's {ref} I keep seeing near me {at:subZone}: {count:days:day} in the past {stranger_span:windowDays}.", fresh = true },
        { "There's {ref} who keeps turning up near me. I counted {count:days:day} in the past {stranger_span:windowDays}.", fresh = true },
        { "I've started to recognise {ref.obj} near me {in:zone}. {count.cap:days:day} in the past {stranger_span:windowDays}.", fresh = true },
        { "That {desc} was near me again {today}, the {nth:days} day in the past {stranger_span:windowDays}.", known = true },
        { "The same {desc} again {today}. That's {count:days:day} out of the last {num:windowDays}.", needs = { "days<@windowDays" }, known = true },
        { "{ref} was near me {at:subZone} again {today}, always in that same spot. {count.cap:days:day} now.", needs = { "sameSpot" } },
        { "Every time I've been {at:subZone} lately, {ref} has been near me too. {count.cap:days:day} so far.", needs = { "sameSpot" } },
        { "{ref} turned up near me around the same hour as before. {count.cap:days:day} in the past {stranger_span:windowDays}, all at about the same time.", needs = { "sameTime" } },
        { "{stranger_parts.cap:days} in the past {stranger_span:windowDays}, and {ref} was near me on every one of them.", needs = { "sameTime" } },
        { "Same {part}, same spot, same face: {ref.noun}, near me for the {nth:days} day in the past {stranger_span:windowDays}.", needs = { "sameTime", "sameSpot" } },
        { "{ref} was level {lvl:levelFirst} the first day I noticed {him} this {stranger_span:windowDays}. {count.cap:days:day} of seeing {him} later, {he} is {lvl:levelNow}.", needs = { "levelRise>0" } },
        { "I've seen {ref.obj} near me on {count:days:day} now, and {he}'s gone up {levels:levelRise} in that time." },
        { "I've seen {ref.obj} near me on {count:days:day}, and {he}'s been level {lvl:levelNow} on every one of them.", needs = { "levelRise==0" } },
        { "{ref} was near me again. {count.cap:days:day} now. I'm starting to think of {him} as part of the place.", voice = "warm" },
        { "A familiar face again {today}: {ref.noun}, near me for the {nth:days} day in the past {stranger_span:windowDays}.", voice = "warm" },
        { "{ref} turned up near me again, and I found I was pleased to see {him}. {count.cap:days:day} now.", curious = true, voice = "warm" },
        { "I've grown used to seeing {ref.obj} near me. {count.cap:days:day} in the past {stranger_span:windowDays}, {today} included.", voice = "warm" },
        { "{ref} was near me again {today}. {count.cap:days:day}. At this point it would be odd not to see {him}.", needs = { "days>=4" }, voice = "warm" },
        { "Whenever I'm {at:subZone}, it seems, {ref} is somewhere near me. {count.cap:days:day} now, and I've started to look forward to it.", needs = { "sameSpot" }, voice = "warm" },
        { "{ref} keeps cropping up near me like a familiar landmark. {count.cap:days:day} in the past {stranger_span:windowDays}.", voice = "wry" },
        { "I keep finding {ref.obj} near me, and I've started to look out for {him}. {count.cap:days:day} now.", curious = true, voice = "warm" },
        { "If I'm {in:zone}, it seems, {ref} is never far off. {count.cap:days:day} in the past {stranger_span:windowDays}.", voice = "wry" },
        { "{ref} was near me for the {nth:days} day in the past {stranger_span:windowDays}. Either we keep the same hours or the world is smaller than I thought.", needs = { "sameTime" }, voice = "wry" },
        { "{count.cap:days:day} in the past {stranger_span:windowDays}, {ref} has been near me. One of us is very predictable, and it may well be me.", voice = "wry" },
        { "{ref.short} again {today}. I've now seen more of {him} than of some of my friends.", needs = { "days>=5" }, says = { "days" }, voice = "wry" },
        { "{ref.short}, near me {at:subZone}, for the {nth:days} day in the past {stranger_span:windowDays}. At this point {he} is practically part of my routine.", voice = "wry" },
        { "{ref.short} again. {count.cap:days:day} in the past {stranger_span:windowDays}.", voice = "terse" },
        { "{ref.short}, near me {at:subZone}. Day {num:days}.", voice = "terse" },
        { "Day {num:days} of {ref.obj} somewhere near me.", voice = "terse" },
        { "{count.cap:days:day} in the past {stranger_span:windowDays}: {ref.noun}.", voice = "terse" },
        { "{ref.short} again, {v:subZone}. {count.cap:days:day} of {num:windowDays}.", needs = { "days<@windowDays" }, voice = "terse" },
        { "{ref.short}. {count.cap:days:day}. Same spot.", needs = { "sameSpot" }, voice = "terse" },
        { "{ref.short}, near me. {count.cap:days:day}, same hour.", needs = { "sameTime" }, voice = "terse" },
        { "{ref} was near me again {today}. I don't know {his} name, but I'd know {him} anywhere. {count.cap:days:day} now.", needs = { "!who.named", "!who.diary" }, voice = "warm" },
        { "Even without a name, a familiar face is good to see. {ref} was near me again, the {nth:days} day in the past {stranger_span:windowDays}.", needs = { "!who.named", "!who.diary" }, voice = "warm" },
        { "{ref} again. {count.cap:days:day} in the past {stranger_span:windowDays}. If this keeps up I'll have to start nodding.", needs = { "!who.hostile" }, voice = "wry" },
        { "By now {ref} is practically part of the landscape: {count:days:day} out of {num:windowDays}.", needs = { "days<@windowDays" }, voice = "wry" },
    },
}, "seen"))

--------------------------------------------------------------------------
-- silence: and yet we have never dealt with each other
--------------------------------------------------------------------------

-- How a silence clause takes the tails: `g` takes "nor grouped" (it's
-- about words), `s` takes "or even spoken" (it's about groups); a clause
-- without "never" takes no ", not once"; a clause about how things stand
-- takes nothing about all those days.
local function Silent(list)
    for i, raw in ipairs(list) do
        local p = type(raw) == "string" and { raw } or raw
        p.says = Copy(p.says)
        if not p.g then Add(p.says, "st_gtail") end
        if not p.s then Add(p.says, "st_stail") end
        if not p[1]:lower():find("never", 1, true) then Add(p.says, "st_nonever") end
        if p.state then Add(p.says, "st_state") end
        list[i] = p
    end
    return list
end

Words("stranger", "silence", Spec({
    must = { "silence" },
    rel = "but",

    stems = {
        { "For all that, ", says = { "st_state" } },
        "And yet ",
        "Strangely, ",
        { "In all that time, ", says = { "st_state" } },
        { "Despite all those days, ", says = { "st_state" } },
        { "As far as I can remember, ", bonus = -0.5 },
        { "Funnily enough, ", voice = "wry" },
        { "For better or worse, ", voice = "wry" },
        { "I'm a little sorry to say ", voice = "warm" },
        { "Oddly, ", voice = "warm" },
        { "Still: ", voice = "terse" },
        { "Note: ", voice = "terse" },
    },

    clauses = Point(Silent({
        { "we've never spoken a word to each other", needs = { "neverSpoke" }, g = true },
        { "we've never exchanged a single word", needs = { "neverSpoke" }, g = true },
        { "neither of us has spoken a word to the other", needs = { "neverSpoke" }, g = true },
        { "not one word has passed between us", needs = { "neverSpoke" } },
        { "I've never spoken to {ref.obj}, nor {he} to me", needs = { "neverSpoke" }, final = true },
        { "{ref} and I have never spoken", needs = { "neverSpoke" }, g = true },
        { "we've never grouped", needs = { "neverGrouped" }, s = true },
        { "we've never been in a group together", needs = { "neverGrouped" }, s = true },
        { "{ref} and I have never grouped", needs = { "neverGrouped" }, s = true },
        { "I've never grouped with {ref.obj}", needs = { "neverGrouped" }, s = true },
        { "we've never once teamed up", needs = { "neverGrouped" }, s = true },
        { "we've never spoken or grouped", needs = { "neverSpoke", "neverGrouped" } },
        { "{ref} and I have never spoken, let alone grouped", needs = { "neverSpoke", "neverGrouped" }, final = true },
        { "we've never had anything to do with each other", needs = { "neverSpoke", "neverGrouped" } },
        { "we remain strangers", needs = { "neverSpoke", "neverGrouped" }, state = true },
        { "{ref} is as much a stranger as ever", needs = { "neverSpoke", "neverGrouped" }, state = true },
        { "we've never spoken, though we did group once", needs = { "neverSpoke", "!neverGrouped" }, final = true },
        { "we've never grouped, though we have exchanged a word or two", needs = { "neverGrouped", "!neverSpoke" }, final = true },
        { "I haven't introduced myself yet", needs = { "neverSpoke", "!who.hostile" }, g = true, voice = "warm" },
        { "I've never so much as said hello", needs = { "neverSpoke", "!who.hostile" }, g = true, voice = "warm" },
        { "we've managed all those days without a single word", needs = { "neverSpoke" }, says = { "st_state" }, voice = "wry", final = true },
        { "we've kept up a perfect silence", needs = { "neverSpoke" }, voice = "wry" },
        { "{ref} and I have perfected the art of not grouping", needs = { "neverGrouped" }, voice = "wry" },
        { "our acquaintance consists entirely of being near each other", needs = { "neverSpoke", "neverGrouped" }, voice = "wry", final = true },
    }), "silence"),

    fragments = Point(Silent({
        { "Never a word between us", needs = { "neverSpoke" } },
        { "Not a single word, in all that time", needs = { "neverSpoke" }, says = { "st_state" }, final = true },
        { "Never grouped, either", needs = { "neverGrouped" }, final = true },
        { "No group, no words", needs = { "neverSpoke", "neverGrouped" } },
        { "Not a word, not a group", needs = { "neverSpoke", "neverGrouped" } },
        { "Strangers still", needs = { "neverSpoke", "neverGrouped" }, state = true },
        { "Close by, and never a word", needs = { "neverSpoke" } },
        { "Never spoken, never grouped", needs = { "neverSpoke", "neverGrouped" }, voice = "terse" },
        { "No words yet", needs = { "neverSpoke" }, voice = "terse" },
        { "No group yet", needs = { "neverGrouped" }, voice = "terse" },
        { "Never spoken", needs = { "neverSpoke" }, g = true, voice = "terse" },
        { "Never grouped", needs = { "neverGrouped" }, s = true, voice = "terse" },
        { "Still not so much as a hello", needs = { "neverSpoke", "!who.hostile" }, voice = "warm" },
        { "The strong, silent type, evidently", needs = { "neverSpoke" }, voice = "wry", final = true },
        { "A neighbour I've never spoken to", needs = { "neverSpoke" }, voice = "wry" },
    }), "silence"),

    tails = {
        { ", or even spoken", needs = { "neverSpoke" }, says = { "st_stail" } },
        { ", and never spoken", needs = { "neverSpoke" }, says = { "st_stail" } },
        { ", let alone grouped", needs = { "neverGrouped" }, says = { "st_gtail" } },
        { ", or grouped either", needs = { "neverGrouped" }, says = { "st_gtail" } },
        { ", nor grouped", needs = { "neverGrouped" }, says = { "st_gtail" } },
        { ", in all those days", says = { "st_state" }, bonus = -0.5 },
        { ", for all the days we've been near each other", says = { "st_state" }, bonus = -0.5 },
        { ", not once", says = { "st_nonever", "st_state" } },
        { ", which I suppose is how it goes", voice = "warm" },
        { ", and that seems to suit us both", says = { "st_suit" } },
        { ", as far as I can tell", bonus = -0.5 },
        { ", and I can't say why", curious = true },
        { ", though I'd know {him} anywhere by now", needs = { "!who.named" }, says = { "st_state" }, voice = "warm" },
        { ", which feels a little strange, given how often I see {him}", says = { "st_state" }, voice = "warm" },
        { ", and somehow that's part of the charm", voice = "wry" },
        { ", which is its own kind of acquaintance", voice = "wry" },
        { ", and I wouldn't know where to start", needs = { "neverSpoke" }, says = { "st_stail" }, voice = "wry" },
        { ", and I keep meaning to change that", needs = { "!who.hostile" }, curious = true, voice = "warm" },
        { ", and maybe that's for the best", voice = "warm" },
        { ", which suits us both, apparently", says = { "st_suit" }, voice = "wry" },
        { ", a record I'm oddly proud of", says = { "st_state" }, voice = "wry" },
        { ", for the record", voice = "terse" },
    },

    -- Wholes that may take a lead ("But ") start in lower case; the first
    -- letter is capitalised when no lead comes.
    wholes = Point({
        { "we've never said a word to each other.", needs = { "neverSpoke" }, lead = true },
        { "not one word has passed between us.", needs = { "neverSpoke" }, lead = true },
        { "we've never grouped, never spoken.", needs = { "neverSpoke", "neverGrouped" }, lead = true },
        { "we've never spoken or grouped, not once.", needs = { "neverSpoke", "neverGrouped" }, lead = true },
        { "in all those days, we've never exchanged a word.", needs = { "neverSpoke" }, says = { "st_state" }, lead = true },
        { "For all that, {ref} and I have never grouped.", needs = { "neverGrouped" } },
        { "We've never grouped. We've never even spoken.", needs = { "neverSpoke", "neverGrouped" } },
        { "As far as the diary knows, {ref} and I have never spoken.", needs = { "neverSpoke" } },
        { "So close, so often, and never a word.", needs = { "neverSpoke" } },
        { "Never a group, never a word. Just there, near me, day after day.", needs = { "neverSpoke", "neverGrouped" } },
        { "And still we're strangers: no words, no group.", needs = { "neverSpoke", "neverGrouped" } },
        { "{ref} remains a stranger. We've never spoken.", needs = { "neverSpoke" } },
        { "{ref} remains a stranger. We've never grouped.", needs = { "neverGrouped" } },
        { "We've exchanged a word or two, but never grouped.", needs = { "neverGrouped", "!neverSpoke" } },
        { "We've grouped, I think, but we've never spoken.", needs = { "neverSpoke", "!neverGrouped" } },
        { "We've never spoken. One of these days I'll say hello.", needs = { "neverSpoke", "!who.hostile" }, curious = true, voice = "warm" },
        { "I've never said a word to {ref.obj}. Somehow that feels like an oversight.", needs = { "neverSpoke" }, curious = true, voice = "warm" },
        { "We've never grouped or spoken, and yet I'd notice if {ref} stopped turning up.", needs = { "neverSpoke", "neverGrouped" }, curious = true, voice = "warm" },
        { "Never a word between us. I find I'm curious all the same.", needs = { "neverSpoke" }, curious = true, voice = "warm" },
        { "we've never spoken. It seems a shame, somehow.", needs = { "neverSpoke", "!who.hostile" }, lead = true, voice = "warm" },
        { "we've never said a word to each other, which at this point would make saying one rather awkward.", needs = { "neverSpoke" }, lead = true, voice = "wry" },
        { "We've never grouped or spoken. A model of mutual discretion.", needs = { "neverSpoke", "neverGrouped" }, voice = "wry" },
        { "Never spoken, never grouped. We are excellent at being strangers.", needs = { "neverSpoke", "neverGrouped" }, voice = "wry" },
        { "Not a word between us yet. I'm told that's how the best acquaintances start.", needs = { "neverSpoke" }, voice = "wry" },
        { "we've never grouped. I suspect we never will, which somehow makes it better.", needs = { "neverGrouped" }, lead = true, voice = "wry" },
        { "Never spoken.", needs = { "neverSpoke" }, voice = "terse" },
        { "Never grouped.", needs = { "neverGrouped" }, voice = "terse" },
        { "No words. No group.", needs = { "neverSpoke", "neverGrouped" }, voice = "terse" },
        { "Still strangers.", needs = { "neverSpoke", "neverGrouped" }, voice = "terse" },
    }, "silence"),
}, "silence"))
