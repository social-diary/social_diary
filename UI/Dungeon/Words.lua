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
local L, Fmt = ns.L, ns.Fmt
-- A locale's own grammar (Locales/Locale.lua): Capital, where a locale has
-- replaced it.
local G = ns.Locale.grammar

local Words = {}
DungeonPage.Words = Words

-- "killed on the %s try" takes these (German declines them: "dritten").
local ORDINAL = { L["first##try"], L["second##try"], L["third##try"], L["fourth##try"], L["fifth##try"],
    L["sixth##try"], L["seventh##try"], L["eighth##try"], L["ninth##try"], L["tenth##try"] }
local NUMBER = { L["one"], L["two"], L["three"], L["four"], L["five"], L["six"], L["seven"], L["eight"], L["nine"],
    L["ten"] }

local function Capital(text)
    return G.Capital(text)
end
Words.Capital = Capital

-- "once", "twice", "three times" ... "ten times", then "11 times".
-- English's word for two is asked for on its own (it is no plural
-- category); the rest is the count's plural (ns.Plural).
local function Times(n)
    if n == 2 and L["twice"] ~= "" then return L["twice"] end
    if NUMBER[n] then return ns.Plural(n, L["once|%s times##plural"], NUMBER[n]) end
    return ns.Plural(n, L["once|%d times##plural"])
end

-- "Wiped once", "Wiped twice", "Wiped three times".
function Words.Wipes(n) return Capital(Fmt(L["Wiped %s"], Times(n))) end

-- The try that killed it, as a strip's heading where there was no wipe
-- ("Killed on the third try"), or how often a boss still standing was
-- tried ("Tried twice"). nil past the tenth try of a kill.
function Words.Tries(n, killed)
    if not killed then return Capital(Fmt(L["Tried %s"], Times(n))) end
    local on = Words.KilledOn(n)
    return on and Capital(on) or nil
end

-- Under a wipe: "killed on the second try". nil past the tenth.
function Words.KilledOn(n)
    return ORDINAL[n] and Fmt(L["killed on the %s try"], ORDINAL[n]) or nil
end

-- Under a boss's wipes or tries when it still stands.
Words.STANDING = L["left standing"]

-- "Ran back once", "Ran back twice", and under it how (Words.GHOST); the
-- door's tooltip says both at once, "Ran back twice as a ghost".
function Words.RanBack(n) return Capital(Fmt(L["Ran back %s"], Times(n))) end
Words.GHOST = L["as a ghost"]
function Words.RanBackGhost(n) return Capital(Fmt(L["Ran back %s as a ghost"], Times(n))) end

-- Whether `guid` is the page's own: "you" in its sentences.
local function Mine(visit, guid) return guid == ns.ownGUID or guid == visit.me end

-- Whose loot `guid` is, as the page says it: "you", or their first name.
-- `you` is the "{you}" the sentence takes (Format.You): a locale declines
-- it by what it follows ("{you}##for", for "dropped for you").
local function Whose(visit, guid, you)
    if Mine(visit, guid) then return Format.You(guid, you or L["{you}##subject"]) end
    for _, m in ipairs(visit.members or {}) do
        if m.guid == guid and m.first then
            local record = ns.Locale.gendered and ns.Characters.Get(guid)
            if record then ns.Locale.Says(m.first, record.sex) end
            return m.first
        end
    end
    return (ns.Characters.Name(guid)) or L["someone"]
end
Words.Whose = Whose

-- After "dropped for", after "from" (snagged from), after "by" (reached by).
local function For(visit, guid) return Whose(visit, guid, L["{you}##for"]) end
local function From(visit, guid) return Whose(visit, guid, L["{you}##from"]) end
local function By(visit, guid) return Whose(visit, guid, L["{you}##by"]) end

-- An item that dropped for someone: "dropped for Tester", "dropped for you".
function Words.Dropped(visit, guid) return Fmt(L["dropped for %s"], For(visit, guid)) end

-- Under an item found on the way, from trash (UI/Dungeon/Notes.lua's
-- wayLoot), for whom: "dropped for Tester on the way", "dropped for you on
-- the way". A boss's "dropped for" with the page's "on the way" (as "Wiped
-- on the way"), so the two sit side by side; its tooltip line is the same,
-- capitalised.
function Words.FoundFor(visit, guid) return Fmt(L["dropped for %s on the way"], For(visit, guid)) end

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
            lines[#lines + 1] = Fmt(L["%1$s, dropped for %2$s"], ns.Style.Inkify(entry.item or "?"), For(visit, entry.guid))
        else
            others = others + 1
        end
    end
    if others > 0 then
        lines[#lines + 1] = Capital(ns.Plural(others, L["One item for someone else|%s items for others##plural"],
            NUMBER[others] or tostring(others)))
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
--
-- A sentence each, as German conjugates the verb by who died: the page's
-- own in "{You}" (Format.You), anyone else by name.
local DIED = {
    you = { bare = L["{You} died"], to = L["{You} died to %s"], probably = L["{You} died, probably to %s"],
        world = L["{You} died (%s)"] },
    other = { bare = L["%s died"], to = L["%1$s died to %2$s"], probably = L["%1$s died, probably to %2$s"],
        world = L["%1$s died (%2$s)"] },
}
-- The death recap's environmental kinds, as the sentence says them.
local WORLD = { falling = L["falling"], drowning = L["drowning"], fatigue = L["fatigue"], fire = L["fire"],
    lava = L["lava"], slime = L["slime"] }

function Words.Death(visit, death)
    local k = death.killer
    local how, what = "bare", nil
    if k and k.name and k.name ~= "" then
        how, what = k.source == "recap" and "to" or "probably", Killer(visit, k)
    elseif k and k.environment then
        local kind = k.environment:lower()
        how, what = "world", WORLD[kind] or kind
    end
    if Mine(visit, death.guid) then
        local text = Format.You(death.guid, DIED.you[how])
        if not what then return text end
        return Fmt(text, what)
    end
    local who = Capital(Whose(visit, death.guid))
    if not what then return Fmt(DIED.other.bare, who) end
    return Fmt(DIED.other[how], who, what)
end

-- Where about a death on the way was: "On the way to Death Speaker
-- Jargba", "After Overlord Ramtusk", "On the way in". Always approximate.
-- A boss by the game's name for it where the data's differs (`names`,
-- DungeonPage.Names).
function Words.Leg(leg, names)
    names = names or {}
    if leg.before then return Fmt(L["On the way to %s"], names[leg.before.name] or leg.before.name) end
    if leg.after then return Fmt(L["After %s"], names[leg.after.name] or leg.after.name) end
    return L["On the way in"]
end

-- A wipe to trash on the way (MAP-17): "Wiped on the way", and under it
-- what to, from what each death of it was to, in the order they fell:
-- "to a Dark Iron Looter", "to a Dark Iron Looter and an Anvilrage
-- Guardsman", past two "to a Dark Iron Looter and others". One kind is
-- named once, with its article, however many deaths it took (as the
-- plates' "Two deaths, to a Sunscale Lashtail."): the data knows the kind,
-- not how many of them there were, so the diary guesses no plural. `wipe`
-- is one of ns.DungeonRun.Notes(visit).wipes; nil when no death says.
Words.WAY_WIPE = L["Wiped on the way"]
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
    if #names > 2 then return Fmt(L["to %s and others"], names[1]) end
    return Fmt(L["to %s##killers"], Format.List(names))
end

-- The items one boss dropped for you and the diary's people, as one
-- strip's heading: "[A]", "[A] and [B]", "[A], [B] and [C]". Returns the
-- heading and each item's piece of it, { text, from } (`from` the heading
-- before it), so each link can take the mouse on its own.
-- Each link joins the heading as a list's next item ("%1$s, %2$s", the
-- last "%1$s and %2$s"); `from` is the heading up to where it lands.
-- (Not "\1": ns.Fmt keeps a template's "%%" in that while it works.)
local SLOT = "\2"
function Words.Items(links)
    local parts, text = {}, ""
    for i, link in ipairs(links) do
        local joined = i == 1 and SLOT
            or Fmt(i == #links and L["%1$s and %2$s"] or L["%1$s, %2$s##list"], text, SLOT)
        local before, after = joined:match("^(.-)\2(.*)$")
        parts[i] = { text = link, from = before }
        text = before .. link .. after
    end
    return text, parts
end

-- Under them, for whom: "dropped for Tester", "dropped for Tester and you".
function Words.DroppedFor(visit, guids)
    local names = {}
    for i, guid in ipairs(guids) do names[i] = For(visit, guid) end
    return Fmt(L["dropped for %s"], Format.List(names))
end

-- "and 2 more", under the notes there was no room for.
function Words.More(n) return ns.Plural(n, L["and %d more|and %d more##plural"]) end

-- A near wipe (Core/DungeonRun.lua's NEAR): "Nearly wiped", and under it
-- how many went down, "two went down" (the diary is not in the group, so
-- no "us").
Words.NEARLY = L["Nearly wiped"]
function Words.WentDown(n)
    return ns.Plural(n, L["%s went down|%s went down##plural"], NUMBER[n] or tostring(n))
end

-- A level-up on the map: the bare level scrawled by its star ("22"), as
-- the plates' level pins, and its tooltip, "Level 22" over who, as the
-- plates' "Reached ...": "Reached by Tester", "Reached by you".
function Words.LevelScrawl(level) return tostring(level) end
function Words.LevelTip(visit, up)
    return ns.Style.TipList(Fmt(L["Level %d"], up.level), { Fmt(L["Reached by %s"], By(visit, up.guid)) })
end

-- A find on the way's mark (Print.lua's Finds), its tooltip: the item
-- itself over its strip's line, capitalised, "Dropped for Tester on the
-- way" (FoundFor). The link as it comes, coloured for the dark tooltip.
function Words.FoundTip(visit, f)
    local entry = f.entry or {}
    return ns.Style.TipList(entry.item or "?", { Capital(Words.FoundFor(visit, entry.guid)) })
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
-- A translation keeps the underlined part at the start ("Brom hat es"
-- before "dir weggeschnappt").
function Words.Snagged(visit, guid)
    local part = Fmt(L["%s snagged it"], Capital(Whose(visit, guid)))
    return Fmt(L["%1$s from %2$s##snagged"], part, From(visit, visit.me)), part
end
function Words.Versus(mine, theirs) return Fmt(L["%1$d against %2$d"], mine, theirs) end
function Words.Finally(total)
    return ns.Plural(total, L["Finally! After %s drop, it's yours|Finally! After %s drops, it's yours##plural"],
        NUMBER[total] or tostring(total)), L["Finally!"]
end
function Words.Rolled(visit, guid, roll)
    if Mine(visit, guid) then return Fmt(Format.You(guid, L["{You} rolled a %d"]), roll) end
    return Fmt(L["%1$s rolled a %2$d"], Capital(Whose(visit, guid)), roll)
end
function Words.OnItem(link) return Fmt(L["on %s##item"], ns.Style.Inkify(link or "?")) end
