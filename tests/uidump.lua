-- Run from the addon folder:
--
--   /opt/homebrew/bin/luajit tests/uidump.lua > /tmp/uidump.txt
--
-- A snapshot of everything the UI draws, for refactors that must not change
-- how it looks. Nobody can look at the client from here, so the proof is a
-- diff: dump before, change the code, dump again, and every line that moved
-- has to be explained. Not part of run.lua: it checks nothing by itself.
--
-- It loads the addon into the mock as the tests do, seeds a diary (the
-- fixtures and /sd testdata's Tester Testerson), opens every surface in the
-- states worth seeing, and prints each widget on one line: where it hangs,
-- its layer, anchors, size, fill, texture coordinates, colours, font, text,
-- whether it is shown, and which scripts it has (from what wowmock.lua
-- records on `w.recorded`). Under each surface, every visible widget with an
-- OnEnter is hovered: what the tooltip said, and what changed on screen
-- while the mouse was over it and after it left. Menus print as trees.
--
-- All of it twice: once with every art file, class icon and atlas present,
-- once with none, so both sides of every fallback are drawn.

local here = (arg and arg[0] or "tests/uidump.lua"):match("^(.*)[/\\]") or "."
local root = here .. "/.."

local mock = dofile(here .. "/wowmock.lua")
DEFAULT_CHAT_FRAME.AddMessage = function() end

-- Today's date, where the addon asks for it without a time (the parcel's
-- postmark), is a fixed day, so two dumps either side of midnight compare.
local wallDate = _G.date
_G.date = function(format, time) return wallDate(format, time or 1791460000) end

-- LuaJIT seeds its string hash per process, so `pairs` order changes from
-- run to run, and the addon builds some frames in that order (the
-- medallion's two faces). Here `pairs` walks keys sorted, which is one of
-- the orders the client could take, and the same every run.
local nextKey = next
-- The dump's own walks sort where order matters, and need not pay for it.
local function Each(t) return nextKey, t, nil end
local function Before(a, b)
    local ta, tb = type(a), type(b)
    if ta ~= tb then return ta < tb end
    if ta == "number" or ta == "string" then return a < b end
    return tostring(a) < tostring(b)
end
function pairs(t)
    local keys = {}
    local k = nextKey(t)
    while k ~= nil do
        keys[#keys + 1] = k
        k = nextKey(t, k)
    end
    table.sort(keys, Before)
    local i = 0
    -- A key cleared while walking is skipped, as `next` would.
    return function()
        while true do
            i = i + 1
            local key = keys[i]
            if key == nil then return nil end
            if t[key] ~= nil then return key, t[key] end
        end
    end, t, nil
end

local out = {}
local function Out(line) out[#out + 1] = line end

--------------------------------------------------------------------------
-- Writing a widget down
--------------------------------------------------------------------------

local paths = {}

-- Paths by parent and per-type creation order ("Texture3"), with the global
-- name where there is one. Recomputed per dump: frames only ever append.
local function IndexPaths()
    paths = {}
    local counts = {}
    for _, w in ipairs(mock.frames) do
        local parent = w.parent
        local base = parent and paths[parent] or "root"
        counts[parent or "root"] = counts[parent or "root"] or {}
        local c = counts[parent or "root"]
        c[w.frameType] = (c[w.frameType] or 0) + 1
        local name = w.recorded.globalName and ("[" .. w.recorded.globalName .. "]") or ""
        paths[w] = base .. "/" .. w.frameType .. c[w.frameType] .. name
    end
end

local function Num(x)
    if x ~= x then return "nan" end
    if x == math.floor(x) and math.abs(x) < 1e15 then return ("%d"):format(x) end
    local s = ("%.6g"):format(x)
    if s == "-0" then s = "0" end
    return s
end

local Val
local function TableVal(t, depth)
    if t.recorded then return "<" .. (paths[t] or "?") .. ">" end
    if depth > 3 then return "{...}" end
    local keys = {}
    for k in Each(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = tostring(k) .. "=" .. Val(t[k], depth + 1) end
    return "{" .. table.concat(parts, ",") .. "}"
end

function Val(v, depth)
    local t = type(v)
    if t == "number" then return Num(v) end
    if t == "string" then return ("%q"):format(v):gsub("\\\n", "\\n") end
    if t == "table" then return TableVal(v, depth or 0) end
    if t == "function" then return "fn" end
    return tostring(v)
end

-- Colours given as r, g, b mean alpha 1.
local COLOURED = { SetTextColor = true, SetVertexColor = true, SetColorTexture = true,
    SetBackdropColor = true, SetBackdropBorderColor = true, SetShadowColor = true }

local function Args(args, method)
    local n = args.n
    while n > 0 and args[n] == nil do n = n - 1 end
    local parts = {}
    for i = 1, n do parts[i] = Val(args[i]) end
    if COLOURED[method] and n == 3 then parts[4] = "1" end
    return table.concat(parts, ",")
end

-- Anchors with the shorthand spelled out: SetPoint("LEFT", 4, 0) is
-- SetPoint("LEFT", parent, "LEFT", 4, 0). "^" is the parent.
local function Anchor(w, anchor)
    local a = anchor.args
    local rel, relPoint, x, y = w.parent, anchor.point, 0, 0
    if type(a[1]) == "number" then
        x, y = a[1], a[2] or 0
    elseif type(a[1]) == "table" then
        rel = a[1]
        if type(a[2]) == "string" then
            relPoint, x, y = a[2], a[3] or 0, a[4] or 0
        elseif type(a[2]) == "number" then
            x, y = a[2], a[3] or 0
        end
    elseif type(a[1]) == "string" then
        relPoint, x, y = a[1], a[2] or 0, a[3] or 0
    end
    local relName = rel == w.parent and "^" or (rel and ("<" .. (paths[rel] or "?") .. ">") or "nil")
    return ("%s %s %s %s %s"):format(anchor.point, relName, relPoint, Num(x), Num(y))
end

-- Methods drawn out above, or that leave nothing on screen.
local SKIP = { SetTexture = true, SetColorTexture = true, SetAtlas = true, Raise = true,
    StartMoving = true, StopMovingOrSizing = true, HighlightText = true, Insert = true,
    SetCursorPosition = true }

local function Shown(w)
    local told = w.recorded.toldShown
    if told == nil then return true end
    return told
end

local function KeysIn(w)
    local parent = w.parent
    if not parent then return "" end
    local keys = {}
    for k, v in Each(parent) do
        if v == w and type(k) == "string" then keys[#keys + 1] = k end
    end
    table.sort(keys)
    return #keys > 0 and (" @" .. table.concat(keys, ",")) or ""
end

local function Line(w)
    local rec = w.recorded
    local parts = { paths[w] .. KeysIn(w) }
    if rec.layer then parts[#parts + 1] = "layer=" .. rec.layer .. (rec.sublevel and (":" .. rec.sublevel) or "") end
    if w.template then parts[#parts + 1] = "template=" .. tostring(w.template) end
    parts[#parts + 1] = Shown(w) and "shown" or "hidden"

    if rec.width or rec.height then
        parts[#parts + 1] = "size=" .. (rec.width and Num(rec.width) or "-") .. "x" .. (rec.height and Num(rec.height) or "-")
    end
    local points = {}
    for _, anchor in ipairs(rec.points) do points[#points + 1] = Anchor(w, anchor) end
    table.sort(points)
    if #points > 0 then parts[#parts + 1] = "pts=[" .. table.concat(points, "; ") .. "]" end

    -- The fill is whichever of the overriding calls came last.
    local fill, fillName
    for _, method in ipairs({ "SetTexture", "SetColorTexture", "SetAtlas" }) do
        local args = rec.calls[method]
        if args and (not fill or args.seq > fill.seq) then fill, fillName = args, method end
    end
    if fill then
        parts[#parts + 1] = "fill=" .. fillName:sub(4) .. "(" .. Args(fill, fillName) .. ")"
    end
    local gradient = rec.calls.SetGradient
    if gradient and fill and gradient.seq < fill.seq then parts[#parts + 1] = "gradient<fill" end

    local font, colour = rec.calls.SetFontObject, rec.calls.SetTextColor
    if font and colour then
        parts[#parts + 1] = colour.seq > font.seq and "colour>font" or "colour<font"
    end

    local methods = {}
    for method in Each(rec.calls) do
        if not SKIP[method] then methods[#methods + 1] = method end
    end
    table.sort(methods)
    for _, method in ipairs(methods) do
        parts[#parts + 1] = method:gsub("^Set", "") .. "(" .. Args(rec.calls[method], method) .. ")"
    end

    if w.text ~= "" and w.text ~= nil then parts[#parts + 1] = "text=" .. Val(w.text) end

    local scripts = {}
    for key, fn in Each(w.scripts) do
        if fn then scripts[#scripts + 1] = key end
    end
    table.sort(scripts)
    if #scripts > 0 then parts[#parts + 1] = "scripts=" .. table.concat(scripts, ",") end

    return table.concat(parts, " ")
end

local function Under(w, top)
    while w do
        if w == top then return true end
        w = w.parent
    end
    return false
end

-- Every widget under `top`, in creation order: { path = line }, and the order.
local function Snapshot(top)
    local lines, order = {}, {}
    for _, w in ipairs(mock.frames) do
        if Under(w, top) then
            local path = paths[w]
            lines[path] = Line(w)
            order[#order + 1] = path
        end
    end
    return lines, order
end

local function Visible(w)
    while w do
        if not Shown(w) then return false end
        w = w.parent
    end
    return true
end

--------------------------------------------------------------------------
-- The tooltip and menus
--------------------------------------------------------------------------

local tip = {}
for _, method in ipairs({ "SetOwner", "SetText", "AddLine", "Show", "Hide", "ClearLines" }) do
    local original = GameTooltip[method]
    GameTooltip[method] = function(self, ...)
        tip[#tip + 1] = method .. "(" .. Args({ n = select("#", ...), ... }) .. ")"
        if original then return original(self, ...) end
    end
end

local function Changes(before, after)
    local list = {}
    for path, line in Each(after) do
        if before[path] ~= line then list[#list + 1] = line end
    end
    for path in Each(before) do
        if not after[path] then list[#list + 1] = "gone " .. path end
    end
    table.sort(list)
    return list
end

-- Hovers every visible widget under `top` that answers the mouse. The
-- changes are looked for under its parent: a hovered row may ink its
-- neighbours (the timeline's bracket).
local function Hover(top)
    for _, w in ipairs(mock.frames) do
        if Under(w, top) and w.scripts.OnEnter and Visible(w) then
            local scope = w.parent or w
            local before = Snapshot(scope)
            tip = {}
            w.scripts.OnEnter(w)
            local entered = tip
            local during = Changes(before, (Snapshot(scope)))
            tip = {}
            if w.scripts.OnLeave then w.scripts.OnLeave(w) end
            local left = tip
            local after = Changes(before, (Snapshot(scope)))

            Out("  hover " .. paths[w])
            Out("    tooltip: " .. table.concat(entered, " "))
            for _, line in ipairs(during) do Out("    over: " .. line) end
            Out("    left: " .. table.concat(left, " "))
            for _, line in ipairs(after) do Out("    after: " .. line) end
        end
    end
end

local function Dump(title, ...)
    IndexPaths()
    Out("### " .. title)
    for i = 1, select("#", ...) do
        local top = select(i, ...)
        if top then
            local lines, order = Snapshot(top)
            for _, path in ipairs(order) do Out(lines[path]) end
            Hover(top)
        else
            Out("(missing)")
        end
    end
end

local function MenuTree(node, depth)
    for _, child in ipairs(node.children) do
        local mark = ""
        if (child.kind == "radio" or child.kind == "checkbox") and child.a then
            mark = child.a() and " [x]" or " [ ]"
        end
        Out(("  %s%s %s%s"):format(("  "):rep(depth), child.kind, tostring(child.text), mark))
        MenuTree(child, depth + 1)
    end
end

local function DumpMenu(title)
    Out("### menu: " .. title)
    if mock.contextMenu then MenuTree(mock.contextMenu, 0) else Out("  (none)") end
    mock.contextMenu = nil
end

--------------------------------------------------------------------------
-- The run
--------------------------------------------------------------------------

local CLASSES = { "DRUID", "MAGE", "ROGUE", "SHAMAN", "WARRIOR", "PRIEST" }
local savedSettings = Settings

local function Run(art)
    mock.Reset()
    Out("########## " .. (art and "with art" or "without art"))

    if art then
        CLASS_ICON_TCOORDS = {}
        for i, class in ipairs(CLASSES) do CLASS_ICON_TCOORDS[class] = { 0, 0.25, (i - 1) * 0.125, i * 0.125 } end
        C_Texture = { GetAtlasInfo = function() return {} end }
        Settings = savedSettings
    else
        CLASS_ICON_TCOORDS, C_Texture = nil, nil
        setmetatable(mock.missingFiles, { __index = function() return true end })
        -- The settings page falls back to a panel of its own.
        Settings = nil
    end

    local F = dofile(here .. "/fixtures.lua")
    local ns = mock.LoadAddon(root)
    mock.SetUnit("player", F.SELF)

    -- The Social window, for the side tab: no native tabs of its own.
    local social = CreateFrame("Frame", "SocialUIFrame", UIParent)
    social.GetChildren = function() end

    mock.fire("ADDON_LOADED", ns.addonName)
    mock.fire("PLAYER_LOGIN")

    -- Mid-afternoon, so nothing straddles midnight.
    local today = ns.DayStart(1791000000)
    mock.now = today + 15 * 3600
    local now = mock.now
    local yesterday = ns.DayStart(today - 1)

    -- People.
    local function Person(def, extra)
        local info = { first = def.name[1], surname = def.name[2], level = def.level,
            faction = def.faction and def.faction[1], class = def.class and def.class[2],
            race = def.race and def.race[2], sex = def.sex }
        for k, v in Each(extra or {}) do info[k] = v end
        ns.Characters.Observe(def.guid, info)
        return def.guid
    end
    local A = Person(F.STRANGER)
    local B = Person(F.GARRICK)
    local C = Person(F.PUG)
    local NOCLASS = Person(F.STRANGER2)
    local HOSTILE = Person(F.HOSTILE)
    local FRIEND = Person(F.FRIEND)
    local LONG = "Player-4620-00EEEE01"
    ns.Characters.Observe(LONG, { first = "Bartholomewmaximilianus", surname = "Featherstonehaughingtonsmytherson",
        class = "WARRIOR", race = "Human", sex = 3, level = 33, faction = "Alliance" })

    ns.Diary.Add(A, { source = "test", tags = { "friend" }, relationship = "questing buddy",
        note = "helped me with Nagas" })
    ns.Diary.Add(B, { source = "test", tags = { "foe", "mapmaker" } })
    ns.Diary.Add(C, { source = "test" })
    ns.Diary.Add(NOCLASS, { source = "test" })
    ns.Diary.Add(LONG, { source = "test", tags = { "helper" } })

    ns.Interactions.Add(A, "trade", { time = now - 40 * ns.DAY,
        context = { given = { { link = "[Linen Cloth]", count = 5 } } } })
    ns.Interactions.Add(B, "whisper_in", { time = now - 3 * ns.DAY, excerpt = "hello there" })

    -- Heat on two maps, for the map tab and its menu.
    for i = 1, 6 do
        ns.Characters.Seen(A, { zone = "Mulgore", mapID = 1412, x = 0.3 + i * 0.02, y = 0.5 + i * 0.01 })
    end
    ns.Characters.Seen(A, { zone = "The Barrens", mapID = 1413, x = 0.5, y = 0.5 })
    ns.Characters.Seen(A, { zone = "Mulgore", mapID = 1412, x = 0.42, y = 0.61 })

    -- Sightings, for Recently nearby: a stranger seen two days, a hostile, a
    -- diary entry, someone with no class, someone only yesterday.
    local MULGORE = { mapID = 1412, x = 0.4, y = 0.6 }
    local BARRENS = { mapID = 1413, x = 0.5, y = 0.5 }
    ns.Sightings.Record(FRIEND, { level = 11, source = "plate" }, MULGORE, yesterday + 20 * 3600)
    ns.Sightings.Record(C, { level = 10, source = "plate" }, MULGORE, yesterday + 21 * 3600)
    ns.Sightings.Record(FRIEND, { level = 12, source = "plate" }, BARRENS, today + 14 * 3600 + 600)
    ns.Sightings.Record(HOSTILE, { level = 5, hostile = true, source = "target" }, MULGORE, today + 13 * 3600 + 44 * 60)
    ns.Sightings.Record(A, { level = 12, source = "plate" }, MULGORE, today + 13 * 3600)
    ns.Sightings.Record(NOCLASS, { level = 20, source = "say" }, { zone = "Restricted Place" }, today + 9 * 3600)
    ns.Interactions.Add(FRIEND, "trade", { time = today + 14 * 3600 })

    local TESTER = ns.TestData.GUID
    ns.TestData.Write(now)

    ----------------------------------------------------------------------
    -- The journal: People, a timeline with a dungeon run and open episodes

    ns.UI.ShowJournal(TESTER)
    local J = SocialDiaryJournalFrame
    local P = J.profile
    Dump("journal: people, Tester on the timeline", J)

    -- Open every episode that folds something away, as a click would.
    local opened = {}
    local IsEpisode = ns.UI.TimelineText.IsEpisode
    local function NextClosed()
        for _, line in ipairs(P.timeline.data) do
            local item = line.item
            if item and IsEpisode(item) and item.hidden > 0 and not opened[item.key] then return line end
        end
    end
    for _ = 1, 10 do
        local line = NextClosed()
        if not line then break end
        opened[line.item.key] = true
        P.timeline.rows[1].scripts.OnMouseUp({ item = line })
    end
    Dump("profile: episodes open", P)

    -- Scrolled to the first open bracket, and to the first dungeon run.
    local bracketAt, visitAt
    for i, line in ipairs(P.timeline.data) do
        if line.bracket and not bracketAt then bracketAt = i end
        if line.bracket and line.visit and not visitAt then visitAt = i end
    end
    if bracketAt then
        P.timeline:SetOffset(bracketAt - 2)
        Dump("profile: scrolled to an open bracket", P.timeline)
    end
    if visitAt then
        P.timeline:SetOffset(visitAt - 2)
        Dump("profile: scrolled to a run inside a bracket", P.timeline)
    end
    P.timeline:SetOffset(0)

    -- The map tab: Tester was never seen on a map, Bram on two. The map
    -- menu, the other map, and everyone's map.
    P.tabMap:Click()
    Dump("profile: map, nobody seen", P)
    ns.UI.SelectPerson(A)
    Dump("profile: map", P)
    P.map.mapButton:Click()
    DumpMenu("map")
    mock.MenuClick("The Barrens (1)")
    Dump("profile: map, the other map", P.map)
    P.map.everyoneButton:Click()
    Dump("profile: map, everyone", P.map)
    P.map.themButton:Click()
    P.tabStory:Click()
    ns.UI.SelectPerson(TESTER)

    -- The note tab (DIA-11): a new note, the Link others card, searching
    -- it, the note with Bram linked, and a test note opened to change.
    P.tabNote:Click()
    Dump("profile: a new note", P.noteSheet)
    P.noteSheet.link:Click()
    local L = P.noteSheet.picker
    Dump("profile: link others", L)
    for _, row in ipairs(L.list.rows) do
        if row:IsShown() and row.guid == A then row:Click() end
    end
    L.search:SetText("gal")
    L.search:GetScript("OnTextChanged")(L.search)
    Dump("profile: link others, Bram linked, searching", L)
    L.done:Click()
    Dump("profile: a new note, Bram linked", P.noteSheet)
    P.noteSheet.cancel:Click()
    ns.UI.Journal.EditNote(ns.Notes.For(TESTER)[1])
    Dump("profile: a note to change", P.noteSheet)
    P.noteSheet.cancel:Click()

    -- Writing mode, and the lines' hints as they take the cursor and text.
    P.edit:Click()
    Dump("profile: edit mode", P)
    local form = P.form
    for _, box in ipairs({ form.note, form.relationship, form.addTag }) do
        box:SetFocus()
        box.scripts.OnEditFocusGained(box)
    end
    Dump("profile: edit mode, every line focused", form)
    form.addTag:SetText("new")
    form.addTag.scripts.OnTextChanged(form.addTag)
    Dump("profile: edit mode, typing a tag", form)
    form.addTag:SetText("")
    form.addTag.scripts.OnTextChanged(form.addTag)
    for _, box in ipairs({ form.note, form.relationship, form.addTag }) do
        box:ClearFocus()
        box.scripts.OnEditFocusLost(box)
    end
    Dump("profile: edit mode, focus gone", form)
    P.form.done:Click()

    -- Someone else: tags, a custom tag in the form, a long name.
    ns.UI.SelectPerson(B)
    Dump("profile: Garrick", P)
    P.edit:Click()
    Dump("profile: Garrick, edit mode", P)
    P.form.done:Click()
    ns.UI.SelectPerson(LONG)
    Dump("profile: a long name", P)
    ns.UI.SelectPerson(NOCLASS)
    Dump("profile: no class", P)

    -- The list's menus, a search, and nobody selected.
    J.sortButton:Click()
    DumpMenu("sort")
    J.filterButton:Click()
    DumpMenu("filter")
    J.filterButton:Click()
    mock.MenuClick("Tag", "friend")
    J.filterButton:Click()
    DumpMenu("filter, tag friend")
    mock.MenuClick("Clear filters")
    J.search:SetText("ba")
    J.search.scripts.OnTextChanged(J.search)
    Dump("people: searching", J.views.people)
    J.search:SetText("")
    J.search.scripts.OnTextChanged(J.search)
    ns.UI.SelectPerson(nil)
    Dump("people: nobody selected", J.views.people)

    ----------------------------------------------------------------------
    -- Recently nearby

    ns.UI.SetJournalView("nearby")
    local NP = ns.UI.NearbyPage
    Dump("nearby: today", J)
    for _, row in ipairs(NP.days.rows) do
        if row:IsShown() and row.item and row.item.start == yesterday then row:Click() end
    end
    Dump("nearby: yesterday chosen", J.views.nearby)
    for _, row in ipairs(NP.days.rows) do
        if row:IsShown() and row.item and row.item.start == today then row:Click() end
    end
    for _, row in ipairs(NP.table.rows) do
        if row:IsShown() and row.item and row.item.guid == HOSTILE then row.add:Click() end
    end
    Dump("nearby: someone just added", J.views.nearby)
    NP.search:SetFocus()
    Dump("nearby: search focused", NP.search)
    NP.search:SetText("mul")
    NP.search.scripts.OnTextChanged(NP.search)
    Dump("nearby: searching", J.views.nearby)
    NP.search:ClearFocus()
    NP.search:SetText("")
    NP.search.scripts.OnTextChanged(NP.search)
    NP.filter:Click()
    DumpMenu("nearby filter")
    NP.headings.name:Click()
    NP.headings.name:Click()
    Dump("nearby: by name, descending", J.views.nearby)
    NP.headings.name:Click()

    ----------------------------------------------------------------------
    -- Your Diary on /sd testdata's road: the newest level's plates, the
    -- level with the most plates, a zone's full page, and laid flat

    ns.UI.SetJournalView("journey")
    Dump("your diary: the newest level", J.views.journey)
    local JP = ns.UI.JourneyPage()
    if JP.recap then
        local most, at = JP.layout or 0, JP.open
        for i = #JP.recap.entries, 1, -1 do
            JP.open = i
            ns.UI.RedrawJourneyPage()
            if (JP.layout or 0) > most then most, at = JP.layout, i end
        end
        JP.open = at
        ns.UI.RedrawJourneyPage()
        Dump("your diary: a level of " .. most .. " plate(s)", J.views.journey)
        local first = JP.recap.zones[1]
        if first then
            ns.UI.OpenZoneSheet(first.mapID)
            Dump("your diary: a zone's full page", J.views.journey)
        end
        ns.SetSetting("flatSheets", true)
        ns.UI.RedrawJourneyPage()
        Dump("your diary: flat paper", J.views.journey)
        ns.SetSetting("flatSheets", false)
        -- SD_UIDUMP_ENTRIES=all: every level's and week's plates, and every
        -- zone's full page, for a refactor of the plates themselves (the
        -- pages above are only a sample of them).
        if os.getenv("SD_UIDUMP_ENTRIES") == "all" then
            for i = 1, #JP.recap.entries do
                JP.open, JP.mode = i, "plates"
                ns.UI.RedrawJourneyPage()
                local e = JP.recap.entries[i]
                Dump("your diary: entry " .. i .. " (" .. tostring(e.level or e.week) .. ")", J.views.journey)
            end
            for _, zone in ipairs(JP.recap.zones) do
                ns.UI.OpenZoneSheet(zone.mapID)
                Dump("your diary: the full page of " .. tostring(zone.mapID), J.views.journey)
            end
        end
    end
    ns.UI.SetJournalView("people")

    ----------------------------------------------------------------------
    -- The loose sheet, the picker, settings, the toast, the tooltip

    ns.UI.CloseJournal()
    ns.UI.ShowEntry(TESTER)
    local sheet = SocialDiaryEntryFrame
    Dump("sheet: Tester", sheet)
    ns.UI.ShowEntry(LONG)
    Dump("sheet: a long name", sheet)

    -- The grain follows /sd art grain, on the book and on the sheet.
    ns.Style.SetGrain(50)
    Dump("grain at 50: sheet", sheet)
    ns.UI.ShowJournal()
    Dump("grain at 50: book", J.book)
    ns.Style.SetGrain(100)
    ns.UI.CloseJournal()
    sheet:Hide()

    mock.SetUnit("target", F.PUG)
    mock.SetUnit("mouseover", F.STRANGER)
    ns.UI.ShowPicker()
    Dump("picker", SocialDiaryPickerFrame)
    ns.UI.ClosePicker()

    ns.UI.ShowSettings()
    Dump("settings", ns.UI.SettingsPage())

    ns.UI.Reunion(A, "group")
    Dump("reunion toast", SocialDiaryToastFrame)

    ns.db.settings.introSeen = false
    ns.db.settings.parcelOpened = false
    ns.UI.OfferSlip()
    Dump("parcel, wrapped", SocialDiaryIntroFrame)
    ns.UI.Slip():Tear()
    Dump("parcel, torn", SocialDiaryIntroFrame)
    ns.UI.ShowIntro()
    Dump("introduction's tour", J.book)
    ns.UI.CloseJournal()

    Dump("social tab", social)

    ns.db.settings.tooltipSeen = true
    for _, guid in ipairs({ A, B, FRIEND, NOCLASS }) do
        Out("### unit tooltip " .. guid)
        for _, line in ipairs(mock.UnitTooltip(guid)) do Out("  " .. Val(line)) end
    end

    IndexPaths()
    Out("### fonts")
    for _, w in ipairs(mock.frames) do
        if w.frameType == "Font" then Out(Line(w)) end
    end
end

Run(true)
Run(false)
Settings = savedSettings

io.write(table.concat(out, "\n"), "\n")
