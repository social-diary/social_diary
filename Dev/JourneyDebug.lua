-- Development tooling for Your Diary (8.11): what capture is doing right
-- now, the latest segments, the raw ring buffer (JRN-18) and what the route
-- weighs saved (JRN-19). For checking the compaction against what was
-- actually walked, in the client.
--
-- /sd journey [stats | segments [n] | raw | clear], and /sd pen for tuning
-- the road's fountain pen by eye (UI/Ink/Pen.lua's PEN). Registered as dev
-- commands, listed only while debug is on. Not part of a release: the TOC's
-- Dev/ block goes.

local addonName, ns = ...

local Journey = ns.Journey

local function Line(text, ...)
    DEFAULT_CHAT_FRAME:AddMessage("   " .. (select("#", ...) > 0 and text:format(...) or text))
end

local function MapName(mapID)
    return mapID and (ns.MapName(mapID) or ("map " .. mapID)) or "?"
end

local function Clock(t)
    return t and date("%d %b %H:%M:%S", t) or "-"
end

-- One segment in a line.
local function Describe(seg)
    local span = ns.UI.Format.Duration(seg.to - seg.from)
    local levels = seg.levelFrom == seg.levelTo and ("lvl %s"):format(tostring(seg.levelFrom))
        or ("lvl %s-%s"):format(tostring(seg.levelFrom), tostring(seg.levelTo))
    local head = ("%s  %-7s %-8s %s, %s"):format(Clock(seg.from), seg.kind, span, MapName(seg.mapID), levels)
    if seg.kind == "stop" then
        local act = {}
        for key, n in pairs(seg.act or {}) do act[#act + 1] = key .. " " .. n end
        table.sort(act)
        return ("%s  at %.3f, %.3f r %d yd%s%s"):format(head, seg.x or 0, seg.y or 0, seg.r or 0,
            seg.subZone and (" (" .. seg.subZone .. ")") or "", #act > 0 and ("  [" .. table.concat(act, ", ") .. "]") or "")
    elseif seg.kind == "road" then
        return ("%s  %d points"):format(head, #Journey.Points(seg) / 2)
    elseif seg.kind == "flight" then
        return ("%s  %s %.3f,%.3f -> %s %.3f,%.3f"):format(head, MapName(seg.mapID1), seg.x1 or 0, seg.y1 or 0,
            MapName(seg.mapID2), seg.x2 or 0, seg.y2 or 0)
    end
    return ("%s  %s (%s), %s inside, entry %s"):format(head, tostring(seg.name), tostring(seg.instanceID),
        ns.UI.Format.Duration(seg.seconds or 0), seg.x and ("%.3f, %.3f"):format(seg.x, seg.y) or "unknown")
end

-- What is being built right now.
local function Open(j)
    local o = j.open or {}
    if o.taxi then
        Line("on a taxi since %s, from %s", Clock(o.taxi.t), MapName(o.taxi.mapID))
    end
    if o.dungeon then
        Line("in %s since %s, %s inside", tostring(o.dungeon.name), Clock(o.dungeon.from),
            ns.UI.Format.Duration(o.dungeon.seconds or 0))
    end
    local c = o.c
    if c and c.stop then
        Line("staying (a stop) since %s, %s, %s%s", Clock(c.since), MapName(c.mapID),
            ns.UI.Format.Duration(c.extra + c.last - c.start), c.ex and (", %d sample(s) out of it"):format(#c.ex) or "")
    elseif c and c.city then
        Line("in a city since %s, %s", Clock(c.since), MapName(c.mapID))
    elseif c and c.samples then
        Line("might be staying: %d sample(s) since %s", #c.samples, Clock(c.since))
    end
    if o.road then
        Line("on a road since %s, %d breadcrumb(s), %s", Clock(o.road.crumbs[1] and o.road.crumbs[1].t),
            #o.road.crumbs, MapName(o.road.mapID))
    end
    if not (o.taxi or o.dungeon or c or o.road) then Line("nothing open") end
    Line("last tick %s, last outdoor spot %s", Clock(o.tick),
        o.seen and ("%s %.3f, %.3f at %s"):format(MapName(o.seen.mapID), o.seen.x, o.seen.y, date("%H:%M:%S", o.seen.t))
            or "-")
end

local function Stats(j)
    local counts, kinds = {}, {}
    for _, seg in ipairs(Journey.Segments(j)) do
        if not counts[seg.kind] then kinds[#kinds + 1] = seg.kind end
        counts[seg.kind] = (counts[seg.kind] or 0) + 1
    end
    local parts = {}
    for _, kind in ipairs(kinds) do parts[#parts + 1] = ("%d %s"):format(counts[kind], kind) end
    local levels = 0
    for _ in pairs(j.levels or {}) do levels = levels + 1 end
    ns.Print("Your Diary: |cff40c040%s|r, %s", ns.JourneyCapture.Running() and "capturing" or "not capturing",
        ns.JourneyCapture.On() and "the setting is on" or "|cffc04040the setting is off|r")
    Line("begun %s at level %s in %s%s", Clock(j.startedAt), tostring(j.startLevel), MapName(j.startMapID),
        j.test and "  |cffffd100(test data)|r" or "")
    Line("%d segment(s): %s", #j.segments, #parts > 0 and table.concat(parts, ", ") or "none")
    Line("%d level(s) reached, %d fight mark(s)", levels, #(j.marks or {}))
    Open(j)
    local st = ns.JourneyCapture.status
    local sample = st.sample
    Line("timer: %d tick(s) this session; last sample %s%s; %s", st.ticks,
        sample and date("%H:%M:%S", sample.t) or "none",
        sample and (" at %s %.3f, %.3f (%.0f, %.0f yd)"):format(MapName(sample.mapID), sample.x, sample.y,
            sample.wx, sample.wy) or "",
        st.skip and ("|cffc04040the last tick took none: " .. st.skip .. "|r") or "the last tick took one")
    if st.errors > 0 then
        Line("|cffc04040%d error(s), the last at %s:|r %s", st.errors, date("%H:%M:%S", st.errorAt), st.lastError)
    end
    local raw, size = Journey.RawCount()
    Line("raw buffer: %d of %d point(s)%s", raw, size, ns.DebugOn() and "" or " (written only with debug on)")
    local bytes = Journey.Size(j)
    Line("storage: about %.1f KB for this character (budget 200 KB), %.1f KB the whole file",
        bytes / 1024, ns.EstimateSize() / 1024)
    -- The plates on Your Diary's right page now (JRN-21): how long each
    -- took, its textures, and its ink trail against its share of the caps
    -- (UI/Ink/Trail.lua's CAP, UI/Journey/Plate.lua's SHARE).
    local page = ns.UI.JourneyPage and ns.UI.JourneyPage()
    local cap, plates = ns.UI.InkTrail.CAP, 0
    for i, plate in ipairs(page and page.plates or {}) do
        if plate:IsShown() and plate.buildMs then
            plates = plates + 1
            local c, share = plate.counts or {}, plate.share or 1
            Line("plate %d, %s: drawn in %.1f ms; %d textures; %d quads, %d dots, %d dabs (caps %d, %d, %d)%s",
                i, MapName(plate.mapID), plate.buildMs, c.textures or 0, c.quads or 0, c.dots or 0,
                c.dabs or 0, math.floor(cap.quads * share), math.floor(cap.dots * share),
                math.floor(cap.dabs * share),
                (c.fallback or 0) > 0 and (", %d as rectangles"):format(c.fallback) or "")
        end
    end
    -- The dungeon run last laid out on the table (UI/Dungeon/Sheet.lua's
    -- STAGE, UI/Dungeon/Spread.lua's Open): how long its click's frame was
    -- held, the lay a slice a frame, and the sheet put down.
    local spread = ns.UI.DungeonPage and ns.UI.DungeonPage.Spread()
    if spread and spread.clickMs then
        local took = spread.map.took
        Line("dungeon map: the click's frame %.1f ms; %s; put down in %.1f ms", spread.clickMs,
            took and ("laid in %.1f ms over %d frame(s), the longest %.1f ms (slices of %d); %d step(s), "
                .. "the longest stretch between two %.1f ms (ending at step %d)"):format(took.ms, took.frames,
                took.worst, ns.UI.DungeonPage.STAGE.budget, took.steps, took.part, took.partAt or 0)
                or "lying as it was laid, or laid at once", spread.downMs or 0)
    end
    if page and page.layout then
        Line("right page: %s", page.layout == "full" and "a zone's full page"
            or ("%d plate(s) (%s), %d margin note(s)"):format(plates, page.pattern or "?", page.notesWritten or 0))
    end
    local zone, x, y = ns.ZoneWhere()
    local wx, wy, inst = ns.WorldWhere()
    Line("here: zone map %s at %s; world %s; max level %d", MapName(zone),
        x and ("%.3f, %.3f"):format(x, y) or "-",
        wx and ("%.1f, %.1f yd, instance %s"):format(wx, wy, tostring(inst)) or "unreadable", Journey.MaxLevel())
end

local function Command(rest)
    local verb, arg = (rest or ""):match("^(%S*)%s*(.-)$")
    verb = verb:lower()
    local j = Journey.Mine()

    if verb == "clear" then
        Journey.ClearRaw()
        ns.Print("raw buffer cleared.")
        return
    end
    if verb == "raw" then
        local raw = ns.db.journeyRaw
        local n, size = Journey.RawCount()
        local at = raw.at or 0
        for i = math.min(n, 10) - 1, 0, -1 do
            local index = (at - 1 - i) % size + 1
            if raw[index] then Line(raw[index]) end
        end
        ns.Print("%d raw point(s) of %d kept (t, map, x, y, world x, world y), newest last.%s", n, size,
            ns.DebugOn() and "" or " Written only while debug is on.")
        return
    end
    if not j then
        ns.Print("no route for this character yet%s.", ns.JourneyCapture.On() and "" or " (the setting is off)")
        return
    end
    if verb == "segments" then
        local list = Journey.Segments(j)
        local count = tonumber(arg) or 10
        for i = math.max(1, #list - count + 1), #list do Line(Describe(list[i])) end
        ns.Print("%d segment(s), the newest %d shown.", #list, math.min(count, #list))
        Open(j)
        return
    end
    Stats(j)
end

ns.Slash.Register("journey", Command,
    "Your Diary: |cffffd100stats|r, |cffffd100segments [n]|r, |cffffd100raw|r, |cffffd100clear|r",
    { dev = true, usage = "journey [stats | segments | raw | clear]" })

--------------------------------------------------------------------------
-- /sd pen: the fountain pen's numbers, changed live
--------------------------------------------------------------------------
--
-- Changes UI/Ink/Pen.lua's PEN table in place and redraws the open zone
-- sheet, for this session only: a /reload puts the file's numbers back.
-- Found a look you like? `/sd pen` prints the numbers to copy into PEN.
--
--   /sd pen                     the numbers now
--   /sd pen bold | wild         presets, stronger and much stronger
--   /sd pen reset               the file's numbers
--   /sd pen nib THIN THICK [ANGLE]   the nib's share of the width, thinnest
--                               (along its edge) to fullest (across it),
--                               and its angle in degrees
--   /sd pen flow CAP [ALPHA]    how much a tight curve fills (the load's
--                               most, 1 = not at all) and how much darker
--   /sd pen bead SIZE [TURN]    a corner bead's size (times the line's
--                               width) and the sharpest turn, in degrees,
--                               a corner must pass to get one
--   /sd pen width LEAST MOST    the line's width clamp, in px
--   /sd pen KEY VALUE           any one number: nib.thin, flow.lag, ...

-- The presets keep the nib's mean share (thin + (thick - thin) * 2 / pi)
-- near 1, so the line gets more eccentric without getting heavier overall.
local PEN_PRESETS = {
    bold = { nib = { thin = 0.40, thick = 1.34 }, flow = { cap = 1.8, alphaGain = 0.5, lag = 14 },
        bead = { size = 1.6, turn = 40 }, width = { 0.6, 3.5 } },
    wild = { nib = { thin = 0.25, thick = 1.43 }, flow = { cap = 2.3, alphaGain = 0.7, lag = 20, radius = 16 },
        bead = { size = 2.0, turn = 30 }, width = { 0.5, 4.5 } },
}

-- The file's own numbers, kept the first time anything is changed.
local penDefaults

local function Copy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = type(v) == "table" and Copy(v) or v end
    return out
end

local function Into(target, from)
    for k, v in pairs(from) do
        if type(v) == "table" and type(target[k]) == "table" then Into(target[k], v) else target[k] = v end
    end
end

local function ShowPen(PEN)
    local N, F, B, Wd = PEN.nib, PEN.flow, PEN.bead, PEN.width
    Line("nib    thin %.2f  thick %.2f  angle %g  (mean share %.2f)", N.thin, N.thick, N.angle,
        N.thin + (N.thick - N.thin) * 2 / math.pi)
    Line("flow   cap %.2f  alphaGain %.2f  lag %g px  radius %g px  straight %.2f  widthGain %.2f", F.cap,
        F.alphaGain, F.lag, F.radius, F.straight, F.widthGain)
    Line("bead   size %.2f  turn %g  arc %g px  start %.2f", B.size, B.turn, B.arc, B.start)
    Line("width  %.2f to %.2f px", Wd[1], Wd[2])
end

local function PenCommand(rest)
    local Pen = ns.UI.Pen
    local PEN = Pen and Pen.PEN
    if not PEN then
        ns.Print("the ink trail is not loaded.")
        return
    end
    penDefaults = penDefaults or Copy(PEN)
    local words = {}
    for word in (rest or ""):gmatch("%S+") do words[#words + 1] = word end
    local verb = (words[1] or ""):lower()
    local a, b, c = tonumber(words[2]), tonumber(words[3]), tonumber(words[4])

    local changed = true
    if verb == "" then
        changed = false
    elseif verb == "reset" then
        Into(PEN, Copy(penDefaults))
    elseif PEN_PRESETS[verb] then
        Into(PEN, Copy(penDefaults))
        Into(PEN, PEN_PRESETS[verb])
    elseif verb == "nib" and a and b then
        PEN.nib.thin, PEN.nib.thick, PEN.nib.angle = a, b, c or PEN.nib.angle
    elseif verb == "flow" and a then
        PEN.flow.cap, PEN.flow.alphaGain = a, b or PEN.flow.alphaGain
    elseif verb == "bead" and a then
        PEN.bead.size, PEN.bead.turn = a, b or PEN.bead.turn
    elseif verb == "width" and a and b then
        PEN.width[1], PEN.width[2] = a, b
    else
        -- One number by its key: nib.thin, flow.lag, width.2, ...
        local group, key = verb:match("^(%a+)%.(%w+)$")
        local t = group and type(PEN[group]) == "table" and PEN[group]
        key = key and (tonumber(key) or key)
        if t and a and type(t[key]) == "number" then
            t[key] = a
        else
            ns.Print("/sd pen [bold | wild | reset | nib THIN THICK [ANGLE] | flow CAP [ALPHA] | bead SIZE [TURN]"
                .. " | width LEAST MOST | KEY VALUE]")
            return
        end
    end

    ShowPen(PEN)
    local page = ns.UI.JourneyPage and ns.UI.JourneyPage()
    local shown = page and page.plates and page.plates[1] and page.plates[1]:IsShown()
    if changed and shown then
        ns.UI.RedrawJourneyPage()
        ns.Print("the pen changed; the plates are redrawn (until /reload).")
    elseif changed then
        ns.Print("the pen changed (until /reload); open Your Diary to see it.")
    else
        ns.Print("the pen's numbers (UI/Ink/Pen.lua PEN).")
    end
end

ns.Slash.Register("pen", PenCommand,
    "Your Diary's fountain pen: |cffffd100bold|r, |cffffd100wild|r, |cffffd100reset|r, "
        .. "|cffffd100nib|r, |cffffd100flow|r, |cffffd100bead|r, |cffffd100width|r",
    { dev = true, usage = "pen [bold | wild | reset | nib | flow | bead | width | KEY VALUE]" })
