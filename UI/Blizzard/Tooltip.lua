-- Unit tooltip lines for diary entries (REU-4), and one line for everyone
-- else the sightings know (REU-6).
--
-- Session 1 verified that TooltipDataProcessor hands over a plain GUID for
-- strangers on mouseover, target and nameplate tooltips, and keeps doing so
-- under combat lockdown. When the GUID does come back secret (an instanced
-- map, a future restriction), SafeGUID drops it and the tooltip is left
-- exactly as Blizzard built it: REU-4 says nothing is shown then.
--
-- Stats come from ns.People.Stats, which works out one person at a time, so
-- a mouseover never pays for rebuilding the whole journal index.

local addonName, ns = ...

local Format = ns.UI.Format

local NOTE_CHARS = 60

-- The note's first line, cut to fit. A cut can land inside a multi-byte
-- character, so a trailing partial one is dropped before the ellipsis.
local function NoteLine(note)
    if not note then return nil end
    local line = note:match("^[^\n]*")
    if #line <= NOTE_CHARS then return line end
    line = line:sub(1, NOTE_CHARS):gsub("[\192-\255][\128-\191]*$", "")
    return line .. "\226\128\166"
end

-- "twice", "3 times". Never "once": that line is not shown.
local function Times(count)
    if count == 2 then return "twice" end
    return count .. " times"
end

-- REU-6: "Seen N times, last ...", off by default. Only what came before
-- this encounter (Sightings.SeenBefore): "last today at <now>" would say
-- nothing, and a first meeting has no line at all.
function ns.UI.SeenLine(guid, now)
    local record = ns.Characters.Get(guid)
    if not record then return nil, "no character record" end
    if record.isSelf then return nil, "one of your own characters" end

    now = now or ns.Now()
    local count, last = ns.Sightings.SeenBefore(guid, now)
    if not count then return nil, last end

    -- A single earlier sighting is too thin to be worth a line.
    if count < 2 then return nil, "seen only once before" end

    return ("Seen %s  ·  last %s"):format(Times(count), Format.At(last, now))
end

local function SeenLine(tooltip, guid)
    if not ns.Setting("tooltipSeen") then return end
    local line = ns.UI.SeenLine(guid)
    if line then tooltip:AddLine(line, 0.6, 0.6, 0.6) end
end

local function OnUnitTooltip(tooltip, data)
    if not data or not tooltip.AddLine or not ns.db then return end

    local guid = ns.SafeGUID(data.guid)
    if not guid then return end

    if not ns.Diary.IsDiary(guid) then
        SeenLine(tooltip, guid)
        return
    end

    if not ns.Setting("tooltips") then return end

    local s = ns.People.Stats(guid)
    if not s then return end
    local entry = s.entry

    local head = entry.tags[1] and table.concat(entry.tags, ", ") or "in your diary"
    if entry.relationship then head = head .. "  ·  " .. entry.relationship end
    tooltip:AddLine("|cffffd100Diary:|r " .. head, 1, 1, 1)

    local note = NoteLine(entry.note)
    if note and note ~= "" then
        tooltip:AddLine(note, 0.9, 0.9, 0.9)
    end

    if s.timesMet > 0 then
        tooltip:AddLine(("Met %s  ·  last %s"):format(Format.Count(s.timesMet, "time", "times"),
            Format.Ago(s.lastMet)), 0.6, 0.6, 0.6)
    else
        -- Before this encounter, as SeenLine: hovering them has just moved
        -- `seen` to now.
        local count, last = ns.Sightings.SeenBefore(guid)
        if count then
            tooltip:AddLine("Last seen " .. Format.At(last), 0.6, 0.6, 0.6)
        end
    end
end

-- Test hook, kept for a tooltip test (none reads it yet).
ns.UI.OnUnitTooltip = OnUnitTooltip

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
    and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnUnitTooltip)
end
