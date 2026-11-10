-- Witnesses' words on Your Diary's plates: the witness card's (Card.lua)
-- in the margin words' register, the timeline's own verbs (Kind.lua's
-- rows) so the card and the profile's row say the same thing: who (the
-- subject, in the hand), what they did (the hand), what it was against
-- (small print); its tooltip; and the caption's sentence where the card
-- has no room (Text.RegisterCaption, UI/Journey/Text/Caption.lua). `w` is the
-- plate's witness (Card.lua's Choose). A creature's name in a sentence
-- ("a Ragged Young Wolf") is the core's Text.KillerName. Copy changes go
-- through the copywriter skill, as every player-read word does.

local addonName, ns = ...

local Witnesses = ns.Witnesses
local Text = ns.UI.JourneyText
local Capital, Glue, Health, NUMBER, Short, When, Who =
    Text.Capital, Text.Glue, Text.Health, Text.NUMBER, Text.Short, Text.When, Text.Who
local L, Fmt = ns.L, ns.Fmt

-- Their first name, "Someone" where the buffer no longer has it. A witness the
-- player wrote in (Kind.lua's Written) goes by the name as written, which is all
-- a typed name has, and all that is left of a picked one once they are forgotten.
function Witnesses.Name(w)
    return w and w.name or Short(w and w.guid) or L["Someone"]
end

-- How many more were there, after the name on the card's one line:
-- "& another", "& two others" (the user's words, 14 Oct); nil for none.
-- `prose`: as a sentence says it, "and another", "and two others".
function Witnesses.Others(n, prose)
    n = n or 0
    if n < 1 then return nil end
    local word = NUMBER[n] or tostring(n)
    if prose then return Fmt(L["and %s##others"], ns.Plural(n, L["another|%s others##plural"], word)) end
    return ns.Plural(n, L["& another|& %s others##plural"], word)
end

-- What the watching was, by how long (Kind.lua's WATCHING): "saw" under
-- `saw` seconds, "merciless" from `merciless` on, else (or not timed, a
-- row from before) "watched". Nil for a helper.
function Witnesses.Look(w)
    if not (w and w.type == Witnesses.WATCHED) then return nil end
    local W = Witnesses.WATCHING
    local s = w.watched
    if type(s) ~= "number" then return "watched" end
    if s < W.saw then return "saw" end
    if s >= W.merciless then return "merciless" end
    return "watched"
end

-- What they did, in the hand under their name: "mercilessly watched you
-- die", "watched you die", "saw you die", "tried to save you", "saved you".
-- The second value is the word the hand underlines (twice), if any.
--
-- `form` is how the sentence takes it, where English says the same words
-- and another language does not:
--   nil      after one name, or under it: "Numa saved you"
--   "many"   after several, the verb theirs: "Numa and another saved you"
--   "line"   a line of its own with no one named before it: "Saved you"
local DEEDS_SAID = {
    many = { merciless = L["mercilessly watched you die##many"], saw = L["saw you die##many"],
        watched = L["watched you die##many"], saved = L["saved you##many"], tried = L["tried to save you##many"] },
    line = { merciless = L["mercilessly watched you die##line"], saw = L["saw you die##line"],
        watched = L["watched you die##line"], saved = L["saved you##line"], tried = L["tried to save you##line"] },
}
--
-- The deed holds no name, so a locale whose verb agrees with the witness
-- writes <they:he/she> and it is picked here by their record's sex.
local function Theirs(w, text, under)
    local record = w and w.guid and ns.Characters.Get and ns.Characters.Get(w.guid)
    return ns.Locale.They(text, record and record.sex or nil), under
end
function Witnesses.Deed(w, form)
    local look = Witnesses.Look(w)
    local said = form and DEEDS_SAID[form]
    if said then
        return Theirs(w, said[look or (w and w.type == Witnesses.SAVED and "saved" or "tried")])
    end
    if look == "merciless" then return Theirs(w, L["mercilessly watched you die"], L["mercilessly"]) end
    if look == "saw" then return Theirs(w, L["saw you die"]) end
    if look then return Theirs(w, L["watched you die"]) end
    if w and w.type == Witnesses.SAVED then return Theirs(w, L["saved you"]) end
    return Theirs(w, L["tried to save you"])
end

-- The creature, in small print under the deed: "to a Ragged Young Wolf"
-- (a death watched), "from Hogger" (a rescue, tried or not); nil where none
-- was kept.
function Witnesses.Foe(w)
    local name = w and w.creature and Text.KillerName(w.creature)
    if not name then return nil end
    return Fmt(w.type == Witnesses.WATCHED and L["to %s##witness"] or L["from %s##witness"], name)
end

-- The witness in a sentence of its own after the caption's, where the card
-- has no room: "Grisha mercilessly watched you die.", "Numa and another
-- tried to save you.", the timeline's verbs.
function Witnesses.Caption(w)
    local who = Witnesses.Name(w)
    local others = Witnesses.Others(w and w.others, true)
    if others then who = Fmt(L["%1$s %2$s##name and others"], who, others) end
    return Fmt(L["%1$s %2$s."], who, (Witnesses.Deed(w, others and "many" or nil)))
end

-- The card's tooltip: their full name, who they are, what they did (the
-- watching to a tenth of a second), whether they were alone, when. One the player
-- wrote in says what its card says and no more: nothing here measured how long
-- anyone watched or who joined which fight, and the tooltip must not claim it. Its
-- mark's tooltip is this too, where the card may have found no room, so the deed
-- and the creature are spelt out.
-- What a written witness did, with its creature: "Saved you from Hogger".
-- `form`: Witnesses.Deed's ("line" where the deed starts a line).
local function Did(w, form)
    local foe = Witnesses.Foe(w)
    local deed = Witnesses.Deed(w, form)
    return foe and Fmt(L["%1$s %2$s##deed and foe"], deed, foe) or deed
end

function Witnesses.Tip(w, now)
    if w.written then
        local lines = { Capital(Did(w, "line")) }
        if ns.Witnesses.Card.Evidence(w) then lines[#lines + 1] = Fmt(L["You came out of it with %s"], Health(w)) end
        lines[#lines + 1] = When(w.t, w.level, now)
        return Who(w.guid) or Witnesses.Name(w), lines
    end
    local record = ns.Characters.Get and ns.Characters.Get(w.guid) or nil
    local lines = {}
    if record then
        local who = {}
        if record.level then who[#who + 1] = Fmt(L["Level %d"], record.level) end
        who[#who + 1] = ns.UI.Format.RaceName(record)
        who[#who + 1] = ns.UI.Format.ClassName(record)
        if #who > 0 then lines[#lines + 1] = table.concat(who, " ") end
    end
    local look = Witnesses.Look(w)
    if look then
        if type(w.watched) == "number" then
            lines[#lines + 1] = Fmt(L["Watched for %s"], Glue(Fmt(L["%s seconds"], ns.UI.Format.Decimal(w.watched, 1))))
        end
        lines[#lines + 1] = L["Not in a fight themselves"]
    elseif w.type == Witnesses.SAVED then
        lines[#lines + 1] = L["Joined your fight"]
        lines[#lines + 1] = Fmt(L["You came out of it with %s"], Health(w))
    else
        lines[#lines + 1] = L["Joined the fight you died in"]
    end
    local more = w.others or 0
    if more > 0 then
        lines[#lines + 1] = ns.Plural(more, L["One other was there too|%s others were there too##plural"],
            Capital(NUMBER[more] or tostring(more)))
    end
    local at = w.death or w.call
    lines[#lines + 1] = When(w.t, at and at.level, now)
    return Who(w.guid) or Witnesses.Name(w), lines
end

-- The written witnesses' mark on a plate (Card.lua's `witnessed`): every
-- one on the spot together, `list` as Witnesses.Written reads them (9 Nov
-- 2026: two on one spot each said their name and time again). Who, then
-- what they did, each deed once with how often ("Saved you from Hogger
-- twice"), then when and at what level (ns.Deaths.Foot, the ending the
-- death-side marks share). One person: their name, a line a deed, the
-- health a rescue left where there was one rescue (DEEDS of them, the last
-- "And more besides" where there were more). Several: "Two
-- witnesses", a line each ("Grisha saved you from Hogger"), PEOPLE of them,
-- then "Others were there too". Four lines at most.
local PEOPLE, DEEDS = 3, 3

-- A person's deeds, each once: { text, n }, in the order first done.
local function Deeds(ws, form)
    local by, list = {}, {}
    for _, w in ipairs(ws) do
        local did = Did(w, form)
        if not by[did] then
            by[did] = { text = did, n = 0 }
            list[#list + 1] = by[did]
        end
        by[did].n = by[did].n + 1
    end
    return list
end

local function Often(d)
    return d.n > 1 and Fmt(L["%1$s %2$s##times"], d.text, ns.UI.Format.Times(d.n)) or d.text
end

function Witnesses.Tips(list, now)
    local people, of = {}, {}
    for _, w in ipairs(list) do
        local key = w.guid or Witnesses.Name(w)
        if not of[key] then
            of[key] = {}
            people[#people + 1] = of[key]
        end
        of[key][#of[key] + 1] = w
    end
    local lines = {}
    if #people == 1 then
        local ws = people[1]
        local deeds = Deeds(ws, "line")
        for i = 1, math.min(#deeds, DEEDS) do lines[i] = Capital(Often(deeds[i])) end
        if #deeds > DEEDS then lines[DEEDS] = L["And more besides"] end
        if #ws == 1 and ns.Witnesses.Card.Evidence(ws[1]) then
            lines[#lines + 1] = Fmt(L["You came out of it with %s"], Health(ws[1]))
        end
        lines[#lines + 1] = ns.Deaths.Foot(list, now)
        return Who(ws[1].guid) or Witnesses.Name(ws[1]), lines
    end
    for i, ws in ipairs(people) do
        if i == PEOPLE and #people > PEOPLE then
            lines[i] = L["Others were there too"]
            break
        end
        local deeds = Deeds(ws)
        local said = {}
        for k, d in ipairs(deeds) do said[k] = Often(d) end
        lines[i] = Fmt(L["%1$s %2$s##name and deed"], Witnesses.Name(ws[1]), ns.UI.TimelineText.Join(said, L["%1$s and %2$s"]))
    end
    lines[#lines + 1] = ns.Deaths.Foot(list, now)
    return Capital(ns.Plural(#people, L["%s witness|%s witnesses##plural"],
        NUMBER[#people] or tostring(#people))), lines
end

-- Someone who was there at a death or a close call on the plate
-- (Card.lua's Choose) whose card found no room beside it: `said.witness`,
-- told in a sentence of its own after the rest, in the timeline's words
-- ("Two deaths, to a Sunscale Lashtail. Grisha mercilessly watched you
-- die."). With the card beside the plate the words say nothing of them;
-- the creature the card names is the margin's to leave out (`said.death`,
-- `said.close`), as with the killer's. A coda (`at` 10) and nothing else:
-- it gathers no moment of the plate's.
Text.RegisterCaption("witness", {
    coda = { at = 10, say = function(c)
        local w = c.said.witness
        return w and Witnesses.Caption(w) or nil
    end },
})

-- Witnesses the player wrote in (Kind.lua's Written) whose cards found no room:
-- each a sentence of its own, as a detected one's, after it (coda 20). Written
-- ones are told separately from `said.witness` because a plate may hold one real
-- witness and any number of written ones. With its card shown nothing is said.
Text.RegisterCaption("witnessed", {
    coda = { at = 20, say = function(c)
        local left = c.said.witnessed
        if not (left and left[1]) then return nil end
        local sentences = {}
        for i, w in ipairs(left) do sentences[i] = Witnesses.Caption(w) end
        return table.concat(sentences, " ")
    end },
})
