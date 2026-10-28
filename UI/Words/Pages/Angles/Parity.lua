-- Parity: our levels side by side, told as a relationship rather than
-- arithmetic: racing, in step, left behind, caught up.
--
-- levels facts
--   who               the person
--   myLevel           my level
--   theirLevel        theirs
--   levelDiff         mine minus theirs (negative when they are ahead)
--   absLevelDiff      |levelDiff|
--   sameLevel         levelDiff is 0
--   aheadMe           I'm ahead (levelDiff > 0)
--   aheadThem         they're ahead
--   crossed           the lead changed hands since we last met (one of us
--                     led then, the other leads now)
--   closed            the gap narrowed since we last met (to nothing, too)
--   widened           the gap grew
--   diffThen          the gap at our last meeting, signed like levelDiff
--                     (nil when there was no last meeting to compare)
--
-- crossed can come with closed or widened (three behind to one ahead is
-- both crossed and closed), so the "gaining" and "pulling away" words guard
-- with "!crossed" where they would read wrongly across a change of lead.
--
-- Every clause, fragment and whole says where we stand (who is ahead, or
-- that we're level); stems and tails only add to it. The bare flags say
-- themselves; stems and tails that lean on them guard with "levelDiff>0" or
-- "crossed==true" instead, so they can still join a clause that says it.
--
-- Tags of this file's own
--   parity.static     a clause that states where we stand now and nothing
--                     about change. Stems such as "Since we last met, " say
--                     it too, so they only ever open a clause about change.
--   parity.unchanged  the gap is as it was last time
--   parity.close      near enough in level to quest together
--   parity.trend      the gap is shrinking or growing
--   parity.and        a stem or tail joined with "and", so a sentence
--                     doesn't run "X, and Y, and Z"
--   parity.now        a clause in the present progressive ("is catching me
--                     up"), which "Since we last met, " can't open
--
-- Slots declared here
--   {parity_gap:f}    a signed gap as a count of levels, sign dropped:
--                     "three levels"; nil when the gap was 0
--   {parity_num:f}    the same as a bare number: "three"

local addonName, ns = ...

local Pages = ns.Pages
local Words = Pages.Words

Pages.Angle("parity", { order = { "levels" },
    about = "our levels side by side" })

Pages.Format("parity_gap", function(v)
    if type(v) ~= "number" or v == 0 then return nil end
    local n = math.abs(v)
    if n == 1 then return "a level" end
    return Pages.Lang.Count(n, "level")
end)

-- The same gap as a bare number, for after "down from" / "up from" when the
-- noun has already been said: "three levels now, down from five".
Pages.Format("parity_num", function(v)
    if type(v) ~= "number" or v == 0 then return nil end
    return Pages.Lang.Num(math.abs(v))
end)

-- Joins lists of needs: N(UNCHANGED, "aheadMe").
local function N(...)
    local out = {}
    for _, part in ipairs({ ... }) do
        if type(part) == "table" then
            for _, c in ipairs(part) do out[#out + 1] = c end
        else
            out[#out + 1] = part
        end
    end
    return out
end

local S = "parity.static"
local SAME = "parity.unchanged"
local CLOSE = "parity.close"
local TREND = "parity.trend"
local AND = "parity.and"
local NOW = "parity.now"

-- We met before and the gap is just as it was then.
local UNCHANGED = { "diffThen ~= __nil", "!closed", "!widened", "!crossed" }
-- Guards for tails and stems: who is ahead, without saying it.
local UP, DOWN, EVEN = "levelDiff>0", "levelDiff<0", "levelDiff==0"

Words("parity", "levels", {
    stems = {
        "As for levels, ",
        { "As things stand, ", says = { "crossed", "closed", "widened" } },
        "For the record, ",
        { "These days, ", says = { "crossed", "closed", "widened" } },
        "Going by the numbers, ",
        { "On the levelling front, ", bonus = -0.5 },
        { "Since we last met, ", needs = { "diffThen ~= __nil" }, says = { S, SAME, NOW } },
        { "Somewhere along the way, ", needs = { "crossed==true" }, says = { S, SAME } },
        { "Slowly but surely, ", needs = { "closed==true", "!crossed" }, says = { S, SAME } },
        { "Just as last time, ", needs = UNCHANGED, says = { SAME, "myLevel" } },
        { "Happily, ", needs = { EVEN }, voice = "warm", bonus = 0.5 },
        { "It's a friendly race, and ", voice = "warm", says = { AND } },
        { "Not that I'm counting, but ", voice = "wry", says = { "parity.count" } },
        { "In the race nobody agreed to, ", voice = "wry" },
        { "Painful as it is to write, ", needs = { "crossed==true", DOWN }, voice = "wry", says = { S, SAME }, bonus = 0.5 },
        { "Levels: ", voice = "terse" },
        { "Good news for our questing: ", needs = { "absLevelDiff<=2", "closed==true" }, says = { CLOSE }, voice = "warm" },
        { "Best of all, ", needs = { "closed==true" }, voice = "warm" },
        { "For what it's worth, ", voice = "wry", says = { "parity.count" } },
        { "In a development I'm choosing to ignore, ", needs = { "crossed==true", DOWN }, voice = "wry", says = { S, SAME }, bonus = 0.5 },
    },

    clauses = {
        -- where we stand, whichever way
        { "I'm {lvl:myLevel} and {ref} is {lvl:theirLevel}", needs = { "!sameLevel" }, says = { S } },
        { "{ref} is {lvl:theirLevel} to my {lvl:myLevel}", needs = { "!sameLevel" }, says = { S } },
        { "{ref} is level {lvl:theirLevel} and I'm {lvl:myLevel}", needs = { "!sameLevel" }, says = { S } },

        -- I'm ahead
        { "I'm [{levels:absLevelDiff} ahead of {ref.obj}|ahead of {ref.obj} by {levels:absLevelDiff}]", needs = { "aheadMe" }, says = { S } },
        { "{ref} is {levels:absLevelDiff} behind me", needs = { "aheadMe" }, says = { S } },
        { "I have {levels:absLevelDiff} on {ref.obj}", needs = { "aheadMe" }, says = { S } },
        { "I've got the edge on {ref.obj}", needs = { "aheadMe", "absLevelDiff<=3" }, says = { S } },
        { "I'm out in front of {ref.obj}", needs = { "aheadMe" }, says = { S } },
        { "there's only a level between {ref.obj} and me, in my favour", needs = { "aheadMe", "absLevelDiff==1" }, says = { S }, final = true },
        { "I'm well ahead of {ref.obj}", needs = { "aheadMe", "absLevelDiff>=6" }, says = { S } },

        -- they're ahead
        { "{ref} is [{levels:absLevelDiff} ahead of me|ahead of me by {levels:absLevelDiff}]", needs = { "aheadThem" }, says = { S } },
        { "I'm {levels:absLevelDiff} behind {ref.obj}", needs = { "aheadThem" }, says = { S } },
        { "{ref} has {levels:absLevelDiff} on me", needs = { "aheadThem" }, says = { S } },
        { "I'm trailing {ref.obj} by {levels:absLevelDiff}", needs = { "aheadThem" }, says = { S } },
        { "{ref} has the edge on me", needs = { "aheadThem", "absLevelDiff<=3" }, says = { S } },
        { "{ref} is out in front", needs = { "aheadThem" }, says = { S } },
        { "{ref} is well ahead of me", needs = { "aheadThem", "absLevelDiff>=6" }, says = { S } },

        -- level
        { "{ref} and I are level, both {lvl:myLevel}", needs = { "sameLevel" }, says = { S } },
        { "{ref} and I are neck and neck", needs = { "sameLevel" }, says = { S } },
        { "{ref} and I are level pegging", needs = { "sameLevel" }, says = { S } },
        { "there's nothing between {ref.obj} and me", needs = { "sameLevel" }, says = { S } },
        { "{ref} and I are both level {lvl:myLevel}", needs = { "sameLevel" }, says = { S } },

        -- the lead changed hands
        { "I've overtaken {ref.obj}", needs = { "crossed", "aheadMe" } },
        { "I've [passed|gone past] {ref.obj}", needs = { "crossed", "aheadMe" } },
        { "I've edged past {ref.obj}", needs = { "crossed", "aheadMe", "absLevelDiff<=2" }, bonus = 0.5 },
        { "I've taken the lead from {ref.obj}", needs = { "crossed", "aheadMe" } },
        { "{ref} has overtaken me", needs = { "crossed", "aheadThem" } },
        { "{ref} has [passed|gone past] me", needs = { "crossed", "aheadThem" } },
        { "{ref} has edged past me", needs = { "crossed", "aheadThem", "absLevelDiff<=2" }, bonus = 0.5 },
        { "{ref} has taken the lead", needs = { "crossed", "aheadThem" } },

        -- the gap narrowed
        { "{ref} has closed to within {levels:absLevelDiff} of me", needs = { "closed", "!crossed", "aheadMe" }, says = { TREND } },
        { "{ref} is catching me up", needs = { "closed", "!crossed", "aheadMe" }, says = { TREND, NOW } },
        { "{ref} has been gaining on me", needs = { "closed", "!crossed", "aheadMe" }, says = { TREND } },
        { "I've closed to within {levels:absLevelDiff} of {ref.obj}", needs = { "closed", "!crossed", "aheadThem" }, says = { TREND } },
        { "I'm catching {ref.obj} up", needs = { "closed", "!crossed", "aheadThem" }, says = { TREND, NOW } },
        { "I've clawed back some ground on {ref.obj}", needs = { "closed", "!crossed", "aheadThem" }, says = { TREND } },
        { "{ref} has caught me up", needs = { "closed", "sameLevel", "diffThen>0" }, says = { TREND } },
        { "I've caught {ref.obj} up", needs = { "closed", "sameLevel", "diffThen<0" }, says = { TREND } },
        { "{ref} and I have drawn level", needs = { "closed", "sameLevel" }, says = { TREND } },

        -- the gap grew
        { "I've pulled further ahead of {ref.obj}", needs = { "widened", "aheadMe", "diffThen>0" }, says = { TREND } },
        { "I've stretched my lead over {ref.obj} to {levels:absLevelDiff}", needs = { "widened", "aheadMe", "diffThen>0" }, says = { TREND } },
        { "I've pulled {levels:absLevelDiff} ahead of {ref.obj}", needs = { "widened", "aheadMe", "!crossed" }, says = { TREND } },
        { "I'm pulling away from {ref.obj}", needs = { "widened", "aheadMe" }, says = { TREND, NOW } },
        { "I've left {ref.obj} [behind|well behind]", needs = { "widened", "aheadMe", "absLevelDiff>=4" }, says = { TREND } },
        { "I've pulled ahead of {ref.obj}", needs = { "widened", "aheadMe", "diffThen==0" }, says = { TREND } },
        { "{ref} has pulled further ahead of me", needs = { "widened", "aheadThem", "diffThen<0" }, says = { TREND } },
        { "{ref} is leaving me behind", needs = { "widened", "aheadThem" }, says = { TREND, NOW } },
        { "{ref} has stretched the gap to {levels:absLevelDiff}", needs = { "widened", "aheadThem", "diffThen<0" }, says = { TREND } },
        { "{ref} has pulled ahead of me", needs = { "widened", "aheadThem", "diffThen==0" }, says = { TREND } },

        -- no change since last time
        { "{ref} and I are still neck and neck", needs = N(UNCHANGED, "sameLevel"), says = { SAME, S } },
        { "{ref} and I are still level", needs = N(UNCHANGED, "sameLevel"), says = { SAME, S } },
        { "I'm still {levels:absLevelDiff} ahead of {ref.obj}", needs = N(UNCHANGED, "aheadMe"), says = { SAME, S } },
        { "{ref} is still {levels:absLevelDiff} ahead of me", needs = N(UNCHANGED, "aheadThem"), says = { SAME, S } },
        { "the gap between {ref.obj} and me hasn't moved", needs = N(UNCHANGED, "!sameLevel"), says = { SAME, S } },
        { "{ref} and I have kept pace since we last met, {he} still {levels:absLevelDiff} ahead", needs = N(UNCHANGED, "aheadThem"), says = { SAME, S }, final = true },
        { "{ref} and I have kept pace since we last met, with me still {levels:absLevelDiff} ahead", needs = N(UNCHANGED, "aheadMe"), says = { SAME, S }, final = true },

        { "{ref} and I are keeping pace with each other", needs = { "absLevelDiff<=1" }, says = { S, NOW }, voice = "warm" },
        { "{ref} and I are close enough in level to quest together", needs = { "absLevelDiff<=3" }, says = { S, CLOSE }, voice = "warm", final = true },
        { "I've got {ref.obj} to chase", needs = { "aheadThem" }, says = { S }, voice = "warm" },
        { "{ref} has left me in {his} dust", needs = { "aheadThem", "absLevelDiff>=4" }, says = { S }, voice = "wry" },
        { "I'm ahead of {ref.obj}, and I intend to stay there", needs = { "aheadMe" }, says = { S }, voice = "wry", final = true },
        { "{ref} is ahead of me, and I'm being very mature about it", needs = { "aheadThem" }, says = { S }, voice = "wry", final = true },
        { "I'm {lvl:myLevel}, {ref} {lvl:theirLevel}", needs = { "!sameLevel" }, says = { S }, voice = "terse" },
        { "{ref} is close behind me, right where I like {him}", needs = { "aheadMe", "absLevelDiff<=2" }, says = { S }, voice = "warm", final = true },
        { "I'm just behind {ref.obj}, which suits me", needs = { "aheadThem", "absLevelDiff<=2" }, says = { S }, voice = "warm", final = true },
        { "{ref} has caught me up, so we can quest together again", needs = { "closed", "sameLevel", "diffThen>0" }, says = { TREND, CLOSE }, voice = "warm", final = true },
        { "I've nearly caught {ref.obj} up", needs = { "closed", "!crossed", "aheadThem", "absLevelDiff<=2" }, says = { TREND }, voice = "warm" },
        { "{ref} has stolen a march on me", needs = { "crossed", "aheadThem" }, voice = "wry" },
        { "I'm trailing {ref.obj}, which builds character", needs = { "aheadThem" }, says = { S }, voice = "wry", final = true },
        { "I've crept ahead of {ref.obj}, and I'm only a little smug", needs = { "aheadMe", "absLevelDiff<=2" }, says = { S }, voice = "wry", final = true },
        { "{ref} is ahead, by {levels:absLevelDiff}", needs = { "aheadThem" }, says = { S }, voice = "terse" },
        { "I'm {levels:absLevelDiff} up on {ref.obj}", needs = { "aheadMe" }, says = { S }, voice = "terse" },
    },

    fragments = {
        { "{levels.cap:absLevelDiff} up on {ref.obj}", needs = { "aheadMe" } },
        { "{levels.cap:absLevelDiff} behind {ref.obj}", needs = { "aheadThem" } },
        { "Neck and neck with {ref.obj}", needs = { "sameLevel" } },
        { "Level with {ref.obj} at {lvl:myLevel}", needs = { "sameLevel" }, final = true },
        { "Level pegging with {ref.obj}", needs = { "sameLevel" } },
        { "Ahead of {ref.obj} now", needs = { "crossed", "aheadMe" } },
        { "Overtaken by {ref.obj}", needs = { "crossed", "aheadThem" }, final = true },
        { "Gaining on {ref.obj}", needs = { "closed", "!crossed", "aheadThem" }, says = { TREND } },
        { "{ref.noun.short} gaining on me", needs = { "closed", "!crossed", "aheadMe" }, says = { TREND }, final = true },
        { "Pulling away from {ref.obj}", needs = { "widened", "aheadMe" }, says = { TREND } },
        { "Falling further behind {ref.obj}", needs = { "widened", "aheadThem", "diffThen<0" }, says = { TREND } },
        { "Still level with {ref.obj}", needs = N(UNCHANGED, "sameLevel"), says = { SAME } },
        { "Still {levels:absLevelDiff} ahead of {ref.obj}", needs = N(UNCHANGED, "aheadMe"), says = { SAME } },
        { "Still {levels:absLevelDiff} behind {ref.obj}", needs = N(UNCHANGED, "aheadThem"), says = { SAME } },
        { "{ref.noun.short} at {lvl:theirLevel}, me at {lvl:myLevel}", needs = { "!sameLevel" } },
        { "Me at {lvl:myLevel}, {ref.noun.short} at {lvl:theirLevel}", needs = { "!sameLevel" }, bonus = -0.5 },
        { "Close enough to {ref.obj} to quest together", needs = { "absLevelDiff<=3" }, says = { CLOSE }, voice = "warm", bonus = 0.5, final = true },
        { "{ref.noun.short} out in front, and me in pursuit", needs = { "aheadThem" }, voice = "warm", says = { AND } },
        { "Ahead of {ref.obj}, for once", needs = { "aheadMe", "crossed==true" }, voice = "wry" },
        { "Me {lvl:myLevel}, {ref.noun.short} {lvl:theirLevel}", needs = { "!sameLevel" }, voice = "terse" },
        { "{ref.noun.short} {lvl:theirLevel}, me {lvl:myLevel}", needs = { "!sameLevel" }, voice = "terse" },
        { "Level with {ref.obj}, {lvl:myLevel} each", needs = { "sameLevel" }, voice = "terse" },
        { "Side by side with {ref.obj}, level for level", needs = { "sameLevel" }, voice = "warm" },
        { "{ref.noun.short} just ahead, and me close behind", needs = { "aheadThem", "absLevelDiff<=2" }, says = { AND, CLOSE }, voice = "warm" },
        { "Behind {ref.obj} by {levels:absLevelDiff}, but who's counting", needs = { "aheadThem" }, voice = "wry", final = true },
        { "Ahead of {ref.obj}, which I'll mention as often as I can", needs = { "aheadMe" }, voice = "wry", final = true },
        { "Level with {ref.obj}", needs = { "sameLevel" }, voice = "terse" },
        { "Overtaken {ref.obj}", needs = { "crossed", "aheadMe" }, voice = "terse" },
        { "{ref.noun.short} ahead now", needs = { "crossed", "aheadThem" }, voice = "terse" },
        { "Closing on {ref.obj}", needs = { "closed", "!crossed", "aheadThem" }, says = { TREND }, voice = "terse" },
    },

    tails = {
        { ", my {lvl:myLevel} to {his} {lvl:theirLevel}", needs = { UP } },
        { ", {lvl:theirLevel} to my {lvl:myLevel}", needs = { DOWN } },
        { ", {lvl:myLevel} to {his} {lvl:theirLevel}", needs = { UP } },
        { ", {his} {lvl:theirLevel} to my {lvl:myLevel}", needs = { DOWN } },
        { "[, both on {lvl:myLevel}|, at {lvl:myLevel} apiece]", needs = { EVEN } },
        { ", and by {levels:absLevelDiff} at that", needs = { "crossed==true", "absLevelDiff>=2" }, says = { AND } },
        { ", after trailing {him} last time", needs = { "crossed==true", UP }, says = { "diffThen" } },
        { ", when last time I was the one ahead", needs = { "crossed==true", DOWN }, says = { "diffThen" }, bonus = 0.5 },
        { ", when last time {he} was {parity_gap:diffThen} ahead", needs = { "crossed==true", UP } },
        { ", when last time I was {parity_gap:diffThen} ahead", needs = { "crossed==true", DOWN } },
        { ", {levels:absLevelDiff} now, down from {parity_num:diffThen} when we last met", needs = { "closed==true", "!crossed", "!sameLevel" } },
        { ", from {parity_gap:diffThen} behind last time", needs = { "closed==true", EVEN, "diffThen>0" } },
        { ", after trailing {him} by {parity_gap:diffThen} last time", needs = { "closed==true", EVEN, "diffThen<0" } },
        { ", {levels:absLevelDiff} now, up from {parity_num:diffThen} last time", needs = { "widened==true", "!crossed", "diffThen~=0" } },
        { ", when we were level last time", needs = { "widened==true", "diffThen==0" }, says = { "diffThen", TREND } },
        { ", and the gap is shrinking", needs = { "closed==true", "!crossed", "!sameLevel" }, says = { TREND, AND } },
        { ", and the gap keeps growing", needs = { "widened==true", "!crossed", "diffThen~=0" }, says = { TREND, AND } },
        { ", the same as last time", needs = UNCHANGED, says = { SAME, "myLevel" } },
        { ", just as when we last met", needs = UNCHANGED, says = { SAME, "myLevel" } },
        { ", and we're still near enough to quest together", needs = { "absLevelDiff<=3", "!sameLevel" }, says = { CLOSE, AND } },
        { ", still near enough to quest together", needs = { "absLevelDiff<=3", "!sameLevel", "!crossed" }, says = { CLOSE } },
        { ", which keeps things interesting", needs = { "absLevelDiff<=3", "!sameLevel" }, voice = "warm" },
        { ", which is just how I like it", needs = { EVEN }, voice = "warm" },
        { ", and I don't mind a bit", needs = { DOWN, "!closed" }, voice = "warm", says = { AND } },
        { ", not that I'm keeping score", voice = "wry", says = { "parity.count" } },
        { ", and I'm trying not to gloat", needs = { UP, "!closed" }, voice = "wry", says = { AND } },
        { ", which I'm taking with good grace", needs = { DOWN, "!closed" }, voice = "wry" },
        { ", which I didn't see coming", needs = { "crossed==true" }, voice = "wry", bonus = 0.5 },
        { ", for the moment at least", voice = "wry" },
        { ", and long may it stay that way", needs = { EVEN }, says = { AND }, voice = "warm" },
        { ", close enough that it hardly matters", needs = { "absLevelDiff<=2", "!sameLevel", "!closed", "!widened" }, says = { CLOSE }, voice = "warm" },
        { ", and I'm happy for {him}", needs = { DOWN, "absLevelDiff>=3", "!closed" }, says = { AND }, voice = "warm" },
        { ", and yes, I checked twice", voice = "wry", says = { AND, "parity.count" } },
        { ", which I'm not at all bitter about", needs = { DOWN, "!closed" }, voice = "wry" },
        { ", gap closing", needs = { "closed==true", "!crossed", "!sameLevel" }, says = { TREND }, voice = "terse" },
        { ", gap growing", needs = { "widened==true", "!crossed", "diffThen~=0" }, says = { TREND }, voice = "terse" },
        { ", unchanged", needs = UNCHANGED, says = { SAME, "myLevel" }, voice = "terse" },
    },

    wholes = {
        { "I'm {levels:absLevelDiff} ahead of {ref.obj} now, {lvl:myLevel} to {lvl:theirLevel}.", needs = { "aheadMe" } },
        { "{ref} is {levels:absLevelDiff} behind me, at {lvl:theirLevel}.", needs = { "aheadMe" } },
        { "{ref} is {levels:absLevelDiff} ahead of me now, {lvl:theirLevel} to my {lvl:myLevel}.", needs = { "aheadThem" } },
        { "I'm {levels:absLevelDiff} behind {ref.obj}: {lvl:myLevel} to {his} {lvl:theirLevel}.", needs = { "aheadThem" } },
        { "{ref} and I are both level {lvl:myLevel} now.", needs = { "sameLevel" } },
        { "We're level, {ref} and I: {lvl:myLevel} apiece.", needs = { "sameLevel" } },
        { "There's nothing between {ref.obj} and me now; we're both {lvl:myLevel}.", needs = { "sameLevel" } },
        { "{ref} is {lvl:theirLevel} and I'm {lvl:myLevel}.", needs = { "!sameLevel" }, lead = true },
        { "Our levels, for the record: {ref} {lvl:theirLevel}, me {lvl:myLevel}.", needs = { "!sameLevel" }, bonus = -0.5 },
        { "Just a level between {ref.obj} and me, and it's mine.", needs = { "aheadMe", "absLevelDiff==1" } },
        { "Just a level between {ref.obj} and me, and {he}'s the one ahead.", needs = { "aheadThem", "absLevelDiff==1" } },
        { "{ref} is well ahead of me now: {lvl:theirLevel} to my {lvl:myLevel}.", needs = { "aheadThem", "absLevelDiff>=6" } },
        { "I'm well ahead of {ref.obj} now, {lvl:myLevel} to {his} {lvl:theirLevel}.", needs = { "aheadMe", "absLevelDiff>=6" } },
        { "I've overtaken {ref.obj}. I'm {lvl:myLevel} now, {he} {lvl:theirLevel}.", needs = { "crossed", "aheadMe" } },
        { "Last time {ref} was ahead of me. Now I'm {levels:absLevelDiff} ahead of {him}.", needs = { "crossed", "aheadMe" }, says = { "diffThen" } },
        { "Last time {ref} was {parity_gap:diffThen} ahead; now I'm {levels:absLevelDiff} up on {him}.", needs = { "crossed", "aheadMe" } },
        { "{ref} has overtaken me, and is {lvl:theirLevel} to my {lvl:myLevel}.", needs = { "crossed", "aheadThem" } },
        { "The tables have turned: {ref} is ahead of me now.", needs = { "crossed", "aheadThem" } },
        { "The tables have turned: I'm ahead of {ref.obj} now.", needs = { "crossed", "aheadMe" } },
        { "When we last met I was ahead of {ref.obj}. Not any more: {he} has {levels:absLevelDiff} on me.", needs = { "crossed", "aheadThem" }, says = { "diffThen" } },
        { "I was {parity_gap:diffThen} ahead of {ref.obj} last time. Now {he} is {levels:absLevelDiff} ahead of me.", needs = { "crossed", "aheadThem" } },
        { "{ref} has closed the gap to {levels:absLevelDiff}, down from {parity_num:diffThen} when we last met.", needs = { "closed", "!crossed", "aheadMe" }, says = { TREND } },
        { "I've closed the gap on {ref.obj} to {levels:absLevelDiff}, down from {parity_num:diffThen}.", needs = { "closed", "!crossed", "aheadThem" }, says = { TREND } },
        { "{ref} was {parity_gap:diffThen} behind me last time, and now we're level.", needs = { "closed", "sameLevel", "diffThen>0" }, says = { TREND } },
        { "I was {parity_gap:diffThen} behind {ref.obj} last time, and now we're level.", needs = { "closed", "sameLevel", "diffThen<0" }, says = { TREND } },
        { "{ref} has caught me up: we're both {lvl:myLevel} now.", needs = { "closed", "sameLevel", "diffThen>0" }, says = { TREND } },
        { "I've caught {ref.obj} up at last. Both {lvl:myLevel}.", needs = { "closed", "sameLevel", "diffThen<0" }, says = { TREND } },
        { "I've pulled further ahead of {ref.obj}: {levels:absLevelDiff} now, up from {parity_num:diffThen}.", needs = { "widened", "aheadMe", "diffThen>0" }, says = { TREND } },
        { "{ref} has pulled further ahead of me: {levels:absLevelDiff} now, up from {parity_num:diffThen}.", needs = { "widened", "aheadThem", "diffThen<0" }, says = { TREND } },
        { "We were level last time. Now I'm {levels:absLevelDiff} ahead of {ref.obj}.", needs = { "widened", "aheadMe", "diffThen==0" }, says = { "diffThen" } },
        { "We were level last time. Now {ref} is {levels:absLevelDiff} ahead of me.", needs = { "widened", "aheadThem", "diffThen==0" }, says = { "diffThen" } },
        { "{ref} and I are still neck and neck, both {lvl:myLevel}.", needs = N(UNCHANGED, "sameLevel"), says = { SAME } },
        { "Still {levels:absLevelDiff} between {ref.obj} and me, just as last time.", needs = N(UNCHANGED, "!sameLevel"), says = { SAME } },
        { "The gap hasn't moved: I'm still {levels:absLevelDiff} ahead of {ref.obj}.", needs = N(UNCHANGED, "aheadMe"), says = { SAME } },
        { "The gap hasn't moved: {ref} is still {levels:absLevelDiff} ahead of me.", needs = N(UNCHANGED, "aheadThem"), says = { SAME } },
        { "{ref} and I have kept pace since we last met, still {levels:absLevelDiff} apart.", needs = N(UNCHANGED, "!sameLevel"), says = { SAME } },

        { "{ref} and I are both {lvl:myLevel}, which feels about right.", needs = { "sameLevel" }, voice = "warm" },
        { "{ref} is {levels:absLevelDiff} ahead of me, which only gives me something to aim for.", needs = { "aheadThem" }, voice = "warm" },
        { "Still close enough to quest together: {ref} {lvl:theirLevel}, me {lvl:myLevel}.", needs = { "absLevelDiff<=3", "!sameLevel" }, says = { CLOSE }, voice = "warm" },
        { "{ref} has caught me up, and I couldn't be happier about it.", needs = { "closed", "sameLevel", "diffThen>0" }, voice = "warm" },
        { "{ref} and I are level again. Long may it last.", needs = { "closed", "sameLevel" }, voice = "warm" },
        { "I'm {levels:absLevelDiff} ahead of {ref.obj}, but still near enough to quest together.", needs = { "aheadMe", "absLevelDiff<=3" }, says = { CLOSE }, voice = "warm" },
        { "{ref} is {levels:absLevelDiff} ahead of me. I'm told it's not a race.", needs = { "aheadThem" }, voice = "wry" },
        { "{ref} has overtaken me. I'll be taking that personally.", needs = { "crossed", "aheadThem" }, voice = "wry" },
        { "I'm {levels:absLevelDiff} ahead of {ref.obj}, and I intend to enjoy it while it lasts.", needs = { "aheadMe" }, voice = "wry" },
        { "{ref} and I are dead level, which settles nothing.", needs = { "sameLevel" }, voice = "wry" },
        { "{ref} is {levels:absLevelDiff} ahead of me and pulling away. I'll catch up eventually. Probably.", needs = { "widened", "aheadThem" }, voice = "wry" },
        { "I've overtaken {ref.obj}. Nobody else will care, but I do.", needs = { "crossed", "aheadMe" }, voice = "wry" },
        { "{ref} is well ahead of me now. I've stopped pretending it's a race.", needs = { "aheadThem", "absLevelDiff>=6" }, voice = "wry" },
        { "{ref.noun.short} {lvl:theirLevel}, me {lvl:myLevel}.", needs = { "!sameLevel" }, voice = "terse" },
        { "Level with {ref.obj}: {lvl:myLevel}.", needs = { "sameLevel" }, voice = "terse" },
        { "{levels.cap:absLevelDiff} up on {ref.obj}.", needs = { "aheadMe" }, voice = "terse" },
        { "{levels.cap:absLevelDiff} behind {ref.obj}.", needs = { "aheadThem" }, voice = "terse" },
        { "Overtaken {ref.obj}. {lvl:myLevel} to {lvl:theirLevel}.", needs = { "crossed", "aheadMe" }, voice = "terse" },
        { "{ref} is {levels:absLevelDiff} ahead of me now. Good for {him}.", needs = { "aheadThem" }, voice = "warm" },
        { "Level with {ref.obj} at {lvl:myLevel}. I hope it stays that way.", needs = { "sameLevel" }, voice = "warm" },
        { "I've pulled {levels:absLevelDiff} ahead of {ref.obj}, and I'll miss questing at the same level.", needs = { "widened", "aheadMe", "absLevelDiff>=4", "!crossed" }, says = { TREND }, voice = "warm" },
        { "{ref} has nearly caught me up, which should mean more questing together.", needs = { "closed", "!crossed", "aheadMe", "absLevelDiff<=2" }, says = { TREND }, voice = "warm" },
        { "{ref} has caught me up. So much for my head start.", needs = { "closed", "sameLevel", "diffThen>0" }, voice = "wry" },
        { "I'm {levels:absLevelDiff} behind {ref.obj}. I prefer to think of it as pacing myself.", needs = { "aheadThem" }, voice = "wry" },
        { "Still level with {ref.obj}. Neither of us can claim anything.", needs = N(UNCHANGED, "sameLevel"), says = { SAME }, voice = "wry" },
        { "Caught up with {ref.obj}. {lvl:myLevel} each.", needs = { "closed", "sameLevel", "diffThen<0" }, voice = "terse" },
        { "{ref.noun.short} passed me. {lvl:theirLevel} to {lvl:myLevel}.", needs = { "crossed", "aheadThem" }, voice = "terse" },
    },
})
