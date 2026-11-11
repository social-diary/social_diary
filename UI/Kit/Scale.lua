-- The diary's size (ns.UI.Scale): "Diary Size" in Settings > Interface,
-- 100% to 200%, the account's. Each window the diary opens over the game
-- registers here as it is built (the book, the entry sheet, the picker,
-- the quick note, the reunion toast, the parcel at login); everything
-- else lies on one of them and takes its scale from it. The Dungeon View's
-- table takes the book's (UI/Dungeon/Spread.lua) and is fitted again here
-- through OnChange.
--
-- The size chosen is a wish, not a promise: a window grows only as far as
-- it still fits the screen (FIT of its width and height), and never shrinks
-- below its own size for that, so 100% is the diary as it always was.

local addonName, ns = ...

local Scale = {}
ns.UI.Scale = Scale

-- The setting's range, in percent, and how much of the screen a window may
-- take before it stops growing.
local RANGE = { min = 100, max = 200, step = 10 }
local FIT = 0.95
Scale.RANGE, Scale.FIT = RANGE, FIT

local windows = {}
local listeners = {}

-- The size chosen, as a scale: 1 to 2, on a step. Before the saved
-- settings are there, 1.
function Scale.Chosen()
    local saved = ns.db and ns.Setting("diaryScale")
    local percent = ns.Style.OnScale(saved or RANGE.min, RANGE.min, RANGE.max, RANGE.step)
    return percent / 100
end

-- The largest scale at which a window `w` by `h` still lies within FIT of
-- the screen; nil while the screen's size is not known.
function Scale.Fit(w, h)
    local sw, sh = UIParent:GetWidth() or 0, UIParent:GetHeight() or 0
    if sw <= 0 or sh <= 0 or not w or not h or w <= 0 or h <= 0 then return nil end
    return math.min(sw * FIT / w, sh * FIT / h)
end

-- The scale for a window `w` by `h`: the size chosen, held to what fits,
-- but never under 1.
function Scale.For(w, h)
    local chosen, fit = Scale.Chosen(), Scale.Fit(w, h)
    if fit then chosen = math.min(chosen, fit) end
    return math.max(1, chosen)
end

-- A registered window's scale: its own, times the size, which fits the
-- window as large as its own scale makes it.
function Scale.Of(entry)
    local base = entry.base or 1
    return base * Scale.For(entry.w * base, entry.h * base)
end

-- One window's scale given again. Only a scale that changed moves it: back
-- to its own place (`place`), as an offset it was dragged by was measured
-- at the old scale and would land elsewhere at the new. Says whether it
-- changed.
local function Fit(entry)
    local frame = entry.frame
    local scale = Scale.Of(entry)
    if math.abs((frame:GetScale() or 1) - scale) < 0.0001 then return false end
    frame:SetScale(scale)
    if entry.place then entry.place(frame) end
    return true
end

-- `frame`, a window `w` by `h` at scale 1, takes the diary's size from now
-- on. `opts.place(frame)` lays it in its own place again after a change
-- (unset: the middle of the screen, as Chrome.Panel lays it);
-- `opts.base`, a scale of its own the size multiplies. Its first scale is
-- given here without moving it: it was just laid where it goes, or the
-- client laid it where the player left it.
function Scale.Register(frame, w, h, opts)
    opts = opts or {}
    local entry = { frame = frame, w = w, h = h, base = opts.base, place = opts.place or function(f)
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "CENTER")
    end }
    windows[#windows + 1] = entry
    -- (at its own scale already, as at 100%, it is left untouched)
    local scale = Scale.Of(entry)
    if math.abs((frame:GetScale() or 1) - scale) >= 0.0001 then frame:SetScale(scale) end
    -- Shown again after the screen changed while it was away.
    frame:HookScript("OnShow", function() Fit(entry) end)
    return frame
end

-- `fn()` runs after any window's scale changed.
function Scale.OnChange(fn)
    listeners[#listeners + 1] = fn
end

-- Every window's scale given again: the setting moved, or the screen.
function Scale.Apply()
    local changed = false
    for _, entry in ipairs(windows) do
        if Fit(entry) then changed = true end
    end
    if not changed then return end
    for _, fn in ipairs(listeners) do fn() end
    -- The pad's box drawn again where its item now lies.
    if ns.UI.Pad and ns.UI.Pad.Refresh then ns.UI.Pad.Refresh() end
end

ns.On("DISPLAY_SIZE_CHANGED", function() Scale.Apply() end)
ns.On("UI_SCALE_CHANGED", function() Scale.Apply() end)
