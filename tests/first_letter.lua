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
