-- Hints: small notes, one at a time, that point out something the player
-- may not have found, laid on the page where it can be done
-- (.claude/hints-plan.md, HNT-1..12). Core keeps when one may come; what
-- each says and where it lies is UI/Journal/Hints.lua's, and the slip
-- itself UI/Paper/HintSlip.lua's.
--
-- Account-wide, all of it (HNT-9): a hint is about the person at the
-- keyboard, so an alt never shows one again. SocialDiaryDB.hints
-- (Core/DB.lua's HINTS):
--
--   seen      [id] = when it was shown (epoch). Shown is gone for good
--             (HNT-7): put away, Escape, the book shut, it never comes back.
--   retired   [id] = true once the player has done what it teaches, shown
--             or not (HNT-8).
--   played    seconds at the game, counted by the heartbeat below: the clock
--             the cooldown runs on (HNT-1), so a short login does not wait
--             it out.
--   lastShown `played` when the last hint was shown.
--   lastBeat  the heartbeat's last time (epoch).
--   sitting   how many sittings so far: one begins after an hour away
--             (Sittings.GAP), a /reload or a quick relog carries on.
--   sittingFrom, sittingShown  when this one began, and the hints shown in it.
--   opens     times the journal was opened (HNT-12: from 0 on the update).
--   remembers times the Remember this key was pressed (SocialDiary_Remember).
--   boundAt   the sitting the Remember this key was first seen bound in.
--   again     [id] = true: asked for again (Show hints again, Hints.Reset),
--             shown the next time its page is open, past the clocks.
--
-- Hints.Register(id, spec), each a hint (UI/Journal/Hints.lua):
--   order     which goes first where two could show at once
--   page      the journal page it lies on ("journey", "people", ...)
--   eligible  function(ctx) -> true where its context holds now (ctx below)
--   done      optional: function() -> true where the player has already done
--             what it teaches, read as it is due: retires it (HNT-8)
--   fits      optional: function(ctx) -> true where it makes sense at all,
--             asked again or not (b1 with no key bound, b2 with one); the
--             part of `eligible` Show hints again still asks
--
-- ctx, from the watcher: { view, selected, inGroup }.

local addonName, ns = ...

local Hints = {}
ns.Hints = Hints

Hints.COOLDOWN = 60 * 60   -- HNT-1: an hour of play between any two hints
Hints.SETTLE = 15 * 60     -- HNT-3: not in a sitting's first quarter hour
Hints.CAP = 3              -- HNT-2: at most this many in one sitting
Hints.DWELL = 5            -- HNT-4: seconds on the page before one comes
Hints.BEAT = 60            -- the heartbeat, seconds
local GAP = 60 * 60        -- an hour away ends a sitting, as Core/Sittings.lua's

local registry = ns.Registry.New({
    what = "Hints.Register(id, { page, eligible })",
    key = "id",
    order = "order",
    default = 100,
    check = function(id, spec)
        if type(spec.page) ~= "string" then return false, "Hints.Register: " .. id .. " has no page" end
        if type(spec.eligible) ~= "function" then return false, "Hints.Register: " .. id .. " has no eligible" end
        for _, field in ipairs({ "done", "fits" }) do
            if spec[field] ~= nil and type(spec[field]) ~= "function" then
                return false, "Hints.Register: " .. id .. "'s " .. field .. " is not a function"
            end
        end
        return true
    end,
})

function Hints.Register(id, spec) return registry:Add(id, spec) end
function Hints.Get(id) return registry:Get(id) end
function Hints.All() return registry:Ordered() end

-- Forced from /sd hint (Dev/Hints.lua): shown the next time its page has
-- been open five seconds, every other gate and its own context passed over. Not saved: a /reload drops it.
local forced = {}

local function State() return ns.HintState() end
local function Now() return GetServerTime() end

-- The heartbeat: the player is at the game. Counts the time since the last
-- beat as played (a beat's worth at most, so a logout or a frozen client
-- never counts), not while AFK, and begins a sitting after an hour away.
function Hints.Beat(now)
    local s = State()
    if not s then return end
    now = now or Now()
    local last = s.lastBeat
    if not last or now - last > GAP then
        s.sitting = (s.sitting or 0) + 1
        s.sittingFrom, s.sittingShown = now, 0
    elseif now > last and not (UnitIsAFK and UnitIsAFK("player")) then
        s.played = (s.played or 0) + math.min(now - last, 2 * Hints.BEAT)
    end
    s.lastBeat = now
end

-- The journal opened (UI/Journal/Book.lua's ShowJournal, a closed book).
function Hints.Opened()
    local s = State()
    if s then s.opens = (s.opens or 0) + 1 end
end

function Hints.Opens()
    local s = State()
    return s and s.opens or 0
end

-- The Remember this key pressed (UI/Blizzard/Bindings.lua).
function Hints.Remembered()
    local s = State()
    if not s then return end
    s.remembers = (s.remembers or 0) + 1
    Hints.Retire("remember-use")
end

function Hints.Remembers()
    local s = State()
    return s and s.remembers or 0
end

-- The Remember this key is bound now: the sitting it was first seen bound
-- in, kept until it is seen unbound again. Sittings since then, or nil.
function Hints.BoundFor(bound)
    local s = State()
    if not s then return nil end
    if not bound then
        s.boundAt = nil
        return nil
    end
    s.boundAt = s.boundAt or (s.sitting or 0)
    return (s.sitting or 0) - s.boundAt
end

function Hints.Retire(id)
    local s = State()
    if s then s.retired[id] = true end
end

function Hints.Retired(id)
    local s = State()
    return s and s.retired[id] == true or false
end

function Hints.Seen(id)
    local s = State()
    return s and s.seen[id] ~= nil or false
end

-- Whether any hint may come now (HNT-1..3, HNT-10), whatever its context.
function Hints.Open(now)
    local s = State()
    if not s or ns.Setting("showHints") == false then return false end
    now = now or Now()
    if not s.sittingFrom or now - s.sittingFrom < Hints.SETTLE then return false end
    if (s.sittingShown or 0) >= Hints.CAP then return false end
    if s.lastShown and (s.played or 0) - s.lastShown < Hints.COOLDOWN then return false end
    return true
end

-- Whether a hint found done is retired here, as it is read.
local function Done(spec)
    if spec.done and spec.done() then
        Hints.Retire(spec.id)
        return true
    end
    return false
end

-- The hint due on this context, or nil. In turn:
--   forced    (/sd hint) on its page: nothing else asked;
--   again     (Show hints again) on its page, with Show hints on, not done
--             and where it fits: the clocks (HNT-1..3) passed over;
--   the rest  the first, in order, the clocks let through that is neither
--             seen nor retired and whose context holds.
function Hints.Due(ctx, now)
    for _, spec in ipairs(registry:Ordered()) do
        if forced[spec.id] and spec.page == ctx.view then return spec end
    end
    local s = State()
    if not s or ns.Setting("showHints") == false then return nil end
    for _, spec in ipairs(registry:Ordered()) do
        local id = spec.id
        if s.again[id] and spec.page == ctx.view then
            if Hints.Retired(id) or Done(spec) then
                s.again[id] = nil
            elseif not spec.fits or spec.fits(ctx) then
                return spec
            end
        end
    end
    if not Hints.Open(now) then return nil end
    for _, spec in ipairs(registry:Ordered()) do
        local id = spec.id
        if not Hints.Seen(id) and not Hints.Retired(id) and spec.page == ctx.view then
            if not Done(spec) and spec.eligible(ctx) then
                return spec
            end
        end
    end
    return nil
end

-- It has been shown (HNT-7): seen, and the clocks start again.
function Hints.Shown(id, now)
    local s = State()
    if not s then return end
    forced[id], s.again[id] = nil, nil
    s.seen[id] = now or Now()
    s.lastShown = s.played or 0
    s.sittingShown = (s.sittingShown or 0) + 1
end

-- HNT-10's "Show hints again": every hint not retired comes once more,
-- the next time its page is open, without waiting on the clocks. Saved, so
-- a /reload keeps the asking.
function Hints.Reset()
    local s = State()
    if not s then return end
    wipe(s.seen)
    s.lastShown = nil
    for _, spec in ipairs(registry:Ordered()) do
        if not Hints.Retired(spec.id) then s.again[spec.id] = true end
    end
end

function Hints.Again(id)
    local s = State()
    return s and s.again[id] == true or false
end

-- /sd hint <id> (Dev/Hints.lua).
function Hints.Force(id) forced[id] = true end
function Hints.Forced(id) return forced[id] == true end

ns.On("PLAYER_LOGIN", function()
    Hints.Beat()
    if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(Hints.BEAT, function() Hints.Beat() end) end
end)
