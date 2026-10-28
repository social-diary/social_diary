-- Duel: a series of friendly duels with someone, the score, who took the
-- last one, sweeps, first duels and the running all-time tally.
--
-- series facts
--   who               the person (usually friendly, often named)
--   won, lost         duels I won and lost in this series (0 counts)
--   total             won + lost
--   lastWon, lastLost who took the last duel of the series (one of them)
--   swept             I won every one, two or more
--   wasSwept          they won every one, two or more
--   even              won == lost
--   first             our first duels ever (then the all-time tally is
--                     just this series, and nothing says "overall")
--   allWon, allLost   all-time, this series included
--   zone, subZone     where I was
--
-- The contract gives no flag for who won the series, and {score} reads
-- "one to three" when I lost, so this file declares its own score slots
-- that put the bigger side first and refuse the wrong direction (a piece
-- whose slot refuses is simply not written, and the next is tried):
--
--   {duel_score:mine}         the series score when I won more: "three to one"
--   {duel_score:theirs}       when they won more, theirs first: "three to one"
--   {duel_score:even}         when level: "two each"
--   {duel_score:mine:close}   ...and only by a single duel ("three to two")
--   {duel_score:mine:wide}    ...and only by three or more ("four to one")
--   {duel_all:mine|theirs|even[:close|wide]}  the same for the all-time tally
--   {duel_all:duels}          all-time duels as a count: "eighteen duels"
--   {duel_if:test}            says nothing, and lets its piece be written only
--                             when the test holds: ahead, behind, notAhead,
--                             notBehind, ahead1, behind1, close (a margin of
--                             one or none), wide (three or more), both (each
--                             of us won at least one), allAhead,
--                             allBehind, allEven; from the tallies before
--                             this series: firstWin (my first win against
--                             them ever), firstLoss, unbeaten (they have never
--                             beaten me, 3+ duels), neverBeaten, tookLead (I
--                             went ahead all-time in this series), lostLead,
--                             levelled (the all-time tally drew level); and
--                             named (the person goes by
--                             name, for the terse "Brennick one, me three")
--
-- Scores need at least two duels: a single duel is told as a win or a loss.
-- {duel_all} and {duel_if:all...} need "!first".
--
-- Every sentence must say both won and lost. A piece that tells the result
-- another way ("I beat her three times running", "and I won two of them"
-- after a count) declares the side it leaves implied in `says`. Clauses and
-- fragments that don't give the result always give the count of duels, so a
-- tail like ", and I won two of them" has something to count from.

local addonName, ns = ...

local Pages = ns.Pages
local Words = Pages.Words

Pages.Angle("duel", { order = { "series" }, about = "a series of friendly duels" })

--------------------------------------------------------------------------
-- Slots
--------------------------------------------------------------------------

local function Lang()
    return Pages.Lang
end

local function Side(n)
    if n == 0 then return "nothing" end
    return Lang().Num(n)
end

-- The bigger side first: "three to one", "two to nothing", "two each".
local function Pair(a, b)
    if a == b then return Lang().Num(a) .. " each" end
    if a > b then return Side(a) .. " to " .. Side(b) end
    return Side(b) .. " to " .. Side(a)
end

local function Fits(mode, a, b, margin)
    if mode == "mine" then
        if a <= b then return false end
    elseif mode == "theirs" then
        if b <= a then return false end
    elseif mode == "even" then
        if a ~= b then return false end
    else
        return false
    end
    local gap = math.abs(a - b)
    if margin == "close" and gap ~= 1 then return false end
    if margin == "wide" and gap < 3 then return false end
    return true
end

local function Nums(...)
    local t = { ... }
    for i = 1, #t do
        if type(t[i]) ~= "number" then return false end
    end
    return true
end

-- The conditions a direction needs, so a piece is only eligible when its
-- score reads true (the margins, close and wide, are checked when written).
local DIRECTION = {
    mine = { "won>@lost" }, theirs = { "lost>@won" }, even = { "won==@lost" },
}
local ALL_DIRECTION = {
    mine = { "allWon>@allLost" }, theirs = { "allLost>@allWon" }, even = { "allWon==@allLost" },
}

local function Join(...)
    local out = {}
    for _, list in ipairs({ ... }) do
        for i = 1, #list do out[#out + 1] = list[i] end
    end
    return out
end

Pages.Slot("duel_score", {
    needs = function(args)
        return Join({ "won ~= __nil", "lost ~= __nil", "total>=2" }, DIRECTION[args[1]] or {})
    end,
    says = function() return { "won", "lost" } end,
    fn = function(env, args)
        local a, b = env.f.won, env.f.lost
        if not Nums(a, b) or a + b < 2 then return nil end
        if not Fits(args[1], a, b, args[2]) then return nil end
        return Pair(a, b)
    end,
})

Pages.Slot("duel_all", {
    needs = function(args)
        return Join({ "allWon ~= __nil", "allLost ~= __nil", "!first" }, ALL_DIRECTION[args[1]] or {})
    end,
    says = function() return { "allWon", "allLost" } end,
    fn = function(env, args)
        local a, b = env.f.allWon, env.f.allLost
        if not Nums(a, b) or a + b < 2 then return nil end
        if args[1] == "duels" then return Lang().Count(a + b, "duel") end
        if not Fits(args[1], a, b, args[2]) then return nil end
        return Pair(a, b)
    end,
})

local TESTS = {
    ahead = function(f) return f.won > f.lost end,
    behind = function(f) return f.lost > f.won end,
    notAhead = function(f) return f.won <= f.lost end,
    notBehind = function(f) return f.won >= f.lost end,
    ahead1 = function(f) return f.won - f.lost == 1 end,
    behind1 = function(f) return f.lost - f.won == 1 end,
    close = function(f) return math.abs(f.won - f.lost) <= 1 end,
    wide = function(f) return math.abs(f.won - f.lost) >= 3 end,
    allAhead = function(f) return f.allWon > f.allLost end,
    allBehind = function(f) return f.allLost > f.allWon end,
    allEven = function(f) return f.allWon == f.allLost end,
    both = function(f) return f.won >= 1 and f.lost >= 1 end,
    -- From the tallies before this series (all-time minus this one).
    firstWin = function(f) return f.won >= 1 and f.allWon == f.won and f.allLost > f.lost end,
    firstLoss = function(f) return f.lost >= 1 and f.allLost == f.lost and f.allWon > f.won end,
    unbeaten = function(f) return f.allLost == 0 and f.allWon >= 3 and f.allWon > f.won end,
    neverBeaten = function(f) return f.allWon == 0 and f.allLost >= 3 and f.allLost > f.lost end,
    tookLead = function(f) return f.allWon > f.allLost and (f.allWon - f.won) <= (f.allLost - f.lost) end,
    lostLead = function(f) return f.allLost > f.allWon and (f.allLost - f.lost) <= (f.allWon - f.won) end,
    levelled = function(f) return f.allWon == f.allLost and (f.allWon - f.won) ~= (f.allLost - f.lost) end,
    named = function(f) return type(f.who) == "table" and f.who.name and (f.who.diary or f.who.named) and true or false end,
}

local ALLTESTS = { firstWin = true, firstLoss = true, unbeaten = true, neverBeaten = true,
    tookLead = true, lostLead = true, levelled = true }

-- The conditions each test can state up front, so pieces gated on it are
-- only eligible when it holds; the rest is checked when written.
local TEST_NEEDS = {
    ahead = { "won>@lost" }, behind = { "lost>@won" },
    notAhead = { "won<=@lost" }, notBehind = { "won>=@lost" },
    ahead1 = { "won>@lost" }, behind1 = { "lost>@won" },
    wide = { "total>=3", "!even" }, both = { "won>=1", "lost>=1" },
    allAhead = { "allWon>@allLost" }, allBehind = { "allLost>@allWon" }, allEven = { "allWon==@allLost" },
    firstWin = { "won>=1", "allLost>@lost" }, firstLoss = { "lost>=1", "allWon>@won" },
    unbeaten = { "allWon>=3", "allLost==0", "allWon>@won" }, neverBeaten = { "allLost>=3", "allWon==0", "allLost>@lost" },
    tookLead = { "allWon>@allLost", "won>@lost" }, lostLead = { "allLost>@allWon", "lost>@won" },
    levelled = { "allWon==@allLost", "!even" },
    named = { "who.name" },
}

Pages.Slot("duel_if", {
    needs = function(args)
        local list = { "won ~= __nil", "lost ~= __nil" }
        if args[1] and (args[1]:sub(1, 3) == "all" or ALLTESTS[args[1]]) then
            list = Join(list, { "allWon ~= __nil", "allLost ~= __nil", "!first" })
        end
        return Join(list, TEST_NEEDS[args[1] or ""] or {})
    end,
    says = function() return {} end,
    fn = function(env, args)
        local test = TESTS[args[1] or ""]
        local f = env.f
        if not test or not Nums(f.won, f.lost) then return nil end
        local needsAll = args[1]:sub(1, 3) == "all" or ALLTESTS[args[1]]
        if needsAll and (f.first or not Nums(f.allWon, f.allLost)) then return nil end
        return test(f) and "" or nil
    end,
})

-- What a piece says when it gives the result without a slot for one side.
local BOTH = { "won", "lost" }
local LOST = { "lost" }
local function Tags(...)
    local out = {}
    for _, list in ipairs({ ... }) do
        for i = 1, #list do out[#out + 1] = list[i] end
    end
    return out
end
local WON = { "won" }
-- Stems that only read before a result, and clauses that give only the
-- count, both say this, so they never meet.
local R = { "duel_countonly" }

--------------------------------------------------------------------------
-- series: the duels, and how they came out
--------------------------------------------------------------------------

Words("duel", "series", {
    must = { "won", "lost" },

    -- Openings. None names a winner, so any result clause can follow; the
    -- ones that give the count of duels pair with clauses that give the score.
    stems = {
        { "{at.cap:subZone}, ", says = { "place" } },
        { "{in.cap:zone}, ", bonus = -0.5, says = { "place" } },
        { "After {count:total:duel}, ", needs = { "total>=2", "!swept", "!wasSwept", "!first" } },
        { "Over {count:total:duel} {in:zone}, ", needs = { "total>=2", "!swept", "!wasSwept", "!first" }, says = { "place" } },
        { "When it was all over, ", needs = { "total>=2" }, says = R },
        { "By the end, ", needs = { "total>=2" }, says = R },
        { "All told, ", needs = { "total>=2" }, says = R },
        { "In our first duels, ", needs = { "first", "total>=2" }, says = Tags(R, { "duel_wordtwice" }) },
        { "{count.cap:total:duel} with {ref.obj}, and ", needs = { "total>=2", "!swept", "!wasSwept", "!first" }, says = { "duel_refstem" } },
        { "{ref.short} and I duelled {at:subZone}, and ", needs = { "total>=2" }, says = Tags(R, { "place" }) },
        { "{ref.short} and I went at it {times:total}, and ", needs = { "total>=3", "!swept", "!wasSwept", "!first" }, says = { "duel_refstem" } },
        { "Rematch after rematch, and ", needs = { "total>=4" }, says = R },
        { "{duel_if:close}It was close, and ", needs = { "total>=3" }, says = R, bonus = 0.5 },
        { "{duel_if:wide}It wasn't close: ", voice = "wry", says = R },
        { "{duel_if:allBehind}{duel_if:ahead}For once, ", needs = { "!first", "won>=1" }, voice = "wry", says = R },
        { "With pride on the line, ", voice = "wry" },
        { "In the name of honour, ", voice = "wry" },
        { "[Purely for sport|For the fun of it], ", voice = "warm" },
        { "Duels with {ref.obj}: ", needs = { "total>=2" }, voice = "terse", says = R },
        { "Duels with {ref.obj} {in:zone}: ", needs = { "total>=2" }, voice = "terse", says = Tags(R, { "place" }) },
        { "{count.cap:total:duel} with {ref.obj}: ", needs = { "total>=2" }, voice = "terse", says = R },
        { "Result {at:subZone}: ", voice = "terse", says = Tags(R, { "place" }) },
    },

    clauses = {
        -- The count only: a tail or stem gives the result.
        { "{ref} and I duelled {times:total}", needs = { "total>=2" }, says = R },
        { "I duelled {ref.obj} {times:total}", needs = { "total>=2" }, says = R },
        { "{ref} and I fought {count:total:duel}", needs = { "total>=2" }, says = R },
        { "{ref} and I squared off {times:total} {at:subZone}", needs = { "total>=2" }, says = Tags(R, { "place" }) },
        { "{ref} and I went at it {times:total}", needs = { "total>=2" }, says = R },
        { "{ref} and I duelled {times:total} {in:zone}", needs = { "total>=2" }, bonus = -0.5, says = Tags(R, { "place" }) },
        { "I took on {ref.obj} {times:total}", needs = { "total>=2" }, says = R },
        { "{ref} and I duelled for the first time, {count:total:duel} in all", needs = { "first", "total>=2" }, says = R },
        { "{ref} and I had our first duels {at:subZone}, {count:total:duel} of them", needs = { "first", "total>=2" }, says = Tags(R, { "place" }) },
        { "{ref} and I crossed swords {times:total}", needs = { "total>=2" }, voice = "wry", says = R },
        { "I had a fine time duelling {ref.obj}, {count:total:duel} in all", needs = { "total>=2" }, voice = "warm", says = R },

        -- The result, either way.
        { "I won {num:won} and lost {num:lost} against {ref.obj}", says = { "duel_refstem" } },
        { "{ref} won {num:lost} and I won {num:won}" },
        { "I took {num:won} of {count:total:duel} off {ref.obj}", needs = { "!swept", "total>=2" }, says = LOST },
        { "{ref} took {num:lost} of {count:total:duel} off me", needs = { "!wasSwept", "total>=2" }, says = WON },

        -- I won more.
        "I beat {ref.obj} {duel_score:mine}",
        "I had the better of {ref.obj}, {duel_score:mine}",
        { "the duels with {ref.obj} went my way, {duel_score:mine}", says = { "duel_wordtwice" } },
        "I finished {duel_score:mine} up on {ref.obj}",
        { "I edged {ref.obj} {duel_score:mine:close}", bonus = 0.25 },
        { "I beat {ref.obj} comfortably, {duel_score:mine:wide}", bonus = 0.25 },
        { "I beat {ref.obj} {duel_score:mine}, and I intend to mention it", voice = "wry", final = true },

        -- They won more.
        "{ref} beat me {duel_score:theirs}",
        "I lost to {ref.obj} {duel_score:theirs}",
        "{ref} had the better of me, {duel_score:theirs}",
        { "the duels went {ref.poss} way, {duel_score:theirs}", says = { "duel_wordtwice" } },
        "{ref} finished {duel_score:theirs} up on me",
        { "{ref} edged me {duel_score:theirs:close}", bonus = 0.25 },
        { "{ref} beat me soundly, {duel_score:theirs:wide}", bonus = 0.25 },
        { "{ref} beat me {duel_score:theirs}, and I'd rather not discuss it", voice = "wry", final = true },
        { "{ref} gave me a lesson, {duel_score:theirs:wide}", voice = "wry" },

        -- Level.
        { "{ref} and I finished {score}", needs = { "even" } },
        { "{ref} and I ended up level at {score}", needs = { "even" } },
        { "{ref} and I couldn't be separated, {score}", needs = { "even" } },
        { "{ref} and I split {count:total:duel} evenly", needs = { "even" }, says = BOTH },
        { "honours were even with {ref.obj} at {score}", needs = { "even" } },

        -- Sweeps.
        { "I beat {ref.obj} {times:total} running", needs = { "swept" }, says = BOTH },
        { "I won every one of {count:total:duel} against {ref.obj}", needs = { "swept", "total>=3" }, says = BOTH },
        { "I won both my duels against {ref.obj}", needs = { "swept", "total==2" }, says = BOTH },
        { "I didn't drop a single duel to {ref.obj}", needs = { "swept" }, says = BOTH },
        { "{ref} beat me {times:total} running", needs = { "wasSwept" }, says = BOTH },
        { "{ref} won all {num:total} of our duels", needs = { "wasSwept", "total>=3" }, says = BOTH },
        { "{ref} won both our duels", needs = { "wasSwept", "total==2" }, says = BOTH },
        { "I couldn't take a single duel off {ref.obj}", needs = { "wasSwept" }, says = BOTH },

        -- First duels, with the result.
        { "I won our first ever duels against {ref.obj}, {duel_score:mine}", needs = { "first" } },
        { "{ref} won our first ever duels, {duel_score:theirs}", needs = { "first" } },
        { "{ref} and I finished our first duels {score}", needs = { "first", "even" } },

        -- A single duel.
        { "I beat {ref.obj} in a single duel", needs = { "total==1", "won==1" }, says = Tags(BOTH, { "total" }) },
        { "{ref} beat me in the one duel we fought", needs = { "total==1", "lost==1" }, says = Tags(BOTH, { "total" }) },
        { "{ref} and I duelled just the once, and I won", needs = { "total==1", "won==1" }, says = Tags(BOTH, { "total" }), final = true },
        { "{ref} and I duelled once, and {ref} won", needs = { "total==1", "lost==1" }, says = Tags(BOTH, { "total" }), final = true },
        { "I lost a duel to {ref.obj}", needs = { "total==1", "lost==1" }, says = Tags(BOTH, { "total" }) },
        { "I won a duel against {ref.obj}", needs = { "total==1", "won==1" }, says = Tags(BOTH, { "total" }) },
    },
})

-- Fragments and the voiced clauses. NC marks a piece that gives no count of
-- duels (and a tail that needs one before it, "and I won two of them"), so
-- the two never meet.
local NC = { "duel_nocount" }

Words("duel", "series", {
    clauses = {
        { "I beat {ref.obj} {duel_score:mine} and enjoyed every minute", voice = "warm", final = true },
        { "{ref} beat me {duel_score:theirs}, and I enjoyed every one anyway", voice = "warm", final = true },
        { "{ref} and I had a good-natured run of {count:total:duel}", needs = { "total>=2" }, voice = "warm", says = R },
        { "I beat {ref.obj} fair and square, {duel_score:mine}", voice = "warm" },
        { "{ref} won fair and square, {duel_score:theirs}", voice = "warm" },
        { "{ref} wiped the floor with me, {duel_score:theirs:wide}", voice = "wry" },
        { "{ref} took me apart {times:total} running", needs = { "wasSwept", "total>=3" }, voice = "wry", says = BOTH },
        { "I won {duel_score:mine:close}, which is a win however you look at it", voice = "wry", final = true },
        { "I lost {duel_score:theirs:close}, which is practically a draw", voice = "wry", final = true },
        { "{ref} and I settled nothing at {score}", needs = { "even" }, voice = "wry" },
        { "I lost to {ref.obj} {duel_score:theirs}", voice = "terse" },
        { "I beat {ref.obj} {duel_score:mine}", voice = "terse" },
        { "{ref} and I drew, {score}", needs = { "even" }, voice = "terse" },
        { "I swept {ref.obj}, {num:total} to nothing", needs = { "swept" }, voice = "terse", says = BOTH },
    },

    fragments = {
        -- Count only: a tail gives the result.
        { "{count.cap:total:duel} with {ref.obj}", needs = { "total>=2" }, says = R },
        { "Duelled {ref.obj} {times:total}", needs = { "total>=2" }, says = R },
        { "Duelled {ref.obj} {times:total} {at:subZone}", needs = { "total>=2" }, says = Tags(R, { "place" }) },
        { "First duels with {ref.obj}", needs = { "first", "total>=2" }, says = Tags(R, NC) },
        { "Another round of duels with {ref.obj}", needs = { "!first", "total>=2" }, says = Tags(R, NC) },
        { "Duels with {ref.obj} {in:zone}", needs = { "total>=2" }, says = Tags(Tags(R, NC), { "place" }), bonus = -0.5 },
        { "Duels with {ref.obj} {at:subZone}", needs = { "total>=2" }, says = Tags(Tags(R, NC), { "place" }) },
        { "A duel with {ref.obj}", needs = { "total==1" }, says = R },

        -- With the result.
        "Beat {ref.obj} {duel_score:mine}",
        "Lost to {ref.obj} {duel_score:theirs}",
        "{duel_score.cap:theirs} to {ref.noun.short}{duel_if:named}{duel_if:both}",
        "{duel_score.cap:mine} to me against {ref.obj}{duel_if:both}",
        "Won {num:won} and lost {num:lost} against {ref.obj}",
        { "{score.cap} with {ref.obj}", needs = { "even" } },
        { "Level with {ref.obj}, {score}", needs = { "even" } },
        { "Honours even with {ref.obj}", needs = { "even" }, says = Tags(BOTH, NC) },
        { "A clean sweep of {ref.obj}, {num:total} to nothing", needs = { "swept" }, says = BOTH },
        { "Swept by {ref.obj}, {num:total} to nothing", needs = { "wasSwept" }, says = BOTH },
        { "{count.cap:total:duel} with {ref.obj} and not one lost", needs = { "swept" }, says = BOTH },
        { "{count.cap:total:duel} with {ref.obj} and not one won", needs = { "wasSwept" }, says = BOTH },
        { "One duel with {ref.obj}, and a win", needs = { "total==1", "won==1" }, says = BOTH },
        { "One duel with {ref.obj}, and a loss", needs = { "total==1", "lost==1" }, says = BOTH },
        { "Edged {ref.obj} {duel_score:mine:close}" },
        { "Edged out by {ref.obj}, {duel_score:theirs:close}" },
        { "Bested by {ref.obj}, {duel_score:theirs}", voice = "wry" },
        { "Thoroughly outduelled by {ref.obj}, {duel_score:theirs:wide}", voice = "wry" },
        { "A rare win over {ref.obj}, {duel_score:mine}{duel_if:allBehind}", voice = "wry" },
        { "Good sport with {ref.obj}, {score} in the end", needs = { "even" }, voice = "warm" },
        { "A fine few duels with {ref.obj}, {duel_score:mine} in my favour", needs = { "total>=3" }, voice = "warm" },
        { "A fine few duels with {ref.obj}, {duel_score:theirs} in {his} favour", needs = { "total>=3" }, voice = "warm" },
        { "Me {num0:won}, {ref.noun.short} {num0:lost}{duel_if:named}", needs = { "total>=2" }, voice = "terse" },
        { "{ref.noun.short} {num0:lost}, me {num0:won}{duel_if:named}", needs = { "total>=2" }, voice = "terse" },
        { "Duels against {ref.obj}: {num0:won} won, {num0:lost} lost", needs = { "total>=2" }, voice = "terse", final = true },
        { "Won {num0:won}, lost {num0:lost}, against {ref.obj}", needs = { "total>=2", "!swept", "!wasSwept" }, voice = "terse" },
        { "Swept {ref.obj}", needs = { "swept" }, voice = "terse", says = Tags(BOTH, NC) },
        { "Swept by {ref.obj}", needs = { "wasSwept" }, voice = "terse", says = Tags(BOTH, NC) },
    },

    tails = {
        -- The result, after a piece that gave only the count.
        { ", and I won {num:won} of them", needs = { "!swept", "total>=2" }, says = Tags(BOTH, NC) },
        { ", {num:won} of them mine", needs = { "total>=3", "!swept" }, says = Tags(BOTH, NC) },
        { ", and {ref} won {num:lost} of them", needs = { "!wasSwept", "total>=2" }, says = Tags(BOTH, NC) },
        { ", and I lost {num:lost} of them", needs = { "!wasSwept", "total>=2" }, says = Tags(BOTH, NC) },
        { ", {duel_score:mine} in my favour" },
        { ", {duel_score:theirs} in {ref.poss} favour" },
        { ", and I came out {duel_score:mine} ahead" },
        { ", and {ref} came out {duel_score:theirs} ahead" },
        { ", finishing {score}", needs = { "even" } },
        { ", {score} in the end", needs = { "even" } },
        { ", and we finished level", needs = { "even" }, says = Tags(BOTH, NC) },
        { ", and I won every one", needs = { "swept", "total>=3" }, says = Tags(BOTH, NC) },
        { ", and I won both", needs = { "swept", "total==2" }, says = Tags(BOTH, NC) },
        { ", and I didn't lose one", needs = { "swept" }, says = Tags(BOTH, NC) },
        { ", and I lost every one", needs = { "wasSwept", "total>=3" }, says = Tags(BOTH, NC) },
        { ", and I lost both", needs = { "wasSwept", "total==2" }, says = Tags(BOTH, NC) },
        { ", and I didn't win a single one", needs = { "wasSwept" }, says = Tags(BOTH, NC) },
        { ", and I won it", needs = { "total==1", "won==1" }, says = BOTH },
        { ", and {ref} won it", needs = { "total==1", "lost==1" }, says = BOTH },
        { ", and I won {num:won}, which I'm counting as a moral victory{duel_if:behind}", voice = "wry", says = Tags(BOTH, NC) },
        { ", and {he} won {duel_score:theirs}, not that I'm counting", voice = "wry" },
        { ", and {ref} took it {duel_score:theirs}, fair and square", voice = "warm" },

        -- After the result: who took the last one.
        { ", though {ref} took the last one{duel_if:ahead}", needs = { "lastLost==true", "total>=3" }, says = { "last" } },
        { ", though I took the last one{duel_if:behind}", needs = { "lastWon==true", "total>=3" }, says = { "last" } },
        { ", and I took the last one too{duel_if:ahead}", needs = { "lastWon==true", "!swept", "total>=3" }, says = { "last" }, bonus = -0.5 },
        { ", and {ref} took the last one too{duel_if:behind}", needs = { "lastLost==true", "!wasSwept", "total>=3" }, says = { "last" }, bonus = -0.5 },
        { ", and I only drew level by winning the last one", needs = { "even", "lastWon==true" }, says = { "last", "even" } },
        { ", and only because {ref} took the last one", needs = { "even", "lastLost==true" }, says = { "last", "even" } },
        { ", the last one deciding it{duel_if:ahead1}", needs = { "total>=3", "lastWon==true" }, says = { "last" } },
        { ", the last one deciding it{duel_if:behind1}", needs = { "total>=3", "lastLost==true" }, says = { "last" } },

        -- After the result: the all-time tally.
        { ", which puts me {duel_all:mine} up overall{duel_if:notBehind}" },
        { ", though I still lead {duel_all:mine} overall{duel_if:behind}" },
        { ", which puts {ref.obj} {duel_all:theirs} up overall{duel_if:notAhead}" },
        { ", though {ref} still leads {duel_all:theirs} overall{duel_if:ahead}" },
        { ", which leaves us level at {duel_all:even} all-time", bonus = 0.75 },
        { ", enough to put me ahead overall{duel_if:tookLead}", says = { "allWon", "allLost" }, bonus = 0.5 },
        { ", enough to put {ref.obj} ahead overall{duel_if:lostLead}", says = { "allWon", "allLost" }, bonus = 0.5 },
        { ", and {ref} still hasn't beaten me in a duel{duel_if:unbeaten}", says = { "allWon", "allLost" }, bonus = 0.5 },
        { ", and I still haven't beaten {ref.obj} in a duel{duel_if:neverBeaten}", says = { "allWon", "allLost" }, bonus = 0.5 },
        { ", my first win over {ref.obj} ever{duel_if:firstWin}", needs = { "won==1" }, says = { "allWon", "allLost" }, bonus = 0.5 },
        { ", my first wins over {ref.obj} ever{duel_if:firstWin}", needs = { "won>=2" }, says = { "allWon", "allLost" }, bonus = 0.5 },
        { ", and that's {duel_all:duels} between us all told", needs = { "allWon>=4", "total>=2" } },

        -- After the result: first duels, place, a reaction.
        { ", our first duels ever", needs = { "first", "total>=2" } },
        { ", the first time we'd ever duelled", needs = { "first" } },
        { ", and I'd happily go again", voice = "warm" },
        { ", and I enjoyed every one of them", needs = { "total>=2" }, voice = "warm" },
        { ", and no hard feelings{duel_if:behind}", voice = "warm" },
        { ", which I'll take with a smile{duel_if:ahead}", voice = "warm" },
        { ", the best sport I'd had in a while", voice = "warm" },
        { ", all in good fun", voice = "warm" },
        { ", and it was a good way to spend the {part}", voice = "warm" },
        { ", for the record{duel_if:ahead}", voice = "wry" },
        { ", which is all anyone needs to know{duel_if:ahead}", voice = "wry" },
        { ", and I want a rematch{duel_if:behind}", voice = "wry" },
        { ", and I was gracious about it, mostly{duel_if:ahead}", voice = "wry" },
        { ", which proves nothing except that I was right{duel_if:ahead}", voice = "wry" },
        { ", which settles nothing", needs = { "even" }, voice = "wry" },
        { ", and I've decided it was lag{duel_if:behind}", voice = "wry" },
        { ", which I'm sure builds character{duel_if:behind}", voice = "wry" },
        { ", easily{duel_if:wide}{duel_if:ahead}", needs = { "!swept" }, voice = "terse" },
        { ", rematch owed{duel_if:behind}", voice = "terse" },
        { ", narrowly{duel_if:close}", needs = { "!even", "total>=3" }, voice = "terse" },
        { ", last one mine", needs = { "lastWon==true", "!swept", "total>=3" }, voice = "terse", says = { "last" } },
        { ", last one to {him}", needs = { "lastLost==true", "!wasSwept", "total>=3" }, voice = "terse", says = { "last" } },
    },
})

Words("duel", "series", {
    wholes = {
        -- I won more.
        { "{ref} and I duelled {at:subZone} {today}. I won, {duel_score:mine}.", says = { "place" } },
        "{count.cap:total:duel} with {ref.obj} {today}, and I came out {duel_score:mine} ahead.",
        "I beat {ref.obj} {duel_score:mine} {today}. {he.cap} took {num:lost} off me, to be fair.",
        { "{ref} challenged me, or I challenged {ref.obj}; either way, I won {duel_score:mine}.", voice = "wry" },
        { "Duels with {ref.obj} {in:zone} {today}: {duel_score:mine} to me.", bonus = -0.25, says = { "place" } },
        { "I won {duel_score:mine:close} against {ref.obj}. It could have gone either way.", bonus = 0.25 },
        { "I beat {ref.obj} {duel_score:mine:wide}. Not close.", bonus = 0.25 },
        { "{ref} and I duelled {times:total}, and I won {num:won} of them. It was close at the end.", needs = { "total>=4" }, says = LOST, bonus = -0.5 },

        -- They won more.
        { "{ref} and I duelled {at:subZone} {today}. {he.cap} won, {duel_score:theirs}.", says = { "place" } },
        "{count.cap:total:duel} with {ref.obj} {today}, and {he} came out {duel_score:theirs} ahead.",
        "{ref} beat me {duel_score:theirs} {today}. I did take {num:won} off {him}.",
        { "Duels with {ref.obj} {in:zone} {today}: {duel_score:theirs} in {his} favour.", bonus = -0.25, says = { "place" } },
        { "{ref} beat me {duel_score:theirs:close}. One more and I'd have had {him}.", bonus = 0.25 },
        { "{ref} beat me {duel_score:theirs:wide}, and I can't pretend otherwise.", bonus = 0.25 },

        -- Level.
        { "{ref} and I fought {count:total:duel} {today} and finished {score}.", needs = { "even" } },
        { "{score.cap}. That's how the duels with {ref.obj} ended {today}, and neither of us is any the wiser.", needs = { "even" } },
        { "{ref} and I traded wins {today} and finished level, {score}.", needs = { "even" } },

        -- Sweeps.
        { "I swept {ref.obj} {today}: {num:total} duels, {num:total} wins.", needs = { "swept" }, says = BOTH },
        { "{count.cap:total:duel} with {ref.obj}, and I won the lot.", needs = { "swept" }, says = BOTH },
        { "{ref} didn't take a single duel off me {today}. {num.cap:total} to nothing.", needs = { "swept" }, says = BOTH },
        { "{ref} swept me {today}: {num:total} duels, {num:total} losses.", needs = { "wasSwept" }, says = BOTH },
        { "{count.cap:total:duel} with {ref.obj}, and {he} won the lot.", needs = { "wasSwept" }, says = BOTH },
        { "I didn't take a single duel off {ref.obj} {today}. {num.cap:total} to nothing.", needs = { "wasSwept" }, says = BOTH },

        -- Who took the last one.
        { "{ref} and I finished {score}, and I only drew level by taking the last one.", needs = { "even", "lastWon==true" }, says = { "last" } },
        { "I was ahead of {ref.obj} until {he} took the last duel and levelled it at {score}.", needs = { "even", "lastLost==true", "total>=4" }, says = { "last" } },
        { "I beat {ref.obj} {duel_score:mine}, though {he} took the last one.", needs = { "lastLost==true", "total>=3" }, says = { "last" } },
        { "{ref} beat me {duel_score:theirs}. I did take the last one, for whatever that's worth.", needs = { "lastWon==true", "total>=3" }, says = { "last" } },
        { "I won the last duel against {ref.obj} to make it {duel_score:mine:close}.", needs = { "lastWon==true", "total>=3" }, says = { "last" } },
        { "{ref} won the last duel to make it {duel_score:theirs:close}.", needs = { "lastLost==true", "total>=3" }, says = { "last" } },

        -- First duels.
        { "{ref} and I duelled for the first time {today}. I won {duel_score:mine}.", needs = { "first" } },
        { "{ref} and I had our first duels {today}, and they went {his} way, {duel_score:theirs}.", needs = { "first" } },
        { "{ref} and I duelled for the first time {today} and finished {score}.", needs = { "first", "even" } },
        { "First time duelling {ref.obj}. I lost, {duel_score:theirs}.", needs = { "first" } },
        { "First time duelling {ref.obj}. I won, {duel_score:mine}.", needs = { "first" } },
        { "{ref} and I duelled for the first time {today}, just the once, and I won.", needs = { "first", "total==1", "won==1" }, says = Tags(BOTH, { "total" }) },
        { "{ref} and I duelled for the first time {today}, just the once, and {he} won.", needs = { "first", "total==1", "lost==1" }, says = Tags(BOTH, { "total" }) },

        -- A single duel.
        { "One duel with {ref.obj} {today}, and I won it.", needs = { "total==1", "won==1" }, says = Tags(BOTH, { "total" }) },
        { "One duel with {ref.obj} {today}, and {he} won it.", needs = { "total==1", "lost==1" }, says = Tags(BOTH, { "total" }) },
        { "{ref} and I had a single duel {at:subZone}. I won.", needs = { "total==1", "won==1" }, says = Tags(Tags(BOTH, { "total" }), { "place" }) },
        { "{ref} and I had a single duel {at:subZone}. I lost.", needs = { "total==1", "lost==1" }, says = Tags(Tags(BOTH, { "total" }), { "place" }) },

        -- The all-time tally.
        { "I beat {ref.obj} {duel_score:mine} {today}. All-time, I lead {duel_all:mine}." },
        { "I beat {ref.obj} {duel_score:mine} {today}, but all-time {he} still leads {duel_all:theirs}." },
        { "{ref} beat me {duel_score:theirs} {today}. All-time, I still lead {duel_all:mine}." },
        { "{ref} beat me {duel_score:theirs} {today}, which makes it {duel_all:theirs} to {him} all-time." },
        { "{ref} and I finished {score} {today}, and it's {duel_all:even} all-time.", needs = { "even" }, bonus = 0.75 },
        { "{ref} and I finished {score} {today}. All-time, I lead {duel_all:mine}.", needs = { "even" } },
        { "{ref} and I finished {score} {today}. All-time, {he} leads {duel_all:theirs}.", needs = { "even" } },
        { "I won {num:won} and lost {num:lost} against {ref.obj} {today}. Overall that's {duel_all:duels}, {num:allWon} of them mine." },
        { "{ref} and I are level all-time now, {duel_all:even}, after {score} {today}.{duel_if:levelled}", bonus = 0.5 },
        { "I went ahead of {ref.obj} all-time {today}, {duel_all:mine}, after winning {duel_score:mine}.{duel_if:tookLead}", bonus = 0.5 },
        { "{ref} went ahead of me all-time {today}, {duel_all:theirs}, after winning {duel_score:theirs}.{duel_if:lostLead}", bonus = 0.5 },
        { "{ref} has still never beaten me in a duel. {today.cap} made it {duel_all:duels} without a loss.{duel_if:unbeaten}", needs = { "swept" }, says = BOTH, bonus = 0.5 },
        { "I have still never beaten {ref.obj} in a duel. {today.cap} made it {duel_all:duels} without a win.{duel_if:neverBeaten}", needs = { "wasSwept" }, says = BOTH, bonus = 0.5 },
        { "At last I took a duel off {ref.obj}. I won {num:won} and lost {num0:lost} {today}, my first wins against {him} ever.{duel_if:firstWin}", needs = { "won>=2" }, bonus = 0.5 },
        { "At last I beat {ref.obj} in a duel. Just the one win {today}, and {num:lost} lost, but it's my first ever.{duel_if:firstWin}", needs = { "won==1" }, says = WON, bonus = 0.5 },
        { "One duel with {ref.obj} {today}, and I won it: my first win against {him} ever.{duel_if:firstWin}", needs = { "total==1" }, says = Tags(BOTH, { "total" }), bonus = 0.5 },
        { "{ref} finally took a duel off me {today}. I won {num0:won} and lost {num:lost}, and my unbeaten run against {him} is over.{duel_if:firstLoss}", bonus = 0.5 },

        -- Warm.
        { "{ref} and I duelled {count:total:duel} {at:subZone}, and I won {num:won}. Good fun, whatever the score.", needs = { "total>=2", "!swept", "!wasSwept" }, voice = "warm", says = Tags(LOST, { "place" }) },
        { "Duelling {ref.obj} is always a pleasure. {today.cap} it finished {duel_score:mine} in my favour.", needs = { "!first" }, voice = "warm" },
        { "Duelling {ref.obj} is always a pleasure, even when {he} wins {duel_score:theirs}.", needs = { "!first" }, voice = "warm" },
        { "{ref} beat me {duel_score:theirs}, and fairly. I'd go again tomorrow.", voice = "warm" },
        { "{ref} and I duelled until we'd had enough and finished level, {score}. A good {part}.", needs = { "even" }, voice = "warm" },
        { "Our first duels, and I liked every one of them. {ref} won {duel_score:theirs}.", needs = { "first" }, voice = "warm" },
        { "{ref} and I duelled for the first time {today}. I won {duel_score:mine}, and I hope it's the first of many.", needs = { "first" }, voice = "warm" },

        -- Wry.
        { "I beat {ref.obj} {duel_score:mine}. I'll be bringing that up for weeks.", voice = "wry" },
        { "{ref} beat me {duel_score:theirs}. I've decided duels don't count on weekdays.", voice = "wry" },
        { "{ref} beat me {duel_score:theirs:wide}. I'd like it noted that I was the one who suggested duelling.", voice = "wry" },
        { "{num.cap:total} duels against {ref.obj}, {num:total} losses. My technique needs work.", needs = { "wasSwept" }, voice = "wry", says = BOTH },
        { "{num.cap:total} duels against {ref.obj}, {num:total} wins. I may be insufferable for a while.", needs = { "swept" }, voice = "wry", says = BOTH },
        { "{ref} and I finished {score}, which settles nothing and means a rematch.", needs = { "even" }, voice = "wry" },
        { "I lost to {ref.obj} {duel_score:theirs:close}. Practically a draw, if you squint.", voice = "wry" },
        { "{ref} won {duel_score:theirs} and is now {duel_all:theirs} up on me all-time. I'm keeping count, even if nobody else is.", voice = "wry" },
        { "I beat {ref.obj} {duel_score:mine} and have decided this is who I am now.", voice = "wry" },
        { "I won a duel against {ref.obj}. Just the one, but it's in the diary now.", needs = { "total==1", "won==1" }, voice = "wry", says = Tags(BOTH, { "total" }) },

        -- Terse.
        { "Duels with {ref.obj}. {duel_score.cap:mine}, mine.", voice = "terse" },
        { "Duels with {ref.obj}. {duel_score.cap:theirs}, {his}.", voice = "terse" },
        { "Duels with {ref.obj}. {score.cap}.", needs = { "even" }, voice = "terse" },
        { "{ref.short}: {num0:lost}. Me: {num0:won}.{duel_if:named}", needs = { "total>=2" }, voice = "terse" },
        { "Duelled {ref.obj}. Won {num0:won}, lost {num0:lost}.", needs = { "total>=2" }, voice = "terse" },
        { "Swept {ref.obj}, {num:total} to nothing.", needs = { "swept" }, voice = "terse", says = BOTH },
        { "Swept by {ref.obj}. {num.cap:total} straight.", needs = { "wasSwept" }, voice = "terse", says = BOTH },
        { "One duel, {ref.short}. Won.", needs = { "total==1", "won==1" }, voice = "terse", says = Tags(BOTH, { "total" }) },
        { "One duel, {ref.short}. Lost.", needs = { "total==1", "lost==1" }, voice = "terse", says = Tags(BOTH, { "total" }) },
        { "Duels, {ref.short}: {duel_score:mine}. Overall {duel_all:mine}.", voice = "terse" },
    },
})

-- More of the warm and wry voices: fondness for the opponent, and the
-- diarist laughing at their own losses.
Words("duel", "series", {
    stems = {
        { "In good spirits, ", voice = "warm" },
        { "With {ref.obj} for company, ", needs = { "total>=2" }, voice = "warm", says = { "duel_refstem" } },
    },
    clauses = {
        { "{ref} and I had a fine time of it, and I came out {duel_score:mine} ahead", voice = "warm" },
        { "{ref} got the better of me, {duel_score:theirs}, and deserved to", voice = "warm" },
        { "{ref} and I ended {score}, which felt about right", needs = { "even" }, voice = "warm" },
        { "I beat {ref.obj} {duel_score:mine}, purely on talent", voice = "wry" },
        { "I beat {ref.obj} {duel_score:mine:close}, though {he} made me work for it", voice = "warm" },
    },
    fragments = {
        { "Friendly duels with {ref.obj}, {score} at the end", needs = { "even" }, voice = "warm" },
        { "A cheerful few rounds with {ref.obj}, and {he} won {duel_score:theirs}", voice = "warm" },
        { "Humbled by {ref.obj}, {duel_score:theirs:wide}", voice = "wry" },
    },
    tails = {
        { ", and I'd duel {him} again any day", voice = "warm" },
        { ", and I had a great time of it", voice = "warm" },
        { ", and I'll be reminding {him} of it{duel_if:ahead}", voice = "wry" },
    },
    wholes = {
        { "{ref} and I duelled {count:total:duel} {today}. I won {duel_score:mine}, but the score was the least of it.", voice = "warm" },
        { "{ref} beat me {duel_score:theirs} {today}, and I was smiling the whole time.", voice = "warm" },
        { "I always enjoy duelling {ref.obj}. {today.cap} we finished {score}.", needs = { "even", "!first" }, voice = "warm" },
        { "{ref} and I duelled for the first time {today}, and I'd happily make a habit of it. {he.cap} won {duel_score:theirs}.", needs = { "first" }, voice = "warm" },
        { "Losing {duel_score:theirs} to {ref.obj} is no disgrace; {he} duels well.", voice = "warm" },
        { "I beat {ref.obj} {duel_score:mine:close} {today}, and {he} made me earn every one.", voice = "warm" },
        { "{ref} and I duelled {count:total:duel} and finished {score}. Nothing was learned.", needs = { "even" }, voice = "wry" },
        { "I lost {duel_score:theirs} to {ref.obj}. In my defence, I have no defence.", voice = "wry" },
        { "Swept by {ref.obj}, {num:total} to nothing. I'm considering a quieter hobby.", needs = { "wasSwept" }, voice = "wry", says = BOTH },
    },
})
