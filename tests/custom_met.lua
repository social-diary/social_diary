-- Custom cards: the met kind (.claude/features/custom-cards.md).

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local SELF = F.SELF
local Custom, Recap, J, Met = ns.Custom, ns.JourneyRecap, ns.Journey, ns.Met
local Text = ns.UI.JourneyText

mock.now = 1791000000
local now = mock.now
SELF.level = 11
mock.SetUnit("player", SELF)
ns.TouchOwnCharacter()

local t0 = now - 7200
local MAP = 1412
J.Begin(ns.ownGUID, t0, 10, MAP)
local j = J.Mine()
j.segments = { { kind = "stop", from = t0, to = t0 + 3000, mapID = MAP, x = 0.40, y = 0.60, r = 30, seconds = 3000,
    levelFrom = 10, levelTo = 10 } }
j.open = nil
j.levels[11] = { at = t0 + 3500, mapID = MAP, x = 0.40, y = 0.60 }
J.Touch()

local GUID = "Player-1-0AAAAAAA"
ns.db.characters[GUID] = { guid = GUID, names = { { first = "Brannoc", surname = "" } } }
ns.db.diary[GUID] = { tags = {}, addedAt = now }
local OTHER = "Player-1-0CCCCCCC"
ns.db.characters[OTHER] = { guid = OTHER, names = { { first = "Wenna", surname = "" } } }
ns.db.diary[OTHER] = { tags = {}, addedAt = now }

local WHERE = { mapID = MAP, x = 0.42, y = 0.58, from = t0, to = t0 + 3000 }

local function Count(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

--------------------------------------------------------------------------
Section("the kind opts in, and only ever by hand")

do
    local spec = Custom.Spec("met")
    Eq(spec.label, "Someone You Met", "the picker's title")
    Eq(spec.group, "social", "its type")
    Eq(spec.fields[1].type, "person", "a person for who")
    Eq(spec.fields[2].key, "what", "and a line for what")
    Eq(Recap.MOMENTS.met.order, 85, "its moment's order")
    Eq(ns.UI.JourneyPlate.MARKS.met.order, 36, "its mark's")
    Eq(ns.UI.JourneyMargin.KINDS.met.order, 2, "its place in the margin")
    Eq(Text.CAPTIONS.met.lead.at, 15, "its lead")
    Eq(Text.CAPTIONS.met.tail.at, 5, "its tail")

    local e = Recap.Gather(j, t0, now, Recap.Context(ns.ownGUID, now))
    Eq(#e.met, 0, "nothing is ever detected")
    Eq(j.custom, nil, "and reading writes no list")
end

--------------------------------------------------------------------------
Section("the mark draws without a moment, for the picker")

do
    local Plate = ns.UI.JourneyPlate
    local kit = Plate.MarkKit(UIParent, function() end, function() end, { 1, 1, 1 })
    Plate.MARKS.met.draw(kit, 10, 10)
    Eq(kit.ink.used, 1, "the ring")
    Eq(kit.inner.used, 1, "and its hole")
end

--------------------------------------------------------------------------
Section("a card writes nothing but itself")

local typed
do
    local rows, sessions = Count(ns.db.interactions), Count(ns.db.sessions)
    local people, diary = Count(ns.db.characters), Count(ns.db.diary)
    local segments = #j.segments
    typed = Custom.Insert("met", { who = "Old Tom", what = "fished off the pier" }, WHERE)
    Eq(typed.who, "Old Tom", "the name as written")
    Eq(typed.whoGuid, nil, "no link")
    Eq(typed.what, "fished off the pier", "the line")
    Eq(j.custom[1], typed, "on the custom list")
    Eq(Count(ns.db.interactions), rows, "no People row")
    Eq(Count(ns.db.sessions), sessions, "no session")
    Eq(Count(ns.db.characters), people, "no character")
    Eq(Count(ns.db.diary), diary, "no diary entry")
    Eq(#j.segments, segments, "the route as it was")
    local e = Recap.Gather(j, t0, now, Recap.Context(ns.ownGUID, now))
    Eq(#e.met, 1, "gathered")
    Eq(e.met[1].customOf, typed, "knows its record")
    Eq(#Recap.Gather(j, t0 + 4000, now, Recap.Context(ns.ownGUID, now)).met, 0, "not outside its time")
    Eq(Recap.Rank({ kind = "met", met = e.met[1] }), 0.5, "above everything, as custom")
end

--------------------------------------------------------------------------
Section("the caption")

do
    local linked = { t = t0, whoGuid = GUID, who = "Brannoc" }
    local name = { t = t0, who = "Old Tom" }
    local function Plated(...)
        local p = { mapID = MAP, moments = {} }
        for _, rec in ipairs({ ... }) do p.moments[#p.moments + 1] = { kind = "met", t = rec.t, met = rec } end
        return p
    end
    Eq(Text.PlateCaption(Plated(name), nil, { named = {}, met = {} }), "With Old Tom.", "left off, a typed name is said")
    Eq(Text.PlateCaption(Plated(linked), nil, { named = {}, met = {} }), "With Brannoc.", "and a linked one")
    Eq(Text.PlateCaption(Plated(name), nil, { named = {}, met = { [name] = true } }), "In good company.",
        "on a strip, never named: the words an automatic strip's plate has")
    Eq(Text.PlateCaption(Plated(linked), nil, { named = { [GUID] = true }, met = {} }), "In good company.",
        "nor where another strip names them")

    local s = { t = t0, guid = OTHER }
    local p = Plated(name)
    p.moments[2] = { kind = "session", t = t0, guid = OTHER, session = s }
    Eq(Text.PlateCaption(p, nil, { named = {}, met = {} }), "With Wenna, and with Old Tom.",
        "after the people's lead, first in the tail")
    p = Plated(linked)
    p.moments[2] = { kind = "session", t = t0, guid = GUID, session = s }
    Eq(Text.PlateCaption(p, nil, { named = {}, met = {} }), "With Brannoc.", "never twice")

    -- What the margin tells the words.
    local spec = ns.UI.JourneyMargin.KINDS.met
    local said = { named = {} }
    spec.say(said, { { rec = linked } }, {})
    Eq(said.named[GUID], true, "its strip names them")
    Eq(said.met[linked], true, "and the card is told")
    Check(said.named.someone == nil, "a card is no stranger's fight")
    said = { named = {} }
    spec.assume(said, { metMarks = { { at = { 1, 2 }, list = { { met = name } } } } })
    Eq(said.met[name], true, "taken as shown until it is left off, typed or not")
end

--------------------------------------------------------------------------
Section("the mark's tooltip: every card on its spot, one account")

do
    local spec = ns.UI.JourneyPlate.MARKS.met
    local function M(rec) return { kind = "met", t = rec.t, met = rec } end
    local function Clock(t) return date("%H:%M", t) end
    local tom = { t = now - 900, who = "Old Tom", what = "fished off the pier", level = 10 }
    local title, lines = spec.tips({ M(tom) }, now)
    Eq(title, "With Old Tom", "a lone card: who")
    Eq(lines[1], "fished off the pier", "a lone card: what")
    Eq(lines[2], "Today at " .. Clock(tom.t) .. ", level 10", "a lone card: when, and the level")
    Eq(#lines, 2, "a lone card: nothing doubled")
    title, lines = Met.Tip({ t = now - 900, who = "Old Tom", what = "" }, now)
    Eq(#lines, 1, "an empty line is no line")

    local again = { t = now - 300, who = "Old Tom", what = "fished off the pier", level = 11 }
    title, lines = spec.tips({ M(tom), M(again) }, now)
    Eq(title, "With Old Tom", "met twice: the name once")
    Eq(lines[1], "fished off the pier", "met twice: the line once")
    Eq(lines[2], "Today at " .. Clock(tom.t) .. " and " .. Clock(again.t) .. ", levels 10 to 11",
        "met twice: both times, the levels spanned")
    Eq(#lines, 2, "met twice: no repeats")

    local wenna = { t = now - 600, whoGuid = OTHER, who = "Wenna", what = "shared a camp", level = 10 }
    local stranger = { t = now - 500, level = 10 }
    title, lines = spec.tips({ M(tom), M(wenna), M(stranger) }, now)
    Eq(title, "With Old Tom, Wenna and someone", "several: each named once, a stranger last")
    Eq(lines[1], "Old Tom, fished off the pier", "several: whose line it is")
    Eq(lines[2], "Wenna, shared a camp", "several: each line once")
    Eq(lines[3], "Today at " .. Clock(tom.t) .. ", " .. Clock(wenna.t) .. " and " .. Clock(stranger.t)
        .. ", level 10", "several: every time, the level once")
    Eq(#lines, 3, "several: four lines at most")
end

--------------------------------------------------------------------------
Section("on the page, a person's strip")

ns.UI.ShowJournal()
ns.UI.SetJournalView("journey")
local page = ns.UI.JourneyPage()
local YourDiary = ns.UI.YourDiary

local function Open()
    J.Touch()
    ns.UI.RefreshJourneyPage(true)
    for i, e in ipairs(page.recap.entries) do
        if e.level == 10 then T.OpenDiaryPage(page, i) end
    end
end
local function Strip(name)
    for i = 1, page.notePool.used do
        local strip = page.notePool[i]
        if strip:IsShown() and strip.name:GetText() == name then return strip end
    end
end
local function Words()
    local all = {}
    for i = 1, page.captionPool.used do all[#all + 1] = page.captionPool[i]:GetText() or "" end
    return table.concat(all, " ")
end

do
    Open()
    Eq(page.state, "entries", "the page draws")
    Eq(page.metWritten, 1, "its strip is counted")
    Eq(page.notesWritten, 0, "and is no automatic person")
    local strip = Strip("with Old Tom")
    Check(strip ~= nil, "from the people's pool, with the name as written")
    Eq(strip:What(), "fished off the pier", "what you did, under it")
    Eq(strip.guid, nil, "no link")
    local plate = page.plates[1]
    Eq(plate.counts.acquaintances, 1, "its mark")
    Eq(plate.margin[1].kind, "met", "first in the margin")
    Check(not Words():find("Old Tom"), "the words do not name them again")
    Eq(strip.tip(), nil, "no tooltip where the strip holds the line")
    local title, lines = Met.Tip(plate.metMarks[1].list[1].met, now)
    Eq(title, "With Old Tom", "the mark's tooltip says who")
    Eq(lines[1], "fished off the pier", "and what")
end

local linked
do
    linked = Custom.Insert("met", { who = "Brannoc", whoGuid = GUID, what = "" }, WHERE)
    Eq(linked.whoGuid, GUID, "a picked name keeps its entry")
    Open()
    local strip = Strip("with Brannoc")
    Check(strip ~= nil, "a picked name's strip")
    Eq(strip.guid, GUID, "links as an automatic strip does")
    Eq(strip.onClick, YourDiary.ToPerson, "to their page")
    Eq(strip:What(), "", "an empty line is no line")
    Check(not Words():find("Brannoc"), "and is not named again")
    Eq(page.metWritten, 2, "a strip each")

    ns.db.characters[GUID].names = { { first = "Brannock", surname = "" } }
    Open()
    Check(Strip("with Brannock") ~= nil, "their current name, not the one written")
    Eq(linked.who, "Brannoc", "which stays as it was")
    ns.db.characters[GUID].names = { { first = "Brannoc", surname = "" } }

    local long = Custom.Insert("met", { who = "Long Line", what = ("word "):rep(40) }, WHERE)
    Eq(#long.what, 60, "the line is held to its length")
    Custom.Remove(long)
end

--------------------------------------------------------------------------
Section("the right click")

do
    Open()
    local strip = Strip("with Old Tom")
    local link = strip.link
    link.scripts.OnMouseUp(link, "RightButton")
    local view = YourDiary.CardSheet.View()
    Eq(view.kind, "met", "a right click on its strip opens its form")
    Eq(view.rec.customOf or view.rec, typed, "for its card")
    local rows = {}
    for _, row in ipairs(view.rows) do rows[row.field.key] = row end
    Eq(rows.who.box:GetText(), "Old Tom", "the name in its line")
    Eq(rows.what.box:GetText(), "fished off the pier", "the line in its")
    view.cancel.scripts.OnClick(view.cancel)

    -- A strip was this card a moment ago, and is someone else's now: the pool
    -- hands them out anew each laying, and an automatic strip takes no click.
    j.marks = { { kind = "fight", outcome = "lost", guid = OTHER, t = t0 + 10, mapID = MAP, x = 0.42, y = 0.40 } }
    Open()
    local person = Strip("with Wenna")
    Check(person ~= nil, "an automatic strip beside them")
    Eq(person.onRight, nil, "takes no right click of a card that had its strip")
    Check(Strip("with Old Tom").onRight ~= nil, "theirs still does")
    Check(Strip("with Brannoc").onRight ~= nil, "each of them")
    local count = page.notesWritten
    Eq(count, 1, "one automatic strip")

    -- Off this page, then a page with nothing of the kind: none keeps the click.
    local saved = j.custom
    j.custom = nil
    Open()
    Eq(page.metWritten, 0, "none written")
    for i = 1, page.notePool.used do
        Eq(page.notePool[i].onRight, nil, "no strip of the pool keeps it")
    end
    j.custom = saved
    j.marks = {}
end

--------------------------------------------------------------------------
Section("forgetting them")

do
    ns.ForgetEverywhere(GUID)
    Eq(linked.whoGuid, nil, "the link goes")
    Eq(linked.who, "Brannoc", "the name as written stays")
    Open()
    local strip = Strip("with Brannoc")
    Check(strip ~= nil, "on its strip")
    Eq(strip.guid, nil, "with no link")
end
