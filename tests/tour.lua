-- The introduction's tour (UI/Windows/Intro/Tour.lua, the spec
-- .claude/ui-proposal/HANDOFF-intro-tour.md): the loose sheet's five steps,
-- the ending on Thex's real page, and every way out. Each way out marks the
-- introduction seen and leaves no Thex behind, and nothing but `introSeen`
-- of the saved files changes. The account migration from frontRead is
-- tests/sample.lua's; the parcel and the entry points' wiring,
-- tests/settings.lua's.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local Tour, Sample, J = ns.UI.Tour, ns.Sample, ns.UI.Journal
local GUID = Sample.GUID

-- A deep copy, and the first place two tables differ (nil when equal),
-- `skip` a key left out of the comparison wherever it is.
local function Copy(v)
    if type(v) ~= "table" then return v end
    local c = {}
    for k, x in pairs(v) do c[Copy(k)] = Copy(x) end
    return c
end
local function Diff(a, b, skip, path)
    path = path or ""
    if type(a) ~= type(b) then return path .. ": " .. tostring(a) .. " vs " .. tostring(b) end
    if type(a) ~= "table" then
        if a ~= b then return path .. ": " .. tostring(a) .. " vs " .. tostring(b) end
        return nil
    end
    for k, x in pairs(a) do
        if k ~= skip then
            local d = Diff(x, b[k], skip, path .. "." .. tostring(k))
            if d then return d end
        end
    end
    for k, y in pairs(b) do
        if k ~= skip and a[k] == nil then return path .. "." .. tostring(k) .. ": nil vs " .. tostring(y) end
    end
    return nil
end

-- The sounds played, by their keys (Style.SOUNDS).
local sounds = {}
local play = ns.Style.PlaySound
ns.Style.PlaySound = function(key, ...)
    sounds[#sounds + 1] = key
    return play(key, ...)
end
local function Played(key)
    for _, k in ipairs(sounds) do
        if k == key then return true end
    end
    return false
end

-- Someone real in the diary, whom the example must hide.
mock.SetUnit("target", F.STRANGER)
ns.Diary.Add(F.STRANGER.guid, { unit = "target", source = "test" })
mock.SetUnit("target", nil)
ns.Sessions.Close(ns.Sessions.Current(), mock.now)

-- The saved files as they were before a tour, `introSeen` aside, and the
-- hints' record: the book opening is counted there (Core/Hints.lua), which
-- is the book's doing, not the tour's.
local before
local function Snapshot()
    ns.db.settings.introSeen = false
    SocialDiaryDB.hints.opens = 0
    before = { Copy(SocialDiaryDB), Copy(SocialDiaryCharDB) }
end
local function Unchanged(what)
    SocialDiaryDB.hints.opens = 0
    Eq(Diff(before[1], SocialDiaryDB, "introSeen"), nil, what .. ": the account file changed")
    Eq(Diff(before[2], SocialDiaryCharDB, "introSeen"), nil, what .. ": the character's file changed")
end
-- What every way out leaves: seen, no Thex, nothing else written.
local function Out(what)
    Eq(ns.db.settings.introSeen, true, what .. ": not marked seen")
    Eq(Sample.Present(), false, what .. ": Thex was left in the diary")
    Eq(Tour.step, nil, what .. ": the sheet is still out")
    Eq(Tour.example, nil, what .. ": the example is still up")
    Eq(J.query.search, "", what .. ": the search was not cleared")
    Unchanged(what)
end

local function Begin()
    Snapshot()
    ns.UI.ShowIntro()
    Tour.Finish()
end

-- Through the steps to `n`, each entrance finished.
local function To(n)
    while Tour.step < n do
        if Tour.step < 4 then Tour.strips.step.foot:Click() else Tour.strips.thex.aside:Click() end
        Tour.Finish()
    end
end

-- How many leaders and arrows show.
local function Shown()
    local leaders, arrows = 0, 0
    for key, line in pairs(Tour.lines) do
        local on = false
        for _, t in ipairs(line.shown or {}) do on = on or t:IsShown() end
        if on then
            if key == "add" or key == "name" then arrows = arrows + 1 else leaders = leaders + 1 end
        end
    end
    return leaders, arrows
end

-- Whether a frame or region would show in the client: nothing up its
-- parents told to hide (the mock starts every frame hidden, the client
-- shown, so only what was hidden counts), and none at alpha 0.
local function Visible(region)
    local f = region
    while f do
        if f.recorded and f.recorded.toldShown == false then return false end
        if f.GetAlpha and f:GetAlpha() <= 0 then return false end
        f = f.parent
    end
    return true
end
-- How many of a layer's textures show, each with ink (alpha over 0).
local function Inked(layer)
    local n = 0
    for _, each in ipairs(layer.list) do
        if Visible(each.texture) and (each.prim.a or 0) > 0 then n = n + 1 end
    end
    return n
end
-- Every string on the tour's strips and sheet, for the glyph check: the
-- fonts (Friz Quadrata, Neuton) have plain ASCII and the curly apostrophe,
-- and no arrows.
local function Glyphs(text, what)
    local rest = (text or ""):gsub("\226\128\153", "")
    Check(not rest:find("[\128-\255]"), what .. " has a glyph the fonts may lack: " .. tostring(text))
end
local function StripGlyphs(strip, what)
    Glyphs(strip.name:GetText(), what .. "'s name")
    Glyphs(strip:What(), what .. "'s words")
    if strip.foot then Glyphs(strip.foot.label:GetText(), what .. "'s foot") end
    if strip.aside then Glyphs(strip.aside.label:GetText(), what .. "'s link") end
end

--------------------------------------------------------------------------
Section("the sheet laid at step 1")

ns.UI.CloseJournal()
Begin()
local host, view = Tour.host, Tour.view
Check(_G.SocialDiaryJournalFrame:IsShown(), "the book did not open")
Eq(ns.UI.JournalView(), "journey", "the tour does not lie on Your Diary")
Eq(Tour.step, 1, "the tour did not start at its first step")
Check(host:IsShown() and view:IsShown(), "the sheet is not on the book")
Check(Played("sheetOpen"), "laying the sheet did not rustle")
Eq(ns.db.settings.introSeen, false, "laying the sheet counted as seeing it")
Eq(Tour.strips.step.foot.label:GetText(), "Continue", "step 1's foot is not Continue")
-- Its arrow is drawn: the fonts have no "→".
for _, t in ipairs(Tour.strips.step.foot.arrow or {}) do Check(t:IsShown(), "Continue's arrow is not drawn") end
Eq(#(Tour.strips.step.foot.arrow or {}), 3, "Continue has no drawn arrow")
Eq(Tour.progress.count:GetText(), "1 of 5", "the progress does not say 1 of 5")

-- Escape is the sheet's while it is out, in the book's place.
local escape = {}
for _, name in ipairs(UISpecialFrames) do escape[name] = true end
Check(escape.SocialDiaryIntroTour and not escape.SocialDiaryJournalFrame, "Escape is not the sheet's")

-- The plate: Your Diary's one-plate slot, no map, the made-up ink on its
-- layers, its marks drawn.
local plate = Tour.plate
Eq(plate.hasArt, false, "the tour's plate printed map art")
Check(#Tour.layers.roadA.textures > 10, "the road was not inked")
Check(#Tour.layers.roadB.textures > 10 and #Tour.layers.pool.textures > 10, "version B's road and pool not inked")
for _, key in ipairs({ "wash", "dab", "rim" }) do
    Check(#Tour.layers.pool.parts[key] > 0, "the pool has no " .. key)
end
Check(Tour.layers.roadA.frame:IsShown() and not Tour.layers.pool.frame:IsShown(), "step 1 shows the wrong layers")
Eq(Tour.layers.pin7.number:GetText(), "7", "pin 7 has no number")

-- The plate shows, on the sheet's paper and inside it, under the strips and
-- the leaders (2 Nov 2026, in the client: it was left hidden). Its card,
-- road and pins are drawn and show at the end of step 1.
Check(Visible(plate) and Visible(plate.sheet), "the plate is hidden")
local sheetLevel = view.sheet:GetFrameLevel()
Check(plate:GetFrameLevel() > sheetLevel, "the plate lies under the sheet's paper")
Check(Tour.strips.step:GetFrameLevel() > plate.over:GetFrameLevel(), "the strips lie under the plate")
local s = plate.slot
Check(s.x >= 0 and s.y >= 0 and s.x + s.w <= Tour.SHEET.w and s.y + s.h <= Tour.SHEET.h,
    ("the plate lies off the sheet: %d, %d, %d by %d"):format(s.x, s.y, s.w, s.h))
Check(plate.counts.textures > 0, "the plate's card has nothing drawn")
Check(Inked(Tour.layers.roadA) == #Tour.layers.roadA.list, "step 1's road does not all show in ink")
for _, key in ipairs({ "pin6", "pin7" }) do
    Check(Visible(Tour.layers[key].frame) and Tour.layers[key].marks.ink.used > 0, key .. " is not on the plate")
end
StripGlyphs(Tour.strips.step, "step 1's strip")

-- No fold through a strip: every fold clear of every strip's box.
local X, Y, folds = Tour.K.Lines()
for _, b in pairs(Tour.boxes) do
    for k in pairs(folds.columns) do
        Check(X[k] < b.x or X[k] > b.x + b.w, ("a fold at x %.1f cuts a strip (%d to %d)"):format(X[k], b.x, b.x + b.w))
    end
    for k in pairs(folds.rows) do
        Check(Y[k] < b.y or Y[k] > b.y + b.h, ("a fold at y %.1f cuts a strip (%d to %d)"):format(Y[k], b.y, b.y + b.h))
    end
end

--------------------------------------------------------------------------
Section("the steps and their lines")

local leaders, arrows = Shown()
Eq(leaders .. "/" .. arrows, "1/0", "step 1's lines")
local WANT = { "1/0", "2/0", "2/0", "1/1", "1/1" }
for n = 2, 5 do
    sounds = {}
    To(n)
    StripGlyphs(Tour.strips.step, "step " .. n .. "'s strip")
    if n >= 3 then StripGlyphs(Tour.strips.thex, "Thex's strip at step " .. n) end
    if n == 2 then
        -- The pool and the road under it show in ink, the pouch is drawn,
        -- and the find card's box is at the card's own strength.
        Check(Inked(Tour.layers.pool) == #Tour.layers.pool.list, "step 2's pool does not all show")
        Check(Inked(Tour.layers.roadB) == #Tour.layers.roadB.list, "step 2's road does not all show")
        Check(Tour.layers.pouch.marks.ink.used > 0, "the pouch is not on the plate")
        Eq(Tour.strips.find.fade, 1, "the find card's box is not at full strength")
        -- A fight's pool: read as fighting from what was done there, in
        -- the trail's rust.
        Eq(Tour.poolKind, "fighting", "the pool is not a fight's")
        Eq(Tour.poolTint, ns.UI.InkTrail.TINT.fighting, "the pool is not in the fight's rust")
    elseif n == 3 then
        for _, key in ipairs({ "bram", "thex" }) do
            Check(Visible(Tour.layers[key].frame) and Tour.layers[key].marks.ink.used > 0, key .. "'s ring is not drawn")
        end
        -- Bram's card: a witness's, saved you from Hogger, a stranger's (no
        -- page), shown at full strength; nothing of it saved.
        local bram = Tour.strips.bram
        Check(Visible(bram), "Bram's card is hidden")
        Eq(bram:GetAlpha(), 1, "Bram's card is not at full strength")
        Eq(bram:Deed(), "saved you", "Bram's card is not a rescue")
        Eq(bram:Foe(), "from Hogger", "Bram's card does not name Hogger")
        Eq(bram.guid, nil, "Bram's card opens a page")
        Eq(bram.name:GetText(), "Bram Redfen", "Bram's card does not name him")
        Check(Tour.layers.bram.marks.ink.used + Tour.layers.bram.marks.inner.used + Tour.layers.bram.marks.halo.used > 0,
            "the rescue's mark is not drawn")
        -- Laid back, the find card's box (its wash multiplied in, which a
        -- frame's alpha does not reach) fades with it.
        Eq(Tour.strips.find.fade, Tour.BACK, "the find card's box is not laid back with the card")
    end
    Eq(Tour.step, n, "not at step " .. n)
    Eq(Tour.progress.count:GetText(), n .. " of 5", "step " .. n .. "'s progress")
    leaders, arrows = Shown()
    Eq(leaders .. "/" .. arrows, WANT[n], "step " .. n .. "'s lines")
    Check(leaders <= 2 and arrows <= 1, "too many lines on step " .. n)
end
Check(Played("write"), "+ Add did not sound as writing")
Eq(Sample.Present(), false, "+ Add wrote Thex")
Unchanged("+ Add")

-- Step 3's words name the live retention; step 4 and 5 end in an
-- instruction, not a link.
Check(Tour.STEPS[3].words():find(ns.UI.Journal.PencilDays(), 1, true), "step 3 does not name the retention")
Check(not Tour.strips.step.foot:IsShown(), "an instruction takes clicks")
-- Laid back at step 5: road, pins, pool and Bram at .32; Thex at full.
Eq(Tour.layers.roadB.frame:GetAlpha(), Tour.BACK, "the road is not laid back")
Eq(Tour.layers.bram.frame:GetAlpha(), Tour.BACK, "Bram's mark is not laid back")
Eq(Tour.strips.bram:GetAlpha(), Tour.BACK, "Bram's card is not laid back")
Eq(Tour.layers.thex.frame:GetAlpha(), 1, "Thex's ring is laid back")
Check(Tour.strips.thex.blot:IsShown(), "Thex's blot did not stay")
Eq(Tour.strips.thex.guid, GUID, "Thex's strip is not a link")

--------------------------------------------------------------------------
Section("the progress marks: back to a step, shown complete")

Tour.progress.marks[2].button:Click()
Eq(Tour.step, 2, "a passed mark did not go back to its step")
Eq(host.scripts.OnUpdate, nil, "a step gone back to plays its entrance")
Eq(Tour.layers.pool.frame:GetAlpha(), 1, "the step gone back to is not at full strength")
Check(Tour.strips.find:IsShown(), "the find card is not on the step gone back to")
Check(not Tour.progress.marks[3].button:IsShown(), "a mark to come takes clicks")
Tour.progress.marks[4].button:Click()
Eq(Tour.step, 2, "a mark to come was followed")
To(5)

--------------------------------------------------------------------------
Section("the ending: Thex on the People page, then begin")

sounds = {}
Tour.strips.thex.link:Click()
Eq(Tour.step, nil, "the sheet stayed out")
Check(not host:IsShown(), "the sheet was not put away")
Eq(Sample.Present(), true, "Thex was not written")
Eq(ns.UI.JournalView(), "people", "the book did not turn to People")
Eq(J.selected, GUID, "Thex is not selected")
Eq(J.query.search, Sample.NAME, "the search is not his name")
Eq(J.journal.search:GetText(), Sample.NAME, "the search box does not show his name")
-- His strip on the sheet said what his page says: 35 minutes together.
local together
for _, session in pairs(ns.db.sessions) do
    if session.sample and session.participants[GUID] then together = session.participants[GUID].seconds end
end
Eq(together, 35 * 60, "Thex's written time together is not the strip's")
Eq(Tour.strips.thex:What(), ns.UI.Format.Duration(together) .. " together", "Thex's strip on the sheet")
local list = ns.People.Query(J.query)
Eq(#list, 1, "more than Thex in the list")
Eq(list[1].guid, GUID, "the one in the list is not Thex")
Check(Tour.endStrip:IsShown(), "no ending strip")
Eq(Tour.endStrip.foot.label:GetText(), "Begin your own diary", "the ending strip's link")
Eq(#(Tour.endStrip.foot.arrow or {}), 3, "Begin your own diary has no drawn arrow")
Check(Played("sheetClose") and Played("pageTurn"), "the ending made no sound of the sheet and the page")
Eq(ns.db.settings.introSeen, true, "the example is not counted seen")
for key, v in pairs(escape) do Check(v ~= nil, key) end
escape = {}
for _, name in ipairs(UISpecialFrames) do escape[name] = true end
Check(escape.SocialDiaryJournalFrame and not escape.SocialDiaryIntroTour, "Escape was not given back to the book")

Tour.endStrip.foot:Click()
Eq(ns.UI.JournalView(), "journey", "Begin did not turn to Your Diary")
Check(not Tour.endStrip:IsShown(), "the ending strip stayed")
Eq(J.selected, nil, "Thex is still selected")
Out("Begin your own diary")
Eq(#ns.People.Query(J.query), 1, "the real person did not come back to the list")

--------------------------------------------------------------------------
Section("every way out of the sheet")

local WAYS = {
    { "a click beside it", function() view.onPutAway("LeftButton") end },
    { "Escape", function()
        for _, name in ipairs(UISpecialFrames) do
            local frame = _G[name]
            if frame and frame:IsShown() then
                frame:Hide()
                return
            end
        end
    end },
    { "the book closed", function() ns.UI.CloseJournal() end },
    { "a ribbon", function() J.journal.ribbons.nearby:Click() end },
    { "a fight", function()
        mock.inCombat = true
        mock.fire("PLAYER_REGEN_DISABLED")
        mock.inCombat = false
    end },
}
for n = 1, 5 do
    for _, way in ipairs(WAYS) do
        Begin()
        To(n)
        way[2]()
        Out(way[1] .. " at step " .. n)
        if way[1] == "a click beside it" or way[1] == "Escape" then
            Check(_G.SocialDiaryJournalFrame:IsShown(), way[1] .. " closed the book")
            Eq(ns.UI.JournalView(), "journey", way[1] .. " turned the book")
        end
    end
end
-- Never laid in a fight.
ns.UI.CloseJournal()
mock.inCombat = true
ns.db.settings.introSeen = false
ns.UI.ShowIntro()
Eq(Tour.step, nil, "the tour was laid in a fight")
Eq(ns.UI.JournalView(), "journey", "the book did not open on Your Diary in a fight")
mock.inCombat = false
ns.UI.CloseJournal()
ns.db.settings.introSeen = true

-- Escape takes the sheet only, then the book.
Begin()
WAYS[2][2]()
Check(_G.SocialDiaryJournalFrame:IsShown(), "Escape closed the book under the sheet")
WAYS[2][2]()
Check(not _G.SocialDiaryJournalFrame:IsShown(), "the next Escape did not close the book")

--------------------------------------------------------------------------
Section("every way out of the example")

local function Example()
    Begin()
    To(5)
    Tour.strips.thex.link:Click()
    Eq(Sample.Present(), true, "setup: Thex was not written")
end
for _, way in ipairs({
    { "the book closed", function() ns.UI.CloseJournal() end },
    { "a ribbon", function() J.journal.ribbons.journey:Click() end },
    { "Escape", WAYS[2][2] },
    { "a fight", WAYS[5][2] },
    { "the introduction again", function() ns.UI.ShowIntro() end },
}) do
    Example()
    way[2]()
    if way[1] == "the introduction again" then
        Eq(Tour.step, 1, "the introduction again did not lay the sheet")
        Eq(Sample.Present(), false, "the introduction again kept Thex")
        view.onPutAway("LeftButton")
    end
    Out("the example left by " .. way[1])
    Check(not Tour.endStrip:IsShown(), way[1] .. " left the ending strip")
end

-- Filters set before the tour come back after it, and none hid Thex.
ns.UI.ShowJournal()
J.query.faction = "Alliance"
Example()
Eq(J.query.faction, nil, "a filter hid Thex")
Eq(#ns.People.Query(J.query), 1, "Thex not alone in the list")
Tour.endStrip.foot:Click()
Eq(J.query.faction, "Alliance", "the filter did not come back")
J.query.faction = nil

--------------------------------------------------------------------------
Section("a /reload in the middle of the example")

Example()
local account, character = Copy(SocialDiaryDB), Copy(SocialDiaryCharDB)
mock.Reset()
_G.SocialDiaryDB, _G.SocialDiaryCharDB = account, character
ns = T.Load()
mock.SetUnit("player", F.SELF)
mock.fire("ADDON_LOADED", ns.addonName)
Eq(ns.Sample.Present(), false, "a reload left Thex in the diary")
Eq(ns.Setting("introSeen"), true, "a reload in the example is not counted seen")
Eq(Diff(before[1], SocialDiaryDB, "introSeen"), nil, "a reload's account file differs")
Tour, Sample, J = ns.UI.Tour, ns.Sample, ns.UI.Journal

--------------------------------------------------------------------------
Section("motion: entrances, a click finishing one, and flat paper")

mock.fire("PLAYER_LOGIN")
ns.db.settings.introSeen = false
ns.UI.ShowJournal()
Eq(Tour.step, 1, "the book opened unseen did not lay the tour")
host, view = Tour.host, Tour.view
Check(host.scripts.OnUpdate ~= nil, "step 1 has no entrance")
Check(view.arriving, "the sheet did not arrive")
-- Its first frame: the road not yet drawn, pin 7 not yet stamped; the
-- step's action already works.
Check(not Tour.layers.roadA.textures[1]:IsShown(), "the road shows before it is drawn")
Eq(Tour.layers.pin7.frame:GetAlpha(), 0, "pin 7 shows before it is stamped")
host.scripts.OnUpdate(host, 0.6)
Check(Tour.layers.roadA.textures[1]:IsShown(), "the road is not drawn as the pen goes")
Check(not Tour.layers.roadA.textures[#Tour.layers.roadA.textures]:IsShown(), "the road drawn all at once")
host.scripts.OnUpdate(host, 1)
Eq(host.scripts.OnUpdate, nil, "the entrance did not stop itself")
Eq(Tour.layers.pin7.frame:GetAlpha(), 1, "pin 7 was not stamped")
view.scripts.OnUpdate(view, 0.3)
Check(not view.arriving and view.scripts.OnUpdate == nil, "the sheet did not settle")

-- A click on the sheet finishes an entrance at once.
Tour.strips.step.foot:Click()
Check(host.scripts.OnUpdate ~= nil, "step 2 has no entrance")
Eq(Tour.strips.find:GetAlpha(), 0, "the find card is laid before its time")
Eq(Tour.strips.find.fade, 0, "the find card's box shows before the card")
-- The step strip says its words last: none yet, the old fading off.
Eq(Tour.strips.step.name:GetAlpha(), 0, "the step strip's words come in first")
Check(Tour.strips.ghost:IsShown(), "the old words are not over the new")
host.scripts.OnUpdate(host, 1.0)
Eq(Tour.strips.step.name:GetAlpha(), 0, "the step strip spoke before the card was laid")
Check(Tour.strips.find:GetAlpha() > 0.5, "the card is not laid by 1 s")
Check(not Tour.strips.ghost:IsShown(), "the old words stayed")
Tour.view.sheet.scripts.OnMouseDown(Tour.view.sheet, "LeftButton")
Eq(host.scripts.OnUpdate, nil, "a click did not finish the entrance")
Eq(Tour.strips.find:GetAlpha(), 1, "the find card is not laid once finished")
Eq(Tour.strips.find.fade, 1, "the find card's box is not at full strength once finished")
Eq(Tour.strips.step.name:GetAlpha(), 1, "the step strip's words are not said once finished")
Eq(Tour.layers.roadB.frame:GetAlpha(), Tour.BACK, "the road is not laid back once finished")
Check(not Tour.strips.ghost:IsShown(), "the old words stayed over the new")

-- Every entrance stops within its 1.5 s.
for n = 3, 5 do
    if Tour.step < 4 then Tour.strips.step.foot:Click() else Tour.strips.thex.aside:Click() end
    Eq(Tour.step, n, "setup: not at step " .. n)
    Check(host.scripts.OnUpdate ~= nil, "step " .. n .. " has no entrance")
    if n == 3 then
        Eq(Tour.strips.bram:GetAlpha(), 0, "Bram's card is laid before its time")
        host.scripts.OnUpdate(host, 0.6)
        local a = Tour.strips.bram:GetAlpha()
        Check(a > 0 and a < 1, "Bram's card does not fade in")
    elseif n == 4 then
        host.scripts.OnUpdate(host, 0.15)
        local a = Tour.strips.bram:GetAlpha()
        Check(a < 1 and a > Tour.BACK, "Bram's card is not laid back as the step comes in")
    end
    host.scripts.OnUpdate(host, 1.5)
    Eq(host.scripts.OnUpdate, nil, "step " .. n .. "'s entrance runs past 1.5 s")
end
view.onPutAway("LeftButton")

-- Flat paper only: nothing moves, every step is shown complete, and the
-- sheet lies straight.
ns.db.settings.flatSheets = true
ns.db.settings.introSeen = false
ns.UI.ShowIntro()
Eq(view.angle, 0, "the sheet is turned laid flat")
Check(not view.arriving and view.scripts.OnUpdate == nil, "the sheet arrives laid flat")
for n = 1, 5 do
    Eq(Tour.step, n, "flat: not at step " .. n)
    Eq(host.scripts.OnUpdate, nil, "flat: step " .. n .. " has an entrance")
    for _, strip in pairs(Tour.strips) do
        Eq(strip.scripts.OnUpdate, nil, "flat: a strip moves on step " .. n)
    end
    if n < 4 then Tour.strips.step.foot:Click() elseif n == 4 then Tour.strips.thex.aside:Click() end
end
Eq(Tour.layers.pool.frame:GetAlpha(), Tour.BACK, "flat: the pool is not laid back")
view.onPutAway("LeftButton")
ns.db.settings.flatSheets = false
Eq(ns.db.settings.introSeen, true, "flat: putting it away is not seeing it")
