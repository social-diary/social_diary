-- Hunts' words (JRN-26 bad luck, EXT-3 good luck): a hunt in a few words,
-- its mark's tooltip (Mark.lua), the cards' words and tooltips
-- (HuntCard.lua, LuckyCard.lua, and S on a light plate's print), the
-- level's prose (Text.RegisterLines, UI/Journey/Text/Prose.lua) and the
-- plates' caption words (Text.RegisterCaption), for bad luck (`luck`) and
-- good (`fortune`). The shared words are the core's (UI/Journey/Text/Grammar.lua's
-- exports): a figure held to its noun (Text.Count), a creature's name for
-- more than one (Text.Plural), an item's (Text.ItemWord, Text.Items), counts
-- in words (Text.NUMBER, Text.WORDS) and a tooltip's last line
-- (Text.Foot). Copy changes go through the copywriter skill, as every
-- player-read word does.

local addonName, ns = ...

local Hunts = ns.Hunts
local Text = ns.UI.JourneyText
local Capital, Count, ItemWord, Items, NUMBER, Plural, WORDS =
    Text.Capital, Text.Count, Text.ItemWord, Text.Items, Text.NUMBER, Text.Plural, Text.WORDS

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
function Hunts.Words(hunt)
    local kills = hunt.kills or 0
    local what = hunt.name and hunt.name ~= "" and (kills == 1 and hunt.name or Plural(hunt.name))
        or (kills == 1 and "kill" or "kills")
    if Kinds(hunt) > 1 and hunt.name and hunt.name ~= "" then what = what .. " and others" end
    return Count(kills, what) .. " for " .. Items(hunt.need or 0, hunt.item or "drop")
end

-- How far a hunt was from what the drop rates said (EXT-2, EXT-3): ", 14
-- more than expected", ", 54 fewer than expected"; "" where nothing was
-- expected, or it came out even.
function Hunts.ExpectedWords(hunt)
    if not hunt.expected then return "" end
    local off = math.floor((hunt.kills or 0) - hunt.expected + 0.5)
    if off == 0 then return "" end
    return ", " .. Count(math.abs(off), off > 0 and "more than expected" or "fewer than expected")
end

-- The hunt with it: "31 Plainstriders for 7 Plainstrider Meat, 14 more
-- than expected".
function Hunts.Line(hunt)
    return Hunts.Words(hunt) .. Hunts.ExpectedWords(hunt)
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
    name = name and name ~= "" and (n == 1 and name or Plural(name)) or (n == 1 and "kill" or "kills")
    return Count(n, name)
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
        lines[#lines + 1] = table.concat(parts, ", ")
    end
    if hunt.title and hunt.title ~= "" then lines[#lines + 1] = "For " .. hunt.title end
    lines[#lines + 1] = Text.Foot({ from = hunt.t, levelFrom = hunt.level }, now)
    return Hunts.Line(hunt), lines
end

-- A tooltip's last line for everything under one mark, as the core says
-- it for every mark (Text.Foot, UI/Journey/Text/Tips.lua): when, from the
-- first to the last ("Today at 12:47", "Today from 12:47 to 13:20"), then
-- the level or levels ("Level 20", "Levels 19 to 20"). `list` is records
-- with `t` and `level`.
local function Foot(list, now)
    local a = {}
    for _, r in ipairs(list) do
        if r.t then a.from, a.to = math.min(a.from or r.t, r.t), math.max(a.to or r.t, r.t) end
        if r.level then
            a.levelFrom, a.levelTo = math.min(a.levelFrom or r.level, r.level), math.max(a.levelTo or r.level, r.level)
        end
    end
    return Text.Foot(a, now)
end

-- A quest's title as the diary quotes it: “Break Sharptusk!”.
local function Quoted(title)
    return "\226\128\156" .. title .. "\226\128\157"
end

-- The kills of `hunts` by kind, summed across them, most killed first: {
-- key, n, name } (name nil for kills of no named creature).
local function KindsOf(hunts)
    local by, list = {}, {}
    local function Add(key, n, name)
        local k = by[key]
        if not k then
            k = { key = tostring(key), n = 0, name = name }
            by[key] = k
            list[#list + 1] = k
        end
        k.n = k.n + (n or 0)
    end
    for _, hunt in ipairs(hunts) do
        if Kinds(hunt) > 0 then
            for npcID, k in pairs(hunt.byKind) do Add(k.name or npcID, k.n, k.name) end
        else
            local named = hunt.name and hunt.name ~= "" and hunt.name or nil
            Add(named or "", hunt.kills, named)
        end
    end
    table.sort(list, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return a.key < b.key
    end)
    return list
end

-- What was killed, each count with its creature and "Killed" said once
-- (12 Oct, the user: no number stands bare): "Killed 31 Plainstriders",
-- "Killed 20 Plainstriders and 11 Adult Plainstriders"; past HUNT_KINDS
-- kinds the rest together, "Killed 17 Scytheclaws, 9 Lashtails and 6
-- others"; kills of no named creature are "others" beside named ones, and
-- alone "31 kills". One kill: "Dropped by the first Hezrul Bloodmark".
local TIP_KINDS = 3

local function KilledLine(hunts)
    local kinds = KindsOf(hunts)
    -- One kill, the first of them: no figure ("Killed 1 Hezrul Bloodmark"
    -- reads as a tally of one), as the prose says it (Hunts.Fortune).
    if #kinds == 1 and kinds[1].n == 1 and kinds[1].name then return "Dropped by the first " .. kinds[1].name end
    local named, rest = {}, 0
    for _, k in ipairs(kinds) do
        if k.name and #named < TIP_KINDS then named[#named + 1] = k else rest = rest + k.n end
    end
    if #named == 0 then return rest > 0 and Count(rest, rest == 1 and "kill" or "kills") or nil end
    -- Past the kinds named, the last one named joins the others.
    if rest > 0 and #named == TIP_KINDS and #kinds > TIP_KINDS then
        rest = rest + table.remove(named).n
    end
    local parts = {}
    for _, k in ipairs(named) do parts[#parts + 1] = Killed(k.n, k.name) end
    if rest > 0 then parts[#parts + 1] = Count(rest, rest == 1 and "other" or "others") end
    return "Killed " .. Text.List(parts)
end

-- How far off the drop rates the kills came, all of them together: "14
-- more kills than expected", "54 fewer kills than expected"; nil unless
-- every hunt had its rates (a sum over some would not be the whole), or
-- where it came out even.
local function OffLine(hunts)
    local off = 0
    for _, hunt in ipairs(hunts) do
        if not hunt.expected then return nil end
        off = off + (hunt.kills or 0) - hunt.expected
    end
    off = math.floor(off + 0.5)
    if off == 0 then return nil end
    return Count(math.abs(off), off > 0 and "more kills than expected" or "fewer kills than expected")
end

-- What a hunt was for, as a heading: "7 Plainstrider Meat", "Hezrul's
-- Head".
local function Wanted(hunt)
    local need, item = hunt.need or 0, hunt.item
    if not item then return need > 1 and Count(need, "drops") or "a drop" end
    return need > 1 and Count(need, ItemWord(need, item)) or item
end

-- The tooltip of a tally or a star (Mark.lua's `tips`): every hunt on the
-- mark told once together (9 Nov 2026, as a fight's stain tells its stops;
-- before, each hunt's Hunts.Tip was stacked under the last, its time
-- again each time). One hunt: what it was for, what was killed, how far
-- off the rates, the quest, when and at what level. Several: how many
-- ("Two slow hunts", `lucky`: "Two lucky hunts"), the kills summed by
-- kind, the items, how far off the rates in all, and from when to when.
-- Four lines at most.
function Hunts.Tips(hunts, now, lucky)
    local lines = {}
    local function Add(line) if line then lines[#lines + 1] = line end end
    if #hunts == 1 then
        local hunt = hunts[1]
        Add(KilledLine(hunts))
        Add(OffLine(hunts))
        if hunt.title and hunt.title ~= "" then Add("For " .. Quoted(hunt.title)) end
        Add(Foot(hunts, now))
        return Capital(Wanted(hunt)), lines
    end
    Add(KilledLine(hunts))
    local items, seen = {}, {}
    for _, hunt in ipairs(hunts) do
        local item = hunt.item or ""
        local at = seen[item]
        if at then
            items[at].need = items[at].need + (hunt.need or 0)
        else
            items[#items + 1] = { item = hunt.item, need = hunt.need or 0 }
            seen[item] = #items
        end
    end
    local wanted = {}
    for i, it in ipairs(items) do wanted[i] = Wanted(it) end
    Add("For " .. Text.List(wanted))
    local off = OffLine(hunts)
    Add(off and (off .. " in all"))
    Add(Foot(hunts, now))
    local n = NUMBER[#hunts] or WORDS[#hunts] or tostring(#hunts)
    return Capital(n .. (lucky and " lucky hunts" or " slow hunts")), lines
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
Hunts.KILLED = "killed"

-- Under the stop rule, where the drop rates said it would end:
-- "expected 12" (to the whole kill, as Hunts.ExpectedWords rounds it). Good
-- luck's card always strikes something through, and a card the player wrote
-- may give no figure: it says only what they said, "expected more", and makes
-- no number up.
function Hunts.ExpectedLabel(hunt)
    if not hunt.expected then return "expected more" end
    return "expected " .. math.floor((hunt.expected or 0) + 0.5)
end

-- The rows of a hunt without drop rates: its kills an item, "each", and
-- the character's usual, "usually"; past HuntCard's ROWS.most a figure
-- says it instead of strokes.
Hunts.EACH, Hunts.USUALLY = "each", "usually"

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
    -- "for 6" held together, as a count is.
    local function For(text) return rates and text or (text .. " " .. Count("for", need)) end
    if #kinds > 1 and not short then
        local lines = {}
        local shown = #kinds <= HUNT_KINDS and #kinds or HUNT_KINDS - 1
        for i = 1, shown do lines[i] = Hunts.KILLED .. " " .. Killed(kinds[i].n, kinds[i].name) end
        if shown < #kinds then
            local rest = 0
            for i = shown + 1, #kinds do rest = rest + kinds[i].n end
            lines[#lines + 1] = Hunts.KILLED .. " " .. Count(rest, rest == 1 and "other" or "others")
        end
        if not rates then lines[#lines] = For(lines[#lines]) end
        return lines
    end
    local others = #kinds > 1 and named
    if rates then
        if not named then return {} end
        return { Plural(hunt.name) .. (others and " and others" or "") }
    end
    local what = Killed(kills, named and hunt.name or nil) .. (others and " and others" or "")
    if not named then what = tostring(kills) end
    return { For(Hunts.KILLED .. " " .. what) }
end

-- The card's tooltip: the mark's, and without the rates the usual it is
-- set against ("Usually 2 each"), when it was known.
function Hunts.CardTip(hunt, now, usual)
    local title, lines = Hunts.Tip(hunt, now)
    if not hunt.expected and usual then
        table.insert(lines, #lines, "Usually " .. math.max(1, math.floor(usual + 0.5)) .. " each")
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
            return "The first " .. hunt.name .. " gave up its " .. (hunt.item or "drop") .. "."
        end
        local expected = math.floor(hunt.expected + 0.5)
        return "The first " .. hunt.name .. " gave up its " .. (hunt.item or "drop") .. ", where "
            .. Count(expected, "were expected") .. "."
    end
    local words = Hunts.Words(hunt):gsub(" for ", " to get ", 1)
    return "It took only " .. words .. Hunts.ExpectedWords(hunt) .. "."
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
    if kills <= 1 then return "on the first", "first" end
    local count = kills <= 10 and WORDS[kills] or Count(kills, "kills")
    return (just and "after just " or "after ") .. count, count
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
Hunts.LUCKY_DROPPED = "dropped"
local LUCKY_LINES = { XL = 2, L = 1, M1 = 1, M2 = 2, M2s = 2 }
local LUCKY_JUST = { XL = true, L = true }

function Hunts.LuckyTag(hunt, form)
    local soon, count = SoonWords(hunt, LUCKY_JUST[form])
    if form == "S" then return { { text = soon, under = count } } end
    if form == "S-" then
        if (hunt.kills or 0) <= 1 then return { { text = "the first", under = "first" } } end
        return { { text = count, under = count } }
    end
    local D = Hunts.LUCKY_DROPPED
    if LUCKY_LINES[form] == 2 then return { { text = D, under = D }, { text = soon } } end
    return { { text = D .. " " .. soon, under = D } }
end

-- Who dropped it, under the struck words at XL: "Kolkar Marauders", one
-- kill "Hezrul Bloodmark" (never "Hezrul Bloodmarks", as Hunts.KillLines
-- would say it), several kinds "Sunscale Scytheclaws and others". Nil
-- where the creature has no name.
function Hunts.LuckyKind(hunt)
    if not (hunt.name and hunt.name ~= "") then return nil end
    local name = (hunt.kills or 0) == 1 and hunt.name or Plural(hunt.name)
    return Kinds(hunt) > 1 and (name .. " and others") or name
end

-- The caption's words while the luck is told on its print (the card's S,
-- which has no heading): the item and who dropped it, the numbers left to
-- the print. "7 Kolkar Booty Keys from Kolkar Marauders"; one item,
-- "Hezrul's Head from Hezrul Bloodmark"; nameless, the item alone.
function Hunts.LuckyCaption(hunt)
    local need, item = hunt.need or 0, hunt.item or "a drop"
    local what = need > 1 and Count(need, ItemWord(need, item)) or item
    local kind = Hunts.LuckyKind(hunt)
    return kind and (what .. " from " .. kind) or what
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
        local words = Hunts.Words(h):gsub(" for ", " to get ", 1)
        parts[#parts + 1] = "It took " .. words .. Hunts.ExpectedWords(h) .. "."
    end
    local more = #hunts - COMBAT.most
    if more > 0 then
        parts[#parts + 1] = more == 1 and "And one more slow hunt." or ("And %s more slow hunts."):format(
            NUMBER[more] or tostring(more))
    end
    local fortunes = e.fortunes or {}
    for i = 1, math.min(#fortunes, COMBAT.most) do parts[#parts + 1] = Hunts.Fortune(fortunes[i]) end
    more = #fortunes - COMBAT.most
    if more > 0 then
        parts[#parts + 1] = more == 1 and "And one more lucky hunt." or ("And %s more lucky hunts."):format(
            NUMBER[more] or tostring(more))
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
        return #hunts == 1 and Hunts.Line(hunts[1]) or ((NUMBER[#hunts] or tostring(#hunts)) .. " slow hunts")
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
                or ((NUMBER[#fortunes] or tostring(#fortunes)) .. " lucky hunts") }
        end
        local words, more = {}, 0
        for _, hunt in ipairs(fortunes) do
            if hunt ~= told then more = more + 1 end
        end
        if lucky.print then words[1] = Hunts.LuckyCaption(told) end
        if more == 1 then
            words[#words + 1] = "another lucky hunt"
        elseif more > 1 then
            words[#words + 1] = (NUMBER[more] or tostring(more)) .. " more lucky hunts"
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
