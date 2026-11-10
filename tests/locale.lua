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

local keys, order = Extract.Keys(".")
local en = Extract.Locale(".", "enUS")
local function IsPlural(k) return k:find("##plural$") ~= nil end

-- A plural key's placeholders, as its "other" (last) form takes them.
local function PluralSignature(k)
    local forms = ns.Locale.Forms(ns.Locale.English(k))
    return (Extract.Signature(forms[#forms])), Extract.PositionalOf(forms[#forms])
end

Section("plural keys")
local badKey = {}
for _, k in ipairs(order) do
    if IsPlural(k) then
        local forms = ns.Locale.Forms(ns.Locale.English(k))
        local sig = PluralSignature(k)
        local ok = #forms == 2 and not k:find("|[cCrRtTnHhAaKk4]") and sig ~= ""
        for _, f in ipairs(forms) do
            local s = Extract.Signature(f)
            if s ~= sig and s ~= "" then ok = false end
        end
        if not ok then badKey[#badKey + 1] = k end
    end
end
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
                local bare = s == "" and i == 1 and oneAlone
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
