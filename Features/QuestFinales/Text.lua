-- Quest chain finales' words (JRN-28): a sentence each in the level's
-- prose (Text.RegisterLines, UI/Journey/Text/Prose.lua), the plates' caption
-- words (Text.RegisterCaption) and the tailpiece's tooltip (Mark.lua).
-- Copy changes go through the copywriter skill, as every player-read word
-- does.

local addonName, ns = ...

local QuestFinales = ns.QuestFinales
local Text = ns.UI.JourneyText
local Capital, MapName, When, Spoken = Text.Capital, Text.MapName, Text.When, Text.Spoken
local NUMBER, WORDS = Text.NUMBER, Text.WORDS
local L, Fmt = ns.L, ns.Fmt

-- A quest's title as the diary quotes it: “Crown of the Earth”.
local function Quoted(title)
    return Fmt(L["“%s”"], title or L["a quest"])
end

-- A number of quests in words: "nine", "29".
local function Many(n)
    return WORDS[n] or tostring(n)
end

-- How long a chain took, as the prose says it: "three hours", "five
-- days", "three weeks", "two months".
local function Span(seconds)
    local days = seconds / ns.DAY
    if days < 1 then return Spoken(seconds) end
    local function Of(n, one, many)
        n = math.max(1, math.floor(n + 0.5))
        return n == 1 and one or Fmt(many, Many(n))
    end
    if days < 13.5 then return Of(days, L["a day"], L["%s days"]) end
    if days < 60 then return Of(days / 7, L["a week"], L["%s weeks"]) end
    return Of(days / 30, L["a month"], L["%s months"])
end

-- A finale in a few words, for a plate's caption: "the end of “Crown of
-- the Earth”".
function QuestFinales.Words(f)
    return Fmt(L["the end of %s"], Quoted(f.title))
end

-- A finale in a sentence: "The end of “Crown of the Earth”, a chain of
-- nine begun in Shadowglen five days before." Where it began is said only
-- where the diary saw it begin.
function QuestFinales.Sentence(f)
    local title = Quoted(f.title)
    local n = f.n or 0
    if n <= 1 then return Fmt(L["The end of %s."], title) end
    local start = f.started
    if start and start.t and f.t then
        local zone = MapName(start.mapID)
        local span = Span(f.t - start.t)
        if zone then return Fmt(L["The end of %1$s, a chain of %2$s begun in %3$s %4$s before."], title, Many(n), zone, span) end
        return Fmt(L["The end of %1$s, a chain of %2$s begun %3$s before."], title, Many(n), span)
    end
    return Fmt(L["The end of %1$s, a chain of %2$s."], title, Many(n))
end

-- The level's finales in its prose, one sentence each.
function QuestFinales.Lines(e)
    local parts = {}
    for _, f in ipairs(e.finales or {}) do parts[#parts + 1] = QuestFinales.Sentence(f) end
    if #parts == 0 then return nil end
    return table.concat(parts, " ")
end

-- Its mark's tooltip: "The end of “Crown of the Earth”", then how long the
-- chain was, where and when it began, when it ended.
function QuestFinales.Tip(f, now)
    local lines = {}
    if (f.n or 0) > 1 then lines[#lines + 1] = Fmt(L["A chain of %d quests"], f.n) end
    local start = f.started
    if start and start.t then
        local zone = MapName(start.mapID)
        local at = ns.UI.Format.At(start.t, now)
        lines[#lines + 1] = zone and Fmt(L["Begun in %1$s, %2$s"], zone, at) or Fmt(L["Begun %s"], at)
    end
    lines[#lines + 1] = When(f.t, f.level, now)
    return Capital(QuestFinales.Words(f)), lines
end

-- Its paragraph in the level's prose: the chains finished, a sentence
-- each, after the firsts found (40), before the profession caps (60).
Text.RegisterLines("finale", { at = 50, lines = function(e) return QuestFinales.Lines(e) end })

-- The caption's words: after the finds, or leading where nothing above it
-- does ("The end of “Crown of the Earth”."); "two chains finished". Its
-- lead (`at` 30) comes after a first found (20), before a profession's
-- cap (40); its tail (`at` 20) after the finds (10), before the caps (30).
local function Ended(finales)
    return #finales == 1 and QuestFinales.Words(finales[1])
        or Fmt(L["%s chains finished"], NUMBER[#finales] or tostring(#finales))
end

Text.RegisterCaption("finale", {
    moment = "finale",
    take = function(m) return m.finale end,
    lead = { at = 30, say = function(finales) return Capital(Ended(finales)) end },
    tail = { at = 20, say = Ended },
})
