-- /sd hint: a hint shown the next time its page has been open five
-- seconds, everything else passed over: its context (ten openings, a
-- group, the key), seen, retired, the cooldown, the settle, the sitting's
-- cap, "Show hints" off (Core/Hints.lua's Force). Combat and what lies over
-- the page still hold it back.
--
--   /sd hint                the hints, and where each stands
--   /sd hint <id> | all     forced at the next occasion
--   /sd hint reset          every hint unseen and unretired, the clocks at 0

local addonName, ns = ...

local Hints = ns.Hints

local function Where(id)
    local s = ns.HintState()
    if Hints.Forced(id) then return "forced" end
    if Hints.Again(id) then return "asked again" end
    if Hints.Retired(id) then return "retired" end
    if Hints.Seen(id) then return "seen " .. date("%d %b %H:%M", s.seen[id]) end
    return "waiting"
end

local function CommandHint(rest)
    local arg = (rest or ""):match("^%s*(%S*)")
    local s = ns.HintState()
    if arg == "" then
        for _, spec in ipairs(Hints.All()) do
            ns.Print("%s (%s): %s", spec.id, spec.page, Where(spec.id))
        end
        ns.Print("open %s; %d opens, %d key presses, %d min played, sitting %d (%d shown).",
            Hints.Open() and "now" or "not yet", s.opens or 0, s.remembers or 0,
            math.floor((s.played or 0) / 60), s.sitting or 0, s.sittingShown or 0)
        return
    end
    if arg == "reset" then
        wipe(s.seen)
        wipe(s.retired)
        wipe(s.again)
        s.lastShown, s.sittingShown, s.opens, s.remembers, s.boundAt = nil, 0, 0, 0, nil
        ns.Print("every hint can come again; the counts are back at 0.")
        return
    end
    local ids = {}
    if arg == "all" then
        for _, spec in ipairs(Hints.All()) do ids[#ids + 1] = spec.id end
    elseif Hints.Get(arg) then
        ids[1] = arg
    else
        ns.Print("no hint %s: /sd hint lists them.", arg)
        return
    end
    for _, id in ipairs(ids) do
        Hints.Force(id)
        ns.Print("%s comes the next time its page (%s) is open five seconds.", id, Hints.Get(id).page)
    end
end

ns.Slash.Register("hint", CommandHint, "a hint at its next occasion: |cffffd100/sd hint [id | all | reset]|r",
    { dev = true })
