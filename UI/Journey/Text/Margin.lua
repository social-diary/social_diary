-- What a person's margin note says in Your Diary (ns.UI.JourneyText): who
-- it is with (Text.MarginWho) and what happened with them on the plate
-- (Text.MarginWhat). Their note's quote is UI/Journey/Text/Notes.lua's; a
-- feature's card writes its own words (Features/<Name>/).
--
-- The module and its siblings: UI/Journey/Text/Grammar.lua.

local addonName, ns = ...

local Text = ns.UI.JourneyText
local Glue, Duration, NUMBER, Short = Text.Glue, Text.Duration, Text.NUMBER, Text.Short
local L, Fmt = ns.L, ns.Fmt

--------------------------------------------------------------------------
-- A fight, told under the one it was with (20 Nov 2026, the user)
--------------------------------------------------------------------------
--
-- Under a foe's name, or a stranger's description, the fight reads on from
-- the heading as one sentence, the foe its subject: "Mika / killed you",
-- "a level 16 Dwarf Hunter / fell to you". The first death of an evening
-- is plain, as it will be the norm; only a repeat in the same play session
-- (a sitting: Journey.SessionFights) says more: "killed you again", "killed
-- you for the third time", and then, where it fits, the spell the death
-- recap named ("killed you again, with Ambush"). Where the evening went
-- the other way too, a second sentence says so plainly, in words: "You
-- killed them once." Several fights with one person on one plate are one
-- phrase, never "killed you and killed you": both ways, in their order
-- ("killed you, then fell to you"); else the latest's count.
--
-- The words have no name in them, so a locale whose verb agrees with the
-- foe writes <they:he/she> and it is picked here by their sex (the mark's
-- description, else their record; Locale.They).

-- "time" counted in words: "for the third time" (Format.Nth; a locale's
-- ordinal agrees with its word for "time", context "time").
local NTH_TIME = { L["first##time"], L["second##time"], L["third##time"], L["fourth##time"], L["fifth##time"],
    L["sixth##time"], L["seventh##time"], L["eighth##time"], L["ninth##time"], L["tenth##time"],
    L["eleventh##time"], L["twelfth##time"], context = "time" }
Text.NTH_TIME = NTH_TIME

-- A fight's own words by how it ended and its count that evening: the
-- first plain, the second "again", the rest "for the third time"; `spell`
-- only on a repeat lost.
local FIGHT = {
    lost = { L["killed you"], L["killed you again"], L["killed you for the %s time"] },
    won = { L["fell to you"], L["fell to you again"], L["fell to you for the %s time"] },
}
local SPELL = { L["killed you again, with %s"], L["killed you for the %1$s time, with %2$s"] }

-- "once", "twice", "three times", in words up to twelve, then figures.
local function TimesSaid(n)
    if n == 2 and L["twice"] ~= "" then return L["twice"] end
    return ns.Plural(n, L["once|%s times##spoken##plural"], Text.WORDS[n] or tostring(n))
end
Text.TimesSaid = TimesSaid

-- The <they:...> forms are picked for `sex` before Fmt fills the words in:
-- Fmt settles any left to the form for no one known (Locales/Locale.lua).
local function Said(outcome, n, spell, sex)
    local function They(text) return ns.Locale.They(text, sex) end
    local words = FIGHT[outcome == "lost" and "lost" or "won"]
    if n <= 1 then return Glue(They(words[1])) end
    if outcome == "lost" and spell then
        if n == 2 then return Fmt(They(SPELL[1]), spell) end
        return Fmt(They(SPELL[2]), ns.UI.Format.Nth(n, NTH_TIME), spell)
    end
    if n == 2 then return Glue(They(words[2])) end
    return Fmt(They(words[3]), ns.UI.Format.Nth(n, NTH_TIME))
end

-- The fight moments on a plate with one person, told as one phrase, longest
-- first, each shorter one for a strip that will not hold the one before
-- (UI/Paper/Strip.lua's `whats`): with the spell, then without it. `ctx`:
-- who (the GUID they are known by, nil for a stranger the buffer has let
-- go: then plain), j (the route), index (FightIndex), sex.
function Text.FightWords(fights, ctx)
    ctx = ctx or {}
    if #fights == 0 then return {} end
    local sorted = {}
    for i, m in ipairs(fights) do sorted[i] = m end
    table.sort(sorted, function(a, b) return (a.t or 0) < (b.t or 0) end)
    local first, latest = sorted[1], sorted[#sorted]
    local both = false
    for _, m in ipairs(sorted) do
        if (m.outcome == "lost") ~= (first.outcome == "lost") then both = true end
    end
    local function They(text) return ns.Locale.They(text, ctx.sex) end
    if both then
        return { They(first.outcome == "lost" and L["killed you, then fell to you"] or L["fell to you, then killed you"]) }
    end
    local lost = latest.outcome == "lost"
    local nLost, nWon
    if ctx.who and latest.mark then nLost, nWon = ns.Journey.SessionFights(ctx.j, latest.mark, ctx.who, ctx.index) end
    -- Counted at least as many as are on the plate.
    local here = #sorted
    local same = math.max(here, (lost and nLost or nWon) or 0)
    local other = (lost and nWon or nLost) or 0
    local spell = lost and same >= 2 and ctx.who and latest.mark and ns.Journey.FightSpell(latest.mark, ctx.who) or nil
    local function Whole(phrase)
        if other <= 0 then return They(phrase) end
        return Fmt(They(lost and L["%1$s. You killed them %2$s.##fight, then the score"]
            or L["%1$s. They killed you %2$s.##fight, then the score"]), phrase, TimesSaid(other))
    end
    local list = {}
    if spell then list[#list + 1] = Whole(Said(latest.outcome, same, spell, ctx.sex)) end
    list[#list + 1] = Whole(Said(latest.outcome, same, nil, ctx.sex))
    return list
end

-- What happened with one person on one plate, for their margin note:
-- "35 min together and a note", "killed you", "first seen, and you'd meet
-- again at level 4". A stranger's note has only fights (JRN-22), or a
-- first sighting. The
-- short phrases are held together by no-break spaces as a time is ("a
-- note", "killed you"), so a strip's last line is never "note" alone
-- (10 Oct, in the client: "3 h 20 min together and a / note"); the strip
-- balances its lines as well (UI/Paper/Strip.lua's STRIP.balance). Where
-- the strip quotes their note (Text.MarginQuote), the quote says it: no
-- "a note", only the others counted ("35 min together and one more note").
-- Their fights are one phrase (Text.FightWords, `ctx` its), after what
-- you did together: "35 min together, then killed you". Returns the text
-- and the shorter ones a strip may take instead (its `whats`), or nil.
-- Whether a note's moments hold a fight, and whether they hold company:
-- time together, a note, or a feature's moment that is this person's at
-- tier 1 (something they gave you). A first sighting or a crossed path is
-- not company (20 Nov 2026).
function Text.HasFight(moments)
    for _, m in ipairs(moments) do
        if m.kind == "fight" then return true end
    end
    return false
end

function Text.HasCompany(moments)
    for _, m in ipairs(moments) do
        if m.kind == "session" or m.kind == "note" or (m.person and m.person.tier == 1) then return true end
    end
    return false
end

function Text.MarginWhat(moments, level, ctx)
    local parts, together, notes = {}, 0, 0
    for _, m in ipairs(moments) do
        if m.kind == "session" then together = together + (m.seconds or 0)
        elseif m.kind == "note" then notes = notes + 1 end
    end
    local quoted = notes > 0 and Text.MarginQuote(moments) ~= nil
    if quoted then notes = notes - 1 end
    -- A feature's moment that is this person's too (its `person`, Core/
    -- JourneyRecap.lua's RegisterMoment: say, something they gave you)
    -- first: a strip keeps STRIP.lines lines and cuts the rest, and that
    -- is what this person is remembered by here.
    -- With a fight the fight is the story: only company goes before it
    -- (a gift, tier 1), and a first sighting is not said at all (20 Nov
    -- 2026, the user dislikes long joined lines: "Mika / killed you", not
    -- "... and first seen, and you'd meet again").
    local fought = Text.HasFight(moments)
    for _, m in ipairs(moments) do
        if m.person and m.person.say and (not fought or m.person.tier == 1) then
            parts[#parts + 1] = m.person.say(m)
        end
    end
    if together > 0 then
        parts[#parts + 1] = Fmt(L["%s together"], together >= 60 and Duration(together) or L["a moment"])
    end
    if notes > 0 and quoted then
        parts[#parts + 1] = Glue(ns.Plural(notes, L["one more note|%s more notes##plural"], NUMBER[notes] or notes))
    elseif notes > 0 then
        parts[#parts + 1] = Glue(ns.Plural(notes, L["a note|%s notes##plural"], NUMBER[notes] or notes))
    end
    -- Each part after the one before, as one whole phrase: "35 min
    -- together and a note".
    local company = parts[1]
    for i = 2, #parts do company = Fmt(L["%1$s and %2$s"], company, parts[i]) end
    local fights = {}
    for _, m in ipairs(moments) do
        if m.kind == "fight" then fights[#fights + 1] = m end
    end
    local firsts = {}
    for _, m in ipairs(moments) do
        if m.kind == "first" and not fought then
            local again = m.metLevel and level and m.metLevel > level
                and Fmt(L["you'd meet again at level %d"], m.metLevel) or L["you'd meet again"]
            firsts[#firsts + 1] = Fmt(L["first seen, and %s"], again)
        end
    end
    local function Told(fight)
        local text = company
        if fight then text = text and Fmt(L["%1$s, then %2$s##company, then fight"], text, fight) or fight end
        for _, part in ipairs(firsts) do text = text and Fmt(L["%1$s and %2$s"], text, part) or part end
        return text or ""
    end
    local said = Text.FightWords(fights, ctx)
    if #said <= 1 then return Told(said[1]), nil end
    local shorter = {}
    for i = 2, #said do shorter[#shorter + 1] = Told(said[i]) end
    return Told(said[1]), shorter
end

-- The name a margin note is headed by, so the note reads as who you were
-- with: "with Koko", or "with someone" for a stranger whose name the
-- buffer no longer has.
function Text.MarginWho(guid)
    local name = guid and Short(guid)
    if not name then return L["with someone"] end
    return Fmt(L["with %s"], name)
end

-- The heading of a stranger's fight strip, whom the diary has no name for
-- (a fight moment with no guid: Journey.Fight keeps only a diary person's):
-- what they looked like, "a level 16 Dwarf Hunter", from what the mark kept
-- or the buffer's record (Text.FoeOf), with shorter forms for a narrow
-- strip; with nothing to go on, "someone" (it reads on into "killed you").
-- Returns the heading and the shorter ones.
function Text.FoeStrip(mark, index)
    local names = Text.FoeNames(Text.FoeOf(mark, index))
    if #names == 0 then return L["someone##foe"], nil end
    local shorter = {}
    for i = 2, #names do shorter[#shorter + 1] = names[i] end
    return names[1], #shorter > 0 and shorter or nil
end
