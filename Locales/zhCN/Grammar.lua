-- Simplified Chinese: the grammar the templates cannot carry.
local addonName, ns = ...
-- Offered on every client, by its own name (Settings, Language).
ns.Locale.Offer("zhCN", "简体中文")
if not ns.Locale.Is("zhCN") then return end

local G = ns.Locale.grammar

-- Chinese has one plural form: singular and plural read the same.
G.PluralForm = function(n) return 1 end
G.PLURAL_FORMS = 1

-- No letter case in Chinese: capitals are no-ops.
G.Upper = function(text) return text end
G.Capital = function(text) return text end

-- "第25".
G.Ordinal = function(n, context) return "第" .. n end

-- A date's day is the figure.
G.Day = function(n) return tostring(n) end

-- "3.2"
G.DECIMAL = "."

-- No articles; a place takes no preposition of its own.
G.NO_ARTICLE = true
G.EACH_PLACE = false

-- A number word before a noun does not agree.
G.Agree = function(text) return text end

-- A name in a genitive sentence: unchanged.
G.Genitive = function(name) return name end

-- The reader's braced words.
-- "{你们}都达到了20级" -> "Thex和对方都达到了20级".
G.YOU_FOR = { ["你"] = "%s", ["你的"] = "%s的", ["你们"] = "%s和对方" }

-- Prepositions for a place.
G.PLACE = {
    ["in"] = "在%s", to = "到%s", from = "从%s", into = "进入%s",
    through = "穿过%s", near = "在%s附近", at = "在%s", around = "在%s周围", round = "在%s附近",
}

-- More than one of a name: unchanged.
G.Plural = function(name) return name end
G.ItemWord = function(n, item) return item end
G.KillerName = function(k) return k.name end

-- A sort label: no case change.
G.PeopleSortLabel = function(label) return label end

-- A first found card's heading.
local FIRSTS = {
    bag = { "第一个背包", "首个背包" },
    shoulder = { "第一件肩部装备", "首件护肩" },
    uncommon = { "第一件绿色优秀物品", "首件绿色物品" },
    rare = { "第一件蓝色精良物品", "首件蓝色物品" },
    epic = { "第一件紫色史诗物品", "首件紫色物品" },
}
G.FirstsHeading = function(list, short)
    local words = {}
    for _, kind in ipairs(list) do
        local f = FIRSTS[kind]
        words[#words + 1] = f and (short and f[2] or f[1]) or "首次发现"
    end
    local text = words[1]
    if #words > 1 then
        text = table.concat(words, "、", 1, #words - 1) .. "和" .. words[#words]
    end
    return text .. "！"
end
