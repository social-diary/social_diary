-- The translations (Locales/Locale.lua): the lookup, the positional
-- placeholders, and every locale against the keys the code uses
-- (Dev/Locale/extract.lua reads them from the source). A whole run under a
-- locale is `luajit tests/run.lua --locale <id>` (deDE, ...).

local T = ...
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local Extract = assert(loadfile("Dev/Locale/extract.lua"))("--lib")

Section("the lookup")
Eq(ns.L["Not a key anyone wrote"], "Not a key anyone wrote", "a missing key is not its own English")
Eq(ns.L["May##short"], "May", "a key's context shows in the English")
Eq(ns.Fmt("%2$s, %1$s", "a", "b"), "b, a", "positional placeholders are not reordered")
Eq(ns.Fmt("%1$d%% of %2$s", 6, "x"), "6% of x", "%% inside a positional template")
Eq(ns.Fmt("%d h %02d", 1, 5), "1 h 05", "a plain template")
Eq(ns.T("%d min", 5), "5 min", "ns.T fills its key")

Section("plurals")
local FIGHTS = ns.L["a fight|%d fights##plural"]
Eq(FIGHTS, "a fight|%d fights", "a plural key's English is its forms")
Eq(ns.Plural(1, FIGHTS), "a fight", "1 takes the first form")
Eq(ns.Plural(0, FIGHTS), "0 fights", "0 takes the other in English")
Eq(ns.Plural(7, FIGHTS), "7 fights", "the count fills the form")
Eq(ns.Plural(2, "%1$s won %2$d|%1$s won %2$d", "Thex", 2), "Thex won 2", "values after the text fill it")
Eq(ns.Plural(5, "only one"), "only one", "fewer forms than the rule: the last there is")

-- The rules the target languages take (CLDR, integers). A locale's
-- grammar.PluralForm is checked against its row when its files land.
-- French and Spanish have a third CLDR category, "many", for whole
-- millions; no count in the diary reaches it, so it is left out on purpose.
local RULES = {
    enUS = { forms = 2, [0] = 2, [1] = 1, [2] = 2, [5] = 2, [11] = 2, [21] = 2, [101] = 2 },
    deDE = { forms = 2, [0] = 2, [1] = 1, [2] = 2, [5] = 2, [11] = 2, [21] = 2, [101] = 2 },
    esES = { forms = 2, [0] = 2, [1] = 1, [2] = 2, [5] = 2, [11] = 2, [21] = 2, [101] = 2 },
    esMX = { forms = 2, [0] = 2, [1] = 1, [2] = 2, [5] = 2, [11] = 2, [21] = 2, [101] = 2 },
    -- French takes the singular for 0 as for 1, so CLDR's "one" is two
    -- numbers and could never leave the count out ("une fois"). The diary
    -- splits it: 1 alone, then 0 (singular, with its count: "0 combat"),
    -- then the rest.
    frFR = { forms = 3, [0] = 2, [1] = 1, [2] = 3, [5] = 3, [11] = 3, [21] = 3, [101] = 3 },
    ruRU = { forms = 3, [0] = 3, [1] = 1, [2] = 2, [4] = 2, [5] = 3, [11] = 3, [12] = 3, [14] = 3,
             [21] = 1, [22] = 2, [25] = 3, [101] = 1, [111] = 3, [112] = 3 },
}
local function RuleHolds(G, rule, who)
    Eq(G.PLURAL_FORMS, rule.forms, who .. " has the right number of plural forms")
    for n, want in pairs(rule) do
        if n ~= "forms" then Eq(G.PluralForm(n), want, ("%s: %d takes form %d"):format(who, n, want)) end
    end
end
RuleHolds(ns.Locale.grammar, RULES.enUS, "the English rule")

-- Whether a locale's first form is for the number 1 alone: only then may a
-- form leave the number out ("a fight").
local function OneAlone(G)
    for n = 0, 200 do if n ~= 1 and G.PluralForm(n) == 1 then return false end end
    return true
end

Section("zones and dungeons")
Eq(ns.ZoneIn(nil, "The Barrens"), "in The Barrens", "a zone takes 'in' by default")
Eq(ns.ZoneIn(nil, "Durotar", "from"), "from Durotar", "a role picks the preposition")
Eq(ns.DungeonIn(36, "The Deadmines", "into"), "into The Deadmines", "a dungeon the same way")
do
    local G = ns.Locale.grammar
    local zones, place = G.ZONES, G.PLACE
    G.ZONES = { [1413] = { ["in"] = "im Brachland" } }
    G.PLACE = { ["in"] = "in %s" }
    Eq(ns.ZoneIn(1413, "Brachland"), "im Brachland", "a locale's own phrase for a zone")
    Eq(ns.ZoneIn(1411, "Durotar"), "in Durotar", "else the locale's default")
    Eq(ns.ZoneIn(1413, "Brachland", "near"), "near Brachland", "a role a locale left out falls back to English")
    G.ZONES, G.PLACE = zones, place
end

do
    local G = ns.Locale.grammar
    local zones, place = G.ZONES, G.PLACE
    -- A phrase may be a function of the bare name: a preposition that
    -- contracts or elides with what follows.
    G.PLACE = {
        ["in"] = "en %s",
        from = function(name) return (name:gsub("^El ", "del ", 1)) end,
    }
    G.ZONES = { [1413] = { near = function(name) return "cerca de " .. name end } }
    Eq(ns.ZoneIn(nil, "El Cruce", "from"), "del Cruce", "a locale's default as a function")
    Eq(ns.ZoneIn(1413, "Los Baldíos", "near"), "cerca de Los Baldíos", "a zone's own as a function")
    Eq(ns.ZoneIn(nil, "Durotar"), "en Durotar", "a text beside them still fills")
    local function And(names) return table.concat(names, " y ") end
    Eq(ns.ZonesIn({ "Mulgore", "Durotar" }, "in", And), "en Mulgore y Durotar", "a list after one preposition")
    G.EACH_PLACE = true
    Eq(ns.ZonesIn({ "Mulgore", "Durotar" }, "in", And), "en Mulgore y en Durotar", "or one for every name")
    G.ZONES, G.PLACE, G.EACH_PLACE = zones, place, nil
end

Section("the grammar hooks")
do
    local G, Format = ns.Locale.grammar, ns.UI.Format
    local noon = os.time({ year = 2026, month = 10, day = 1, hour = 18, min = 5 })
    Eq(Format.Day(1), "1", "a date's day is the figure")
    Eq(Format.Day(25, true), "25th", "and an ordinal where the English says one")
    Eq(Format.Clock(noon), "18:05", "the clock")
    Eq(Format.Decimal(3.24, 1), "3.2", "a decimal")
    Eq(Format.Pad("sí", 3), "sí ", "padding counts characters, not bytes")
    Eq(Format.Pad("off", 3), "off", "nothing to add at the width")
    Eq(Format.Ordinal(13, "death"), "13th", "English ordinals take no noun")
    Eq(Format.List({ "Ana", "Inés" }), "Ana and Inés", "the list's own and")
    local _, dated = Format.Ago(noon, noon + 400 * 86400)
    Eq(dated, true, "Ago says when its answer is a date")
    Eq(select(2, Format.Ago(noon, noon + 3 * 86400)), nil, "and not when it is words")

    G.Day = function(n) return n == 1 and "1er" or tostring(n) end
    G.Clock = function(h, m) return ("%d h %02d"):format(h, m) end
    G.DECIMAL = ","
    G.Ordinal = function(n, context) return n .. (context == "death" and ".ª" or ".º") end
    G.ListEnd = function(head, last) return head .. (last:find("^I") and " e " or " y ") .. last end
    G.Agree = function(text) return (text:gsub("deux<f>", "deux (f)")) end
    Eq(Format.Day(1), "1er", "a locale's day")
    Eq(Format.Day(1, true), "1er", "for the sitting label too")
    Eq(Format.Clock(noon), "18 h 05", "a locale's clock")
    Eq(Format.Decimal(3.24, 1), "3,2", "a locale's decimal mark")
    Eq(Format.Nth(13, { "first", context = "death" }), "13.ª", "an ordinal past its words takes the list's noun")
    Eq(Format.Nth(13, Format.NTH_MATCH), "13.º", "a match's")
    Eq(Format.List({ "Ana", "Inés" }), "Ana e Inés", "a locale joins the last name")
    Eq(ns.Fmt("%s<f> morts", "deux"), "deux (f) morts", "Agree passes over a filled template")
    Eq(ns.Plural(2, "une mort|%s<f> morts", "deux"), "deux (f) morts", "a plural form too")
    G.Day, G.Clock, G.DECIMAL, G.Ordinal, G.ListEnd, G.Agree = nil, nil, nil, nil, nil, nil
end

Section("a person's gender")
do
    local Locale, Format = ns.Locale, ns.UI.Format
    Eq(Locale.Gender("убил/убила", 2), "убил", "he")
    Eq(Locale.Gender("убил/убила", 3), "убила", "she")
    Eq(Locale.Gender("убил/убила", nil), "убил", "not known: the first of two")
    Eq(Locale.Gender("убил/убила/убивает", nil), "убивает", "or the third, where the words give one")
    Eq(Locale.Gender("убил/убила/убивает", 1), "убивает", "the game's 'unknown' too")
    Eq(ns.Fmt("%1$s <1:he/she> x", "Numa"), "Numa <1:he/she> x", "no template is searched before a locale has a form")

    Locale.gendered = true
    Locale.Says("Numa", 3)
    Locale.Says("Brakk", 2)
    Eq(ns.Fmt("%1$s <1:убил/убила> %2$s", "Numa", "Brakk"), "Numa убила Brakk", "by the first value's character")
    Eq(ns.Fmt("%1$s, <2:спасён/спасена>: %2$s", "Numa", "Brakk"), "Numa, спасён: Brakk", "by the second's")
    Eq(ns.Fmt("%s <1:убил/убила>", "|cffffd100Numa|r"), "|cffffd100Numa|r убила", "a name in colour is still its name")
    Eq(ns.Fmt("%s <1:убил/убила/убивает>", "Someone"), "Someone убивает", "a name no record gave")
    Eq(ns.Plural(2, "%2$s <2:умер/умерла> раз|%2$s <2:умер/умерла> %1$d раза", 2, "Numa"), "Numa умерла 2 раза",
        "inside a plural form: the forms are split by a slash, not the plural's bar")
    Locale.Says("Numa", 2)
    Eq(ns.Fmt("%s <1:убил/убила>", "Numa"), "Numa убил", "of two with one name, the one just named")

    -- The reader: the character playing.
    local was = _G.UnitSex
    _G.UnitSex = function() return 3 end
    Eq(Format.You(nil, "{ты} <you:погиб/погибла>"), "ты погибла", "the reader's forms, by the character playing")
    _G.UnitSex = function() return 2 end
    Eq(Format.You(nil, "{ты} <you:погиб/погибла>"), "ты погиб", "he")
    _G.UnitSex = was
    Eq(Locale.You("<you:погиб/погибла/—>", nil), "—", "the reader's sex not known")
    Eq(Locale.They("<they:спас/спасла> тебя", 3), "спасла тебя", "words about one character, picked by the code")
    Eq(ns.Fmt("%s <they:спас/спасла/спасает> тебя", "Numa"), "Numa спасает тебя", "a <they> no code picked takes no one's form")
    Locale.gendered = false
end

local keys, order = Extract.Keys(".")
local en = Extract.Locale(".", "enUS")
local function IsPlural(k) return k:find("##plural$") ~= nil end

-- A plural key's placeholders, as its "other" (last) form takes them.
local function PluralSignature(k)
    local forms = ns.Locale.Forms(ns.Locale.English(k))
    return (Extract.Signature(forms[#forms])), Extract.PositionalOf(forms[#forms])
end

-- WoW's own "|" escapes, which a plural value can't hold: colour, textures,
-- links, atlases, the client's own plural (|4).
local function Escaped(text)
    return text:find("|c%x%x%x%x%x%x%x%x") or text:find("|cn") or text:find("|r") or text:find("|T.-|t")
        or text:find("|H.-|h") or text:find("|A:") or text:find("|K") or text:find("|n") or text:find("|4")
end

-- Whether signature `part` takes only values `whole` takes ("2d" of
-- "1d,2d"): the form for exactly 1 may leave the count out and keep the
-- rest ("Took a quest, handed in %2$d").
local function Within(part, whole)
    local has = {}
    for v in whole:gmatch("[^,]+") do has[v] = true end
    for v in part:gmatch("[^,]+") do if not has[v] then return false end end
    return true
end

Section("plural keys")
local badKey = {}
for _, k in ipairs(order) do
    if IsPlural(k) then
        local forms = ns.Locale.Forms(ns.Locale.English(k))
        local sig = PluralSignature(k)
        local ok = #forms == 2 and not Escaped(k) and sig ~= ""
        for i, f in ipairs(forms) do
            local s = Extract.Signature(f)
            if s ~= sig and not (i == 1 and Within(s, sig)) then ok = false end
        end
        if not ok then badKey[#badKey + 1] = k end
    end
end
-- No fragments: a key is a whole unit. One with a space at an edge is
-- glued to something; a bare preposition or conjunction means nothing alone.
local BARE = {}
for w in ("for to in from at with on near of by and or into through around over than"):gmatch("%S+") do
    BARE[w] = true
end
-- The prepositions a zone phrase brings itself. "to", "from" and "at" are
-- left out: "died to %s" and "level %s to %s" name no place. ADVERB keys
-- keep a word that belongs to the verb ("flew in", then "from Durotar").
local PLACE_WORDS = { "in", "into", "through", "near", "around", "round" }
local ADVERB = { ["Flew in %s##zone"] = true, ["Flew in %1$s %2$s##zone"] = true }
-- A context that marks a word as a whole unit on screen: "on##switch" is a
-- status (on / off), not the preposition; "to##score" stands alone between
-- two rows of drawn pennants (UI/Journey/Match.lua).
local WHOLE = { switch = true, score = true }
local edged, bare, glued = {}, {}, {}
for _, k in ipairs(order) do
    local text = ns.Locale.English(k)
    if text:find("^%s") or text:find("%s$") then edged[#edged + 1] = ("%q (%s)"):format(k, keys[k]) end
    if BARE[text:lower()] and not WHOLE[k:match("##(.*)$") or ""] then bare[#bare + 1] = ("%q (%s)"):format(k, keys[k]) end
    if k:find("##zone") and not ADVERB[k] then
        for _, word in ipairs(PLACE_WORDS) do
            if text:find("%f[%a]" .. word .. " %%%d*%$?s") then glued[#glued + 1] = k; break end
        end
    end
end
Check(#edged == 0, "keys that begin or end with a space are fragments; write the whole sentence: "
    .. table.concat(edged, " | "))
Check(#bare == 0, "keys that are a bare preposition or conjunction are fragments: " .. table.concat(bare, " | "))
Check(#glued == 0, "a ##zone key takes the whole phrase (ns.ZoneIn / ns.DungeonIn), not a preposition before it: "
    .. table.concat(glued, " | "))

Check(#badKey == 0, "plural keys need two English forms that take the same values, the other form the count, "
    .. "and no WoW | escapes: " .. table.concat(badKey, " | "))

--------------------------------------------------------------------------
-- What a translation must carry over from its key besides the values: the
-- client's markup and the reader's braced words. Checked for every locale
-- below, and here on words made up for it, so the checks themselves are
-- tested while no locale is loaded.
--------------------------------------------------------------------------

-- A text's markup as the client reads it, in a comparable form: each
-- colour by its code, each close, texture, link and atlas, and the line
-- breaks ("\n" and the client's "|n"). A translation may move them, never
-- drop, add or recolour one.
--
-- `plural`: the text is a "##plural" value. Its bars split the forms and
-- it can hold none of the client's escapes (the plural keys' own check),
-- so only its line breaks count: "une note|notes" has no "|n".
local function Markup(text, plural)
    local found = {}
    if plural then
        local _, n = text:gsub("\n", "")
        return ("line"):rep(n, ", ")
    end
    local function Count(name, pattern)
        local _, n = text:gsub(pattern, "")
        for _ = 1, n do found[#found + 1] = name end
    end
    for code in text:gmatch("|c(%x%x%x%x%x%x%x%x)") do found[#found + 1] = "colour " .. code:lower() end
    for name in text:gmatch("|cn([%w_]+):") do found[#found + 1] = "colour " .. name end
    Count("close", "|r")
    Count("texture", "|T.-|t")
    Count("link", "|H.-|h")
    Count("atlas", "|A.-|a")
    Count("break", "|n")
    Count("line", "\n")
    table.sort(found)
    return table.concat(found, ", ")
end

-- The words a text braces for the reader ("{you}", "{Du hast}"), lower
-- case as Format.You looks them up.
local function Braced(text)
    local words = {}
    for word in text:gmatch("{(.-)}") do words[#words + 1] = word:lower() end
    return words
end

-- What is wrong with the gender forms in `value` (<1:he/she>,
-- <you:he/she/neither>: Locales/Locale.lua), or nil: each names the reader
-- or one of the key's values, and holds two forms or three.
local function Forms(key, value)
    local english = ns.Locale.English(key)
    local _, takes = english:gsub("%%%d*%$?[-+ #0]*%d*%.?%d*[%a]", "")
    if key:find("##plural") then
        local forms = ns.Locale.Forms(english)
        _, takes = forms[#forms]:gsub("%%%d*%$?[-+ #0]*%d*%.?%d*[%a]", "")
    end
    for who, forms in value:gmatch("<([^<>:/|]*):([^<>]*)>") do
        local n = tonumber(who)
        if who ~= "you" and who ~= "they" and not n then return ("<%s:...> names neither a value nor the reader"):format(who) end
        if n and (n < 1 or n > takes) then return ("<%d:...> but the key takes %d values"):format(n, takes) end
        local _, slashes = forms:gsub("/", "")
        if slashes < 1 or slashes > 2 then return ("<%s:%s> needs two forms or three, split by /"):format(who, forms) end
        if forms:find("|", 1, true) or forms:find("%", 1, true) then
            return ("<%s:%s> holds a bar or a value"):format(who, forms)
        end
    end
    if value:gsub("<[^<>:/|]*:[^<>]*>", ""):find("<%w+:") then return "a gender form is not closed" end
    return nil
end

-- What is wrong with `value` as the words for `key`, or nil. `forms` is
-- the locale's table of the reader's words (grammar.YOU_FOR, else the
-- English one): a braced word not in it would stay as written in a shared
-- diary, "du hast" where another character's name belongs.
local function Carried(key, value, forms)
    local english = ns.Locale.English(key)
    local plural = key:find("##plural$") ~= nil
    local a, b = Markup(english, plural), Markup(value, plural)
    if a ~= b then return ("markup differs: [%s] in the key, [%s] in the words"):format(a, b) end
    local mine, theirs = Braced(english), Braced(value)
    if (#mine == 0) ~= (#theirs == 0) then
        return #mine == 0 and "braces the reader where the key does not"
            or "the key braces the reader ({you}), the words do not"
    end
    for _, word in ipairs(theirs) do
        if not forms[word] then return ("{%s} is not one of the locale's reader's words (grammar.YOU_FOR)"):format(word) end
    end
    return Forms(key, value)
end

Section("what a translation carries over")
do
    local EN = ns.UI.Format.YOU_FOR
    local DE = { ["du"] = "%s", ["du hast"] = "%s hat", ["dich"] = "%s" }
    Check(Carried("added |cffffffff%s|r to the diary.", "|cffffffff%s|r ins Tagebuch eingetragen.", DE) == nil,
        "markup kept and moved is fine")
    Check(Carried("added |cffffffff%s|r to the diary.", "%s ins Tagebuch eingetragen.", DE) ~= nil, "a dropped colour")
    Check(Carried("added |cffffffff%s|r to the diary.", "|cffffd100%s|r eingetragen.", DE) ~= nil, "another colour")
    Check(Carried("One line.\n\nAnother.", "Eine Zeile.\nNoch eine.", DE) ~= nil, "a lost line break")
    Check(Carried("One line.\n\nAnother.", "Eine Zeile.\n\nNoch eine.", DE) == nil, "line breaks kept")
    Check(Carried("{You} killed them", "{Du hast} sie getötet", DE) == nil, "the reader braced in the locale's words")
    Check(Carried("{You} killed them", "Du hast sie getötet", DE) ~= nil, "the reader's braces dropped")
    Check(Carried("{You} killed them", "{Ihr habt} sie getötet", DE) ~= nil, "a braced word the locale has no form for")
    Check(Carried("Killed them", "{Du hast} sie getötet", DE) ~= nil, "braces the key has not")
    Check(Carried("%s saw {you} die##context", "%s sah {dich} sterben", DE) == nil, "a key's context is not its text")
    Check(Carried("a fight|%d fights##plural", "ein Kampf|%d Kämpfe", DE) == nil, "a plural's bar is no markup")
    Check(Carried("%1$s killed %2$s", "%1$s <1:убил/убила> %2$s", DE) == nil, "gender forms by a value")
    Check(Carried("%1$s killed %2$s", "%1$s <3:убил/убила> %2$s", DE) ~= nil, "by a value the key has not")
    Check(Carried("%s died", "%s <1:умер>", DE) ~= nil, "one form alone")
    Check(Carried("%s died", "%s <1:умер/умерла", DE) ~= nil, "a form left open")
    Check(Carried("%s died", "%s <him:умер/умерла>", DE) ~= nil, "a form by no one")
    Check(Carried("Died here", "<you:Погиб/Погибла/Смерть> здесь", DE) == nil, "the reader's, with a third")
    Check(Carried("saved you", "<they:спас/спасла/спасает> тебя", DE) == nil, "the one the words are about")
    Check(Carried("a note|%d notes##plural", "une note|%d notes|nos %d notes", DE) == nil,
        "nor is a bar before a form that starts like an escape")
    -- The code's own keys against the English forms.
    local bad = {}
    local all, list = Extract.Keys(".")
    for _, k in ipairs(list) do
        for _, word in ipairs(Braced(ns.Locale.English(k))) do
            if not EN[word] then bad[#bad + 1] = ("%q (%s)"):format(k, all[k]) end
        end
    end
    Check(#bad == 0, "keys that brace a word Format.You has no form for: " .. table.concat(bad, " | "))
end

Section("enUS.lua is the code's keys")
local stale, absent = {}, {}
for _, k in ipairs(order) do if en[k] == nil then absent[#absent + 1] = k .. " (" .. keys[k] .. ")" end end
for k in pairs(en) do if not keys[k] then stale[#stale + 1] = k end end
Check(#absent == 0, "keys used in the code but not in Locales/enUS.lua (run luajit Dev/Locale/extract.lua): "
    .. table.concat(absent, " | "))
Check(#stale == 0, "keys in Locales/enUS.lua the code no longer uses (run luajit Dev/Locale/extract.lua): "
    .. table.concat(stale, " | "))

-- Every locale the TOC loads words for (Locales/<id>/...), each checked
-- against the keys the code uses.
local LOCALES, listed = {}, {}
for line in io.lines("social_diary.toc") do
    local id = line:match("^Locales/(%a%a%a%a)/")
    if id and not listed[id] then listed[id] = true; LOCALES[#LOCALES + 1] = id end
end

-- A locale's grammar, as its client loads it.
local loaded = {}
local function GrammarNs(id)
    if loaded[id] then return loaded[id] end
    local was, wasNs = _G.GetLocale, T.ns
    _G.GetLocale = function() return id end
    loaded[id] = T.Load()
    _G.GetLocale, T.ns = was, wasNs
    return loaded[id]
end
local function GrammarOf(id) return GrammarNs(id).Locale.grammar end

for _, id in ipairs(LOCALES) do
    Section(id)
    local G = GrammarOf(id)
    if RULES[id] then RuleHolds(G, RULES[id], id) end
    local oneAlone = OneAlone(G)
    local words = Extract.Locale(".", id)
    local unknown, wrong, missing, plural, lost = {}, {}, {}, {}, {}
    local forms = G.YOU_FOR or GrammarNs(id).UI.Format.YOU_FOR
    for k, v in pairs(words) do
        if keys[k] then
            local why = Carried(k, v, forms)
            if why then lost[#lost + 1] = ("%q -> %q (%s)"):format(k, v, why) end
        end
        if not keys[k] then unknown[#unknown + 1] = k
        elseif IsPlural(k) then
            local sig, pos = PluralSignature(k)
            local forms, ok = ns.Locale.Forms(v), true
            if #forms ~= G.PLURAL_FORMS then ok = false end
            for i, f in ipairs(forms) do
                local s, mixed = Extract.Signature(f)
                local fits = s == sig or (s:find("%d") and s == pos)
                local bare = i == 1 and oneAlone and (Within(s, sig) or Within(s, pos))
                if mixed or not (fits or bare) then ok = false end
            end
            if not ok then
                plural[#plural + 1] = ("%q -> %q (%d forms, %s)"):format(k, v, G.PLURAL_FORMS, sig)
            end
        else
            local a, mixedA = Extract.Signature(k)
            local b, mixedB = Extract.Signature(v)
            if b:find("%d") and not a:find("%d") then a = Extract.PositionalOf(k) end
            if a:find("%d") and not b:find("%d") then b = Extract.PositionalOf(v) end
            if a ~= b or mixedB then wrong[#wrong + 1] = ("%q -> %q (%s vs %s)"):format(k, v, a, b) end
        end
    end
    for _, k in ipairs(order) do if words[k] == nil then missing[#missing + 1] = k end end
    Check(#unknown == 0, id .. " words for keys the code doesn't use: " .. table.concat(unknown, " | "))
    Check(#wrong == 0, id .. " words that take other values than their key: " .. table.concat(wrong, " | "))
    Check(#plural == 0, id .. " plural words need one form per plural category, each with the key's values"
        .. (oneAlone and "" or " (every form shows the count: form 1 is not the number 1 alone here)")
        .. ": " .. table.concat(plural, " | "))
    Check(#lost == 0, id .. " words that lose what their key carries (colour codes, line breaks, the reader's braces): "
        .. table.concat(lost, " | "))
    -- Words still to write are no failure: the key reads in English until
    -- they are, and a release need not wait for a translator. Said, so the
    -- gap shows (the list: luajit Dev/Locale/extract.lua --missing <id>).
    if #missing > 0 then
        print(("        %s: %d of %d keys translated, %d still in English (luajit Dev/Locale/extract.lua --missing %s)")
            :format(id, #order - #missing, #order, #missing, id))
    end
end
