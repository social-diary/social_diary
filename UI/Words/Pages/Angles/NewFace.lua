-- New faces: someone I dealt with for the first time today, told by the way
-- we met, and whether I wrote them into the diary.
--
-- meet facts (the planner's)
--   who            the person, new to me today
--   how            "group", "trade", "duel", "campfire", "chat", "rescue" or "say"
--   viaGroup, viaTrade, viaDuel, viaCampfire, viaChat, viaRescue, viaSay
--                  the flag matching `how`; exactly one is true
--   zone, subZone  where I was when we met (the user's own position)
--   seconds        how long we were grouped (viaGroup only)
--   quests         quests completed together (viaGroup only)
--   guildmate      they are in my guild
--   theirLevel     their level when we met
--
-- added facts
--   addedToday     I wrote them into the diary today
--   tag            their first tag ("friend", "healer", "avoid", ...), if any
--
-- The words follow the evidence. "Met", "a new face" and "sat down" only
-- when we were near each other, so never with viaChat, which is "heard
-- from" and "got talking". Nobody's mind but mine: no guessing who opened a
-- trade, asked for a duel or sent the first whisper, and no duel results.
--
-- The meet move's words come in two layers: general words that work
-- whichever way we met ("I met {ref.obj}", "Someone new tonight: "), and words
-- for one way of meeting (Via below), which need that flag and say "how".
-- Every meet sentence holds exactly one piece that says how, so a Via
-- clause takes a general stem or tail, and a Via tail a general clause.
--
-- Tags this file says beyond its slots. What a sentence says is remembered
-- for the rest of the page about this person, so a tag that only shapes
-- one sentence carries its move's name.
--   how               the way we met (every meet sentence must say it)
--   added             that I wrote them into the diary (every added sentence)
--   nf_new            that they were new to me
--   nf_today          {today}: "tonight" once on the page
--   nf_<move>_part    {part}, {share} or {today}: the time of day once a sentence
--   nf_<move>_place   where I was, once a sentence ("In Ashenvale ... at
--                     Astranaar" never)
--   nf_<move>_colon   one colon to a sentence
--   nf_meet_notref    a clause not ending on the person, kept from tails
--                     that describe them (", someone I'd never dealt with")
--   nf_meet_bare      a clause ending ": {ref.noun}", kept from tails without a
--                     comma (" at my campfire")
--   nf_glad           a fond coda, one to a sentence
--   nf_once           "after one meeting"
--   nf_now            a present state ("is in the diary now"), kept from
--                     stems that want a past action ("Later, ")
--   nf_notdiary       an added clause not ending on "the diary", kept from
--                     ", where he belongs"
--   nf_added_noti     an added clause whose subject isn't I, kept from tails
--                     about my choosing (", which I don't do lightly")
--   nf_calm           "without hesitation" and the like
--   nf_decide         "decided"

local addonName, ns = ...

local Pages = ns.Pages
local Words = Pages.Words

local KINDS = { "stems", "clauses", "fragments", "tails", "wholes" }

-- Fond words stay away from anyone tagged foe or avoid. The guards keep the
-- words true; they are no reason to prefer a piece, so their weight in its
-- specificity is taken back off.
local FOND = { "!who.tags.foe", "!who.tags.avoid" }
local FOND_BONUS = -0.25 * #FOND

local PLACES = { "{in:zone}", "{in.cap:zone}", "{at:subZone}", "{at.cap:subZone}", "{v:subZone}", "{v:zone}" }

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

-- Tags each piece of a move by what its text does, and applies the
-- shorthands `fond` (needs FOND) and `glad` (fond, says nf_glad, and as a
-- clause or fragment takes no tail).
local function Spec(spec, move)
    for _, kind in ipairs(KINDS) do
        for i, raw in ipairs(spec[kind] or {}) do
            local p = type(raw) == "string" and { raw } or raw
            local text = p[1]
            local bare = text:gsub("{[^}]*}", "")
            p.says = Copy(p.says)
            p.needs = Copy(p.needs)
            if p.glad then
                p.fond = true
                Add(p.says, "nf_glad")
                if kind == "clauses" or kind == "fragments" then p.final = true end
            end
            if p.fond then
                for _, c in ipairs(FOND) do Add(p.needs, c) end
                p.bonus = (p.bonus or 0) + FOND_BONUS
            end
            if text:find("{today", 1, true) then Add(p.says, "nf_today") end
            if text:find("{today", 1, true) or text:find("{part", 1, true) or text:find("{share", 1, true) then
                Add(p.says, "nf_" .. move .. "_part")
            end
            for _, place in ipairs(PLACES) do
                if text:find(place, 1, true) then Add(p.says, "nf_" .. move .. "_place") break end
            end
            if kind ~= "wholes" and bare:find(":", 1, true) then
                Add(p.says, "nf_" .. move .. "_colon")
            end
            local person = kind == "clauses" or kind == "fragments"
            if move == "meet" then
                if person and not text:find("{ref[%.%w]*}$") then Add(p.says, "nf_meet_notref") end
                if person and text:find(": {ref[%.%w]*}$") then Add(p.says, "nf_meet_bare") end
                if kind == "tails" and text:sub(1, 1) == " " then Add(p.says, "nf_meet_bare") end
                -- A fragment has no verb to hang ", and it turns out..." on.
                if kind == "fragments" then Add(p.says, "nf_meet_frag") end
                if kind == "tails" and (text:find("^, and ") or text:find("^, though ") or text:find("^, which ")) then
                    Add(p.says, "nf_meet_frag")
                end
            else
                if person and not text:find("diary$") then Add(p.says, "nf_notdiary") end
                local mine = (kind == "clauses" and text:find("^I ")) or (kind == "fragments" and (text:find("^Added ") or text:find("^Wrote ")))
                if person and not mine then Add(p.says, "nf_added_noti") end
            end
            spec[kind][i] = p
        end
    end
    return spec
end

Pages.Angle("new_face", { order = { "meet", "added" },
    about = "someone new, by the way we met, and whether they went into the diary" })

--------------------------------------------------------------------------
-- meet: the general words, whichever way we met
--------------------------------------------------------------------------

Words("new_face", "meet", Spec({
    must = { "how" },

    stems = {
        "{today.cap}, ",
        { "{in.cap:zone}, ", needs = { "!viaChat" }, bonus = -0.25 },
        { "{at.cap:subZone}, ", needs = { "!viaChat" }, bonus = -0.25 },
        "While I was {in:zone}, ",
        "While I was {at:subZone}, ",
        "Quite by chance, ",
        "Before the {part} was out, ",
        { "Someone new {today}: ", says = { "nf_new" } },
        { "A new face {today}: ", needs = { "!viaChat" }, says = { "nf_new" } },
        { "A new face {at:subZone}: ", needs = { "!viaChat" }, says = { "nf_new" } },
        { "{today.cap} brought someone new: ", says = { "nf_new" } },
        { "Not every {part} brings someone new, but ", says = { "nf_new" }, voice = "warm" },
        { "As luck would have it, ", voice = "warm" },
        { "To my good fortune, ", voice = "warm" },
        { "For once, ", needs = { "!viaRescue" }, voice = "wry" },
        { "I wasn't looking for company, but ", voice = "wry" },
        { "New {today}: ", says = { "nf_new" }, voice = "terse" },
        { "{at.cap:subZone}: ", needs = { "!viaChat" }, voice = "terse" },
    },

    clauses = {
        { "I met {ref.obj}", needs = { "!viaChat" }, says = { "nf_new" } },
        { "I made the acquaintance of {ref.obj}", says = { "nf_new" } },
        { "I had my first dealings with {ref.obj}", says = { "nf_new" } },
        { "{ref} and I met", needs = { "!viaChat" }, says = { "nf_new" } },
        { "{ref} and I got acquainted", says = { "nf_new" } },
        { "I made a new acquaintance in {ref.obj}", says = { "nf_new" } },
        { "{ref} and I first crossed paths", needs = { "!viaChat" }, says = { "nf_new" } },
        { "I struck up an acquaintance with {ref.obj}", says = { "nf_new" } },
        { "I got to know {ref.obj} a little", needs = { "!viaRescue", "!viaDuel", "!viaTrade" }, says = { "nf_new" }, final = true },
        { "I met someone new: {ref.noun}", needs = { "!viaChat" }, says = { "nf_new" }, final = true },
        { "{ref} came into my {part}", says = { "nf_new" }, voice = "warm" },
        { "I made a friend, or the start of one, in {ref.obj}", fond = true, says = { "nf_new" }, voice = "warm" },
        { "I was lucky enough to meet {ref.obj}", needs = { "!viaChat" }, says = { "nf_new" }, voice = "warm" },
        { "I somehow ended up with a new acquaintance in {ref.obj}", says = { "nf_new" }, voice = "wry" },
        { "I met {ref.obj}", needs = { "!viaChat" }, says = { "nf_new" }, voice = "terse" },
        { "I found a new acquaintance in {ref.obj}", says = { "nf_new" }, voice = "warm" },
        { "{ref} entered the story", says = { "nf_new" }, voice = "wry" },
        { "the cast of my {part} grew by one: {ref.noun}", says = { "nf_new" }, final = true, voice = "wry" },
    },

    fragments = {
        { "First dealings with {ref.obj}", says = { "nf_new" } },
        { "A new face: {ref.noun}", needs = { "!viaChat" }, says = { "nf_new" } },
        { "Someone new: {ref.noun}", says = { "nf_new" } },
        { "A first meeting with {ref.obj}", needs = { "!viaChat" }, says = { "nf_new" } },
        { "My introduction to {ref.obj}", says = { "nf_new" } },
        { "Made the acquaintance of {ref.obj}", says = { "nf_new" } },
        { "A new face in my {part}: {ref.noun}", needs = { "!viaChat" }, says = { "nf_new" }, voice = "warm" },
        { "A welcome new face: {ref.noun}", needs = { "!viaChat" }, says = { "nf_new" }, fond = true, voice = "warm" },
        { "Fresh company: {ref.noun}", needs = { "!viaChat" }, says = { "nf_new" }, voice = "wry" },
        { "New acquaintance: {ref.noun}", says = { "nf_new" }, voice = "terse" },
        { "Met {ref.obj}", needs = { "!viaChat" }, says = { "nf_new" }, voice = "terse" },
    },

    tails = {
        { " {in:zone}", needs = { "!viaChat" }, bonus = -0.5 },
        { " {at:subZone}", needs = { "!viaChat" }, bonus = -0.5 },
        { ", the first time we'd met", needs = { "!viaChat" }, says = { "nf_new" } },
        { ", someone I'd never dealt with before", says = { "nf_new", "nf_meet_notref" } },
        { ", the first time we'd had anything to do with each other", says = { "nf_new" } },
        { ", though it turned out we share a guild", needs = { "guildmate" } },
        { ", and it turns out we're in the same guild", needs = { "guildmate" } },
        { ", and {he} was level {lvl:theirLevel}", needs = { "!viaChat" }, bonus = -0.25 },
        { ", level {lvl:theirLevel} at the time", says = { "nf_meet_notref" }, bonus = -0.25 },
        { ", and I was glad of it", glad = true, voice = "warm" },
        { ", which made my {part}", glad = true, voice = "warm" },
        { ", someone I hope to see again", glad = true, says = { "nf_meet_notref" }, voice = "warm" },
        { ", which I hadn't planned on", voice = "wry" },
        { ", first meeting", needs = { "!viaChat" }, says = { "nf_new" }, voice = "terse" },
    },
}, "meet"))

-- The words for one way of meeting: each piece needs the flag and says how.
local function Via(flag, spec)
    for _, kind in ipairs(KINDS) do
        for i, raw in ipairs(spec[kind] or {}) do
            local p = type(raw) == "string" and { raw } or raw
            p.needs = Copy(p.needs)
            p.says = Copy(p.says)
            table.insert(p.needs, 1, flag)
            Add(p.says, "how")
            if flag == "viaRescue" and kind ~= "wholes" then Add(p.says, "nf_glad") end
            -- A stem of its own pairs only with the few general clauses,
            -- so it is drawn a little more readily to be seen at all.
            if kind == "stems" then p.bonus = (p.bonus or 0) + 0.5 end
            spec[kind][i] = p
        end
    end
    Words("new_face", "meet", Spec(spec, "meet"))
end

--------------------------------------------------------------------------
-- grouped for quests
--------------------------------------------------------------------------

Via("viaGroup", {
    stems = {
        "In a group {in:zone}, ",
        "In a group {at:subZone}, ",
        "Over {count:quests:quest} together, ",
        "Questing in a group {in:zone}, ",
        { "Over {dur:seconds} in the same group, ", needs = { "seconds>=1200" } },
        { "Sharing quests {in:zone}, ", voice = "warm" },
        { "Somewhere between quest turn-ins, ", needs = { "quests>=3" }, voice = "wry" },
        { "Grouped up {in:zone}: ", voice = "terse" },
    },

    clauses = {
        "I <groupedWith> {ref.obj}",
        "I <groupedWith> {ref.obj} {in:zone}",
        "{ref} and I grouped up {in:zone}",
        "{ref} and I grouped up {at:subZone}",
        "{ref} and I ended up in a group together",
        "{ref} and I ended up in the same group {in:zone}",
        "I <groupedWith> {ref.obj} for {counta:quests:quest}",
        "{ref} and I did {count:quests:quest} together",
        "{ref} and I worked through {count:quests:quest} together {in:zone}",
        "I spent {dur:seconds} in a group with {ref.obj}",
        "{ref} and I spent {share:seconds} grouped up",
        { "I <groupedWith> {ref.noun.short}, level {lvl:theirLevel},", bonus = -0.25 },
        { "I <groupedWith> {ref.noun.short}, {desc.a},", needs = { "who.diary" }, bonus = -0.75 },
        { "I <groupedWith> {ref.obj} for the first time", says = { "nf_new" } },
        { "{ref} and I grouped up for the first time {in:zone}", says = { "nf_new" } },
        { "{ref} turned out to be a guildmate when we grouped up", needs = { "guildmate" } },
        { "I <groupedWith> {ref.obj} and enjoyed the company", glad = true },
        { "{ref} and I made a good team for {count:quests:quest}", needs = { "quests>=2" }, glad = true, voice = "warm" },
        { "{ref} and I spent {share:seconds} in a group, and it went quickly", needs = { "seconds>=1800" }, glad = true, voice = "warm" },
        { "{ref} and I took on whatever {v:zone} could throw at us", voice = "wry" },
        { "I gave up soloing long enough to group with {ref.obj}", voice = "wry" },
        { "{ref} and I teamed up, two strangers with the same quests", needs = { "quests>=1" }, says = { "nf_new" }, voice = "wry", final = true },
        { "I <groupedWith> {ref.obj} {today}", voice = "terse" },
    },

    fragments = {
        "Grouped with {ref.obj}",
        "Grouped with {ref.obj} {in:zone}",
        "{count.cap:quests:quest} with {ref.obj}",
        "{dur.cap:seconds} in a group with {ref.obj}",
        "Questing with {ref.obj} {in:zone}",
        "Teamed up with {ref.obj}",
        { "A group with someone new: {ref.noun}", says = { "nf_new" } },
        { "Good company for {count:quests:quest}: {ref.noun}", glad = true, voice = "warm" },
        { "{count.cap:quests:quest}, one new face: {ref.noun}", needs = { "quests>=2" }, says = { "nf_new" }, voice = "wry" },
        { "Grouped: {ref.noun}", voice = "terse" },
        { "{ref.noun.short}: grouped, {dur:seconds}", voice = "terse" },
    },

    tails = {
        ", in a group {in:zone}",
        ", when we grouped up {in:zone}",
        ", when we ended up in the same group",
        ", over {count:quests:quest} together",
        ", in a group that lasted {dur:seconds}",
        ", in a group {at:subZone}",
        { ", over {count:quests:quest} that went by quickly", needs = { "quests>=2" }, glad = true, voice = "warm" },
        { ", which turned a dull run of quests into a decent {part}", needs = { "quests>=2" }, voice = "wry" },
        { ", grouped", voice = "terse" },
    },

    wholes = {
        { "I <groupedWith> {ref.obj} {today}, someone I'd never met before.", says = { "nf_new" } },
        { "{ref} and I grouped up {in:zone} {today}. We'd never met before.", says = { "nf_new" } },
        { "{ref} and I did {count:quests:quest} together {in:zone}, the first time we'd ever grouped.", says = { "nf_new" } },
        { "A new face in my group {today}: {ref.noun}.", says = { "nf_new" } },
        { "I spent {dur:seconds} in a group with {ref.obj} {today}, a complete stranger when we started.", says = { "nf_new" } },
        { "{count.cap:quests:quest} {in:zone}, all of them with {ref.obj}, who I'd never met before.", needs = { "quests>=2" }, says = { "nf_new" } },
        "{ref} and I ended up in a group {at:subZone} and stayed in it for {dur:seconds}.",
        { "Grouped with someone new {in:zone}: {ref.noun}, level {lvl:theirLevel}.", says = { "nf_new" } },
        { "My first group with {ref.obj} came {today}, {in:zone}.", says = { "nf_new" } },
        "{ref} was level {lvl:theirLevel} when we grouped up {in:zone}.",
        { "{ref} turned out to be a guildmate, though we'd never grouped until {today}.", needs = { "guildmate" }, says = { "nf_new" } },
        { "Some groups last a quest. The one with {ref.obj} lasted {dur:seconds}.", needs = { "seconds>=1800" }, voice = "warm" },
        { "{ref} and I grouped up {in:zone} {today}, and the quests went better for the company.", glad = true, voice = "warm" },
        { "I <groupedWith> {ref.obj} {today} and liked the company. {count.cap:quests:quest} went by quickly.", needs = { "quests>=2" }, glad = true, voice = "warm" },
        { "{ref} and I spent {share:seconds} grouped up {in:zone}, and I'd happily do it again.", glad = true, voice = "warm" },
        { "{ref} and I grouped up {today}. {count.cap:quests:quest} later, I'd have called us acquainted.", needs = { "quests>=2" }, voice = "wry" },
        { "Strangers when we grouped up, {ref} and I had {count:quests:quest} behind us by the end.", says = { "nf_new" }, voice = "wry" },
        { "Nothing breaks the ice like {count:quests:quest}. {ref} and I did ours {in:zone}.", needs = { "quests>=2" }, voice = "wry" },
        { "Grouped with {ref.obj}. {count.cap:quests:quest}.", voice = "terse" },
        { "New: {ref.noun}. Grouped {in:zone}.", says = { "nf_new" }, voice = "terse" },
        { "Grouped with {ref.obj} {at:subZone}. {dur.cap:seconds}.", voice = "terse" },
    },
})

--------------------------------------------------------------------------
-- a trade
--------------------------------------------------------------------------

Via("viaTrade", {
    stems = {
        "Over a trade {at:subZone}, ",
        "Over a trade {in:zone}, ",
        "Thanks to a trade, ",
        { "Through a trade, of all things, ", voice = "wry" },
        { "By way of the trade window, ", voice = "wry" },
        { "Trade {at:subZone}: ", voice = "terse" },
    },

    clauses = {
        "{ref} and I traded {at:subZone}",
        "I traded with {ref.obj}",
        "I traded with {ref.obj} {in:zone}",
        "{ref} and I did a trade {in:zone}",
        "a trade put me in touch with {ref.obj}",
        "a trade passed between {ref.obj} and me {at:subZone}",
        { "I traded with {ref.noun.short}, level {lvl:theirLevel},", bonus = -0.25 },
        { "I traded with {ref.noun.short}, {desc.a},", needs = { "who.diary" }, bonus = -0.75 },
        { "I traded with {ref.obj} for the first time", says = { "nf_new" } },
        { "I traded with {ref.obj}, a guildmate I'd never dealt with", needs = { "guildmate" }, says = { "nf_new" }, final = true },
        { "a trade with {ref.obj} turned into a pleasant first meeting", glad = true, says = { "nf_new" }, voice = "warm" },
        { "a simple trade left me with a new acquaintance in {ref.obj}", says = { "nf_new" }, voice = "warm" },
        { "I did a little business with {ref.obj}", voice = "wry" },
        { "I met {ref.obj} across a trade window", says = { "nf_new" }, voice = "wry" },
        { "{ref} and I were strangers right up until the trade window", says = { "nf_new" }, voice = "wry" },
        { "I traded with {ref.obj} {today}", voice = "terse" },
    },

    fragments = {
        "Traded with {ref.obj}",
        "A trade with {ref.obj} {at:subZone}",
        "A trade with {ref.obj} {in:zone}",
        { "First trade with {ref.obj}", says = { "nf_new" } },
        { "A trade, and a new face: {ref.noun}", says = { "nf_new" } },
        { "A good trade and a new acquaintance: {ref.noun}", glad = true, says = { "nf_new" }, voice = "warm" },
        { "A little light trading with {ref.obj}", voice = "wry" },
        { "Trade: {ref.noun}", voice = "terse" },
        { "{v:subZone}: traded with {ref.obj}", voice = "terse" },
    },

    tails = {
        " over a trade",
        ", through a trade {at:subZone}",
        ", by way of a trade",
        " over a trade {in:zone}",
        ", thanks to a trade",
        { ", over a trade I'm glad I made", glad = true, voice = "warm" },
        { ", across a trade window", voice = "wry" },
        { ", trade window and all", voice = "wry" },
        { ", by trade", voice = "terse" },
    },

    wholes = {
        { "{ref} and I traded {at:subZone} {today}. I'd never met {him} before.", says = { "nf_new" } },
        { "A trade {today} introduced me to {ref.obj}.", says = { "nf_new" } },
        { "I traded with {ref.obj} {in:zone}, the first time we'd ever dealt with each other.", says = { "nf_new" } },
        { "My first dealings with {ref.obj} were a trade, {at:subZone}.", says = { "nf_new" } },
        { "It started with a trade {at:subZone}. Until then, {ref} and I were strangers.", says = { "nf_new" } },
        "{ref.short}, level {lvl:theirLevel}, and I traded {at:subZone}.",
        { "I traded with someone new {today}: {ref.noun}.", says = { "nf_new" } },
        { "{ref} and I traded {in:zone} {today}, and it turns out we share a guild.", needs = { "guildmate" } },
        { "A trade with {ref.obj} {today}, and a new face worth remembering.", glad = true, says = { "nf_new" }, voice = "warm" },
        { "Some acquaintances start with a trade. {ref} was one of them, {at:subZone}.", says = { "nf_new" }, voice = "warm" },
        { "A trade {at:subZone} {today}, and a pleasant one. {ref} and I had never met before.", glad = true, says = { "nf_new" }, voice = "warm" },
        { "Nothing makes an introduction like a trade window. {ref} and I met over one {today}.", says = { "nf_new" }, voice = "wry" },
        { "{ref} and I were strangers right up until the trade window opened.", says = { "nf_new" }, voice = "wry" },
        { "I went {in:zone} for quests and came away with a trade and a new acquaintance: {ref.noun}.", says = { "nf_new" }, voice = "wry" },
        { "Trade with {ref.obj}. New face.", says = { "nf_new" }, voice = "terse" },
        { "Traded with {ref.obj} {at:subZone}. First time.", says = { "nf_new" }, voice = "terse" },
    },
})

--------------------------------------------------------------------------
-- a duel (never who asked, never who won)
--------------------------------------------------------------------------

Via("viaDuel", {
    stems = {
        "Over a duel {at:subZone}, ",
        "After a duel {in:zone}, ",
        "By way of a duel, ",
        { "With a duel flag between us, ", voice = "wry" },
        { "After a duel I enjoyed, ", glad = true, voice = "warm" },
        { "With a duel for an introduction, ", voice = "wry" },
        { "Duel {at:subZone}: ", voice = "terse" },
    },

    clauses = {
        "{ref} and I duelled {at:subZone}",
        "{ref} and I duelled {in:zone}",
        "I duelled {ref.obj}",
        "I fought a duel with {ref.obj}",
        "{ref} and I squared off in a duel",
        "{ref} and I had a duel {at:subZone}",
        { "a duel with {ref.obj} was how we met", says = { "nf_new" } },
        { "I duelled {ref.noun.short}, level {lvl:theirLevel},", bonus = -0.25 },
        { "I duelled {ref.noun.short}, {desc.a},", needs = { "who.diary" }, bonus = -0.75 },
        { "{ref} and I duelled for the first time", says = { "nf_new" } },
        { "I duelled {ref.obj}, a guildmate I'd never met", needs = { "guildmate" }, says = { "nf_new" }, final = true },
        { "{ref} and I duelled, and I came away glad to have met {him}", glad = true, says = { "nf_new" }, voice = "warm" },
        { "a friendly duel introduced me to {ref.obj}", says = { "nf_new" }, voice = "warm" },
        { "I met {ref.obj} across a duel flag", says = { "nf_new" }, voice = "wry" },
        { "{ref} and I skipped the small talk and duelled", voice = "wry" },
        { "I duelled {ref.obj} {at:subZone}", voice = "terse" },
    },

    fragments = {
        "A duel with {ref.obj}",
        "Duelled {ref.obj} {at:subZone}",
        "Duelled {ref.obj} {in:zone}",
        "Squared off with {ref.obj}",
        { "A duel, and a new face: {ref.noun}", says = { "nf_new" } },
        { "A good duel with someone new: {ref.noun}", glad = true, says = { "nf_new" }, voice = "warm" },
        { "Introductions by duel: {ref.noun}", says = { "nf_new" }, voice = "wry" },
        { "Duel: {ref.noun}", voice = "terse" },
    },

    tails = {
        " over a duel",
        ", by way of a duel",
        " in a duel {at:subZone}",
        ", over a duel {in:zone}",
        { ", over a duel I enjoyed", glad = true, voice = "warm" },
        { ", across a duel flag", voice = "wry" },
        { ", over a duel, which is one way to break the ice", voice = "wry" },
        { ", by duel", voice = "terse" },
    },

    wholes = {
        { "{ref} and I duelled {at:subZone} {today}. It was the first time we'd met.", says = { "nf_new" } },
        { "My first meeting with {ref.obj} was a duel, {in:zone}.", says = { "nf_new" } },
        { "{ref} and I squared off in a duel {today}, strangers until the flag went up.", says = { "nf_new" } },
        { "A duel {at:subZone} {today}, and with it a new face: {ref.noun}.", says = { "nf_new" } },
        { "I'd never met {ref.obj} before we duelled {in:zone} {today}.", says = { "nf_new" } },
        "{ref} was level {lvl:theirLevel} when we duelled {at:subZone}.",
        { "{ref} and I duelled {today}, and it turns out we're in the same guild.", needs = { "guildmate" } },
        { "A duel is a strange way to meet someone, but I'm glad I met {ref.obj}.", glad = true, says = { "nf_new" }, voice = "warm" },
        { "{ref} and I duelled {in:zone} {today}. Whatever the result, I liked meeting {him}.", glad = true, says = { "nf_new" }, voice = "warm" },
        { "I met {ref.obj} the direct way {today}: a duel {at:subZone}.", says = { "nf_new" }, voice = "wry" },
        { "As introductions go, a duel is a blunt one. {ref} and I had ours {in:zone}.", says = { "nf_new" }, voice = "wry" },
        { "Some people say hello. {ref} and I duelled.", says = { "nf_new" }, voice = "wry" },
        { "Duel with {ref.obj}. First meeting.", says = { "nf_new" }, voice = "terse" },
        { "Duelled {ref.obj} {at:subZone}. New face.", says = { "nf_new" }, voice = "terse" },
    },
})

--------------------------------------------------------------------------
-- they sat at my campfire
--------------------------------------------------------------------------

Via("viaCampfire", {
    stems = {
        "At my campfire {at:subZone}, ",
        "By my fire {in:zone}, ",
        "Over a campfire, ",
        { "Around my fire {today}, ", voice = "warm" },
        { "Campfire lit, ", voice = "wry" },
        { "At the fire: ", voice = "terse" },
    },

    clauses = {
        "{ref} sat down at my campfire",
        "{ref} sat down at my campfire {at:subZone}",
        "{ref} joined me at my campfire",
        "{ref} took a seat by my fire {in:zone}",
        "{ref} shared my campfire {in:zone}",
        "{ref} sat down by my fire",
        { "I had company at my campfire: {ref.noun}", final = true },
        { "{ref.noun.short}, level {lvl:theirLevel}, sat down at my fire", bonus = -0.25 },
        { "{ref.noun.short}, {desc.a}, sat down at my campfire", needs = { "who.diary" }, bonus = -0.75 },
        { "{ref} sat down at my fire, a stranger until then", says = { "nf_new" } },
        { "a guildmate I'd never met sat down at my campfire: {ref.noun}", needs = { "guildmate" }, says = { "nf_new" }, final = true },
        { "{ref} sat down at my campfire, and I liked having the company", glad = true, voice = "warm" },
        { "my campfire {at:subZone} gained a guest in {ref.obj}", voice = "warm" },
        { "I lit a fire and got {ref.obj} for company", voice = "wry" },
        { "my campfire proved more sociable than I am: {ref.noun} sat down at it", final = true, voice = "wry" },
        { "{ref} sat at my fire", voice = "terse" },
    },

    fragments = {
        "Company at my campfire: {ref.noun}",
        "A new face at my fire: {ref.noun}",
        "{ref.noun.short}, by my campfire {at:subZone}",
        "Shared my fire with {ref.obj}",
        { "A stranger at my campfire: {ref.noun}", says = { "nf_new" } },
        { "Good company by the fire: {ref.noun}", glad = true, voice = "warm" },
        { "One campfire, one guest: {ref.noun}", voice = "wry" },
        { "Campfire guest: {ref.noun}", voice = "terse" },
    },

    tails = {
        " at my campfire",
        ", when {he} sat down at my fire",
        " by my campfire {at:subZone}",
        ", at my fire {in:zone}",
        { ", over a campfire, which is the best way", glad = true, voice = "warm" },
        { ", sharing a campfire like old hands", voice = "wry" },
        { ", sharing the warmth of my fire", voice = "warm" },
        { ", at my fire", voice = "terse" },
    },

    wholes = {
        { "{ref} sat down at my campfire {today}. I'd never met {him} before.", says = { "nf_new" } },
        { "I had a visitor at my campfire {at:subZone}: {ref.noun}, a stranger until then.", says = { "nf_new" } },
        { "Someone new sat down at my fire {in:zone} {today}: {ref.noun}.", says = { "nf_new" } },
        { "My campfire {at:subZone} had a new guest {today}: {ref.noun}.", says = { "nf_new" } },
        "{ref.short}, level {lvl:theirLevel}, sat down at my campfire {in:zone}.",
        "I lit a fire {in:zone} and {ref} sat down at it.",
        { "{ref} sat down at my campfire {today}, and it turns out we share a guild.", needs = { "guildmate" } },
        { "{ref} sat down at my campfire {at:subZone}, which is as good a way to meet as any.", says = { "nf_new" }, voice = "warm" },
        { "A campfire is an open invitation, and {ref} took it {today}.", voice = "warm" },
        { "{ref} sat down at my fire {today}, and the {part} was better for it.", glad = true, voice = "warm" },
        { "Light a fire and people turn up. {today.cap} it was {ref}.", voice = "wry" },
        { "I made a campfire {at:subZone} and it made me an acquaintance: {ref.noun}.", says = { "nf_new" }, voice = "wry" },
        { "Campfire guest: {ref.noun}. New.", says = { "nf_new" }, voice = "terse" },
        { "{ref.noun.short} at my fire, {v:subZone}. First meeting.", says = { "nf_new" }, voice = "terse" },
    },
})

--------------------------------------------------------------------------
-- chat: heard from, never met or seen
--------------------------------------------------------------------------

Via("viaChat", {
    stems = {
        "By whisper, ",
        "Over chat {today}, ",
        "Through a few whispers, ",
        { "By whisper, of all things, ", voice = "wry" },
        { "Through whispers alone, ", voice = "terse" },
    },

    clauses = {
        "{ref} and I got talking by whisper",
        "{ref} and I struck up a conversation in whispers",
        "I first heard from {ref.obj} by whisper",
        "{ref} and I exchanged whispers {today}",
        "{ref} and I fell into conversation over whispers",
        "{ref} and I got chatting",
        "my first words with {ref.obj} were in whispers",
        { "{ref.noun.short}, level {lvl:theirLevel}, and I got talking by whisper", bonus = -0.25 },
        { "{ref.noun.short}, {desc.a}, and I got talking by whisper", needs = { "who.diary" }, bonus = -0.75 },
        { "{ref} and I talked by whisper for the first time", says = { "nf_new" } },
        { "{ref}, a guildmate as it turned out, and I got talking by whisper", needs = { "guildmate" } },
        { "{ref} and I got talking by whisper, and I enjoyed it", glad = true, voice = "warm" },
        { "a whispered conversation left me with a new acquaintance in {ref.obj}", says = { "nf_new" }, voice = "warm" },
        { "{ref} and I became acquainted the modern way, by whisper", says = { "nf_new" }, final = true, voice = "wry" },
        { "{ref} and I talked by whisper", voice = "terse" },
    },

    fragments = {
        "Whispers with {ref.obj}",
        "First whispers with {ref.obj}",
        "Talking with {ref.obj} by whisper",
        { "A new name by whisper: {ref.noun}", needs = { "who.diary" }, says = { "nf_new" } },
        { "A new contact by whisper: {ref.noun}", says = { "nf_new" } },
        { "A good conversation by whisper with {ref.obj}", glad = true, voice = "warm" },
        { "An acquaintance by correspondence: {ref.noun}", says = { "nf_new" }, voice = "wry" },
        { "Whispers: {ref.noun}", voice = "terse" },
    },

    tails = {
        ", by whisper",
        " in whispers",
        ", over whispers",
        " over chat",
        ", by way of a whisper",
        { ", by whisper, which I enjoyed more than I expected", glad = true, voice = "warm" },
        { ", by whisper, as is the fashion", voice = "wry" },
        { ", whispers only", voice = "terse" },
    },

    wholes = {
        { "My first dealings with {ref.obj} {today} were in whispers.", says = { "nf_new" } },
        { "A whispered conversation {today} introduced me to {ref.obj}.", says = { "nf_new" } },
        { "I first heard from {ref.obj} {today}, by whisper.", says = { "nf_new" } },
        { "{ref} and I exchanged whispers {today}, the first words between us.", says = { "nf_new" } },
        { "Not every acquaintance starts face to face. {ref} and I got talking by whisper.", says = { "nf_new" } },
        "{ref} and I got talking by whisper {today}. {he} turned out to be level {lvl:theirLevel}.",
        { "{ref} and I got talking by whisper {today}, and it turns out we share a guild.", needs = { "guildmate" } },
        { "Whispers with {ref.obj} {today}, and I'm glad of them.", glad = true, voice = "warm" },
        { "{ref} and I got talking by whisper {today}. Good conversation is worth writing down.", glad = true, voice = "warm" },
        { "{ref} and I got talking by whisper {today}, and I hope we keep it up.", glad = true, voice = "warm" },
        { "{ref} and I became acquainted by whisper {today}. Faces can come later.", says = { "nf_new" }, voice = "wry" },
        { "I know {ref.obj} by whisper so far, and that's all.", says = { "nf_new" }, voice = "wry" },
        { "Whispers with {ref.obj}. A new contact.", says = { "nf_new" }, voice = "terse" },
        { "New contact, by whisper: {ref.noun}.", says = { "nf_new" }, voice = "terse" },
    },
})

--------------------------------------------------------------------------
-- they saved me in a fight
--------------------------------------------------------------------------

Via("viaRescue", {
    stems = {
        "In the middle of a fight that was going badly, ",
        "In a tight spot {in:zone}, ",
        "When a fight went wrong {at:subZone}, ",
        { "In my hour of need, ", voice = "wry" },
        { "Losing a fight {at:subZone}, ", voice = "terse" },
    },

    clauses = {
        "{ref} saved my life {in:zone}",
        "{ref} pulled me out of a fight I was losing",
        "{ref} stepped into a fight I was losing {at:subZone}",
        "{ref} came to my rescue",
        "{ref} rescued me {in:zone}",
        "I was saved by {ref.obj}",
        "{ref} got me out of trouble {at:subZone}",
        { "{ref.noun.short}, level {lvl:theirLevel}, pulled me out of a fight", bonus = -0.25 },
        { "{ref.noun.short}, {desc.a}, saved my life", needs = { "who.diary" }, bonus = -0.75 },
        { "a guildmate I'd never met saved my life: {ref.noun}", needs = { "guildmate" }, says = { "nf_new" }, final = true },
        { "{ref}, a complete stranger, saved my life", says = { "nf_new" } },
        { "I ended up owing my life to {ref.obj}", voice = "warm" },
        { "{ref} stepped into my fight when I needed it most", says = { "nf_meet_bare" }, voice = "warm" },
        { "{ref} bailed me out of a bad fight", voice = "wry" },
        { "{ref} spared me a walk back from the graveyard", says = { "nf_meet_bare" }, voice = "wry" },
        { "{ref} saved me", voice = "terse" },
    },

    fragments = {
        "Saved by {ref.obj}",
        "Rescued by {ref.obj} {in:zone}",
        "Pulled out of a bad fight by {ref.obj}",
        { "Saved by a stranger: {ref.noun}", says = { "nf_new" } },
        { "A rescue, courtesy of {ref.obj}", voice = "wry" },
        { "Saved: by {ref.obj}", voice = "terse" },
    },

    tails = {
        ", when {he} pulled me out of a fight I was losing",
        ", when {he} saved my life",
        ", when {he} stepped into my fight",
        ", in the middle of a fight I was losing",
        { ", when {he} saved my life, which I won't forget", voice = "warm" },
        { ", when {he} saved my skin", voice = "wry" },
        { ", in a fight that was going badly until then", voice = "wry" },
        { ", in a losing fight", voice = "terse" },
    },

    wholes = {
        { "{ref} saved my life {today}, and I'd never even met {him}.", says = { "nf_new" } },
        { "A fight {in:zone} was going badly until {ref} stepped in. I'd never met {him} before.", says = { "nf_new" } },
        { "{ref} was a stranger right up until {he} saved my life {at:subZone}.", says = { "nf_new" } },
        { "Some people you meet over a trade. {ref} I met when {he} pulled me out of a fight.", says = { "nf_new" } },
        "{ref.short}, level {lvl:theirLevel}, saved my life {in:zone}.",
        "{ref} saved my skin {at:subZone}. <relief>",
        { "{ref} saved my life {today}, and it turns out we share a guild.", needs = { "guildmate" } },
        { "{ref} stepped in when I needed it most {today}. I'll remember that.", voice = "warm" },
        { "I'm grateful to {ref.obj}. {he} stepped into my fight {in:zone} and turned it around.", voice = "warm" },
        { "I owe {ref.obj} one. {he} pulled me out of a fight {in:zone}, a complete stranger.", says = { "nf_new" }, voice = "warm" },
        { "Not how I'd have chosen to meet {ref.obj}, but {he} saved my life {in:zone}.", says = { "nf_new" }, voice = "wry" },
        { "I met {ref.obj} {today} at my lowest ebb, mid-fight and losing.", says = { "nf_new" }, voice = "wry" },
        { "Saved by {ref.obj}. Never met before.", says = { "nf_new" }, voice = "terse" },
        { "Bad fight. {ref} stepped in.", voice = "terse" },
    },
})

--------------------------------------------------------------------------
-- words in /say
--------------------------------------------------------------------------

Via("viaSay", {
    stems = {
        "Over a few words in /say, ",
        "Thanks to /say, ",
        "In /say {at:subZone}, ",
        { "Out loud, in /say, ", voice = "wry" },
        { "In /say: ", voice = "terse" },
    },

    clauses = {
        "{ref} and I exchanged a few words in /say",
        "{ref} and I got talking in /say {at:subZone}",
        "I fell into conversation with {ref.obj} in /say",
        "{ref} and I struck up a conversation in /say",
        "{ref} and I talked in /say {in:zone}",
        "a few words in /say introduced me to {ref.obj}",
        { "{ref.noun.short}, level {lvl:theirLevel}, and I got talking in /say", bonus = -0.25 },
        { "{ref.noun.short}, {desc.a}, and I got talking in /say", needs = { "who.diary" }, bonus = -0.75 },
        { "{ref} and I spoke in /say for the first time", says = { "nf_new" } },
        { "{ref}, a guildmate I'd never met, and I got talking in /say", needs = { "guildmate" }, says = { "nf_new" } },
        { "{ref} and I got talking in /say, and I'm glad we did", glad = true, voice = "warm" },
        { "{ref} and I had a pleasant chat in /say", glad = true, voice = "warm" },
        { "a few friendly words in /say left me with a new acquaintance in {ref.obj}", says = { "nf_new" }, voice = "warm" },
        { "I actually spoke to someone in /say {today}: {ref.noun}", final = true, voice = "wry" },
        { "{ref} and I talked out loud, in /say, like proper adventurers", final = true, voice = "wry" },
        { "{ref} and I talked in /say", voice = "terse" },
    },

    fragments = {
        "Words in /say with {ref.obj}",
        "Talking with {ref.obj} in /say {at:subZone}",
        "A few words with {ref.obj} in /say",
        { "A new voice in /say: {ref.noun}", says = { "nf_new" } },
        { "Good talk in /say with {ref.obj}", glad = true, voice = "warm" },
        { "Actual conversation, in /say, with {ref.obj}", voice = "wry" },
        { "/say: {ref.noun}", voice = "terse" },
    },

    tails = {
        " in /say",
        ", over a few words in /say",
        " in /say {at:subZone}",
        ", talking in /say {in:zone}",
        { ", over a few friendly words in /say", voice = "warm" },
        { ", out loud in /say", voice = "wry" },
        { ", in /say", voice = "terse" },
    },

    wholes = {
        { "{ref} and I exchanged a few words in /say {at:subZone} {today}, our first.", says = { "nf_new" } },
        { "A few words in /say {today}, and I'd met {ref.obj}.", says = { "nf_new" } },
        { "{ref} and I got talking in /say {in:zone}. We'd never met before.", says = { "nf_new" } },
        "{ref} was level {lvl:theirLevel} when we got talking in /say.",
        { "I fell into conversation with someone new in /say {today}: {ref.noun}.", says = { "nf_new" } },
        { "{ref} and I got talking in /say {today}, and it turns out we share a guild.", needs = { "guildmate" } },
        { "A few words in /say {at:subZone}, and a new face I'd like to see again: {ref.noun}.", glad = true, says = { "nf_new" }, voice = "warm" },
        { "{ref} and I got talking in /say {today}. Easy company.", glad = true, voice = "warm" },
        { "I met {ref.obj} {today} the old-fashioned way: talking in /say {at:subZone}.", says = { "nf_new" }, voice = "wry" },
        { "For once /say held more than the usual chatter: {ref.noun} and I got talking {at:subZone}.", voice = "wry" },
        { "Talked with {ref.obj} in /say. New face.", says = { "nf_new" }, voice = "terse" },
        { "/say, {v:subZone}: {ref.noun}. First words.", says = { "nf_new" }, voice = "terse" },
    },
})

--------------------------------------------------------------------------
-- added: I wrote them into the diary today
--------------------------------------------------------------------------

local function Added(list)
    for i, raw in ipairs(list) do
        local p = type(raw) == "string" and { raw } or raw
        p.says = Copy(p.says)
        Add(p.says, "added")
        list[i] = p
    end
    return list
end

-- Stems that want a past action after them ("Later, I wrote him in"), so
-- never a present state ("Later, he is in the diary now").
local PAST = { "nf_now" }

Words("new_face", "added", Spec({
    must = { "added" },
    needs = { "addedToday" },

    stems = {
        { "Later, ", says = PAST },
        { "Before the {part} was out, ", says = PAST },
        { "{today.cap}, ", says = PAST },
        { "On the strength of one meeting, ", needs = { "how~=chat" }, says = { "nf_once" } },
        { "On the strength of one conversation, ", needs = { "how==chat" }, says = { "nf_once" } },
        { "It didn't take long to decide: ", says = { "nf_decide" } },
        { "By the end of the {part}, ", says = PAST },
        { "First meeting or not, ", needs = { "how~=chat" }, fond = true, says = { "nf_once" }, voice = "warm" },
        { "One meeting was enough: ", needs = { "how~=chat" }, fond = true, says = { "nf_once" }, voice = "warm" },
        { "A few whispers were enough: ", needs = { "how==chat" }, fond = true, says = { "nf_once" }, voice = "warm" },
        { "I don't do this for everyone, but ", fond = true, says = { "nf_now", "nf_added_noti" }, voice = "warm" },
        { "Without much hesitation, ", says = { "nf_now", "nf_calm", "nf_added_noti" }, voice = "warm" },
        { "For better or worse, ", voice = "wry" },
        { "Call it a hunch, but ", voice = "wry" },
        { "On a whim, ", says = { "nf_now", "nf_added_noti" }, voice = "wry" },
        { "For the record, ", voice = "terse" },
        { "Noted: ", voice = "terse" },
    },

    clauses = Added({
        "I wrote {ref.obj} into the diary",
        "I added {ref.obj} to the diary",
        "{ref} went into the diary",
        { "{ref} has a page in the diary now", says = { "nf_now" } },
        "I gave {ref.obj} a page in the diary",
        "I started a page for {ref.obj}",
        { "{ref} is in the diary now", says = { "nf_now" } },
        "{ref} made it into the diary",
        "I put {ref.obj} in the diary",
        { "I decided {ref} belonged in the diary", says = { "nf_decide", "nf_belong", "nf_added_noti" } },
        { "the diary gained a new name: {ref.noun.short}", final = true },
        "I set aside a page for {ref.obj}",
        "{ref} got a page of {his} own",
        "I made {ref.obj} a diary entry",
        { "{ref} earned a page in the diary", fond = true, voice = "warm" },
        { "I made room in the diary for {ref.obj}", fond = true, voice = "warm" },
        { "{ref} joins the people in this diary", fond = true, says = { "nf_now" }, voice = "warm" },
        { "I found I wanted {ref.obj} in the diary", fond = true, voice = "warm" },
        { "{ref} now has the dubious honour of a page in my diary", says = { "nf_now" }, voice = "wry" },
        { "I opened a file on {ref.obj}, so to speak", voice = "wry" },
        { "the diary grew by one name: {ref.noun.short}", final = true, voice = "wry" },
        { "{ref} is now a matter of record", says = { "nf_now" }, voice = "wry" },
        { "{ref} went in the book", voice = "terse" },
        { "I logged {ref.obj} in the diary", voice = "terse" },
    }),

    fragments = Added({
        "Into the diary with {ref.obj}",
        "Added {ref.obj} to the diary",
        "Wrote {ref.obj} into the diary",
        "{ref.noun.short}, added to the diary",
        { "New in the diary: {ref.noun.short}", final = true },
        { "A new page: {ref.noun.short}", final = true },
        "A page in the diary for {ref.obj}",
        { "A page of the diary for {ref.noun.short}, all {his} own", fond = true, voice = "warm" },
        { "Into the diary, where {ref} belongs", fond = true, says = { "nf_belong" }, voice = "warm" },
        { "Another name for the diary, and a good one: {ref.noun.short}", fond = true, final = true, voice = "warm" },
        { "Promoted to the diary: {ref.noun.short}", final = true, voice = "wry" },
        { "The diary's newest resident: {ref.noun.short}", final = true, voice = "wry" },
        { "Added to the diary", voice = "terse" },
        { "Into the diary", voice = "terse" },
        { "{ref.noun.short}: added", voice = "terse" },
    }),

    tails = {
        ', tagged "{v:tag}"',
        ', filed under "{v:tag}"',
        ' with the tag "{v:tag}"',
        { ", after just the one meeting", needs = { "how~=chat" }, says = { "nf_once" } },
        { ", on the strength of a single meeting", needs = { "how~=chat" }, says = { "nf_once" } },
        { ", the same day we met", needs = { "how~=chat" }, says = { "nf_once" } },
        { ", on the strength of a few whispers", needs = { "how==chat" }, says = { "nf_once" } },
        { ", before we'd so much as stood in the same zone", needs = { "how==chat" }, says = { "nf_once" } },
        ", so I'll know {him} next time",
        { ", in case our paths cross again", needs = { "how~=chat" } },
        { ", in case our paths ever cross", needs = { "how==chat" } },
        { ', tagged "{v:tag}", which seems right', needs = { "tag==friend" }, voice = "warm" },
        { ", which I don't do lightly", fond = true, says = { "nf_added_noti" }, voice = "warm" },
        { ", where {he} belongs", fond = true, says = { "nf_notdiary", "nf_belong" }, voice = "warm" },
        { ", without a second thought", fond = true, says = { "nf_calm", "nf_added_noti" }, voice = "warm" },
        { ", which is the least I owe {him}", needs = { "how==rescue" }, voice = "warm" },
        { ", before I could talk myself out of it", says = { "nf_calm", "nf_added_noti" }, voice = "wry" },
        { ", for whatever that's worth", voice = "wry" },
        { ", all on the strength of a duel", needs = { "how==duel" }, says = { "nf_once" }, voice = "wry" },
        { ", all because of a campfire", needs = { "how==campfire" }, says = { "nf_once" }, voice = "wry" },
        { ', tagged "{v:tag}" so future me knows to steer clear', needs = { "tag==avoid" }, voice = "wry" },
        { ", just in case", voice = "terse" },
        { ', tag "{v:tag}"', voice = "terse" },
    },

    wholes = Added({
        "{ref} is in the diary now.",
        "I wrote {ref.obj} into the diary before the {part} was over.",
        "Into the diary {ref} went.",
        { "One meeting, and {ref} already has a page in the diary.", needs = { "how~=chat" }, says = { "nf_once" } },
        { "A handful of whispers, and {ref} already has a page in the diary.", needs = { "how==chat" }, says = { "nf_once" } },
        "New in the diary {today}: {ref.noun.short}.",
        "The diary has a new name in it: {ref.noun.short}.",
        'I added {ref.obj} to the diary and tagged {him} "{v:tag}".',
        'Tagged "{v:tag}", {ref} went into the diary.',
        "I gave {ref.obj} a page in the diary. We'll see what ends up on it.",
        { "{ref} went into the diary the same day we met.", needs = { "how~=chat" }, says = { "nf_once" } },
        { "We've never stood in the same place, but {ref} has a page in the diary now.", needs = { "how==chat" }, says = { "nf_once" } },
        "There's a page in the diary for {ref.obj} now.",
        "By the end of the {part}, {ref} had a page in the diary.",
        'The diary has {ref.obj} down as "{v:tag}" now.',
        "I started a page for {ref.obj}. Whether it fills up is another matter.",
        { "I wrote {ref.obj} into the diary, which says enough about how the {part} went.", fond = true },
        { "I don't add people lightly, but {ref} has a page now.", fond = true, voice = "warm" },
        { "{ref} has a page in the diary now. I have a feeling it won't stay empty.", fond = true, voice = "warm" },
        { "I wrote {ref.obj} into the diary. I'd like to see more of {him}.", fond = true, voice = "warm" },
        { "I wrote {ref.obj} into the diary as a friend. One meeting, but it felt right.", needs = { "tag==friend", "how~=chat" }, says = { "nf_once" }, voice = "warm" },
        { "{ref} saved my life, and a page in the diary seemed the least I could do in return.", needs = { "how==rescue" }, voice = "warm" },
        { "A campfire, a stranger, and now a page in the diary for {ref.noun.short}.", needs = { "how==campfire" }, fond = true, voice = "warm" },
        { "{ref} went into the diary on the strength of one meeting. Impulsive of me.", needs = { "how~=chat" }, says = { "nf_once" }, voice = "wry" },
        { "{ref} went into the diary before I'd even seen {him}. Impulsive of me.", needs = { "how==chat" }, says = { "nf_once" }, voice = "wry" },
        { "{ref} now has a page in the diary, for better or worse.", voice = "wry" },
        { "I've given {ref.obj} a page in the diary. No pressure.", voice = "wry" },
        { "I added {ref.obj} to the diary. Future me can thank present me.", voice = "wry" },
        { 'I added {ref.obj} to the diary, but only to tag {him} "{v:tag}".', needs = { "tag==avoid" }, voice = "wry" },
        { "One duel and {ref} is in the diary. I've known people for weeks who aren't.", needs = { "how==duel" }, says = { "nf_once" }, voice = "wry" },
        { '{ref} went into the diary tagged "{v:tag}". Better to know.', needs = { "tag==foe" }, voice = "terse" },
        { "Added {ref.obj} to the diary.", voice = "terse" },
        { "Added to the diary. Tag: {v:tag}.", voice = "terse" },
        { "Diary: {ref.noun.short}, added.", voice = "terse" },
    }),
}, "added"))
