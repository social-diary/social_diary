-- How much each candidate beat would change the reader's picture of this
-- relationship (experimental, planner stage 2): a tier, from the beat's
-- kind and the relationship's own history.
--
-- Four tiers, not scores (the planner's design, 28 Oct 2026):
--   Headline  could be the point of the row
--   Notable   worth a sentence of its own
--   Texture   colour, not news: a stem or a tail, or nothing
--   Ledger    a fact, not a story: the details line only
--
-- Each kind starts at a tier (RULES). Each "up" that applies lifts it one,
-- two at most; each "down" drops it one. Then, for every kind: "around"
-- (nothing to do with them) drops one, a probable beat is never above
-- Notable, and a beat the run covers is Ledger. A beat that shows them
-- badly (their deaths, their watching me die) keeps its tier but may not
-- be the point, unless they are tagged foe or avoid.
--
-- The user's decisions: my own milestone may be the point on their row
-- (a round level is Notable with them there, the cap a Headline).
--
-- Stage 2 only weighs: SessionProse.Point shows which beat would lead, for
-- the trace and for checking against the user's own picks. Choosing what
-- else goes in, and the budget, are stage 3's.

local addonName, ns = ...

local SessionProse = ns.UI.SessionProse or {}
ns.UI.SessionProse = SessionProse

local LEDGER, TEXTURE, NOTABLE, HEADLINE = 1, 2, 3, 4
local TIER_NAMES = { "Ledger", "Texture", "Notable", "Headline" }
SessionProse.TIERS = { LEDGER = LEDGER, TEXTURE = TEXTURE, NOTABLE = NOTABLE, HEADLINE = HEADLINE,
    names = TIER_NAMES }

-- What a routine is: this share of recent sessions, or this many times in
-- the same form.
local ROUTINE_SHARE, ROUTINE_TIMES = 0.5, 5
-- A gap only this much over our usual one is no news.
local LITTLE_OVER_USUAL = 1.5
-- My deaths are a rough patch at this many, and this many times my rate.
local ROUGH_DEATHS, ROUGH_RATE = 3, 2
-- A session is "our longest yet" only once there are this many before it.
local RECORD_AFTER = 3

local function Runs(c)
    c.runs = c.runs or SessionProse.RunsBefore(c.visit, c.guid)
    return c.runs
end

-- Each rule: { why, kind, test(c, h), step = 1, must = tag }. The kind
-- breaks ties between points: a first beats a record beats a size. `must`
-- is the fact that says why, when the words have one: a lead beat must
-- say it (stage 3), or it isn't the point.
local RULES = {
    ["rescue/saved"] = { start = HEADLINE,
        up = { { "the first time", "first", function(c) return c.facts.firstByThem end, must = "firstByThem" } } },
    ["rescue/helped"] = { start = NOTABLE,
        up = { { "the first time", "first", function(_, h) return (h.rows.tried_to_help or 0) == 0 end } } },
    ["witness/watched"] = { start = TEXTURE },
    ["new_face/meet"] = { start = HEADLINE },
    ["new_face/added"] = { start = HEADLINE },
    ["reunion/gap"] = { start = HEADLINE,
        up = { { "our longest gap", "record", function(c) return c.facts.isRecordGap end, must = "isRecordGap" } },
        down = { { "only a little over our usual gap", nil, function(c, h)
            return h.usualGapDays and c.facts.gapDays < LITTLE_OVER_USUAL * h.usualGapDays
        end } } },
    ["dungeon/run"] = { start = NOTABLE,
        up = {
            { "our first run there", "first", function(c) return Runs(c).here == 0 end },
            { "my first clear", "first", function(c) return c.facts.firstClear end, must = "firstClear" },
            { "a full clear", "size", function(c) return c.facts.fullClear end, must = "fullClear" },
        },
        down = { { "we've done it five times or more", nil, function(c) return Runs(c).here >= ROUTINE_TIMES end } } },
    ["dungeon/trouble"] = { start = LEDGER,
        up = { { "more wipes than our usual", "size", function(c)
            local wipes = c.facts.wipes or 0
            return wipes >= 2 and wipes > (Runs(c).wipesPerRun or 0)
        end } } },
    ["dungeon/loot"] = { start = LEDGER },
    -- One step for both, as the design's first example has it (Notable):
    -- a roll stands out of its run only when it was close and ours.
    ["dungeon/roll"] = { start = TEXTURE,
        up = { { "ours, within three points", "size", function(c)
            return c.involvement == "between" and c.facts.close
        end } } },
    ["trade/gift"] = "trade", ["trade/given"] = "trade", ["trade/swap"] = "trade",
    trade = { start = NOTABLE,
        up = {
            { "our first trade", "first", function(c) return c.facts.first end, must = "first" },
            { "returning a favour", "first", function(c) return c.facts.returned end, must = "returned" },
        },
        down = { { "routine between us", nil, function(c, h)
            return not c.facts.first and (h.tradeShare or 0) >= ROUTINE_SHARE
        end } } },
    ["chat/heard"] = { start = LEDGER,
        up = { { "the first whispers", "first", function(c) return c.facts.firstWhisper end, must = "firstWhisper" } } },
    ["campfire/sat"] = { start = TEXTURE,
        up = { { "the first time at my fire", "first", function(c) return c.facts.firstTime end, must = "firstTime" } } },
    ["ding/level"] = { start = TEXTURE,
        up = { { "a round level or the cap", "size", function(c) return c.facts.round or c.facts.cap end } } },
    ["together/rares"] = { start = TEXTURE,
        up = {
            { "killed together", "size", function(c) return c.facts.rareKilled end },
            { "our first rare", "first", function(_, h) return h.raresBefore == 0 end },
        } },
    ["parity/levels"] = { start = TEXTURE,
        up = { { "the lead changed hands", "record", function(c) return c.facts.crossed end, must = "crossed" } },
        down = { { "the gap hasn't moved", nil, function(c)
            return c.facts.diffThen ~= nil and c.facts.diffThen == c.facts.levelDiff
        end } } },
    ["together/time"] = { start = TEXTURE,
        up = { { "our longest session yet", "record", function(c, h)
            return #h.prior >= RECORD_AFTER and (c.facts.seconds or 0) > (h.longestSeconds or 0)
        end } } },
    ["together/deaths"] = { start = LEDGER,
        up = { { "well above my usual rate", "size", function(c, h)
            local mine = c.facts.myDeaths or 0
            local hours = math.max(1, (c.facts.seconds or 3600) / 3600)
            return mine >= ROUGH_DEATHS and h.myDeathsPerHour ~= nil and mine / hours >= ROUGH_RATE * h.myDeathsPerHour
        end } } },
    ["open/climb"] = { start = LEDGER, around = false,
        up = { { "my milestone, with them there", "size", function(c) return c.facts.milestone end,
            step = 2, must = "milestone" } },
        set = { { "my level cap, with them there", HEADLINE, function(c) return c.facts.reachedCap end,
            must = "reachedCap" } } },
}

local function Rule(c)
    local rule = RULES[c.angle .. "/" .. c.move]
    if type(rule) == "string" then rule = RULES[rule] end
    return rule or { start = LEDGER }
end

local SURPRISE = { first = 3, record = 2, size = 1 }

local function Tagged(c)
    local who = c.facts.who or c.facts.friend
    local tags = who and who.tags or {}
    return tags.foe or tags.avoid
end

-- A kind that led this many of the last rows (SessionProse.RECENT_LEADS)
-- drops a tier, unless this one is bigger than those were.
local LED_RECENTLY = 2

-- Sets each candidate's tier, startTier, reasons ("+our first clear"),
-- surprise (the strongest "up" kind, for ties), musts (the facts that say
-- why it rose, strongest first) and noLead. `ledger` is what the rows
-- before this one told (UI/Words/SessionLedger.lua), or nil.
function SessionProse.Weigh(list, h, ledger)
    for _, c in ipairs(list) do
        local rule = Rule(c)
        local tier, ups, reasons, surprise, musts = rule.start, 0, {}, 0, {}
        for _, up in ipairs(rule.up or {}) do
            if ups < 2 and up[3](c, h) then
                local step = math.min(up.step or 1, 2 - ups)
                tier, ups = tier + step, ups + step
                reasons[#reasons + 1] = "+" .. up[1]
                surprise = math.max(surprise, SURPRISE[up[2]] or 0)
                if up.must then musts[#musts + 1] = up.must end
            end
        end
        for _, down in ipairs(rule.down or {}) do
            if down[3](c, h) then
                tier = tier - 1
                reasons[#reasons + 1] = "-" .. down[1]
            end
        end
        for _, set in ipairs(rule.set or {}) do
            if set[3](c, h) and set[2] > tier then
                tier = set[2]
                reasons[#reasons + 1] = "=" .. set[1]
                if set.must then musts = { set.must } end
            end
        end
        -- Not the same lead row after row: a daily companion's page
        -- shouldn't say "two hours together" every day.
        if ledger then
            local kind, led, top = c.angle .. "/" .. c.move, 0, 0
            for _, r in ipairs(ledger.recent) do
                if r.kind == kind then led, top = led + 1, math.max(top, r.tier or 0) end
            end
            if led >= LED_RECENTLY and tier <= top then
                tier = tier - 1
                reasons[#reasons + 1] = ("-led %d of the last %d rows"):format(led, #ledger.recent)
            end
        end
        if c.involvement == "around" and rule.around ~= false then
            tier = tier - 1
            reasons[#reasons + 1] = "-nothing to do with them"
        end
        if c.coveredBy then
            tier = LEDGER
            reasons[#reasons + 1] = "-said through the " .. c.coveredBy
        end
        if c.probable and tier > NOTABLE then
            tier = NOTABLE
            reasons[#reasons + 1] = "-probable"
        end
        c.startTier = rule.start
        c.tier = math.max(LEDGER, math.min(HEADLINE, tier))
        c.reasons, c.surprise, c.musts = reasons, surprise, musts
        c.noLead = (c.probable or (c.sensitive and not Tagged(c))) or nil
    end
    return list
end

local INVOLVEMENT = { between = 4, together = 3, company = 2, around = 1 }

-- Whether a is a better point than b: the tier, then involvement, then
-- surprise, then an event over a state, then the later event (outcomes
-- read better than process).
local function Better(a, b)
    if a.tier ~= b.tier then return a.tier > b.tier end
    local ia, ib = INVOLVEMENT[a.involvement] or 0, INVOLVEMENT[b.involvement] or 0
    if ia ~= ib then return ia > ib end
    if a.surprise ~= b.surprise then return a.surprise > b.surprise end
    -- Something that happened before a standing state (our levels side by
    -- side, the time together).
    if (a.state or false) ~= (b.state or false) then return not a.state end
    return (a.time or 0) > (b.time or 0)
end
SessionProse.Better = Better

-- The beat that would lead the row, or nil for a quiet one (nothing at
-- Notable or above that may lead).
function SessionProse.Point(list)
    local best
    for _, c in ipairs(list) do
        if not c.noLead and c.tier >= NOTABLE and (not best or Better(c, best)) then best = c end
    end
    return best
end

function SessionProse.TierName(tier)
    return TIER_NAMES[tier] or "?"
end
