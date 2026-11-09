-- Profession caps' words (JRN-29): a sentence each in the level's prose
-- (Text.RegisterLines, UI/Journey/Text/Prose.lua), the plates' caption words
-- (Text.RegisterCaption) and the stairs' tooltip (Mark.lua). Copy changes
-- go through the copywriter skill, as every player-read word does.

local addonName, ns = ...

local ProfessionCaps = ns.ProfessionCaps
local Text = ns.UI.JourneyText
local Capital, NUMBER = Text.Capital, Text.NUMBER

-- Who a cap is as far as the training goes: each rank's trainer's title,
-- with its article. Any other number (a cap the client adds later) is
-- told bare, without the clause.
local SKILL_RANK = { [75] = "an Apprentice", [150] = "a Journeyman", [225] = "an Expert", [300] = "an Artisan" }

-- The profession as the client called it, or "a profession" where it gave
-- no name.
local function Trade(cap)
    return cap.name and cap.name ~= "" and cap.name or "a profession"
end

-- The cap reached, as a number to say after "at": "75"; "its cap" where
-- the record has none.
local function Rank(cap)
    return cap.rank and tostring(cap.rank) or "its cap"
end

-- A cap in a few words, for a plate's caption: "First Aid at 75", "a
-- profession at 75".
function ProfessionCaps.Words(cap)
    return Trade(cap) .. " at " .. Rank(cap)
end

-- How far the training goes, after a comma: "as far as an Apprentice
-- goes"; nil for a rank with no trainer's title.
local function AsFar(cap)
    local who = SKILL_RANK[cap.rank]
    return who and ("as far as " .. who .. " goes") or nil
end

-- A cap in a sentence: "First Aid reached 75, as far as an Apprentice
-- goes." The same profession again straight after only counts on: "Then
-- 150, as far as a Journeyman goes."
function ProfessionCaps.Sentence(cap, before)
    local again = before and (before.skillLine or before.name) == (cap.skillLine or cap.name)
        and (cap.skillLine or cap.name) ~= nil
    local text = again and ("Then " .. Rank(cap)) or (Capital(Trade(cap)) .. " reached " .. Rank(cap))
    local far = AsFar(cap)
    return text .. (far and (", " .. far) or "") .. "."
end

-- The level's caps in its prose, one sentence each.
function ProfessionCaps.Lines(e)
    local parts, before = {}, nil
    for _, cap in ipairs(e.skillCaps or {}) do
        parts[#parts + 1] = ProfessionCaps.Sentence(cap, before)
        before = cap
    end
    if #parts == 0 then return nil end
    return table.concat(parts, " ")
end

-- Its mark's tooltip: "First Aid at 75", then how far the training goes
-- ("As far as an Apprentice goes"), then when.
function ProfessionCaps.Tip(cap, now)
    local lines = {}
    local far = AsFar(cap)
    if far then lines[#lines + 1] = Capital(far) end
    lines[#lines + 1] = Text.Foot({ from = cap.t, levelFrom = cap.level }, now)
    return Capital(ProfessionCaps.Words(cap)), lines
end

-- Its paragraph in the level's prose: after the chains finished (50),
-- before the close calls and luck (70).
Text.RegisterLines("skill", { at = 60, lines = function(e) return ProfessionCaps.Lines(e) end })

-- The caption's words: after the chains' ends, or leading where neither
-- finds nor finales do: "First Aid at 75"; one profession twice, "First
-- Aid at 75, then 150"; several, "two professions at their cap". Its lead
-- (`at` 40) comes after a chain's end (30), before a fight with strangers
-- (45); its tail (`at` 30) after the chains' ends (20), before the deaths
-- (40).
local function Capped(caps)
    local trades, seen = 0, {}
    for _, cap in ipairs(caps) do
        local key = cap.skillLine or cap.name or cap
        if not seen[key] then seen[key], trades = true, trades + 1 end
    end
    if trades > 1 then return (NUMBER[trades] or tostring(trades)) .. " professions at their cap" end
    local text = ProfessionCaps.Words(caps[1])
    for k = 2, #caps do text = text .. ", then " .. (caps[k].rank or "its cap") end
    return text
end

Text.RegisterCaption("skill", {
    moment = "skill",
    take = function(m) return m.cap end,
    lead = { at = 40, say = function(caps) return Capital(Capped(caps)) end },
    tail = { at = 30, say = Capped },
})

-- A tooltip's last line for everything under one mark, as the core says
-- it for every mark (Text.Foot, UI/Journey/Text/Tips.lua): when, from the
-- first to the last ("Today at 12:47", "Today from 12:47 to 13:20"), then
-- the level or levels ("Level 20", "Levels 19 to 20"). `list` is records
-- with `t` and `level`.
local function Foot(list, now)
    local a = {}
    for _, r in ipairs(list) do
        if r.t then a.from, a.to = math.min(a.from or r.t, r.t), math.max(a.to or r.t, r.t) end
        if r.level then
            a.levelFrom, a.levelTo = math.min(a.levelFrom or r.level, r.level), math.max(a.levelTo or r.level, r.level)
        end
    end
    return Text.Foot(a, now)
end

-- The tooltip of a flight of stairs (Mark.lua's `tips`): every cap
-- reached on the spot told once together (9 Nov 2026; before, each cap's
-- ProfessionCaps.Tip was stacked under the last, its time again each
-- time). One profession: its caps in the order reached, as the caption
-- says them ("First Aid at 75, then 150"), how far the training goes at
-- the last, when and at what level. Several: "Two professions at their
-- cap", each profession's caps on a line of its own ("First Aid at 75,
-- then 150"; never run on with a middle dot, the copywriter skill), then
-- from when to when.
function ProfessionCaps.Tips(caps, now)
    caps = { unpack(caps) }
    table.sort(caps, function(a, b)
        if (a.t or 0) ~= (b.t or 0) then return (a.t or 0) < (b.t or 0) end
        return (tonumber(a.rank) or 0) < (tonumber(b.rank) or 0)
    end)
    local trades, by = {}, {}
    for _, cap in ipairs(caps) do
        local key = cap.skillLine or cap.name or cap
        if not by[key] then
            by[key] = {}
            trades[#trades + 1] = by[key]
        end
        table.insert(by[key], cap)
    end
    local lines = {}
    if #trades == 1 then
        local far = AsFar(caps[#caps])
        if far then lines[1] = Capital(far) end
        lines[#lines + 1] = Foot(caps, now)
        return Capital(Capped(caps)), lines
    end
    for _, list in ipairs(trades) do lines[#lines + 1] = Capital(Capped(list)) end
    lines[#lines + 1] = Foot(caps, now)
    return Capital((NUMBER[#trades] or tostring(#trades)) .. " professions at their cap"), lines
end
