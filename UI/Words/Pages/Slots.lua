-- The slots a page's words can use (PAGE-3): each turns facts into words.
--
-- Two sorts. Person slots take the fact holding a person (default "who")
-- and say who they are the way the sentence needs it. Formatters take the
-- fact to read as their first argument, need it (truthy: 0 and "" don't
-- count) and say it, so a move's `must` can ask for it by that name.
--
-- Person slots                                    e.g.
--   {ref}            subject: name, description or pronoun     Brennick / a night elf hunter / he
--   {ref.obj}        object                                    him
--   {ref.poss}       possessive                                his / Brennick's
--   {ref.full}       name with epithet, even if mentioned       Brennick, my levelling buddy,
--   {ref.noun}       never a pronoun                            Brennick / the hunter
--   {ref.short}      no epithet                                 Brennick
--   {ref:by}         someone else in the facts (any mod works)  Kaelith
--   {name}           the name, named or not                     Morthis
--   {desc}           what they look like, no article            undead rogue ({desc.a}: an undead rogue)
--   {he} {him} {his} pronoun; their name when the sex is unknown
--   {class} {race}   lower case                                 hunter / night elf
--   {epithet}        the relationship, as an appositive         my levelling buddy
--
-- Formatters                                      e.g.
--   {num:f}          number in words (digits past 99)          nineteen
--   {num0:f}         the same, but 0 is "zero" and counts      zero
--   {digits:f}       digits                                    1,240
--   {count:f:noun[:plural]}  number and noun                    nine quests
--   {counta:f:noun}  "a quest" for one                         a quest / nine quests
--   {times:f}        once, twice, three times
--   {nth:f}          third (23rd past twenty)
--   {days:f}         a span of days, rounded                   nearly three weeks
--   {daysx:f}        a span of days, exact                     nineteen days
--   {dayadj:f}       a span of days as an adjective            a nineteen-day (gap)
--   {ago:f}          days ago, rounded                         nearly three weeks ago / yesterday
--   {agox:f}         days ago, exact                           nineteen days ago
--   {when:f}         a time, from the page's own time          on the 12th / back in September
--   {date:f}         a bare date, for after "since"            the 12th / September / Tuesday
--   {dur:f}          seconds as a duration                     nearly two hours
--   {secs:f}         short seconds                             about half a minute
--   {share:f}        seconds as a share of the session         most of the evening
--   {lvl:f}          a level, digits                           33
--   {levels:f}       a count of levels                         a level / five levels
--   {money:f}        copper, exact                             2 gold and 10 silver
--   {coins:f}        copper, banded                            a few gold
--   {items:f}        trade entries                             five [Silk Cloth] and a [Lesser Healing Potion]
--   {item:f}         the first trade entry                     a [Lesser Healing Potion]
--   {list:f}         a list of strings                         Ashenvale and Stonetalon Mountains
--   {v:f}            the value as it is                        Astranaar
--   {at:f} {in:f}    with a preposition                        at Astranaar / in Ashenvale
--   {pct:f}          a percentage                              6%
--   {foe:f}          a creature { name, rank }                 a Thistlefur Shaman / Mor'Ladim
--   {foename:f}      its name only
--   {rank:f}         its rank as a word                        elite / rare elite
--   {score}          won and lost, winner's side first          three to one / two each
--
-- Page slots (from plan.page)
--   {part}           evening / afternoon / morning / night
--   {today}          tonight / this afternoon / this morning
--   {zones}          the session's zones as a list

local addonName, ns = ...

local Pages = ns.Pages
local Get = Pages.Get

local function Lang()
    return Pages.Lang
end

--------------------------------------------------------------------------
-- People
--------------------------------------------------------------------------

local function PersonPath(args)
    return args[1] and args[1] ~= "" and args[1] or "who"
end

local function Person(env, args)
    local p = Get(env.f, PersonPath(args))
    if type(p) ~= "table" then return nil end
    return p
end

local function PersonNeeds(args)
    return { PersonPath(args) }
end

local function Mention(env, p)
    local key = p.id or p.name or tostring(p)
    env.staged.mentioned[key] = true
    env.staged.last = key
    env.staged.para[key] = p
end

Pages.Slot("ref", {
    needs = PersonNeeds,
    fn = function(env, args, mods)
        local p = Person(env, args)
        if not p then return nil end
        local case = (mods.obj and "obj") or (mods.poss and "poss") or "subj"
        return Pages.Refer(env, p, case, mods)
    end,
})

Pages.Slot("name", {
    needs = function(args) return { PersonPath(args) .. ".name" } end,
    fn = function(env, args, mods)
        local p = Person(env, args)
        if not p or not p.name then return nil end
        Mention(env, p)
        if mods.poss then return Lang().Possessive(p.name) end
        return p.name
    end,
})

Pages.Slot("desc", {
    needs = PersonNeeds,
    fn = function(env, args)
        local p = Person(env, args)
        if not p then return nil end
        Mention(env, p)
        return Pages.Describe(p)
    end,
})

local function PronounSlot(case)
    return {
        needs = PersonNeeds,
        fn = function(env, args, mods)
            local p = Person(env, args)
            if not p then return nil end
            local set = Pages.PRONOUNS[p.sex]
            if set then
                Mention(env, p)
                return set[case]
            end
            return Pages.Refer(env, p, case, { noun = true, short = true })
        end,
    }
end
Pages.Slot("he", PronounSlot("subj"))
Pages.Slot("him", PronounSlot("obj"))
Pages.Slot("his", PronounSlot("poss"))

Pages.Slot("class", {
    needs = function(args) return { PersonPath(args) .. ".class" } end,
    fn = function(env, args)
        local p = Person(env, args)
        return p and p.class and Lang().Lower(p.class)
    end,
})

Pages.Slot("race", {
    needs = function(args) return { PersonPath(args) .. ".race" } end,
    fn = function(env, args)
        local p = Person(env, args)
        if not (p and p.race) then return nil end
        return Pages.LOWER_RACES and Lang().Lower(p.race) or p.race
    end,
})

Pages.Slot("epithet", {
    needs = function(args) return { PersonPath(args) .. ".relationship" } end,
    fn = function(env, args)
        local p = Person(env, args)
        return p and Pages.Epithet(p)
    end,
})

--------------------------------------------------------------------------
-- Formatters
--------------------------------------------------------------------------

local F = Pages.Format

F("num", function(v) return type(v) == "number" and Lang().Num(v) or nil end)
F("digits", function(v) return type(v) == "number" and Lang().Digits(v) or nil end)
F("times", function(v) return type(v) == "number" and Lang().Times(v) or nil end)
F("nth", function(v) return type(v) == "number" and Lang().Nth(v) or nil end)
F("lvl", function(v) return type(v) == "number" and tostring(v) or nil end)

F("count", function(v, env, args)
    if type(v) ~= "number" or not args[2] then return nil end
    return Lang().Count(v, args[2], args[3])
end)
F("counta", function(v, env, args)
    if type(v) ~= "number" or not args[2] then return nil end
    return Lang().CountA(v, args[2], args[3])
end)

F("levels", function(v)
    if type(v) ~= "number" then return nil end
    if v == 1 then return "a level" end
    return Lang().Count(v, "level")
end)

F("days", function(v) return type(v) == "number" and Lang().Days(v) or nil end)
F("daysx", function(v) return type(v) == "number" and Lang().Days(v, true) or nil end)
F("dayadj", function(v) return type(v) == "number" and Lang().DayAdj(v) or nil end)
F("ago", function(v) return type(v) == "number" and Lang().Ago(v) or nil end)
F("agox", function(v) return type(v) == "number" and Lang().Ago(v, true) or nil end)
F("when", function(v, env)
    if type(v) ~= "number" or not env.plan.now then return nil end
    return Lang().When(v, env.plan.now)
end)
F("date", function(v, env)
    if type(v) ~= "number" or not env.plan.now then return nil end
    return Lang().Date(v, env.plan.now)
end)
F("dur", function(v) return type(v) == "number" and Lang().Duration(v) or nil end)
F("secs", function(v) return type(v) == "number" and Lang().Seconds(v) or nil end)
F("share", function(v, env)
    local page = env.f.page or {}
    if type(v) ~= "number" or not page.seconds then return nil end
    return Lang().Share(v, page.seconds, page.part)
end, { alsoNeeds = { "page.seconds" } })

F("money", function(v) return type(v) == "number" and Lang().Money(v) or nil end)
F("coins", function(v) return type(v) == "number" and Lang().Coins(v) or nil end)
F("items", function(v) return type(v) == "table" and Lang().Items(v) or nil end)
F("item", function(v) return type(v) == "table" and v[1] and Lang().Item(v[1]) or nil end)
F("list", function(v) return type(v) == "table" and Lang().List(v) or nil end)

F("v", function(v) return tostring(v) end)
F("at", function(v) return "at " .. tostring(v) end)
F("in", function(v) return "in " .. tostring(v) end)
F("pct", function(v) return type(v) == "number" and (math.floor(v + 0.5) .. "%") or nil end)

local NAMED_RANKS = { rare = true, rareelite = true, worldboss = true }
local RANK_WORDS = {
    elite = "elite", rare = "rare", rareelite = "rare elite", worldboss = "world boss",
    trivial = "trivial", minus = "minor", normal = "ordinary",
}

-- A creature: rares and bosses have their own names ("Mor'Ladim"),
-- everything else is one of many ("a Thistlefur Shaman").
F("foe", function(v)
    if type(v) ~= "table" or not v.name then return nil end
    if NAMED_RANKS[v.rank] then return v.name end
    return Lang().A(v.name)
end)
F("foename", function(v) return type(v) == "table" and v.name or nil end)
F("rank", function(v)
    if type(v) ~= "table" or not v.rank then return nil end
    return RANK_WORDS[v.rank]
end)

-- Numbers where zero counts: needs only that the fact is there.
local function ZeroOk(name, fn)
    Pages.Slot(name, {
        needs = function(args) return { args[1] .. " ~= __nil" } end,
        says = function(args) return { args[1] } end,
        fn = function(env, args)
            local v = args[1] and Get(env.f, args[1])
            if type(v) ~= "number" then return nil end
            return fn(v)
        end,
    })
end
ZeroOk("num0", function(v) return Lang().Zero(v) end)

-- A duel score from won and lost, the winner's side first whoever won:
-- "three to one", "three to nothing", "two each". The words around it say
-- who won ("I beat {ref.obj} {score}", "{ref} beat me {score}").
Pages.Slot("score", {
    needs = function() return { "won ~= __nil", "lost ~= __nil" } end,
    says = function() return { "won", "lost" } end,
    fn = function(env)
        local won, lost = env.f.won, env.f.lost
        if type(won) ~= "number" or type(lost) ~= "number" then return nil end
        local L = Lang()
        if won == lost then return L.Num(won) .. " each" end
        local function Side(n) return n == 0 and "nothing" or L.Num(n) end
        local hi, lo = math.max(won, lost), math.min(won, lost)
        return Side(hi) .. " to " .. Side(lo)
    end,
})

--------------------------------------------------------------------------
-- The page
--------------------------------------------------------------------------

Pages.Slot("part", {
    needs = function() return { "page.part" } end,
    fn = function(env) return env.f.page and env.f.page.part end,
})

-- "tonight" says the hour, so two sentences about one person don't both
-- start with it.
Pages.Slot("today", {
    needs = function() return { "page.part" } end,
    says = function() return { "page.part" } end,
    fn = function(env) return env.f.page and Lang().Today(env.f.page.part) end,
})

Pages.Slot("zones", {
    needs = function() return { "page.zones" } end,
    says = function() return { "page.zones" } end,
    fn = function(env) return env.f.page and Lang().List(env.f.page.zones) end,
})
