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
local RULES = {
    enUS = { forms = 2, [0] = 2, [1] = 1, [2] = 2, [5] = 2, [11] = 2, [21] = 2, [101] = 2 },
    deDE = { forms = 2, [0] = 2, [1] = 1, [2] = 2, [5] = 2, [11] = 2, [21] = 2, [101] = 2 },
    frFR = { forms = 2, [0] = 1, [1] = 1, [2] = 2, [5] = 2, [11] = 2, [21] = 2, [101] = 2 },
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
local function GrammarOf(id)
    local was, wasNs = _G.GetLocale, T.ns
    _G.GetLocale = function() return id end
    local G = T.Load().Locale.grammar
    _G.GetLocale, T.ns = was, wasNs
    return G
end

for _, id in ipairs(LOCALES) do
    Section(id)
    local G = GrammarOf(id)
    if RULES[id] then RuleHolds(G, RULES[id], id) end
    local oneAlone = OneAlone(G)
    local words = Extract.Locale(".", id)
    local unknown, wrong, missing, plural = {}, {}, {}, {}
    for k, v in pairs(words) do
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
    Check(#missing == 0, ("%d of %d keys have no %s words (luajit Dev/Locale/extract.lua --missing %s): %s")
        :format(#missing, #order, id, id, table.concat(missing, " | ", 1, math.min(#missing, 20))))
end
