-- A dungeon run's page in Your Diary's words (ns.UI.JourneyText): the
-- keepsake page (.claude/ui-proposal/super-plate.md, B, round 5, 28 Oct;
-- UI/Journey/Run.lua). The user's own wording, taken as written: no
-- /copywriter pass (their decision, 28 Oct).
--
-- The module and its siblings: UI/Journey/Text/Grammar.lua.

local addonName, ns = ...

local Text = ns.UI.JourneyText

-- Numbers a person says in words, up to twenty; past that, figures.
local SAID = { "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve",
    "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen", "twenty" }
local function Said(n)
    return SAID[n] or tostring(n)
end
Text.RunSaid = Said

-- How long, in hours and minutes: "35 minutes", "1 hour 52 minutes",
-- "2 hours"; under a minute, "a minute".
function Text.RunDuration(seconds)
    local minutes = math.floor((seconds or 0) / 60 + 0.5)
    if minutes < 1 then return "a minute" end
    local h, m = math.floor(minutes / 60), minutes % 60
    local parts = {}
    if h > 0 then parts[#parts + 1] = h == 1 and "1 hour" or (h .. " hours") end
    if m > 0 then parts[#parts + 1] = m == 1 and "1 minute" or (m .. " minutes") end
    return table.concat(parts, " ")
end

-- The subtitle: the level span and the time inside, no date (the user):
-- "Level 22–23, 1 hour 52 minutes", or "Level 22, 35 minutes".
function Text.RunSubtitle(from, to, seconds)
    local time = Text.RunDuration(seconds)
    if not from then return time end
    if to and to > from then return ("Level %d\226\128\147%d, %s"):format(from, to, time) end
    return ("Level %d, %s"):format(from, time)
end

-- The boss strip: "4 out of 7 bosses slain", or "Full run" (underlined by
-- the page in ink, never by the font).
function Text.RunBosses(k, m, full)
    if full then return "Full run" end
    return ("%d out of %d bosses slain"):format(k or 0, m or 0)
end

-- The slip pinned to the last keepsake: "and eleven more".
function Text.RunMore(n)
    return ("and %s more"):format(Said(n))
end

-- Whose a keepsake is: "yours at last", "yours", "Brom's" ("Atlas'").
function Text.RunWhose(item, name)
    if item.mine then return item.atLast and "yours at last" or "yours" end
    if not name or name == "" then return "someone's" end
    return name:find("s$") and (name .. "'") or (name .. "'s")
end

-- The fallen note's first line: "we fell once", "we fell twice", "we fell
-- six times".
function Text.RunFell(n)
    if n == 1 then return "we fell once" end
    if n == 2 then return "we fell twice" end
    return ("we fell %s times"):format(Said(n))
end

-- One of the fallen with how often: "you", "you twice", "Brom thrice",
-- "Zuri four times".
function Text.RunFallenOne(name, times)
    if times == 1 then return name end
    if times == 2 then return name .. " twice" end
    if times == 3 then return name .. " thrice" end
    return ("%s %s times"):format(name, Said(times))
end

-- Everyone who fell, as many as `fits(words)` lets in, the rest counted:
-- "you twice, Brom twice, Zuri, Grimble", "…, and three others". `names`
-- is each one's words (RunFallenOne). Returns the words.
function Text.RunFallen(names, fits)
    for take = #names, 1, -1 do
        local rest = #names - take
        local words = table.concat(names, ", ", 1, take)
        if rest > 0 then words = words .. (", and %s other%s"):format(Said(rest), rest > 1 and "s" or "") end
        if take == 1 or not fits or fits(words) then return words end
    end
    return ""
end

-- A death in the fallen note's tooltip: "Grimble died to Overlord Ramtusk".
function Text.RunDiedTo(name, killer)
    if killer and killer ~= "" then return ("%s died to %s"):format(name, killer) end
    return ("%s died"):format(name)
end

-- After the signatures: the party not in the diary, "and one you didn't
-- keep"; and what had no room, "and 34 others".
function Text.RunStrangers(n)
    return ("and %s you didn't keep"):format(Said(n))
end
function Text.RunOthers(n)
    return ("and %d others"):format(n)
end

Text.RUN = {
    nobody = "Nobody fell.",
    nothing = "Nothing came up with us.",
    you = "you",
    someone = "someone",
    open = "Click to open its map.",
    sheet = "Click to open its sheet.",
}

-- The title's tooltip, TLN-12's line: "Razorfen Kraul, 35 min, 4 of 6
-- bosses, 6 deaths, with Brom, Kaelith and Zuri".
function Text.RunTip(visit, seconds, k, m, deaths, names)
    local parts = { visit.name or "A dungeon", ns.UI.Format.Duration(seconds) }
    if m then parts[#parts + 1] = ("%d of %d bosses"):format(k, m) end
    if deaths > 0 then parts[#parts + 1] = deaths == 1 and "1 death" or (deaths .. " deaths") end
    local line = table.concat(parts, ", ")
    local with = ns.UI.Format.List(names or {}, { max = 4, shown = 3, more = "others" })
    if with then line = line .. ", with " .. with end
    return line
end
