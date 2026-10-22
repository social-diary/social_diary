-- A dungeon run's words (MAP-13 to MAP-15): what a margin note says
-- (UI/Dungeon/Notes.lua), the facts a boss's tooltip adds under its name
-- and a death's cross's tooltip (UI/Dungeon/Print.lua). One place, so the
-- strips and the tooltips always say the same.
--
-- A strip is written as the plates' margin strips are (UI/Journey/Text/
-- Margin.lua, "killed you twice"): its first line a heading in sentence
-- case, what happened under it in lower case, and counts in words up to
-- ten. A tooltip line is the same words, capitalised.

local addonName, ns = ...

local DungeonPage = ns.UI.DungeonPage
local Format = ns.UI.Format

local Words = {}
DungeonPage.Words = Words

local ORDINAL = { "first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth", "tenth" }
local NUMBER = { "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten" }

local function Capital(text) return (text:gsub("^%l", string.upper)) end
Words.Capital = Capital

-- "once", "twice", "three times" ... "ten times", then "11 times".
local function Times(n)
    if n == 1 then return "once" end
    if n == 2 then return "twice" end
    return (NUMBER[n] or tostring(n)) .. " times"
end

-- "Wiped once", "Wiped twice", "Wiped three times".
function Words.Wipes(n) return "Wiped " .. Times(n) end

-- The try that killed it, as a strip's heading where there was no wipe
-- ("Killed on the third try"), or how often a boss still standing was
-- tried ("Tried twice"). nil past the tenth try of a kill.
function Words.Tries(n, killed)
    if not killed then return "Tried " .. Times(n) end
    local on = Words.KilledOn(n)
    return on and Capital(on) or nil
end

-- Under a wipe: "killed on the second try". nil past the tenth.
function Words.KilledOn(n)
    return ORDINAL[n] and ("killed on the %s try"):format(ORDINAL[n]) or nil
end

-- Under a boss's wipes or tries when it still stands.
Words.STANDING = "left standing"

-- "Ran back once", "Ran back twice", and under it how (Words.GHOST).
function Words.RanBack(n) return "Ran back " .. Times(n) end
Words.GHOST = "as a ghost"

-- Whose loot `guid` is, as the page says it: "you", or their first name.
local function Whose(visit, guid)
    if guid == ns.ownGUID or guid == visit.me then return Format.You(guid, "{you}") end
    for _, m in ipairs(visit.members or {}) do
        if m.guid == guid and m.first then return m.first end
    end
    return (ns.Characters.Name(guid)) or "someone"
end
Words.Whose = Whose

-- An item that dropped for someone: "dropped for Tester", "dropped for you".
function Words.Dropped(visit, guid) return "dropped for " .. Whose(visit, guid) end

-- Loot worth a note: the user's own, or a diary entry's (MAP-13). A
-- stranger's is only counted.
function Words.Noted(visit, guid)
    return guid == ns.ownGUID or guid == visit.me or ns.Diary.IsDiary(guid)
end

-- What happened at a boss, a line each, for its tooltip: its wipes, its
-- tries (unless the wipes already told them), what dropped there for
-- whom, and how much for others.
function Words.Facts(visit, e)
    local lines = {}
    local wipes, tries = e.wipes or 0, e.tries or 0
    if wipes > 0 then lines[#lines + 1] = Words.Wipes(wipes) end
    if (e.near or 0) > 0 then lines[#lines + 1] = Words.NEARLY end
    if tries > 1 then
        local said
        if e.killed then
            said = Words.KilledOn(tries)
            said = said and Capital(said)
        elseif tries > wipes then
            said = Words.Tries(tries, false)
        end
        if said then lines[#lines + 1] = said end
    end
    local others = 0
    for _, entry in ipairs(e.loot or {}) do
        if Words.Noted(visit, entry.guid) then
            lines[#lines + 1] = ("%s, dropped for %s"):format(ns.Style.Inkify(entry.item or "?"), Whose(visit, entry.guid))
        else
            others = others + 1
        end
    end
    if others == 1 then
        lines[#lines + 1] = "One item for someone else"
    elseif others > 1 then
        lines[#lines + 1] = Capital(NUMBER[others] or tostring(others)) .. " items for others"
    end
    return lines
end

-- Who or what killed someone, as a sentence names it: a player by name,
-- this dungeon's bosses and rares bare ("Aggem Thorncurse"), anything
-- else with its article ("a Razorfen Defender").
local function Killer(visit, k)
    if k.player then return (k.guid and ns.Characters.Name(k.guid)) or k.name end
    local D = ns.Dungeons
    local boss = D and visit.instanceID and D.Boss(visit.instanceID, k.name)
    if (boss and not boss.trash) or (D and visit.instanceID and D.IsRare(visit.instanceID, k.name)) then
        return k.name
    end
    return ns.UI.JourneyText.KillerName(k) or k.name
end

-- A death, for its cross: "Brom died, probably to Aggem Thorncurse", "You
-- died to a Razorfen Defender" (the killer as the death recap gave it, or
-- the guess at the time), "You died (falling)", as the timeline says it
-- (UI/Words/Timeline.lua's DeathText).
function Words.Death(visit, death)
    local who = Capital(Whose(visit, death.guid))
    local text = who .. " died"
    local k = death.killer
    if k and k.name and k.name ~= "" then
        text = text .. (k.source == "recap" and " to " or ", probably to ") .. Killer(visit, k)
    elseif k and k.environment then
        text = text .. " (" .. k.environment:lower() .. ")"
    end
    return text
end

-- Where about a death on the way was: "On the way to Death Speaker
-- Jargba", "After Overlord Ramtusk", "On the way in". Always approximate.
-- A boss by the game's name for it where the data's differs (`names`,
-- DungeonPage.Names).
function Words.Leg(leg, names)
    names = names or {}
    if leg.before then return ("On the way to %s"):format(names[leg.before.name] or leg.before.name) end
    if leg.after then return ("After %s"):format(names[leg.after.name] or leg.after.name) end
    return "On the way in"
end

-- A wipe to trash on the way (MAP-17): "Wiped on the way", and under it
-- what to, from what each death of it was to, in the order they fell:
-- "to a Dark Iron Looter", "to a Dark Iron Looter and an Anvilrage
-- Guardsman", past two "to a Dark Iron Looter and others". One kind is
-- named once, with its article, however many deaths it took (as the
-- plates' "Two deaths, to a Sunscale Lashtail."): the data knows the kind,
-- not how many of them there were, so the diary guesses no plural. `wipe`
-- is one of ns.DungeonRun.Notes(visit).wipes; nil when no death says.
Words.WAY_WIPE = "Wiped on the way"
function Words.WipedTo(visit, wipe)
    local names, seen = {}, {}
    for _, death in ipairs(wipe and wipe.deaths or {}) do
        local k = death.killer
        local name = k and k.name and k.name ~= "" and Killer(visit, k)
        if name and not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end
    if #names == 0 and wipe and wipe.killer and wipe.killer ~= "" then
        names[1] = Killer(visit, { name = wipe.killer })
    end
    if #names == 0 then return nil end
    if #names > 2 then return "to " .. names[1] .. " and others" end
    return "to " .. Format.List(names)
end

-- The items one boss dropped for you and the diary's people, as one
-- strip's heading: "[A]", "[A] and [B]", "[A], [B] and [C]". Returns the
-- heading and each item's piece of it, { text, from } (`from` the heading
-- before it), so each link can take the mouse on its own.
function Words.Items(links)
    local parts, text = {}, ""
    for i, link in ipairs(links) do
        local sep = i == 1 and "" or (i == #links and " and " or ", ")
        text = text .. sep
        parts[i] = { text = link, from = text }
        text = text .. link
    end
    return text, parts
end

-- Under them, for whom: "dropped for Tester", "dropped for Tester and you".
function Words.DroppedFor(visit, guids)
    local names = {}
    for i, guid in ipairs(guids) do names[i] = Whose(visit, guid) end
    return "dropped for " .. Format.List(names)
end

-- "and 2 more", under the notes there was no room for.
function Words.More(n) return ("and %d more"):format(n) end

-- A near wipe (Core/DungeonRun.lua's NEAR): "Nearly wiped", and under it
-- how many went down, "two went down" (the diary is not in the group, so
-- no "us").
Words.NEARLY = "Nearly wiped"
function Words.WentDown(n) return ("%s went down"):format(NUMBER[n] or tostring(n)) end

-- A level-up on the map: the bare level scrawled by its star ("22"), as
-- the plates' level pins, and its tooltip, "Level 22" over who, as the
-- plates' "Reached ...": "Reached by Tester", "Reached by you".
function Words.LevelScrawl(level) return tostring(level) end
function Words.LevelTip(visit, up)
    return ns.Style.TipList(("Level %d"):format(up.level), { "Reached by " .. Whose(visit, up.guid) })
end

-- Rolls (pass B). An item snagged from you: "Brom snagged it from you"
-- (the user's own name in a shared diary, as "dropped for"), under it the
-- rolls, "80 against 85" (yours first). An item that finally came to you:
-- "Finally! After two drops, it's yours": the exclamation is the user's
-- (16 Oct), an exception to the quiet voice like "Your first green!";
-- `total` is at least two (Core/DungeonRun.lua: a drop lost before, and
-- this one). A bad roll: "Brom rolled a 2", "You rolled a 2", under it
-- "on [item]". The pairs' words come with the part of them that is
-- underlined, from their start: "Brom snagged it", "Finally!" (the user,
-- 16 Oct).
function Words.Snagged(visit, guid)
    local part = ("%s snagged it"):format(Capital(Whose(visit, guid)))
    return ("%s from %s"):format(part, Whose(visit, visit.me)), part
end
function Words.Versus(mine, theirs) return ("%d against %d"):format(mine, theirs) end
function Words.Finally(total)
    return ("Finally! After %s drops, it's yours"):format(NUMBER[total] or tostring(total)), "Finally!"
end
function Words.Rolled(visit, guid, roll) return ("%s rolled a %d"):format(Capital(Whose(visit, guid)), roll) end
function Words.OnItem(link) return "on " .. ns.Style.Inkify(link or "?") end

-- The party's cards (step 4). A fact of a card's holder's run in words
-- (Core/DungeonRun.lua's Person), its subject the card's own: "died
-- twice", "won [Golemguard Chest]", "snagged [Gnarled Tusk Band] from
-- you", "rolled a 2", "reached level 23" (the level star's words),
-- "joined late", "left early", "your third run together", past the tenth
-- "11 runs together". Facts, never a judgement. "You" is the visit's own
-- character's name in a shared diary, as on the strips. A card prints
-- none of them (its notes are handwritten, UI/Dungeon/Cards.lua): a note
-- about an item says this in its tooltip where the item's cannot show.
function Words.Fact(fact, visit)
    local k = fact.kind
    if k == "snagged" then
        local from = visit and Whose(visit, visit.me) or "you"
        return ("snagged %s from %s"):format(ns.Style.Inkify(fact.item or "?"), from)
    end
    if k == "won" then return "won " .. ns.Style.Inkify(fact.item or "?") end
    if k == "died" then return "died " .. Times(fact.n) end
    if k == "rolled" then return ("rolled a %d"):format(fact.roll) end
    if k == "reached" then return ("reached level %d"):format(fact.level) end
    if k == "late" then return "joined late" end
    if k == "early" then return "left early" end
    if k == "together" then
        return ORDINAL[fact.n] and ("your %s run together"):format(ORDINAL[fact.n]) or ("%d runs together"):format(fact.n)
    end
end

-- The card's line under the name: "Level 22 Shaman" (never the race).
function Words.Who(level, class)
    local parts = {}
    if level then parts[#parts + 1] = "Level " .. level end
    if class then parts[#parts + 1] = class end
    return table.concat(parts, " ")
end

-- A gnome's employee number on their badge, from the GUID: "4471-G"
-- (printed matter, so its zeros, not the diary's hand; the badge's own
-- "EMPLOYEE ID" says what it is).
function Words.Serial(guid)
    local hex = tostring(guid or ""):match("(%x%x%x%x%x%x)$") or "0"
    return ("%04d-G"):format((tonumber(hex, 16) or 0) % 10000)
end

-- The tooltip every card's way into the diary gives, a click hint as the
-- timeline's ("Click to open its map.").
Words.ADD = "Click to add them to the diary."
-- The cards' stack on the table (UI/Dungeon/Cards.lua), lying together.
Words.STACK = "Click to fan out the cards."
