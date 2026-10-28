-- Trade: things that changed hands between me and someone else.
--
-- gift facts: they gave, I gave nothing
--   who             the person (a diary entry or a stranger)
--   received        items I got: a list of { link, count }
--   moneyReceived   copper I got
--   first           our first trade
--   returned        I had given them something before
--   returnDays      days since I did (not always known)
--
-- given facts: I gave, they gave nothing (the mirror of gift)
--   who, given, moneyGiven, first, returned (they had given me something
--   before), returnDays
--
-- swap facts: both ways
--   who, received, given, moneyReceived, moneyGiven, first
--
-- What the data shows is what changed hands, never why: no "to thank me",
-- no "because I helped", no conversation. "Back" and "in return" only
-- where `returned` makes them true. The narrator may be touched, amused or
-- grateful. Size words ("a small fortune", "an armful") are guarded by the
-- amounts, and "for X" in a swap always names the whole of that side.

local addonName, ns = ...

local Pages = ns.Pages
local Words = Pages.Words

Pages.Angle("trade", { order = { "gift", "given", "swap" },
    about = "things that changed hands" })

--------------------------------------------------------------------------
-- Guards on item lists
--------------------------------------------------------------------------
--
-- "#received>=2" counts a list's entries, but not the items in them, so
-- these formatters do: each writes nothing when its list fits and fails
-- otherwise, and the engine then tries another combination. They need
-- their list but say nothing, so a guarded piece still combines with one
-- that names the items.
--   {trade_lone:f}     one entry, a single item: "a [Linen Bandage]"
--   {trade_lots:f}     three or more entries, or ten or more items
--   {trade_few:f}      two items at most, all told

local floor = math.floor

local function Units(list)
    local n = 0
    for i = 1, #list do n = n + floor(list[i].count or 1) end
    return n
end

local function Guard(name, test)
    Pages.Format(name, function(v)
        if type(v) == "table" and #v > 0 and test(v) then return "" end
        return nil
    end, { says = false })
end

Guard("trade_lone", function(v) return #v == 1 and floor(v[1].count or 1) <= 1 end)
Guard("trade_lots", function(v) return #v >= 3 or Units(v) >= 10 end)
Guard("trade_few", function(v) return Units(v) <= 2 end)

--------------------------------------------------------------------------
-- Banks
--------------------------------------------------------------------------

-- "For nothing", after an object: "gave me five [Silk Cloth] <trade.free>".
Pages.Bank("trade.free", {
    "for nothing", "for nothing", "free of charge", "for free",
    { "for nothing at all", voice = "warm" },
    { "gratis", voice = "wry" },
    { "for free", voice = "terse" },
})

-- My reaction to being given something, as a whole short sentence.
Pages.Bank("trade.touched", {
    "That was kind.", "I was touched.", "I'm grateful.", "Kind of {him}.",
    { "It made my {part}.", voice = "warm" },
    { "I won't forget it.", voice = "warm" },
    { "I'll take it.", voice = "wry" },
    { "No complaints here.", voice = "wry" },
    { "Kind.", voice = "terse" },
})

-- My reaction to giving something away, as a whole short sentence.
Pages.Bank("trade.giving", {
    "It felt good.", "Glad to.", "I hope it helps.",
    { "I'd do it again.", voice = "warm" },
    { "No regrets.", voice = "wry" },
    { "My bags thank me.", voice = "wry" },
    { "Done.", voice = "terse" },
})

--------------------------------------------------------------------------
-- What each piece tells
--------------------------------------------------------------------------
--
-- A move's `must` can't say "received or moneyReceived", so a piece whose
-- slots tell what I got says "got", and what I gave says "gave". In gift
-- and given only clauses, fragments and wholes carry the tag, so a tail
-- can still add the money to the items ("..., plus 2 gold"); pieces that
-- tell both carry a bonus big enough that, when both are there, the
-- sentences leaving one out drop from the draw. In swap every kind carries
-- it, so a clause can tell one side and its tail the other, and a piece
-- telling a side tells all of it: items alone need no money on that side,
-- money alone needs no items on it (and items on the other). Pieces naming
-- the time ({today}, {part}) say so, so it isn't said twice; so do pieces
-- using a word that reads badly twice ("trade", "gift", "back"), and any
-- piece but a whole that holds a colon.
--
-- `me = true` marks a stem where I act ("To even things up, "), and
-- `them = true` a clause whose subject isn't me, so the two never meet.
-- Anything that needs `returned` also says "free" and "why", so giving back
-- is never "for nothing" or "for no reason" in the same sentence.
--
-- `nostem = true` marks a clause no stem can open ("the first thing {ref}
-- ever gave me was ...").
--
-- `shut = true` marks a clause or fragment that doesn't end on what changed
-- hands ("..., courtesy of {ref.obj}"), and the tails that add to it
-- (", plus 2 gold"), so the two never meet.

local CONVEY = { items = true, item = true, money = true, coins = true }
local SIDE = { received = "got", moneyReceived = "got", given = "gave", moneyGiven = "gave" }
local KINDS = { "stems", "clauses", "fragments", "tails", "wholes" }
local CORE = { clauses = true, fragments = true, wholes = true }
local ALL = { stems = true, clauses = true, fragments = true, tails = true, wholes = true }

-- Pieces telling both items and money in gift and given.
local BOTH = 3.5

-- Someone I'd never dealt with: no name, not a face I keep seeing.
local STRANGER = { "!who.diary", "!who.named", "!who.familiar", "first" }
-- An unnamed face I keep seeing.
local FAMILIAR = { "who.familiar", "!who.diary", "!who.named" }

-- Words that read badly twice in a sentence, and the tag each says.
local WORDS = {
    ["%f[%a]trad"] = "w_trade", ["%f[%a]deal"] = "w_deal", ["%f[%a]swap"] = "w_swap",
    ["%f[%a]gift"] = "w_gift", ["%f[%a]kind"] = "w_kind", ["%f[%a]back%f[%A]"] = "w_back",
    ["%f[%a]nothing"] = "w_nothing", ["%f[%a]bags"] = "w_bags", ["%f[%a]turn"] = "w_turn",
    ["%f[%a]purse"] = "w_purse", ["on top"] = "w_ontop", ["other way"] = "w_otherway",
    ["one way"] = "w_otherway", ["one%-sided"] = "w_otherway",
    ["%f[%a]happ"] = "w_glad", ["%f[%a]glad"] = "w_glad", ["%f[%a]free"] = "w_free",
}

local function Mark(spec, kinds, strict)
    for _, kind in ipairs(KINDS) do
        local list = spec[kind] or {}
        for i = 1, #list do
            local p = list[i]
            if type(p) == "string" then p = { p } end
            -- Strangers and familiar faces have lines of their own, but
            -- they shouldn't crowd out everything else when they trade.
            if p.needs == STRANGER then p.bonus = (p.bonus or 0) - 1 end
            if p.needs == FAMILIAR then p.bonus = (p.bonus or 0) - 0.75 end
            local says, needs = {}, {}
            for _, s in ipairs(p.says or {}) do says[#says + 1] = s end
            for _, c in ipairs(p.needs or {}) do needs[#needs + 1] = c end
            local told = {}
            for slot in p[1]:gmatch("{([^}]*)}") do
                local name = slot:match("^([%w_]+)")
                local fact = slot:match(":([%w_]+)")
                if CONVEY[name] and SIDE[fact] then
                    told[fact] = true
                    if kinds[kind] then says[#says + 1] = SIDE[fact] end
                end
                if name == "today" then says[#says + 1] = "today" end
                if name == "part" then says[#says + 1] = "today" end
            end
            if p.shut then says[#says + 1] = "shut" end
            local bare = p[1]:gsub("{[^}]*}", "x"):lower()
            for pattern, tag in pairs(WORDS) do
                if bare:find(pattern) then says[#says + 1] = tag end
            end
            if kind ~= "wholes" and bare:find(":", 1, true) then says[#says + 1] = "colon" end
            -- Giving back is the best of it: let it lead when it's there.
            -- Giving back can't also be "for nothing" in the same breath.
            for _, c in ipairs(needs) do
                if c == "returned" then
                    p.bonus = (p.bonus or 0) + 0.5
                    says[#says + 1] = "free"
                    says[#says + 1] = "why"
                end
            end
            -- A stem where I act ("By way of thanks, ") can't open a clause
            -- where someone else does.
            if p.me or p.them then says[#says + 1] = "agent" end
            -- Every stem says "stem", and so does a clause that can't follow
            -- one (`nostem`), being a statement rather than an act.
            if kind == "stems" or p.nostem then says[#says + 1] = "stem" end
            if strict then
                local function Side(items, money, otherItems, otherMoney)
                    if told[items] and not told[money] then needs[#needs + 1] = "!" .. money end
                    if told[money] and not told[items] then
                        needs[#needs + 1] = "!" .. items
                        if not told[otherItems] and not told[otherMoney] then
                            needs[#needs + 1] = otherItems .. " ~= __nil"
                        end
                    end
                end
                Side("received", "moneyReceived", "given", "moneyGiven")
                Side("given", "moneyGiven", "received", "moneyReceived")
            end
            p.says, p.needs = says, needs
            list[i] = p
        end
    end
    return spec
end

--------------------------------------------------------------------------
-- gift: they gave, I gave nothing
--------------------------------------------------------------------------

Words("trade", "gift", Mark({
    needs = { "!given", "!moneyGiven" },
    must = { "got" },

    stems = {
        { "To my surprise, ", says = { "sudden" } },
        { "[Out of the blue|Unexpectedly], ", says = { "sudden" }, voice = "warm" },
        { "For the first time, ", needs = { "first" } },
        { "The first time {ref} and I ever traded, ", needs = { "first" }, says = { "intro" } },
        { "In the first trade we'd ever made, ", needs = { "first" } },
        { "Our first trade: ", needs = { "first" } },
        { "{ago.cap:returnDays} I'd given {ref.obj} something. {today.cap}, ", needs = { "returned" }, says = { "intro" } },
        { "{days.cap:returnDays} after I'd given {ref.obj} something, ", needs = { "returned" }, says = { "intro" } },
        { "I'd given {ref.obj} something before, and {today} ", needs = { "returned" }, says = { "intro" } },
        { "[This time it went the other way|The other way round this time]: ", needs = { "returned" } },
        { "Turnabout: ", needs = { "returned" }, voice = "wry" },
        { "For nothing at all, ", says = { "free" } },
        { "Free of charge, ", says = { "free" }, voice = "wry" },
        { "In a one-sided trade, ", says = { "free" } },
        { "With nothing going the other way, ", says = { "free" } },
        { "Though I put nothing in the trade, ", says = { "free" } },
        { "Small kindness of the {part}: ", voice = "warm" },
        { "A nice surprise {today}: ", says = { "sudden" }, voice = "warm" },
        { "The kindness of strangers: ", needs = { "!who.diary", "!who.named", "!who.familiar" }, voice = "warm" },
        { "I've no idea what I did to deserve it, but ", needs = { "!returned" }, says = { "why" }, voice = "wry" },
        { "Here's a thing: ", voice = "wry" },
        { "File under unearned: ", says = { "free" }, voice = "wry" },
        { "{today.cap}: ", voice = "terse" },
        { "One-way trade: ", says = { "free" }, voice = "terse" },
        { "{today.cap}, ", bonus = -0.5 },
    },

    clauses = {
        -- items
        "{ref} [gave|handed|passed] me {items:received}",
        { "{ref} put {items:received} in the trade window for me", shut = true },
        "I came away from {ref.obj} with {items:received}",
        { "{items:received} came my way from {ref.obj}", shut = true },
        { "{items:received} changed hands, from {ref.obj} to me", shut = true },
        "{ref} spared me {items:received}",
        { "I ended up with {items:received}, courtesy of {ref.obj}", shut = true },
        { "I found myself holding {items:received}, courtesy of {ref.obj}", shut = true },
        { "I got {items:received} from {ref.obj}", shut = true, bonus = -0.5 },
        { "I was given {items:received} by {ref.obj}", shut = true, says = { "intro" } },
        { "I accepted {items:received} from {ref.obj}", shut = true },
        "a trade with {ref.obj} left me holding {items:received}",
        { "a trade with {ref.obj} left me holding {items:received} and {him} holding nothing", says = { "free" }, final = true },
        { "{ref.poss} side of the trade window held {items:received}, and mine held nothing", shut = true, says = { "free" } },
        { "{ref} gave me {items:received} <trade.free>", shut = true, says = { "free" } },
        { "{ref} let me have {items:received} for nothing", shut = true, says = { "free" } },
        { "{ref} handed over {items:received} and took nothing back", shut = true, says = { "free" } },
        { "{trade_lots:received}{ref} [loaded|stocked] me up with {items:received}", bonus = 0.5 },
        { "{ref} gave me {item:received} and more besides", needs = { "#received>=2" }, shut = true, bonus = 0.25 },
        { "{ref} saw me right with {items:received}", voice = "warm" },
        { "{ref} made me a present of {items:received}", voice = "warm" },
        { "{ref} dropped {items:received} into my bags", shut = true, voice = "warm" },
        { "{ref} was good enough to give me {items:received}", voice = "warm" },
        { "{ref} sorted me out with {items:received}", voice = "warm" },
        { "{ref} slipped me {items:received}", voice = "wry" },
        { "I became the proud owner of {items:received}, thanks to {ref.obj}", shut = true, voice = "wry" },
        { "I was the lucky recipient of {items:received}, from {ref.obj}", shut = true, voice = "wry" },
        { "{ref} gave me {items:received}", voice = "terse" },
        { "{ref} kindly gave me {items:received}", says = { "feel" }, voice = "warm" },
        -- items and money
        { "{ref} gave me {items:received}, plus {money:moneyReceived}", bonus = BOTH },
        { "{ref} gave me {money:moneyReceived} along with {items:received}", bonus = BOTH },
        { "{ref} handed me {items:received} with {coins:moneyReceived} on top", bonus = BOTH },
        { "I came away from {ref.obj} with {items:received}, and {money:moneyReceived} besides", bonus = BOTH, final = true },
        -- money
        "{ref} [gave|handed] me {money:moneyReceived}",
        "{ref} [handed|passed] me {coins:moneyReceived}",
        { "{ref} put {money:moneyReceived} in the trade window for me", shut = true },
        { "{ref} put {coins:moneyReceived} in my purse", shut = true },
        { "I came away {money:moneyReceived} richer, thanks to {ref.obj}", shut = true },
        { "{coins:moneyReceived} came my way from {ref.obj}", shut = true },
        { "I pocketed {money:moneyReceived}, courtesy of {ref.obj}", shut = true },
        { "{ref} made me {money:moneyReceived} richer", shut = true },
        { "{ref} gave me {coins:moneyReceived} <trade.free>", shut = true, says = { "free" } },
        { "{ref} handed over {money:moneyReceived}, and I handed over nothing", says = { "free" }, final = true },
        { "{ref} topped up my purse with {money:moneyReceived}", voice = "warm" },
        { "my purse got {money:moneyReceived} heavier, courtesy of {ref.obj}", shut = true, voice = "wry" },
        { "{ref} slipped me {coins:moneyReceived}", voice = "wry" },
        { "{ref} handed me {money:moneyReceived}, a small fortune by my standards", bonus = 0.5, needs = { "moneyReceived>=500000", "!received" }, says = { "size" }, final = true },
        { "{ref} gave me {money:moneyReceived}, which I'll try not to spend all at once", bonus = 0.5, needs = { "moneyReceived<100", "!received" }, says = { "size" }, final = true, voice = "wry" },
        { "{ref} gave me {money:moneyReceived}, which at level {lvl:page.levelEnd} is real money", bonus = 0.5, needs = { "moneyReceived>=10000", "page.levelEnd<=20", "!received" }, says = { "size" }, final = true },
        -- first, and back again
        { "{ref} and I traded for the first time, and it all went one way: {items:received}", nostem = true, needs = { "first" }, says = { "free" }, final = true },
        { "the first thing {ref} ever gave me was {items:received}", nostem = true, needs = { "first" } },
        { "the first thing {ref} ever gave me was {money:moneyReceived}", nostem = true, needs = { "first" } },
        { "it went the other way this time: {ref} gave me {items:received}", nostem = true, needs = { "returned" } },
        { "it went the other way this time: {ref} gave me {coins:moneyReceived}", nostem = true, needs = { "returned" } },
        { "this time it was {ref} doing the giving: {items:received}", nostem = true, needs = { "returned" }, final = true },
        { "the giving came back round, with {items:received} from {ref.obj}", nostem = true, shut = true, needs = { "returned" } },
        -- who they are
        { "{ref.noun}, no one I knew, gave me {items:received}", needs = STRANGER, says = { "intro" } },
        { "{ref.noun}, no one I knew, handed me {coins:moneyReceived}", needs = STRANGER, says = { "intro" } },
        { "{ref.noun} I keep seeing around gave me {items:received}", needs = FAMILIAR, says = { "intro" } },
        { "{ref.short}, of all people, gave me {items:received}", needs = { "who.tags.avoid" }, says = { "intro" }, voice = "wry" },
    },

    fragments = {
        "{items.cap:received} from {ref.obj}",
        "{coins.cap:moneyReceived} from {ref.obj}",
        "A gift from {ref.obj}: {items:received}",
        "A gift from {ref.obj}: {money:moneyReceived}",
        "Something from {ref.obj}: {items:received}",
        "Got {items:received} from {ref.obj}",
        { "Given {items:received} by {ref.obj}", shut = true },
        { "Richer by {money:moneyReceived}, thanks to {ref.obj}", shut = true },
        "{ref.poss} gift: {items:received}",
        { "{items.cap:received}, courtesy of {ref.obj}", shut = true },
        { "In my bags now: {items:received}, from {ref.obj}", shut = true },
        { "{items.cap:received}, free, from {ref.obj}", shut = true, says = { "free" } },
        { "{items.cap:received}, plus {coins:moneyReceived}, from {ref.obj}", bonus = BOTH, final = true },
        { "A gift from {ref.obj}: {items:received}, with {money:moneyReceived} on top", bonus = BOTH, final = true },
        { "First trade with {ref.obj}, and all one way: {items:received}", needs = { "first" }, says = { "free" } },
        { "First trade with {ref.obj}, and all one way: {coins:moneyReceived}", needs = { "first" }, says = { "free" } },
        { "The other way round this time: {items:received} from {ref.obj}", needs = { "returned" } },
        { "{days.cap:returnDays} after my gift to {ref.obj}, {items:received} from {him}", needs = { "returned" } },
        { "{items.cap:received} from {ref.obj}, no one I knew", needs = STRANGER, final = true },
        { "{trade_lots:received}An armful from {ref.obj}: {items:received}", bonus = 0.5 },
        { "Gift of the {part}: {items:received}, from {ref.obj}", shut = true, voice = "warm" },
        { "A kindness from {ref.obj}: {items:received}", voice = "warm" },
        { "Something for nothing from {ref.obj}: {items:received}", says = { "free" }, voice = "wry" },
        { "{items.cap:received} richer, thanks to {ref.obj}", shut = true, voice = "wry" },
        { "Unearned income: {money:moneyReceived} from {ref.obj}", voice = "wry" },
        { "{ref.short}: {items:received}, <trade.free>", shut = true, says = { "free" }, voice = "terse" },
        { "From {ref.obj}: {items:received}", voice = "terse" },
        { "From {ref.obj}: {coins:moneyReceived}", voice = "terse" },
        { "{trade_lone:received}One thing from {ref.obj}: {items:received}", bonus = 0.5, voice = "terse" },
        { "Gift: {items:received}, from {ref.short}", voice = "terse" },
        { "{items.cap:received}. From {ref.short}, no charge", says = { "free" }, voice = "terse", final = true },
        { "{money.cap:moneyReceived} from {ref.short}", needs = { "!received" }, voice = "terse" },
    },

    tails = {
        { ", <trade.free>", says = { "free" } },
        { ", and nothing went the other way", says = { "free" } },
        { ", and I gave nothing back", says = { "free" } },
        { ", [our first trade|the first time we'd ever traded|the first trade between us]", needs = { "first" } },
        { ", the first time anything had changed hands between us", needs = { "first" } },
        { ", which I hadn't expected", says = { "sudden" } },
        { ", and I was grateful", says = { "feel" } },
        { ", {days:returnDays} after I'd given {him} something", needs = { "returned" } },
        { ", after I'd given {him} something {ago:returnDays}", needs = { "returned" } },
        { ", so it's gone both ways between us now", needs = { "returned" } },
        { ", which [squares us, I think|makes us about even, I think]", needs = { "returned" } },
        { ", and now I owe {him} one", needs = { "!returned" }, says = { "owe" } },
        { ", plus {money:moneyReceived}", shut = true, bonus = BOTH },
        { ", and {coins:moneyReceived} on top", shut = true, bonus = BOTH },
        { ", along with {items:received}", shut = true, bonus = BOTH },
        { ", and {items:received} with it", shut = true, bonus = BOTH },
        { ", generous by anyone's measure", needs = { "moneyReceived>=100000", "!received" }, says = { "size" } },
        { ", which is a lot at level {lvl:page.levelEnd}", needs = { "moneyReceived>=10000", "page.levelEnd<=20", "!received" }, says = { "size" } },
        { ", and I'm still a little stunned", needs = { "moneyReceived>=500000", "!received" }, says = { "size", "feel" } },
        { ", and I was touched", says = { "feel" }, voice = "warm" },
        { ", which was kind", says = { "feel" }, voice = "warm" },
        { ", which made my {part}", says = { "feel" }, voice = "warm" },
        { ", bless {him}", says = { "feel" }, voice = "warm" },
        { ", which I'll put to good use", says = { "feel" }, voice = "warm" },
        { ", which I'll be sure to remember", says = { "feel" }, voice = "warm" },
        { ", every copper of it welcome", needs = { "moneyReceived<10000", "!received" }, says = { "size", "feel" }, voice = "warm" },
        { ", not that I'm complaining", says = { "feel" }, voice = "wry" },
        { ", and I didn't argue", says = { "feel" }, voice = "wry" },
        { ", and I'm not about to say no to that", says = { "feel" }, voice = "wry" },
        { ", for no reason I could name", needs = { "!returned" }, says = { "why" }, voice = "wry" },
        { "{trade_lots:received}, and my bags are fuller for it", needs = { "!moneyReceived" }, bonus = 0.5, voice = "wry" },
        { ", which won't change my life but was nice all the same", needs = { "moneyReceived<1000", "!received" }, says = { "size" }, voice = "wry" },
        { ", nothing back", says = { "free" }, voice = "terse" },
        { ", and that was that", voice = "terse" },
        { ", much appreciated", says = { "feel" }, voice = "terse" },
        { ", first trade", needs = { "first" }, voice = "terse" },
        { ", no strings", says = { "free" }, voice = "terse" },
        { ", a kindness I'll remember", says = { "feel" }, voice = "warm" },
    },

    wholes = {
        { "{ref} gave me {items:received}.", bonus = -0.5, lead = true },
        { "{ref} gave me {coins:moneyReceived}.", bonus = -0.5, lead = true },
        { "{ref} gave me {items:received}, and took nothing for it.", says = { "free" }, lead = true },
        { "{ref} gave me {money:moneyReceived} {today}. Just like that.", says = { "sudden" }, lead = true },
        "{today.cap}, a gift from {ref.obj}: {items:received}.",
        { "{ref} gave me {items:received}, and {coins:moneyReceived} on top of that.", bonus = BOTH, lead = true },
        { "A gift from {ref.obj}: {items:received}, and {money:moneyReceived} with it.", bonus = BOTH },
        { "{ref} filled the trade window for me: {items:received}, plus {money:moneyReceived}. I put in nothing.", bonus = BOTH, says = { "free" } },
        { "I came away from {ref.obj} with {items:received}, and {money:moneyReceived} in my purse besides.", bonus = BOTH },
        { "{items.cap:received} from {ref.obj}, and {coins:moneyReceived} with it.", bonus = BOTH },
        { "{ref} gave me {items:received}, with {money:moneyReceived} on top. I was touched.", bonus = BOTH, voice = "warm", lead = true },
        { "{ref} gave me {items:received}, and then {money:moneyReceived} as well. I didn't ask questions.", bonus = BOTH, voice = "wry", lead = true },
        { "From {ref.short}: {items:received}, plus {money:moneyReceived}.", bonus = BOTH, voice = "terse" },
        { "I came away from a trade with {ref.obj} holding {items:received}, and {he} came away with nothing.", says = { "free" } },
        { "{ref.poss} side of the trade window held {items:received}. Mine stayed empty.", says = { "free" } },
        { "{ref} put {money:moneyReceived} in the trade window and took nothing out.", says = { "free" }, lead = true },
        { "{ref} put {items:received} in the trade window. I put in nothing, and it went through anyway.", says = { "free" } },
        { "{coins.cap:moneyReceived} from {ref.obj}, for nothing at all.", says = { "free" } },
        { "A one-sided trade with {ref.obj}: {items:received} to me, nothing to {him}.", says = { "free" } },
        { "{ref} gave me {coins:moneyReceived}, {money:moneyReceived} to be exact.", needs = { "moneyReceived>=30000", "!received" }, lead = true },
        { "{ref} gave me {items:received}. <trade.touched>", lead = true },
        { "{coins.cap:moneyReceived} from {ref.obj}. <trade.touched>", needs = { "!received" } },
        { "{ref} gave me {item:received}, among other things.", needs = { "#received>=2", "!moneyReceived" }, bonus = 0.25, lead = true },
        { "{trade_lots:received}{ref} loaded me up with {items:received}. My bags are fuller for it.", needs = { "!moneyReceived" }, bonus = 0.5 },
        { "{trade_lone:received}{ref} gave me {items:received}. Only one, but a gift's a gift.", needs = { "!moneyReceived" }, bonus = 0.5 },
        { "Now I owe {ref.short} one: {items:received}, for nothing.", needs = { "!returned" }, says = { "owe", "free" } },
        { "{ref} and I have traded before, but this time it all went one way: {he} gave me {items:received}.", needs = { "!first", "!returned" }, says = { "free" } },
        { "{ref} gave me {items:received} {today}. I owe {him} one.", needs = { "!returned" }, says = { "owe" } },
        -- first
        { "Our first trade, and it went one way: {ref} gave me {items:received}.", needs = { "first" }, says = { "free" } },
        { "Our first trade, and it went one way: {ref} gave me {money:moneyReceived}.", needs = { "first", "!received" }, says = { "free" } },
        { "It was the first time {ref} and I had ever traded, and {he} gave me {items:received}.", needs = { "first" } },
        { "{ref} and I had never traded before {today}, and the first thing {he} gave me was {coins:moneyReceived}.", needs = { "first", "!received" } },
        { "A first: {ref} and I traded, and I came away with {items:received}.", needs = { "first" } },
        { "Our first trade ever, and {ref} was the one giving: {items:received}.", needs = { "first" } },
        { "The first thing {ref} ever gave me: {items:received}. I'll remember that.", needs = { "first" }, voice = "warm" },
        { "We'd never traded before, {ref} and I, and {he} gave me {items:received} for nothing.", needs = { "first" }, says = { "free" }, voice = "warm" },
        { "First trade with {ref.short}, and I didn't even have to pay: {items:received}.", needs = { "first" }, says = { "free" }, voice = "wry" },
        { "First trade with {ref.short}. {items.cap:received}, all one way.", needs = { "first" }, says = { "free" }, voice = "terse" },
        -- back again
        { "I'd given {ref.obj} something {ago:returnDays}. {today.cap}, {he} gave me {items:received}.", needs = { "returned" } },
        { "{days.cap:returnDays} after I'd given {ref.obj} something, {he} gave me {coins:moneyReceived}.", needs = { "returned", "!received" } },
        { "{days.cap:returnDays} after I'd given {ref.obj} something, {he} gave me {items:received}.", needs = { "returned" } },
        { "I'd given {ref.obj} something before. {today.cap} it went the other way: {items:received}.", needs = { "returned" } },
        { "{ago.cap:returnDays} I gave {ref.obj} something. {today.cap} things came back round: {items:received} from {him}.", needs = { "returned" } },
        { "{ref} gave me {items:received} {today}. That evens us up, by my count.", needs = { "returned" }, lead = true },
        { "It came back round {today}: {ref} gave me {items:received}, {days:returnDays} after I'd given {him} something.", needs = { "returned" } },
        { "{ago.cap:returnDays}, I gave {ref.obj} something; {today} it came the other way, {items:received}.", needs = { "returned" } },
        { "So it goes both ways with {ref.short}: I'd given {him} something {ago:returnDays}, and {today} {he} gave me {items:received}.", needs = { "returned" }, voice = "warm" },
        { "What goes around: I gave {ref.obj} something {ago:returnDays}, and {today} {he} gave me {items:received}.", needs = { "returned" }, voice = "wry" },
        { "Gave {ref.obj} something {ago:returnDays}. {today.cap}, {he} gave me {items:received}.", needs = { "returned" }, voice = "terse" },
        -- money, sized
        { "{ref} handed me {money:moneyReceived} {today}. That's a small fortune.", needs = { "moneyReceived>=500000", "!received" }, says = { "size" }, lead = true },
        { "It's not every day someone hands me {money:moneyReceived}, but {ref} did {today}.", needs = { "moneyReceived>=100000", "!received" }, says = { "size" } },
        { "{ref} gave me {money:moneyReceived}. At level {lvl:page.levelEnd}, that's real money.", needs = { "moneyReceived>=10000", "page.levelEnd<=20", "!received" }, says = { "size" }, lead = true },
        { "{ref} gave me {money:moneyReceived} {today}. I'll try not to spend it all at once.", needs = { "moneyReceived<100", "!received" }, says = { "size" }, voice = "wry" },
        { "{ref} gave me {coins:moneyReceived}. Small, but I'll take it.", needs = { "moneyReceived<1000", "!received" }, says = { "size" }, voice = "wry" },
        { "{ref} handed me {money:moneyReceived} {today}, and I'm not going to ask.", needs = { "moneyReceived>=100000", "!received" }, says = { "size" }, voice = "wry" },
        { "I'd never have asked anyone for {money:moneyReceived}, but {ref} handed it over all the same.", needs = { "moneyReceived>=200000", "!received" }, says = { "size" }, voice = "warm" },
        { "Just {money:moneyReceived} from {ref.obj}, but it's the thought that counts.", needs = { "moneyReceived<1000", "!received" }, says = { "size" }, voice = "warm" },
        -- who they are
        { "Someone I didn't know gave me {items:received} {today}: {ref.noun}.", needs = STRANGER },
        { "{ref.noun}, no one I knew, gave me {coins:moneyReceived} for nothing.", needs = STRANGER, says = { "free" } },
        { "{ref.noun} I keep seeing around gave me {items:received} {today}.", needs = FAMILIAR },
        { "I've seen {ref.noun} around for a while; {today} {he} gave me {items:received}.", needs = FAMILIAR, voice = "warm" },
        { "{ref} gave me {items:received}. Friends like that are worth keeping.", needs = { "who.tags.friend" }, voice = "warm" },
        { "{ref.short}, of all people, gave me {items:received} {today}. I'm not sure what to make of it.", needs = { "who.tags.avoid" }, voice = "wry" },
        -- warm
        { "{ref} gave me {items:received} {today}. It touched me more than I expected.", voice = "warm", lead = true },
        { "{ref} gave me {items:received}, and it made my {part}.", voice = "warm", lead = true },
        { "{ref} topped up my purse {today}: {money:moneyReceived}, for nothing.", says = { "free" }, needs = { "!received" }, voice = "warm" },
        { "Some days people are kind. {today.cap} it was {ref.noun}, with {items:received}.", voice = "warm" },
        { "{ref} was generous {today}: {items:received}, all for me.", voice = "warm" },
        -- wry
        { "No idea what I did to deserve it, but {ref} gave me {items:received} {today}.", needs = { "!returned" }, says = { "why" }, voice = "wry" },
        { "Something for nothing {today}: {items:received}, from {ref.obj}.", says = { "free" }, voice = "wry" },
        { "{ref} gave me {items:received}. I looked for the catch and couldn't find one.", voice = "wry", lead = true },
        { "{ref} gave me {money:moneyReceived} {today}. I'm choosing not to feel like a charity case.", needs = { "!received", "moneyReceived>=1000" }, voice = "wry" },
        { "I'm {items:received} richer {today}, thanks to {ref.obj}.", voice = "wry" },
        { "Only one of us came out of the trade with anything, and it was me: {items:received} from {ref.obj}.", says = { "free" }, voice = "wry" },
        { "{ref} and I traded {today}, if you can call it trading: {he} gave me {items:received}, and I gave nothing.", says = { "free" }, voice = "wry" },
        { "{ref} gave me {items:received}. I gave {him} nothing, and I'm a little embarrassed about it.", says = { "free" }, voice = "wry" },
        { "{trade_lots:received}{ref} gave me {items:received}, and I still haven't worked out where to put it all.", needs = { "!moneyReceived" }, bonus = 0.5, voice = "wry" },
        -- terse
        { "{ref.short}: {items:received}. Nothing back.", says = { "free" }, voice = "terse" },
        { "Gift from {ref.obj}. {items.cap:received}.", voice = "terse" },
        { "{coins.cap:moneyReceived}, from {ref.obj}. Free.", says = { "free" }, needs = { "!received" }, voice = "terse" },
        { "From {ref.obj}: {money:moneyReceived}. Free.", says = { "free" }, needs = { "!received" }, voice = "terse" },
        { "{ref.short} gave; I took. {items.cap:received}.", voice = "terse" },
        { "{ref.short}. {items.cap:received}. No charge.", says = { "free" }, voice = "terse" },
        { "Got {items:received}. {ref.poss} gift.", voice = "terse" },
        { "First trade with {ref.short}: {coins:moneyReceived}, free.", needs = { "first", "!received" }, says = { "free" }, voice = "terse" },
        { "Owed {ref.short} nothing; got {items:received} anyway.", needs = { "!returned" }, voice = "terse" },
        { "It's the small things. {ref} gave me {items:received} {today}, and it lifted my {part}.", needs = { "!moneyReceived" }, voice = "warm" },
        { "{ref} gave me {coins:moneyReceived} {today}, and I was more grateful than I can say.", needs = { "!received" }, voice = "warm" },
    },
}, CORE))

--------------------------------------------------------------------------
-- given: I gave, they gave nothing
--------------------------------------------------------------------------

Words("trade", "given", Mark({
    needs = { "!received", "!moneyReceived" },
    must = { "gave" },

    stems = {
        { "For the first time, ", needs = { "first" } },
        { "The first time {ref} and I ever traded, ", needs = { "first" }, says = { "intro" } },
        { "Our first trade: ", needs = { "first" } },
        { "{ref} had given me something {ago:returnDays}, so {today} ", needs = { "returned" }, says = { "intro" } },
        { "{days.cap:returnDays} after {ref} gave me something, ", needs = { "returned" }, says = { "intro" } },
        { "Since {ref} had given me something before, ", needs = { "returned" }, says = { "intro" } },
        { "It was my turn, so ", me = true, needs = { "returned" } },
        { "To even things up, ", me = true, needs = { "returned" } },
        { "By way of thanks, ", me = true, needs = { "returned" }, voice = "warm" },
        { "To pay back an old kindness, ", me = true, needs = { "returned", "returnDays>=14" }, voice = "warm" },
        { "Settling an old debt, ", me = true, needs = { "returned", "returnDays>=14" }, voice = "wry" },
        { "[Free of charge|For nothing in return], ", me = true, says = { "free" } },
        { "In a one-sided trade, ", says = { "free" } },
        { "Without taking anything back, ", me = true, says = { "free" } },
        { "Feeling generous, ", me = true, needs = { "moneyGiven>=50000", "!given" }, says = { "why" }, voice = "warm" },
        { "Because it seemed right, ", me = true, says = { "why" }, voice = "warm" },
        { "In a fit of generosity, ", me = true, says = { "why" }, voice = "wry" },
        { "Because I could, ", me = true, says = { "why" }, voice = "wry" },
        { "My good deed for the {part}: ", me = true, voice = "wry" },
        { "{today.cap}: ", voice = "terse" },
        { "One-way trade: ", says = { "free" }, voice = "terse" },
        { "{today.cap}, ", bonus = -0.5 },
    },

    clauses = {
        -- items
        "I [gave|handed|passed] {ref.obj} {items:given}",
        { "I gave {items:given} to {ref.obj}", shut = true },
        { "I put {items:given} in the trade window for {ref.obj}", shut = true },
        { "{ref} got {items:given} from me", shut = true, them = true },
        { "{ref} came away with {items:given} of mine", shut = true, them = true },
        { "{items:given} went from my bags to {ref.obj}", shut = true, them = true },
        { "{items:given} changed hands, from me to {ref.obj}", shut = true, them = true },
        { "I passed {items:given} on to {ref.obj}", shut = true },
        "I set {ref.obj} up with {items:given}",
        "I spared {ref.obj} {items:given}",
        { "I parted with {items:given} in {ref.poss} favour", shut = true },
        { "I gave away {items:given} to {ref.obj}", shut = true, bonus = -0.5 },
        { "{ref.poss} side of the trade window stayed empty while mine held {items:given}", shut = true, them = true, says = { "free" } },
        { "I gave {ref.obj} {items:given} [for nothing|and took nothing back|without taking a thing]", shut = true, says = { "free" } },
        { "I let {ref.obj} have {items:given} for nothing", shut = true, says = { "free" } },
        { "a trade with {ref.obj} left {him} holding {items:given} and me holding nothing", them = true, says = { "free" }, final = true },
        { "{trade_lots:given}I loaded {ref.obj} up with {items:given}", bonus = 0.5 },
        { "I gave {ref.obj} {item:given} and more besides", needs = { "#given>=2" }, shut = true, bonus = 0.25 },
        { "I saw {ref.obj} right with {items:given}", voice = "warm" },
        { "I made {ref.obj} a present of {items:given}", voice = "warm" },
        { "I dropped {items:given} into {ref.poss} bags", shut = true, voice = "warm" },
        { "I sorted {ref.obj} out with {items:given}", voice = "warm" },
        { "I slipped {ref.obj} {items:given}", voice = "wry" },
        { "{ref} ended up with {items:given}, courtesy of me", shut = true, them = true, voice = "wry" },
        { "{trade_lots:given}I offloaded {items:given} onto {ref.obj}", needs = { "!moneyGiven" }, bonus = 0.5, voice = "wry" },
        { "I gave {ref.obj} {items:given}", voice = "terse" },
        { "I happily gave {ref.obj} {items:given}", says = { "feel" }, voice = "warm" },
        -- items and money
        { "I gave {ref.obj} {items:given}, plus {money:moneyGiven}", bonus = BOTH },
        { "I gave {ref.obj} {money:moneyGiven} along with {items:given}", bonus = BOTH },
        { "I handed {ref.obj} {items:given} with {coins:moneyGiven} on top", bonus = BOTH },
        -- money
        "I [gave|handed] {ref.obj} {money:moneyGiven}",
        "I [handed|passed] {ref.obj} {coins:moneyGiven}",
        { "{ref} got {money:moneyGiven} from me", shut = true, them = true },
        { "I put {money:moneyGiven} in the trade window for {ref.obj}", shut = true },
        { "I put {coins:moneyGiven} in {ref.poss} purse", shut = true },
        { "I made {ref.obj} {money:moneyGiven} richer", shut = true },
        { "{ref} went off {money:moneyGiven} the richer, thanks to me", shut = true, them = true, final = true },
        { "I gave {ref.obj} {coins:moneyGiven} <trade.free>", shut = true, says = { "free" } },
        { "I topped up {ref.poss} purse with {money:moneyGiven}", voice = "warm" },
        { "I slipped {ref.obj} {coins:moneyGiven}", voice = "wry" },
        { "{ref} came away {money:moneyGiven} richer, thanks to me", shut = true, them = true, voice = "wry" },
        { "I gave {ref.obj} {money:moneyGiven}, which is a lot of gold to part with", bonus = 0.5, needs = { "moneyGiven>=500000", "!given" }, says = { "size" }, final = true },
        { "I gave {ref.obj} {money:moneyGiven}, which I won't miss", bonus = 0.5, needs = { "moneyGiven<1000", "!given" }, says = { "size" }, final = true, voice = "wry" },
        -- back again, and first
        { "I paid back {ref.obj} with {items:given}", needs = { "returned" } },
        { "I paid back {ref.obj} with {coins:moneyGiven}", needs = { "returned" } },
        { "I returned the favour to {ref.obj} with {items:given}", needs = { "returned" } },
        { "I finally gave {ref.obj} something back: {items:given}", needs = { "returned", "returnDays>=7" }, final = true },
        { "I evened things up with {ref.obj}: {items:given}", needs = { "returned" }, final = true },
        { "it was my turn to give, and {ref} got {items:given}", nostem = true, them = true, needs = { "returned" }, final = true },
        { "I gave {items:given} to {ref.obj}, someone I'd never traded with before", needs = { "first" }, final = true },
        -- who they are
        { "{ref.noun}, no one I knew, got {items:given} from me", shut = true, them = true, needs = STRANGER, says = { "intro" } },
        { "I gave {items:given} to {ref.noun} I keep seeing around", shut = true, needs = FAMILIAR, says = { "intro" } },
        { "I gave {ref.obj} {items:given}, as one does for a friend", needs = { "who.tags.friend" }, final = true, voice = "warm" },
        { "I gave {items:given} to {ref.obj}, against my better judgement", needs = { "who.tags.avoid" }, final = true, voice = "wry" },
    },

    fragments = {
        "{items.cap:given} to {ref.obj}",
        "{coins.cap:moneyGiven} to {ref.obj}",
        "A gift for {ref.obj}: {items:given}",
        "A gift for {ref.obj}: {money:moneyGiven}",
        "Something for {ref.obj}: {items:given}",
        "From me to {ref.obj}: {items:given}",
        "My gift to {ref.obj}: {items:given}",
        "Given away to {ref.obj}: {items:given}",
        "Handed {ref.obj} {items:given}",
        { "{items.cap:given}, free, to {ref.obj}", shut = true, says = { "free" } },
        { "{items.cap:given} for {ref.obj}, and nothing back", shut = true, says = { "free" } },
        { "A gift for {ref.obj}: {items:given}, with {money:moneyGiven} on top", bonus = BOTH, final = true },
        { "{items.cap:given}, plus {coins:moneyGiven}, to {ref.obj}", bonus = BOTH, final = true },
        { "Paid back {ref.obj} with {items:given}", needs = { "returned" } },
        { "Paid back {ref.obj} with {coins:moneyGiven}", needs = { "returned" } },
        { "{days.cap:returnDays} after {ref.poss} gift, one of mine: {items:given}", needs = { "returned" } },
        { "First trade with {ref.obj}, and all from my side: {items:given}", needs = { "first" }, says = { "free" } },
        { "{items.cap:given} for {ref.obj}, no one I knew", needs = STRANGER, final = true },
        { "{trade_lots:given}An armful for {ref.obj}: {items:given}", bonus = 0.5 },
        { "{trade_few:given}A little something for {ref.obj}: {items:given}", needs = { "!moneyGiven" }, bonus = 0.5, voice = "warm" },
        { "Gift of the {part}, from me to {ref.obj}: {items:given}", voice = "warm" },
        { "Out of my bags and over to {ref.obj}: {items:given}", voice = "wry" },
        { "{coins.cap:moneyGiven} out of my purse and into {ref.poss} pocket", shut = true, voice = "wry" },
        { "Poorer by {money:moneyGiven}, and {ref.short} the richer", shut = true, voice = "wry" },
        { "Gave {ref.obj} {items:given}", voice = "terse" },
        { "To {ref.obj}: {items:given}, <trade.free>", shut = true, says = { "free" }, voice = "terse" },
        { "My turn: {items:given} for {ref.obj}", shut = true, needs = { "returned" }, voice = "terse" },
        { "{trade_lone:given}One thing for {ref.obj}: {items:given}", bonus = 0.5, voice = "terse" },
        { "Gift to {ref.short}: {items:given}", voice = "terse" },
        { "To {ref.short}: {money:moneyGiven}", needs = { "!given" }, voice = "terse" },
    },

    tails = {
        { ", <trade.free>", says = { "free" } },
        { ", and nothing came back", says = { "free" } },
        { ", with nothing in return", says = { "free" } },
        { ", [our first trade|the first time we'd ever traded|the first trade between us]", needs = { "first" } },
        { ", the first time anything had changed hands between us", needs = { "first" } },
        { ", and I didn't think twice", says = { "feel" } },
        { ", to pay {him} back for something from {ago:returnDays}", needs = { "returned" }, says = { "free" } },
        { ", {days:returnDays} after {he} had given me something", needs = { "returned" } },
        { ", in return for something {he} gave me {ago:returnDays}", needs = { "returned" }, says = { "free" } },
        { ", which [squares us, I think|makes us about even, I think]", needs = { "returned" } },
        { ", so it's gone both ways between us now", needs = { "returned" } },
        { ", which seemed only fair after what {he} gave me", needs = { "returned" } },
        { ", plus {money:moneyGiven}", shut = true, bonus = BOTH },
        { ", and {coins:moneyGiven} on top", shut = true, bonus = BOTH },
        { ", along with {items:given}", shut = true, bonus = BOTH },
        { ", and {items:given} with it", shut = true, bonus = BOTH },
        { ", no small sum to part with", needs = { "moneyGiven>=100000", "!given" }, says = { "size" } },
        { ", and I was glad to", says = { "feel" }, voice = "warm" },
        { ", and it felt good", says = { "feel" }, voice = "warm" },
        { ", and I hope it helps", says = { "feel" }, voice = "warm" },
        { ", and {he} is welcome to it", says = { "feel" }, voice = "warm" },
        { ", and I'd do it again", says = { "feel" }, voice = "warm" },
        { ", every copper of it gladly given", needs = { "moneyGiven<10000", "!given" }, says = { "size", "feel" }, voice = "warm" },
        { ", for what it's worth", says = { "feel" }, voice = "wry" },
        { ". Generosity or bag space; I'm not saying which", needs = { "given" }, says = { "why" }, voice = "wry", final = true },
        { ", because why not", says = { "why" }, voice = "wry" },
        { ", which my purse will feel", needs = { "moneyGiven>=100000", "!given" }, says = { "size" }, voice = "wry" },
        { "{trade_lots:given}, and my bags are lighter for it", needs = { "!moneyGiven" }, bonus = 0.5, voice = "wry" },
        { ", nothing back", says = { "free" }, voice = "terse" },
        { ", and that was that", voice = "terse" },
        { ", gladly", says = { "feel" }, voice = "terse" },
        { ", first trade", needs = { "first" }, voice = "terse" },
        { ", no strings", says = { "free" }, voice = "terse" },
        { ", with my blessing", says = { "feel" }, voice = "warm" },
    },

    wholes = {
        { "I gave {ref.obj} {items:given}.", bonus = -0.5, lead = true },
        { "I gave {ref.obj} {coins:moneyGiven}.", bonus = -0.5, lead = true },
        { "{ref} got {items:given} from me {today}, and nothing came back.", says = { "free" }, lead = true },
        { "I put {items:given} in the trade window for {ref.obj} and took nothing out.", says = { "free" }, lead = true },
        { "{ref.poss} side of the trade window stayed empty. Mine held {items:given}.", says = { "free" } },
        { "A one-sided trade with {ref.obj}: {items:given} to {him}, nothing to me.", says = { "free" } },
        { "{coins.cap:moneyGiven} to {ref.obj}, for nothing at all.", says = { "free" }, needs = { "!given" } },
        "{today.cap} I was the one giving: {items:given} to {ref.obj}.",
        { "I gave {ref.obj} {money:moneyGiven}, and {items:given} besides.", bonus = BOTH, lead = true },
        { "{today.cap}, a gift for {ref.obj}: {items:given}, and {coins:moneyGiven} with it.", bonus = BOTH },
        { "I filled the trade window for {ref.obj}: {items:given}, plus {money:moneyGiven}, and took nothing out.", bonus = BOTH, says = { "free" } },
        { "{ref} came away with {items:given} of mine, and {coins:moneyGiven} besides.", bonus = BOTH, lead = true },
        { "I gave {ref.obj} {items:given}, with {money:moneyGiven} on top. I hope it helps.", bonus = BOTH, voice = "warm", lead = true },
        { "I gave {ref.obj} {items:given}, and {money:moneyGiven} as well, for reasons I'll keep to myself.", bonus = BOTH, voice = "wry", lead = true },
        { "To {ref.short}: {items:given}, plus {money:moneyGiven}.", bonus = BOTH, voice = "terse" },
        { "I gave {ref.obj} {coins:moneyGiven}, {money:moneyGiven} to be exact.", needs = { "moneyGiven>=30000", "!given" }, lead = true },
        { "I gave {ref.obj} {items:given}. <trade.giving>", lead = true },
        { "I gave {ref.obj} {item:given}, among other things.", needs = { "#given>=2", "!moneyGiven" }, bonus = 0.25, lead = true },
        { "I gave {ref.obj} {items:given}, and I didn't want anything for it.", says = { "free" }, lead = true },
        { "{ref} and I have traded before, but this time it all went one way: I gave {him} {items:given}.", needs = { "!first", "!returned" }, says = { "free" } },
        { "A little generosity {today}: {items:given} to {ref.obj}.", voice = "warm" },
        -- back again
        { "{ref} had given me something {ago:returnDays}. {today.cap} I gave {him} {items:given} back.", needs = { "returned" } },
        { "I owed {ref.obj} one from {ago:returnDays}, so {today} I gave {him} {items:given}.", needs = { "returned" } },
        { "{days.cap:returnDays} after {ref} gave me something, I gave {him} {money:moneyGiven} in return.", needs = { "returned", "!given" } },
        { "It was my turn: {ref} had given me something {ago:returnDays}, so I gave {him} {items:given}.", needs = { "returned" } },
        { "{ago.cap:returnDays}, {ref} gave me something. {today.cap} I returned the favour with {items:given}.", needs = { "returned" } },
        { "I'd owed {ref.obj} for {days:returnDays}. {today.cap} I squared it: {items:given}.", needs = { "returned" } },
        { "{ref} had given me something before, so {today} it was my turn: {items:given}.", needs = { "returned" } },
        { "Gave {ref.obj} something back {today}: {items:given}. It had been {days:returnDays} since {he} gave me something.", needs = { "returned" } },
        { "I hadn't forgotten {ref.poss} gift from {ago:returnDays}. {today.cap} I gave {him} {items:given}.", needs = { "returned" } },
        { "A debt paid: {ref} had given me something {ago:returnDays}, and {today} I gave {him} {items:given}.", needs = { "returned" } },
        { "Paid back at last: {items:given} to {ref.obj}, {days:returnDays} after {he} gave me something.", needs = { "returned", "returnDays>=10" } },
        { "So it goes both ways now: {ref} gave me something {ago:returnDays}, and {today} I gave {him} {items:given}.", needs = { "returned" }, voice = "warm" },
        { "One good turn deserves another. {ref} gave me something {ago:returnDays}; {today} I gave {him} {items:given}.", needs = { "returned" }, voice = "warm" },
        { "Turnabout {today}: {ref} gave me something {ago:returnDays}, and now I've given {him} {items:given}.", needs = { "returned" }, voice = "wry" },
        { "Paid {ref.obj} back {today}: {items:given}.", needs = { "returned" }, voice = "terse" },
        -- first
        { "Our first trade, and it went one way: I gave {ref.obj} {items:given}.", needs = { "first" }, says = { "free" } },
        { "The first thing I ever gave {ref.obj}: {items:given}.", needs = { "first" } },
        { "{ref} and I had never traded before {today}, and it was me who did the giving: {items:given}.", needs = { "first" } },
        { "A first: {ref} and I traded, and {he} came away with {items:given}.", needs = { "first" } },
        { "It was our first trade, and I was glad it was me giving: {items:given} to {ref.obj}.", needs = { "first" }, voice = "warm" },
        { "First trade with {ref.short}, and I did all the giving: {items:given}. A strange way to start.", needs = { "first" }, says = { "free" }, voice = "wry" },
        { "First trade with {ref.short}. Gave {him} {items:given}.", needs = { "first" }, voice = "terse" },
        -- money, sized
        { "I gave {ref.obj} {coins:moneyGiven}. Hardly a fortune, but it's something.", needs = { "moneyGiven<10000", "!given" }, says = { "size" }, lead = true },
        { "It's not every day I hand someone {money:moneyGiven}, but {ref} got it {today}.", needs = { "moneyGiven>=100000", "!given" }, says = { "size" } },
        { "I gave {ref.obj} {money:moneyGiven}. At level {lvl:page.levelEnd}, that's not nothing.", needs = { "moneyGiven>=10000", "page.levelEnd<=20", "!given" }, says = { "size" }, lead = true },
        { "I gave {ref.obj} {money:moneyGiven} {today}. Easy come, easy go.", needs = { "moneyGiven<10000", "!given" }, says = { "size" }, voice = "wry" },
        { "I gave {ref.obj} {money:moneyGiven} {today}. My purse felt that.", needs = { "moneyGiven>=100000", "!given" }, says = { "size" }, voice = "wry" },
        { "I handed {ref.obj} {money:moneyGiven}, and tried not to think about it.", needs = { "moneyGiven>=100000", "!given" }, says = { "size" }, voice = "wry", lead = true },
        { "I gave {ref.obj} {money:moneyGiven}. Big spender, me.", needs = { "moneyGiven<100", "!given" }, says = { "size" }, voice = "wry" },
        { "I gave {ref.obj} {money:moneyGiven}, more than I've ever handed anyone in one go.", needs = { "moneyGiven>=1000000", "!given" }, says = { "size" }, voice = "warm" },
        -- who they are
        { "I gave {items:given} to {ref.obj}, a complete stranger.", needs = STRANGER },
        { "Someone I didn't know got {items:given} from me {today}: {ref.noun}.", needs = STRANGER, voice = "warm" },
        { "{ref.noun} I keep seeing around got {items:given} from me {today}.", needs = FAMILIAR },
        { "I gave {ref.obj} {items:given}. That's what friends are for.", needs = { "who.tags.friend" }, voice = "warm" },
        { "I gave {items:given} to {ref.obj}, of all people. I'm as surprised as anyone.", needs = { "who.tags.avoid" }, voice = "wry" },
        -- warm
        { "I gave {ref.obj} {items:given} {today}. It felt good to give something away.", voice = "warm", lead = true },
        { "I gave {ref.obj} {items:given}, and I'm glad I did.", voice = "warm", lead = true },
        { "I topped up {ref.poss} purse {today}: {money:moneyGiven}, for nothing.", says = { "free" }, needs = { "!given" }, voice = "warm" },
        { "There's a pleasure in giving that I keep forgetting. {today.cap} it was {items:given}, to {ref.obj}.", voice = "warm" },
        -- wry
        { "I gave {ref.obj} {items:given}. Generosity or bag space; I'm not saying which.", says = { "why" }, voice = "wry", lead = true },
        { "{ref} is now the proud owner of {items:given}, courtesy of me.", voice = "wry" },
        { "I'm {items:given} lighter {today}, and {ref} is the richer for it.", voice = "wry" },
        { "My purse is {money:moneyGiven} lighter {today}, and {ref} is that much richer.", needs = { "!given" }, voice = "wry" },
        { "{ref} and I traded {today}, if you can call it that: I gave {him} {items:given}, and got nothing.", says = { "free" }, voice = "wry" },
        { "{trade_lone:given}I gave {ref.obj} {items:given}. Only one, but it's the thought that counts.", needs = { "!moneyGiven" }, bonus = 0.5, voice = "wry" },
        { "{trade_lots:given}I gave {ref.obj} {items:given}. My bags are lighter, and I don't mind.", needs = { "!moneyGiven" }, bonus = 0.5, voice = "wry" },
        { "Good deed done: {items:given} to {ref.obj}.", voice = "wry" },
        -- terse
        { "Gave {ref.obj} {items:given}. Nothing back.", says = { "free" }, voice = "terse" },
        { "{coins.cap:moneyGiven} to {ref.obj}, no charge.", says = { "free" }, needs = { "!given" }, voice = "terse" },
        { "To {ref.short}: {items:given}.", voice = "terse" },
        { "I gave; {ref.short} took. {items.cap:given}.", voice = "terse" },
        { "{ref.short}. {items.cap:given}, from me. No charge.", says = { "free" }, voice = "terse" },
        { "Owed {ref.short} one. Paid: {items:given}.", needs = { "returned" }, voice = "terse" },
        { "First trade with {ref.short}: {coins:moneyGiven}, free.", needs = { "first", "!given" }, says = { "free" }, voice = "terse" },
        { "I gave {ref.obj} {coins:moneyGiven} {today}. It cost me little and felt like a lot.", needs = { "moneyGiven<10000", "!given" }, says = { "size" }, voice = "warm" },
    },
}, CORE))

--------------------------------------------------------------------------
-- swap: both ways
--------------------------------------------------------------------------

Words("trade", "swap", Mark({
    must = { "got", "gave" },

    stems = {
        { "For the first time, ", needs = { "first" } },
        { "In the first trade we'd ever made, ", needs = { "first" } },
        { "The first time {ref} and I ever traded, ", needs = { "first" }, says = { "intro" } },
        "[A bit of business|A swap|A trade] {today}: ",
        { "Business with {ref.obj}: ", says = { "intro" } },
        { "In a straight swap, ", needs = { "!moneyReceived", "!moneyGiven" } },
        { "In what looked like a fair swap, ", says = { "fair" } },
        "Not a gift either way, but a trade: ",
        { "One good turn for another: ", needs = { "!moneyReceived", "!moneyGiven" }, voice = "warm" },
        { "In a deal that suited me, ", says = { "feel" }, voice = "warm" },
        { "Fair's fair, I suppose: ", says = { "fair" }, voice = "wry" },
        { "Strictly business: ", voice = "wry" },
        { "Commerce: ", voice = "wry" },
        { "Trade: ", voice = "terse" },
        { "{today.cap}, ", bonus = -0.5 },
    },

    clauses = {
        -- items for items
        "I [traded|swapped] {items:given} for {items:received} with {ref.obj}",
        "I traded {ref.obj} {items:given} for {items:received}",
        "{ref} gave me {items:received} for {items:given}",
        "I gave {ref.obj} {items:given} and got {items:received} back",
        { "{ref} handed over {items:received}, and I handed over {items:given}", final = true },
        { "{items:given} went to {ref.obj}, and {items:received} came back", final = true },
        "{ref} and I [did a deal|traded]: {items:given} from me, {items:received} from {him}",
        { "I came away from {ref.obj} with {items:received}, and {he} came away with {items:given}", final = true },
        { "{ref} got {items:given}, and I got {items:received}", final = true },
        { "{ref} took {items:given}, and I took {items:received}", final = true },
        "I let {ref.obj} have {items:given} in exchange for {items:received}",
        { "{ref} relieved me of {items:given} in exchange for {items:received}", voice = "wry" },
        { "I parted with {items:given} and got {items:received} for my trouble", voice = "wry" },
        -- bought
        "I bought {items:received} from {ref.obj} for {money:moneyGiven}",
        "{ref} sold me {items:received} for {money:moneyGiven}",
        "I paid {ref.obj} {money:moneyGiven} for {items:received}",
        "{ref} let me have {items:received} for {coins:moneyGiven}",
        "I picked up {items:received} from {ref.obj} for {money:moneyGiven}",
        "I handed {ref.obj} {money:moneyGiven} and came away with {items:received}",
        "I parted with {money:moneyGiven} and got {items:received} for it",
        { "I bought {items:received} off {ref.obj}", needs = { "!given" } },
        -- sold
        "I sold {ref.obj} {items:given} for {money:moneyReceived}",
        "{ref} bought {items:given} off me for {money:moneyReceived}",
        "{ref} paid me {money:moneyReceived} for {items:given}",
        "{ref} took {items:given} off my hands for {money:moneyReceived}",
        "I let {ref.obj} have {items:given} for {coins:moneyReceived}",
        "{items:given} went to {ref.obj} for {money:moneyReceived}",
        { "I sold {items:given} to {ref.obj}", needs = { "!received" } },
        -- items and money on one side
        { "{ref} gave me {items:received}, with {money:moneyReceived} on top, for {items:given}", bonus = 1, final = true },
        { "I gave {ref.obj} {items:given}, with {money:moneyGiven} on top, for {items:received}", bonus = 1, final = true },
        { "{ref} gave me {items:received}, plus {money:moneyReceived}", bonus = 0.5 },
        { "I gave {ref.obj} {items:given}, plus {money:moneyGiven}", bonus = 0.5 },
        -- one side, the other told by the tail
        "I [gave|handed] {ref.obj} {items:given}",
        "{ref} [gave|handed] me {items:received}",
        "I paid {ref.obj} {money:moneyGiven}",
        "{ref} paid me {money:moneyReceived}",
        -- neither side, both told by the tail
        { "{ref} and I [traded for the first time|did our first deal|made our first trade]", needs = { "first" } },
        -- voiced
        { "I happily traded {ref.obj} {items:given} for {items:received}", says = { "feel" }, voice = "warm" },
        { "I was glad to swap {items:given} for {items:received} with {ref.obj}", says = { "feel" }, voice = "warm" },
        { "I was happy to pay {ref.obj} {money:moneyGiven} for {items:received}", says = { "feel" }, voice = "warm" },
        { "I was happy to let {ref.obj} have {items:given} for {money:moneyReceived}", says = { "feel" }, voice = "warm" },
        { "{ref} and I did each other a good turn, {items:given} for {items:received}", voice = "warm" },
        { "{ref} sold me {items:received} for {money:moneyGiven}, and I was glad of it", voice = "warm", final = true },
        { "I talked myself into paying {ref.obj} {money:moneyGiven} for {items:received}", voice = "wry" },
        { "I unloaded {items:given} on {ref.obj} for {money:moneyReceived}", voice = "wry" },
        { "I sold {ref.obj} {items:given} for {money:moneyReceived}", voice = "terse" },
    },

    fragments = {
        "[Traded|Swapped] {items:given} for {items:received} with {ref.obj}",
        "A trade with {ref.obj}: {items:given} from me, {items:received} from {him}",
        "{items.cap:received} from {ref.short}, {items:given} from me",
        "Bought {items:received} from {ref.obj} for {money:moneyGiven}",
        "Sold {ref.obj} {items:given} for {money:moneyReceived}",
        "A deal with {ref.obj}: {money:moneyGiven} from me for {items:received}",
        "A deal with {ref.obj}: {items:given} from me for {money:moneyReceived}",
        "{coins.cap:moneyReceived} from {ref.obj} for {items:given}",
        "{coins.cap:moneyGiven} to {ref.obj} for {items:received}",
        "Got {money:moneyReceived} from {ref.obj} for {items:given}",
        "{items.cap:received} for {money:moneyGiven}, from {ref.obj}",
        "Gave {ref.obj} {items:given}",
        "Got {items:received} from {ref.obj}",
        { "First trade with {ref.obj}: I gave {items:given} and got {items:received}", needs = { "first" } },
        { "My first trade with {ref.obj}: I bought {items:received} for {money:moneyGiven}", needs = { "first" } },
        { "My first trade with {ref.obj}: I sold {him} {items:given} for {money:moneyReceived}", needs = { "first" } },
        { "Out went {items:given}, in came {items:received}, courtesy of {ref.obj}", voice = "wry" },
        { "{items.cap:received} from {ref.obj}, at the cost of {money:moneyGiven}", voice = "wry" },
        { "Paid {ref.obj} {money:moneyGiven} for {items:received}", voice = "terse" },
        { "Gave {ref.obj} {items:given}, got {items:received}", voice = "terse" },
        { "{items.cap:given} to {ref.short}, {items:received} back", voice = "terse" },
        { "Sold to {ref.obj}: {items:given}, for {money:moneyReceived}", voice = "terse" },
        { "A happy swap with {ref.obj}: {items:given} for {items:received}", voice = "warm" },
        { "A good buy from {ref.obj}: {items:received}, for {money:moneyGiven}", voice = "warm" },
        { "A good sale to {ref.obj}: {items:given}, for {money:moneyReceived}", voice = "warm" },
        { "Commerce with {ref.obj}: {items:given} out, {money:moneyReceived} in", voice = "wry" },
    },

    tails = {
        -- the other side
        ", and I got {items:received} back",
        ", [in exchange|in return] for {items:received}",
        ", [in exchange|in return] for {money:moneyReceived}",
        ", [in exchange|in return] for {items:given}",
        ", [in exchange|in return] for {money:moneyGiven}",
        ", and I gave {him} {items:given} in return",
        ", and {he} paid me {money:moneyReceived}",
        ", and I paid {him} {money:moneyGiven}",
        ", and {coins:moneyReceived} came back my way",
        " for {coins:moneyGiven}",
        { ", and got {items:received} back, with {money:moneyReceived} on top", bonus = 0.5 },
        { ", and I gave {him} {items:given}, with {money:moneyGiven} on top", bonus = 0.5 },
        -- both sides
        ", {items:given} going {his} way and {items:received} coming mine",
        ", {items:given} from me for {items:received} from {him}",
        ", {money:moneyGiven} from me for {items:received}",
        ", {items:given} from me for {money:moneyReceived}",
        -- neither
        { ", [our first trade|the first time we'd traded|the first deal we've done]", needs = { "first" } },
        { ", which seemed fair to me", says = { "fair" } },
        { ", fair enough as far as I can tell", says = { "fair" } },
        { ", and both of us came away with something", says = { "fair" } },
        { ", a straight swap", needs = { "!moneyReceived", "!moneyGiven" } },
        { ", which will do nicely", says = { "feel" } },
        { ", which suited me", says = { "feel" }, voice = "warm" },
        { ", and I'm happy with that", says = { "feel" }, voice = "warm" },
        { ", and I think we both did well out of it", says = { "fair" }, voice = "warm" },
        { ", and I was glad to do it", says = { "feel" }, voice = "warm" },
        { ", a trade I'd happily make again", says = { "feel" }, voice = "warm" },
        { ", which I'll call a fair price", says = { "fair" }, voice = "wry" },
        { ", which I'll call even", says = { "fair" }, voice = "wry" },
        { ", and I've no idea who got the better end", says = { "fair" }, voice = "wry" },
        { ", and I think I came out ahead", says = { "fair" }, voice = "wry" },
        { ", and that was that", voice = "terse" },
        { ", deal done", voice = "terse" },
        { ", simple as that", voice = "terse" },
    },

    wholes = {
        { "I traded {items:given} to {ref.obj} for {items:received}.", bonus = -0.5, lead = true },
        { "I traded {ref.obj} {items:given} for {items:received} {today}.", lead = true },
        { "{ref} paid me {money:moneyReceived} for {items:given} {today}.", lead = true },
        "{items.cap:received} from {ref.obj} cost me {money:moneyGiven}.",
        { "I earned {money:moneyReceived} {today}, selling {items:given} to {ref.obj}.", lead = true },
        "{today.cap} I bought {items:received} from {ref.obj}. It cost me {money:moneyGiven}.",
        { "{ref} bought {items:given} off me {today} for {money:moneyReceived}.", lead = true },
        { "{ref} and I did some business {today}: {he} sold me {items:received} for {money:moneyGiven}." },
        { "A fair swap, I think: {items:given} to {ref.obj}, {items:received} to me.", says = { "fair" } },
        { "I paid {ref.obj} {money:moneyGiven} for {items:received}, which seemed fair enough.", says = { "fair" }, lead = true },
        { "I swapped {items:given} for {items:received} with {ref.obj}, and we both came away with something.", says = { "fair" }, lead = true },
        "Not a gift either way, a proper trade: {items:given} to {ref.obj}, {items:received} back.",
        "{ref} and I traded {today}. {he} came away with {items:given}, and I came away with {items:received}.",
        "Money for goods: {money:moneyGiven} to {ref.obj}, {items:received} to me.",
        "Goods for money: {items:given} to {ref.obj}, {money:moneyReceived} to me.",
        { "{ref} took {items:given}; I took {items:received}. [Fair enough, as far as I can tell|Fair, I think|That seemed about right].", says = { "fair" } },
        { "A straight swap {today}: I gave {ref.obj} {items:given}, and {he} gave me {items:received}.", needs = { "!moneyReceived", "!moneyGiven" } },
        { "{trade_lots:received}I traded {ref.obj} {items:given} for a whole armful of things: {items:received}.", bonus = 0.5 },
        { "I gave {ref.obj} {money:moneyGiven} on top of {items:given}, and got {items:received} back.", bonus = 1, lead = true },
        { "For {items:given}, {ref} gave me {items:received} with {money:moneyReceived} on top.", bonus = 1 },
        { "{items.cap:received} from {ref.obj} cost me {items:given}, plus {money:moneyGiven}.", bonus = 1 },
        -- first
        { "Our first trade: I gave {ref.obj} {items:given}, and {he} gave me {items:received}.", needs = { "first" } },
        { "{ref} and I traded for the first time {today}. I gave {items:given} and got {items:received}.", needs = { "first" } },
        { "The first time {ref} and I ever traded, I paid {money:moneyGiven} for {items:received}.", needs = { "first" } },
        { "The first time {ref} and I ever traded, {he} paid me {money:moneyReceived} for {items:given}.", needs = { "first" } },
        { "First deal with {ref.short}: {he} sold me {items:received} for {money:moneyGiven}.", needs = { "first" }, voice = "terse" },
        { "We'd never traded before, {ref} and I, but {today} {he} took {items:given} and I took {items:received}.", needs = { "first" }, voice = "warm" },
        -- who they are
        { "I traded with a stranger {today}, {ref.noun}: {items:given} for {items:received}.", needs = STRANGER },
        { "{ref.noun} I keep seeing around bought {items:given} off me for {coins:moneyReceived}.", needs = FAMILIAR },
        { "{ref} sold me {items:received} for {money:moneyGiven}. I'd buy from {him} again.", needs = { "who.tags.friend" }, voice = "warm" },
        -- warm
        { "{ref} took {items:given} off my hands for {coins:moneyReceived}, which suited me.", voice = "warm", lead = true },
        { "{ref} got {items:given}, and I got {items:received}. A good trade for both of us, I hope.", voice = "warm" },
        { "A good trade {today}: I gave {ref.obj} {items:given} and came away with {items:received}.", voice = "warm" },
        { "I traded {ref.obj} {items:given} for {items:received}. Not a gift, but it felt like one.", voice = "warm", lead = true },
        -- wry
        { "I gave {ref.obj} {items:given} and got {items:received} back. I've no idea who did better out of it.", says = { "fair" }, voice = "wry", lead = true },
        { "I sold {ref.obj} {items:given} for {money:moneyReceived}. Not a bad {part}'s business.", voice = "wry", lead = true },
        { "{ref} let me have {items:received} for {money:moneyGiven}. I didn't argue.", voice = "wry", lead = true },
        { "{ref} sold me {items:received} for {money:moneyGiven}. I'll pretend it was a bargain.", voice = "wry", lead = true },
        { "I paid {ref.obj} {money:moneyGiven} for {items:received}. Steep, maybe, but done.", needs = { "moneyGiven>=100000" }, voice = "wry", lead = true },
        { "I sold {items:given} to {ref.obj} for {money:moneyReceived}. Pocket money.", needs = { "moneyReceived<10000" }, voice = "wry", lead = true },
        { "A little light commerce {today}: {ref} got {items:given}, and I got {coins:moneyReceived}.", voice = "wry" },
        { "{ref} paid me {money:moneyReceived} for {items:given}. At level {lvl:page.levelEnd}, I'll take that.", needs = { "moneyReceived>=10000", "page.levelEnd<=20" }, voice = "wry", lead = true },
        { "{trade_lone:given}{trade_lots:received}I gave {ref.obj} {items:given} and got {items:received} for it. I'm not complaining.", bonus = 1, voice = "wry" },
        { "{trade_lots:given}{trade_lone:received}I gave {ref.obj} {items:given} for {items:received}. Whether that was a good deal, I can't say.", bonus = 1, voice = "wry" },
        -- terse
        { "Traded with {ref.obj}: {items:given} out, {items:received} in.", voice = "terse" },
        { "Swap with {ref.short}. Gave {items:given}, got {items:received}.", voice = "terse" },
        { "Bought {items:received} off {ref.obj}, {money:moneyGiven}.", voice = "terse" },
        { "Sold {items:given} to {ref.obj}, {money:moneyReceived}.", voice = "terse" },
        { "Sold {ref.short} {items:given}. {coins.cap:moneyReceived}.", voice = "terse" },
        { "Bought {items:received} from {ref.short}. {coins.cap:moneyGiven}.", voice = "terse" },
        { "In: {items:received}. Out: {items:given}. Trade with {ref.short}.", voice = "terse" },
        { "{ref} and I swapped {items:given} for {items:received} {today}. It's nice when a trade works out.", voice = "warm" },
        { "I was glad to pay {ref.obj} {money:moneyGiven} for {items:received}. Worth every copper.", voice = "warm" },
        { "Sold {items:given} to {ref.obj} for {money:moneyReceived}, and glad to.", voice = "warm" },
        { "I bought {items:received} from {ref.obj} for {money:moneyGiven}, and I'd do it again.", voice = "warm" },
        { "{ref} paid me {money:moneyReceived} for {items:given}. I'm sure I undercharged.", voice = "wry" },
        { "I paid {ref.obj} {money:moneyGiven} for {items:received}. Somewhere, a vendor is weeping.", needs = { "moneyGiven<1000" }, voice = "wry" },
    },
}, ALL, true))
