-- PvP: world PvP with a hostile player. They killed me (death), or we
-- killed them (kill).
--
-- death facts
--   who               the hostile player who killed me (often named)
--   probable          the kill is inferred, not certain: every claim about
--                     who did it must be hedged
--   spell             the killing blow's ability name, when known
--   timesKilledMe     how often they have killed me, this one included (1+)
--   lastDeathWhen     when they last killed me before this (a time; with
--                     timesKilledMe 2+)
--   toldBefore        the diary told an earlier one (timesKilledMe 2+), so
--                     callbacks ("the same rogue as before") are safe
--   zone, subZone     where I was
--   outlevelled       they were five or more levels above me
--
-- kill facts
--   who               the hostile player we killed
--   by                the groupmate who landed the blow (a person), or
--   mine              I landed it
--   timesKilledThem   how often we have killed them, this one included (1+)
--   revenge           they had killed me before
--   zone              where I was
--
-- Hedging. Every death sentence must say "pvp_sure": that the killer is
-- named with the right certainty. Three kinds of piece say it:
--   - pieces with {pvp_h:...}, which hedges when the kill is probable and
--     says nothing when it is certain;
--   - pieces that need "probable" and hedge in their own words;
--   - pieces that need "!probable" and state it flat.
-- A bare clause ("{ref} caught me {at:subZone}") says none of it, so it is
-- only written after a stem {pvp_h:lead} or before a tail {pvp_h:tail}.
--
-- Slots declared here
--   {pvp_h:adv}    "probably " when probable, else nothing: "{ref} {pvp_h:adv}killed me"
--   {pvp_h:lead}   "as far as I can tell, ", "I think ", ... or nothing, to open a clause
--   {pvp_h:tail}   ", I think", ", as far as I can tell", ... or nothing, to end one
--   {pvp_named}    nothing, and only when they go by name ("Morthis again")
--   {pvp_known}    nothing, and only when they go by name, look familiar or
--                  were mentioned in an earlier sentence, so "again" can
--                  follow them
--
-- In kill sentences two people are about, so pieces use {ref} and {ref:by}
-- (which turn into pronouns only when that is unambiguous) rather than
-- {he} and {him}. Every kill sentence must say "pvp_blow": who landed it.
-- Revenge is measured: evened up, a small measure, never gloating. No
-- piece says what the other player wanted, meant or felt.

local addonName, ns = ...

local Pages = ns.Pages
local Words = Pages.Words

Pages.Angle("pvp", { order = { "death", "kill" }, about = "world PvP with a hostile player" })

--------------------------------------------------------------------------
-- Slots
--------------------------------------------------------------------------

local HEDGES = {
    adv = { "probably " },
    lead = { "as far as I can tell, ", "I think ", "from what I could make out, ", "if I read it right, " },
    tail = { ", I think", ", as far as I can tell", ", or so it looked", ", if I read it right", ", I'm fairly sure" },
}

Pages.Slot("pvp_h", {
    needs = function() return {} end,
    says = function() return { "pvp_sure" } end,
    fn = function(env, args)
        local list = HEDGES[args[1] or ""]
        if not list then return nil end
        if not env.f.probable then return "" end
        return list[env.rng.int(#list)]
    end,
})

-- Nothing, but only when the person goes by name (a diary entry or a
-- named player), for note-style lines like "Morthis again".
Pages.Slot("pvp_named", {
    needs = function() return { "who.name" } end,
    says = function() return {} end,
    fn = function(env)
        local p = env.f.who
        if type(p) == "table" and p.name and (p.diary or p.named) then return "" end
        return nil
    end,
})

-- Nothing, but only when "again" can sit next to them: they go by name, or
-- look familiar, or an earlier sentence on the page mentioned them. "A
-- priest killed me again" reads as if any priest would do.
Pages.Slot("pvp_known", {
    needs = function() return { "who" } end,
    says = function() return {} end,
    fn = function(env)
        local p = env.f.who
        if type(p) ~= "table" then return nil end
        if (p.name and (p.diary or p.named)) or p.familiar then return "" end
        local key = p.id or p.name or tostring(p)
        if env.ctx.mentioned[key] then return "" end
        return nil
    end,
})

-- Tags.
local SURE = { "pvp_sure" }
local AGAIN = { "again" }
local BLOW = { "pvp_blow" }
local REV = { "revenge" }

local function Tags(...)
    local out = {}
    for _, list in ipairs({ ... }) do
        for i = 1, #list do out[#out + 1] = list[i] end
    end
    return out
end

--------------------------------------------------------------------------
-- death: a hostile player killed me
--------------------------------------------------------------------------

Words("pvp", "death", {
    must = { "pvp_sure" },
    needs = { "timesKilledMe" },

    stems = {
        -- The hedge, or nothing: these make a bare clause safe.
        { "{pvp_h:lead}", bonus = -0.25 },
        "{at.cap:subZone}, {pvp_h:lead}",
        { "{in.cap:zone}, {pvp_h:lead}", bonus = -0.5 },
        { "{today.cap}, {pvp_h:lead}", bonus = -0.5 },
        { "{pvp_known}Once again, {pvp_h:lead}", needs = { "timesKilledMe>=2" }, says = AGAIN, bonus = 0.5 },
        { "{pvp_known}Not for the first time, {pvp_h:lead}", needs = { "timesKilledMe>=2" }, says = AGAIN, bonus = 0.5 },
        { "{pvp_known}For the {nth:timesKilledMe} time, {pvp_h:lead}", needs = { "timesKilledMe>=2", "timesKilledMe<=20" }, says = AGAIN, bonus = 0.5 },
        { "{pvp_known}In the latest round of an old feud, {pvp_h:lead}", needs = { "toldBefore", "timesKilledMe>=3" }, voice = "wry", says = AGAIN },
        { "{pvp_known}Right on schedule, {pvp_h:lead}", needs = { "toldBefore" }, voice = "wry", says = AGAIN },

        -- Openings that leave the hedging to the clause.
        { "Out of nowhere, ", bonus = -0.5 },
        { "Without much ceremony, ", voice = "wry" },
        { "Annoyingly, ", voice = "wry" },
        { "{pvp_known}Just as {when:lastDeathWhen}, ", needs = { "toldBefore" }, says = AGAIN },
        { "In world PvP news, ", voice = "wry" },
        { "A bad moment {at:subZone}: ", voice = "terse" },
        { "PvP {in:zone}: ", voice = "terse" },
        { "{pvp_known}Again: ", needs = { "timesKilledMe>=2" }, voice = "terse", says = AGAIN, bonus = 0.5 },
    },

    clauses = {
        -- Hedged or flat by the slot.
        "{ref} {pvp_h:adv}killed me",
        "{ref} {pvp_h:adv}killed me {at:subZone}",
        { "{ref} {pvp_h:adv}killed me {in:zone}", bonus = -0.5 },
        "I was {pvp_h:adv}killed by {ref.obj}",
        "I was {pvp_h:adv}killed {at:subZone} by {ref.obj}",
        "{ref} {pvp_h:adv}killed me with {v:spell}",
        { "{pvp_known}{ref} {pvp_h:adv}killed me again", needs = { "timesKilledMe>=2" }, says = AGAIN, bonus = 0.5 },
        { "{pvp_known}{ref} {pvp_h:adv}killed me again {at:subZone}", needs = { "timesKilledMe>=2" }, says = AGAIN, bonus = 0.5 },
        { "{pvp_known}{ref} {pvp_h:adv}killed me for the {nth:timesKilledMe} time", needs = { "timesKilledMe>=2", "timesKilledMe<=20" }, says = AGAIN, bonus = 0.5 },
        { "the same {class} as before {pvp_h:adv}killed me", needs = { "toldBefore" }, says = AGAIN },
        { "the same {class} as before {pvp_h:adv}killed me {at:subZone}", needs = { "toldBefore" }, says = AGAIN },
        { "{pvp_known}{ref} {pvp_h:adv}killed me, just as {he} did {when:lastDeathWhen}", needs = { "timesKilledMe>=2" }, says = AGAIN, final = true, bonus = 0.5 },
        { "{ref}, at least five levels above me, {pvp_h:adv}killed me", needs = { "outlevelled" } },
        { "{ref} {pvp_h:adv}killed me, and with five levels or more on me there wasn't much I could do about it", needs = { "outlevelled" }, final = true },

        -- Flat: only when it's certain.
        { "{ref.poss} {v:spell} finished me", needs = { "!probable" }, says = SURE },
        { "{ref} put me down with {v:spell}", needs = { "!probable" }, says = SURE },
        { "{ref} landed the killing blow on me", needs = { "!probable" }, says = SURE },
        { "{ref} got the better of me {at:subZone}", needs = { "!probable" }, says = SURE },
        { "I lost a fight to {ref.obj}", needs = { "!probable" }, says = SURE },
        { "I died to {ref.poss} {v:spell}", needs = { "!probable" }, says = SURE },
        { "{ref} killed me with {v:spell}, and that was that", needs = { "!probable" }, says = SURE, final = true },
        { "there was no doubt about it: {ref} killed me", needs = { "!probable" }, says = SURE, voice = "terse" },

        -- Hedged in their own words: only when it's probable.
        { "I think it was {ref.noun} who killed me", needs = { "probable" }, says = SURE },
        { "I died {at:subZone}, most likely to {ref.obj}", needs = { "probable" }, says = SURE },
        { "I died {in:zone}, and as far as I can tell it was {ref.noun} who did it", needs = { "probable" }, says = SURE, final = true },
                { "{ref} looks to have been the one who killed me", needs = { "probable" }, says = SURE },
        { "I went down to {v:spell}, most likely from {ref.obj}", needs = { "probable" }, says = SURE },
        { "I was killed, and {ref} is my best guess for who did it", needs = { "probable" }, says = Tags(SURE, { "spell" }), final = true },
        { "{pvp_known}I'm fairly sure {ref} killed me again", needs = { "probable", "timesKilledMe>=2" }, says = Tags(SURE, AGAIN), bonus = 0.5 },
        { "it was probably the same {class} as before who killed me", needs = { "probable", "toldBefore" }, says = Tags(SURE, AGAIN) },

        -- Bare: a hedge stem or tail does the hedging.
        "{ref} caught me {at:subZone}",
        { "{ref} caught me {in:zone}", bonus = -0.5 },
        "{ref} cut me down",
        { "{ref} did for me", voice = "wry" },
        { "{ref} made short work of me", needs = { "outlevelled" } },
        { "{ref} ganked me", needs = { "outlevelled" } },
        { "{ref} ganked me {at:subZone}", needs = { "outlevelled" } },
        { "{pvp_known}{ref} had me again", needs = { "timesKilledMe>=2" }, says = AGAIN, bonus = 0.5 },
        { "{pvp_known}{ref} cut me down again", needs = { "timesKilledMe>=2" }, says = AGAIN, bonus = 0.5 },
        { "{pvp_known}{ref} caught me again", needs = { "timesKilledMe>=2" }, says = AGAIN, bonus = 0.5 },
        { "the same {class} as before caught me", needs = { "toldBefore" }, says = AGAIN },
        { "{ref} put me in the dirt", voice = "wry" },
        { "{ref} took me apart", needs = { "outlevelled" }, voice = "wry" },
        { "{ref} ended me", voice = "terse" },
    },
})

Words("pvp", "death", {
    fragments = {
        "Killed by {ref.obj}{pvp_h:tail}",
        "Killed by {ref.obj} {at:subZone}{pvp_h:tail}",
        { "Killed by {ref.obj} {in:zone}{pvp_h:tail}", bonus = -0.5 },
        "Killed by {ref.poss} {v:spell}{pvp_h:tail}",
        "Dead, {pvp_h:adv}at the hands of {ref.obj}",
        { "{pvp_known}Killed by {ref.obj} again{pvp_h:tail}", needs = { "timesKilledMe>=2" }, says = AGAIN, bonus = 0.5 },
        { "Dead again, and {ref.short} again{pvp_h:tail}{pvp_named}", needs = { "toldBefore", "who.name" }, says = AGAIN, final = true },
        { "{ref.short} again, killing me for the {nth:timesKilledMe} time{pvp_h:tail}{pvp_named}", needs = { "toldBefore", "who.name", "timesKilledMe<=20" }, says = AGAIN, final = true },
        { "Killed by the same {class} as before{pvp_h:tail}", needs = { "toldBefore" }, says = AGAIN },
        { "Ganked by {ref.obj}{pvp_h:tail}", needs = { "outlevelled" } },
        { "Ganked {at:subZone} by {ref.obj}{pvp_h:tail}", needs = { "outlevelled" } },
        { "Killed by {ref.obj}, no question", needs = { "!probable" }, says = SURE },
        { "Killed by {ref.obj}, and no doubt about it", needs = { "!probable" }, says = SURE },
        { "Dead to {ref.poss} {v:spell}", needs = { "!probable" }, says = SURE },
        { "Killed, most likely by {ref.obj}", needs = { "probable" }, says = SURE },
        { "Dead {at:subZone}, probably {ref.poss} doing", needs = { "probable" }, says = SURE },
        { "Killed {in:zone}, with {ref.obj} the likely culprit", needs = { "probable" }, says = SURE },
        { "{pvp_known}One more death to {ref.obj}{pvp_h:tail}", needs = { "timesKilledMe>=2" }, says = AGAIN, voice = "wry", bonus = 0.5 },
        { "Flattened by {ref.obj}{pvp_h:tail}", voice = "wry" },
        { "Dead, courtesy of {ref.obj}{pvp_h:tail}", voice = "wry" },
        { "Outlevelled and outfought by {ref.obj}{pvp_h:tail}", needs = { "outlevelled" }, voice = "wry" },
        { "Killed by {ref.short}{pvp_h:tail}", voice = "terse" },
        { "Dead. {ref.short}{pvp_h:tail}{pvp_named}", needs = { "who.name" }, voice = "terse", final = true },
        { "Ganked. {ref.short}{pvp_h:tail}{pvp_named}", needs = { "outlevelled", "who.name" }, voice = "terse", final = true },
        { "{ref.short} again. Dead{pvp_h:tail}{pvp_named}", needs = { "toldBefore", "who.name" }, voice = "terse", says = AGAIN },
    },

    tails = {
        -- The hedge, after a bare clause.
        { "{pvp_h:tail}", needs = { "probable" }, bonus = -0.25 },
        { ", or so it looked from where I lay", needs = { "probable" }, says = SURE },
        { ", though I couldn't swear to it", needs = { "probable" }, says = SURE },
        { ", if the log is anything to go by", needs = { "probable" }, says = SURE },
        { ", and there was no mistaking who did it", needs = { "!probable" }, says = SURE },
        { ", plain as day", needs = { "!probable" }, says = SURE, voice = "terse" },

        -- The killing blow.
        { " with {v:spell}{pvp_h:tail}" },
        { ", {v:spell} doing the job{pvp_h:tail}" },
        { ", finishing me with {v:spell}", needs = { "!probable" }, says = SURE },
        { ", {v:spell} by the look of it", needs = { "probable" }, says = SURE },

        -- Again, and how often.
        { "{pvp_known}, the {nth:timesKilledMe} time {he} has killed me", needs = { "timesKilledMe>=2", "timesKilledMe<=20" }, says = AGAIN, bonus = 0.5 },
        { "{pvp_known}, which makes it {times:timesKilledMe} now", needs = { "timesKilledMe>=3" }, says = AGAIN },
        { "{pvp_known}, {times:timesKilledMe} now, all told", needs = { "timesKilledMe>=3" }, says = AGAIN },
        { "{pvp_known}, not for the first time", needs = { "timesKilledMe>=2" }, says = AGAIN, bonus = 0.5 },
        { "{pvp_known}, the same as {when:lastDeathWhen}", needs = { "timesKilledMe>=2" }, says = AGAIN, bonus = 0.5 },
        { "{pvp_known}, just like {when:lastDeathWhen}", needs = { "toldBefore" }, says = AGAIN },
        { ", the same {class} as before", needs = { "toldBefore" }, says = AGAIN },
        { "{pvp_known}, again", needs = { "timesKilledMe>=2" }, says = AGAIN, bonus = -0.5 },
        { "{pvp_known}, for the second time", needs = { "timesKilledMe==2" }, says = AGAIN },

        -- Levels, place, reaction.
        { ", and {he} had at least five levels on me", needs = { "outlevelled" } },
        { ", a fight I was never going to win", needs = { "outlevelled" }, says = { "outlevelled" } },
        { ", which did nothing for my {part}", voice = "wry" },
        { ", and I'm still annoyed", voice = "wry" },
        { ", and not gently", voice = "wry" },
        { "{pvp_known}, which is getting old", needs = { "timesKilledMe>=3" }, voice = "wry", says = AGAIN },
        { ", rather unsportingly", needs = { "outlevelled" }, voice = "wry" },
        { ", no contest", needs = { "outlevelled" }, voice = "terse" },
    },
})

Words("pvp", "death", {
    wholes = {
        -- Plain, hedged by the slot.
        "{ref} {pvp_h:adv}killed me {at:subZone} {today}.",
        "{at.cap:subZone}, {pvp_h:lead}{ref} killed me.",
        "I died {in:zone} {today}, {pvp_h:adv}to {ref.obj}.",
        "{ref} {pvp_h:adv}killed me with {v:spell}. I didn't get much say in it.",
        "{v:spell}, {pvp_h:adv}from {ref.obj}, and I was dead.",
        "World PvP caught up with me {in:zone}: {ref} {pvp_h:adv}killed me.",

        -- Certain.
        { "{ref} killed me {at:subZone}. There's no getting round it.", needs = { "!probable" }, says = SURE },
        { "{ref} killed me {today} with {v:spell}.", needs = { "!probable" }, says = SURE },
        { "{ref.poss} {v:spell} was the last thing I saw before the spirit healer.", needs = { "!probable" }, says = SURE },
        { "I lost a fight to {ref.obj} {in:zone}. It wasn't close.", needs = { "!probable" }, says = SURE },
        { "{ref} caught me {at:subZone} and killed me. Simple as that.", needs = { "!probable" }, says = SURE },

        -- Probable, hedged in their own words.
        { "I died {at:subZone} {today}. I think it was {ref.noun}, though I couldn't swear to it.", needs = { "probable" }, says = SURE },
        { "Something killed me {in:zone}, and as far as I can tell it was {ref.noun}.", needs = { "probable" }, says = SURE },
        { "I went down {at:subZone}. My best guess for who did it is {ref.noun}.", needs = { "probable" }, says = SURE },
        { "I died to {v:spell} {today}, most likely cast by {ref.noun}.", needs = { "probable" }, says = SURE },
        { "{ref} was the likeliest culprit when I died {in:zone} {today}.", needs = { "probable" }, says = SURE },
        { "I can't be certain, but I think {ref} killed me {at:subZone}.", needs = { "probable" }, says = SURE },
        { "I died {in:zone}, and the killing blow was most likely {ref.poss}.", needs = { "probable" }, says = Tags(SURE, { "spell" }) },

        -- Again.
        { "{pvp_known}{ref} {pvp_h:adv}killed me again {today}. That makes {times:timesKilledMe}.", needs = { "timesKilledMe>=3" }, says = AGAIN },
        { "{pvp_known}{ref} {pvp_h:adv}killed me for the second time {today}. The first was {when:lastDeathWhen}.", needs = { "timesKilledMe==2" }, says = AGAIN },
        { "{pvp_known}For the {nth:timesKilledMe} time, {pvp_h:lead}{ref} killed me.", needs = { "timesKilledMe>=3", "timesKilledMe<=20" }, says = AGAIN },
        { "{pvp_known}{ref} {pvp_h:adv}killed me {at:subZone}, the same as {when:lastDeathWhen}.", needs = { "timesKilledMe>=2" }, says = AGAIN, bonus = 0.5 },
        { "{pvp_known}The last time {ref} killed me was {when:lastDeathWhen}. {today.cap}, {pvp_h:lead}{he} did it again.", needs = { "timesKilledMe>=2" }, says = AGAIN, bonus = 0.5 },
        { "{pvp_known}I've now died to {ref.obj} {times:timesKilledMe}.", needs = { "timesKilledMe>=3", "!probable" }, says = Tags(SURE, AGAIN) },

        -- The nemesis, when the diary has told an earlier one.
        { "{pvp_known}{ref} again. {pvp_h.cap:lead}{he} killed me {at:subZone}, just like {when:lastDeathWhen}.", needs = { "toldBefore" }, says = AGAIN },
        { "The same {class} as before {pvp_h:adv}killed me {today}. I'm starting to recognise {him}.", needs = { "toldBefore" }, says = AGAIN },
        { "{pvp_known}{ref} {pvp_h:adv}killed me {in:zone} again. I've written about {him} before, and I expect I'll write about {him} again.", needs = { "toldBefore" }, says = AGAIN },
        { "My old nemesis {ref.short} {pvp_h:adv}killed me again {today}{pvp_named}.", needs = { "toldBefore", "timesKilledMe>=3" }, says = AGAIN },
        { "{pvp_known}{ref} has now killed me {times:timesKilledMe}. {today.cap} was the latest, {at:subZone}.", needs = { "toldBefore", "timesKilledMe>=3", "!probable" }, says = Tags(SURE, AGAIN) },
        { "{pvp_known}{ref} again, and probably the same ending: dead, {at:subZone}.", needs = { "toldBefore", "probable" }, says = Tags(SURE, AGAIN) },

        -- Outlevelled.
        { "{ref}, five levels or more above me, {pvp_h:adv}killed me {at:subZone}.", needs = { "outlevelled" } },
        { "{ref} {pvp_h:adv}killed me {in:zone}. With at least five levels between us, it was never going to be a fair fight.", needs = { "outlevelled" } },
        { "There's not much to say about a fight against someone at least five levels higher. {ref} {pvp_h:adv}killed me.", needs = { "outlevelled" } },

        -- Warm: rueful, not bitter.
        { "{ref} {pvp_h:adv}killed me {at:subZone}. I picked myself up and got on with the {part}.", voice = "warm" },
        { "A rough moment {in:zone}: {ref} {pvp_h:adv}killed me. Still, the rest of the {part} was kinder.", voice = "warm" },
        { "{ref} {pvp_h:adv}killed me {today}. Part of the game, I suppose, and I'd rather it was out here than nowhere.", voice = "warm" },

        -- Wry.
        { "{ref} {pvp_h:adv}killed me {at:subZone}. I had plans for that life.", voice = "wry" },
        { "Note to self: give {v:subZone} a wide berth. {ref} {pvp_h:adv}killed me there.", voice = "wry" },
        { "{ref} {pvp_h:adv}killed me with {v:spell}, which I'm told is very effective.", voice = "wry" },
        { "Died {in:zone} {today}, {pvp_h:adv}to {ref.obj}. I'll be taking the long way round from now on.", voice = "wry" },
        { "{pvp_known}{ref} {pvp_h:adv}killed me again. At this point {he} should be paying rent on my corpse.", needs = { "timesKilledMe>=3" }, voice = "wry", says = AGAIN },
        { "{ref}, five levels or more above me, {pvp_h:adv}killed me. Very brave.", needs = { "outlevelled" }, voice = "wry" },
        { "{ref} and I met {at:subZone}. Briefly. {pvp_h.cap:lead}{he} won.", voice = "wry" },
        { "Someone killed me {at:subZone}, and the evidence points at {ref.noun}. I'm not a detective, but I can hold a grudge.", needs = { "probable" }, voice = "wry", says = SURE },

        -- Terse.
        { "Killed by {ref.obj} {at:subZone}{pvp_h:tail}.", voice = "terse" },
        { "{ref.short}. {v.cap:spell}. Dead{pvp_h:tail}.{pvp_named}", voice = "terse" },
        { "Dead {in:zone}. {ref.short}, probably.{pvp_named}", needs = { "probable" }, voice = "terse", says = SURE },
        { "Dead {in:zone}. {ref.short}.{pvp_named}", needs = { "!probable" }, voice = "terse", says = SURE },
        { "{ref.short} again. {count.cap:timesKilledMe:death} now{pvp_h:tail}.{pvp_named}", needs = { "timesKilledMe>=3" }, voice = "terse", says = AGAIN },
        { "Ganked {at:subZone}{pvp_h:tail}. {ref.short}, five levels up at least.{pvp_named}", needs = { "outlevelled" }, voice = "terse" },
    },
})

--------------------------------------------------------------------------
-- kill: we killed them
--------------------------------------------------------------------------
--
-- Every sentence says who landed the blow (must "pvp_blow"). Pieces guard
-- with "by.id" and "mine==true", which are conditions, not news, so a piece
-- that only puts a groupmate beside me ("we killed her") can still take a
-- tail that credits the blow. "We" only where `by` puts a groupmate beside me. Counts
-- are told without saying whose blows the earlier kills were.

local KAGAIN = { "kill_again" }

Words("pvp", "kill", {
    must = { "pvp_blow" },
    needs = { "timesKilledThem" },
    rel = "then",

    stems = {
        { "{in.cap:zone}, ", bonus = -0.5 },
        "Before long, ",
        { "On the other side of the ledger, ", voice = "wry" },
        { "For once, ", needs = { "timesKilledThem==1" }, voice = "wry", says = { "forOnce" } },
        { "In return, ", needs = { "revenge" } },
        { "By way of evening the score, ", needs = { "revenge" } },
        { "Some small measure of justice: ", needs = { "revenge" }, voice = "wry" },
        { "With {ref.obj:by} at my side, ", needs = { "by.id" }, voice = "warm", says = { "pvp_by" } },
        { "Teamwork {in:zone}: ", needs = { "by.id" }, voice = "warm" },
        { "Score settled: ", needs = { "revenge" }, voice = "terse" },
        { "PvP {in:zone}: ", voice = "terse" },
    },

    clauses = {
        -- A groupmate's blow.
        { "{ref:by} killed {ref.obj}", needs = { "by.id" }, says = Tags(BLOW, { "pvp_by" }) },
        { "{ref:by} landed the killing blow on {ref.obj}", needs = { "by.id" }, says = Tags(BLOW, { "pvp_by" }) },
        { "{ref:by} finished off {ref.obj}", needs = { "by.id" }, says = Tags(BLOW, { "pvp_by" }) },
        { "{ref:by} got the kill on {ref.obj}", needs = { "by.id" }, says = Tags(BLOW, { "pvp_by" }) },
        { "{ref} fell to {ref.obj:by}", needs = { "by.id" }, says = Tags(BLOW, { "pvp_by" }) },
        { "{ref} went down to {ref.obj:by}", needs = { "by.id" }, says = Tags(BLOW, { "pvp_by" }) },
        { "{ref.poss:by} blow finished {ref.obj}", needs = { "by.id" }, says = Tags(BLOW, { "pvp_by" }) },
        { "{ref} went down {in:zone}, and {ref:by} landed the last hit", needs = { "by.id" }, final = true, says = Tags(BLOW, { "pvp_by" }) },
        { "we took {ref.obj} down, and the last hit was {ref.poss:by}", needs = { "by.id" }, final = true, says = Tags(BLOW, { "pvp_by" }) },
        { "{ref:by} and I killed {ref.obj}, the last hit {ref.poss:by}", needs = { "by.id" }, final = true, says = Tags(BLOW, { "pvp_by" }) },
        { "{pvp_known}{ref} went down again, this time to {ref.obj:by}", needs = { "by.id", "timesKilledThem>=2" }, says = Tags({ "pvp_by" }, BLOW, KAGAIN) },
        { "{ref:by} put {ref.obj} down, neat as you like", needs = { "by.id" }, voice = "warm", says = Tags(BLOW, { "pvp_by" }) },
        { "{ref:by} made short work of {ref.obj}", needs = { "by.id" }, voice = "wry", says = Tags(BLOW, { "pvp_by" }) },

        -- My blow.
        { "I killed {ref.obj}", needs = { "mine==true" }, says = BLOW },
        { "I landed the killing blow on {ref.obj}", needs = { "mine==true" }, says = BLOW },
        { "I finished off {ref.obj}", needs = { "mine==true" }, says = BLOW },
        { "I got the kill on {ref.obj}", needs = { "mine==true" }, says = BLOW },
        { "{ref} fell to me", needs = { "mine==true" }, says = BLOW },
        { "the killing blow on {ref.obj} was mine", needs = { "mine==true" }, says = BLOW },
        { "I put {ref.obj} down {in:zone}", needs = { "mine==true" }, says = BLOW },
        { "{pvp_known}{ref} went down again, this time to me", needs = { "mine==true", "timesKilledThem>=2" }, says = Tags(BLOW, KAGAIN) },
        { "I got the better of {ref.obj} for once", needs = { "mine==true" }, voice = "wry", says = Tags(BLOW, { "forOnce" }) },
        { "I won a fight against {ref.obj}, which doesn't happen every day", needs = { "mine==true" }, voice = "wry", final = true, says = BLOW },
        { "I killed {ref.obj}", needs = { "mine==true" }, voice = "terse", says = BLOW },

        -- Neither: a tail says whose blow it was.
        "{ref} went down {in:zone}",
        "{ref} died {in:zone}",
        "{ref} went down",
        { "we caught {ref.obj} {in:zone}", needs = { "by.id" } },
        { "we took down {ref.obj}", needs = { "by.id" } },
        { "we killed {ref.obj}", needs = { "by.id" } },
        { "{pvp_known}{ref} went down again", needs = { "timesKilledThem>=2" }, says = KAGAIN },
        { "{ref} didn't last long", voice = "wry" },
        { "{ref} was the one lying in the dirt this time", needs = { "revenge" }, voice = "wry", says = { "forOnce" } },

        -- Revenge, measured.
        { "I got a little of my own back on {ref.obj}", needs = { "revenge" } },
        { "the score with {ref.obj} came a little closer to even", needs = { "revenge" } },
        { "we evened the score with {ref.obj}", needs = { "revenge", "by.id" } },
        { "{ref} finally went down", needs = { "revenge" } },
        { "I paid {ref.obj} back for an earlier death", needs = { "revenge", "mine==true" }, says = BLOW },
        { "{ref:by} squared my account with {ref.obj}", needs = { "revenge", "by.id" }, says = Tags(BLOW, { "pvp_by" }) },
        { "{ref}, who had killed me before, went down to {ref.obj:by}", needs = { "revenge", "by.id" }, says = Tags(BLOW, { "pvp_by" }) },
        { "{ref}, who had killed me before, fell to my blow", needs = { "revenge", "mine==true" }, says = BLOW },
    },

    fragments = {
        { "A kill on {ref.obj}, with {ref:by} landing the blow", needs = { "by.id" }, says = Tags(BLOW, { "pvp_by" }) },
        { "A kill on {ref.obj}, the blow mine", needs = { "mine==true" }, says = BLOW },
        { "Helped {ref.obj:by} kill {ref.obj}", needs = { "by.id" }, says = Tags(BLOW, { "pvp_by" }) },
        { "{ref.short} down, {ref.poss:by} blow", needs = { "by.id" }, says = Tags(BLOW, { "pvp_by" }) },
        { "{ref.short} down, my blow", needs = { "mine==true" }, says = BLOW },
        { "The killing blow on {ref.obj}, mine", needs = { "mine==true" }, says = BLOW },
        { "The killing blow on {ref.obj}, {ref.poss:by}", needs = { "by.id" }, says = Tags(BLOW, { "pvp_by" }) },
        { "Killed {ref.obj} {in:zone}", needs = { "mine==true" }, says = BLOW },
        "{ref.short} down {in:zone}",
        "A kill on {ref.obj}",
        { "{pvp_known}Another kill on {ref.obj}", needs = { "timesKilledThem>=2" }, says = KAGAIN },
        { "{ref.short} down again{pvp_named}", needs = { "timesKilledThem>=2" }, says = KAGAIN },
        { "Some payback for {ref.obj}", needs = { "revenge" } },
        { "Revenge on {ref.obj}, of a sort", needs = { "revenge" } },
        { "A small debt settled with {ref.obj}", needs = { "revenge" } },
        { "Good work by {ref.obj:by} on {ref.obj}", needs = { "by.id" }, voice = "warm", says = { "pvp_by" } },
        { "A rare win over {ref.obj}", needs = { "mine==true" }, voice = "wry", says = BLOW },
        { "Turnabout, with {ref.obj} on the floor", needs = { "revenge" }, voice = "wry" },
        { "{ref.short}: dead. {ref.poss.short.cap:by} kill", needs = { "by.id" }, voice = "terse", says = Tags(BLOW, { "pvp_by" }), final = true },
        { "{ref.short}: dead. My kill", needs = { "mine==true" }, voice = "terse", says = BLOW, final = true },
        { "Killed {ref.obj}", needs = { "mine==true" }, voice = "terse", says = BLOW },
    },

    tails = {
        -- Whose blow.
        { ", {ref.poss:by} blow", needs = { "by.id" }, says = BLOW },
        { ", with {ref:by} landing the last hit", needs = { "by.id" }, says = BLOW },
        { ", and {ref:by} got the kill", needs = { "by.id" }, says = BLOW },
        { ", and {ref:by} landed the killing blow", needs = { "by.id" }, says = BLOW },
        { ", the killing blow {ref.poss:by}", needs = { "by.id" }, says = BLOW },
        { ", the killing blow mine", needs = { "mine==true" }, says = BLOW },
        { ", and the killing blow was mine", needs = { "mine==true" }, says = BLOW },
        { ", my blow finishing it", needs = { "mine==true" }, says = BLOW },
        { ", with me landing the last hit", needs = { "mine==true" }, says = BLOW },
        { ", by my hand", needs = { "mine==true" }, voice = "wry", says = BLOW },
        { ", with a tidy finishing blow from {ref.obj:by}", needs = { "by.id" }, voice = "warm", says = Tags(BLOW, { "pvp_by" }) },
        { ", and {ref:by} had the last word", needs = { "by.id" }, voice = "wry", says = BLOW },

        -- How often.
        { "{pvp_known}, the {nth:timesKilledThem} time {ref} has gone down", needs = { "timesKilledThem>=2", "timesKilledThem<=20" }, says = KAGAIN },
        { "{pvp_known}, {count:timesKilledThem:kill} on {ref.obj} now", needs = { "timesKilledThem>=2" }, says = KAGAIN },
        { ", not for the first time", needs = { "timesKilledThem>=2" }, says = KAGAIN },
        { ", the first time {ref} has gone down", needs = { "timesKilledThem==1", "revenge" } },

        -- Revenge, measured.
        { ", a small measure of revenge", needs = { "revenge" } },
        { ", which evened the score a little", needs = { "revenge" } },
        { ", and {ref} had killed me before, so I won't pretend I minded", needs = { "revenge" } },
        { ", and that made up for an earlier death", needs = { "revenge" } },
        { ", which I enjoyed more than I probably should have", needs = { "revenge" }, voice = "wry" },
        { ", and I felt a little better about the last time", needs = { "revenge" }, voice = "warm" },
        { ", even", needs = { "revenge" }, voice = "terse" },

        { ", for what it's worth", voice = "wry" },
    },
})

Words("pvp", "kill", {
    wholes = {
        -- A groupmate's blow.
        { "{ref:by} killed {ref.obj} {in:zone}, and I was glad to be there for it.", needs = { "by.id" }, says = BLOW },
        { "We caught {ref.obj} {in:zone}. {ref.cap:by} landed the killing blow.", needs = { "by.id" }, says = BLOW },
        { "{ref} went down {in:zone}. The killing blow was {ref.poss:by}.", needs = { "by.id" }, says = BLOW },
        { "The fight with {ref.obj} ended with {ref.poss:by} blow.", needs = { "by.id" }, says = BLOW },
        { "{ref:by} and I took on {ref.obj}, and {ref:by} finished it.", needs = { "by.id" }, says = BLOW },
        { "We killed {ref.obj}. Credit for the last hit goes to {ref.obj:by}.", needs = { "by.id" }, says = BLOW },
        { "{pvp_known}{ref:by} got the kill on {ref.obj} {today}. That's {count:timesKilledThem:kill} on {ref.obj} now.", needs = { "by.id", "timesKilledThem>=2" }, says = Tags(BLOW, KAGAIN) },

        -- My blow.
        { "I killed {ref.obj} {in:zone} {today}.", needs = { "mine==true" }, says = BLOW },
        { "{ref} went down {in:zone}, and the killing blow was mine.", needs = { "mine==true" }, says = BLOW },
        { "I landed the killing blow on {ref.obj}. It doesn't always go that way.", needs = { "mine==true" }, says = BLOW },
        { "The last hit on {ref.obj} was mine.", needs = { "mine==true" }, says = BLOW },
        { "{pvp_known}I killed {ref.obj} {today}, the {nth:timesKilledThem} time {ref} has gone down.", needs = { "mine==true", "timesKilledThem>=2", "timesKilledThem<=20" }, says = Tags(BLOW, KAGAIN) },
        { "{pvp_known}{ref} has now gone down {times:timesKilledThem}. {today.cap} it was my blow.", needs = { "mine==true", "timesKilledThem>=3" }, says = Tags(BLOW, KAGAIN) },

        -- Revenge, measured.
        { "{ref} had killed me before. {today.cap} I killed {ref.obj}, and I'll call that even for now.", needs = { "revenge", "mine==true" }, says = BLOW },
        { "{ref} had killed me before. {today.cap} {ref:by} killed {ref.obj}, and I'll take that.", needs = { "revenge", "by.id" }, says = BLOW },
        { "Some of the score with {ref.obj} came back {today}: {ref:by} landed the killing blow.", needs = { "revenge", "by.id" }, says = BLOW },
        { "Some of the score with {ref.obj} came back {today}: the killing blow was mine.", needs = { "revenge", "mine==true" }, says = BLOW },
        { "I've died to {ref.obj} before. This time {ref} went down, and the blow was mine.", needs = { "revenge", "mine==true" }, says = BLOW },
        { "I've died to {ref.obj} before. This time {ref} went down, to {ref.obj:by}.", needs = { "revenge", "by.id" }, says = BLOW },
        { "A little revenge on {ref.obj} {today}. {ref.cap:by} got the kill, and I was glad to see it.", needs = { "revenge", "by.id" }, says = BLOW },
        { "Revenge on {ref.obj}, finally. The killing blow was mine, and I didn't gloat. Much.", needs = { "revenge", "mine==true" }, voice = "wry", says = BLOW },

        -- Warm.
        { "{ref:by} and I made a good team against {ref.obj}, and {ref:by} landed the last hit.", needs = { "by.id" }, voice = "warm", says = BLOW },
        { "{ref:by} finished off {ref.obj} {in:zone}. I'm glad I had the company.", needs = { "by.id" }, voice = "warm", says = BLOW },
        { "I killed {ref.obj} {today}, and I'll admit it felt good after the last time.", needs = { "mine==true", "revenge" }, voice = "warm", says = BLOW },

        -- Wry.
        { "{ref} went down {in:zone}, and the killing blow was mine. I'm writing it down before it stops being true.", needs = { "mine==true" }, voice = "wry", says = BLOW },
        { "{ref:by} killed {ref.obj}. I contributed moral support and some damage.", needs = { "by.id" }, voice = "wry", says = BLOW },
        { "I killed {ref.obj}. Let the record show it can be done.", needs = { "mine==true" }, voice = "wry", says = BLOW },
        { "{ref} had killed me before, so I wasn't sorry when {ref:by} returned the favour.", needs = { "revenge", "by.id" }, voice = "wry", says = BLOW },

        -- Terse.
        { "Killed {ref.obj}. My blow.", needs = { "mine==true" }, voice = "terse", says = BLOW },
        { "Killed {ref.obj}. {ref.poss.cap:by} blow.", needs = { "by.id" }, voice = "terse", says = BLOW },
        { "{ref.short} down, {in:zone}. {ref.short.cap:by} got the kill.", needs = { "by.id" }, voice = "terse", says = BLOW },
        { "{ref.short}: down. Revenge, of a kind. My blow.", needs = { "revenge", "mine==true" }, voice = "terse", says = BLOW },
        { "{ref.short} again, dead this time. {count.cap:timesKilledThem:kill} now.{pvp_named}", needs = { "mine==true", "timesKilledThem>=2" }, voice = "terse", says = Tags(BLOW, KAGAIN) },
    },
})

-- The warm voice: rueful rather than bitter, the diarist taking a death in
-- stride and glad of the people beside them for a kill. Feelings are mine.
Words("pvp", "death", {
    stems = {
        { "Ah well: {pvp_h:lead}", voice = "warm" },
        { "It happens, and {today} {pvp_h:lead}", voice = "warm" },
    },
    clauses = {
        { "{ref} {pvp_h:adv}killed me, and I took it in good part", voice = "warm" },
        { "{ref} {pvp_h:adv}got the better of me, fair enough", voice = "warm" },
        { "{ref} {pvp_h:adv}killed me {at:subZone}, which is the risk out here", voice = "warm", final = true },
    },
    fragments = {
        { "A death to {ref.obj}{pvp_h:tail}, and no harm done", voice = "warm", final = true },
        { "Killed by {ref.obj}{pvp_h:tail}, but back on my feet soon enough", voice = "warm", final = true },
    },
    tails = {
        { ", and I was up again soon enough", voice = "warm" },
        { ", but no lasting harm", voice = "warm" },
        { ", and I shrugged it off", voice = "warm" },
        { ", which is part of the deal out here", voice = "warm" },
    },
    wholes = {
        { "{ref} {pvp_h:adv}killed me {in:zone}. No hard feelings; it's that kind of world.", voice = "warm" },
        { "I died {at:subZone}, {pvp_h:adv}to {ref.obj}. A short walk back, and the {part} went on.", voice = "warm" },
        { "{ref} {pvp_h:adv}killed me again {today}. I'm almost fond of the routine.", needs = { "toldBefore" }, voice = "warm", says = AGAIN },
        { "{ref}, at least five levels above me, {pvp_h:adv}killed me. I'll be a match for {him} one day.", needs = { "outlevelled" }, voice = "warm" },
        { "{ref} {pvp_h:adv}killed me with {v:spell}. I can admire good timing, even when I'm on the end of it.", voice = "warm" },
        { "I lost a fight to {ref.obj} {in:zone}, cleanly. Well played, I suppose.", needs = { "!probable" }, voice = "warm", says = SURE },
    },
})

Words("pvp", "kill", {
    stems = {
        { "Side by side with {ref.obj:by}, ", needs = { "by.id" }, voice = "warm", says = { "pvp_by" } },
        { "To my quiet satisfaction, ", voice = "warm" },
    },
    clauses = {
        { "{ref:by} landed the blow on {ref.obj}, and I was proud to be fighting beside {ref.obj:by}", needs = { "by.id" }, voice = "warm", says = Tags(BLOW, { "pvp_by" }), final = true },
        { "I finished {ref.obj} off myself, and it felt good", needs = { "mine==true" }, voice = "warm", says = BLOW, final = true },
        { "{ref:by} landed the last hit on {ref.obj}, and I was glad of the help", needs = { "by.id" }, voice = "warm", says = Tags(BLOW, { "pvp_by" }), final = true },
    },
    fragments = {
        { "A good kill on {ref.obj}, the last hit {ref.poss:by}", needs = { "by.id" }, voice = "warm", says = Tags(BLOW, { "pvp_by" }) },
        { "{ref.short} down, my blow, and a good feeling", needs = { "mine==true" }, voice = "warm", says = BLOW, final = true },
    },
    tails = {
        { ", and I was glad of the company", needs = { "by.id" }, voice = "warm" },
        { ", which cheered me up", voice = "warm" },
    },
    wholes = {
        { "{ref:by} landed the killing blow on {ref.obj} {in:zone}. Good to have {ref.obj:by} on my side.", needs = { "by.id" }, voice = "warm", says = BLOW },
        { "I killed {ref.obj} {in:zone}, and I'll admit I was pleased with myself.", needs = { "mine==true" }, voice = "warm", says = BLOW },
        { "{ref} had killed me before, and {today} {ref:by} put that right. I owe {ref.obj:by} one.", needs = { "revenge", "by.id" }, voice = "warm", says = BLOW },
    },
})
