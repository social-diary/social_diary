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
local When = Text.When

Hunter.WORDS = {
    -- The printed line under a given name: the family, then the beast it
    -- was, as the game names them ("Wolf · Prairie Stalker"). %1$s family,
    -- %2$s beast. Single-spaced, as signed: the card is narrow.
    kind = "%s · %s",
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
    -- Its second line, under a given name: what the game calls it, the
    -- ledger's join ("Wolf  ·  Prairie Stalker"). %1$s family, %2$s beast.
    tipKind = "%s  ·  %s",

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

-- The printed line under the hand: "Wolf · Prairie Stalker" under a given
-- name; the family alone under the beast's name; nil knowing neither.
function Hunter.Kind(tame)
    if tame.name and tame.family and tame.beast then return W.kind:format(tame.family, tame.beast) end
    return tame.family
end

-- The level tag's words, or nil.
function Hunter.Level(tame)
    return tame.petLevel and W.level:format(tame.petLevel) or nil
end

-- The mark's tooltip lines: who, what it was, when.
function Hunter.Tip(tame, now)
    local lines = {}
    if tame.name then
        lines[#lines + 1] = W.tipNamed:format(tame.name)
        if tame.family and tame.beast then lines[#lines + 1] = W.tipKind:format(tame.family, tame.beast) end
    elseif tame.beast then
        lines[#lines + 1] = W.tipBeast:format(tame.beast)
    else
        lines[#lines + 1] = W.tipNone
    end
    -- When, without the hunter's level (the user's sign-off, 4 Nov).
    lines[#lines + 1] = When(tame.t, nil, now)
    return lines
end

-- A menu's line for one card (the custom spec's `describe`).
function Hunter.Describe(tame)
    return tame.name or tame.beast or W.describeNone
end
