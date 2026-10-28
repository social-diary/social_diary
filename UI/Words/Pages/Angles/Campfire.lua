-- Campfire: someone sat down at my campfire. A small, cosy moment, told as
-- it was: they sat, perhaps others sat too, and that's all. No talk, no
-- emotes, no guesses at why they sat or how long they stayed.
--
-- campfire facts (the planner's)
--   who          the person who sat (usually a stranger, sometimes a diary
--                entry)
--   zone         where my fire was
--   subZone      where my fire was, more closely (if known)
--   theirLevel   their level
--   strangers    others who sat at the fire too (0+)
--   firstTime    (bool) the first time they sat at my fire
--
-- The fire is mine and so is the place: "at my fire at Lakeshire" is where
-- I was. Nothing says where they came from, where they went, or what they
-- did beyond sitting. A "stranger" is someone with no name in the diary
-- and no familiar face (the STRANGER guards below).
--
-- Declared here, both reading `strangers` (1+):
--   {campfire_us:strangers}      everyone at the fire, me included, in
--                                words ("four" for two others)
--   {campfire_guests:strangers}  everyone who sat, them included: "three
--                                visitors" for two others

local addonName, ns = ...

local Pages = ns.Pages
local Words = Pages.Words

Pages.Angle("campfire", { order = { "sat" }, about = "someone sat at my campfire" })

Pages.Format("campfire_us", function(v)
    if type(v) ~= "number" or v < 1 then return nil end
    return Pages.Lang.Num(v + 2)
end)

Pages.Format("campfire_guests", function(v)
    if type(v) ~= "number" or v < 1 then return nil end
    return Pages.Lang.Count(v + 1, "visitor")
end)

local SEX = "who.sex>1"
local DIARY = "who.diary==true"
-- No name and no familiar face: a stranger in the plain sense.
local STRANGER = { "!who.diary", "!who.named", "!who.familiar" }
local AGAIN = "firstTime==false"
local NOBODY = "strangers==0"

local function With(list, ...)
    local out = {}
    for i = 1, #list do out[#out + 1] = list[i] end
    for i = 1, select("#", ...) do out[#out + 1] = select(i, ...) end
    return out
end

-- Tags read from the wording, so two pieces never lean on the same word or
-- make the same point in one sentence.
local RULES = {
    { "campfire:fire", { "fire", "flame", "hearth" } },
    { "campfire:company", { "company", "alone", "guest", "visitor", "crowd", "busy", "customer" } },
    { "campfire:glad", { "glad", "nice", "liked", "pleasant", "welcome", "best part", "good" } },
    { "campfire:again", { "again", "before", "first time", "a first", "regular", "habit" } },
    { "campfire:too", { "%f[%a]too%f[%A]", "as well", "%f[%a]also%f[%A]", "besides", "along with", "joined by" } },
    { "campfire:small", { "small", "little", "that's all", "nothing more" } },
    { "campfire:stranger", { "stranger", "unknown", "didn't know", "never seen" } },
    { "campfire:seat", { "seat", "spot", "place at" } },
}

local KINDS = { "stems", "clauses", "fragments", "tails", "wholes" }

local function Tagged(spec)
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
            -- One colon a sentence.
            if (kind == "stems" and bare:find(":%s*$")) or (kind ~= "stems" and kind ~= "wholes" and bare:find(":")) then
                piece.says[#piece.says + 1] = "campfire:colon"
            end
            -- Every sentence names who sat.
            if piece[1]:find("{ref", 1, true) then
                piece.says[#piece.says + 1] = "campfire:who"
            end
            -- A place tail never follows a bare name: "Company at the fire:
            -- Ilyra in Duskwood" would put her somewhere. The place is mine.
            local tail = piece[1]:gsub("%s+$", "")
            if tail:find("{ref[%.%w]*}$") or tail:find("among them$") or tail:find("{lvl:theirLevel}$") then
                piece.says[#piece.says + 1] = "campfire:where"
            end
            -- The others at the fire, however they are put, are told once,
            -- and a level remark never follows them (whose level?).
            if piece[1]:find("strangers", 1, true) then
                piece.says[#piece.says + 1] = "campfire:others"
            end
            -- The time of day is said once.
            if piece[1]:find("{part}", 1, true) then
                piece.says[#piece.says + 1] = "page.part"
            end
            -- The level, however it is put, is said once.
            if piece[1]:find("theirLevel", 1, true) then
                piece.says[#piece.says + 1] = "theirLevel"
            end
        end
    end
    return spec
end

--------------------------------------------------------------------------
-- sat: someone sat at my fire
--------------------------------------------------------------------------

Words("campfire", "sat", Tagged({
    must = { "campfire:who" },

    stems = {
        "{today.cap}, ",
        "{at.cap:subZone}, ",
        "{in.cap:zone}, ",
        "While I had a fire going {at:subZone}, ",
        "While I had a fire going {in:zone}, ",
        "By my campfire {at:subZone}, ",
        "At my fire {today}, ",
        "Unexpectedly, ",
        "A small thing from {today}: ",
        { "Once again, ", needs = { AGAIN } },
        { "Not for the first time, ", needs = { AGAIN } },
        { "For the first time, ", needs = { "firstTime", DIARY } },
        { "Late in the night, ", needs = { "page.part==night" }, says = { "page.part" } },
        { "A nice moment {today}: ", voice = "warm" },
        { "The best part of the {part}: ", voice = "warm" },
        { "To my quiet pleasure, ", voice = "warm" },
        { "As fires go, mine was popular {today}: ", needs = { "strangers>=2" }, says = { "strangers" }, voice = "wry" },
        { "Apparently my fire is the place to be: ", needs = { "strangers>=1" }, says = { "strangers" }, voice = "wry" },
        { "In news from the hearth, ", voice = "wry" },
        { "Campfire: ", voice = "terse" },
        { "{at.cap:subZone}: ", voice = "terse" },
    },

    clauses = {
        "{ref} sat down at my fire",
        "{ref} sat down at my campfire",
        "{ref} took a seat at my fire",
        "{ref} sat by my fire",
        "{ref} shared my fire",
        "{ref} sat down with me",
        "{ref} sat down beside me",
        "{ref} took a seat beside me",
        "{ref} sat down across from me",
        "{ref} joined me at the fire",
        "{ref} sat with me at my campfire",
        "{ref} sat down at my campfire {at:subZone}",
        "{ref} sat down at my fire {in:zone}",
        "{ref} sat at my fire {today}",
        { "I had company at the fire: {ref}", final = true },
        { "my fire had a visitor, {ref}" },
        { "my fire {at:subZone} had a visitor: {ref}", final = true },
        { "I wasn't alone at my fire {today}: {ref} sat down", final = true },
        { "{ref}, level {lvl:theirLevel}, sat down at my fire" },

        -- who it was
        { "a stranger sat down at my fire, {ref}", needs = STRANGER },
        { "{ref}, a stranger to me, sat down at my fire", needs = STRANGER },
        { "someone I didn't know sat at my fire: {ref}", needs = STRANGER, final = true },
        { "{ref}, a face I'd seen around before, sat at my fire", needs = { "who.familiar" } },
        { "{ref} sat at my fire, a face I half knew", needs = { "who.familiar" } },
        { "an old friend sat at my fire: {ref}", needs = { DIARY }, final = true },
        { "{ref} sat down at my fire for the first time", needs = { "firstTime", DIARY } },
        { "{ref} sat at my fire again", needs = { AGAIN } },
        { "{ref} took a seat at my fire again", needs = { AGAIN } },
        { "{ref} was back at my fire", needs = { AGAIN } },

        -- the others
        { "{ref} and {count:strangers:other} sat at my fire" },
        { "{ref} sat down at my fire, and {count:strangers:other} too", final = true },
        { "{ref} sat at my fire along with {count:strangers:other}" },
        { "{ref} was one of {campfire_us:strangers} round my fire, me included", final = true },
        { "my fire had {campfire_guests:strangers}, {ref.short} among them" },
        { "{ref} sat at my fire, and nobody else", needs = { NOBODY }, says = { "strangers" } },

        -- voices
        { "{ref} kept me company at the fire", voice = "warm" },
        { "{ref} sat down at my fire, and I was glad of the company", voice = "warm", final = true },
        { "I shared my fire with {ref.obj}, and liked it", voice = "warm", final = true },
        { "{ref} made a quiet {part} a little less quiet by sitting at my fire", voice = "warm", final = true },
        { "my fire acquired a guest, {ref}", voice = "wry" },
        { "{ref} helped {him}self to a seat at my fire", needs = { SEX }, voice = "wry" },
        { "{ref} claimed a spot at my fire", voice = "wry" },
        { "{ref} became a regular at my fire", needs = { AGAIN }, voice = "wry" },
        { "{ref} sat at my fire", voice = "terse" },
        { "{ref} joined me at the fire", voice = "terse" },
    },

    fragments = {
        "Company at the fire: {ref}",
        "A visitor at my fire {at:subZone}: {ref}",
        "A guest at my campfire, {ref}",
        "Shared my fire with {ref.obj}",
        "Shared my fire {in:zone} with {ref.obj}",
        "{ref.short} at my fire",
        "{ref.short} at my campfire {today}",
        "{ref.short}, level {lvl:theirLevel}, at my fire",
        "Someone at my fire {today}: {ref}",
        { "{ref.short} at my fire again", needs = { AGAIN } },
        { "{ref.short}, back at my fire", needs = { AGAIN } },
        { "First time {ref.short} sat at my fire", needs = { "firstTime", DIARY } },
        { "A stranger at my fire, {ref}", needs = STRANGER },
        { "{ref.short} and {count:strangers:other} at my fire" },
        { "A full fire: {ref.short} and {count:strangers:other}", needs = { "strangers>=2" } },
        { "{campfire_us.cap:strangers} round the fire, {ref.short} among them" },
        { "Good company at the fire, {ref.short}", voice = "warm" },
        { "A warm fire and {ref.short} beside it", voice = "warm" },
        { "A guest at my fire, uninvited and welcome: {ref}", voice = "wry" },
        { "One more customer for my fire, {ref.short}", needs = { "strangers>=1" }, voice = "wry" },
        { "{ref.short}, by the fire", voice = "terse" },
        { "{ref.short}. Campfire", voice = "terse" },
        { "{ref.short} and {num:strangers} more at the fire", voice = "terse" },
    },

    tails = {
        { " {at:subZone}", says = { "campfire:where" } },
        { " {in:zone}", says = { "campfire:where" } },
        { " {today}", says = { "campfire:where" } },
        { ", and {count:strangers:other} sat too" },
        { ", along with {count:strangers:other}" },
        { ", one of {campfire_guests:strangers}", says = { "campfire:company" } },
        { ", making {campfire_us:strangers} of us round the fire" },
        { ", the only one who sat", needs = { NOBODY }, says = { "strangers" } },
        { ", just the two of us", needs = { NOBODY }, says = { "strangers" } },
        { ", the first time {he} has sat at my fire", needs = { "firstTime", DIARY, SEX } },
        { ", not for the first time", needs = { AGAIN } },
        { ", as {he} has done before", needs = { AGAIN, SEX } },
        { ", a level {lvl:theirLevel} {class}", needs = { DIARY } },
        { ", the same level as me", needs = { "theirLevel==@page.levelEnd" }, says = { "theirLevel", "campfire:others" } },
        { ", higher in level than me", needs = { "theirLevel>@page.levelEnd" }, says = { "theirLevel", "campfire:others" } },
        { ", a good way below my level", needs = { "theirLevel<@page.levelEnd", "theirLevel<=20" }, says = { "theirLevel", "campfire:others" } },
        { ", and I was glad of the company", voice = "warm" },
        { ", which I liked", voice = "warm" },
        { ", and the fire felt better for it", voice = "warm" },
        { ", which made for a pleasant {part}", voice = "warm" },
        { ", uninvited but welcome", voice = "wry" },
        { ", as if I'd put up a sign", voice = "wry" },
        { ", which I'll take as a compliment to the fire", voice = "wry" },
        { ", for the record", voice = "terse" },
    },

    wholes = {
        -- plain
        "{ref} sat down at my fire {today}.",
        "{ref} sat down at my campfire {at:subZone}.",
        "I had a fire going {at:subZone}, and {ref} sat down at it.",
        "I had a fire going {in:zone}, and {ref} sat down at it.",
        "Company at my fire {at:subZone}: {ref}.",
        "My fire {at:subZone} had a guest {today}: {ref}.",
        "{ref} took a seat at my campfire {in:zone}.",
        "Someone sat at my fire {today}: {ref}.",
        "{ref}, level {lvl:theirLevel}, sat down at my fire {in:zone}.",
        "{ref} sat at my campfire. That's all, and it was enough.",
        "A small moment {today}: {ref} sat down at my fire.",
        "I lit a fire {at:subZone}, and {ref} sat down at it.",
        "I lit a fire {in:zone}. {ref} sat down at it.",
        { "A stranger sat down at my fire {today}: {ref}.", needs = STRANGER },
        { "{ref} sat down at my fire. I didn't know {him}, and it didn't matter.", needs = With(STRANGER, SEX) },
        { "{ref}, a face I'd seen around, sat down at my fire {today}.", needs = { "who.familiar" } },
        { "{ref} sat at my fire again {today}.", needs = { AGAIN } },
        { "{ref} was back at my fire {today}, as {he} has been before.", needs = { AGAIN, SEX } },
        { "{ref} sat down at my fire for the first time {today}.", needs = { "firstTime", DIARY } },
        { "I've known {ref.obj} a while, but {he} had never sat at my fire before {today}.", needs = { "firstTime", DIARY } },

        -- the others
        { "{ref} sat at my campfire {in:zone}. {count.cap:strangers:other} sat too.", needs = { "strangers>=1" } },
        { "There were {campfire_us:strangers} of us at the fire {today}: me, {ref.short} and {count:strangers:other}." },
        { "{ref} shared my fire {today}, along with {count:strangers:other}." },
        { "My fire had {campfire_guests:strangers} {today}, {ref.short} among them." },
        { "{ref} sat down at my fire, and so did {count:strangers:other}." },
        { "{ref} was the only one at my fire {today}, and that suited me.", needs = { NOBODY }, says = { "strangers" } },
        { "Just {ref.short} and me at the fire {at:subZone}.", needs = { NOBODY }, says = { "strangers" } },

        -- warm
        { "{ref} took a seat at my fire. I was glad of the company.", voice = "warm" },
        { "{ref} sat down at my fire {today}. That's all, and it was nice.", voice = "warm" },
        { "A fire {at:subZone}, and {ref} sitting at it. A good way to spend the {part}.", voice = "warm" },
        { "I wasn't alone at my fire {today}. {ref} sat down, and I liked having the company.", voice = "warm" },
        { "{ref} sat at my fire {today}, and I'll remember it.", needs = { DIARY }, voice = "warm" },
        { "My fire, {ref.short} and {count:strangers:other}. A good little gathering.", voice = "warm" },
        { "Nothing much happened at my fire {today}, except that {ref} sat down at it, and that was enough.", voice = "warm" },

        -- wry
        { "My campfire drew a crowd {today}: {ref.short} and {count:strangers:other}.", needs = { "strangers>=2" }, voice = "wry" },
        { "I should start charging for seats at my fire. {ref} sat down {today}.", voice = "wry" },
        { "{ref} found my fire. Or my fire found {him}.", needs = { SEX }, voice = "wry" },
        { "{ref} sat at my fire again. I may have to start setting a place.", needs = { AGAIN }, voice = "wry" },
        { "{ref} sat down at my fire {at:subZone} again. I'm becoming quite the innkeeper.", needs = { AGAIN }, voice = "wry" },
        { "{ref} sat down at my fire. I'll take it as a compliment to my fire-making.", voice = "wry" },
        { "Of all the fires {in:zone}, {ref} sat down at mine.", voice = "wry" },

        -- terse
        { "{ref.short}, at my fire.", voice = "terse" },
        { "Campfire {at:subZone}. {ref.short} sat down.", voice = "terse" },
        { "Campfire. {ref.short} and {count:strangers:other}.", voice = "terse" },
        { "{ref.short} at my fire again.", needs = { AGAIN }, voice = "terse" },
        { "Company at the fire: {ref.short}, level {lvl:theirLevel}.", voice = "terse" },
    },
}))

--------------------------------------------------------------------------
-- More voices
--------------------------------------------------------------------------

Words("campfire", "sat", Tagged({
    stems = {
        { "Happily, ", voice = "warm" },
        { "In what passes for excitement, ", voice = "wry" },
        { "Business was brisk at my fire {today}: ", needs = { "strangers>=2" }, says = { "campfire:company" }, voice = "wry" },
    },
    clauses = {
        { "{ref} sat down by my fire, and the {part} felt warmer for it", voice = "warm", final = true },
        { "my fire collected {ref.obj}", voice = "wry" },
    },
    fragments = {
        { "A shared fire, {ref.short} and me", needs = { NOBODY }, says = { "strangers" }, voice = "warm" },
        { "Another guest for the fire: {ref}", needs = { "strangers>=1" }, voice = "wry" },
        { "Visitor: {ref}", voice = "terse" },
        { "Fire company: {ref.short}", voice = "terse" },
    },
    tails = {
        { ", which I didn't mind one bit", voice = "warm" },
        { ", and I was glad not to be alone", voice = "warm" },
        { ", which I'll count as the {part}'s social event", voice = "wry" },
        { ", no invitation required", voice = "wry" },
    },
    wholes = {
        { "{ref} sat with me at my fire. It's a small thing, but I liked it.", voice = "warm" },
        { "Good company {today}: {ref} took a seat at my fire.", voice = "warm" },
        { "I had my fire going {at:subZone}, and {ref} sat down beside it. I'd hoped someone might.", voice = "warm" },
        { "A quiet fire {in:zone}, and then {ref} sat down at it, and it felt less lonely.", voice = "warm" },
        { "{ref} and {count:strangers:other} sat round my fire {today}. I liked the company.", voice = "warm" },
        { "My fire {at:subZone} drew {ref.obj} in. It has that effect.", voice = "wry" },
        { "{ref} sat down at my fire. I've decided to take it personally, in a good way.", voice = "wry" },
        { "Free seats at my fire, and {ref} took one.", voice = "wry" },
        { "I built a fire {in:zone} and {ref} sat down at it, which I gather is how fires work.", voice = "wry" },
        { "{ref} sat down at my fire. Word of my fire-building must be spreading.", voice = "wry" },
        { "Fire {at:subZone}. {ref.short} sat.", voice = "terse" },
        { "{ref.short} sat down. Fire {in:zone}.", voice = "terse" },
        { "{ref.short} at the fire, {count:strangers:other} besides.", voice = "terse" },
        { "Campfire, {today}: {ref.short}.", voice = "terse" },
    },
}))

