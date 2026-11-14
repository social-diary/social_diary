local _, ns = ...

ns.Locale.Offer("plPL", "Polski")
if not ns.Locale.Is("plPL") then return end

local grammar = ns.Locale.grammar

grammar.PLURAL_FORMS = 3
grammar.PluralForm = function(n)
    if n == 1 then return 1 end
    local last, lastTwo = n % 10, n % 100
    if last >= 2 and last <= 4 and (lastTwo < 12 or lastTwo > 14) then return 2 end
    return 3
end

local capitals = {
    ["ą"] = "Ą", ["ć"] = "Ć", ["ę"] = "Ę", ["ł"] = "Ł", ["ń"] = "Ń",
    ["ó"] = "Ó", ["ś"] = "Ś", ["ź"] = "Ź", ["ż"] = "Ż",
}

grammar.Upper = function(text)
    return (text:upper():gsub("[\194-\244][\128-\191]+", capitals))
end

grammar.Capital = function(text)
    return (text:gsub("^([%s\"'„]*)([%w\194-\244][\128-\191]*)", function(prefix, first)
        return prefix .. (capitals[first] or first:upper())
    end, 1))
end

grammar.Day = tostring
grammar.Ordinal = function(n) return n .. "." end
grammar.DECIMAL = ","
grammar.ListEnd = function(head, last) return head .. " i " .. last end

-- The count formatter shares its words across nouns. A localized template
-- marks the cases where the same number needs a different form.
local agreedCounts = {
    f = { jeden = "jedna", dwa = "dwie" },
    m = { dwa = "dwóch", trzy = "trzech", cztery = "czterech" },
}
grammar.Agree = function(text)
    return (text:gsub("([%w\128-\255]+)<([fm])>", function(word, form)
        local agreed = agreedCounts[form][word:lower()]
        if not agreed then return word end
        return word:match("^%u") and grammar.Capital(agreed) or agreed
    end))
end

grammar.PLACE = {
    ["in"] = "w %s", to = "do %s", from = "z %s", into = "do %s",
    through = "przez %s", near = "w pobliżu %s", at = "w %s",
    around = "w okolicy %s", round = "w okolicy %s",
}

-- Names read from the client or the diary are kept verbatim.
grammar.NO_ARTICLE = true
local function unchanged(name) return name end
grammar.Genitive = unchanged
grammar.Plural = unchanged
grammar.ItemWord = function(_, name) return name end
grammar.KillerName = function(killer) return killer.name end

grammar.YOU_FOR = {
    ["ty"] = "%s", ["cię"] = "%s", ["ci"] = "%s",
    ["ciebie"] = "%s", ["tobie"] = "%s", ["tobą"] = "%s",
    ["twój"] = "%s", ["twoja"] = "%s", ["twoje"] = "%s",
    ["twoja grupa"] = "Grupa postaci %s",
    ["twoja bitwa"] = "Bitwa postaci %s",
    ["twojej śmierci"] = "śmierci postaci %s",
    ["twoją śmierć"] = "śmierć postaci %s",
    ["zabiłeś"] = "%s zabił", ["zabiłaś"] = "%s zabiła",
    ["pokonałeś"] = "%s pokonał", ["pokonałaś"] = "%s pokonała",
    ["pokonujesz"] = "%s pokonuje",
    ["uciekłeś"] = "%s uciekł", ["uciekłaś"] = "%s uciekła",
    ["uciekasz"] = "%s ucieka",
}

local firsts = {
    bag = "pierwsza torba",
    shoulder = "pierwsze naramienniki",
    uncommon = "pierwszy zielony przedmiot",
    rare = "pierwszy niebieski przedmiot",
    epic = "pierwszy epicki przedmiot",
}

grammar.FirstsHeading = function(kinds)
    local names = {}
    for i, kind in ipairs(kinds) do names[i] = firsts[kind] or "pierwsza zdobycz" end
    if #names == 0 then return "Pierwsza zdobycz!" end
    if #names == 1 then return grammar.Capital(names[1]) .. "!" end
    return grammar.Capital(table.concat(names, ", ", 1, #names - 1) .. " i " .. names[#names]) .. "!"
end
