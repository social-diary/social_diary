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
local L, Fmt = ns.L, ns.Fmt

-- Words and what it did them with: "Sunscale Lashtail, with Bite".
local function With(text, spell)
    return spell and Fmt(L["%1$s, with %2$s"], text, spell) or text
end

-- The killer card (Card.lua): what the creature did, under its name:
-- "killed you", "killed you twice", "killed you three times", held
-- together as a margin note's phrases are.
function Deaths.Killed(n)
    n = n or 1
    -- Once says no count, and English has a word for two that is no plural
    -- category (as Text.Times has them); the rest is the count's plural.
    if n == 1 then return Glue(L["killed you"]) end
    if n == 2 then return Glue(L["killed you twice"]) end
    return Glue(Fmt(L["killed you %s##times"], ns.Plural(n, L["%s time|%s times##plural"], NUMBER[n] or tostring(n))))
end

-- A creature's rank, as a tooltip says it.
local RANK = { elite = L["Elite"], rare = L["Rare"], rareelite = L["Rare elite"], worldboss = L["Boss"] }

-- What the world killed you with (the death recap's environmental kinds).
local WORLD = { FALLING = L["A fall"], DROWNING = L["Drowned"], FATIGUE = L["Exhaustion"], FIRE = L["Fire"],
    LAVA = L["Lava"], SLIME = L["Slime"] }

-- The killer card's tooltip: the creature's name, its rank, how often it
-- killed you on the plate and with what, and when it last did. A killer
-- the death recap never confirmed (`probable`) says so, quietly.
function Deaths.KillerTip(k, now)
    local lines = {}
    if RANK[k.rank] then lines[#lines + 1] = RANK[k.rank] end
    lines[#lines + 1] = With(Times(k.count or 1, L["Killed you here"], L["Killed you here %s"]), k.spell)
    if k.last then lines[#lines + 1] = Fmt(L["The last time %s"], ns.UI.Format.At(k.last, now)) end
    if k.probable then lines[#lines + 1] = L["As near as the diary could tell"] end
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
                line = { n = 0, name = d.name or WORLD[d.environment:upper()] or L["The world"] }
                at[key] = line
                lines[#lines + 1] = line
            end
            line.n = line.n + 1
            line.spell = d.spell or line.spell
        end
    end
    local out = {}
    for i, line in ipairs(lines) do
        local text = With(line.name, line.spell)
        if line.n == 2 and L["twice"] ~= "" then
            text = Fmt(L["%1$s, %2$s"], text, L["twice"])
        elseif line.n > 2 then
            text = Fmt(L["%1$s, %2$s"], text, ns.Plural(line.n, L["once|%d times##plural"]))
        end
        out[i] = text
    end
    return Times(math.max(count or 0, #(deaths or {}), 1), L["Died here"], L["Died here %s"]), out
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
        return ns.Plural(n, L["a death|%s deaths##plural"], NUMBER[n] or tostring(n))
    end
    local function Died(n, c)
        local killer = c.said.death
        return killer and Fmt(L["%1$s, to %2$s"], Count(n), killer) or Count(n)
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
