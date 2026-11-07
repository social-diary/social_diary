-- A dungeon run's page in Your Diary's words (ns.UI.JourneyText): the
-- keepsake page (.claude/ui-proposal/super-plate.md, B, round 5, 28 Oct;
-- UI/Journey/Run.lua). The user's own wording, taken as written: no
-- /copywriter pass (their decision, 28 Oct).
--
-- The module and its siblings: UI/Journey/Text/Grammar.lua.

local addonName, ns = ...

local Text = ns.UI.JourneyText
local L, Fmt = ns.L, ns.Fmt
local G = ns.Locale.grammar

-- Numbers a person says in words, up to twenty; past that, figures. Where
-- a sentence takes "one", it has its own template (a translation's "one"
-- changes with its noun).
local SAID = { L["one"], L["two"], L["three"], L["four"], L["five"], L["six"], L["seven"], L["eight"], L["nine"],
    L["ten"], L["eleven"], L["twelve"], L["thirteen"], L["fourteen"], L["fifteen"], L["sixteen"], L["seventeen"],
    L["eighteen"], L["nineteen"], L["twenty"] }
local function Said(n)
    return SAID[n] or tostring(n)
end
Text.RunSaid = Said

-- How long, in hours and minutes: "35 minutes", "1 hour 52 minutes",
-- "2 hours"; under a minute, "a minute".
function Text.RunDuration(seconds)
    local minutes = math.floor((seconds or 0) / 60 + 0.5)
    if minutes < 1 then return L["a minute"] end
    local h, m = math.floor(minutes / 60), minutes % 60
    local hours = h == 1 and L["1 hour"] or Fmt(L["%d hours"], h)
    local mins = m == 1 and L["1 minute"] or Fmt(L["%d minutes"], m)
    if h > 0 and m > 0 then return Fmt(L["%1$s %2$s##hours minutes"], hours, mins) end
    return h > 0 and hours or mins
end

-- The subtitle: the level span and the time inside, no date (the user):
-- "Level 22–23, 1 hour 52 minutes", or "Level 22, 35 minutes".
function Text.RunSubtitle(from, to, seconds)
    local time = Text.RunDuration(seconds)
    if not from then return time end
    if to and to > from then return Fmt(L["Level %1$d\226\128\147%2$d, %3$s"], from, to, time) end
    return Fmt(L["Level %1$d, %2$s"], from, time)
end

-- The boss strip: "4 out of 7 bosses slain", or "Full run" (underlined by
-- the page in ink, never by the font).
function Text.RunBosses(k, m, full)
    if full then return L["Full run"] end
    return Fmt(L["%1$d out of %2$d bosses slain"], k or 0, m or 0)
end

-- The slip pinned to the last keepsake: "and eleven more".
function Text.RunMore(n)
    if n == 1 then return L["and one more"] end
    return Fmt(L["and %s more"], Said(n))
end

-- Whose a keepsake is: "yours at last", "yours", "Brom's" ("Atlas'").
function Text.RunWhose(item, name)
    if item.mine then return item.atLast and L["yours at last"] or L["yours"] end
    if not name or name == "" then return L["someone's"] end
    if G.Genitive then return G.Genitive(name) end
    return name:find("s$") and (name .. "'") or (name .. "'s")
end

-- The fallen note's first line: "we fell once", "we fell twice", "we fell
-- six times".
function Text.RunFell(n)
    if n == 1 then return L["we fell once"] end
    if n == 2 then return L["we fell twice"] end
    return Fmt(L["we fell %s times"], Said(n))
end

-- One of the fallen with how often: "you", "you twice", "Brom thrice",
-- "Zuri four times".
function Text.RunFallenOne(name, times)
    if times == 1 then return name end
    if times == 2 then return Fmt(L["%s twice"], name) end
    if times == 3 then return Fmt(L["%s thrice"], name) end
    return Fmt(L["%1$s %2$s times"], name, Said(times))
end

-- Everyone who fell, as many as `fits(words)` lets in, the rest counted:
-- "you twice, Brom twice, Zuri, Grimble", "…, and three others". `names`
-- is each one's words (RunFallenOne). Returns the words.
function Text.RunFallen(names, fits)
    for take = #names, 1, -1 do
        local rest = #names - take
        local words = table.concat(names, L[", "], 1, take)
        if rest == 1 then
            words = Fmt(L["%s, and one other"], words)
        elseif rest > 1 then
            words = Fmt(L["%1$s, and %2$s others"], words, Said(rest))
        end
        if take == 1 or not fits or fits(words) then return words end
    end
    return ""
end

-- A death in the fallen note's tooltip: "Grimble died to Overlord Ramtusk".
function Text.RunDiedTo(name, killer)
    -- "you" takes its own verb in a translation ("du starbst").
    if name == Text.RUN.you then
        if killer and killer ~= "" then return Fmt(L["you died to %s"], killer) end
        return L["you died"]
    end
    if killer and killer ~= "" then return Fmt(L["%1$s died to %2$s"], name, killer) end
    return Fmt(L["%s died"], name)
end

-- After the names: members a run saved no name for, "and one you didn't
-- keep"; and who has no room on this turn of the list, "and 34 others".
function Text.RunStrangers(n)
    if n == 1 then return L["and one you didn't keep"] end
    return Fmt(L["and %s you didn't keep"], Said(n))
end
function Text.RunOthers(n)
    if n == 1 then return L["and 1 other"] end
    return Fmt(L["and %d others"], n)
end

Text.RUN = {
    nobody = L["Nobody fell."],
    nothing = L["No noteworthy drops."],
    you = L["you"],
    someone = L["someone"],
    open = L["Click to open its map."],
    sheet = L["Click to open its sheet."],
    add = L["+ Add"],
}

-- The title's tooltip, TLN-12's line: "Razorfen Kraul, 35 min, 4 of 6
-- bosses, 6 deaths, with Brom, Kaelith and Zuri".
function Text.RunTip(visit, seconds, k, m, deaths, names)
    local parts = { visit.name or L["A dungeon"], ns.UI.Format.Duration(seconds) }
    if m then parts[#parts + 1] = Fmt(L["%1$d of %2$d bosses"], k, m) end
    if deaths > 0 then parts[#parts + 1] = deaths == 1 and L["1 death"] or Fmt(L["%d deaths"], deaths) end
    local line = table.concat(parts, L[", "])
    local with = ns.UI.Format.List(names or {}, { max = 4, shown = 3, more = L["others"] })
    if with then line = Fmt(L["%1$s, with %2$s"], line, with) end
    return line
end
