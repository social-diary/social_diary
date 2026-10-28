-- Dungeon: a dungeon run told as a diary would tell it. No `who`; the
-- people are facts of their own.
--
-- run facts
--   instance          the dungeon's name, as the game gives it; some start
--                     with "the" ("the Deadmines"), so {v:instance} goes in
--                     as it is and the sentence's capital handles the rest
--   difficulty        "normal" or "heroic"
--   groupSize         members, me included (2-5)
--   friend            a diary person in the group (the first, if several)
--   friendCount       diary people in the group, friend included
--   strangers         members who aren't in the diary
--   seconds           how long the run took
--   bossesKilled      bosses down (0 when none went down)
--   bossesTotal       bosses the dungeon has, when known
--   fullClear         every boss went down (only when bossesTotal is known)
--   firstClear        my first time finishing it (only with fullClear)
--   firstVisit        my first time inside
--
-- trouble facts
--   wipes             times the whole group died (0 counts)
--   deaths            deaths in the group, mine included (0 counts)
--   myDeaths          my deaths (0 counts)
--   noDeaths          nobody died, so no wipes either
--   deadliest         the member who died most (never me), with
--   deadliestCount    their deaths
--
-- loot facts
--   myLoot            items I got (a list of { link, count })
--   friend, friendLoot  the friend, and the items they got
--
-- roll facts
--   rollItem          the item rolled for (a one-entry list, as myLoot)
--   iWon              I won the roll
--   winner            who won it, when I didn't
--   myRoll            my roll, 1-100
--   winRoll           the winning roll when I lost; when I won, the best
--                     roll I beat. Pieces that print it when I won use
--                     {dungeon_beat}, which prints nothing (and drops the
--                     sentence) unless it is below mine, so a planner that
--                     sends winRoll == myRoll on a win is safe too.
--   close             the two rolls were within 3
--
-- Honesty, beyond WRITING.md: there are no combat logs, so nothing about
-- how a boss was fought, who pulled, who healed or whose fault a death was.
-- A wipe is the group going down, nothing more, and a partial run is how
-- far we got, not a defeat (groups end runs for all sorts of reasons). The
-- one who died most is told kindly. Loot is named, never judged: no
-- upgrades, no junk. Rolls are "rolls", not need or greed.
--
-- Slots this file adds
--   {dungeon_the:rollItem}   the item's link with "the": "the [Ironfoe]"
--                            (left bare when the name has its own "The")
--   {dungeon_beat:winRoll}   the roll I beat, in digits, only below myRoll
--   {dungeon_margin}         the gap between the rolls: "a single point",
--                            "two points"; {dungeon_margin:wide} only at 20+,
--                            {dungeon_margin:narrow} only under 20,
--                            {dungeon_margin:one} only for a single point
--   {dungeon_wide}           prints nothing; there only when the rolls were
--                            20+ apart, to guard "it wasn't close"
--
-- Tags this file adds to `says` (all prefixed, as the "page" said-set is
-- shared with the other angles that have no `who`)
--   friend@<move>, winner@<move>, deadliest@<move>   added by Add() to any
--       piece naming that person, so one sentence names them once; a piece
--       marked back = true refers back to them and adds none
--   d.today     added by Add() to pieces with {today} or {part}, so the beat
--               says "tonight" once
--   d.first     added by Add() to pieces with the word "first"
--   d.group     the group's make-up, or a stem that can't introduce it
--   d.with      a "with X" phrase, or a clause that can't take one
--   d.notme     a clause whose subject isn't I or we, or a stem that needs
--               one that is
--   d.span      "all told", "start to finish": the whole run as a span
--   d.nomine    nothing dropped for me
--   d.show      "to show for it"
--   d.rollnoun  the word "roll" as a noun
--   d.itref     a roll clause that calls the item "it"
--   d.margin    both rolls, or the gap between them
--   d.good      good news about deaths, kept from "but it was still good"
--   d.nonum     a trouble clause without a number, kept from "By my count"
--   d.nowinner  a losing roll piece that doesn't name the winner, kept
--               from tails that refer back to them
--   d.fair, d.glad, d.once, d.end, d.bags, d.away, d.luck   words that
--               shouldn't come twice in one sentence; Add() tags most of
--               them from the text (REPEATS)

local addonName, ns = ...

local Pages = ns.Pages
local Words = Pages.Words

Pages.Angle("dungeon", { order = { "run", "trouble", "loot", "roll" },
    about = "a dungeon run: who, how far, deaths, loot and rolls" })

--------------------------------------------------------------------------
-- Slots
--------------------------------------------------------------------------

local function Lang()
    return Pages.Lang
end

Pages.Format("dungeon_the", function(v)
    if type(v) ~= "table" then return nil end
    local entry = v[1] or v
    local link = entry.link or entry.name
    if not link then return nil end
    local name = Lang().Visible(link):gsub("^%[", "")
    if name:match("^[Tt]he ") then return link end
    return "the " .. link
end)

Pages.Format("dungeon_beat", function(v, env)
    local mine = env.f.myRoll
    if type(v) ~= "number" or type(mine) ~= "number" or v >= mine then return nil end
    return Lang().Digits(v)
end, { alsoNeeds = { "myRoll" } })

-- The gap between the two rolls, the right way round for who won.
local function Margin(f)
    local mine, win = f.myRoll, f.winRoll
    if type(mine) ~= "number" or type(win) ~= "number" then return nil end
    local d = f.iWon and (mine - win) or (win - mine)
    if d <= 0 then return nil end
    return d
end

Pages.Slot("dungeon_margin", {
    needs = function() return { "myRoll", "winRoll" } end,
    says = function() return { "d.margin" } end,
    fn = function(env, args)
        local d = Margin(env.f)
        if not d then return nil end
        if args[1] == "wide" and d < 20 then return nil end
        if args[1] == "narrow" and d >= 20 then return nil end
        if args[1] == "one" and d ~= 1 then return nil end
        if d == 1 then return "a single point" end
        return Lang().Count(d, "point")
    end,
})

Pages.Slot("dungeon_wide", {
    needs = function() return { "myRoll", "winRoll" } end,
    fn = function(env)
        local d = Margin(env.f)
        if d and d >= 20 then return "" end
        return nil
    end,
})


--------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------

local KINDS = { "stems", "clauses", "fragments", "tails", "wholes" }
local PEOPLE = { "friend", "winner", "deadliest" }

-- Words that shouldn't come twice in one sentence, and the tag a piece
-- holding one says (Lua patterns, matched in lower case).
local REPEATS = {
    { "%f[%a]c[oa]me away", "d.away" },
    { "%f[%a]bags%f[%A]", "d.bags" },
    { "glad", "d.glad" }, { "pleased", "d.glad" }, { "delighted", "d.glad" },
    { "complaining", "d.glad" }, { "%f[%a]enjoy", "d.glad" }, { "happ[yi]", "d.glad" },
    { "good fun", "d.glad" }, { "best of all", "d.glad" }, { "nice to see", "d.glad" },
    { "%f[%a]fair%f[%A]", "d.fair" },
    { "%f[%a]luck", "d.luck" },
    { "together", "d.together" },
    { "%f[%a]end%f[%A]", "d.end" }, { "%f[%a]ended%f[%A]", "d.end" },
    { "whole way", "d.span" }, { "throughout", "d.span" }, { "start to finish", "d.span" },
    { "all told", "d.span" }, { "all run", "d.span" },
    { "%f[%a]in all%f[%A]", "d.inall" },
    { "show for it", "d.show" },
    { "for my trouble", "d.trouble" },
    { "good for", "d.glad" }, { "good to have", "d.glad" },
    { "death", "d.death" }, { "tally", "d.tally" },
    { "%f[%a]good%f[%A]", "d.goodword" },
    { "keeping track", "d.counting" }, { "was counting", "d.counting" },
    { "insufferable", "d.insufferable" },
}

-- Words for a move, with the automatic tags described above.
local function Add(move, spec)
    for _, kind in ipairs(KINDS) do
        local list = spec[kind]
        for i = 1, #(list or {}) do
            local piece = list[i]
            if type(piece) == "string" then piece = { piece } end
            local text = piece[1]
            local says = {}
            for _, tag in ipairs(piece.says or {}) do says[#says + 1] = tag end
            if not piece.back then
                for _, who in ipairs(PEOPLE) do
                    if text:find(":" .. who .. "}", 1, true) then says[#says + 1] = who .. "@" .. move end
                end
            end
            if text:find("{today", 1, true) or text:find("{part", 1, true) then says[#says + 1] = "d.today" end
            -- The words themselves, slots left out ({num:myDeaths} isn't
            -- the word "death").
            local lower = text:gsub("{[^}]*}", "#"):lower()
            if lower:find("%f[%a]first%f[%A]") then says[#says + 1] = "d.first" end
            for _, r in ipairs(REPEATS) do
                if lower:find(r[1]) then says[#says + 1] = r[2] end
            end
            -- One ", and" per sentence: a stem ending in it, a clause or tail
            -- holding one.
            if kind ~= "wholes" and text:find(", and ", 1, true) or text:find(", and $") then
                says[#says + 1] = "d.and"
            end
            if #says > 0 then piece.says = says end
            piece.back = nil
            list[i] = piece
        end
    end
    return Words("dungeon", move, spec)
end

local function Join(...)
    local out = {}
    for _, list in ipairs({ ... }) do
        for _, v in ipairs(list) do out[#out + 1] = v end
    end
    return out
end

local function With(piece, field, extra)
    if type(piece) == "string" then piece = { piece } end
    piece[field] = Join(extra, piece[field] or {})
    return piece
end

-- A roll piece that says I won.
local function Won(piece)
    return With(piece, "needs", { "iWon" })
end

-- A roll piece that says I lost. One that doesn't name the winner says
-- d.nowinner, which keeps it from tails that refer back to them.
local function Lost(piece)
    piece = With(piece, "needs", { "!iWon" })
    piece = With(piece, "says", { "iWon" })
    if not piece[1]:find(":winner}", 1, true) then piece = With(piece, "says", { "d.nowinner" }) end
    return piece
end


-- Partial runs, only when the dungeon's boss count is known.
local PART = { "!fullClear", "bossesTotal>0" }
-- What a full clear says, beyond the flag.
local FULL = { "bossesKilled" }
-- The whole group named: only right when there is one diary person in it.
local ONE = { "friendCount==1" }

--------------------------------------------------------------------------
-- run: which dungeon, with whom, how far and how long
--------------------------------------------------------------------------

Add("run", {
    must = { "instance" },

    stems = {
        "{today.cap}, ",
        "With {ref.short.obj:friend} along, ",
        { "With {ref.short.obj:friend} and {counta:strangers:stranger}, ", needs = ONE, says = { "d.group" } },
        { "With a group of strangers, ", needs = { "!friend", "strangers>=2" }, says = { "strangers", "d.group", "groupSize" } },
        { "With only {num:groupSize} of us, ", needs = { "groupSize<=3" }, says = { "d.group" } },
        { "Back in {v:instance}, ", needs = { "!firstVisit" } },
        "In {v:instance} {today}, ",
        { "After {dur:seconds} in {v:instance}, ", says = { "d.group" } },
        "Off to {v:instance} {today}, and ",
        { "On my first trip into {v:instance}, ", needs = { "firstVisit" } },
        { "On heroic, ", needs = { "difficulty==heroic" }, says = { "difficulty" } },
        { "In the name of loot, ", voice = "wry", says = { "d.notme" } },
        { "Against my better judgement, ", voice = "wry", says = { "d.notme" } },
        { "It was good to have {ref.short.obj:friend} along: ", needs = { "!friend.tags.avoid" }, voice = "warm" },
        { "Glad of {ref.poss:friend} company, ", needs = { "!friend.tags.avoid" }, voice = "warm" },
        { "With familiar faces around me, ", needs = { "friendCount>=2" }, says = { "friendCount", "d.group" }, voice = "warm", bonus = 0.75 },

        { "{v:instance} again {today}, and ", needs = { "!firstVisit" }, voice = "terse" },
        { "{dur.cap:seconds} in {v:instance}: ", voice = "terse", says = { "d.group" } },
    },

    clauses = {
        -- the dungeon named
        "we [ran|did] {v:instance}",
        "I ran {v:instance} with {ref.obj:friend}",
        "{ref:friend} and I ran {v:instance}",
        { "{ref:friend} and I went into {v:instance} with {counta:strangers:stranger}", needs = ONE, says = { "d.with" } },
        { "{ref.short:friend}, {counta:strangers:stranger} and I made up the group for {v:instance}", needs = ONE, says = { "d.with", "d.group" } },
        { "I <groupedWith> {counta:strangers:stranger} for {v:instance}", needs = { "!friend" }, says = { "d.with", "d.group" } },
        { "I went into {v:instance} with [a group of strangers|a pickup group]", needs = { "!friend", "strangers>=2" }, says = { "strangers", "d.with", "d.group" } },
        { "we cleared {v:instance}", needs = { "fullClear" }, says = FULL },
        { "we killed every boss in {v:instance}", needs = { "fullClear" }, says = FULL },
        { "we got through all {num:bossesTotal} bosses in {v:instance}", needs = { "fullClear", "bossesTotal>=3" }, says = FULL },
        { "we saw {v:instance} through to the end", needs = { "fullClear" }, says = FULL },
        { "we took down {num:bossesKilled} of the {num:bossesTotal} bosses in {v:instance}", needs = { "!fullClear" } },
        { "we got {count:bossesKilled:boss} down in {v:instance}", bonus = -0.5 },
        { "we made it {count:bossesKilled:boss} into {v:instance}", needs = PART },
        { "we went into {v:instance} and came out without a single boss", needs = { "bossesKilled==0" }, says = { "bossesKilled" } },
        { "we left {v:instance} with bosses still standing", needs = PART, says = { "bossesKilled" } },
        { "I finally finished {v:instance}", needs = { "firstClear", "!firstVisit" }, says = FULL },
        { "I finished {v:instance} for the first time", needs = { "firstClear" }, says = FULL },
        { "I set foot in {v:instance} for the first time", needs = { "firstVisit" } },
        { "I got my first look at {v:instance}", needs = { "firstVisit" } },
        { "I was back in {v:instance}", needs = { "!firstVisit" } },
        { "{v:instance} took us {dur:seconds}", says = { "d.with", "d.notme" } },
        { "{v:instance} took {share:seconds}", says = { "d.with", "d.notme" } },
        "we spent {dur:seconds} in {v:instance}",
        { "we were through {v:instance} in {dur:seconds}", needs = { "seconds<=3000" } },
        "{num:groupSize} of us ran {v:instance}",
        { "just {ref:friend} and I ran {v:instance}", needs = { "groupSize==2" }, says = { "d.with", "groupSize" } },
        { "only the {num:groupSize} of us went into {v:instance}", needs = { "groupSize<=4", "groupSize>=3" } },
        { "we went into {v:instance} as a pair", needs = { "groupSize==2" }, says = { "groupSize" } },
        { "we went into {v:instance} as a group of {num:groupSize}", needs = { "groupSize<=4", "groupSize>=3" } },
        { "we ran {v:instance} on heroic", needs = { "difficulty==heroic" }, says = { "difficulty" } },
        { "{v:instance} it was", voice = "terse", says = { "d.notme" }, final = true },
        { "{ref:friend} and I ran {v:instance} together, and it made for a good {part}", needs = { "!friend.tags.avoid" }, voice = "warm", final = true },
        { "I spent {share:seconds} in {v:instance} with {ref.obj:friend}, which suited me fine", needs = { "!friend.tags.avoid" }, voice = "warm", final = true },
        { "I finally saw the far end of {v:instance}", needs = { "firstClear" }, says = FULL, voice = "wry" },
        { "I could finally cross {v:instance} off my list", needs = { "firstClear", "!firstVisit" }, says = FULL, voice = "wry" },
        { "{v:instance} ate {dur:seconds} of my {part}", needs = { "seconds>=5400" }, voice = "wry", final = true, says = { "d.notme" } },
        { "{v:instance} kept a few of its bosses for another day", needs = { "!fullClear", "bossesTotal>0", "bossesKilled>=1" }, says = { "bossesKilled", "d.notme" }, voice = "wry" },
        { "I went into {v:instance} with {counta:strangers:stranger} and high hopes", needs = { "!friend" }, says = { "d.with" }, voice = "wry" },
        { "{v:instance} and I met again", needs = { "!firstVisit" }, voice = "wry" },
        { "I spent {dur:seconds} in {v:instance} and enjoyed every minute", voice = "warm", final = true },
        { "{ref:friend} and I took on {v:instance} together", needs = { "!friend.tags.avoid" }, voice = "warm", says = { "d.with" } },
        { "we made a good group for {v:instance}", says = { "d.group" }, voice = "warm" },
        { "I finally got to see the end of {v:instance}", needs = { "firstClear", "!firstVisit" }, says = FULL, voice = "warm" },


        -- for after a stem that names the dungeon
        { "we killed every boss", needs = { "fullClear" }, says = Join(FULL, { "d.with" }) },
        { "we cleared the lot", needs = { "fullClear" }, says = Join(FULL, { "d.with" }) },
        { "every boss went down", needs = { "fullClear" }, says = Join(FULL, { "d.notme" }), final = true },
        { "we got {num:bossesKilled} of {num:bossesTotal} bosses down", needs = { "!fullClear" }, says = { "d.with" } },
        { "we managed {num:bossesKilled} of the {num:bossesTotal} bosses", needs = { "!fullClear" }, says = { "d.with" } },
        { "we got {count:bossesKilled:boss} down and no further", needs = PART, says = { "d.with" } },
        { "not a single boss went down", needs = { "bossesKilled==0" }, says = { "bossesKilled", "d.notme" }, final = true },
        { "the group was {ref.short:friend}, me and {counta:strangers:stranger}", needs = ONE, says = { "d.group", "d.with", "d.notme" } },
        { "I was with {ref.short.obj:friend} and {counta:strangers:stranger}", needs = ONE, says = { "d.group", "d.with" } },
        { "I finished the place for the first time", needs = { "firstClear" }, says = FULL },
    },

    fragments = {
        "{v:instance} with {ref.obj:friend}",
        "{v:instance} {today}",
        "Ran {v:instance} with {ref.obj:friend}",
        { "Into {v:instance} with {counta:strangers:stranger}", needs = { "!friend" }, says = { "d.with", "d.group" } },
        "A run through {v:instance}",
        { "First time in {v:instance}", needs = { "firstVisit" } },
        { "My first look at {v:instance}", needs = { "firstVisit" } },
        { "{v:instance}, start to finish", needs = { "fullClear" }, says = FULL },
        { "A full clear of {v:instance}", needs = { "fullClear" }, says = FULL },
        { "Finally finished {v:instance}", needs = { "firstClear", "!firstVisit" }, says = FULL },
        { "{v:instance} with a pickup group", needs = { "!friend", "strangers>=2" }, says = { "strangers", "d.with", "d.group" } },
        "{dur.cap:seconds} in {v:instance}",
        { "Back to {v:instance}", needs = { "!firstVisit" } },
        { "{num.cap:bossesKilled} of {num:bossesTotal} bosses in {v:instance}", needs = { "!fullClear" } },
        { "{v:instance} on heroic", needs = { "difficulty==heroic" }, says = { "difficulty" } },
        { "{v:instance} with {ref.obj:friend}, which is how I like it", needs = { "!friend.tags.avoid" }, voice = "warm", final = true },
        { "A happy {part} in {v:instance}", voice = "warm" },
        { "A good {part} in {v:instance} with {ref.obj:friend}", needs = { "!friend.tags.avoid" }, voice = "warm" },
        { "{v:instance} with familiar faces", needs = { "friendCount>=2" }, says = { "friendCount", "d.with" }, voice = "warm", bonus = 0.75 },
        { "{v:instance}, the long way round", needs = { "seconds>=7200" }, voice = "wry" },

        { "{v:instance}, {num:bossesKilled} down", voice = "terse" },
        { "{v:instance}, {dur:seconds}", voice = "terse" },
        { "{v:instance} with {ref.short.obj:friend}", voice = "terse" },
        { "{v:instance}, cleared at last", needs = { "firstClear", "!firstVisit" }, says = FULL, voice = "warm" },
        { "{v:instance}, because the loot won't fetch itself", voice = "wry", final = true },
        { "{v:instance}, first visit", needs = { "firstVisit" }, voice = "terse" },
        { "Another trip into {v:instance}", needs = { "!firstVisit" }, voice = "wry" },
        { "{v:instance}, for my sins", voice = "wry" },
        { "{v:instance}, cleared", needs = { "fullClear" }, says = FULL, voice = "terse" },
        { "{v:instance}: {num:bossesKilled} of {num:bossesTotal}", needs = { "!fullClear" }, voice = "terse" },
        { "{part.cap} in {v:instance}", voice = "terse" },
        { "{v:instance} again", needs = { "!firstVisit" }, voice = "terse" },
    },

    tails = {
        { ", with {ref.obj:friend}", says = { "d.with" } },
        { ", with {ref.short.obj:friend} and {counta:strangers:stranger}", needs = ONE, says = { "d.with", "d.group" } },
        { ", with {ref.obj:friend} and another familiar face", needs = { "friendCount==2" }, says = { "friendCount", "d.with" }, bonus = 0.75 },
        { ", with {ref.obj:friend} and two other familiar faces", needs = { "friendCount==3" }, says = { "friendCount", "d.with" }, bonus = 0.75 },
        { " in a pickup group", needs = { "!friend", "strangers>=2" }, says = { "strangers", "d.with", "d.group" } },
        { ", just {num:groupSize} of us", needs = { "groupSize<=4" } },
        { ", every boss down", needs = { "fullClear" }, says = FULL },
        { ", and we saw it through to the end", needs = { "fullClear" }, says = FULL },
        { ", {num:bossesKilled} of {num:bossesTotal} bosses down", needs = { "!fullClear" } },
        { ", though we only got {count:bossesKilled:boss} down", needs = { "!fullClear", "bossesTotal>0", "bossesKilled<=3" } },
        { ", though not a single boss went down", needs = { "bossesKilled==0" }, says = { "bossesKilled" } },
        ", and we were in there {dur:seconds}",
        ", {dur:seconds} in all",
        { ", my first time there", needs = { "firstVisit" } },
        { ", the first time I'd seen the place", needs = { "firstVisit" } },
        { ", and this time we finished it", needs = { "firstClear", "!firstVisit" }, says = FULL },
        { ", the first time I'd ever finished it", needs = { "firstClear" }, says = FULL },
        { ", my first full clear of the place", needs = { "firstClear" }, says = FULL },
        { ", on heroic", needs = { "difficulty==heroic" }, says = { "difficulty" } },
        { ", which was good fun", voice = "warm" },
        { ", and the company was good", needs = { "!friend.tags.avoid" }, voice = "warm" },
        { ", and I enjoyed it", voice = "warm", bonus = -0.5 },
        { ", in good company", needs = { "friend", "!friend.tags.avoid" }, says = { "d.with", "friend@run" }, voice = "warm" },
        { ", every boss down at last", needs = { "firstClear", "!firstVisit" }, says = FULL, voice = "warm" },
        { ", my first proper look at the place", needs = { "firstVisit" }, voice = "warm" },
        { ", which is one way to spend {part.a}", voice = "wry" },
        { ", for my sins", voice = "wry" },
        { ", which is how these things go", needs = PART, voice = "wry" },
        { ", which was longer than the dungeon deserved", needs = { "seconds>=9000" }, says = { "seconds" }, voice = "wry" },
        { ", and I'd do it again", voice = "wry", bonus = -0.5 },
        { ", {count:bossesKilled:boss} down", voice = "terse" },
        { ", with {ref.short.obj:friend}", voice = "terse", says = { "d.with" } },
        { ", first time", needs = { "firstVisit" }, voice = "terse" },

    },

    wholes = {
        { "We ran {v:instance} {today}.", lead = true },
        { "{ref:friend} and I ran {v:instance} {today}, with {counta:strangers:stranger} making up the group.", needs = ONE },
        "{v:instance} {today}, with {ref.obj:friend}. We were in there {dur:seconds}.",
        { "Into {v:instance} with {counta:strangers:stranger}, and out again with every boss dead.", needs = { "!friend", "fullClear" }, says = FULL },
        { "We cleared {v:instance} {today}: all {num:bossesTotal} bosses, {dur:seconds} start to finish.", needs = { "fullClear", "bossesTotal>=3" }, says = FULL, lead = true },
        { "{dur.cap:seconds} in {v:instance}, and every boss went down.", needs = { "fullClear" }, says = FULL },
        { "We got {num:bossesKilled} of the {num:bossesTotal} bosses in {v:instance} before the run ended.", needs = { "!fullClear" }, lead = true },
        { "We left {v:instance} with {num:bossesKilled} of its {num:bossesTotal} bosses down and the rest still waiting.", needs = { "!fullClear" } },
        { "My first time in {v:instance}, and we cleared the whole place.", needs = { "firstVisit", "fullClear" }, says = Join(FULL, { "firstClear" }) },
        { "I saw all of {v:instance} on my first visit, every boss included.", needs = { "firstVisit", "fullClear" }, says = Join(FULL, { "firstClear" }) },
        { "I'd never been inside {v:instance} before {today}.", needs = { "firstVisit" } },
        { "I finally finished {v:instance} {today}, after never quite getting through it before.", needs = { "firstClear", "!firstVisit" }, says = FULL },
        { "Back to {v:instance} {today}, and this time we finished it.", needs = { "firstClear", "!firstVisit" }, says = FULL },
        { "{v:instance} took {share:seconds}, and we cleared it.", needs = { "fullClear" }, says = FULL },
        { "{ref:friend} and I went into {v:instance} with {counta:strangers:stranger} and came out {dur:seconds} later.", needs = ONE },
        { "Just {ref:friend} and me in {v:instance} {today}.", needs = { "groupSize==2" } },
        { "Only {num:groupSize} of us went into {v:instance}, and we still got {count:bossesKilled:boss} down.", needs = { "groupSize<=3" } },
        "We spent {share:seconds} in {v:instance} with {ref.obj:friend}.",
        { "I ran {v:instance} {today} with {counta:strangers:stranger}.", needs = { "!friend" }, lead = true },
        { "{v:instance} with {ref.short.obj:friend} and {counta:strangers:stranger} {today}, {count:bossesKilled:boss} down.", needs = ONE },
        { "The run through {v:instance} took {dur:seconds}.", lead = true },
        { "{v:instance} on heroic {today}, with {ref.obj:friend}.", needs = { "difficulty==heroic" }, says = { "difficulty" } },
        { "We cleared {v:instance} on heroic.", needs = { "difficulty==heroic", "fullClear" }, says = { "difficulty", "bossesKilled" } },
        { "The {num:groupSize} of us cleared {v:instance} {today}.", needs = { "fullClear" }, says = FULL },
        { "{today.cap} was {v:instance}, with {ref.short.obj:friend} and {counta:strangers:stranger}.", needs = ONE },
        { "{today.cap} was for {v:instance}.", bonus = -0.5 },
        { "We didn't get a single boss down in {v:instance} {today}.", needs = { "bossesKilled==0" }, says = { "bossesKilled" } },
        { "We were in and out of {v:instance} in {dur:seconds}.", needs = { "seconds<=2700" } },
        { "A first look at {v:instance}: {num:bossesKilled} of {num:bossesTotal} bosses before the run ended.", needs = { "firstVisit", "!fullClear" } },
        { "{v:instance} with {ref.obj:friend} and another familiar face {today}.", needs = { "friendCount==2" }, says = { "friendCount" }, bonus = 0.75 },
        { "{v:instance} {today}, with {ref.obj:friend} and two other faces from the diary.", needs = { "friendCount==3" }, says = { "friendCount" }, bonus = 0.75 },
        { "I took a pickup group into {v:instance}, and we got {count:bossesKilled:boss} down.", needs = { "!friend", "strangers>=2" }, says = { "strangers" } },
        { "With {ref.obj:friend} along, {dur:seconds} in {v:instance} went by quickly.", needs = { "!friend.tags.avoid" }, voice = "warm" },
        { "It was good to have {ref.obj:friend} with me in {v:instance} {today}.", needs = { "!friend.tags.avoid" }, voice = "warm" },
        { "I'd waited a while to see the end of {v:instance}, and {today} I did.", needs = { "firstClear", "!firstVisit" }, says = FULL, voice = "warm" },
        { "{ref:friend} and I took on {v:instance} {today}. I can't think of better company for it.", needs = { "!friend.tags.avoid" }, voice = "warm" },
        { "A first visit to {v:instance}, and I'd go back.", needs = { "firstVisit" }, voice = "warm" },
        { "We cleared {v:instance}, and I enjoyed every room of it.", needs = { "fullClear" }, says = FULL, voice = "warm" },
        { "{ref:friend} and I ran {v:instance} {today}. Good company makes a long run short.", needs = { "seconds>=3600", "!friend.tags.avoid" }, voice = "warm" },
        { "A good {part}: {v:instance} with {ref.obj:friend}.", needs = { "!friend.tags.avoid" }, voice = "warm" },
        { "Some {part}s in {v:instance} drag. This one didn't.", needs = { "!firstVisit" }, voice = "warm" },
        { "We cleared {v:instance}, and I came out of it in a good mood.", needs = { "fullClear" }, says = FULL, voice = "warm" },
        { "{v:instance} with familiar faces {today}: {ref.short:friend} and {count:friendCount:other} from the diary.", needs = { "friendCount>=2" }, says = { "friendCount" }, voice = "warm" },
        { "{v:instance} took {dur:seconds}. I'd budgeted less.", needs = { "seconds>=5400" }, voice = "wry" },
        { "{v:instance} and I finally parted on good terms: a full clear.", needs = { "firstClear", "!firstVisit" }, says = FULL, voice = "wry" },
        { "We went into {v:instance} and came out {count:bossesKilled:boss} later. Not the full set.", needs = PART, voice = "wry" },
        { "{num.cap:bossesKilled} of {num:bossesTotal} bosses in {v:instance}. The rest can wait.", needs = PART, voice = "wry" },
        { "{v:instance} {today}: we went in, and not one boss went down.", needs = { "bossesKilled==0" }, says = { "bossesKilled" }, voice = "wry" },
        { "{ref:friend} was in the group for {v:instance} {today}. I kept my thoughts to myself.", needs = { "friend.tags.avoid" }, voice = "wry" },
        { "{v:instance} with four strangers, which is how most of my dungeon stories start.", needs = { "!friend", "strangers==4" }, says = { "strangers" }, voice = "wry" },
        { "{v:instance} again. I know the way by now.", needs = { "!firstVisit" }, voice = "wry" },
        { "{v:instance} again. At this point it should charge me rent.", needs = { "!firstVisit" }, voice = "wry" },
        { "We cleared {v:instance} in {dur:seconds}, which I'm choosing to call efficient.", needs = { "fullClear", "seconds<=3600" }, says = FULL, voice = "wry" },
        { "{dur.cap:seconds} in {v:instance}. Time well spent, or at least spent.", needs = { "seconds>=5400" }, voice = "wry" },
        { "My first trip into {v:instance}. Now I know where it is, at least.", needs = { "firstVisit" }, voice = "wry" },
        { "A pickup group, {v:instance}, {dur:seconds}.", needs = { "!friend", "strangers>=2" }, says = { "strangers" }, voice = "terse" },
        { "{v:instance}. {num.cap:bossesKilled} of {num:bossesTotal} bosses. {dur.cap:seconds}.", needs = { "!fullClear" }, voice = "terse" },
        { "{v:instance}, cleared, {dur:seconds}.", needs = { "fullClear" }, says = FULL, voice = "terse" },
        { "{v:instance} again. {dur.cap:seconds}, every boss.", needs = { "!firstVisit", "fullClear" }, says = FULL, voice = "terse" },
        { "Never been to {v:instance} before {today}. Now I have.", needs = { "firstVisit" }, voice = "terse" },
        { "{v:instance} with {ref.obj:friend}. {dur.cap:seconds}.", voice = "terse" },
        { "{v:instance}. {count.cap:bossesKilled:boss}. {dur.cap:seconds}.", needs = { "!bossesTotal" }, voice = "terse" },
        { "{v:instance}, first visit. {dur.cap:seconds}.", needs = { "firstVisit" }, voice = "terse" },
        { "{v:instance}. First full clear.", needs = { "firstClear" }, says = FULL, voice = "terse" },
        { "{v:instance}, {num:groupSize} of us, {count:bossesKilled:boss}.", voice = "terse" },
        { "Into {v:instance}. Out {dur:seconds} later.", voice = "terse" },
        { "I'd heard {v:instance} was long. It was.", needs = { "firstVisit", "seconds>=7200" }, voice = "wry" },
        { "We cleared {v:instance}, which I mention mainly because it doesn't always happen.", needs = { "fullClear" }, says = FULL, voice = "wry" },
        { "{v:instance} {today}. I went in for the loot and stayed for the corridors.", voice = "wry", bonus = -0.5 },
    },
})

--------------------------------------------------------------------------
-- trouble: wipes and deaths, in good humour and blaming nobody
--------------------------------------------------------------------------
--
-- Every clause, fragment and whole says one of the trouble facts, so no
-- `must` is needed to keep a sentence on topic. Tails that say "of them"
-- follow only a count of deaths: they say wipes and deadliest@trouble too,
-- which keeps them off clauses about wipes or the one who died most.

local OF_DEATHS = { "wipes", "deadliest@trouble" }
local SAFE = { "myDeaths==0", "wipes==0" }
-- Only my deaths: none of the group's were anyone else's.
local ALONE = { "myDeaths>=1", "deaths==@myDeaths" }
-- A tail that comments on a wipe follows only a clause about wipes.
local ON_WIPES = { "deadliest@trouble", "myDeaths", "deaths" }

Add("trouble", {
    must = { "wipes|deaths|myDeaths|noDeaths|deadliestCount" },

    stems = {
        { "All told, ", says = { "d.span", "d.nonum" } },
        { "By my count, ", says = { "d.nonum" } },
        { "In all that time, ", says = { "d.span" } },
        "For the record, ",
        { "Along the way, ", needs = { "!noDeaths" } },
        { "Before it was over, ", needs = { "!noDeaths" } },
        { "It wasn't all smooth: ", needs = { "!noDeaths" } },
        { "As for deaths, ", needs = { "!noDeaths" } },
        { "Start to finish, ", needs = { "noDeaths==true" }, says = { "d.span" } },
        { "Somehow, ", needs = { "noDeaths==true" }, voice = "wry" },
        { "Through no skill of mine, ", needs = { "noDeaths==true" }, voice = "wry" },
        { "Never let it be said we didn't try: ", needs = { "wipes>=2" }, says = ON_WIPES, voice = "wry" },

        { "As for the rest of it, ", voice = "terse", bonus = -0.5 },
        { "It wasn't pretty: ", needs = { "wipes>=2" }, voice = "wry" },
        { "Inevitably, ", needs = { "wipes>=1" }, says = ON_WIPES, voice = "wry" },
        { "Not that it was tidy: ", needs = { "!noDeaths" }, voice = "wry" },
        { "Credit where it's due: ", needs = { "noDeaths==true" }, voice = "warm" },
        { "Happily, ", needs = { "noDeaths==true" }, voice = "warm" },
        { "To be fair to all of us, ", needs = { "wipes>=1" }, says = ON_WIPES, voice = "warm" },

    },

    clauses = {
        -- wipes
        "we wiped {times:wipes}",
        "the whole group went down {times:wipes}",
        "we all ended up on the floor {times:wipes}",
        "{count:wipes:wipe} set us back",
        { "everyone died at least once", needs = { "wipes>=1" }, says = { "wipes", "d.nonum" } },
        { "we [never wiped|didn't wipe once|got through without a wipe]", needs = { "wipes==0", "!noDeaths" }, says = { "wipes", "d.good", "d.nonum" } },
        -- deaths in all
        { "there were {count:deaths:death} between us", says = { "d.between" } },
        { "we racked up {count:deaths:death} between us", says = { "d.between" } },
        { "the group died {times:deaths} in all", says = { "d.times" } },
        { "the death count came to {num:deaths}", needs = { "deaths>=3" } },
        { "{count:deaths:death} was the tally", needs = { "deaths>=4" } },
        -- mine
        "I died {times:myDeaths}",
        "I went down {times:myDeaths}",
        { "I stayed on my feet throughout", needs = Join(SAFE, { "!noDeaths" }), says = { "myDeaths", "d.good", "d.nonum" } },
        { "I didn't die once", needs = Join(SAFE, { "!noDeaths" }), says = { "myDeaths", "d.good", "d.nonum" } },
        { "I was the only one to die, {times:myDeaths}", needs = ALONE, says = { "deaths" }, final = true, bonus = 0.5 },
        { "the only deaths were mine, {num:myDeaths} of them", needs = { "myDeaths>=2", "deaths==@myDeaths" }, says = { "deaths" }, final = true, bonus = 0.5 },
        -- the one who died most
        "{ref:deadliest} died the most, {times:deadliestCount}",
        "{ref:deadliest} had the roughest time of it, with {count:deadliestCount:death}",
        "{ref:deadliest} took the worst of it, going down {times:deadliestCount}",
        "it was {ref:deadliest} who went down most often, {times:deadliestCount}",
        -- nobody
        { "nobody died", needs = { "noDeaths" }, says = { "d.nonum" } },
        { "not one of us died", needs = { "noDeaths" }, says = { "d.nonum" } },
        { "we got through without a single death", needs = { "noDeaths" }, says = { "d.nonum" } },
        { "the whole group stayed on its feet", needs = { "noDeaths" }, says = { "d.nonum" } },
        { "everyone stayed alive the whole way", needs = { "noDeaths" }, says = { "d.nonum" } },
        { "the spirit healer never saw any of us", needs = { "noDeaths" }, says = { "d.nonum" } },
        -- voiced
        { "we kept each other upright the whole way", needs = { "noDeaths" }, says = { "d.nonum" }, voice = "warm" },
        { "we looked after each other well enough that nobody died", needs = { "noDeaths" }, says = { "d.nonum" }, voice = "warm", final = true },
        { "we picked ourselves up {times:wipes} and carried on", needs = { "wipes>=1" }, says = { "d.good" }, voice = "warm" },
        { "{ref:deadliest} went down {times:deadliestCount}, and it could have been any of us", voice = "warm", final = true },
        { "nobody so much as had to run back", needs = { "noDeaths" }, says = { "d.nonum" }, voice = "wry" },
        { "the graveyard didn't see any of us", needs = { "noDeaths" }, says = { "d.nonum" }, voice = "wry" },
        { "nobody died but me, and I managed it {times:myDeaths}", needs = ALONE, says = { "deaths" }, voice = "wry", final = true, bonus = 0.5 },
        { "we wiped {times:wipes}, and I was in every one of them", needs = { "wipes>=2" }, says = { "myDeaths" }, voice = "wry", final = true },
        { "the spirit healer and I got reacquainted {times:myDeaths}", voice = "wry" },
        { "I died {times:myDeaths}, which is not a record I'm proud of", needs = { "myDeaths>=3" }, voice = "wry", final = true },
        { "the floor and I became well acquainted", needs = { "myDeaths>=3" }, says = { "myDeaths", "d.nonum" }, voice = "wry" },
        { "no deaths", needs = { "noDeaths" }, says = { "d.nonum" }, voice = "terse" },
    },

    fragments = {
        { "{count.cap:deaths:death} between us", says = { "d.between" } },
        "{count.cap:wipes:wipe} and {count:deaths:death}",
        { "Not a single death", needs = { "noDeaths" }, says = { "d.nonum" } },
        { "Not one death between us", needs = { "noDeaths" }, says = { "d.nonum", "d.between" } },
        { "A clean run", needs = { "noDeaths" }, says = { "d.nonum" } },
        { "Hard going, with {count:wipes:wipe}", needs = { "wipes>=2" } },
        { "Never wiped", needs = { "wipes==0", "!noDeaths" }, says = { "wipes", "d.span", "d.good", "d.nonum" } },
        { "Only {count:myDeaths:death}, all of them mine", needs = { "myDeaths<=3", "deaths==@myDeaths" }, says = { "deaths" }, final = true, bonus = 0.5 },
        { "A rough run for {ref.obj:deadliest}, with {count:deadliestCount:death}", voice = "warm" },
        { "Nobody hurt, nobody dead", needs = { "noDeaths" }, says = { "d.nonum" }, voice = "warm" },
        { "Every one of us alive at the end", needs = { "noDeaths" }, says = { "d.nonum" }, voice = "warm" },
        { "Plenty of deaths, {num:deaths} in all", needs = { "deaths>=10" }, voice = "wry" },
        { "A lot of lying about on floors", needs = { "deaths>=10" }, says = { "deaths" }, voice = "wry", final = true },
        { "A good run for the spirit healer", needs = { "deaths>=8" }, says = { "deaths" }, voice = "wry" },
        { "{count.cap:wipes:wipe}", voice = "terse" },
        { "No deaths, no wipes", needs = { "noDeaths" }, says = { "d.nonum" }, voice = "terse" },
        { "Died {times:myDeaths}", voice = "terse" },
        { "Wiped {times:wipes}", voice = "terse" },
        { "Died {times:myDeaths} myself", needs = { "deaths>@myDeaths" }, voice = "terse" },
        { "Deaths: {num:deaths}", voice = "terse" },
        { "Alive throughout", needs = Join(SAFE, { "!noDeaths" }), says = { "myDeaths", "d.good", "d.nonum" }, voice = "terse" },
    },

    tails = {
        { ", and I died {times:myDeaths} myself", needs = { "deaths>@myDeaths" }, says = { "wipes" } },
        { ", {num:myDeaths} of them mine", needs = { "deaths>@myDeaths" }, says = Join(OF_DEATHS, { "d.times" }) },
        { ", none of them mine", needs = Join(SAFE, { "!noDeaths", "deaths>=2" }), says = Join(OF_DEATHS, { "myDeaths", "d.times" }) },
        { ", though I stayed on my feet", needs = Join(SAFE, { "!noDeaths" }), says = { "myDeaths", "wipes" } },
        { ", with {ref.obj:deadliest} going down most often", says = { "d.good" } },
        { ", {num:deadliestCount} of them {ref.poss:deadliest}", needs = { "deadliest.diary" }, says = { "wipes", "myDeaths", "d.times" } },
        { ", though only {count:wipes:wipe}", says = { "myDeaths", "deadliest@trouble" } },
        { ", but no wipes", needs = { "wipes==0", "!noDeaths" }, says = { "wipes", "myDeaths", "deadliest@trouble", "d.good" } },
        { ", but we got there in the end", needs = { "wipes>=1", "fullClear==true" }, says = { "deadliest@trouble", "d.good" } },
        { ", start to finish", needs = { "noDeaths==true" } },
        { ", which is not bad for a pickup group", needs = { "noDeaths==true", "!friend" } },
        { ", but I'd still call it a good run", needs = { "!noDeaths" }, says = { "deadliest@trouble", "d.good" }, voice = "warm" },
        { ", which I was glad of", needs = { "noDeaths==true" }, voice = "warm" },
        { ", and it was nobody's fault in particular", needs = { "wipes>=1" }, says = ON_WIPES, voice = "warm" },
        { ", and we laughed about it afterwards, or I did", needs = { "wipes>=1" }, says = ON_WIPES, voice = "wry" },
        { ", which builds character, I'm told", needs = { "wipes>=1" }, says = { "deadliest@trouble", "d.good" }, voice = "wry" },
        { ", which my repair bill will remember", needs = { "myDeaths>=2" }, says = { "deadliest@trouble" }, voice = "wry" },
        { ", not that anyone was counting", needs = { "!noDeaths" }, says = { "d.good" }, voice = "wry" },
        { ", all told", needs = { "deaths>=2" }, says = { "d.nonum", "deadliest@trouble" }, voice = "terse" },
    },

    wholes = {
        { "Nobody died. Not once.", needs = { "noDeaths" } },
        { "Not one death between us, start to finish.", needs = { "noDeaths" } },
        { "Nobody died, and nobody had to run back from the graveyard.", needs = { "noDeaths" } },
        { "A clean run: no wipes, no deaths.", needs = { "noDeaths" } },
        "{count.cap:wipes:wipe} and {count:deaths:death} in all. It wasn't a clean run.",
        { "There were {count:deaths:death} between us, {num:myDeaths} of them mine.", needs = { "deaths>@myDeaths" } },
        "{times.cap:wipes}, the whole group went down.",
        { "We all died at least once.", needs = { "wipes>=1" }, says = { "wipes" } },
        { "We wiped {times:wipes} and still finished it.", needs = { "fullClear==true" } },
        { "We never wiped, though there were {count:deaths:death} along the way.", needs = { "wipes==0", "deaths>=2" }, says = { "wipes" } },
        { "{count.cap:deaths:death} between us, but no wipes.", needs = { "wipes==0" }, says = { "wipes" } },
        { "I didn't die once. The others weren't so lucky: {count:deaths:death} between them.", needs = SAFE, says = { "myDeaths" } },
        { "It was a rough one: {count:wipes:wipe} and {count:deaths:death}.", needs = { "wipes>=2" } },
        { "Only one wipe, which is about as tidy as these things go.", needs = { "wipes==1" }, says = { "wipes" } },
        "{ref:deadliest} died the most, {times:deadliestCount}. Not that it's a competition.",
        "There were {count:deaths:death} in all, {ref:deadliest} accounting for {num:deadliestCount}.",
        { "I was the only one to die, {times:myDeaths}.", needs = ALONE, says = { "deaths" }, bonus = 0.5 },
        { "{count.cap:myDeaths:death} for me, {num:deaths} for the group as a whole.", needs = { "deaths>@myDeaths" } },
        { "Not a single wipe, and only {count:deaths:death} all run.", needs = { "wipes==0", "deaths<=3" }, says = { "wipes" } },
        { "{ref:deadliest} died the most, {times:deadliestCount}. It happens to all of us.", voice = "warm" },
        { "Spare a thought for {ref.obj:deadliest}, who went down {times:deadliestCount}.", voice = "warm" },

        { "{ref:deadliest} had a rough run of it, with {count:deadliestCount:death}. I've had runs like that.", voice = "warm" },
        { "We wiped {times:wipes}. Nobody's fault; these things happen.", voice = "warm" },
        { "Nobody died, which I was quietly pleased about.", needs = { "noDeaths" }, voice = "warm" },
        { "{ref:deadliest} went down {times:deadliestCount}; we all had our moments.", needs = { "myDeaths>=1" }, voice = "warm" },
        { "We wiped {times:wipes}, picked ourselves up and kept going.", needs = { "!fullClear" }, voice = "warm" },
        { "We wiped {times:wipes}, and nobody gave up on the run.", needs = { "fullClear==true" }, voice = "warm" },
        { "Nobody died. I'll remember this group.", needs = { "noDeaths" }, voice = "warm" },
        { "There were {count:deaths:death} between us, and I wouldn't have wanted a different group.", needs = { "deaths>=2" }, voice = "warm" },
        { "Not a single death in there, which I'm not used to.", needs = { "noDeaths" }, voice = "wry" },
        { "Nobody died. I'd almost forgotten that was possible.", needs = { "noDeaths" }, voice = "wry" },
        { "Nobody died, me included.", needs = { "noDeaths" }, voice = "wry" },
        { "We wiped {times:wipes} and lived to tell it, more or less.", voice = "wry" },
        { "The floor and I got well acquainted: {count:myDeaths:death}.", needs = { "myDeaths>=3" }, voice = "wry" },
        { "I died {times:myDeaths}, my contribution to {today}'s death count.", voice = "wry" },
        { "I died {times:myDeaths}. I'd like to blame the lag.", voice = "wry" },
        { "The group wiped {times:wipes}, and I'd be lying if I said I enjoyed it.", voice = "wry" },
        { "I came through without dying, which is more than I usually manage.", needs = Join(SAFE, { "!noDeaths" }), says = { "myDeaths" }, voice = "wry" },
        { "Nobody died but me, and I managed it {times:myDeaths}. Someone had to.", needs = ALONE, says = { "deaths" }, voice = "wry", bonus = 0.5 },
        { "The spirit healer got to know me {today}: {count:myDeaths:death}.", needs = { "myDeaths>=2" }, voice = "wry" },
        { "{count.cap:deaths:death} between us. I'd like to think the floors needed the company.", needs = { "deaths>=8" }, voice = "wry" },
        { "Clean. Nobody died.", needs = { "noDeaths" }, voice = "terse" },
        { "Wiped {times:wipes}. Died {times:myDeaths}. Still here.", voice = "terse" },
        { "Deaths: {num:deaths}. Wipes: none.", needs = { "wipes==0" }, says = { "wipes" }, voice = "terse" },
        { "Deaths: {num:deaths}. Wipes: {num:wipes}.", voice = "terse" },
        { "No deaths.", needs = { "noDeaths" }, voice = "terse" },
    },
})

--------------------------------------------------------------------------
-- loot: what dropped for me, and for my friend
--------------------------------------------------------------------------
--
-- Every clause, fragment and whole names myLoot or friendLoot. Pieces only
-- about my own loot ("for my trouble") say friendLoot too, which keeps them
-- off clauses about the friend's. Pieces saying nothing came my way say
-- d.nomine, so they say it once.

local MINE = { "friendLoot" }
local NONE = { "d.nomine" }

Add("loot", {
    must = { "myLoot|friendLoot" },

    stems = {
        "As for loot, ",
        "On the loot front, ",
        "[By|In] the end, ",
        "When it was all over, ",
        "By the time we were done, ",
        { "For my trouble, ", says = Join(MINE, NONE, { "d.noobj" }) },
        { "For once, ", says = Join(MINE, NONE, { "d.once" }), voice = "wry" },
        { "Not that I was keeping track, but ", says = MINE, voice = "wry" },
        { "To my bags' delight, ", says = Join(MINE, NONE, { "d.noobj" }), voice = "wry" },
        { "I'm glad to say ", says = NONE, voice = "warm" },
        { "Spoils: ", voice = "terse" },
        { "Happily, ", says = NONE, voice = "warm" },
        { "Best of all, ", says = NONE, voice = "warm", bonus = -0.5 },
        { "Loot-wise, ", voice = "terse" },
    },

    clauses = {
        -- mine
        "I [came away|walked out] with {items:myLoot}",
        { "{items:myLoot} went into my bags", says = { "d.noobj" } },
        { "{items:myLoot} dropped for me", says = { "d.noobj" } },
        "I picked up {items:myLoot}",
        "I ended up with {items:myLoot}",
        { "{items:myLoot} came my way", says = { "d.noobj" } },
        { "I left with {items:myLoot} in my bags", says = { "d.noobj" } },
        { "my share was {items:myLoot}", says = { "d.noobj" } },
        "I got my hands on {items:myLoot}",
        { "I got {items:myLoot}", bonus = -0.5 },
        -- the friend's
        "{ref:friend} [came away|walked out] with {items:friendLoot}",
        "{ref:friend} got {items:friendLoot}",
        "{items:friendLoot} went to {ref.obj:friend}",
        "{ref:friend} picked up {items:friendLoot}",
        "{items:friendLoot} came {ref.poss:friend} way",
        "{items:friendLoot} ended up in {ref.poss:friend} bags",
        -- both
        "I got {items:myLoot} and {ref:friend} got {items:friendLoot}",
        "{items:myLoot} went to me and {items:friendLoot} to {ref.obj:friend}",
        { "{ref:friend} and I both came away with something: {items:myLoot} for me, {items:friendLoot} for {him:friend}", needs = { "friend.sex" }, final = true },
        -- the friend's, none mine
        { "nothing dropped for me, but {ref:friend} came away with {items:friendLoot}", needs = { "!myLoot" }, says = NONE },
        { "I came away empty-handed, but {ref:friend} got {items:friendLoot}", needs = { "!myLoot" }, says = NONE },
        { "the loot passed me by and went to {ref.obj:friend} instead: {items:friendLoot}", needs = { "!myLoot" }, says = NONE, final = true },
        -- voiced
        { "I was pleased to come away with {items:myLoot}", voice = "warm" },
        { "{items:myLoot} came my way, which made the run for me", voice = "warm", final = true },
        { "{ref:friend} and I each had something to show for it: {items:myLoot} for me, {items:friendLoot} for {ref.short.obj:friend}", needs = { "!friend.tags.avoid" }, voice = "warm", final = true },
        { "the loot fairy smiled on me: {items:myLoot}", voice = "wry", says = MINE, final = true },
        { "{items:myLoot} followed me home", voice = "wry" },
        { "{ref:friend} came away with {items:friendLoot}, which pleased me nearly as much as loot of my own", needs = { "!friend.tags.avoid" }, voice = "warm", final = true },
        { "{ref:friend} did better out of it than I did, with {items:friendLoot}", needs = { "!myLoot" }, says = NONE, voice = "wry" },
        { "{items:myLoot} somehow ended up in my bags", says = { "d.noobj" }, voice = "wry" },
        { "my bags gained {items:myLoot}", says = { "d.noobj" }, voice = "wry" },
        { "the run left me {items:myLoot} richer", says = { "d.noobj" }, voice = "wry" },
        { "{items:myLoot} for me", voice = "terse" },
        { "{items:friendLoot} to {ref.obj:friend}", voice = "terse" },
    },

    fragments = {
        "Came away with {items:myLoot}",
        "{items:friendLoot} for {ref.obj:friend}",
        { "Into my bags: {items:myLoot}", final = true },
        { "{items:myLoot} to show for it", says = { "friendLoot" } },
        "Loot for {ref.obj:friend}: {items:friendLoot}",
        { "Picked up {items:myLoot} on the way round", final = true },
        { "Nothing for me, {items:friendLoot} for {ref.obj:friend}", needs = { "!myLoot" }, says = NONE },
        { "Something for both of us: {items:myLoot} for me, {items:friendLoot} for {ref.obj:friend}", final = true },
        { "{today.cap}'s haul: {items:myLoot}", says = { "d.show" }, final = true },
        { "Something for {ref.obj:friend} too: {items:friendLoot}", needs = { "myLoot~=__nil", "!friend.tags.avoid" }, voice = "warm", final = true },
        { "A good haul for {ref.obj:friend}, too: {items:friendLoot}", needs = { "myLoot~=__nil", "!friend.tags.avoid" }, says = { "myLoot" }, voice = "warm", final = true, bonus = -1 },
        { "My cut: {items:myLoot}", voice = "wry", final = true },
        { "Proof I was there: {items:myLoot}", voice = "wry", says = { "d.show" }, final = true },
        { "A small haul, but mine: {items:myLoot}", needs = { "#myLoot==1" }, voice = "wry", says = MINE, final = true },
        { "Loot: {items:myLoot}", voice = "terse", final = true },
        { "My share: {items:myLoot}", voice = "terse", final = true },
        { "{ref.short.poss:friend} loot: {items:friendLoot}", voice = "terse" },
        { "{items:myLoot} for me, {items:friendLoot} for {ref.obj:friend}", voice = "terse" },
    },

    tails = {
        ", and {ref:friend} got {items:friendLoot}",
        ", while {ref:friend} came away with {items:friendLoot}",
        ", and {items:friendLoot} went to {ref.obj:friend}",
        ", plus {items:friendLoot} for {ref.obj:friend}",
        { ", and {ref:friend} came away with something too: {items:friendLoot}", needs = { "myLoot~=__nil" } },
        { ", and nothing for me", needs = { "!myLoot" }, says = NONE },
        { ", though nothing dropped for me", needs = { "!myLoot" }, says = NONE },
        { " for my trouble", says = Join(MINE, { "d.noobj" }) },
        { " to show for it", says = Join(MINE, { "d.show", "d.noobj" }) },
        { ", and that was the lot", says = MINE },
        { ", which was nice to see", needs = { "!friend.tags.avoid" }, says = { "myLoot" }, voice = "warm" },
        { ", and I was glad of it", says = MINE, voice = "warm" },
        { ", and I'm not complaining", says = MINE, voice = "warm" },
        { ", and good for {him:friend}", needs = { "friend.sex", "!friend.tags.avoid" }, says = { "myLoot", "d.backfriend" }, back = true, voice = "warm" },
        { ", which pleased me almost as much as my own", needs = { "myLoot~=__nil", "!friend.tags.avoid" }, says = { "myLoot" }, voice = "warm" },
        { ", which my bags were glad of", says = MINE, voice = "wry", bonus = -0.5 },
        { ", and my bags were the heavier for it", says = MINE, voice = "wry" },
        { ", and I'll take it", says = MINE, voice = "wry" },
        { ", which is more than I'd hoped for", says = MINE, voice = "wry", bonus = -0.5 },
        { ", {items:friendLoot} for {ref.obj:friend}", voice = "terse" },
        { ", nothing for me", needs = { "!myLoot" }, says = NONE, voice = "terse" },
    },

    wholes = {
        "I came away from it with {items:myLoot}.",
        "The loot was {items:myLoot} for me and {items:friendLoot} for {ref.obj:friend}.",
        "{items:myLoot} came my way {today}.",
        { "When it was all done, I had {items:myLoot} to show for it.", says = { "d.show" } },
        "{items:friendLoot} went to {ref.obj:friend}, and {items:myLoot} to me.",
        "I picked up {items:myLoot} along the way.",
        "I came out of it with {items:myLoot}, and {ref:friend} with {items:friendLoot}.",
        "{items:friendLoot} for {ref.obj:friend}; for me, {items:myLoot}.",
        "Out of all that, {items:myLoot} ended up with me.",
        "I left {today} with {items:myLoot}.",
        "It wasn't a wasted trip: {items:myLoot} came with me.",
        "{ref:friend} came away with {items:friendLoot}.",
        "{ref:friend} came out of it with {items:friendLoot}.",
        "My bags were heavier on the way out: {items:myLoot}.",
        { "Nothing came my way, but {items:friendLoot} went to {ref.obj:friend}.", needs = { "!myLoot" }, says = NONE },
        { "Nothing for me this time. {ref:friend} got {items:friendLoot}.", needs = { "!myLoot" }, says = NONE },
        { "{ref:friend} did better out of it than I did: {items:friendLoot}, and nothing for me.", needs = { "!myLoot" }, says = NONE, voice = "wry" },
        { "Nothing dropped for me, but {ref:friend} came away with {items:friendLoot}, and that's nearly as good.", needs = { "!myLoot", "!friend.tags.avoid" }, says = NONE, voice = "warm" },
        { "{ref:friend} came away with {items:friendLoot}. I was glad it went to someone I know.", needs = { "!friend.tags.avoid" }, voice = "warm" },
        { "{ref:friend} came away with {items:friendLoot}, and good for {him:friend}.", needs = { "friend.sex", "!friend.tags.avoid" }, voice = "warm" },
        { "I won't pretend I wasn't pleased to come away with {items:myLoot}.", voice = "warm" },
        { "{items:myLoot} for me and {items:friendLoot} for {ref.obj:friend}. A good {part} for both of us.", needs = { "!friend.tags.avoid" }, voice = "warm" },
        { "I walked out with {items:myLoot}, and my bags were the heavier for it.", voice = "wry" },
        { "I left with more than I came in with: {items:myLoot}.", voice = "wry" },
        { "The run left me {items:myLoot} richer.", voice = "wry" },
        { "My share of the spoils: {items:myLoot}.", voice = "wry" },
        { "{items:myLoot} dropped for me, which I'll take.", voice = "wry" },
        { "For all that, {items:myLoot}. I'll take it.", voice = "wry" },
        { "Loot: {items:myLoot}.", voice = "terse" },
        { "Loot for me: {items:myLoot}. For {ref.obj:friend}: {items:friendLoot}.", voice = "terse" },
        { "Mine: {items:myLoot}.", voice = "terse" },
        { "{ref.short:friend}: {items:friendLoot}.", voice = "terse" },
    },
})

--------------------------------------------------------------------------
-- roll: the drama of a roll, won or lost
--------------------------------------------------------------------------
--
-- Every sentence names the item (`must`) and says who came out ahead:
-- winning pieces need iWon, losing ones need !iWon and say iWon by hand
-- (Won and Lost above). Clauses tagged d.itref call the item "it" and need
-- a stem that names it. Two clauses only give my roll, and take a tail
-- that settles the roll.

local ROLL = { "d.rollnoun" }

Add("roll", {
    must = { "rollItem", "iWon" },

    stems = {
        "When {item:rollItem} dropped, ",
        "{item:rollItem} dropped, and ",
        { "{item:rollItem} came up for rolls, and ", says = ROLL },
        { "In the roll for {dungeon_the:rollItem}, ", says = ROLL },
        { "When it came to the roll for {dungeon_the:rollItem}, ", says = ROLL },
        "With {item:rollItem} up for grabs, ",
        { "Then came the roll: ", says = ROLL },
        { "So close: ", needs = { "close", "!iWon" } },
        { "When the dust settled, ", says = { "d.nowinner" } },
        { "Alas, ", needs = { "!iWon" }, says = { "d.luck" }, voice = "wry" },
        { "To my quiet delight, ", needs = { "iWon==true" }, says = { "d.glad" }, voice = "warm" },
        { "For once, ", needs = { "iWon==true" }, says = { "d.once" }, voice = "wry" },
        { "Against the odds, ", needs = { "iWon==true", "myRoll<=30" }, voice = "wry" },
        { "Then the dice had their say: ", voice = "wry" },
        { "Happily, ", needs = { "iWon==true" }, voice = "warm" },
        { "Win some, lose some: ", needs = { "!iWon" }, voice = "warm" },
        { "Rolls: ", voice = "terse" },
        { "Roll for {dungeon_the:rollItem}: ", says = ROLL, voice = "terse" },
    },

    clauses = {
        -- won, the item named
        Won("I [won|took] {item:rollItem} with {digits.a:myRoll}"),
        Won({ "I won the roll for {item:rollItem}", says = ROLL }),
        Won("my {digits:myRoll} won {item:rollItem}"),
        Won("{item:rollItem} went to me on {digits.a:myRoll}"),
        Won("I rolled {digits.a:myRoll} and won {item:rollItem}"),
        Won("{dungeon_the:rollItem} was mine with {digits.a:myRoll}"),
        Won("{dungeon_the:rollItem} went my way"),
        Won({ "I won {item:rollItem}, {digits:myRoll} to {dungeon_beat:winRoll}", says = { "d.margin" } }),
        Won({ "my {digits:myRoll} edged out {dungeon_beat.a:winRoll} for {item:rollItem}", needs = { "close" }, says = { "d.margin" } }),
        Won({ "I won {item:rollItem} by {dungeon_margin}", needs = { "close" } }),
        Won({ "I won {item:rollItem} with {digits.a:myRoll}, of all things", needs = { "myRoll<=20" }, voice = "wry", final = true }),
        -- won, the item left to a stem
        Won({ "I won the roll with {digits.a:myRoll}", says = ROLL }),
        Won("I came out on top with {digits.a:myRoll}"),
        Won({ "my {digits:myRoll} took it", says = { "d.itref" } }),
        Won({ "the roll went my way", says = ROLL }),
        Won({ "I beat {dungeon_beat.a:winRoll} with {digits.a:myRoll}", says = { "d.margin" } }),
        Won({ "I rolled a perfect {digits:myRoll}", needs = { "myRoll==100" } }),
        Won({ "nobody topped my {digits:myRoll}", needs = { "myRoll>=50" } }),
        Won({ "I won with a measly {digits:myRoll}", needs = { "myRoll<=20" }, voice = "wry" }),
        Won({ "I won it, and I may never roll that well again", needs = { "myRoll>=95" }, says = { "d.itref" }, voice = "wry", final = true }),
        Won({ "I won it, and I was delighted", says = { "d.itref", "d.glad" }, voice = "warm", final = true }),
        Won({ "I won {item:rollItem}, and I was as pleased as I'd been all {part}", voice = "warm", final = true }),
        Won({ "I won it with {digits.a:myRoll}, and I'm still smiling", says = { "d.itref", "d.glad" }, voice = "warm", final = true }),
        Won({ "won it, {digits:myRoll}", says = { "d.itref" }, voice = "terse" }),
        Won({ "won {item:rollItem} on {digits.a:myRoll}", voice = "terse" }),
        Won({ "it was mine on {digits.a:myRoll}", says = { "d.itref" }, voice = "terse" }),

        -- lost, the item named
        Lost("{ref:winner} won {item:rollItem}"),
        Lost({ "{ref:winner} won the roll for {item:rollItem} with {digits.a:winRoll}", says = ROLL }),
        Lost("{item:rollItem} went to {ref.obj:winner}"),
        Lost({ "{ref:winner} took {item:rollItem} with {digits.a:winRoll} to my {digits:myRoll}", says = { "d.margin" } }),
        Lost("I lost {item:rollItem} to {ref.obj:winner}"),
        Lost({ "{dungeon_the:rollItem} went to {ref.obj:winner}, {digits:winRoll} to my {digits:myRoll}", says = { "d.margin" } }),
        Lost({ "I lost the roll for {item:rollItem} by {dungeon_margin}", needs = { "close" }, says = ROLL }),
        Lost({ "{ref:winner} pipped me to {item:rollItem}", needs = { "close" } }),
        -- lost, the item left to a stem
        Lost({ "{ref:winner} beat my {digits:myRoll} with {digits.a:winRoll}", says = { "d.margin" } }),
        Lost({ "my {digits:myRoll} lost to {ref.poss:winner} {digits:winRoll}", says = { "d.margin" } }),
        Lost({ "{ref:winner} edged me out by {dungeon_margin}", needs = { "close" } }),
        Lost("{ref:winner} outrolled me"),
        Lost({ "the roll went against me", says = ROLL }),
        Lost({ "{ref:winner} rolled a perfect {digits:winRoll}", needs = { "winRoll==100" } }),
        Lost({ "even {digits.a:myRoll} wasn't enough against {ref.poss:winner} {digits:winRoll}", needs = { "myRoll>=90" }, says = { "d.margin" } }),
        Lost({ "my {digits:myRoll} wasn't enough against {ref.poss:winner} {digits:winRoll}", needs = { "myRoll<90" }, says = { "d.margin" } }),
        Lost({ "I rolled a miserable {digits:myRoll}", needs = { "myRoll<=10" }, voice = "wry" }),
        Lost({ "{ref:winner} rolled {digits.a:winRoll} and that was that", voice = "wry", final = true }),
        Lost({ "{ref:winner} won it, and fair enough", says = { "d.itref", "d.fair" }, voice = "warm", final = true }),
        Lost({ "{ref:winner} won it fairly, and I can't complain", says = { "d.itref" }, voice = "warm", final = true }),
        Lost({ "the dice sided with {ref.obj:winner}", voice = "wry" }),
        Lost({ "{ref:winner} rolled higher, as people tend to when I'm rolling", voice = "wry", final = true }),
        Lost({ "I lost, {digits:myRoll} to {digits:winRoll}", says = { "d.margin" }, voice = "terse", final = true }),
        Lost({ "{ref:winner} won {item:rollItem}, and it couldn't have gone to a nicer roll", needs = { "winRoll>=90" }, voice = "warm", final = true }),
        Lost({ "lost {item:rollItem} to {ref.obj:winner}", voice = "terse" }),

        -- my roll only; a tail settles it
        "I rolled {digits.a:myRoll} for {item:rollItem}",
        "I rolled {digits.a:myRoll}",
    },

    fragments = {
        Won("Won {item:rollItem} with {digits.a:myRoll}"),
        Won({ "Won the roll for {item:rollItem}", says = ROLL }),
        Won("{item:rollItem}, mine on {digits.a:myRoll}"),
        Won({ "A perfect {digits:myRoll} for {item:rollItem}", needs = { "myRoll==100" } }),
        Won({ "Mine by {dungeon_margin}: {item:rollItem}", needs = { "close" }, voice = "terse", final = true }),
        Won({ "A win: {item:rollItem}, {digits:myRoll} to {dungeon_beat:winRoll}", says = { "d.margin" }, voice = "terse", final = true }),
        Lost("Lost {item:rollItem} to {ref.obj:winner}"),
        Lost("Outrolled for {item:rollItem}"),
        Lost({ "Beaten to {item:rollItem} by {dungeon_margin}", needs = { "close" } }),
        Lost({ "So close on {dungeon_the:rollItem}", needs = { "close" } }),
        Lost("No luck on {dungeon_the:rollItem}"),
        Lost({ "{item:rollItem} to {ref.obj:winner}, {digits:winRoll} to my {digits:myRoll}", says = { "d.margin" }, voice = "terse", final = true }),
        Lost({ "Pipped to {dungeon_the:rollItem}", needs = { "close" }, voice = "wry" }),
        Won("{item:rollItem}, won fair and square"),
        Won({ "The roll for {dungeon_the:rollItem}, won with {digits.a:myRoll}" }),
        Won({ "A lucky {digits:myRoll} for {item:rollItem}", needs = { "myRoll<=40" }, voice = "wry" }),
        Won({ "{item:rollItem}, and the luck to go with it", voice = "warm" }),
        Lost("{item:rollItem} to {ref.obj:winner}"),
        Lost({ "Close but not quite on {dungeon_the:rollItem}", needs = { "close" } }),
        Lost({ "A good roll lost to a better one: {digits:myRoll} to {ref.poss:winner} {digits:winRoll}", needs = { "myRoll>=70" }, says = { "d.margin", "rollItem" }, voice = "warm", final = true }),
        Lost({ "Outrolled for {item:rollItem}. The dice and I are not friends", voice = "wry", final = true }),
        Lost({ "Lost the roll for {dungeon_the:rollItem}", voice = "terse" }),
    },

    tails = {
        -- after a clause that says I won
        { ", with {digits.a:myRoll}", needs = { "iWon==true" } },
        { ", {digits:myRoll} to {dungeon_beat:winRoll}", needs = { "iWon==true" }, says = { "d.margin" } },
        { ", so {item:rollItem} was mine", needs = { "iWon==true" }, says = { "d.itref" } },
        { ", and I'll be insufferable about it for a while", needs = { "iWon==true" }, voice = "wry" },
        { ", and I was delighted", needs = { "iWon==true" }, says = { "d.glad" }, voice = "warm" },


        -- after a clause that says I lost
        { ", {digits:winRoll} to my {digits:myRoll}", needs = { "!iWon" }, says = { "d.margin" } },
        { ", so {item:rollItem} went to {him:winner}", needs = { "!iWon", "winner.sex" }, says = { "d.itref", "d.nowinner" }, back = true },
        { ", so {dungeon_the:rollItem} wasn't mine", needs = { "!iWon" }, says = { "d.itref" } },
        { ", and fair enough", needs = { "!iWon" }, says = { "d.fair" } },
        { ", and I can't argue with {digits.a:winRoll}", needs = { "!iWon", "winRoll>=70" } },
        { ", and it wasn't close{dungeon_wide}", needs = { "!iWon" } },
        { ", and good for {him:winner}", needs = { "!iWon", "winner.sex" }, says = { "d.nowinner" }, back = true, voice = "warm" },
        { ", and I hope it serves {him:winner} well", needs = { "!iWon", "winner.sex" }, says = { "d.nowinner" }, back = true, voice = "warm" },
        { ", which is roughly how my luck goes", needs = { "!iWon" }, voice = "wry" },
        { ", {digits:winRoll} to {digits:myRoll}", needs = { "!iWon" }, says = { "d.margin" }, voice = "terse" },
        -- either way
        ", by {dungeon_margin:narrow}",
        { ", by a clear {dungeon_margin:wide}", bonus = -0.5 },
        { ", fair and square", says = { "d.fair" } },
        { ", and it was close", needs = { "close" } },
        -- settling a clause that only gives my roll
        Won(", and won"),
        Won(", and nobody [beat|topped] it"),
        Lost(", which wasn't enough"),
        Lost(", but {ref:winner} [rolled|beat it with] {digits.a:winRoll}"),
        Lost({ ", and {ref:winner} rolled higher", voice = "wry" }),
    },

    wholes = {
        Won("{item:rollItem} dropped, and I won it with {digits.a:myRoll}."),
        Won("I rolled {digits.a:myRoll} for {item:rollItem} and won."),
        Won("{item:rollItem} dropped, I rolled {digits.a:myRoll}, and nobody beat it."),
        Won("{item:rollItem} is mine now, thanks to {digits.a:myRoll}."),
        Won("I won {item:rollItem}. My {digits:myRoll} held up."),
        Won({ "My {digits:myRoll} beat {dungeon_beat.a:winRoll} for {item:rollItem}. Close.", needs = { "close" }, says = { "d.margin" } }),
        Won({ "My {digits:myRoll} edged out {dungeon_beat.a:winRoll}, and {item:rollItem} was mine.", needs = { "close" }, says = { "d.margin" } }),
        Won({ "The roll for {dungeon_the:rollItem} came down to {dungeon_margin}, and it went my way.", needs = { "close" } }),
        Won({ "I won {item:rollItem} by {dungeon_margin:one}; it doesn't get much closer.", needs = { "close" } }),
        Won({ "A perfect {digits:myRoll} won me {item:rollItem}.", needs = { "myRoll==100" } }),
        Won({ "{item:rollItem} went to me on {digits.a:myRoll}, which nobody was going to beat.", needs = { "myRoll>=97" } }),
        Won({ "I won {item:rollItem} with {digits.a:myRoll}, and I was delighted.", says = { "d.glad" }, voice = "warm" }),
        Won({ "{item:rollItem} came my way on {digits.a:myRoll}. A happy roll.", voice = "warm" }),
        Won({ "I won {item:rollItem}, and I'll treasure it, whatever it turns out to be worth.", voice = "warm" }),
        Won({ "I won {item:rollItem} on {digits.a:myRoll}, and I'll be insufferable about it for a while.", voice = "wry" }),
        Won({ "I won {item:rollItem} with {digits.a:myRoll}, of all things.", needs = { "myRoll<=20" }, voice = "wry" }),
        Won({ "My {digits:myRoll} won {item:rollItem}. The others rolled even lower, which takes some doing.", needs = { "myRoll<=15" }, voice = "wry" }),
        Won({ "I rolled for {item:rollItem} and, for once, the dice agreed with me.", says = { "d.once" }, voice = "wry" }),
        Won({ "Won the roll for {item:rollItem}: {digits:myRoll}.", voice = "terse" }),
        Won({ "Mine: {item:rollItem}, on {digits.a:myRoll}.", voice = "terse" }),
        Won({ "{item:rollItem}. Rolled {digits:myRoll}. Won.", voice = "terse" }),
        Won({ "I won {item:rollItem}. Some {part}s the dice like me.", voice = "warm" }),

        Lost("{item:rollItem} came up for rolls, and {ref:winner} won it with {digits.a:winRoll} to my {digits:myRoll}."),
        Lost({ "{ref:winner} rolled {digits.a:winRoll} for {item:rollItem}, against my {digits:myRoll}. Fair enough.", says = { "d.fair" } }),
        Lost("It was {digits:myRoll} against {digits:winRoll}, and {item:rollItem} went to {ref.obj:winner}."),
        Lost("I rolled {digits.a:myRoll} on {item:rollItem}. It wasn't enough; {ref:winner} rolled {digits.a:winRoll}."),
        Lost({ "{ref:winner} won {item:rollItem} fair and square.", says = { "d.fair" } }),
        Lost({ "{ref:winner} took {item:rollItem} with {digits.a:winRoll}. Well rolled.", needs = { "winRoll>=60" } }),
        Lost({ "{ref:winner} won {item:rollItem} with {digits.a:winRoll}, which tells you what I rolled.", needs = { "winRoll<=15" }, voice = "wry" }),
        Lost("I rolled {digits.a:myRoll}, {ref:winner} rolled {digits.a:winRoll}, and that settled {dungeon_the:rollItem}."),
        Lost({ "I lost {item:rollItem} to {ref.obj:winner} by {dungeon_margin}. So close.", needs = { "close" } }),
        Lost({ "{ref:winner} pipped me to {item:rollItem}, {digits:winRoll} to {digits:myRoll}.", needs = { "close" }, says = { "d.margin" } }),
        Lost({ "The roll for {dungeon_the:rollItem} came down to {dungeon_margin}, and it went to {ref.obj:winner}.", needs = { "close" } }),
        Lost({ "{ref:winner} rolled a perfect {digits:winRoll} for {item:rollItem}. Nothing to be done about that.", needs = { "winRoll==100" } }),
        Lost({ "My {digits:myRoll} would beat most rolls, just not {ref.poss:winner} {digits:winRoll}, so {item:rollItem} went to {him:winner}.", needs = { "myRoll>=85", "winner.sex" }, says = { "d.margin" } }),
        Lost({ "{ref:winner} won {item:rollItem}, and I can't begrudge {him:winner} a fair roll.", needs = { "winner.sex" }, voice = "warm" }),
        Lost({ "{ref:winner} won {item:rollItem}. A fair roll is a fair roll.", voice = "warm" }),
        Lost({ "I'd have liked {item:rollItem}, but {ref:winner} rolled {digits.a:winRoll} and that's how it goes.", voice = "warm" }),
        Lost({ "Good for {ref.obj:winner}: {digits.a:winRoll} took {item:rollItem}.", voice = "warm" }),
        Lost({ "{item:rollItem} went to {ref.obj:winner}, who rolled {digits.a:winRoll}. I'd rather lose to a good roll than a bad one.", voice = "warm" }),
        Lost({ "I lost the roll for {item:rollItem} with {digits.a:myRoll}, which is roughly how my luck goes.", voice = "wry" }),
        Lost({ "I lost {item:rollItem} to {ref.obj:winner}. That's rolling for you.", voice = "wry" }),
        Lost({ "I rolled {digits.a:myRoll} for {item:rollItem}. Enough said.", needs = { "myRoll<=5" }, voice = "wry" }),
        Lost({ "{item:rollItem} went to {ref.obj:winner}. My {digits:myRoll} never stood a chance against {digits.a:winRoll}{dungeon_wide}.", says = { "d.margin" }, voice = "wry" }),
        Lost({ "{ref:winner} beat me to {item:rollItem} by {dungeon_margin:wide}. Not close at all.", voice = "wry" }),
        Lost({ "Lost {item:rollItem} to {ref.obj:winner}, {digits:winRoll} to {digits:myRoll}.", says = { "d.margin" }, voice = "terse" }),
        Lost({ "{item:rollItem}: {ref:winner}, {digits:winRoll}. Me, {digits:myRoll}.", says = { "d.margin" }, voice = "terse" }),
        Lost({ "Rolled {digits:myRoll} for {item:rollItem}. Lost.", voice = "terse" }),
        Lost({ "{ref:winner} won {item:rollItem}. I hope it's a good one for {him:winner}.", needs = { "winner.sex" }, voice = "warm" }),
    },
})
