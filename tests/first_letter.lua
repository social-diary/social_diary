-- A line's first letter and a name's initial, as some clients upper them.
-- The client's string.upper can change a byte above 127 on its own (as
-- Latin-1 would: 0xE4 "ä" to 0xC4 "Ä"); LuaJIT's leaves such bytes alone,
-- so a capital made byte by byte passes here and breaks a Chinese or
-- Korean first letter in the game. This file runs with an upper that does
-- what such a client does.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local plainUpper = string.upper
local function ClientUpper(text)
    return (plainUpper(text):gsub("[\224-\246\248-\254]", function(c)
        return string.char(c:byte() - 32)
    end))
end

local G = ns.Locale.grammar
local Text = ns.UI.JourneyText
local now = mock.now or 1791000000

Section("first letter")
Eq(ns.Locale.FirstLetter("Bram"), "B", "an ASCII name's first letter")
Eq(ns.Locale.FirstLetter("夏溪"), "夏", "a Chinese name's first letter is one whole character")
Eq(ns.Locale.FirstLetter("Ärger"), "Ä", "a two-byte letter stays whole")
Eq(ns.Locale.FirstLetter(""), "", "an empty name")

string.upper = ClientUpper

Section("the English defaults, under a client upper")
Eq(G.Upper("Bram and 夏溪"), "BRAM AND 夏溪", "Upper touches ASCII letters only")
Eq(G.Capital("夏溪 waved"), "夏溪 waved", "Capital leaves a Chinese first letter alone")
Eq(G.Capital("bram waved"), "Bram waved", "and still capitals an ASCII one")

Section("a name's initial, under a client upper")
Eq(ns.Locale.Initial("bram"), "B", "an ASCII name's initial is a capital")
Eq(ns.Locale.Initial("夏溪"), "夏", "a Chinese name's initial is its whole first character")
Eq(ns.Locale.Initial("하늘"), "하", "and a Korean one")

Section("a tooltip's time line, under a client upper")
local english = Text.When(now - 60, nil, now)
Check(english:sub(1, 1) == "T", "the English line starts with a capital: " .. english)

local capital = G.Capital
G.Capital = function(text) return text end
rawset(ns.L, "today at %s", "今天%s")
local chinese = Text.When(now - 60, nil, now)
Eq(chinese:sub(1, 6), "今天", "a Chinese first letter is not cut")
G.Capital = capital

string.upper = plainUpper
