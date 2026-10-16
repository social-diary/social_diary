-- The timeline's words (JNL-2, TLN-2 to TLN-6, TLN-10): what each timeline item says
-- on the profile's page, and in its tooltip.
--
-- Pure functions over ns.Timeline's items, no frames: the page
-- (UI/Journal/Timeline.lua) lays the lines out, this file only writes them.
-- What an episode's rows add up to is Core/Timeline.lua's (Timeline.Tally).

local addonName, ns = ...

local Format = ns.UI.Format

local Tally = ns.Timeline.Tally

--------------------------------------------------------------------------
-- Describing timeline items
--------------------------------------------------------------------------

local function Items(list)
    local parts = {}
    for i = 1, #list do
        local item = list[i]
        parts[#parts + 1] = (item.count and item.count > 1 and (item.count .. "x ") or "") .. item.link
    end
    return table.concat(parts, ", ")
end

local function Quote(text, fallback)
    if not text then return fallback end
    return fallback .. ': "' .. text .. '"'
end

local ROW_TEXT = {
    group_join = function(row)
        return (row.context and row.context.raid) and "Raided together" or "Grouped"
    end,
}

-- " in Hillsbrad Foothills", the row's zone, or "" (a feature's row,
-- through ns.UI.TimelineText.Place).
local function Place(row)
    return row.zone and (" in " .. row.zone) or ""
end

-- The creature a row's context names ({ name, rank }, as a witness's row
-- keeps it) as Your Diary names a killer ("a Sunscale Lashtail",
-- Text.KillerName), or nil.
local function Foe(row)
    local c = row.context or {}
    return ns.UI.JourneyText.KillerName({ name = c.name, rank = c.rank })
end

-- Each kind's icon, a Style.ART key.
local ROW_ICON = {
    group_join = "together",
}

-- Told to each kind (Core/Rows.lua: `text`, `icon`), where the page reads
-- them; a feature's own kinds tell theirs from its own folder.
for kind, text in pairs(ROW_TEXT) do ns.Rows.Register(kind, { text = text }) end
for kind, icon in pairs(ROW_ICON) do ns.Rows.Register(kind, { icon = icon }) end

-- "You died to Plainstrider (3 attackers) near Red Cloud Mesa", "Gunther
-- died, probably to Plainstrider". A death on this page is theirs or the
-- user's (Timeline's NewSession), so one that is not theirs is "You".
-- `there`: the line above named the place already, so this one says
-- "there" instead of naming it again.
local function DeathText(death, guid, there)
    local who = death.guid == guid and (ns.Characters.Name(guid) or "They") or Format.You(death.guid, "{You}")
    local text = who .. " died"

    local killer = death.killer
    local name = killer and (killer.player and killer.guid and ns.Characters.FullName(killer.guid) or killer.name)
    if killer and killer.environment and not name then
        text = text .. " (" .. killer.environment:lower() .. ")"
    elseif name then
        local to = name .. (killer.spell and ("'s " .. killer.spell) or "")
        text = text .. (killer.source == "recap" and " to " or ", probably to ") .. to
        if (killer.attackers or 0) > 1 then text = text .. " (" .. killer.attackers .. " attackers)" end
    end

    local place = death.subZone or death.zone
    if there and place then
        text = text .. " there"
    elseif place then
        text = text .. " near " .. place
    end
    return text
end

-- "Mulgore", "Mulgore and The Barrens", "Mulgore, Durotar and 2 more".
local PLACES = { max = 3, shown = 2 }

local function Places(zones)
    return Format.List(zones, PLACES)
end

local Count = Format.Count

-- Episodes (ns.Timeline) carry their children; nothing else does.
local function IsEpisode(item)
    return item ~= nil and item.all ~= nil
end

-- "Mor'Ladim", "Mor'Ladim and Rakk", "Mor'Ladim and 2 more". `max` names at
-- most that many.
local function RareNames(rares, max)
    local names = {}
    for i = 1, #rares do names[i] = rares[i].name or "a rare" end
    return Format.List(names, max and { max = max }) or ""
end

local function Rares(episode)
    return episode.participant and episode.participant.rares or {}
end

-- TLN-2's activities in words: how one opens a headline, and how it is
-- added after the first.
local LEAD = {
    quest = "Quested together",
    rare = "Hunted together",
    group = "Grouped",
    trade = "Traded",
    chat = "Chatted",
    other = "Crossed paths",
}

-- The headline and its extras are clauses, not names: "Quested together,
-- killed Mor'Ladim, and traded".
local CLAUSES = { oxford = true }

local EXTRA = {
    quest = "quested together",
    rare = function(episode) return "killed " .. RareNames(Rares(episode), 1) end,
    group = "grouped",
    trade = "traded",
    chat = "chatted",
    other = "crossed paths",
}

local ACTIVITY_ICON = { quest = "together", rare = "rare", group = "together", trade = "trade",
    chat = "talk", other = "talk" }

-- "Quested together for 3 h 5 min through Westfall and Duskwood, killed
-- Mor'Ladim, and traded".
local function Headline(episode, activities)
    local text = LEAD[activities[1]] or "Together"
    if episode.kind == "session" or episode.seconds >= 60 then
        text = text .. " for " .. Format.Duration(episode.seconds)
    end

    local zones = episode.zones or {}
    local places = Places(zones)
    if places then text = text .. (#zones > 1 and " through " or " in ") .. places end

    local clauses = { text }
    for i = 2, #activities do
        local extra = EXTRA[activities[i]]
        clauses[#clauses + 1] = type(extra) == "function" and extra(episode) or extra
    end
    return Format.List(clauses, CLAUSES)
end

-- Everyone in the visit but the user and the person whose page this is.
local function OtherMembers(visit, guid)
    local others = {}
    for _, member in ipairs(visit.members or {}) do
        if member.guid ~= guid and member.guid ~= ns.ownGUID and member.guid ~= visit.me then
            others[#others + 1] = member
        end
    end
    return others
end

-- "with Kaelith, Brom and 2 others".
local MEMBERS = { max = 3, shown = 2, more = "others" }

local function Members(visit, guid)
    local names = {}
    for _, member in ipairs(OtherMembers(visit, guid)) do names[#names + 1] = member.first or "someone" end
    local list = Format.List(names, MEMBERS)
    return list and ("with " .. list)
end

-- "Wailing Caverns, 52 min, 5 of 8 bosses", then deaths, wipes, who else
-- was there and the bosses by name.
local function VisitText(episode, guid)
    local visit = episode.visit
    local text = (visit.name or "An instance") .. ", " .. Format.Duration(episode.seconds)
    if visit.difficulty and visit.difficulty ~= "Normal" then
        text = text .. " (" .. visit.difficulty .. ")"
    end
    local bosses = visit.bossesKilled or {}
    if visit.bossTotal then
        text = text .. (", %d of %d bosses"):format(#bosses, visit.bossTotal)
    elseif #bosses > 0 then
        text = text .. ", " .. Count(#bosses, "boss", "bosses")
    end

    local facts = {}
    if (visit.deaths or 0) > 0 then facts[#facts + 1] = Count(visit.deaths, "death", "deaths") end
    local wipes = ns.DungeonRun.Wipes(visit)
    if wipes > 0 then facts[#facts + 1] = Count(wipes, "wipe", "wipes") end
    facts[#facts + 1] = Members(visit, guid)
    if #bosses > 0 then facts[#facts + 1] = "killed " .. table.concat(bosses, ", ") end
    return text, facts
end

-- TLN-6: every trade in the episode, summed, once the headline says "traded".
local function TradeFact(t)
    local parts = {}
    if #t.given > 0 then parts[#parts + 1] = "gave " .. Items(t.given) end
    if t.moneyGiven > 0 then parts[#parts + 1] = "gave " .. Format.Money(t.moneyGiven) end
    if #t.received > 0 then parts[#parts + 1] = "got " .. Items(t.received) end
    if t.moneyReceived > 0 then parts[#parts + 1] = "got " .. Format.Money(t.moneyReceived) end
    if #parts == 0 then return t.trades > 1 and Count(t.trades, "trade", "trades") or nil end
    local text = table.concat(parts, "; ")
    return t.trades > 1 and (t.trades .. " trades: " .. text) or text
end

-- The details line, most telling first: what the headline names, then how
-- they changed, then the counts of everything else. Moments the headline
-- does not name are lines of their own, so they are not counted here.
local function Facts(episode, guid)
    local t = Tally(episode)
    local p = episode.participant
    local facts = {}
    local function Add(fact) if fact then facts[#facts + 1] = fact end end

    for _, activity in ipairs(episode.headline) do
        if activity == "quest" then
            Add(Count(#p.quests, "quest", "quests"))
        elseif activity == "rare" then
            Add("killed " .. RareNames(Rares(episode)))
        elseif activity == "trade" then
            Add(TradeFact(t))
        elseif activity == "chat" then
            Add(Count(t.chat, "message", "messages"))
        elseif activity == "other" then
            Add(Count(t.other, "other interaction", "other interactions"))
        end
    end

    if p and p.levelStart and p.levelEnd and p.levelEnd ~= p.levelStart then
        Add(("they went from %d to %d"):format(p.levelStart, p.levelEnd))
    end

    -- Deaths with a line of their own (Timeline's death items) are not
    -- counted again, nor those a dungeon run in it counts (TLN-11); older
    -- sessions only have the count.
    local session = episode.session
    if session then
        local deaths = (session.deaths[guid] or 0) + (session.deaths[session.me] or 0)
            - (episode.runDeaths or 0)
        for i = 1, #episode.all do
            if episode.all[i].kind == "death" then deaths = deaths - 1 end
        end
        if deaths > 0 then Add(Count(deaths, "death", "deaths")) end
    end

    -- TLN-4: a session counts its visits; each one tells its own story.
    local dungeons, raids = 0, 0
    for i = 1, #episode.all do
        local child = episode.all[i]
        if child.kind == "visit" then
            if child.visit.instanceType == "raid" then raids = raids + 1 else dungeons = dungeons + 1 end
        end
    end
    if dungeons > 0 then Add(Count(dungeons, "dungeon", "dungeons")) end
    if raids > 0 then Add(Count(raids, "raid", "raids")) end

    local named = episode.named
    if not named.chat and t.chat > 0 then Add(Count(t.chat, "message", "messages")) end
    if not named.trade and t.chatterTrades > 0 then Add(Count(t.chatterTrades, "trade", "trades")) end
    if not named.other and t.other > 0 then Add(Count(t.other, "other interaction", "other interactions")) end

    return facts
end

-- TLN-3: the headline and details line cut to the episode's length; the
-- tooltip gets all of it.
local function EpisodeText(episode, guid)
    local visitText, facts
    if episode.kind == "visit" then
        visitText, facts = VisitText(episode, guid)
        for _, fact in ipairs(Facts(episode, guid)) do facts[#facts + 1] = fact end
    else
        facts = Facts(episode, guid)
    end
    local _, budget = ns.Timeline.Budget(episode.seconds)

    local shown = {}
    for i = 1, math.min(budget, #facts) do shown[i] = facts[i] end
    if episode.session and not episode.session.endedAt then
        shown[#shown + 1] = "still going"
        facts[#facts + 1] = "still going"
    end

    local text = visitText or Headline(episode, episode.headline)
    local sub = #shown > 0 and table.concat(shown, "  ·  ") or nil
    local full = visitText or Headline(episode, episode.activities)
    if #facts > 0 then full = full .. "\n" .. table.concat(facts, "  ·  ") end

    local icon = (episode.kind == "session" and "together") or (episode.kind == "visit" and "dungeon")
        or ACTIVITY_ICON[episode.headline[1]] or "talk"
    return text, sub, icon, full
end

-- A note the user wrote (DIA-11, TLN-10): its text on one line, and for
-- the tooltip all of it, whom else it is about, and when it was written.
-- Shared by a note of its own and one in a run's description.
local function DescribeNote(note, guid)
    local text = note.text:gsub("%s*\n%s*", " ")
    local full = { note.text }

    local others = {}
    for _, other in ipairs(ns.Notes.Others(note, guid)) do
        others[#others + 1] = ns.Characters.FullName(other) or "someone"
    end
    if #others > 0 then full[#full + 1] = "Also about " .. Format.List(others) .. "." end

    local written = "Written at " .. date("%H:%M", note.time)
    if note.zone then written = written .. " in " .. note.zone end
    full[#full + 1] = written .. "."
    full[#full + 1] = "Click to change or delete it."
    return text, table.concat(full, "\n")
end

-- Returns the time, the line, an optional second line, the icon and the
-- whole story for the tooltip (nil: the lines are all of it), coloured for a
-- dark tooltip; the page inks them (Style.Inkify).
function ns.UI.DescribeItem(item, guid)
    local when = date("%H:%M", item.time)

    if IsEpisode(item) then
        local text, sub, icon, full = EpisodeText(item, guid)
        return when, text, sub, icon, full
    elseif item.kind == "climb" then
        -- "Tester went from level 1 to 6", each level and its time in the
        -- tooltip. The climb is the timeline's (Core/Rows.lua's `climb`),
        -- so its words and icon stay here; its rows' context { from, level }
        -- is that flag's contract.
        local ups = item.ups
        local first, last = ups[1].row.context or {}, ups[#ups].row.context or {}
        local from, to = first.from or ((first.level or 1) - 1), last.level or "?"
        local name = guid and ns.Characters.Name(guid)
        local text = ("%s from level %s to %s"):format(name and (name .. " went") or "Went", from, to)
        local full = { text }
        for _, up in ipairs(ups) do
            full[#full + 1] = date("%H:%M", up.time) .. "  level " .. tostring(up.row.context and up.row.context.level or "?")
        end
        return when, text, nil, "levelup", table.concat(full, "\n")
    elseif item.kind == "rare" then
        return when, "Killed " .. (item.rare.name or "a rare"), nil, "rare"
    elseif item.kind == "death" then
        -- Said "there", the tooltip still names the place.
        return when, DeathText(item.death, guid, item.there), nil, "death",
            item.there and DeathText(item.death, guid) or nil
    elseif item.kind == "around" then
        local stretch = item.around
        local text = "Seen around"
        local places = Places(stretch.zones)
        if places then text = text .. " " .. places end
        local seconds = stretch.last - stretch.start
        if seconds >= 60 then text = text .. " for " .. Format.Duration(seconds) end
        return when, text, nil, "around"
    elseif item.kind == "note" then
        local text, full = DescribeNote(item.note, guid)
        return when, text, nil, "note", full
    elseif item.kind == "first" then
        local first = item.first
        local place = ns.UI.JourneyText.Place(first.mapID, first.subZone)
        return when, "First seen" .. (place and (" at " .. place) or "")
            .. (first.level and (", level " .. first.level) or ""), nil, "added"
    elseif item.kind == "added" then
        local context = item.entry.addedContext
        local place = context and context.zone and (" in " .. context.zone) or ""
        return when, "Added to the diary" .. place, nil, "added"
    end

    local kind = ns.Rows.Get(item.row.type)
    return when, kind.text and kind.text(item.row, guid) or item.row.type, nil, kind.icon
end

-- For the page lines, which lay episodes and visits out, and a note's
-- words (UI/Journal/Timeline.lua).
-- And a row's words shared by its kinds, for a feature's file
-- (Features/<Name>/, .claude/skills/new-feature/folder.md) to tell its own rows
-- (Core/Rows.lua's `text`) as these do: Items(list) "2x [Linen Cloth],
-- [Copper Ore]"; Quote(text, fallback) 'Said: "hello"', or the fallback
-- alone; Place(row) " in Hillsbrad Foothills", or ""; Foe(row) the
-- creature in a witness's row as Your Diary names a killer ("a Kobold
-- Vermin"), or nil.
ns.UI.TimelineText = { IsEpisode = IsEpisode, OtherMembers = OtherMembers, DescribeNote = DescribeNote,
    Items = Items, Quote = Quote, Place = Place, Foe = Foe }
