-- City trips' words: every line a trip's sheet writes, in its full form and
-- in the folded forms it takes when the leaf would overflow, the ticklist
-- row's words and the tooltips. The copy is the copywriter's, placed as
-- written (.claude/ui-proposal/city-trips-copy.md; its section numbers and
-- line ids, A1, M3, F2 ..., are given beside each key so the two can be
-- read side by side). Sheet.lua lays the lines out and decides what folds.
--
-- A line is never built from translated pieces: each is one template,
-- filled with the real values (so a locale's grammar and plural rules see
-- them), and the parts of it that are drawn differently (a name the diary
-- knows: underlined, a button to their page; a counted tail: graphite with
-- a tooltip; a sum in the purse: struck or ringed) are found again in the
-- finished text by a plain search, in the order the values were passed
-- (Sheet.lua's Runs). So a translator may reorder the placeholders freely.
--
-- CityTrips.Stops(rec, ctx, folds) gives the round as stops, in the order
-- they are drawn (see STOPS below for that order and why), each
-- { key, icon, lines = { line, ... } }. A line:
--   text    the whole line, its first letter up
--   marks   { { s = text, kind = "name" | "tail" | "struck" | "ringed",
--             guid, tip }, ... } in the order the values were passed
--   tip     a counted line's tooltip (Style.TipList's list): what it
--           merged, each in its full form
--   rank    { name, from, to }: a profession's rank line, no key (the
--           client's name for it and two figures, the pen's arrow between)
--   cross   true: the pen's cross on the thread at this line (lots back)
--   fixed   true: never dropped nor folded (the heading, the purse, a
--           rank line, what came back: the copy's §14 "Never")
-- `ctx`: { named = { [guid] = true } (the margin already names them),
-- people = CityTrips.Round's list, owner, errands = the sheet moment's
-- errands (RegisterMoment's `errand`: what other kinds offered the
-- sheet) }. `folds`: the steps of the
-- copy's §14 taken so far (Sheet.lua's FOLDS), each true.

local addonName, ns = ...

local CityTrips = ns.CityTrips
local Text = ns.UI.JourneyText
local Format = ns.UI.Format
local Style = ns.Style
local L, Fmt = ns.L, ns.Fmt
local Capital, Count, Glue, Short, Who, WORDS = Text.Capital, Text.Count, Text.Glue, Text.Short, Text.Who, Text.WORDS

--------------------------------------------------------------------------
-- Words for counts, coin and things
--------------------------------------------------------------------------

-- A count in words up to those Text.WORDS has, the figure past them
-- (§0): "one", "six", "twenty", "46".
local function Num(n)
    if n == 1 then return L["one"] end
    return WORDS[n] or tostring(n)
end
CityTrips.Num = Num

-- Coin as the diary notes it (§0, settled): Format.Money rounded to the
-- silver once there is a silver or more ("2g 80s", not "2g 80s 37c"), the
-- copper under a silver, held together so "2g" and "80s" never part
-- across a row. The purse's tooltip gives the exact sums (Exact).
local function Coin(copper)
    copper = math.max(0, math.floor((copper or 0) + 0.5))
    if copper >= 100 then copper = 100 * math.floor(copper / 100 + 0.5) end
    return Glue(Format.Money(copper))
end
local function Exact(copper)
    return Glue(Format.Money(copper or 0))
end
CityTrips.Coin, CityTrips.Exact = Coin, Exact

-- An item's name for more than one. Text.ItemWord looks at the name's last
-- word, so "Bolt of Woolen Cloth" (its last word "Cloth", not counted)
-- came out "twelve Bolt of Woolen Cloth" (the copy's §16). Text.Plural
-- already splits at " of "; here the head before " of " is asked instead,
-- where no locale gives its own (grammar.ItemWord). (24 Nov: kept here,
-- not in UI/Journey/Text/Grammar.lua, which this build may not touch; the
-- fix belongs there, for every reader, and this then goes.)
local function ItemWord(n, name)
    if n == 1 or ns.Locale.grammar.ItemWord then return Text.ItemWord(n, name) end
    local head, tail = name:match("^(.-)( of .+)$")
    if head and head ~= "" then return Text.ItemWord(n, head) .. tail end
    return Text.ItemWord(n, name)
end
CityTrips.ItemWord = ItemWord

-- An item's name as the client has it cached; nil where it has not
-- loaded yet (asked for, so the next drawing may have it).
local function ItemName(id)
    if not id then return nil end
    local C = C_Item
    local name = C and C.GetItemNameByID and C.GetItemNameByID(id)
    if (type(name) ~= "string" or name == "") and GetItemInfo then name = GetItemInfo(id) end
    if type(name) == "string" and name ~= "" then return name end
    if C and C.RequestLoadItemDataByID then pcall(C.RequestLoadItemDataByID, id) end
    return nil
end

-- An entry of an item list: its name (an invoice's own name, else the
-- client's for its id), nil for the list's `rest` and a name not loaded.
local function NameOf(e)
    if e.rest then return nil end
    return e.name or ItemName(e.id)
end

-- "one Woolen Bag", "six Woolen Bags", "twenty Linen Cloth" (§0's item).
local function Item(n, name)
    return Count(Num(n), ItemWord(n, name))
end
CityTrips.Phrase = Item

-- "one thing", "three things" (M6): how many things in a letter, or a
-- list's rest whose names are not kept.
local function Things(n)
    return ns.Plural(n, L["one thing|%s things##plural"], Num(n))
end

-- What a letter carried (M7): "two things and 50s"; things or coin alone.
local function Contents(items, coin)
    local parts = {}
    if (items or 0) > 0 then parts[#parts + 1] = Things(items) end
    if (coin or 0) > 0 then parts[#parts + 1] = Coin(coin) end
    return Text.List(parts)
end

-- A recipe's name, as the client gives its spell.
local function SpellName(id)
    local name
    if C_Spell and C_Spell.GetSpellName then name = C_Spell.GetSpellName(id) end
    if (type(name) ~= "string" or name == "") and GetSpellInfo then name = GetSpellInfo(id) end
    return type(name) == "string" and name ~= "" and name or nil
end

--------------------------------------------------------------------------
-- People
--------------------------------------------------------------------------

-- Someone on a line: their first name (Text.Short) and whether it is one
-- of the player's own characters (plain ink, no underline, no button: the
-- copy's role "own"). nil where the diary has no name for them.
local function Person(guid, ctx)
    local name = guid and Short(guid)
    if not name then return nil end
    local own = ctx.own and ctx.own[guid] ~= nil
    return name, own
end

-- A mark for `guid` named `name` on a line: a name, or nothing for one of
-- the player's own characters.
local function NameMark(marks, guid, name, own)
    if not own then marks[#marks + 1] = { s = name, kind = "name", guid = guid } end
end

-- Several people as one list ("Bram and Tabi"), and their marks.
local function Names(guids, ctx, marks)
    local names = {}
    for _, guid in ipairs(guids or {}) do
        local name, own = Person(guid, ctx)
        if name then
            names[#names + 1] = name
            NameMark(marks, guid, name, own)
        end
    end
    return names
end

-- A line, its first letter up.
local function Line(text, marks, more)
    local line = more or {}
    line.text, line.marks = Capital(text), marks or {}
    return line
end

-- A line's text for a tooltip's list: the same words, nothing marked.
local function Plain(line) return line.text end

local function Lines(list)
    local out = {}
    for _, line in ipairs(list) do out[#out + 1] = Plain(line) end
    return out
end

-- A tail after a line (J2 + F1): "Bought Silk Cloth from Koko, and five
-- other things". `n` the other kinds; `tip` what they were.
local function WithTail(head, n, tip, title)
    local tail = ns.Plural(n, L["and one other thing|and %s other things##plural"], Num(n))
    head.text = Fmt(L["%1$s, %2$s##line and the rest"], head.text, tail)
    head.marks[#head.marks + 1] = { s = tail, kind = "tail", tip = tip and title and Style.TipList(title, tip) or nil }
    return head
end

--------------------------------------------------------------------------
-- The post: what sold (its invoices), what came back, letters taken and
-- letters sent (§2 A3 to A7, §3)
--------------------------------------------------------------------------

-- One item's sales split up: a line for each buyer the diary knows (A4),
-- and what is left (how many, the coin, the strangers among the buyers).
-- The record keeps who bought and how many sold, not how many each bought
-- or paid (Kind.lua's `sold`: one invoice a sale), so a buyer the diary
-- knows is taken to have bought one, at an even share of the coin; where
-- they were the only buyer, all of it.
local BOUGHT_YOURS = L["%1$s bought your %3$s for %4$s|%1$s bought %2$s of your %3$s for %4$s##plural"]
local function Split(e, ctx)
    local name = NameOf(e)
    local n, got = e.n or 1, e.got or 0
    local known, strangers = {}, e.others or 0
    for _, guid in ipairs(e.who or {}) do
        local who, own = Person(guid, ctx)
        if who then known[#known + 1] = { guid = guid, name = who, own = own } else strangers = strangers + 1 end
    end
    local lines = {}
    if not name then return name, lines, n, got, strangers end
    local function Bought(k, many, coin)
        local marks = {}
        NameMark(marks, k.guid, k.name, k.own)
        lines[#lines + 1] = Line(ns.Plural(many, BOUGHT_YOURS, k.name, Num(many), ItemWord(many, name), Coin(coin)), marks)
    end
    if #known == 1 and strangers == 0 then
        Bought(known[1], n, got)
        return name, lines, 0, 0, 0
    end
    local each = n > 0 and got / n or 0
    for _, k in ipairs(known) do
        if n <= 0 then break end
        Bought(k, 1, each)
        n, got = n - 1, got - each
    end
    return name, lines, n, got, strangers
end

-- "…, to three strangers" (J1 + A6) after a sale, unless that step is
-- taken (§14's 9).
local function ToStrangers(text, strangers, folds)
    if strangers <= 0 or folds.soldStrangers then return text end
    return Fmt(L["%1$s, %2$s##line and who"], text,
        ns.Plural(strangers, L["to a stranger|to %s strangers##plural"], Num(strangers)))
end

-- Sales of one item, unfolded: the known buyers' lines (A4), the rest
-- after them (A5) or alone (A3), the strangers counted (A6). A list's
-- rest, its items unnamed: counted as lots (F6).
local function SoldLines(e, ctx, folds, out)
    local name, lines, left, coin, strangers = Split(e, ctx)
    for _, line in ipairs(lines) do out[#out + 1] = line end
    if left <= 0 then return end
    local text
    if not name then
        text = ns.Plural(left, L["%1$s lot sold for %2$s|%1$s lots sold for %2$s##plural"], Num(left), Coin(coin))
    elseif lines[1] then
        text = ns.Plural(left, L["One more sold for %2$s|%1$s more sold for %2$s##plural"], Num(left), Coin(coin))
    else
        text = ns.Plural(left, L["%1$s sold for %2$s|%1$s sold for %2$s##plural"], Item(left, name), Coin(coin))
    end
    out[#out + 1] = Line(ToStrangers(text, strangers, folds))
end

-- Every sale, folded (§8 F6, F7): the known buyers' lines stay (A4), the
-- rest is one line counted, its tooltip every item in full (T2).
local function SoldFolded(sold, ctx, folds, out)
    local full, kept = {}, 0
    local left, coin, strangers = 0, 0, 0
    for _, e in ipairs(sold) do
        SoldLines(e, ctx, {}, full)
        local _, lines, n, got, s = Split(e, ctx)
        for _, line in ipairs(lines) do
            out[#out + 1] = line
            kept = kept + 1
        end
        left, coin, strangers = left + n, coin + got, strangers + s
    end
    if left <= 0 then return end
    local text
    if kept > 0 then
        text = ns.Plural(left, L["One more lot sold for %2$s|%1$s more lots sold for %2$s##plural"], Num(left), Coin(coin))
    else
        text = ns.Plural(left, L["%1$s lot sold for %2$s|%1$s lots sold for %2$s##plural"], Num(left), Coin(coin))
    end
    out[#out + 1] = Line(ToStrangers(text, strangers, folds), nil, { tip = Style.TipList(L["Also sold"], Lines(full)) })
end

-- A letter taken, in full (M1 to M5): from someone the diary knows or one
-- of your own (a parcel, a letter with coin, an empty letter), or every
-- stranger's counted. nil where the step dropping it has been taken.
local function LetterIn(e, ctx, folds)
    local name, own = Person(e.from, ctx)
    local items, coin, n = e.items or 0, e.coin or 0, e.n or 1
    if name and not e.rest then
        local marks = {}
        NameMark(marks, e.from, name, own)
        if items > 0 then return Line(Fmt(L["A parcel from %1$s with %2$s"], name, Contents(items, coin)), marks) end
        if coin > 0 then return Line(Fmt(L["A letter from %1$s with %2$s"], name, Coin(coin)), marks) end
        if folds.emptyLetters then return nil end
        return Line(Fmt(L["A letter from %s"], name), marks)
    end
    if items > 0 then
        return Line(ns.Plural(n, L["A parcel from a stranger|%s parcels from strangers##plural"], Num(n)))
    end
    if coin <= 0 and folds.emptyStrangers then return nil end
    return Line(ns.Plural(n, L["A letter from a stranger|%s letters from strangers##plural"], Num(n)))
end

-- A letter sent, in full (M8 to M10).
local function LetterOut(e, ctx, folds)
    local name, own = Person(e.to, ctx)
    local items, coin, n = e.items or 0, e.coin or 0, e.n or 1
    if name and not e.rest then
        local marks = {}
        NameMark(marks, e.to, name, own)
        if items > 0 or coin > 0 then return Line(Fmt(L["Sent %1$s to %2$s"], Contents(items, coin), name), marks) end
        if folds.emptyLetters then return nil end
        return Line(Fmt(L["Sent a letter to %s"], name), marks)
    end
    if folds.emptyStrangers then return nil end
    return Line(ns.Plural(n, L["Sent a letter to a stranger|Sent %s letters to strangers##plural"], Num(n)))
end

-- Letters folded into one line (F2 + F3 taken, F4 + F5 sent): all of them
-- counted, the first sender or recipient the diary knows named with their
-- count; any second one the diary knows keeps a full line of their own
-- (a name is never folded away). `full` builds an entry's full line.
local function LettersFolded(entries, field, ctx, out, full, head, one, title)
    local total, first, firstN, rest, all = 0, nil, 0, {}, {}
    for _, e in ipairs(entries) do
        local line = full(e)
        if line then all[#all + 1] = line end
        local name, own = Person(e[field], ctx)
        if name and not e.rest and not own and not first then
            first, firstN = e, e.n or 1
            total = total + (e.n or 1)
        elseif name and not e.rest and not own then
            if line then rest[#rest + 1] = line end
        else
            total = total + (e.n or 1)
        end
    end
    if total > 0 then
        local text = ns.Plural(total, head, Num(total))
        local marks = {}
        if first then
            local name = Person(first[field], ctx)
            NameMark(marks, first[field], name, false)
            text = Fmt(L["%1$s, %2$s##line and who"], text, ns.Plural(firstN, one, Num(firstN), name))
        end
        out[#out + 1] = Line(text, marks, { tip = Style.TipList(title, Lines(all)) })
    end
    for _, line in ipairs(rest) do out[#out + 1] = line end
end

local function PostStop(rec, ctx, folds)
    local lines = {}
    local sold = rec.sold or {}
    local kinds = 0
    for _ in ipairs(sold) do kinds = kinds + 1 end
    if folds.soldFold and kinds > 1 then
        SoldFolded(sold, ctx, folds, lines)
    else
        for _, e in ipairs(sold) do SoldLines(e, ctx, folds, lines) end
    end
    if (rec.back or 0) > 0 then
        lines[#lines + 1] = Line(ns.Plural(rec.back, L["A lot came back unsold|%s lots came back unsold##plural"], Num(rec.back)),
            nil, { cross = true, fixed = true })
    end
    local letters = rec.letters or {}
    if folds.lettersFold and #letters > 0 then
        LettersFolded(letters, "from", ctx, lines, function(e) return LetterIn(e, ctx, {}) end,
            L["A letter in the post|%s letters in the post##plural"],
            L["one from %2$s|%1$s from %2$s##letters##plural"], L["In the post"])
    else
        for _, e in ipairs(letters) do lines[#lines + 1] = LetterIn(e, ctx, folds) end
    end
    local sent = rec.sent or {}
    if folds.sentOwn and #sent > 0 then
        LettersFolded(sent, "to", ctx, lines, function(e) return LetterOut(e, ctx, {}) end,
            L["Sent a letter|Sent %s letters##plural"], L["one to %2$s|%1$s to %2$s##letters##plural"], L["Sent"])
    else
        for _, e in ipairs(sent) do lines[#lines + 1] = LetterOut(e, ctx, folds) end
    end
    return lines
end

--------------------------------------------------------------------------
-- The auction house: what was bought, what was put up (§2 A1, A2, A8 to
-- A10)
--------------------------------------------------------------------------

-- A purchase in full: from someone the diary knows with or without its
-- price (A9, A10), or with nobody named (A8; a stranger seller is never
-- mentioned on a purchase, §2). A list's rest: "Bought seven things".
local function BoughtLine(e, ctx, folds)
    local name = NameOf(e)
    if not name then return Line(Fmt(L["Bought %s"], Things(e.n or 1))) end
    local item = Item(e.n or 1, name)
    local marks = {}
    local names = Names(e.who, ctx, marks)
    if names[1] then
        if folds.prices or not e.paid then
            return Line(Fmt(L["Bought %1$s from %2$s"], item, Text.List(names)), marks)
        end
        return Line(Fmt(L["Bought %1$s from %2$s for %3$s"], item, Text.List(names), Coin(e.paid)), marks)
    end
    if folds.bare or not e.paid then return Line(Fmt(L["Bought %s"], item)) end
    return Line(Fmt(L["Bought %1$s for %2$s"], item, Coin(e.paid)))
end

-- Whether a purchase names someone the diary knows (not one of your own).
local function KnownSeller(e, ctx)
    for _, guid in ipairs(e.who or {}) do
        local name, own = Person(guid, ctx)
        if name and not own then return true end
    end
    return false
end

local function AuctionStop(rec, ctx, folds)
    local lines = {}
    local bought = rec.bought or {}
    if folds.boughtFold and #bought > 1 then
        -- The first kept: a known seller's, else the most bought (§8).
        local first
        for _, e in ipairs(bought) do
            if not e.rest and NameOf(e) and KnownSeller(e, ctx) then first = e break end
        end
        if not first then
            for _, e in ipairs(bought) do
                if not e.rest and NameOf(e) and (not first or (e.n or 0) > (first.n or 0)) then first = e end
            end
        end
        local full, others, keep = {}, 0, {}
        for _, e in ipairs(bought) do
            full[#full + 1] = BoughtLine(e, ctx, {})
            if e ~= first then
                if first and not e.rest and NameOf(e) and KnownSeller(e, ctx) then
                    keep[#keep + 1] = BoughtLine(e, ctx, folds)
                else
                    others = others + 1
                end
            end
        end
        if first then
            -- (the folded line's head has no price: A10, or "Bought %s")
            local head = BoughtLine(first, ctx, { prices = true, bare = true })
            if others > 0 then WithTail(head, others, Lines(full), L["Bought"]) end
            lines[#lines + 1] = head
            for _, line in ipairs(keep) do lines[#lines + 1] = line end
        else
            -- (nothing of it named yet: as it is, rather than nothing)
            for _, e in ipairs(bought) do lines[#lines + 1] = BoughtLine(e, ctx, folds) end
        end
    else
        for _, e in ipairs(bought) do lines[#lines + 1] = BoughtLine(e, ctx, folds) end
    end
    local up = rec.up or {}
    if #up > 0 then
        local items, rest, full, total, most = {}, 0, {}, 0, nil
        for _, e in ipairs(up) do
            local name = NameOf(e)
            total = total + (e.n or 1)
            if name then
                items[#items + 1] = Item(e.n or 1, name)
                full[#full + 1] = Capital(Fmt(L["Put up %s##auction"], Item(e.n or 1, name)))
                if not most or (e.n or 0) > (most.n or 0) then most = e end
            else
                rest = rest + (e.n or 1)
                full[#full + 1] = Capital(Fmt(L["Put up %s##auction"], Things(e.n or 1)))
            end
        end
        if folds.upFold and #up > 1 and most then
            lines[#lines + 1] = Line(ns.Plural(total, L["Put up %1$s lot, most of them %2$s|Put up %1$s lots, most of them %2$s##plural"],
                Num(total), ItemWord(2, NameOf(most))), nil, { tip = Style.TipList(L["Also put up"], full) })
        elseif items[1] then
            local line = Line(Fmt(L["Put up %s##auction"], Text.List(items)))
            if rest > 0 then WithTail(line, rest) end
            lines[#lines + 1] = line
        else
            lines[#lines + 1] = Line(Fmt(L["Put up %s##auction"], Things(rest)))
        end
    end
    return lines
end

--------------------------------------------------------------------------
-- The workbench: what was made, the ranks, the recipes (§4)
--------------------------------------------------------------------------

local function WorkbenchStop(rec, ctx, folds)
    local lines = {}
    local made = rec.made or {}
    if #made > 0 then
        local items, rest, full, total, most = {}, 0, {}, 0, nil
        for _, e in ipairs(made) do
            local name = NameOf(e)
            total = total + (e.n or 1)
            if name then
                items[#items + 1] = Item(e.n or 1, name)
                full[#full + 1] = Capital(Fmt(L["Made %s"], Item(e.n or 1, name)))
                if not most or (e.n or 0) > (most.n or 0) then most = e end
            else
                rest = rest + (e.n or 1)
                full[#full + 1] = Capital(Fmt(L["Made %s"], Things(e.n or 1)))
            end
        end
        if folds.madeFold and #made > 1 and most then
            lines[#lines + 1] = Line(ns.Plural(total, L["Made %1$s thing, most of them %2$s|Made %1$s things, most of them %2$s##plural"],
                Num(total), ItemWord(2, NameOf(most))), nil, { tip = Style.TipList(L["Also made"], full) })
        elseif items[1] then
            local line = Line(Fmt(L["Made %s"], Text.List(items)))
            if rest > 0 then WithTail(line, rest) end
            lines[#lines + 1] = line
        else
            lines[#lines + 1] = Line(Fmt(L["Made %s"], Things(rest)))
        end
    end
    for _, s in ipairs(rec.skills or {}) do
        if s.name and s.from and s.to and s.to > s.from then
            lines[#lines + 1] = { text = s.name, marks = {}, rank = { name = s.name, from = s.from, to = s.to },
                fixed = true }
        end
    end
    local recipes = rec.recipes or {}
    local n = #recipes + (type(recipes.more) == "number" and recipes.more or 0)
    if n > 0 and not folds.recipesDrop then
        local names = {}
        for _, id in ipairs(recipes) do names[#names + 1] = SpellName(id) end
        if not folds.recipesFold and #names == n then
            lines[#lines + 1] = Line(ns.Plural(n, L["Learnt a new recipe, %2$s|Learnt %1$s new recipes, %2$s##plural"],
                Num(n), Text.List(names)))
        else
            lines[#lines + 1] = Line(ns.Plural(n, L["Learnt a new recipe|Learnt %s new recipes##plural"], Num(n)), nil,
                { tip = names[1] and Style.TipList(L["Recipes learnt"], names) or nil })
        end
    end
    return lines
end

--------------------------------------------------------------------------
-- Put on: a thing first put on in town and worn for good (scoped 25 Nov
-- 2026, the dossier's "Upgrades on the sheet")
--------------------------------------------------------------------------

-- Not the trip's record: the errands offered to the sheet (ctx.errands,
-- the sheet moment's, RegisterMoment's `errand`), those of kind "worn"
-- (Kind.lua's CityTrips.ERRANDS), each a line saying where it came from.
-- The item is plain words, its name out of its link (no icon: the user,
-- "No player icons"); a gift names its giver while the diary knows them,
-- underlined as every name here, and a stranger's is only "a gift". Where
-- nothing said how it came, the thing alone.
local WORN_FROM = {
    auction = L["Put on %s, off the auction house"],
    mail = L["Put on %s, from a letter"],
    vendor = L["Put on %s, from a merchant"],
    quest = L["Put on %s, a quest’s reward"],
    craft = L["Put on %s, made by hand"],
    loot = L["Put on %s, looted"],
}

local function LinkName(link)
    return type(link) == "string" and (link:match("|h%[(.-)%]|h") or link:match("%[(.-)%]")) or nil
end

local function WornLine(errand, ctx)
    local name = LinkName(errand.link)
    if not name then return nil end
    if errand.from == "trade" then
        local giver, own = Person(errand.guid, ctx)
        if giver then
            local marks = {}
            NameMark(marks, errand.guid, giver, own)
            return Line(Fmt(L["Put on %1$s, a gift from %2$s"], name, giver), marks)
        end
        return Line(Fmt(L["Put on %s, a gift"], name))
    end
    return Line(Fmt(WORN_FROM[errand.from] or L["Put on %s"], name))
end

local function WornStop(rec, ctx, folds)
    local lines = {}
    for _, errand in ipairs(CityTrips.Errands(ctx.errands, "worn")) do
        lines[#lines + 1] = WornLine(errand, ctx)
    end
    if folds.wornFold and #lines > 1 then
        -- The first that names someone kept whole, else the first; the
        -- other named ones kept too, the rest a tail with every line in
        -- its tooltip, as the purchases fold (§8).
        local first
        for _, line in ipairs(lines) do
            if not first and line.marks[1] then first = line end
        end
        first = first or lines[1]
        local keep, others = { first }, 0
        for _, line in ipairs(lines) do
            if line ~= first then
                if line.marks[1] then keep[#keep + 1] = line else others = others + 1 end
            end
        end
        if others > 0 then
            local full = Lines(lines)
            first = Line(first.text, first.marks)
            keep[1] = WithTail(first, others, full, L["Put on"])
        end
        return keep
    end
    return lines
end

--------------------------------------------------------------------------
-- Quests (§5)
--------------------------------------------------------------------------

local function Title(q) return Fmt(L["“%s”"], q.title or "?") end

local function Titles(list)
    local out = {}
    for _, q in ipairs(list) do out[#out + 1] = Title(q) end
    return Text.List(out)
end

-- A quest handed in, in full: with the people the diary knows who were on
-- it (Q2), else plain (Q1).
local function HandedLine(list, ctx)
    local marks, guids, seen = {}, {}, {}
    for _, q in ipairs(list) do
        for _, guid in ipairs(q.with or {}) do
            if not seen[guid] then seen[guid] = true guids[#guids + 1] = guid end
        end
    end
    local names = Names(guids, ctx, marks)
    if names[1] then return Line(Fmt(L["Handed in %1$s with %2$s"], Titles(list), Text.List(names)), marks) end
    return Line(Fmt(L["Handed in %s"], Titles(list)))
end

local function KnownOn(q, ctx)
    for _, guid in ipairs(q.with or {}) do
        if Person(guid, ctx) then return true end
    end
    return false
end

local function QuestStop(rec, ctx, folds)
    local lines = {}
    local handed, taken = {}, {}
    for _, q in ipairs(rec.quests or {}) do
        if q.out then handed[#handed + 1] = q else taken[#taken + 1] = q end
    end
    local tookTip
    if taken[1] then
        local full = {}
        for _, q in ipairs(taken) do full[#full + 1] = Title(q) end
        tookTip = Style.TipList(L["Quests taken"], full)
    end
    local function Took(line)
        if not taken[1] or folds.takenDrop then return line end
        local n = #taken
        local more = ns.Plural(n, L["took another|took %s more##quests##plural"], Num(n))
        line.text = Fmt(L["%1$s, %2$s##line and the rest"], line.text, more)
        line.marks[#line.marks + 1] = { s = more, kind = "tail", tip = tookTip }
        return line
    end
    if handed[1] and folds.questsFold then
        -- Q4, the first the diary knows on them (Q5), what was taken (Q6).
        local full, counts, order = {}, {}, {}
        for _, q in ipairs(handed) do
            full[#full + 1] = HandedLine({ q }, ctx).text
            for _, guid in ipairs(q.with or {}) do
                local name, own = Person(guid, ctx)
                if name and not own then
                    if not counts[guid] then order[#order + 1] = guid end
                    counts[guid] = (counts[guid] or 0) + 1
                end
            end
        end
        local n = #handed
        local text = ns.Plural(n, L["Handed in a quest|Handed in %s quests##plural"], Num(n))
        local marks = {}
        local first = order[1]
        if first then
            local name = Person(first, ctx)
            NameMark(marks, first, name, false)
            text = Fmt(L["%1$s, %2$s##line and who"], text,
                ns.Plural(counts[first], L["one with %2$s|%1$s with %2$s##quests##plural"], Num(counts[first]), name))
        end
        local line = Line(text, marks, { tip = Style.TipList(L["Quests handed in"], full) })
        if folds.takenFold then Took(line) end
        lines[#lines + 1] = line
        -- A second person the diary knows keeps a line of their own.
        for k = 2, #order do
            local guid, theirs = order[k], {}
            for _, q in ipairs(handed) do
                for _, g in ipairs(q.with or {}) do
                    if g == guid then theirs[#theirs + 1] = q end
                end
            end
            local m = {}
            local name = Person(guid, ctx)
            NameMark(m, guid, name, false)
            lines[#lines + 1] = Line(Fmt(L["Handed in %1$s with %2$s"], Titles(theirs), name), m)
        end
    elseif handed[1] then
        local plain, social = {}, {}
        for _, q in ipairs(handed) do
            if KnownOn(q, ctx) then social[#social + 1] = q else plain[#plain + 1] = q end
        end
        local first = true
        if plain[1] then
            local line = HandedLine(plain, ctx)
            if folds.takenFold then Took(line) end
            lines[#lines + 1] = line
            first = false
        end
        for _, q in ipairs(social) do
            local line = HandedLine({ q }, ctx)
            if first and folds.takenFold then Took(line) end
            first = false
            lines[#lines + 1] = line
        end
    end
    if taken[1] and not folds.takenDrop then
        if not folds.takenFold then
            lines[#lines + 1] = Line(Fmt(L["Took %s##quest"], Titles(taken)))
        elseif not handed[1] then
            lines[#lines + 1] = Line(ns.Plural(#taken, L["Took a quest|Took %s quests##plural"], Num(#taken)), nil,
                { tip = tookTip })
        end
    end
    return lines
end

--------------------------------------------------------------------------
-- People round the trip (§6): who you traded, whispered, grouped and
-- duelled with in town, read off the People rows inside the trip's span
--------------------------------------------------------------------------

-- The row kinds each clause reads, in the clauses' order. A row of a kind
-- no feature registered is simply never there.
local AROUND = {
    { key = "traded", rows = { trade = true },
      known = L["traded with %s"],
      strangers = L["traded with a stranger|traded with %s strangers##plural"],
      both = L["traded with %1$s and a stranger|traded with %1$s and %2$s strangers##plural"] },
    { key = "whispered", rows = { whisper_in = true, whisper_out = true },
      known = L["whispered with %s"],
      strangers = L["whispered with a stranger|whispered with %s strangers##plural"],
      both = L["whispered with %1$s and a stranger|whispered with %1$s and %2$s strangers##plural"] },
    { key = "grouped", rows = { group_join = true },
      known = L["grouped with %s"],
      strangers = L["grouped with a stranger|grouped with %s strangers##plural"],
      both = L["grouped with %1$s and a stranger|grouped with %1$s and %2$s strangers##plural"] },
    { key = "duelled", rows = { duel_series = true },
      known = L["duelled %s"],
      strangers = L["duelled a stranger|duelled %s strangers##plural"],
      both = L["duelled %1$s and a stranger|duelled %1$s and %2$s strangers##plural"] },
}
CityTrips.AROUND = AROUND

-- Who was round trip `rec`: { [clause key] = { guids = { ... }, strangers
-- = n } }, from the People rows the route's owner `me` wrote between the
-- trip's two ends. Someone with no name to show is counted. Nothing is
-- stored: read as the sheet is drawn, as the record's header says.
function CityTrips.Round(rec, me)
    local out, unnamed = { strangers = 0 }, {}
    local interactions = ns.db and ns.db.interactions or {}
    local guids = {}
    for guid in pairs(interactions) do guids[#guids + 1] = guid end
    table.sort(guids)
    for _, guid in ipairs(guids) do
        for _, row in ipairs(interactions[guid]) do
            if row.time and row.time >= rec.t and row.time <= (rec.to or rec.t) and (not me or row.me == nil or row.me == me) then
                for _, clause in ipairs(AROUND) do
                    if clause.rows[row.type] then
                        local list = out[clause.key] or { guids = {}, seen = {}, strangers = 0 }
                        out[clause.key] = list
                        if not list.seen[guid] then
                            list.seen[guid] = true
                            if Short(guid) then
                                list.guids[#list.guids + 1] = guid
                            else
                                list.strangers = list.strangers + 1
                                if not unnamed[guid] then
                                    unnamed[guid] = true
                                    out.strangers = out.strangers + 1
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return out
end

local function PeopleStop(rec, ctx, folds)
    local round = ctx.people or {}
    local clauses, marks, tips = {}, {}, {}
    local everyone, seen = {}, {}
    for _, clause in ipairs(AROUND) do
        local list = round[clause.key]
        if list then
            local guids = {}
            for _, guid in ipairs(list.guids) do
                if not (ctx.named and ctx.named[guid]) then guids[#guids + 1] = guid end
            end
            local count = list.strangers
            local m = {}
            local names = Names(guids, ctx, m)
            local text
            if names[1] and count > 0 then
                text = ns.Plural(count, clause.both, Text.List(names), Num(count))
            elseif names[1] then
                text = Fmt(clause.known, Text.List(names))
            elseif count > 0 then
                text = ns.Plural(count, clause.strangers, Num(count))
            end
            if text then
                tips[#tips + 1] = Capital(text)
                -- §14's 5: whispers go first, then the strangers' counts.
                local keep = not (folds.whispers and clause.key == "whispered")
                if keep and folds.strangers and count > 0 then
                    if names[1] then text = Fmt(clause.known, Text.List(names)) else keep = false end
                end
                if keep then
                    clauses[#clauses + 1] = text
                    for _, mark in ipairs(m) do marks[#marks + 1] = mark end
                end
                for _, guid in ipairs(guids) do
                    if Person(guid, ctx) and not seen[guid] then
                        seen[guid] = true
                        everyone[#everyone + 1] = guid
                    end
                end
            end
        end
    end
    if not tips[1] then return {} end
    if folds.peopleFold and everyone[1] then
        -- "With Ragna, Ysolde and 3 others": two named, the rest counted
        -- with the strangers among them (Format.OTHERS); its tooltip every
        -- clause in full (T9).
        local strangers = round.strangers or 0
        local total = #everyone + strangers
        local shown = (total <= 3 and strangers == 0) and #everyone or math.min(2, #everyone)
        local names, kept = {}, {}
        for k = 1, shown do
            local guid = everyone[k]
            local name, own = Person(guid, ctx)
            names[k] = name
            NameMark(kept, guid, name, own)
        end
        local text
        if shown == total then
            text = Text.List(names)
        else
            local head = names[1]
            for k = 2, shown do head = Fmt(L["%1$s, %2$s##list"], head, names[k]) end
            text = ns.Plural(total - shown, Format.OTHERS, head, total - shown)
        end
        return { Line(Fmt(L["With %s"], text), kept, { tip = Style.TipList(L["About town"], tips) }) }
    end
    if not clauses[1] then return {} end
    local text = clauses[1]
    for k = 2, #clauses do
        text = Fmt(k == #clauses and L["%1$s, and %2$s##list"] or L["%1$s, %2$s##list"], text, clauses[k])
    end
    return { Line(text, marks) }
end

--------------------------------------------------------------------------
-- The purse (§7): always the last stop
--------------------------------------------------------------------------

local function PurseStop(rec)
    local came, left = rec.came or 0, rec.left or rec.came or 0
    local tip = { Fmt(L["Came with %1$s at %2$s"], Exact(came), Format.Clock(rec.t)) }
    if rec.to then tip[2] = Fmt(L["Left with %1$s at %2$s"], Exact(left), Format.Clock(rec.to)) end
    tip = Style.TipList(L["Your purse"], tip)
    local a, b = Coin(came), Coin(left)
    if a == b then
        return { Line(Fmt(L["Came and went with %s"], b), { { s = b, kind = "ringed" } }, { fixed = true, purse = tip }) }
    end
    return { Line(Fmt(L["Came with %s"], a), { { s = a, kind = "struck" } }, { fixed = true, purse = tip }),
        Line(Fmt(L["Left with %s"], b), { { s = b, kind = "ringed" } }, { fixed = true, purse = tip }) }
end

--------------------------------------------------------------------------
-- The round
--------------------------------------------------------------------------

-- The stops, in the order they are drawn. The record keeps its errands by
-- kind, not by time (Kind.lua: one list a kind, merged as the trip grows),
-- so the round's order cannot be read back. It is the order a round in
-- town runs in, and the order of first visits the user signed for a heavy
-- round ("a window visited again joins its first stop", 24 Nov), every
-- window once:
--   post      the mailbox first: what sold comes there (its invoices, the
--             coin), what came back, letters from people; and the letters
--             sent, which join it (the mailbox visited again)
--   auctions  the auction house: what was bought, what was put up
--   workbench what was made, a profession's ranks, the recipes learnt
--   put on    what was put on and kept on (25 Nov 2026): after the
--             windows it may have come from (the post, the auction house,
--             the workbench), before the way out
--   quests    the quest-givers on the way out: handed in, taken
--   people    who was round the trip (no drawing: §6)
--   purse     always last, right after the last errand (the user's "purse
--             sits last")
-- Each stop's drawing (Sheet.lua's DRAWINGS): a letter, a lot's tag, the
-- hammer, a tunic, the scroll, none, a coin. A stop with nothing to write is left
-- out.
local STOPS = {
    { key = "post", icon = "cityTrips.letter", lines = PostStop },
    { key = "auctions", icon = "cityTrips.tag", lines = AuctionStop },
    { key = "workbench", icon = "hammer", lines = WorkbenchStop },
    { key = "worn", icon = "cityTrips.tunic", lines = WornStop },
    { key = "quests", icon = "scroll", lines = QuestStop },
    { key = "people", lines = PeopleStop },
    { key = "purse", icon = "cityTrips.coin", lines = PurseStop },
}
CityTrips.STOPS = STOPS

function CityTrips.Stops(rec, ctx, folds)
    ctx, folds = ctx or {}, folds or {}
    ctx.own = ctx.own or (ns.OwnCharacters and ns.OwnCharacters()) or {}
    local out = {}
    for _, stop in ipairs(STOPS) do
        local lines = {}
        for _, line in ipairs(stop.lines(rec, ctx, folds)) do
            if line then lines[#lines + 1] = line end
        end
        if lines[1] then
            -- (Sheet.lua's `wornJoin`, short of room: what was put on joins
            -- the stop before it, the window it most likely came from, its
            -- own drawing and the gap before it given up)
            local before = out[#out]
            if folds.wornJoin and stop.key == "worn" and before and before.key ~= "post" then
                for _, line in ipairs(lines) do before.lines[#before.lines + 1] = line end
            else
                out[#out + 1] = { key = stop.key, icon = stop.icon, lines = lines }
            end
        end
    end
    return out
end

--------------------------------------------------------------------------
-- The heading, the ticklist's row, a name's tooltip
--------------------------------------------------------------------------

-- The sheet's heading (§1): the city and the day as a plate's heading says
-- them (Text.PlateHeading), always naming the city: the "later" form a
-- plate on the same map writes has no city in it ("Forty minutes later"),
-- so a sheet asks without the plate before it then. Returns the line and
-- the city's name in it (underlined by the pen).
function CityTrips.Heading(plate, now, before)
    local line, zone = Text.PlateHeading(plate, now, before)
    local city = Text.MapName(plate.mapID)
    if city and not line:find(city, 1, true) then
        line, zone = Text.PlateHeading(plate, now, nil)
    end
    return line, city
end

-- How long the stay was, spoken (§1: "forty minutes"), for the heading's end.
function CityTrips.Stay(rec)
    return Text.Spoken((rec.to or rec.t) - rec.t)
end

-- The ticklist's row (K1): "Errands in town" (its time is the row's column; 28 Nov 2026, was "Errands, 38 min").
function CityTrips.Label()
    return L["Errands in town"]
end

-- Its tooltip's words (K2).
function CityTrips.Tip()
    return L["What you did in town, on half a page"]
end

-- A name's tooltip (§9): their full name, then the click's hint.
function CityTrips.NameTip(guid)
    return Style.TipList(Who(guid) or Short(guid) or "", { L["Click to open their page."] })
end
