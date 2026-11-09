-- A hunter's tames: the words a player reads. The margin card (card A,
-- signed 4 Nov: .claude/ui-proposal/hunter-tames.md), its mark's tooltip
-- (Mark.lua), and a custom card's line in a menu. The custom card's picker
-- title, heading and form labels are on the moment's spec (Kind.lua, which
-- loads first). No caption words and no paragraph on the left page (the scope); neither
-- the hunter's level nor the tries merged (`n`) is said anywhere (the
-- user's sign-off, 4 Nov). Copy changes go through the copywriter skill,
-- as every player-read word does.
--
-- The card's inks (the diary's rule): the hand writes what happened (the
-- name the hunter gave the pet, else the beast's own name), printed type
-- what the game says (the family, the beast under a given name, the pet's
-- level on the printed tag).

local addonName, ns = ...

local Hunter = ns.Hunter
local Text = ns.UI.JourneyText
local Capital, List = Text.Capital, Text.List

Hunter.WORDS = {
    -- The printed line under a given name: the family, then the beast it
    -- was, as the game names them ("Wolf, Prairie Stalker"). %1$s family,
    -- %2$s beast. Where it will not go on one line, the card puts each on
    -- its own (Card.lua). A comma, never a middle dot (the copywriter skill).
    kind = "%s, %s",
    -- The pet's level on the printed tag, as the close call's tag says a
    -- creature's ("Lv 7"). %d the level.
    level = "Lv %d",
    -- The mark's tooltip, its first line under a given name: the name and
    -- the deed ("Bristlemane, tamed here"). %s the name.
    tipNamed = "%s, tamed here",
    -- Its first line with no given name: the beast's own name, bare as a
    -- tooltip's title ("Prairie Stalker, tamed here"). %s the beast.
    tipBeast = "%s, tamed here",
    -- Its first line knowing neither ("A pet, tamed here").
    tipNone = "A pet, tamed here",
    -- Its second line, under a given name: what the game calls it, as the
    -- card prints it ("Wolf, Prairie Stalker"). %1$s family, %2$s beast.
    tipKind = "%s, %s",
    -- Under several tames on one spot, a given name's line names it too
    -- ("Bristlemane, Wolf, Prairie Stalker"). %1$s the name, %2$s family,
    -- %3$s beast.
    tipEach = "%s, %s, %s",
    -- In the title's list of several, a tame known by neither name ("Snarl
    -- and a pet, tamed here").
    tipSome = "a pet",

    -- The custom card's picker title, heading and form labels are on the
    -- moment's spec in Kind.lua, as every feature's are (it loads first).
    -- A menu's line for one card with neither name nor beast ("A pet").
    describeNone = "A pet",
}

local W = Hunter.WORDS

-- What the hand writes: the given name, else the beast.
function Hunter.Hand(tame)
    return tame.name or tame.beast
end

-- The printed line under the hand: "Wolf, Prairie Stalker" under a given
-- name; the family alone under the beast's name; nil knowing neither.
function Hunter.Kind(tame)
    if tame.name and tame.family and tame.beast then return W.kind:format(tame.family, tame.beast) end
    return tame.family
end

-- The level tag's words, or nil.
function Hunter.Level(tame)
    return tame.petLevel and W.level:format(tame.petLevel) or nil
end

-- When the tames on one spot were, as every mark's tooltip on the plates
-- ends (the core's Text.Foot and Text.Moments, UI/Journey/Text/Tips.lua):
-- each time, a day said once for the times on it, "Today at 12:47 and
-- 15:10", past four the first to the last, "Today from 12:47 to 19:02".
-- Never the hunter's level (the user's sign-off, 4 Nov).
local function Foot(ts, now)
    return Text.Foot({ times = ts }, now)
end

-- The paw's tooltip: one account of every tame on its spot (a list of one
-- for a lone paw), as a title and lines. Who, each once: "Bristlemane,
-- tamed here", "Bristlemane and Snarl, tamed here", "Snarl and a pet, tamed
-- here" (known by neither name), "A pet, tamed here"; what the game calls a
-- named one, "Wolf, Prairie Stalker", or with several on the spot
-- "Bristlemane, Wolf, Prairie Stalker", two at most (past that the
-- title has named them all); then when, without the hunter's level and
-- without the tries merged (the user's sign-off, 4 Nov).
function Hunter.Tips(tames, now)
    local hands, seen, some = {}, {}, false
    local kinds, said = {}, {}
    local ts = {}
    for _, tame in ipairs(tames) do
        local hand = Hunter.Hand(tame)
        if not hand then
            some = true
        elseif not seen[hand] then
            seen[hand] = true
            hands[#hands + 1] = hand
        end
        ts[#ts + 1] = tame.t or 0
    end
    local many = #hands + (some and 1 or 0) > 1
    for _, tame in ipairs(tames) do
        if tame.name and tame.family and tame.beast then
            local line = many and W.tipEach:format(tame.name, tame.family, tame.beast)
                or W.tipKind:format(tame.family, tame.beast)
            if not said[line] then
                said[line] = true
                kinds[#kinds + 1] = line
            end
        end
    end
    local title = W.tipNone
    if hands[1] then
        if some then hands[#hands + 1] = W.tipSome end
        title = W.tipNamed:format(List(hands))
    end
    local lines = {}
    if #kinds <= 2 then
        for _, line in ipairs(kinds) do lines[#lines + 1] = line end
    end
    lines[#lines + 1] = Foot(ts, now)
    return title, lines
end

-- One tame's tooltip lines, the title first (the card's, Card.lua): its
-- paw's alone (Hunter.Tips).
function Hunter.Tip(tame, now)
    local title, lines = Hunter.Tips({ tame }, now)
    return { title, unpack(lines) }
end

-- A menu's line for one card (the custom spec's `describe`).
function Hunter.Describe(tame)
    return tame.name or tame.beast or W.describeNone
end
