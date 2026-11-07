-- How Your Diary writes a time (ns.UI.JourneyText): a duration held
-- together (Duration), a zone's time in the ledger (LedgerTime), a time as
-- one speaks it (Spoken), a day ("6 October") and a tooltip's last line
-- (When).
--
-- The module and its siblings: UI/Journey/Text/Grammar.lua.

local addonName, ns = ...

local Format = ns.UI.Format
local L, Fmt = ns.L, ns.Fmt
local G = ns.Locale.grammar

local Text = ns.UI.JourneyText
local Glue = Text.Glue

local function Duration(seconds)
    return Glue(Format.Duration(seconds))
end
Text.Duration = Duration

-- A zone's time in the ledger under an entry, short as a column of
-- figures: "1 h 33", "2 h", "52 min".
function Text.LedgerTime(seconds)
    local minutes = math.floor((seconds or 0) / 60)
    if minutes < 60 then return Glue(Fmt(L["%d min"], minutes)) end
    local h, m = math.floor(minutes / 60), minutes % 60
    if m == 0 then return Glue(Fmt(L["%d h"], h)) end
    return Glue(Fmt(L["%d h %02d"], h, m))
end

-- A time as the diary says it in a sentence, rounded the way one speaks:
-- "a few minutes", "twenty minutes", "half an hour", "an hour and a half",
-- "three hours". The prose is not a ledger; the zone rows carry the
-- exact times.
local WORDS = { [2] = L["two"], [3] = L["three"], [4] = L["four"], [5] = L["five"], [6] = L["six"],
    [7] = L["seven"], [8] = L["eight"], [9] = L["nine"], [10] = L["ten"], [11] = L["eleven"],
    [12] = L["twelve"], [15] = L["fifteen"], [20] = L["twenty"], [25] = L["twenty-five"], [40] = L["forty"],
    [45] = L["forty-five"], [50] = L["fifty"], [55] = L["fifty-five"] }

local function Spoken(seconds)
    local m = (seconds or 0) / 60
    if m < 1 then return L["a moment"] end
    if m < 8 then return L["a few minutes"] end
    if m < 25 or (m >= 38 and m < 53) then
        local n = 5 * math.floor(m / 5 + 0.5)
        return Fmt(L["%s minutes"], WORDS[n] or Glue(tostring(n)))
    end
    if m < 38 then return L["half an hour"] end
    if m < 75 then return L["an hour"] end
    if m < 105 then return L["an hour and a half"] end
    local halves = math.floor(m / 30 + 0.5)
    local whole = math.floor(halves / 2)
    local name = WORDS[whole] or Glue(tostring(whole))
    return Fmt(halves % 2 == 1 and L["%s and a half hours"] or L["%s hours"], name)
end
Text.Spoken = Spoken

-- "6 October", with the year once it is not this one's.
local function Day(t, now)
    return Format.DayMonth(t, now or ns.Now())
end

local function When(t, level, now)
    local text = Format.At(t, now)
    text = text:sub(1, 1):upper() .. text:sub(2)
    if level then text = Fmt(L["%1$s, at level %2$d"], text, level) end
    return text
end

Text.Day, Text.When, Text.WORDS = Day, When, WORDS

-- A sitting's label under its level (.claude/sittings-plan.md): "Oct 25th",
-- and when another sitting began that day the part of it, "Oct 25th,
-- Evening" (two alike are fine: "Noon" and "Noon"). The year once it is
-- not this one's. `p` a recap piece: its `at`, `many`. A night past
-- midnight is the day before's (Recap.SittingDay), and its part "Night".
local PARTS = {
    { 5, L["Morning"] }, { 11, L["Noon"] }, { 14, L["Afternoon"] }, { 18, L["Evening"] }, { 22, L["Night"] },
}

local function Ordinal(n)
    if G.Ordinal then return G.Ordinal(n) end
    local tail = n % 100
    if tail >= 11 and tail <= 13 then return n .. "th" end
    local last = n % 10
    return n .. (last == 1 and "st" or last == 2 and "nd" or last == 3 and "rd" or "th")
end

local function Part(t)
    local hour = date("*t", t).hour
    local name = L["Night"]
    for _, part in ipairs(PARTS) do
        if hour >= part[1] then name = part[2] end
    end
    return name
end
Text.DayPart = Part

function Text.SittingLabel(p, now)
    local t = p.at or p.from
    local day = ns.JourneyRecap.SittingDay(t) + 12 * 3600
    local text = Fmt(L["%1$s %2$s##month day"], Format.MonthShort(day), Ordinal(tonumber(date("%d", day))))
    if date("%Y", day) ~= date("%Y", now or ns.Now()) then text = Fmt(L["%1$s %2$s"], text, date("%Y", day)) end
    text = Glue(text)
    if p.many then text = Fmt(L["%1$s, %2$s"], text, Part(t)) end
    return text
end
