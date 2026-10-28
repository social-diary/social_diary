-- Chat: words exchanged with someone, by whisper or out loud, and a line
-- worth keeping.
--
-- heard facts (the planner's)
--   who            the person
--   whispersIn     whispers from them today (0 counts as none)
--   whispersOut    whispers from me to them today
--   noMeeting      only whispers today: we never crossed paths
--   firstWhisper   today's were the first whispers ever between us
--
-- quote facts
--   quote          a short line (90 characters at most), as typed
--   fromMe         I wrote it; otherwise they did
--   channel        "whisper", "say", "party" or "yell"
--
-- The rules this file keeps: a whisper is "heard from", never "saw"; who
-- said a line follows fromMe; a quote goes in only through {v:quote},
-- inside quotation marks, and always at the very end of its sentence (the
-- quote's own ? or ! then ends the sentence, and nothing has to follow a
-- closing mark); the quote is never commented on, only framed; and the
-- order of whispers is unknown, so no "replied" or "whispered back".
--
-- Slots declared here
--   {chat_total}   whispers both ways, with the noun: "five whispers"
--                  (needs both directions)
--   {chat_q}       nothing, but only when the quote ends in "?": a guard
--                  for "asked"
--
-- Tags said beyond slots
--   heard           (heard's point) that we exchanged whispers
--   ch_mine         a heard clause with me as the subject, kept from stems
--                   that want someone else's whisper ("Out of the blue, ")
--   ch_chan         the channel named, once a sentence
--   ch_who          the speaker named, once a sentence
--   ch_nomsg        a quote clause that doesn't end on the message itself,
--                   kept from ", which read ..."
--   ch_<move>_colon one colon to a sentence
--   ch_keep         "for the record", "worth keeping" and the like, once
--   ch_glad         a glad word about hearing from them, once
--   ch_sentme       "{ref} sent me", once on the page for this person
--   ch_wrote        "wrote", once a sentence
--   ch_nosay        a fragment that can't take ", saying"
--   ch_first        firstWhisper, said once (a bare flag would also be
--                   said, but the tag keeps "the first" wordings apart)

local addonName, ns = ...

local Pages = ns.Pages
local Words = Pages.Words
local Get = Pages.Get

local KINDS = { "stems", "clauses", "fragments", "tails", "wholes" }

--------------------------------------------------------------------------
-- Slots
--------------------------------------------------------------------------

Pages.Slot("chat_total", {
    needs = function() return { "whispersIn", "whispersOut" } end,
    says = function() return { "whispersIn", "whispersOut" } end,
    fn = function(env)
        local a, b = Get(env.f, "whispersIn"), Get(env.f, "whispersOut")
        if type(a) ~= "number" or type(b) ~= "number" then return nil end
        return Pages.Lang.Count(a + b, "whisper")
    end,
})

Pages.Slot("chat_q", {
    needs = function() return { "quote" } end,
    says = function() return {} end,
    fn = function(env)
        local q = Get(env.f, "quote")
        if type(q) ~= "string" then return nil end
        if q:gsub("%s+$", ""):sub(-1) == "?" then return "" end
        return nil
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

local function Spec(spec, move)
    for _, kind in ipairs(KINDS) do
        for i, raw in ipairs(spec[kind] or {}) do
            local p = type(raw) == "string" and { raw } or raw
            local text = p[1]
            local bare = text:gsub("{[^}]*}", "")
            p.needs = Copy(p.needs)
            p.says = Copy(p.says)
            -- {part} is the time of day as much as {today} is.
            if text:find("{part", 1, true) then Add(p.says, "page.part") end
            if kind ~= "wholes" and bare:find(":", 1, true) then Add(p.says, "ch_" .. move .. "_colon") end
            -- A piece holding the quote ends with it, and nothing follows.
            if text:find("{v:quote}", 1, true) and (kind == "clauses" or kind == "fragments") then p.final = true end
            spec[kind][i] = p
        end
    end
    return spec
end

local function Point(list, tag)
    for i, raw in ipairs(list) do
        local p = type(raw) == "string" and { raw } or raw
        p.says = Copy(p.says)
        Add(p.says, tag)
        list[i] = p
    end
    return list
end

Pages.Angle("chat", { order = { "heard", "quote" },
    about = "words exchanged: whispers, and a line worth keeping" })

--------------------------------------------------------------------------
-- heard: whispers today
--------------------------------------------------------------------------

-- Who whispered: IN only theirs, OUT only mine, BOTH both ways.
-- Comparisons rather than bare flags: a bare flag would count as said, and
-- then a stem needing it could never meet a clause needing it.
local IN = { "whispersIn>=1", "!whispersOut" }
local OUT = { "whispersOut>=1", "!whispersIn" }
local BOTH = { "whispersIn>=1", "whispersOut>=1" }

local function N(base, extra)
    local out = {}
    for _, c in ipairs(base) do out[#out + 1] = c end
    for _, c in ipairs(extra or {}) do out[#out + 1] = c end
    return out
end

Words("chat", "heard", Spec({
    must = { "heard" },

    stems = {
        "{today.cap}, ",
        { "Though our paths never crossed {today}, ", needs = { "noMeeting" } },
        { "Without our paths crossing once, ", needs = { "noMeeting" } },
        { "For the first time, ", needs = { "firstWhisper" }, says = { "ch_first" } },
        { "Out of the blue, ", needs = IN, says = { "ch_mine" } },
        { "Somewhere in the {part}, ", bonus = -0.5 },
        { "Without so much as crossing paths, ", needs = { "noMeeting" }, voice = "wry" },
        { "Not once in the same place all {part}, but ", needs = { "noMeeting" }, voice = "wry" },
        { "To my pleasant surprise, ", needs = { "whispersIn>=1" }, says = { "ch_mine", "ch_glad" }, voice = "warm" },
        { "Happily, ", needs = { "whispersIn>=1" }, says = { "ch_glad" }, voice = "warm" },
        { "Not in person, but ", needs = { "noMeeting" }, voice = "terse" },
    },

    clauses = Point({
        -- both ways
        { "{ref} and I traded whispers", needs = BOTH },
        { "{ref} and I exchanged {chat_total}", needs = BOTH },
        { "{ref} and I whispered back and forth", needs = N(BOTH, { "whispersIn>=2", "whispersOut>=2" }) },
        { "{ref} and I kept up a whispered conversation", needs = N(BOTH, { "whispersIn>=2", "whispersOut>=2" }) },
        { "I traded {chat_total} with {ref.obj}", needs = BOTH, says = { "ch_mine" } },
        { "{ref} and I talked by whisper", needs = BOTH },
        { "{ref} and I had a quick whispered exchange", needs = N(BOTH, { "whispersIn<=2", "whispersOut<=2" }) },
        { "{ref} and I had a long exchange of whispers", needs = N(BOTH, { "whispersIn>=5", "whispersOut>=5" }) },
        { "{ref} and I stayed in touch by whisper", needs = N(BOTH, { "noMeeting" }) },
        { "{ref} and I kept each other company by whisper", needs = BOTH, voice = "warm" },
        { "{ref} and I caught up by whisper", needs = BOTH, voice = "warm" },
        { "{ref} and I conducted our business entirely in whispers", needs = N(BOTH, { "noMeeting" }), voice = "wry" },
        { "{ref} and I whispered", needs = BOTH, voice = "terse" },
        -- theirs only
        { "I heard from {ref.obj} by whisper", needs = IN },
        { "{ref} sent me {counta:whispersIn:whisper}", needs = IN, says = { "ch_sentme" } },
        { "{ref} whispered to me {times:whispersIn}", needs = IN },
        { "I had {counta:whispersIn:whisper} from {ref.obj}", needs = IN, says = { "ch_mine" } },
        { "{counta:whispersIn:whisper} came in from {ref.obj}", needs = IN },
        { "word came from {ref.obj}, by whisper", needs = IN },
        { "{ref} got in touch by whisper", needs = IN },
        { "{ref} sent me {counta:whispersIn:whisper}, and I never whispered back", needs = IN, says = { "ch_mine", "ch_sentme" }, final = true },
        { "it was good to hear from {ref.obj}", needs = IN, says = { "ch_glad" }, voice = "warm" },
        { "a whisper from {ref.obj} made my {part}", needs = IN, says = { "ch_glad" }, voice = "warm" },
        { "{ref} broke the silence with {counta:whispersIn:whisper}", needs = IN, voice = "wry" },
        { "{ref} whispered", needs = IN, voice = "terse" },
        -- mine only
        { "I whispered to {ref.obj}", needs = OUT, says = { "ch_mine" } },
        { "I sent {ref.obj} {counta:whispersOut:whisper}", needs = OUT, says = { "ch_mine" } },
        { "I whispered to {ref.obj} {times:whispersOut}", needs = OUT, says = { "ch_mine" } },
        { "I got in touch with {ref.obj} by whisper", needs = OUT, says = { "ch_mine" } },
        { "I whispered to {ref.obj} {times:whispersOut} and heard nothing back", needs = OUT, says = { "ch_mine" }, final = true },
        { "I sent {ref.obj} {counta:whispersOut:whisper} into the void", needs = OUT, says = { "ch_mine" }, voice = "wry", final = true },
        { "I whispered to {ref.obj} {times:whispersOut}, for all the answer I got", needs = OUT, says = { "ch_mine" }, voice = "wry", final = true },
        { "I dropped {ref.obj} {counta:whispersOut:whisper}", needs = OUT, says = { "ch_mine" }, voice = "warm" },
        { "I whispered to {ref.obj}", needs = OUT, says = { "ch_mine" }, voice = "terse" },
    }, "heard"),

    fragments = Point({
        { "Whispers with {ref.obj}", needs = BOTH },
        { "{chat_total.cap} with {ref.obj}", needs = BOTH },
        { "A whispered exchange with {ref.obj}", needs = BOTH },
        { "Back and forth by whisper with {ref.obj}", needs = N(BOTH, { "whispersIn>=2", "whispersOut>=2" }) },
        { "Heard from {ref.obj} by whisper", needs = IN },
        { "{counta.cap:whispersIn:whisper} from {ref.obj}", needs = IN },
        { "Word from {ref.obj}", needs = IN },
        { "Whispered to {ref.obj}", needs = OUT },
        { "{counta.cap:whispersOut:whisper} to {ref.obj}", needs = OUT },
        { "Whispered to {ref.obj} {times:whispersOut}, no answer", needs = OUT, final = true },
        { "A friendly word from {ref.obj}, by whisper", needs = IN, says = { "ch_glad" }, voice = "warm" },
        { "Good to hear from {ref.obj}", needs = IN, says = { "ch_glad" }, voice = "warm" },
        { "A long-distance chat with {ref.obj}", needs = N(BOTH, { "noMeeting" }), voice = "warm" },
        { "Correspondence with {ref.obj}, by whisper", needs = BOTH, voice = "wry" },
        { "One-way correspondence with {ref.obj}", needs = OUT, voice = "wry" },
        { "Whispers, {ref.short}: {num:whispersIn} in, {num:whispersOut} out", needs = BOTH, voice = "terse" },
        { "{ref.short}: {counta:whispersIn:whisper}", needs = IN, voice = "terse" },
        { "{ref.short}, by whisper", voice = "terse" },
    }, "heard"),

    tails = {
        { ", though we never crossed paths", needs = { "noMeeting" } },
        { ", though our paths never crossed {today}", needs = { "noMeeting" } },
        { ", all of it at a distance", needs = { "noMeeting" } },
        { ", without our paths crossing once", needs = { "noMeeting" } },
        { ", the first words ever between us", needs = { "firstWhisper" }, says = { "ch_first" } },
        { ", the first time we've ever been in touch", needs = { "firstWhisper" }, says = { "ch_first" } },
        { ", for the first time ever", needs = { "firstWhisper" }, says = { "ch_first" } },
        { ", {count:whispersIn:whisper} from {him} and {count:whispersOut:whisper} from me", needs = BOTH },
        { ", {num:whispersIn} from {him}, {num:whispersOut} from me", needs = BOTH },
        { ", {times:whispersIn} in all", needs = N(IN, { "whispersIn>=2" }) },
        { ", {times:whispersOut} in all", needs = N(OUT, { "whispersOut>=2" }) },
        { " {today}", bonus = -0.5 },
        { ", and it was good to hear from {him}", needs = { "whispersIn>=1" }, says = { "ch_glad" }, voice = "warm" },
        { ", which brightened my {part}", needs = { "whispersIn>=1" }, says = { "ch_glad" }, voice = "warm" },
        { ", which was nice", needs = { "whispersIn>=1" }, says = { "ch_glad" }, voice = "warm" },
        { ", the modern way to keep in touch", needs = { "noMeeting" }, voice = "wry" },
        { ", which saves on walking", needs = { "noMeeting" }, voice = "wry" },
        { ", no meeting", needs = { "noMeeting" }, voice = "terse" },
        { ", first ever", needs = { "firstWhisper" }, says = { "ch_first" }, voice = "terse" },
    },

    wholes = Point({
        { "{ref} and I traded whispers {today}: {count:whispersIn:whisper} from {him}, {count:whispersOut:whisper} from me.", needs = BOTH },
        { "{ref} and I exchanged {chat_total} {today}, though our paths never crossed.", needs = N(BOTH, { "noMeeting" }) },
        { "We never crossed paths {today}, but {ref} and I kept up a conversation by whisper.", needs = N(BOTH, { "noMeeting" }) },
        { "{ref} and I talked by whisper {today}. The first whispers we've ever exchanged.", needs = N(BOTH, { "firstWhisper" }), says = { "ch_first" } },
        { "{chat_total.cap} passed between {ref.obj} and me {today}.", needs = BOTH },
        { "I heard from {ref.obj} by whisper {today}, {times:whispersIn}.", needs = IN },
        { "{ref} whispered to me {today}, though our paths never crossed all {part}.", needs = N(IN, { "noMeeting" }) },
        { "{ref} sent me {counta:whispersIn:whisper} {today}, the first {he} has ever sent me.", needs = N(IN, { "firstWhisper", "whispersIn==1" }), says = { "ch_first", "ch_sentme" } },
        { "{ref} sent me {count:whispersIn:whisper} {today}, the first {he} has ever sent me.", needs = N(IN, { "firstWhisper", "whispersIn>=2" }), says = { "ch_first", "ch_sentme" } },
        { "A whisper from {ref.obj} {today}, out of nowhere.", needs = N(IN, { "whispersIn==1" }) },
        { "I whispered to {ref.obj} {today}, {times:whispersOut}.", needs = OUT },
        { "I sent {ref.obj} {counta:whispersOut:whisper} {today}. Nothing came back.", needs = OUT },
        { "I whispered to {ref.obj} for the first time {today}.", needs = N(OUT, { "firstWhisper" }), says = { "ch_first" } },
        { "Our paths didn't cross {today}, but {ref} and I still found each other by whisper.", needs = N(BOTH, { "noMeeting" }), voice = "warm" },
        { "{ref} whispered to me {today}, and it was good to hear from {him}.", needs = IN, says = { "ch_glad" }, voice = "warm" },
        { "A few whispers from {ref.obj} {today}. It's nice to hear from people.", needs = N(IN, { "whispersIn>=2" }), voice = "warm" },
        { "{ref} and I caught up by whisper {today}, and the {part} was better for it.", needs = BOTH, voice = "warm" },
        { "{ref} and I whispered {today} without ever crossing paths. Very modern of us.", needs = N(BOTH, { "noMeeting" }), voice = "wry" },
        { "I whispered to {ref.obj} {times:whispersOut} {today}. So far it's been a rather one-sided conversation.", needs = N(OUT, { "whispersOut>=2" }), voice = "wry" },
        { "{ref} and I exchanged {chat_total} {today}. Practically pen pals.", needs = N(BOTH, { "noMeeting" }), voice = "wry" },
        { "{ref} whispered to me {today}. I'm told that's how friendships start.", needs = N(IN, { "firstWhisper" }), says = { "ch_first" }, voice = "wry" },
        { "Whispers with {ref.short.obj}: {num:whispersIn} in, {num:whispersOut} out.", needs = BOTH, voice = "terse" },
        { "{ref.short} whispered. {times.cap:whispersIn}.", needs = IN, voice = "terse" },
        { "Whispered {ref.short}. No reply.", needs = OUT, voice = "terse" },
    }, "heard"),
}, "heard"))

--------------------------------------------------------------------------
-- quote: a line, theirs or mine
--------------------------------------------------------------------------

-- Who said it and where. Every piece of the move needs one of these.
local THEIRS = { "!fromMe" }
local MINE = { "fromMe==true" }

local function Ch(ch, who)
    local out = { "channel==" .. ch }
    for _, c in ipairs(who or {}) do out[#out + 1] = c end
    return out
end

-- Every quote sentence names its channel (says ch_chan): a piece that
-- needs "channel==..." names it; a clause that doesn't takes a stem that
-- does; and a fragment or whole that doesn't is only for whispers, where
-- the heard sentence has named the channel already. So a line in party
-- chat never reads as a whispered reply.
local function Channels(spec)
    for _, kind in ipairs(KINDS) do
        for _, p in ipairs(spec[kind] or {}) do
            p.needs = Copy(p.needs)
            local named = false
            for _, c in ipairs(p.needs) do
                if c:find("^channel==") then named = true end
            end
            p.says = Copy(p.says)
            if named then
                Add(p.says, "ch_chan")
            elseif kind == "fragments" or kind == "wholes" then
                table.insert(p.needs, 1, "channel==whisper")
                Add(p.says, "ch_chan")
            end
        end
    end
    return spec
end

Words("chat", "quote", Channels(Spec({
    must = { "quote", "ch_chan" },

    stems = {
        { "{today.cap}, ", bonus = -0.25 },
        "At one point, ",
        { "For the record, ", says = { "ch_keep" } },
        { "In /say, ", needs = { "channel==say" }, says = { "ch_chan" } },
        { "By whisper, ", needs = { "channel==whisper" }, says = { "ch_chan" } },
        { "In a whisper, ", needs = { "channel==whisper" }, says = { "ch_chan" } },
        { "Over whispers {today}, ", needs = { "channel==whisper" }, says = { "ch_chan" } },
        { "Out loud in /say, ", needs = { "channel==say" }, says = { "ch_chan" } },
        { "At the top of {his} voice, ", needs = { "channel==yell", "!fromMe" }, says = { "ch_chan" }, voice = "wry" },
        { "In a yell that carried, ", needs = { "channel==yell" }, says = { "ch_chan" } },
        { "In the group's chat, ", needs = { "channel==party" }, says = { "ch_chan" }, voice = "terse" },
        { "In party chat, ", needs = { "channel==party" }, says = { "ch_chan" } },
        { "Over party chat, ", needs = { "channel==party" }, says = { "ch_chan" } },
        { "In a yell, ", needs = { "channel==yell" }, says = { "ch_chan" } },
        { "At some point in the {part}, ", bonus = -0.5 },
        { "I wrote this down: ", says = { "ch_keep", "ch_wrote" } },
        { "I want to remember this: ", says = { "ch_keep" }, voice = "warm" },
        { "Worth keeping, from the {part}: ", says = { "ch_keep" }, voice = "warm" },
        { "For posterity, ", needs = MINE, says = { "ch_keep" }, voice = "wry" },
        { "Lest it be lost to history, ", needs = MINE, says = { "ch_keep" }, voice = "wry" },
        { "Noted: ", says = { "ch_keep" }, voice = "terse" },
        { "Quote: ", says = { "ch_keep" }, voice = "terse" },
    },

    clauses = {
        -- theirs, with the quote
        { '{ref} whispered "{v:quote}"', needs = Ch("whisper", THEIRS), says = { "ch_chan", "ch_who" } },
        { '{ref} whispered to me, "{v:quote}"', needs = Ch("whisper", THEIRS), says = { "ch_chan", "ch_who" } },
        { '{ref} asked{chat_q} me by whisper, "{v:quote}"', needs = Ch("whisper", THEIRS), says = { "ch_chan", "ch_who" } },
        { '{ref} said in /say, "{v:quote}"', needs = Ch("say", THEIRS), says = { "ch_chan", "ch_who" } },
        { 'I heard {ref.obj} say "{v:quote}"', needs = Ch("say", THEIRS), says = { "ch_chan", "ch_who" } },
        { '{ref} asked{chat_q} in /say, "{v:quote}"', needs = Ch("say", THEIRS), says = { "ch_chan", "ch_who" } },
        { '{ref} said in party chat, "{v:quote}"', needs = Ch("party", THEIRS), says = { "ch_chan", "ch_who" } },
        { '{ref} put it to the party: "{v:quote}"', needs = Ch("party", THEIRS), says = { "ch_chan", "ch_who" } },
        { '{ref} asked{chat_q} the group, "{v:quote}"', needs = Ch("party", THEIRS), says = { "ch_chan", "ch_who" } },
        { '{ref} yelled "{v:quote}"', needs = Ch("yell", THEIRS), says = { "ch_chan", "ch_who" } },
        { '{ref} whispered: "{v:quote}"', needs = Ch("whisper", THEIRS), says = { "ch_chan", "ch_who" }, voice = "terse" },
        { 'I was glad to hear from {ref.obj} by whisper: "{v:quote}"', needs = Ch("whisper", THEIRS), says = { "ch_chan", "ch_who" }, voice = "warm" },
        { 'I heard {ref.obj} yell "{v:quote}"', needs = Ch("yell", THEIRS), says = { "ch_chan", "ch_who" } },
        -- theirs, the channel left to a stem
        { '{ref} said "{v:quote}"', needs = THEIRS, says = { "ch_who" } },
        { '{ref} wrote "{v:quote}"', needs = { "!fromMe", "channel~=say", "channel~=yell" }, says = { "ch_who", "ch_wrote" } },
        { '{ref} asked{chat_q}, "{v:quote}"', needs = THEIRS, says = { "ch_who" } },
        { '{ref.poss} words were "{v:quote}"', needs = THEIRS, says = { "ch_who" } },
        { 'the line from {ref.obj} was "{v:quote}"', needs = THEIRS, says = { "ch_who" } },
        { 'what {ref} said was "{v:quote}"', needs = THEIRS, says = { "ch_who" } },
        -- theirs, the quote left to a tail
        { "{ref} sent me a whisper", needs = Ch("whisper", THEIRS), says = { "ch_chan", "ch_who", "ch_sentme" } },
        { "a whisper came in from {ref.obj}", needs = Ch("whisper", THEIRS), says = { "ch_chan", "ch_who", "ch_nomsg" } },
        { "{ref} spoke up in /say", needs = Ch("say", THEIRS), says = { "ch_chan", "ch_who", "ch_nomsg" } },
        { "{ref} said something in /say", needs = Ch("say", THEIRS), says = { "ch_chan", "ch_who", "ch_nomsg" } },
        { "{ref} spoke up in party chat", needs = Ch("party", THEIRS), says = { "ch_chan", "ch_who", "ch_nomsg" } },
        { "{ref} posted a line to the party", needs = Ch("party", THEIRS), says = { "ch_chan", "ch_who" } },
        { "{ref} let out a yell", needs = Ch("yell", THEIRS), says = { "ch_chan", "ch_who" } },
        { "{ref} yelled across the area", needs = Ch("yell", THEIRS), says = { "ch_chan", "ch_who", "ch_nomsg" } },
        { '{ref} had a line I liked: "{v:quote}"', needs = THEIRS, says = { "ch_who", "ch_keep" }, voice = "warm" },
        { '{ref} said something I want to keep: "{v:quote}"', needs = THEIRS, says = { "ch_who", "ch_keep" }, voice = "warm" },
        { '{ref} contributed a line to the diary: "{v:quote}"', needs = THEIRS, says = { "ch_who", "ch_keep" }, voice = "wry" },
        -- mine, with the quote
        { 'I whispered to {ref.obj}, "{v:quote}"', needs = Ch("whisper", MINE), says = { "ch_chan", "ch_who" } },
        { 'I asked{chat_q} {ref.obj} by whisper, "{v:quote}"', needs = Ch("whisper", MINE), says = { "ch_chan", "ch_who" } },
        { 'I said to {ref.obj} in /say, "{v:quote}"', needs = Ch("say", MINE), says = { "ch_chan", "ch_who" } },
        { 'I told {ref.obj}, out loud in /say, "{v:quote}"', needs = Ch("say", MINE), says = { "ch_chan", "ch_who" } },
        { 'I said in party chat, "{v:quote}"', needs = Ch("party", MINE), says = { "ch_chan" } },
        { 'I told the party, {ref.obj} included, "{v:quote}"', needs = Ch("party", MINE), says = { "ch_chan", "ch_who" } },
        { 'I asked{chat_q} the group, {ref.obj} among them, "{v:quote}"', needs = Ch("party", MINE), says = { "ch_chan", "ch_who" } },
        { 'I yelled to {ref.obj}, "{v:quote}"', needs = Ch("yell", MINE), says = { "ch_chan", "ch_who" } },
        { 'I sent {ref.obj} a friendly whisper: "{v:quote}"', needs = Ch("whisper", MINE), says = { "ch_chan", "ch_who" }, voice = "warm" },
        { 'I committed this to party chat, {ref.obj} included: "{v:quote}"', needs = Ch("party", MINE), says = { "ch_chan", "ch_who" }, voice = "wry" },
        -- mine, the channel left to a stem
        { 'I said to {ref.obj}, "{v:quote}"', needs = MINE, says = { "ch_who" } },
        { 'I asked{chat_q} {ref.obj}, "{v:quote}"', needs = MINE, says = { "ch_who" } },
        { 'my words to {ref.obj} were "{v:quote}"', needs = MINE, says = { "ch_who" } },
        { 'what I told {ref.obj} was "{v:quote}"', needs = MINE, says = { "ch_who" } },
        -- mine, the quote left to a tail
        { "I sent {ref.obj} a whisper", needs = Ch("whisper", MINE), says = { "ch_chan", "ch_who" } },
        { "I spoke up in /say, to {ref.obj}", needs = Ch("say", MINE), says = { "ch_chan", "ch_who", "ch_nomsg" } },
        { "I spoke up in party chat", needs = Ch("party", MINE), says = { "ch_chan", "ch_nomsg" } },
        { "I put a line to the party", needs = Ch("party", MINE), says = { "ch_chan" } },
        { "I yelled to {ref.obj}", needs = Ch("yell", MINE), says = { "ch_chan", "ch_who", "ch_nomsg" } },
        { 'I had a line for {ref.obj}: "{v:quote}"', needs = MINE, says = { "ch_who" } },
        { 'I managed one line worth keeping, to {ref.obj}: "{v:quote}"', needs = MINE, says = { "ch_who", "ch_keep" }, voice = "wry" },
        { 'my own contribution, to {ref.obj}, was "{v:quote}"', needs = MINE, says = { "ch_who" }, voice = "wry" },
    },

    fragments = {
        { '{ref.poss} whisper: "{v:quote}"', needs = Ch("whisper", THEIRS), says = { "ch_chan", "ch_who" } },
        { 'From {ref.obj}, by whisper: "{v:quote}"', needs = Ch("whisper", THEIRS), says = { "ch_chan", "ch_who" } },
        { '{ref.short} in /say: "{v:quote}"', needs = Ch("say", THEIRS), says = { "ch_chan", "ch_who" } },
        { '{ref.short}, in party chat: "{v:quote}"', needs = Ch("party", THEIRS), says = { "ch_chan", "ch_who" } },
        { 'A yell from {ref.obj}: "{v:quote}"', needs = Ch("yell", THEIRS), says = { "ch_chan", "ch_who" } },
        { 'Words from {ref.obj}: "{v:quote}"', needs = THEIRS, says = { "ch_who" } },
        { 'My whisper to {ref.obj}: "{v:quote}"', needs = Ch("whisper", MINE), says = { "ch_chan", "ch_who" } },
        { 'Me, to {ref.obj}, in /say: "{v:quote}"', needs = Ch("say", MINE), says = { "ch_chan", "ch_who" } },
        { 'Me, in party chat: "{v:quote}"', needs = Ch("party", MINE), says = { "ch_chan" } },
        { 'My yell to {ref.obj}: "{v:quote}"', needs = Ch("yell", MINE), says = { "ch_chan", "ch_who" } },
        { 'My words to {ref.obj}: "{v:quote}"', needs = MINE, says = { "ch_who" } },
        -- the quote left to a tail
        { "A whisper from {ref.obj}", needs = Ch("whisper", THEIRS), says = { "ch_chan", "ch_who", "ch_nomsg" } },
        { "Words from {ref.obj} in /say", needs = Ch("say", THEIRS), says = { "ch_chan", "ch_who", "ch_nomsg" } },
        { "{ref.short} in party chat", needs = Ch("party", THEIRS), says = { "ch_chan", "ch_who", "ch_nomsg" } },
        { "My whisper to {ref.obj}", needs = Ch("whisper", MINE), says = { "ch_chan", "ch_who", "ch_nomsg" } },
        { "A line of mine to {ref.obj}", needs = MINE, says = { "ch_who", "ch_nomsg", "ch_nosay" } },
        { 'The line of the {part}, from {ref.obj}: "{v:quote}"', needs = THEIRS, says = { "ch_who" }, voice = "warm" },
        { 'A keeper from {ref.obj}: "{v:quote}"', needs = THEIRS, says = { "ch_who" }, voice = "warm" },
        { 'Quoted for the record, {ref.short}: "{v:quote}"', needs = THEIRS, says = { "ch_who" }, voice = "wry" },
        { 'My own words, to {ref.obj}: "{v:quote}"', needs = MINE, says = { "ch_who" }, voice = "wry" },
        { 'A whisper I was glad of, from {ref.obj}: "{v:quote}"', needs = THEIRS, says = { "ch_who" }, voice = "warm" },
        { 'For the collection, from {ref.obj}: "{v:quote}"', needs = THEIRS, says = { "ch_who" }, voice = "wry" },
        { '{ref.short}: "{v:quote}"', needs = THEIRS, says = { "ch_who" }, voice = "terse" },
        { 'Me, to {ref.short.obj}: "{v:quote}"', needs = MINE, says = { "ch_who" }, voice = "terse" },
    },

    tails = {
        ': "{v:quote}"',
        { ', saying "{v:quote}"', says = { "ch_nosay" } },
        { ', which read "{v:quote}"', needs = { "channel~=say", "channel~=yell" }, says = { "ch_nomsg" } },
        { ', word for word: "{v:quote}"' },
        { ', in these words: "{v:quote}"', bonus = -0.5 },
        { ', and it went like this: "{v:quote}"' },
        { ', exactly this: "{v:quote}"' },
        { ', which I liked: "{v:quote}"', needs = THEIRS, says = { "ch_nomsg", "ch_keep" }, voice = "warm" },
        { ', a line I mean to keep: "{v:quote}"', says = { "ch_keep" }, voice = "warm" },
        { ', and I quote: "{v:quote}"', voice = "wry" },
        { ', in so many words: "{v:quote}"', voice = "wry" },
        { ': "{v:quote}"', voice = "terse" },
        { ', verbatim: "{v:quote}"', voice = "terse" },
        { ', a line I enjoyed: "{v:quote}"', needs = THEIRS, says = { "ch_keep" }, voice = "warm" },
        { ', and I was glad of it: "{v:quote}"', needs = THEIRS, says = { "ch_nomsg" }, voice = "warm" },
        { ', no more and no less: "{v:quote}"', voice = "wry" },
        { ', as follows: "{v:quote}"', bonus = -0.25 },
    },

    wholes = {
        { 'One whisper from {ref.obj} {today} I want to keep: "{v:quote}"', needs = Ch("whisper", THEIRS) },
        { 'In /say {today}, {ref} said "{v:quote}"', needs = Ch("say", THEIRS) },
        { 'At one point {ref} said in party chat, "{v:quote}"', needs = Ch("party", THEIRS) },
        { '{ref} yelled at one point {today}: "{v:quote}"', needs = Ch("yell", THEIRS) },
        { 'What {ref} whispered was "{v:quote}"', needs = Ch("whisper", THEIRS) },
        { 'I keep coming back to one thing {ref} said in /say: "{v:quote}"', needs = Ch("say", THEIRS) },
        { 'For the record, my whisper to {ref.obj} was "{v:quote}"', needs = Ch("whisper", MINE) },
        { 'I said to {ref.obj} in /say {today}, "{v:quote}"', needs = Ch("say", MINE) },
        { 'My line in party chat {today}, with {ref.obj} in the group: "{v:quote}"', needs = Ch("party", MINE) },
        { 'At one point I yelled to {ref.obj}: "{v:quote}"', needs = Ch("yell", MINE) },
        { 'One line from {ref.obj} {today}: "{v:quote}"', needs = THEIRS },
        { 'I wrote down what {ref} said: "{v:quote}"', needs = THEIRS },
        { 'I wrote down what I said to {ref.obj}: "{v:quote}"', needs = MINE },
        { 'The words I want to keep from {today} came from {ref.obj}: "{v:quote}"', needs = THEIRS },
        { 'There was a line from {ref.obj} worth keeping: "{v:quote}"', needs = THEIRS },
        { 'One line from {ref.obj} stayed with me: "{v:quote}"', needs = THEIRS, voice = "warm" },
        { 'I liked something {ref} said {today}, so here it is: "{v:quote}"', needs = THEIRS, voice = "warm" },
        { 'I want to remember what {ref} whispered: "{v:quote}"', needs = Ch("whisper", THEIRS), voice = "warm" },
        { 'I keep thinking of something {ref} said in party chat: "{v:quote}"', needs = Ch("party", THEIRS), voice = "warm" },
        { 'Something I said to {ref.obj} {today}, which I stand by: "{v:quote}"', needs = MINE, voice = "warm" },
        { 'For the archive, from {ref.obj}: "{v:quote}"', needs = THEIRS, voice = "wry" },
        { 'My own contribution to the conversation, whispered to {ref.obj}: "{v:quote}"', needs = Ch("whisper", MINE), voice = "wry" },
        { 'I was the one who said this, to {ref.obj}, in /say: "{v:quote}"', needs = Ch("say", MINE), voice = "wry" },
        { 'My entire contribution to party chat {today}: "{v:quote}"', needs = Ch("party", MINE), voice = "wry" },
        { 'I yelled, for once, to {ref.obj}: "{v:quote}"', needs = Ch("yell", MINE), voice = "wry" },
        { 'Today\'s line, courtesy of {ref.obj}: "{v:quote}"', needs = THEIRS, voice = "wry" },
        { '{ref} said one thing in /say that I liked: "{v:quote}"', needs = Ch("say", THEIRS), voice = "warm" },
        { 'A small thing, but I want to keep it. {ref} whispered "{v:quote}"', needs = Ch("whisper", THEIRS), voice = "warm" },
        { 'I told {ref.obj} by whisper, and meant it: "{v:quote}"', needs = Ch("whisper", MINE), voice = "warm" },
        { 'One line from party chat I liked, from {ref.obj}: "{v:quote}"', needs = Ch("party", THEIRS), voice = "warm" },
        { 'Overheard in /say, courtesy of {ref.obj}: "{v:quote}"', needs = Ch("say", THEIRS), voice = "wry" },
        { 'The yell of the {part}, from {ref.obj}: "{v:quote}"', needs = Ch("yell", THEIRS), voice = "wry" },
        { 'My contribution to /say {today}, addressed to {ref.obj}: "{v:quote}"', needs = Ch("say", MINE), voice = "wry" },
        { 'Yell, {ref.short}: "{v:quote}"', needs = Ch("yell", THEIRS), voice = "terse" },
        { 'Me, party chat: "{v:quote}"', needs = Ch("party", MINE), voice = "terse" },
        { 'Me, yelling to {ref.short}: "{v:quote}"', needs = Ch("yell", MINE), voice = "terse" },
        { '{ref.short}, by whisper: "{v:quote}"', needs = Ch("whisper", THEIRS), voice = "terse" },
        { '{ref.short}, /say: "{v:quote}"', needs = Ch("say", THEIRS), voice = "terse" },
        { '{ref.short}, party: "{v:quote}"', needs = Ch("party", THEIRS), voice = "terse" },
        { 'Me to {ref.short.obj}, by whisper: "{v:quote}"', needs = Ch("whisper", MINE), voice = "terse" },
        { 'Me, /say, to {ref.short.obj}: "{v:quote}"', needs = Ch("say", MINE), voice = "terse" },
    },
}, "quote")))
