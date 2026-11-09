-- Deaths' words on Your Diary's plates: the killer card's (Card.lua), its
-- tooltip and the death cross's, and the caption's deaths
-- (Text.RegisterCaption, UI/Journey/Text/Caption.lua). A killer's name in a
-- sentence ("a Sunscale Lashtail") is the core's Text.KillerName: close
-- calls, witnesses and the timeline say theirs with it too. Copy changes
-- go through the copywriter skill, as every player-read word does.

local addonName, ns = ...

local Deaths = ns.Deaths
local Text = ns.UI.JourneyText
local Capital, Glue, NUMBER, Times = Text.Capital, Text.Glue, Text.NUMBER, Text.Times

-- How a plate's mark's tooltip ends (9 Nov 2026: every mark tells all it
-- stands for at once, as a fight's stain does): when, from the first to the
-- last, then at what level, in the core's words (Text.Foot,
-- UI/Journey/Text/Tips.lua): "Today at 12:47, level 20", "Today from 12:47
-- to 13:20, levels 19 to 20". `list` is plain records, each { t, level }
-- (either may be missing); nil with neither. The close calls' and the
-- witnesses' marks end with it too (their Text.lua), so the death-side
-- tooltips read as one family.
function Deaths.Foot(list, now)
    local a = {}
    for _, r in ipairs(list or {}) do
        if type(r.t) == "number" then
            a.from, a.to = math.min(a.from or r.t, r.t), math.max(a.to or r.t, r.t)
        end
        if type(r.level) == "number" and r.level > 0 then
            a.levelFrom, a.levelTo = math.min(a.levelFrom or r.level, r.level), math.max(a.levelTo or r.level, r.level)
        end
    end
    return Text.Foot(a, now)
end

-- The killer card (Card.lua): what the creature did, under its name:
-- "killed you", "killed you twice", "killed you three times", held
-- together as a margin note's phrases are.
function Deaths.Killed(n)
    n = n or 1
    if n == 1 then return Glue("killed you") end
    if n == 2 then return Glue("killed you twice") end
    return Glue("killed you " .. (NUMBER[n] or tostring(n)) .. " times")
end

-- A creature's rank, as a tooltip says it.
local RANK = { elite = "Elite", rare = "Rare", rareelite = "Rare elite", worldboss = "Boss" }

-- What the world killed you with (the death recap's environmental kinds).
local WORLD = { FALLING = "A fall", DROWNING = "Drowned", FATIGUE = "Exhaustion", FIRE = "Fire", LAVA = "Lava",
    SLIME = "Slime" }

-- The killer card's tooltip: the creature's name, its rank, how often it
-- killed you on the plate and with what, and when it last did. A killer
-- the death recap never confirmed (`probable`) says so, quietly.
function Deaths.KillerTip(k, now)
    local lines = {}
    if RANK[k.rank] then lines[#lines + 1] = RANK[k.rank] end
    lines[#lines + 1] = Times(k.count or 1, "Killed you here", "Killed you here %s")
        .. (k.spell and (", with " .. k.spell) or "")
    if k.last then lines[#lines + 1] = "The last time " .. ns.UI.Format.At(k.last, now) end
    if k.probable then lines[#lines + 1] = "As near as the diary could tell" end
    return k.name, lines
end

-- A death cross's tooltip on a plate: how many deaths it marks, then what
-- killed you there, each once, the one that did most first (then in the
-- order it did): "Sunscale Lashtail, with Bite, twice"; "A fall". At most
-- KILLERS lines of them, the last "And others" where more did, then when
-- and at what level (Deaths.Foot). `deaths` are Deaths.List's records
-- matched to the cross (Card.Match), with the level each was at (`level`,
-- the pass's, from the route), or an inserted card's (Kind.lua's
-- `killedBy`: one mark tells all the inserted deaths on its spot); deaths
-- from before they were kept have none, and add only to the count.
-- (9 Nov: inserted deaths on one spot each said "Died here" again.)
local KILLERS = 3

function Deaths.DeathCross(count, deaths, now)
    local lines, at = {}, {}
    for _, d in ipairs(deaths or {}) do
        local key = d.name or (d.environment and ("world:" .. d.environment:upper()))
        if key then
            local line = at[key]
            if not line then
                line = { n = 0, first = #lines + 1, name = d.name or WORLD[d.environment:upper()] or "The world" }
                at[key] = line
                lines[#lines + 1] = line
            end
            line.n = line.n + 1
            line.spell = d.spell or line.spell
        end
    end
    table.sort(lines, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return a.first < b.first
    end)
    local out = {}
    for i, line in ipairs(lines) do
        if i == KILLERS and #lines > KILLERS then
            out[i] = "And others"
            break
        end
        out[i] = line.name .. (line.spell and (", with " .. line.spell) or "")
            .. (line.n == 2 and ", twice" or line.n > 2 and (", " .. line.n .. " times") or "")
    end
    local foot = Deaths.Foot(deaths, now)
    if foot then out[#out + 1] = foot end
    return Times(math.max(count or 0, #(deaths or {}), 1), "Died here", "Died here %s"), out
end

-- The deaths there: "a death", "two deaths". The plate's moments of kind
-- "death" are the route's (its crosses, Core/JourneyRecap.lua), told here.
-- `said.death` is what killed you, as Text.KillerName writes it, when its
-- card (Card.lua) found no room beside the plate (or a witness's card did
-- not name it): it goes with the deaths ("Two deaths, to a Sunscale
-- Lashtail."), so its name is still written somewhere. They lead at 50,
-- after a fight with a stranger (the diary's "fights", 45) and before a
-- close call (60), and a fight lost to strangers already says how it went,
-- so with that lead the deaths are not added to the tail (40: after the
-- firsts found, before a close call).
--
-- A death the player inserted (Kind.lua's `killedBy`) counts with them, so
-- beside the route's one it is "Two deaths", as two detected would be, and not
-- "A death, and a death". The route's words count both and the inserted kind's
-- only speak where the route's have not: no death of the route's here (a lead at
-- 55, a tail at 45), or the route's left silent after a fight lost to strangers,
-- which says how that fight went and nothing of the one the player wrote.
do
    local function Count(n)
        if n == 1 then return "a death" end
        return (NUMBER[n] or tostring(n)) .. " deaths"
    end
    local function Died(n, c)
        local killer = c.said.death
        return Count(n) .. (killer and (", to " .. killer) or "")
    end
    local function Inserted(c)
        return c.lists.killedBy and #c.lists.killedBy or 0
    end
    Text.RegisterCaption("death", {
        moment = "death",
        lead = { at = 50, say = function(deaths, c) return Capital(Died(#deaths + Inserted(c), c)) end },
        tail = { at = 40, say = function(deaths, c)
            if c.lead == "fights" then return nil end
            return Died(#deaths + Inserted(c), c)
        end },
    })
    Text.RegisterCaption("killedBy", {
        moment = "killedBy",
        lead = { at = 55, say = function(list, c) return Capital(Died(#list, c)) end },
        tail = { at = 45, say = function(list, c)
            if #(c.lists.death or {}) > 0 and c.lead ~= "fights" then return nil end
            return Died(#list, c)
        end },
    })
end
