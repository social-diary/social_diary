-- The reunion toast with the pad (.claude/controller-plan.md, step 7b).
--
-- A toast comes by itself, over the game, often in a fight: it **never
-- takes the pad**. Nothing on its way calls Pad.Opened (UI/Windows/Reunion/
-- Queue.lua shows it, Toast.lua builds it), so this scope is never active
-- for it, and its catcher (made on the card once it exists, so the scope
-- can turn it off again) stays off: no button of the pad is ever taken
-- from the game while a toast is up.
--
-- Placing it is the player's own: Settings' "Move the toast"
-- (UI/Settings/Sections/Toasts.lua) says Pad.Opened as it lays the sample
-- card. Then, with the pad in hand, the D-pad (held: it repeats) or the
-- left stick moves the card, as dragging it does (kept where it lands,
-- read back where the screen's edge holds it); A is Done, X "Put it back",
-- B ends it as Escape does (where it lies is kept, as with the mouse:
-- there is no undo there either). Placing opened by Blizzard's Edit Mode
-- is not ours to drive: Forever's Gamepad UI has the pad there, and the
-- card is dragged with the mouse as before.

local addonName, ns = ...

local Pad = ns.UI.Pad
local Toast = ns.UI.Toast

-- A D-pad step, and the stick's speed pushed all the way (px a second).
local STEP, SPEED = 8, 420

local PROMPT = {
    move = { { "PADDUP", "PADDDOWN" }, "Move the toast" },
    done = { "PAD1", "Done", main = true },
    reset = { "PAD3", "Put it back" },
}

local function Placing()
    local toast = Toast.toast
    return toast and Toast.placing and Pad.Owns(toast) and toast or nil
end

local function Nudge(dx, dy)
    return function()
        if not Placing() then return false end
        Toast.Nudge(dx, dy)
    end
end

-- The stick's travel, a fraction of a pixel at a time: kept until whole.
local rest = { 0, 0 }

local scope = {
    layer = 50,
    -- (the card whenever it exists, so its catcher is turned off as well
    -- as on: only an opened placing turns it on)
    host = function() return Toast.toast end,
    active = function() return Placing() ~= nil end,
    keys = {
        PADDUP = Nudge(0, STEP), PADDDOWN = Nudge(0, -STEP),
        PADDLEFT = Nudge(-STEP, 0), PADDRIGHT = Nudge(STEP, 0),
        PAD3 = function()
            local toast = Placing()
            if not toast then return false end
            toast.reset:Click()
        end,
    },
}

-- Done, boxed: what A does.
function scope.build(f)
    f:Group("done", { mode = "list" })
    local toast = Placing()
    if not toast then return end
    f:Add("done", {
        key = "done", frame = toast.done, words = toast.done.label,
        level = toast.button:GetFrameLevel() + 5,
        enter = function() end, leave = function() end,
        press = function() toast.done:Click() end,
    })
end

-- The left stick moves it (the right one is the camera's, left alone).
function scope.stick(_, stick, x, y, len, elapsed)
    if stick == "Right" or stick == "Camera" then return false end
    if not Placing() then return false end
    if elapsed > 0 then
        rest[1] = rest[1] + x * SPEED * len * elapsed
        rest[2] = rest[2] + y * SPEED * len * elapsed
        local dx = rest[1] >= 0 and math.floor(rest[1]) or -math.floor(-rest[1])
        local dy = rest[2] >= 0 and math.floor(rest[2]) or -math.floor(-rest[2])
        rest[1], rest[2] = rest[1] - dx, rest[2] - dy
        if dx ~= 0 or dy ~= 0 then Toast.Nudge(dx, dy) end
    end
    return true
end

function scope.back()
    if not Placing() then return false end
    Toast.StopPlacing()
    return true
end

function scope.legend()
    return { PROMPT.move, PROMPT.done, PROMPT.reset }
end

Pad.RegisterScope("toastplace", scope)
