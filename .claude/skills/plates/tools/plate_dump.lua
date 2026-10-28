-- Your Diary's right page, dumped from the mock for plate_render.py.
-- Run through plates.sh (it builds the harness farm this needs); not a test.
--
-- For every /sd testdata page (an entry drawn whole where it is spliced,
-- else each of its pieces, one a sitting: T.DiaryPages): one SUMMARY line
-- on stdout (pattern, each plate's weight and moment kinds, what made the
-- margin) and its geometry in $SD_PLATES_OUT/out.txt. With
-- $SD_PLATES_FORCE=1 (the default) each weighted page (FL, LF, FFL, FLF,
-- LFF, LFL, F+L) is also forced onto a page with that many plates,
-- whatever their weights, so pages testdata never produces still get
-- drawn; where no page has that many, onto a week drawn whole (as it was
-- before the pages went by sitting), the only place three plates still
-- come from.
--
-- The mock measures text at a flat 14 px; captions are patched to wrap
-- roughly as the client does (body 6.6 px a letter, 15 px a line; the
-- hand 7 px a letter, 18 px a line). Real widths differ: screenshots win.
local T = ...
local ns = T.Boot()
local dir = os.getenv("SD_PLATES_OUT") or "/tmp/sd-plates"
local out = assert(io.open(dir .. "/out.txt", "w"))

ns.TestData.Write()
ns.UI.ShowJournal()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
local page = ns.UI.JourneyPage()
local LAYOUT = ns.UI.JourneyLook.LAYOUT
local Plate = ns.UI.JourneyPlate

out:write(("CONST %g %g %g %g %g %g\n"):format(Plate.SHADOW.out, Plate.SHADOW.blur, Plate.SHADOW.gain,
    Plate.SHADOW.spread, Plate.LIFT.height, Plate.LIFT.reach))

local function Patch(fs, per, line)
    if fs.patched then return end
    fs.patched = true
    fs.GetStringHeight = function(self)
        local width = (self.width or 0) > 0 and self.width or 1e9
        if not self.text or self.text == "" then return 0 end
        return line * math.max(1, math.ceil(#self.text * per / width))
    end
    fs.GetUnboundedStringWidth = function(self) return #(self.text or "") * per end
end
for _, pair in ipairs({ { "headingPool", 7, 18 }, { "captionPool", 6.6, 15 } }) do
    local pool = page[pair[1]]
    local next = pool.Next
    pool.Next = function(self)
        local fs = next(self)
        Patch(fs, pair[2], pair[3])
        return fs
    end
end

local function Summary(label, e)
    local kinds = {}
    for k, p in ipairs(e.plates or {}) do
        local ks = {}
        for _, m in ipairs(p.moments or {}) do ks[#ks + 1] = m.kind end
        kinds[k] = (p.light and "L" or "F") .. "(" .. table.concat(ks, ",") .. ")"
    end
    local margins = {}
    for i, plate in ipairs(page.plates) do
        if plate:IsShown() then
            local ks = {}
            -- A witness's card with the size it took (Features/Witnesses/Card.lua).
            for _, it in ipairs(plate.margin or {}) do
                ks[#ks + 1] = it.kind .. (it.kind == "witness" and it.note and it.note.form
                    and ("(" .. it.note.form .. ")") or "")
            end
            margins[#margins + 1] = i .. ":" .. table.concat(ks, ",") .. (plate.print and ("+S(" .. plate.print.form .. ")") or "")
        end
    end
    print(("SUMMARY %-22s %-4s %s | margin %s"):format(label, tostring(page.pattern), table.concat(kinds, " "),
        table.concat(margins, " ")))
end

local function Dump(label)
    out:write(("PAGE %s %s\n"):format(label, tostring(page.pattern)))
    for i, p in ipairs(page.plates) do
        if p:IsShown() then
            local s = p.slot
            out:write(("PLATE %d %g %g %g %g %g %g %s %s %s\n"):format(i, s.x, s.y, s.w, s.h, s.t or 0, s.pad,
                s.pc or 0, table.concat(s.corners or {}, ","), s.lift or "-"))
        end
    end
    for _, key in ipairs({ "headingPool", "captionPool" }) do
        local pool = page[key]
        for k = 1, pool.used do
            local fs = pool[k]
            if fs:IsShown() and fs.text and fs.text ~= "" then
                local a = fs.recorded.points[#fs.recorded.points].args
                local calls = fs.recorded.calls.SetJustifyH
                out:write(("TEXT %s %g %g %g %g %s|%s\n"):format(key, a[3], -a[4], fs.width or 0,
                    fs:GetStringHeight(), fs.justifyH or calls and calls[1] or "LEFT", fs.text:gsub("\n", " ")))
            end
        end
    end
    -- Good luck told on a print (Features/Hunts/LuckyCard.lua's S): its slip, its tag
    -- and its icon, each four corners on the page.
    for i, p in ipairs(page.plates) do
        if p:IsShown() and p.print then
            for _, part in ipairs({ "label", "tag", "icon" }) do
                local pts = {}
                for _, pt in ipairs(p.print.polys[part]) do pts[#pts + 1] = ("%g %g"):format(pt[1], pt[2]) end
                out:write(("PRINTSLIP %d %s %s\n"):format(i, part, table.concat(pts, " ")))
            end
        end
    end
    for _, link in ipairs(page.links) do
        local b = link.strip.box
        -- (S's own leader leaves the print: S is drawn above, PRINTSLIP.)
        if b and link.strip:IsShown() and not link.strip.polys then
            out:write(("NOTE %g %g %g %g %g %g\n"):format(b[1], b[2], b[3], b[4], link.mark[1], link.mark[2]))
        end
    end
end

-- Every page a reader opens, and what it draws: the piece, or the entry.
local pages = T.DiaryPages(page)
for _, at in ipairs(pages) do at.obj = at.k and at.e.pieces[at.k] or at.e end
local function Draw(at)
    T.OpenDiaryPage(page, at.i, at.k)
end

for _, at in ipairs(pages) do
    Draw(at)
    local label = "entry" .. at.i .. "_" .. tostring(at.e.level or "week") .. (at.k and ("_s" .. at.k) or "")
    Dump(label)
    Summary(label, at.obj)
end

-- The tool's fallback for the forced pages: the entries read by sitting
-- drawn whole, each a page of its own (spliced for the while).
local whole = {}
for i, e in ipairs(page.recap.entries) do
    if not e.spliced then
        e.spliced = true
        ns.UI.YourDiary.PlatesOf(e)
        e.spliced = false
        whole[#whole + 1] = { i = i, e = e, obj = e, whole = true }
    end
end
local function DrawWhole(at)
    at.e.spliced = true
    T.OpenDiaryPage(page, at.i, nil)
end
local function Done(at)
    if at.whole then at.e.spliced = false end
end

if (os.getenv("SD_PLATES_FORCE") or "1") ~= "0" then
    -- Each weighted page on the first entry with that many plates (the
    -- tucked page kept off, so FL is FL).
    local function Force(key, n)
        for _, list in ipairs({ pages, whole }) do
            for _, at in ipairs(list) do
                local e = at.obj
                if e.plates and #e.plates == n then
                    local layout, pattern = e.layout, e.pattern
                    e.layout, e.pattern = LAYOUT[key], key
                    if at.whole then DrawWhole(at) else Draw(at) end
                    Dump("forced_" .. key .. "_entry" .. at.i .. (at.k and ("_s" .. at.k) or "")
                        .. (at.whole and "_whole" or ""))
                    e.layout, e.pattern = layout, pattern
                    Done(at)
                    return
                end
            end
        end
        print("NONE: no testdata page has " .. n .. " plates to force " .. key .. " onto")
    end
    local tucked = LAYOUT.FL.tucked
    LAYOUT.FL.tucked = nil
    for key, slots in pairs(LAYOUT) do
        if type(key) == "string" and key ~= "F+L" then Force(key, #slots) end
    end
    LAYOUT.FL.tucked = tucked
    -- F+L as if FL's rule kept it (its `whole` test off), on every
    -- two-plate entry.
    if tucked then
        local whole = tucked[1].whole
        tucked[1].whole = nil
        for _, at in ipairs(pages) do
            local e = at.obj
            if e.plates and #e.plates == 2 then
                local layout, pattern = e.layout, e.pattern
                e.layout, e.pattern = LAYOUT.FL, "FL"
                Draw(at)
                Dump("forced_FpL_entry" .. at.i .. (at.k and ("_s" .. at.k) or ""))
                e.layout, e.pattern = layout, pattern
            end
        end
        tucked[1].whole = whole
    end
end
out:close()
