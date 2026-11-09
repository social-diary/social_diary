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

local keys, order = Extract.Keys(".")
local en = Extract.Locale(".", "enUS")

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

for _, id in ipairs(LOCALES) do
    Section(id)
    local words = Extract.Locale(".", id)
    local unknown, wrong, missing = {}, {}, {}
    for k, v in pairs(words) do
        if not keys[k] then unknown[#unknown + 1] = k
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
    Check(#missing == 0, ("%d of %d keys have no %s words (luajit Dev/Locale/extract.lua --missing %s): %s")
        :format(#missing, #order, id, id, table.concat(missing, " | ", 1, math.min(#missing, 20))))
end
