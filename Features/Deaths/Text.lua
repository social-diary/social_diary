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
-- killed you there, each once, in the order it did ("Sunscale Lashtail,
-- with Bite, twice"; "A fall"). `deaths` are Deaths.List's records
-- matched to the cross (Card.Match); deaths from before they were kept
-- have none, and add only to the count.
function Deaths.DeathCross(count, deaths)
    local lines, at = {}, {}
    for _, d in ipairs(deaths or {}) do
        local key = d.name or (d.environment and ("world:" .. d.environment:upper()))
        if key then
            local line = at[key]
            if not line then
                line = { n = 0, name = d.name or WORLD[d.environment:upper()] or "The world" }
                at[key] = line
                lines[#lines + 1] = line
            end
            line.n = line.n + 1
            line.spell = d.spell or line.spell
        end
    end
    local out = {}
    for i, line in ipairs(lines) do
        out[i] = line.name .. (line.spell and (", with " .. line.spell) or "")
            .. (line.n == 2 and ", twice" or line.n > 2 and (", " .. line.n .. " times") or "")
    end
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
