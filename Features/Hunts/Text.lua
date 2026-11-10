-- Hunts' words (JRN-26 bad luck, EXT-3 good luck): a hunt in a few words,
-- its mark's tooltip (Mark.lua), the cards' words and tooltips
-- (HuntCard.lua, LuckyCard.lua, and S on a light plate's print), the
-- level's prose (Text.RegisterLines, UI/Journey/Text/Prose.lua) and the
-- plates' caption words (Text.RegisterCaption), for bad luck (`luck`) and
-- good (`fortune`). The shared words are the core's (UI/Journey/Text/Grammar.lua's
-- exports): a figure held to its noun (Text.Count), a creature's name for
-- more than one (Text.Plural), an item's (Text.ItemWord, Text.Items), counts
-- in words (Text.NUMBER, Text.WORDS) and a tooltip's last line
-- (Text.When). Copy changes go through the copywriter skill, as every
-- player-read word does.

local addonName, ns = ...

local Hunts = ns.Hunts
local Text = ns.UI.JourneyText
local Capital, Count, Counts, ItemWord, Items, NUMBER, Plural, When, WORDS =
    Text.Capital, Text.Count, Text.Counts, Text.ItemWord, Text.Items, Text.NUMBER, Text.Plural, Text.When, Text.WORDS
local L, Fmt = ns.L, ns.Fmt

-- Kills of a creature with no name, counted: "31 kills".
local KILLS = L["%d kill|%d kills##plural"]

-- Whether a hunt's kills were of more kinds than one (EXT-2).
local function Kinds(hunt)
    local n = 0
    for _ in pairs(hunt.byKind or {}) do n = n + 1 end
    return n
end
Hunts.Kinds = Kinds

-- A hunt in a few words: "31 Plainstriders for 7 Plainstrider Meat"; "31
-- kills" when the creature has no name. Of several kinds, the one killed
-- most is named and the count is all of them: "31 Plainstriders and others
-- for 7 Plainstrider Meat" (12 Oct).
--
-- Parts: the kills and the items apart ("31 Plainstriders", "7
-- Plainstrider Meat"), for the sentences that say them in their own words.
local function Parts(hunt)
    local kills = hunt.kills or 0
    local items = Items(hunt.need or 0, hunt.item or L["drop"])
    if not (hunt.name and hunt.name ~= "") then return Counts(kills, KILLS), items end
    local what = kills == 1 and hunt.name or Plural(hunt.name)
    if Kinds(hunt) > 1 then what = Fmt(L["%s and others"], what) end
    return Count(kills, what), items
end

function Hunts.Words(hunt)
    return Fmt(L["%1$s for %2$s"], Parts(hunt))
end

-- How far a hunt was from what the drop rates said (EXT-2, EXT-3): "14
-- more than expected", "54 fewer than expected"; "" where nothing was
-- expected, or it came out even.
function Hunts.ExpectedWords(hunt)
    if not hunt.expected then return "" end
    local off = math.floor((hunt.kills or 0) - hunt.expected + 0.5)
    if off == 0 then return "" end
    return Counts(math.abs(off), off > 0 and L["%d more than expected|%d more than expected##plural"]
        or L["%d fewer than expected|%d fewer than expected##plural"])
end

-- The hunt with it: "31 Plainstriders for 7 Plainstrider Meat, 14 more
-- than expected".
function Hunts.Line(hunt)
    local expected = Hunts.ExpectedWords(hunt)
    if expected == "" then return Hunts.Words(hunt) end
    return Fmt(L["%1$s, %2$s"], Hunts.Words(hunt), expected)
end

-- A hunt's kinds, most killed first: { id, n, name }; empty with one kind.
local function SortedKinds(hunt)
    local kinds = {}
    if Kinds(hunt) <= 1 then return kinds end
    for npcID, k in pairs(hunt.byKind) do kinds[#kinds + 1] = { id = npcID, n = k.n or 0, name = k.name } end
    table.sort(kinds, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return a.id < b.id
    end)
    return kinds
end

-- `n` of a creature: "17 Sunscale Scytheclaws", "a kill" kept as "1 kill".
local function Killed(n, name)
    if not (name and name ~= "") then return Counts(n, KILLS) end
    return Count(n, n == 1 and name or Plural(name))
end

-- Its mark's tooltip: the words, each kind's own kills where there were
-- several ("20 Plainstriders, 11 Elder Plainstriders"), the quest it was
-- for, when.
function Hunts.Tip(hunt, now)
    local lines = {}
    local kinds = SortedKinds(hunt)
    if #kinds > 0 then
        local parts = {}
        for _, k in ipairs(kinds) do parts[#parts + 1] = Killed(k.n, k.name) end
        lines[#lines + 1] = ns.UI.TimelineText.Join(parts)
    end
    if hunt.title and hunt.title ~= "" then lines[#lines + 1] = Fmt(L["For %s"], hunt.title) end
    lines[#lines + 1] = When(hunt.t, hunt.level, now)
    return Hunts.Line(hunt), lines
end

-- The hunt card (HuntCard.lua, JRN-26): bad luck written out in the
-- margin, its tally at length. Words for the card, the ledger's: figures,
-- "killed" said with each count so no number stands bare (12 Oct, the
-- user: "what does 36 mean?").
--
-- Its heading, in the hand: the item, as many as the quest wanted ("Intact
-- Raptor Horns", "Plainstrider Meat"; "Hezrul's Head" for one).
function Hunts.Item(hunt)
    return ItemWord(hunt.need or 0, hunt.item or "?")
end

-- The figure at the tally's end, in the hand: "26", then "killed".
Hunts.KILLED = L["killed"]

-- Under the stop rule, where the drop rates said it would end:
-- "expected 12" (to the whole kill, as Hunts.ExpectedWords rounds it). Good
-- luck's card always strikes something through, and a card the player wrote
-- may give no figure: it says only what they said, "expected more", and makes
-- no number up.
function Hunts.ExpectedLabel(hunt)
    if not hunt.expected then return L["expected more"] end
    return Fmt(L["expected %d"], math.floor((hunt.expected or 0) + 0.5))
end

-- The rows of a hunt without drop rates: its kills an item, "each", and
-- the character's usual, "usually"; past HuntCard's ROWS.most a figure
-- says it instead of strokes.
Hunts.EACH, Hunts.USUALLY = L["each"], L["usually"]

-- The lines under the tally, by kind, most killed first: with the drop
-- rates, "killed 17 Sunscale Scytheclaws", "killed 9 Sunscale Lashtails"
-- (one kind: its name alone, "Sunscale Scytheclaws", as the figure counts
-- them already); without, "killed 37 Defias Rogue Wizards for 6". Past
-- HUNT_KINDS kinds, the rest together, "killed 4 others". `short`: one
-- line, the kind most killed "and others" ("Sunscale Scytheclaws and
-- others"; without the rates, "killed 37 Defias Rogue Wizards and others
-- for 6"). A list, maybe empty.
local HUNT_KINDS = 3

function Hunts.KillLines(hunt, short)
    local kills, need = hunt.kills or 0, hunt.need or 0
    local named = hunt.name and hunt.name ~= ""
    local kinds = SortedKinds(hunt)
    local rates = hunt.expected ~= nil
    -- "killed 17 Sunscale Scytheclaws"; the last line without the rates
    -- with "for 6" after it, held together (a no-break space), as a count is.
    local function Line(what, last)
        if last and not rates then return Fmt(L["killed %1$s for\194\160%2$d"], what, need) end
        return Fmt(L["killed %s"], what)
    end
    if #kinds > 1 and not short then
        local whats = {}
        local shown = #kinds <= HUNT_KINDS and #kinds or HUNT_KINDS - 1
        for i = 1, shown do whats[i] = Killed(kinds[i].n, kinds[i].name) end
        if shown < #kinds then
            local rest = 0
            for i = shown + 1, #kinds do rest = rest + kinds[i].n end
            whats[#whats + 1] = Counts(rest, L["%d other|%d others##plural"])
        end
        local lines = {}
        for i, what in ipairs(whats) do lines[i] = Line(what, i == #whats) end
        return lines
    end
    local others = #kinds > 1 and named
    if rates then
        if not named then return {} end
        return { others and Fmt(L["%s and others"], Plural(hunt.name)) or Plural(hunt.name) }
    end
    local what = Killed(kills, named and hunt.name or nil)
    if others then what = Fmt(L["%s and others"], what) end
    if not named then what = tostring(kills) end
    return { Line(what, true) }
end

-- The card's tooltip: the mark's, and without the rates the usual it is
-- set against ("Usually 2 each"), when it was known.
function Hunts.CardTip(hunt, now, usual)
    local title, lines = Hunts.Tip(hunt, now)
    if not hunt.expected and usual then
        table.insert(lines, #lines, Fmt(L["Usually %d each"], math.max(1, math.floor(usual + 0.5))))
    end
    return title, lines
end

-- A hunt that was good luck in a sentence (EXT-3): "It took only 4
-- Plainstriders to get 7 Plainstrider Meat, 54 fewer than expected."; one
-- item off the first kill, "The first Plainstrider gave up its Sharptalon's
-- Claw, where 10 were expected."
function Hunts.Fortune(hunt)
    if hunt.kills == 1 and hunt.need == 1 and hunt.name and hunt.name ~= "" and Kinds(hunt) <= 1 then
        -- One the player wrote may have no figure to set it against.
        if not hunt.expected then
            return Fmt(L["The first %1$s gave up its %2$s."], hunt.name, hunt.item or L["drop"])
        end
        local expected = math.floor(hunt.expected + 0.5)
        return Fmt(L["The first %1$s gave up its %2$s, where %3$s."], hunt.name, hunt.item or L["drop"],
            Counts(expected, L["%d was expected|%d were expected##plural"]))
    end
    local kills, items = Parts(hunt)
    local expected = Hunts.ExpectedWords(hunt)
    if expected == "" then return Fmt(L["It took only %1$s to get %2$s."], kills, items) end
    return Fmt(L["It took only %1$s to get %2$s, %3$s."], kills, items, expected)
end

-- The lucky card (LuckyCard.lua, JRN-27): good luck in the margin, the
-- drop tables' "expected 58" printed and scribbled out, and taped over it
-- a smaller slip in the diary's hand saying what happened instead. The
-- printed words are Hunts.ExpectedLabel's, as the bad-luck card's.
--
-- How soon it dropped, in the hand: "after just four", "after four";
-- off one kill, "on the first"; past ten a figure with its noun, so no
-- figure stands bare (12 Oct, the user: "what does 36 mean?"), "after
-- just 14 kills". `just` carries the surprise where there is room for it.
-- Returns the words and the count's own words (for the underline at S).
local function SoonWords(hunt, just)
    local kills = hunt.kills or 0
    if kills <= 1 then return L["on the first"], L["first##on the first"] end
    local count = kills <= 10 and WORDS[kills] or Counts(kills, KILLS)
    return Fmt(just and L["after just %s"] or L["after %s"], count), count
end

-- The tag's lines for one of the card's forms (LuckyCard's FORMS): a list
-- of { text, under }, `under` the words the hand underlined in it.
--   XL      "dropped" / "after just four" (two lines, beside the struck words)
--   L       "dropped after just four"
--   M1      "dropped after four"
--   M2      "dropped" / "after four"
--   S       on a light plate's print: "after four", the count underlined
--   S-      the count alone, "four"; off one kill "the first"
-- One kill is "on the first" in every size but S-.
Hunts.LUCKY_DROPPED = L["dropped"]
local LUCKY_LINES = { XL = 2, L = 1, M1 = 1, M2 = 2, M2s = 2 }
local LUCKY_JUST = { XL = true, L = true }

function Hunts.LuckyTag(hunt, form)
    local soon, count = SoonWords(hunt, LUCKY_JUST[form])
    if form == "S" then return { { text = soon, under = count } } end
    if form == "S-" then
        if (hunt.kills or 0) <= 1 then return { { text = L["the first"], under = L["first##the first"] } } end
        return { { text = count, under = count } }
    end
    local D = Hunts.LUCKY_DROPPED
    if LUCKY_LINES[form] == 2 then return { { text = D, under = D }, { text = soon } } end
    return { { text = Fmt(L["%1$s %2$s"], D, soon), under = D } }
end

-- Who dropped it, under the struck words at XL: "Kolkar Marauders", one
-- kill "Hezrul Bloodmark" (never "Hezrul Bloodmarks", as Hunts.KillLines
-- would say it), several kinds "Sunscale Scytheclaws and others". Nil
-- where the creature has no name.
function Hunts.LuckyKind(hunt)
    if not (hunt.name and hunt.name ~= "") then return nil end
    local name = (hunt.kills or 0) == 1 and hunt.name or Plural(hunt.name)
    return Kinds(hunt) > 1 and Fmt(L["%s and others"], name) or name
end

-- The caption's words while the luck is told on its print (the card's S,
-- which has no heading): the item and who dropped it, the numbers left to
-- the print. "7 Kolkar Booty Keys from Kolkar Marauders"; one item,
-- "Hezrul's Head from Hezrul Bloodmark"; nameless, the item alone.
function Hunts.LuckyCaption(hunt)
    local need, item = hunt.need or 0, hunt.item or L["a drop"]
    local what = need > 1 and Count(need, ItemWord(need, item)) or item
    local kind = Hunts.LuckyKind(hunt)
    return kind and Fmt(L["%1$s from %2$s"], what, kind) or what
end

-- The level's luck in its prose: each hunt that was bad luck ("It took
-- 31 Plainstriders to get 7 Plainstrider Meat, 14 more than expected."),
-- then each that was good (Hunts.Fortune), at most `most` of each, the rest
-- counted. Nil with none. Told in the fights' paragraph, after the close
-- calls (its `run`, "combat", below).
local COMBAT = { most = 2 }

function Hunts.Lines(e)
    local parts = {}
    local hunts = e.hunts or {}
    for i = 1, math.min(#hunts, COMBAT.most) do
        local h = hunts[i]
        local kills, items = Parts(h)
        local expected = Hunts.ExpectedWords(h)
        parts[#parts + 1] = expected == "" and Fmt(L["It took %1$s to get %2$s."], kills, items)
            or Fmt(L["It took %1$s to get %2$s, %3$s."], kills, items, expected)
    end
    local more = #hunts - COMBAT.most
    if more > 0 then
        parts[#parts + 1] = Fmt(L["And %s.##more"], ns.Plural(more,
            L["one more slow hunt|%s more slow hunts##plural"], NUMBER[more] or tostring(more)))
    end
    local fortunes = e.fortunes or {}
    for i = 1, math.min(#fortunes, COMBAT.most) do parts[#parts + 1] = Hunts.Fortune(fortunes[i]) end
    more = #fortunes - COMBAT.most
    if more > 0 then
        parts[#parts + 1] = Fmt(L["And %s.##more"], ns.Plural(more,
            L["one more lucky hunt|%s more lucky hunts##plural"], NUMBER[more] or tostring(more)))
    end
    if #parts == 0 then return nil end
    return table.concat(parts, " ")
end

--------------------------------------------------------------------------
-- In the level's prose (Text.RegisterLines)
--------------------------------------------------------------------------

-- Bad luck, then good luck with a quest's drops (JRN-26, EXT-3): in the
-- fights' paragraph (the run "combat"), running on after a kind before it
-- there (the close calls', 70), or starting it where none had anything
-- to say.
Text.RegisterLines("hunts", { at = 75, run = "combat", lines = function(e) return Hunts.Lines(e) end })

--------------------------------------------------------------------------
-- On a plate (Text.RegisterCaption)
--------------------------------------------------------------------------

-- Bad luck with a quest's drops (JRN-26): after the close calls, or
-- leading where nothing above does: "31 Plainstriders for 7 Plainstrider
-- Meat, 14 more than expected", "two slow hunts". `said.luck` is the hunt
-- whose card (HuntCard.lua) is beside the plate: its words are on the
-- card, so they leave the caption, and any other slow hunt is said as
-- before. `said.lucks` is the same for the cards the player changed or wrote,
-- a set, as there may be several.
do
    local function Hunted(hunts)
        return #hunts == 1 and Hunts.Line(hunts[1])
            or ns.Plural(#hunts, L["%s slow hunt|%s slow hunts##plural"], NUMBER[#hunts] or tostring(#hunts))
    end
    Text.RegisterCaption("luck", {
        moment = "luck",
        take = function(m, said)
            if m.hunt and m.hunt ~= said.luck and not (said.lucks and said.lucks[m.hunt]) then return m.hunt end
            return nil
        end,
        lead = { at = 70, say = function(hunts) return Capital(Hunted(hunts)) end },
        tail = { at = 60, say = Hunted },
    })
end

-- Good luck with a quest's drops (EXT-3), a list after the slow hunts: "4
-- Plainstriders for 7 Plainstrider Meat, 54 fewer than expected", "two
-- lucky hunts". `said.fortune` is { hunt, print }, the good luck told
-- beside the plate (LuckyCard.lua). On a margin card its words leave
-- the caption, and any other lucky hunt is counted, not told ("another
-- lucky hunt", "two more lucky hunts"): told whole, the second would make
-- the words longer because a card showed. On a light plate's print
-- (`print`: the card's S, no heading) the words name the item and who
-- dropped it, the print how it went (Hunts.LuckyCaption). Leading, it says
-- the first of these, and the rest in its place in the tail. `said.fortunes`,
-- a set, is the cards the player changed or wrote that are in the margin: they
-- say their own words, so these are not counted among the rest either.
do
    local function Lucky(fortunes, c)
        local lucky = c.said.fortune
        local told = lucky and lucky.hunt
        if not told then
            return { #fortunes == 1 and Hunts.Line(fortunes[1])
                or ns.Plural(#fortunes, L["%s lucky hunt|%s lucky hunts##plural"], NUMBER[#fortunes] or tostring(#fortunes)) }
        end
        local words, more = {}, 0
        for _, hunt in ipairs(fortunes) do
            if hunt ~= told then more = more + 1 end
        end
        if lucky.print then words[1] = Hunts.LuckyCaption(told) end
        if more > 0 then
            words[#words + 1] = ns.Plural(more, L["another lucky hunt|%s more lucky hunts##plural"],
                NUMBER[more] or tostring(more))
        end
        return words
    end
    Text.RegisterCaption("fortune", {
        moment = "fortune",
        take = function(m, said)
            if said.fortunes and said.fortunes[m.hunt] then return nil end
            return m.hunt
        end,
        lead = { at = 80, say = function(fortunes, c)
            local words = Lucky(fortunes, c)
            if #words == 0 then return nil end
            local rest = {}
            for k = 2, #words do rest[#rest + 1] = words[k] end
            return Capital(words[1]), rest
        end },
        tail = { at = 70, say = Lucky },
    })
end
