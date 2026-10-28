-- Changed: what is different about someone since we last met. The diary
-- notices the change and leaves the why alone: no guessing at reasons, no
-- "she must have", no falling-outs, no decisions put in their heads.
--
-- changed facts (the planner's)
--   who               the person (diary, or named); who.name is the name now
--   oldName, newName  their name before and now (both set only when it changed)
--   oldGuild          their guild when we last met (nil: none)
--   newGuild          their guild now (nil: none)
--   joined            oldGuild nil, newGuild set
--   left              oldGuild set, newGuild nil
--   switched          both set and different
--   theirLevelThen    their level when we last met
--   theirLevel        their level now
--   gained            theirLevel - theirLevelThen (0 when no change)
--   myGained          the levels I gained over the same stretch (0+)
--   daysSince         days since we last met
--
-- Moves, in order: name, guild, levels. Each is skipped when its facts hold
-- no change. The name comes first so a renamed person is placed before
-- anything else is said about them, and the name move never uses {ref}
-- (which prints the new name): it names both, and uses {he}/{his} only
-- where the sex is known.
--
-- A flag in `needs` also says itself, so the piece that tells the news
-- needs "joined", and a tail that only fits a join guards with
-- "joined==true", which says nothing.
--
-- {changed_if:test} is declared here. It writes nothing, and lets a piece
-- through only when the test holds, for what `needs` can't express:
--   after    an earlier sentence of this beat already told another change
--            about them (for "too", "as well", "on top of that")
--   moved    joined or switched: newGuild is new to them
--
-- Guild and character names are proper nouns and go in as they are:
-- {v:newGuild}, {v:oldName}.

local addonName, ns = ...

local Pages = ns.Pages
local Words = Pages.Words

Pages.Angle("changed", { order = { "name", "guild", "levels" },
    about = "what changed about someone since we last met" })

local SEX = "who.sex>1"
local DIARY = "who.diary==true"

--------------------------------------------------------------------------
-- The gate slot
--------------------------------------------------------------------------

local CHANGE_TAGS = { "oldName", "newName", "oldGuild", "newGuild", "joined", "left", "switched" }

local function SaidBefore(env)
    local said = env.ctx and env.ctx.said and env.ctx.said[env.whoKey]
    if not said then return false end
    for i = 1, #CHANGE_TAGS do
        if said[CHANGE_TAGS[i]] then return true end
    end
    return false
end

local TESTS = {
    after = { needs = {}, test = SaidBefore },
    moved = { needs = { "newGuild" },
        test = function(env) return env.f.joined or env.f.switched end },
}

-- {changed_new}: the new name, as {v:newName}, but it also counts as
-- mentioning them, so the sentence after the name move can say "she"
-- rather than the new name again.
Pages.Slot("changed_new", {
    needs = function() return { "newName" } end,
    says = function() return { "newName" } end,
    fn = function(env)
        local p, name = env.f.who, env.f.newName
        if type(name) ~= "string" then return nil end
        if type(p) == "table" then
            local key = p.id or p.name or tostring(p)
            env.staged.mentioned[key] = true
            env.staged.last = key
            env.staged.para[key] = p
        end
        return name
    end,
})

Pages.Slot("changed_if", {
    needs = function(args)
        local t = TESTS[args[1] or ""]
        return t and t.needs or { "__no_such_test" }
    end,
    says = function() return {} end,
    fn = function(env, args)
        local t = TESTS[args[1] or ""]
        if t and t.test(env) then return "" end
        return nil
    end,
})

--------------------------------------------------------------------------
-- Tags from the wording
--------------------------------------------------------------------------
--
-- Some words should appear once per beat whichever move uses them ("now",
-- "since we last met", "too"), and some pieces repeat each other's point
-- ("the tag under her name" twice). Rather than tag each piece by hand, the
-- wording is read here and the tags added to `says`, so the engine never
-- puts two of them in one sentence, or in two sentences of the beat.

local RULES = {
    { "changed:now", { "%f[%a]now%f[%A]", "these days", "any more" } },
    { "changed:last", { "last met", "we last", "last time", "met again", "our last", "when we parted", "as was" } },
    { "changed:too", { "%f[%a]too%f[%A]", "as well", "%f[%a]also%f[%A]", "on top", "so had i" } },
    { "changed:tag", { "%f[%a]tag%f[%A]", "under .-name", "above .-head", "over .-head", "nameplate", "the name said", "the name read", "roster" } },
    { "changed:why", { "%f[%a]why%f[%A]", "my business", "own affair", "all i know", "all i'll write" } },
    { "changed:news", { "news", "expected", "surprise", "caught my eye", "threw me" } },
    { "changed:same", { "%f[%a]same%f[%A]" } },
    { "changed:used", { "getting used", "get used", "get it wrong", "remember" } },
    { "changed:good", { "good for", "good luck", "well there", "glad", "pleased", "good going", "lucky", "good to see", "nicely", "good progress" } },
    { "changed:record", { "for the record", "noted", "note for", "mark this", "writing", "write" } },
    { "changed:busy", { "busy", "quick going", "a long way", "envious" } },
    { "changed:newname", { "new name", "renamed", "name change", "another name", "one more name" } },
}

local KINDS = { "stems", "clauses", "fragments", "tails", "wholes" }

local function Tagged(spec, extra)
    for _, kind in ipairs(KINDS) do
        local list = spec[kind] or {}
        for i = 1, #list do
            local piece = list[i]
            if type(piece) == "string" then
                piece = { piece }
                list[i] = piece
            end
            local bare = piece[1]:gsub("{[^}]*}", ""):gsub("<[^>]*>", ""):lower()
            piece.says = piece.says or {}
            for _, rule in ipairs(RULES) do
                for _, pattern in ipairs(rule[2]) do
                    if bare:find(pattern) then
                        piece.says[#piece.says + 1] = rule[1]
                        break
                    end
                end
            end
            -- One colon a sentence: a stem that ends in one never leads into
            -- a clause that has one.
            if (kind == "stems" and bare:find(":%s*$")) or (kind == "clauses" and bare:find(":")) then
                piece.says[#piece.says + 1] = "changed:colon"
            end
            if piece[1]:find("daysSince", 1, true) or bare:find("%f[%a]later%f[%A]") then
                piece.says[#piece.says + 1] = "changed:last"
            end
            if extra then extra(piece, kind, bare) end
        end
    end
    return spec
end

-- Clauses in the simple past ("was in Dawnwatch now") say "changed:simple",
-- and so do the stems that want a perfect after them ("Since we last met,
-- she had joined"), so the two never meet.
local SIMPLE = "changed:simple"
local PARTICIPLES = { gone = true, taken = true, been = true, become = true, grown = true,
    come = true, risen = true, shot = true, kept = true, made = true }

local function Perfect(bare)
    for word in bare:gmatch("[h']a?d (%S+)") do
        word = word:gsub("^%[", ""):match("^[%a]+") or ""
        if word == "also" or word == "both" or word == "just" then return true end
        if word:find("ed$") or PARTICIPLES[word] then return true end
    end
    return false
end

local function Tense(piece, kind, bare)
    if kind == "clauses" and not Perfect(bare) then
        piece.says[#piece.says + 1] = SIMPLE
    end
end

--------------------------------------------------------------------------
-- name: a new name
--------------------------------------------------------------------------
--
-- "name:present" is said both by the clauses in the present or plain past
-- ("goes by Thandris now", "turned out to be") and by the stems and tails
-- that want a perfect after them ("Since we last met, ... had become"), so
-- the two never meet.

local PRESENT = "name:present"

local function NameHook(piece, kind)
    piece[1] = piece[1]:gsub("{v:newName}", "{changed_new}")
    -- A fragment has no verb for "at some point since we last met" to hang on.
    if kind == "fragments" then piece.says[#piece.says + 1] = PRESENT end
end

Words("changed", "name", Tagged({
    needs = { "oldName", "newName" },
    must = { "oldName", "newName" },

    stems = {
        { "Since we last met, ", says = { PRESENT } },
        { "At some point since we last met, ", says = { PRESENT } },
        { "Somewhere in the last {daysx:daysSince}, ", needs = { "daysSince>=2" }, says = { PRESENT } },
        { "In the {daysx:daysSince} since I last saw {him}, ", needs = { "daysSince>=2", SEX }, says = { PRESENT } },
        "{days.cap:daysSince} since we last met, and ",
        "For the record, ",
        "It took me a moment to place the name: ",
        "Something to remember: ",
        "To my surprise, ",
        "One thing had changed: ",
        "[Same {class}, new name|New name, same {class}]: ",
        { "Strange to write, but ", voice = "warm" },
        { "It still sounds odd to me, but ", voice = "warm" },
        { "It will take some getting used to, but ", voice = "warm" },
        { "I'll have to get used to this: ", voice = "wry" },
        { "For future pages, ", voice = "wry" },
        { "Mark this down: ", voice = "wry" },
        { "Just when I'd learnt the old one, ", voice = "wry" },
        { "Name change: ", voice = "terse" },
        { "Noted {today}: ", voice = "terse" },
    },

    clauses = {
        { "{v:oldName} goes by {v:newName} now", says = { PRESENT } },
        { "{v:oldName} is {v:newName} now", says = { PRESENT } },
        { "{v:oldName} is [known as|called] {v:newName} these days", says = { PRESENT } },
        { "{v:oldName}'s name is {v:newName} now", says = { PRESENT } },
        { "{v:newName} is what {v:oldName} goes by now", says = { PRESENT } },
        { "{v:oldName} has a new name, {v:newName}", says = { PRESENT } },
        "{v:oldName} has become {v:newName}",
        "{v:oldName} had become {v:newName}",
        "{v:oldName} had been renamed {v:newName}",
        "{v:oldName} had taken the name {v:newName}",
        { "{v:oldName} was {v:oldName} no longer, but {v:newName}", says = { PRESENT } },
        { "{v:oldName} had [changed {his} name to|traded {his} name for] {v:newName}", needs = { SEX } },
        { "{v:oldName} had renamed {him}self {v:newName}", needs = { SEX } },
        { "{v:oldName} was going by {v:newName} {today}", says = { PRESENT } },
        { "{v:newName} turned out to be {v:oldName}", says = { PRESENT } },
        { "{v:newName} was {v:oldName} under a new name", says = { PRESENT } },
        { "the name over {v:oldName}'s head read {v:newName} {today}", says = { PRESENT } },
        { "I'd known {v:newName} as {v:oldName} until {today}", says = { PRESENT } },
        { "the {class} I knew as {v:oldName} is called {v:newName} now", says = { PRESENT } },
        { "{v:oldName} had a new name by the time we met again: {v:newName}", final = true },
        { "the {v:oldName} in my diary goes by {v:newName} now", needs = { DIARY }, says = { PRESENT } },
        { "the name I'd written down as {v:oldName} reads {v:newName} now", needs = { DIARY }, says = { PRESENT } },
        { "my {v:oldName} is {v:newName} these days", needs = { DIARY }, says = { PRESENT }, voice = "warm" },
        { "{v:oldName} has a new name, and it's {v:newName}", says = { PRESENT }, voice = "warm" },
        { "dear old {v:oldName} goes by {v:newName} now", needs = { DIARY }, says = { PRESENT }, voice = "warm" },
        { "{v:oldName} answers to {v:newName} these days", says = { PRESENT }, voice = "wry" },
        { "{v:oldName} is {v:newName}, as far as the rest of Azeroth is concerned", says = { PRESENT }, voice = "wry" },
        { "I'll be writing {v:newName} from now on, not {v:oldName}", says = { PRESENT }, voice = "wry" },
        { "{v:oldName} had gone and changed {his} name to {v:newName}", needs = { SEX }, voice = "wry" },
        { "{v:oldName} is {v:newName} now", says = { PRESENT }, voice = "terse" },
        { "{v:oldName} became {v:newName}", voice = "terse" },
    },

    fragments = {
        "{v:oldName}, now {v:newName}",
        "{v:newName}, formerly {v:oldName}",
        "New name for {v:oldName}: {v:newName}",
        "{v:oldName} under a new name, {v:newName}",
        "{v:newName}, who I knew as {v:oldName}",
        "{v:oldName}, going by {v:newName} these days",
        "Same {class}, new name: {v:newName}, once {v:oldName}",
        "A new name on an old acquaintance: {v:oldName} is {v:newName}",
        { "A new name on a face I know well: {v:oldName} is {v:newName}", needs = { DIARY }, voice = "warm" },
        { "My old friend {v:oldName}, going by {v:newName} now", needs = { DIARY }, voice = "warm" },
        { "{v:oldName} as was, {v:newName} as is", voice = "wry" },
        { "Another name to learn: {v:newName}, who was {v:oldName}", voice = "wry" },
        { "{v:oldName} renamed: {v:newName}", voice = "terse" },
        { "Name change, {v:oldName} to {v:newName}", voice = "terse" },
        { "{v:newName}. Used to be {v:oldName}", voice = "terse" },
        { "{v:newName} now, not {v:oldName}", voice = "terse" },
    },

    tails = {
        ", which will take some getting used to",
        ", and I'll need to remember it",
        ", still the same {class}",
        ", which I hadn't expected",
        ", which threw me for a moment",
        ", and I won't guess why",
        ", so that's the name I'll write from here on",
        { ", at some point since we last met", says = { PRESENT } },
        { ", in the {daysx:daysSince} since we last met", needs = { "daysSince>=2" }, says = { PRESENT } },
        { ", if the name above {his} head is to be believed", needs = { SEX }, voice = "wry" },
        { ", and the new name suits {him}", needs = { SEX }, voice = "warm" },
        { ", though {he}'s the same {class} to me", needs = { SEX }, voice = "warm" },
        { ", and it suits", voice = "warm" },
        { ", for anyone reading this later", voice = "wry" },
        { ", not that it's any of my business", voice = "wry" },
        { ", if the diary's to keep up", voice = "wry" },
        { ", and I'll get it wrong at least once", voice = "wry" },
        { ", for the record", voice = "terse" },
    },

    wholes = {
        "{v:oldName} goes by {v:newName} now.",
        "{v:oldName} is {v:newName} now. Same {class}, new name.",
        "{v:oldName} has a new name: {v:newName}. I won't guess why.",
        "A new name {today}: {v:oldName} is {v:newName} now.",
        "{v:newName}. That's what {v:oldName} goes by now.",
        "{v:oldName} isn't {v:oldName} any more. It's {v:newName}.",
        "Since we last met, {v:oldName} has become {v:newName}.",
        "{days.cap:daysSince} since we last met, and {v:oldName} is {v:newName} now.",
        "It took me a moment to place {v:newName}. It's {v:oldName}, under a new name.",
        "{v:newName} used to be {v:oldName}. I'll have to remember that.",
        "{v:oldName} has been renamed {v:newName}.",
        "{v:oldName} wears a new name now: {v:newName}.",
        "The {class} I knew as {v:oldName} is called {v:newName} now.",
        "{v:newName}, the name said. It used to say {v:oldName}.",
        "I read the name {v:newName} and it took a moment to click: {v:oldName}, renamed.",
        "{v:oldName} goes by {v:newName} now. I don't know why, and I won't guess.",
        "New name, same {class}: {v:oldName} is {v:newName} these days.",
        "Whatever the reason, {v:oldName} is {v:newName} now.",
        { "The name said {v:newName}. I'd known {him} as {v:oldName}.", needs = { SEX } },
        { "I'd always known this {class} as {v:oldName}. {today.cap}, the name read {v:newName}." },
        { "{v:oldName} had changed {his} name to {v:newName} since we last met.", needs = { SEX } },
        { "I'd written {v:oldName} in this diary. From here on, it's {v:newName}.", needs = { DIARY } },
        { "{v:oldName} is in this diary under one name and goes by another now: {v:newName}.", needs = { DIARY } },
        { "My {v:oldName} is {v:newName} now. The name is new; the {class} is the same.", needs = { DIARY }, voice = "warm" },
        { "{v:oldName} goes by {v:newName} now, but it's the same {class} to me.", voice = "warm" },
        { "{v:oldName} goes by {v:newName} now. It will take me a while, but I'll get there.", voice = "warm" },
        { "A new name for someone I know well: {v:oldName} is {v:newName} now.", needs = { DIARY }, voice = "warm" },
        { "{v:newName} is {v:oldName}. Different name, same {class}, and I'm glad to see {him} either way.", needs = { SEX }, voice = "warm" },
        { "{v:oldName} or {v:newName}, the diary keeps a place either way.", needs = { DIARY }, voice = "warm" },
        { "{v:oldName} is {v:newName} now. I'll get it wrong at least once.", voice = "wry" },
        { "One more name to learn: {v:newName}, who was {v:oldName}.", voice = "wry" },
        { "Future pages will say {v:newName}. That's {v:oldName}, renamed.", voice = "wry" },
        { "{v:oldName} goes by {v:newName} now, and I'm writing both down so I don't lose track.", voice = "wry" },
        { "{v:oldName} had gone and changed {his} name: {v:newName} now.", needs = { SEX }, voice = "wry" },
        { "Apparently I know someone called {v:newName} now. It's {v:oldName}.", voice = "wry" },
        { "Note for the diary: {v:oldName} is {v:newName} now.", voice = "terse" },
        { "{v:oldName}, now {v:newName}. Noted.", voice = "terse" },
        { "Renamed: {v:oldName} to {v:newName}.", voice = "terse" },
        { "{v:oldName}? {v:newName} now.", voice = "terse" },
    },
}, NameHook))

--------------------------------------------------------------------------
-- guild: joined, left or switched
--------------------------------------------------------------------------
--
-- Every piece that tells of a change needs the flag (or the gate) that makes
-- it true: a guild name alone is not news. Leaving is "no longer in" or "out
-- of", never a decision; switching is "moved from", never a reason.

local NOGUILD = "changed:noguild"

Words("changed", "guild", Tagged({
    stems = {
        { "Since we last met, ", says = { SIMPLE } },
        "{days.cap:daysSince} since we last met, and ",
        { "Somewhere along the way, ", says = { SIMPLE } },
        { "{changed_if:after}Another change: " },
        { "{changed_if:after}Besides that, " },
        "For the record, ",
        "I noticed {today} that ",
        "Something new {today}: ",
        "As for guilds, ",
        "It caught my eye straight away: ",
        { "Not that it's my business, but ", voice = "wry" },
        { "Plenty can change in {days:daysSince}: ", voice = "wry" },
        { "Times change: ", voice = "wry" },
        { "A small thing, but ", voice = "warm" },
        { "Something I was glad to see: ", needs = { "joined==true" }, voice = "warm" },
        { "Guild news: ", voice = "terse" },
        { "{days.cap:daysSince} later: ", voice = "terse" },
    },

    clauses = {
        -- joined
        { "{ref} had [joined|signed up with] {v:newGuild}", needs = { "joined" } },
        { "{ref} was wearing a guild tag {today}: {v:newGuild}", needs = { "joined" }, final = true },
        { "{ref} had picked up a guild, {v:newGuild}", needs = { "joined" } },
        { "{ref.short}, guildless when we last met, was in {v:newGuild}", needs = { "joined" } },
        { "there was a guild under {ref.poss} name {today}, {v:newGuild}", needs = { "joined" } },
        { "{ref} wasn't guildless any more", needs = { "joined" }, bonus = -0.5 },
        { "{v:newGuild} had taken {ref.obj} in", needs = { "joined" }, voice = "warm" },
        { "{ref} had also joined {v:newGuild}{changed_if:after}", needs = { "joined" } },

        -- in a guild that is new to them (joined or switched)
        "{ref} was in {v:newGuild} now{changed_if:moved}",
        "{ref} [belonged to|was a member of] {v:newGuild}{changed_if:moved}",
        "{v:newGuild} was the guild under {ref.poss} name{changed_if:moved}",
        "{ref} was with {v:newGuild} these days{changed_if:moved}",
        { "{ref} carried a new guild tag, {v:newGuild}{changed_if:moved}", bonus = -0.5 },
        { "the guild under {ref.poss} name had changed too: {v:newGuild}{changed_if:moved}{changed_if:after}", final = true },

        -- switched
        { "{ref} had [moved|gone] from {v:oldGuild} to {v:newGuild}", needs = { "switched" } },
        { "{ref} was in {v:newGuild} now, not {v:oldGuild}", needs = { "switched" } },
        { "{ref.short}, once of {v:oldGuild}, was with {v:newGuild} now", needs = { "switched" } },
        { "{ref} had changed guilds, {v:oldGuild} to {v:newGuild}", needs = { "switched" } },
        { "{ref} had changed guilds, to {v:newGuild}", needs = { "switched" } },
        { "{v:oldGuild} was out and {v:newGuild} was in, under {ref.poss} name", needs = { "switched" } },
        { "the tag under {ref.poss} name had gone from {v:oldGuild} to {v:newGuild}", needs = { "switched" } },
        { "{ref} had changed guilds", needs = { "switched" }, bonus = -0.5 },
        { "{ref} had changed guilds too, from {v:oldGuild} to {v:newGuild}{changed_if:after}", needs = { "switched" } },
        { "{ref} had gone and changed guilds on me, {v:oldGuild} for {v:newGuild}", needs = { "switched" }, voice = "wry", final = true },

        -- left
        { "{ref} [was no longer in {v:oldGuild}|was out of {v:oldGuild}|wasn't in {v:oldGuild} any more]", needs = { "left" } },
        { "{v:oldGuild} was gone from under {ref.poss} name", needs = { "left" } },
        { "{ref} no longer carried a guild tag, where last time it read {v:oldGuild}", needs = { "left" }, final = true },
        { "{ref} and {v:oldGuild} had parted ways", needs = { "left" } },
        { "{ref} [had no guild|was without a guild|was guildless] {today}", needs = { "left" }, says = { NOGUILD } },
        { "there was no guild under {ref.poss} name any more", needs = { "left" }, says = { NOGUILD } },
        { "{ref} was out of {v:oldGuild} and in no guild at all", needs = { "left" }, says = { NOGUILD } },
        { "{ref.poss} name stood on its own now, no {v:oldGuild} under it", needs = { "left" }, says = { NOGUILD } },
        { "{ref} was out of {v:oldGuild} as well{changed_if:after}", needs = { "left" } },
        { "{ref} was on {his} own, guild-wise", needs = { "left", SEX }, says = { NOGUILD }, voice = "wry" },
        { "{ref} was a free agent, {v:oldGuild} no longer under {his} name", needs = { "left", SEX }, says = { NOGUILD }, voice = "wry" },
        { "{ref} had no guild", needs = { "left" }, says = { NOGUILD }, voice = "terse" },
    },

    fragments = {
        "{ref.short}, now of {v:newGuild}{changed_if:moved}",
        "New guild for {ref.short}: {v:newGuild}{changed_if:moved}",
        "{v:newGuild} under {ref.poss} name now{changed_if:moved}",
        { "No more {v:oldGuild} for {ref.short}", needs = { "left" } },
        { "A guild for {ref.short} now: {v:newGuild}", needs = { "joined" } },
        { "{ref.short} in a guild these days, {v:newGuild}", needs = { "joined" } },
        { "Out of {v:oldGuild}, into {v:newGuild}: {ref.short}", needs = { "switched" }, final = true },
        { "A change of guild for {ref.short}", needs = { "switched" }, bonus = -0.5 },
        { "No guild under {ref.poss} name any more", needs = { "left" }, says = { NOGUILD } },
        { "{ref.short}, guildless no longer", needs = { "joined" }, voice = "wry" },
        { "{ref.short}, a free agent now", needs = { "left" }, says = { NOGUILD }, voice = "wry" },
        { "{ref.short} in {v:newGuild}, of all things{changed_if:moved}", voice = "wry" },
        { "{ref.short}: {v:oldGuild} to {v:newGuild}", needs = { "switched" }, voice = "terse" },
        { "{ref.short}: {v:newGuild} now", needs = { "joined" }, voice = "terse" },
        { "{ref.short}, out of {v:oldGuild}", needs = { "left" }, voice = "terse", final = true },
        { "{ref.short}, guildless now", needs = { "left" }, says = { NOGUILD }, voice = "terse", final = true },
    },

    tails = {
        ", which was news to me",
        ", which I hadn't expected",
        ", and I won't guess why",
        ", and that's all I know of it",
        { ", going by the tag under {his} name", needs = { SEX } },
        { ", having had no guild when we last met", needs = { "joined==true" } },
        { ", [not {v:oldGuild} any more|and no longer in {v:oldGuild}]", needs = { "switched==true" } },
        { ", out of {v:oldGuild} and into {v:newGuild}", needs = { "switched==true" } },
        { ", and no other guild had taken its place", needs = { "left==true" }, says = { NOGUILD } },
        { ", and good luck to {him}{changed_if:moved}", needs = { SEX }, voice = "warm" },
        { ", and I wish {him} well there{changed_if:moved}", needs = { SEX }, voice = "warm" },
        { ", which I was glad to see{changed_if:moved}", voice = "warm" },
        { ", and I hope it's a good one{changed_if:moved}", voice = "warm" },
        { ", not that it's any of my business", voice = "wry" },
        { ", for anyone keeping track", voice = "wry" },
        { ", which will take some getting used to", voice = "wry" },
        { ", news to me", voice = "terse" },
        { ", for the record", voice = "terse" },
    },

    wholes = {
        -- joined
        { "{ref} had joined {v:newGuild} since we last met.", needs = { "joined" } },
        { "{ref} was in a guild now: {v:newGuild}.", needs = { "joined" } },
        { "When we last met, {ref} had no guild. Now {he} was in {v:newGuild}.", needs = { "joined" } },
        { "There was a guild under {ref.poss} name {today}: {v:newGuild}. That was new.", needs = { "joined" } },
        { "{ref} had picked up a guild since we last met. {v:newGuild}, the tag said.", needs = { "joined" } },
        { "Guildless last time, {ref} belonged to {v:newGuild} now.", needs = { "joined" } },
        { "{ref} isn't guildless any more. {v:newGuild}, the tag says.", needs = { "joined" } },
        { "{ref} had joined {v:newGuild}. Good for {him}.", needs = { "joined" }, voice = "warm" },
        { "{ref} is in {v:newGuild} now. They're lucky to have {him}.", needs = { "joined", DIARY }, voice = "warm" },
        { "{v:newGuild} has a new name on its roster, and it's {ref.short}.", needs = { "joined" }, voice = "wry" },
        { "{ref} had joined {v:newGuild}, too.{changed_if:after}", needs = { "joined" } },
        { "{ref.short}: {v:newGuild} now. Noted.", needs = { "joined" }, voice = "terse" },

        -- switched
        { "{ref} had moved from {v:oldGuild} to {v:newGuild}.", needs = { "switched" } },
        { "{ref} was in {v:newGuild} now. Last time it was {v:oldGuild}.", needs = { "switched" } },
        { "The tag under {ref.poss} name said {v:newGuild} {today}, not {v:oldGuild}.", needs = { "switched" } },
        { "{v:oldGuild} out, {v:newGuild} in: {ref} had changed guilds.", needs = { "switched" } },
        { "{ref} had gone from {v:oldGuild} to {v:newGuild} since we last met.", needs = { "switched" } },
        { "When we last met, {ref} was in {v:oldGuild}. Now it's {v:newGuild}.", needs = { "switched" } },
        { "{ref.short}, once of {v:oldGuild}, is with {v:newGuild} now.", needs = { "switched" } },
        { "On top of that, {ref} had moved from {v:oldGuild} to {v:newGuild}.{changed_if:after}", needs = { "switched" } },
        { "In my head the tag under {ref.poss} name still reads {v:oldGuild}, but it says {v:newGuild} now.", needs = { "switched" }, voice = "warm" },
        { "{ref} is with {v:newGuild} now. I hope it suits {him} as well as {v:oldGuild} did.", needs = { "switched", SEX }, voice = "warm" },
        { "{ref} has a new guild, {v:newGuild}, and {v:oldGuild} is history.", needs = { "switched" }, voice = "wry" },
        { "{ref} had moved from {v:oldGuild} to {v:newGuild}. I just write these things down.", needs = { "switched" }, voice = "wry" },
        { "{ref.short}: {v:oldGuild} to {v:newGuild}.", needs = { "switched" }, voice = "terse" },

        -- left
        { "{ref} was no longer in {v:oldGuild}. No guild at all, now.", needs = { "left" } },
        { "{v:oldGuild} was gone from under {ref.poss} name {today}.", needs = { "left" } },
        { "{ref} had no guild {today}. Last time it was {v:oldGuild}.", needs = { "left" } },
        { "Last time we met, {ref} was in {v:oldGuild}. Not any more.", needs = { "left" } },
        { "No {v:oldGuild} under {ref.poss} name any more, and nothing in its place.", needs = { "left" } },
        { "{ref} is guildless now. When we last met, {he} was in {v:oldGuild}.", needs = { "left" } },
        { "{ref} was out of {v:oldGuild}. That's all the tag tells me, and all I'll write.", needs = { "left" } },
        { "{ref} wasn't in {v:oldGuild} any more. Whatever happened there is {his} own affair.", needs = { "left", SEX }, voice = "warm" },
        { "{ref} and {v:oldGuild} are apparently no longer a pair.", needs = { "left" }, voice = "wry" },
        { "{ref} was out of {v:oldGuild} as well.{changed_if:after}", needs = { "left" } },
        { "{ref.short}: no guild. {v:oldGuild} is gone from the tag.", needs = { "left" }, voice = "terse" },
    },
}, Tense))

--------------------------------------------------------------------------
-- levels: levels gained since we last met
--------------------------------------------------------------------------
--
-- "gained" is the point. A piece that gives the old level and the new one
-- says it too (added below), since "from 23 to 28" makes the climb plain.

local PACE = "changed:pace"
local CAP = "changed:cap"

Words("changed", "levels", Tagged({
    needs = { "gained" },
    must = { "gained" },

    stems = {
        { "Since we last met, ", says = { SIMPLE } },
        "{days.cap:daysSince} since we last met, and ",
        { "In {days:daysSince}, ", says = { SIMPLE } },
        "{days.cap:daysSince} on, ",
        "As for levels, ",
        { "{changed_if:after}And as for levels, " },
        "I couldn't help noticing that ",
        { "While I'd gained {levels:myGained}, ", needs = { "gained~=@myGained" }, says = { PACE } },
        { "Where I'd managed {levels:myGained}, ", needs = { "gained>@myGained" }, says = { PACE }, voice = "wry" },
        { "While I hadn't gained a level myself, ", needs = { "myGained==0" }, says = { PACE } },
        { "Somebody's been busy: ", needs = { "gained>=4", "daysSince<=30" }, voice = "wry" },
        { "While I wasn't looking, ", says = { SIMPLE }, voice = "wry" },
        { "Good to see: ", voice = "warm" },
        { "I was pleased to see that ", voice = "warm" },
        { "Quick going: ", needs = { "gained>=6", "daysSince<=14" }, voice = "terse" },
        { "{days.cap:daysSince} later: ", voice = "terse" },
        { "Levels: ", voice = "terse" },
    },

    clauses = {
        "{ref} had gained {levels:gained}",
        "{ref} had picked up {levels:gained}",
        "{ref} had gained {levels:gained} in {days:daysSince}",
        "{ref} had gained {levels:gained} since we last met",
        "{ref} had gone from level {lvl:theirLevelThen} to {lvl:theirLevel}",
        "{ref} had climbed from {lvl:theirLevelThen} to {lvl:theirLevel}",
        "{ref.poss} level had risen by {num:gained}",
        "{ref} was {levels:gained} [higher than when we last met|up on our last meeting]",
        { "{ref} was level {lvl:theirLevel} now", bonus = -0.5 },
        { "{ref} had reached level {lvl:theirLevel}", bonus = -0.5 },
        { "{ref} had moved up to {lvl:theirLevel}", bonus = -0.5 },
        { "{ref} had levelled {times:gained}", needs = { "gained<=4" } },
        { "{ref} had [gained just the one level|edged up a single level]", needs = { "gained==1" }, says = { "gained" } },
        { "{ref} had gained a couple of levels", needs = { "gained==2" }, says = { "gained" } },
        { "{ref} had gained a good few levels", needs = { "gained>=4", "gained<=7" }, says = { "gained" } },
        { "{ref} had [shot up|piled on] {levels:gained}", needs = { "gained>=6" } },
        { "{ref} had gained {levels:gained} to my {num:myGained}", needs = { "gained>@myGained" }, says = { PACE } },
        { "{ref} had outpaced me, {num:gained} levels to {num:myGained}", needs = { "gained>@myGained" }, says = { PACE } },
        { "{ref} had gained {levels:gained} while I'd gained none", needs = { "myGained==0" }, says = { PACE } },
        { "{ref} and I had both gained {levels:gained}", needs = { "gained==@myGained" }, says = { PACE, "myGained" } },
        { "{ref} had kept pace with me, {levels:gained} each", needs = { "gained==@myGained" }, says = { PACE, "myGained" } },
        { "{ref} had gained {levels:gained}, fewer than my {num:myGained}", needs = { "gained<@myGained" }, says = { PACE } },
        { "{ref} had reached the level cap", needs = { "theirLevel>=@page.levelCap" }, says = { CAP, "gained" } },
        { "{ref} was at the cap now, level {lvl:theirLevel}", needs = { "theirLevel>=@page.levelCap" }, says = { CAP, "gained" } },
        { "{ref} had gained {levels:gained} as well{changed_if:after}" },
        { "{ref} had also gone up {levels:gained}{changed_if:after}" },
        { "{ref} had been busy, {levels:gained} since we last met", needs = { "gained>=4", "daysSince<=30" }, final = true },
        { "{ref} had come a long way, {levels:gained} since we last met", needs = { "gained>=5" }, voice = "warm", final = true },
        { "{ref} had grown up a fair bit, from {lvl:theirLevelThen} to {lvl:theirLevel}", needs = { "gained>=4" }, voice = "warm" },
        { "{ref} was coming along nicely, level {lvl:theirLevel} now", voice = "warm" },
        { "{ref} had dinged {times:gained}", needs = { "gained<=5" }, voice = "wry" },
        { "I'd outpaced {ref.obj}, {num:myGained} levels to {num:gained}", needs = { "gained<@myGained" }, says = { PACE }, voice = "wry" },
        { "{ref} had gained {levels:gained} while I stood still", needs = { "myGained==0" }, says = { PACE }, voice = "wry" },
        { "{ref} was up {levels:gained}", voice = "terse" },
        { "{ref} was {lvl:theirLevel} now", voice = "terse", bonus = -0.5 },
    },

    fragments = {
        "{ref.short}, level {lvl:theirLevel} now, up from {lvl:theirLevelThen}",
        "{levels.cap:gained} up for {ref.short} since we last met",
        "{levels.cap:gained} in {days:daysSince} for {ref.short}",
        "Level {lvl:theirLevel} for {ref.short}, {levels:gained} on from last time",
        { "{ref.short} at level {lvl:theirLevel} now", bonus = -0.5 },
        { "Just the one level for {ref.short}", needs = { "gained==1" }, says = { "gained" } },
        { "A good few levels for {ref.short}: {lvl:theirLevelThen} to {lvl:theirLevel}", needs = { "gained>=4" } },
        { "{levels.cap:gained} for {ref.short}, to my {num:myGained}", needs = { "gained>@myGained" }, says = { PACE } },
        { "{levels.cap:gained} each, {ref.short} and me", needs = { "gained==@myGained" }, says = { PACE, "myGained" } },
        { "Good progress from {ref.short}: {levels:gained} since we last met", voice = "warm" },
        { "{levels.cap:gained} for {ref.short} and not one for me", needs = { "myGained==0" }, says = { PACE }, voice = "wry" },
        { "{ref.short}: {lvl:theirLevelThen} to {lvl:theirLevel}", voice = "terse" },
        { "{ref.short}: {lvl:theirLevelThen} then, {lvl:theirLevel} now", voice = "terse" },
        { "{ref.short}, up {levels:gained}", voice = "terse" },
        { "{ref.short} at the cap now", needs = { "theirLevel>=@page.levelCap" }, says = { CAP, "gained" }, voice = "terse" },
    },

    tails = {
        ", up from [{lvl:theirLevelThen}|level {lvl:theirLevelThen} when we last met]",
        ", where last time it was {lvl:theirLevelThen}",
        ", having been {lvl:theirLevelThen} when we last met",
        ", {levels:gained} in {days:daysSince}",
        ", {levels:gained} [since we last met|on from last time|up on our last meeting]",
        { ", while I'd gained {levels:myGained}", needs = { "gained~=@myGained" }, says = { PACE } },
        { ", which put {him} at the cap", needs = { "theirLevel>=@page.levelCap", SEX }, says = { CAP } },
        { ", which is quick going", needs = { "gained>=6", "daysSince<=14" } },
        { ", which surprised me", needs = { "gained>=8" } },
        { ", and good for {him}", needs = { SEX }, voice = "warm" },
        { ", which I was glad to see", voice = "warm" },
        { ", good going", needs = { "gained>=4" }, voice = "warm" },
        { ", while I hadn't gained a single level", needs = { "myGained==0" }, says = { PACE }, voice = "wry" },
        { ", not bad for {days:daysSince}", needs = { "gained>=4" }, voice = "wry" },
        { ", and I'm a little envious", needs = { "gained>@myGained" }, says = { PACE }, voice = "wry" },
        { ", so {he}'s been busy", needs = { "gained>=5", "daysSince<=30", SEX }, voice = "wry" },
        { ", from {lvl:theirLevelThen}", voice = "terse" },
    },

    wholes = {
        "{ref} was level {lvl:theirLevel} now, up from {lvl:theirLevelThen} when we last met.",
        "When we last met, {ref} was level {lvl:theirLevelThen}. Now {he} was {lvl:theirLevel}.",
        "{ref} had gained {levels:gained} since we last met.",
        "{levels.cap:gained} in {days:daysSince}: {ref} was level {lvl:theirLevel} now.",
        "{ref} was {lvl:theirLevel} now. Last time, {lvl:theirLevelThen}.",
        "{ref} had gone from {lvl:theirLevelThen} to {lvl:theirLevel} in {days:daysSince}.",
        "Level {lvl:theirLevel} for {ref.obj} now, {levels:gained} on from our last meeting.",
        "{ref} wasn't level {lvl:theirLevelThen} any more. {he.cap} was {lvl:theirLevel}.",
        "{days.cap:daysSince} since we last met, and {ref} had gained {levels:gained}.",
        "The level on {ref.poss} nameplate said {lvl:theirLevel} {today}, not {lvl:theirLevelThen}.",
        { "{ref} had levelled {times:gained} since we last met.", needs = { "gained<=4" } },
        { "{ref} had gained just the one level since we last met.", needs = { "gained==1" }, says = { "gained" } },
        { "One level for {ref.obj} since we last met: {lvl:theirLevel} now.", needs = { "gained==1" }, says = { "gained" } },
        { "{ref} had gained {levels:gained} in {days:daysSince}, which is quick going.", needs = { "gained>=6", "daysSince<=14" } },
        { "{ref} had gained {levels:gained} to my {num:myGained}.", needs = { "gained>@myGained" }, says = { PACE } },
        { "{ref} had gone up {levels:gained} in {days:daysSince}, more than I had.", needs = { "gained>@myGained" }, says = { PACE } },
        { "{ref} and I had both gained {levels:gained} since we last met.", needs = { "gained==@myGained" }, says = { PACE, "myGained" } },
        { "{ref} had gained {levels:gained}, and so had I.", needs = { "gained==@myGained" }, says = { PACE, "myGained" } },
        { "{ref} had gained {levels:gained}, fewer than my {num:myGained}.", needs = { "gained<@myGained" }, says = { PACE } },
        { "{ref} had reached the cap since we last met: level {lvl:theirLevel}.", needs = { "theirLevel>=@page.levelCap" }, says = { CAP, "gained" } },
        { "{ref} had hit level {lvl:theirLevel}, the cap. Last time we met, {he} was {lvl:theirLevelThen}.", needs = { "theirLevel>=@page.levelCap" }, says = { CAP } },
        { "{ref} had gained {levels:gained} as well.{changed_if:after}" },
        { "And {levels:gained} on top: {ref} was {lvl:theirLevel} now.{changed_if:after}" },
        { "{ref} was level {lvl:theirLevel} now. I remember {him} at {lvl:theirLevelThen}.", needs = { SEX, "gained>=4" }, voice = "warm" },
        { "{ref} is level {lvl:theirLevel} now. Not so long ago {he} was {lvl:theirLevelThen}.", needs = { "daysSince<=30" }, voice = "warm" },
        { "{ref} had gained {levels:gained}. Good for {him}.", needs = { SEX }, voice = "warm" },
        { "{ref} had come a long way since we last met: {lvl:theirLevelThen} to {lvl:theirLevel}.", needs = { "gained>=5" }, voice = "warm" },
        { "{ref} had gained {levels:gained}, and I was glad to see it.", voice = "warm" },
        { "{ref} had piled on {levels:gained} since we last met.", needs = { "gained>=6" }, voice = "wry" },
        { "{levels.cap:gained} since we last met. {ref} has been busy.", needs = { "gained>=5", "daysSince<=30" }, voice = "wry" },
        { "{ref} had gained {levels:gained}; I'd managed {num:myGained}.", needs = { "gained>@myGained" }, says = { PACE }, voice = "wry" },
        { "For once I'd outpaced {ref.obj}: {num:myGained} levels to {num:gained} since we last met.", needs = { "gained<@myGained" }, says = { PACE }, voice = "wry" },
        { "{ref} had gained {levels:gained} while I sat on the same level.", needs = { "myGained==0" }, says = { PACE }, voice = "wry" },
        { "{ref} had dinged {times:gained} since I last saw {him}. I'd have liked to see one.", needs = { "gained>=2", "gained<=5", SEX }, voice = "wry" },
        { "{ref.short}: level {lvl:theirLevel}, up {num:gained}.", voice = "terse" },
        { "{ref.short}, {lvl:theirLevelThen} to {lvl:theirLevel}.", voice = "terse" },
        { "{ref.short}, up {levels:gained}.", voice = "terse" },
        { "{levels.cap:gained} for {ref.short}. {lvl:theirLevel} now.", voice = "terse" },
    },
}, function(piece, kind, bare)
    Tense(piece, kind, bare)
    -- From one level to the other is a climb, so it says "gained".
    if piece[1]:find("{lvl:theirLevelThen}", 1, true) then
        piece.says[#piece.says + 1] = "gained"
    end
end))

--------------------------------------------------------------------------
-- More voices, added to the moves above
--------------------------------------------------------------------------

Words("changed", "name", Tagged({
    stems = {
        { "I had to look twice, but ", voice = "warm" },
        { "For the diary's index, ", voice = "wry" },
    },
    clauses = {
        { "{v:oldName}, who I'm always glad to see, goes by {v:newName} now", says = { PRESENT }, voice = "warm" },
        { "{v:oldName} has turned into {v:newName}, as far as the nameplate goes", says = { PRESENT }, voice = "wry" },
    },
    fragments = {
        { "{v:newName} now, though always {v:oldName} to me", voice = "warm" },
        { "{v:oldName}, renamed {v:newName}", voice = "terse" },
    },
    tails = {
        { ", though the {class} behind it is the one I know", voice = "warm" },
    },
    wholes = {
        { "{v:oldName} has a new name, {v:newName}. New name or old, I'm glad to see {him}.", needs = { SEX }, voice = "warm" },
        { "I'll write {v:newName} from here on, though in my head it will be {v:oldName} for a while yet.", voice = "warm" },
        { "{v:oldName} goes by {v:newName} now. The diary will need a note in the margin.", voice = "wry" },
        { "New name: {v:newName}. Was {v:oldName}.", voice = "terse" },
    },
}, NameHook))

Words("changed", "guild", Tagged({
    stems = {
        { "Good news, I think: ", needs = { "joined==true" }, voice = "warm" },
    },
    clauses = {
        { "{ref} had joined {v:newGuild}, and I hope they're good to {him}", needs = { "joined", SEX }, voice = "warm", final = true },
        { "{ref} had {v:newGuild} under {his} name, and it looked right there{changed_if:moved}", needs = { SEX }, voice = "warm", final = true },
        { "{ref} turned up under a new banner, {v:newGuild}{changed_if:moved}", voice = "wry" },
    },
    fragments = {
        { "{ref.short} in {v:newGuild} now, was {v:oldGuild}", needs = { "switched" }, voice = "terse" },
    },
    tails = {
        { ", and I hope it treats {him} well{changed_if:moved}", needs = { SEX }, voice = "warm" },
        { ", and I'll miss seeing {v:oldGuild} under {his} name", needs = { "left==true", SEX }, voice = "warm" },
        { ", whatever the reason, and that's {his} business", needs = { SEX }, says = { "changed:why" }, voice = "warm" },
        { ", which the nameplate announced without ceremony", voice = "wry" },
    },
    wholes = {
        { "{ref} had joined {v:newGuild}. I hope they look after {him}.", needs = { "joined", SEX }, voice = "warm" },
        { "{ref} had moved to {v:newGuild}. New tag, same {class} I've always been glad to see.", needs = { "switched" }, voice = "warm" },
        { "No guild under {ref.poss} name now. Guild or none, {he}'s always welcome in these pages.", needs = { "left", DIARY, SEX }, voice = "warm" },
        { "{ref} has a guild these days, {v:newGuild}. I'm glad of it.", needs = { "joined" }, voice = "warm" },
        { "{ref} was no longer in {v:oldGuild}, and whatever the story, it's {his} to tell.", needs = { "left", SEX }, voice = "warm" },
        { "{ref} had joined {v:newGuild}. I'd ask, but it's none of my business.", needs = { "joined" }, voice = "wry" },
        { "{v:oldGuild} off, {v:newGuild} on: {ref} had changed guilds while I wasn't looking.", needs = { "switched" }, voice = "wry" },
        { "The {v:oldGuild} tag was gone from under {ref.poss} name. I just write down what the nameplate tells me.", needs = { "left" }, voice = "wry" },
        { "{ref.short}: joined {v:newGuild}.", needs = { "joined" }, voice = "terse" },
        { "{ref.short}: out of {v:oldGuild}, no guild now.", needs = { "left" }, voice = "terse" },
    },
}, Tense))

Words("changed", "levels", Tagged({
    stems = {
        { "To my delight, ", needs = { "gained>=3" }, says = { SIMPLE }, voice = "warm" },
    },
    clauses = {
        { "{ref} had come on nicely, {levels:gained} since we last met", voice = "warm", final = true },
        { "{ref} had quietly racked up {levels:gained}", voice = "wry" },
    },
    fragments = {
        { "{ref.short}, coming along nicely at {lvl:theirLevel}", voice = "warm" },
    },
    tails = {
        { ", and it was good to see {him} doing well", needs = { SEX }, voice = "warm" },
        { ", which made me smile", voice = "warm" },
        { ", which is more than I can say for myself", needs = { "gained>@myGained" }, says = { PACE }, voice = "wry" },
    },
    wholes = {
        { "{ref} was {lvl:theirLevel} now. I remember when {he} was {lvl:theirLevelThen}, and it doesn't feel long ago.", needs = { SEX, "daysSince<=45" }, voice = "warm" },
        { "{levels.cap:gained} since we last met. {ref} is getting on well, and I'm pleased for {him}.", needs = { SEX }, voice = "warm" },
        { "It was nice to see {ref.obj} at level {lvl:theirLevel}, {levels:gained} on from our last meeting.", voice = "warm" },
        { "{ref} had gained {levels:gained} since we last met. Good to see.", voice = "warm" },
        { "{ref} had gained {levels:gained}. I, meanwhile, had gained {levels:myGained}.", needs = { "gained>@myGained", "myGained>=1" }, says = { PACE }, voice = "wry" },
        { "{ref} was level {lvl:theirLevel} now, {levels:gained} on. I clearly need to get out more.", needs = { "gained>@myGained" }, says = { PACE }, voice = "wry" },
        { "{levels.cap:gained} since we last met. Whatever {ref} is doing, it's working.", needs = { "gained>=4" }, voice = "wry" },
        { "{ref.short}, {lvl:theirLevel}. Was {lvl:theirLevelThen}.", voice = "terse" },
    },
}, function(piece, kind, bare)
    Tense(piece, kind, bare)
    if piece[1]:find("{lvl:theirLevelThen}", 1, true) then
        piece.says[#piece.says + 1] = "gained"
    end
end))
