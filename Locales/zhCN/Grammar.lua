-- 简体中文（中国大陆）：模板容不下的语法。口吻见
-- .claude/skills/translate/voices/zhCN.md。
local addonName, ns = ...
-- 在每个客户端都列进「语言」页，用本语言自己的名字。
ns.Locale.Offer("zhCN", "简体中文")
if not ns.Locale.Is("zhCN") then return end

local G = ns.Locale.grammar

-- CLDR：中文只有 other 一类，任何数字都用同一个形式。因此每个
-- ##plural 词只有一个形式、且都带计数（1 也写「1次」，不写「一次」）。
G.PluralForm = function(n) return 1 end
G.PLURAL_FORMS = 1

-- 中文没有大小写：标题、行首、排序标签都原样，别把词里的拉丁字母
-- （PvP、ID）改掉。
G.Upper = function(text) return text end
G.Capital = function(text) return text end

-- 「第13」，用在词表之外的序数（Format.Nth 越过第十二个之后）。
G.Ordinal = function(n, context) return "第" .. n end

-- 日期里的「日」：中文不说「25th」，座次标签也不用序数。日期模板
-- 自己把月放到前面（「10月25日」），这里只给数字。
G.Day = function(n, ordinal) return tostring(n) end

-- 时间、小数沿用默认：18:05、3.2。中文同样这样写。
-- 列表用顿号，末项用「和」：写在词表里，不需要 ListEnd / Agree。

-- 名字的所有格：「Brom 的这一趟」。
G.Genitive = function(name) return name .. "的" end

-- 中文名词不随数量变形，游戏给的名字已经本地化，原样使用。
G.Plural = function(name) return name end
G.ItemWord = function(n, item) return item end
G.KillerName = function(k) return k.name end
-- 见证者设置里的「冠词」选项对中文没有意义，藏起来。
G.NO_ARTICLE = true
-- 排序标签没有大小写可转。
G.PeopleSortLabel = function(label) return label end

-- 第一次找到某件东西的卡片标题，整句由这里拼（英文是
-- "Your first green item!"）。中文不用冠词，量词跟名词走。
local FIRST = {
    bag = { "第一个背包", "第一个背包" },
    shoulder = { "第一副护肩", "第一副护肩" },
    uncommon = { "第一件绿色物品", "第一件绿色" },
    rare = { "第一件蓝色物品", "第一件蓝色" },
    epic = { "第一件紫色物品", "第一件紫色" },
}
G.FirstsHeading = function(list, short)
    local words = {}
    for _, kind in ipairs(list) do
        local f = FIRST[kind]
        words[#words + 1] = f and f[short and 2 or 1] or "第一件发现"
    end
    local text = words[1]
    if #words > 1 then
        text = table.concat(words, "、", 1, #words - 1) .. "和" .. words[#words]
    end
    return "你的" .. text .. "！"
end

-- 共享日记里「你」换成另一个角色的名字：中文的「你」不分主宾格，
-- 所有格用「你的」。词表里所有 {…} 只有这两种。
G.YOU_FOR = {
    ["你"] = "%s",
    ["你的"] = "%s的",
}

-- 地名的介词由 ns.ZoneIn 给出，##zone 模板里不再写「在」。
-- 中文的介词在名字前面，多个地点共用一个即可（不设 EACH_PLACE）。
G.PLACE = {
    ["in"] = "在%s", to = "到%s", from = "从%s", into = "进入%s",
    through = "穿过%s", near = "%s附近", at = "在%s",
    around = "%s周围", round = "%s周围",
}
-- ZONES、DUNGEONS、SUBZONES 留空：地名来自客户端，不能凭记忆填。
