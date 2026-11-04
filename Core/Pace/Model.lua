--[[
RouteModel: places a death along a dungeon route from time alone.

Taken from the route-model handover (3 Nov 2026; ref/route-model-handover,
kept local and untracked) as it came, but for this header and the
name it registers under (ns.PaceModel): Core/DungeonPace.lua builds the legs
it reads from the addon's own way through and Core/Pace/*.lua's packs.
tests/pace_model.lua holds it to the answers recorded from the handover's
preview pages (tests/pace/vectors.lua): change it only with them.

Pure Lua 5.1, no WoW API. A line-by-line port of the preview pages'
JavaScript (functions profile / stateAt / placeDeath).

Coordinates are game yards (x north, y west). A route is a list of legs
(entrance -> boss 1 -> boss 2 ...); each leg has a path, a length in yards and
the pulls on it ({at = yards along the path, elites = n}). See Data/*.lua.

The model, per leg:
  * effort profile: walking moves the group at `speed` yd/s; a pull holds it in
    place for base + mob * elites seconds; the boss fight takes `boss` seconds.
  * pace: real groups take k times the profile, k ~ log-normal(0, spread).
  * danger: a death is `danger` x elites times more likely in a pull than while
    walking; a boss counts as BOSS_ELITES elites.
  * a death at time t is placed at the weighted median, along the path, of the
    states (t / k) over k, weighted by prior(k) x danger(state). States after
    the boss kill are impossible (the clock is still on this leg), so the
    estimate reaches the boss but never passes it.
  * if the next boss kill time is known, the leg is stretched to it instead.
]]

local addonName, ns = ...
local RouteModel = {}

RouteModel.DEFAULTS = {
  base = 20,      -- seconds per pull, fixed (pull, loot, drink)
  mob = 12,       -- extra seconds per elite in the pull
  speed = 5,      -- walking speed, yards per second
  boss = 60,      -- seconds per boss fight
  spread = 0.35,  -- pace spread (sigma of log pace factor)
  danger = 20,    -- danger of one elite relative to walking
}
RouteModel.BOSS_ELITES = 4

-- z grid for the pace factor, identical to the page: -3 .. 3 in steps of 0.025
local ZS = {}
for i = 0, 240 do ZS[#ZS + 1] = -3 + i * 0.025 end

local function params(P)
  local d, out = RouteModel.DEFAULTS, {}
  P = P or {}
  for k, v in pairs(d) do out[k] = P[k] or v end
  if out.spread < 0.05 then out.spread = 0.05 end
  if out.danger < 1 then out.danger = 1 end
  return out
end

local function elitesOf(leg, i)
  local e = leg.pulls[i].elites or leg.pulls[i].size or 1
  if e < 1 then e = 1 end
  return e
end

-- Effort profile: list of steps {t0, t1, y0, y1, kind = "walk"|"pull"|"boss", pull = index}
function RouteModel.Profile(leg, P)
  P = params(P)
  local steps, t, yd = {}, 0, 0
  for i, pull in ipairs(leg.pulls) do
    local at = pull.at
    if at < yd then at = yd end
    if at > leg.length then at = leg.length end
    local w = (at - yd) / P.speed
    steps[#steps + 1] = { t0 = t, t1 = t + w, y0 = yd, y1 = at, kind = "walk" }
    t, yd = t + w, at
    local c = P.base + P.mob * elitesOf(leg, i)
    steps[#steps + 1] = { t0 = t, t1 = t + c, y0 = yd, y1 = yd, kind = "pull", pull = i }
    t = t + c
  end
  local w = (leg.length - yd) / P.speed
  steps[#steps + 1] = { t0 = t, t1 = t + w, y0 = yd, y1 = leg.length, kind = "walk" }
  t = t + w
  steps[#steps + 1] = { t0 = t, t1 = t + P.boss, y0 = leg.length, y1 = leg.length, kind = "boss" }
  return { steps = steps, walk = t, total = t + P.boss, length = leg.length }
end

-- Expected seconds for the whole leg, boss fight included.
function RouteModel.LegTime(leg, P)
  return RouteModel.Profile(leg, P).total
end

-- State after `sec` seconds of effort, or nil once the boss is dead.
function RouteModel.StateAt(prof, sec)
  local pullsDone = 0
  for _, s in ipairs(prof.steps) do
    if sec < s.t1 then
      local f = 0
      if s.t1 > s.t0 then f = (sec - s.t0) / (s.t1 - s.t0) end
      return { yd = s.y0 + (s.y1 - s.y0) * f, kind = s.kind, pull = s.pull, pullsDone = pullsDone }
    end
    if s.kind == "pull" then pullsDone = pullsDone + 1 end
  end
  return nil
end

local function tanh(x)
  if x > 20 then return 1 end
  if x < -20 then return -1 end
  local e = math.exp(2 * x)
  return (e - 1) / (e + 1)
end

RouteModel.CURVES = {
  tanh = function(t, m) return tanh(t / m) end,
  hyp = function(t, m) return t / (t + m) end,
  exp = function(t, m) return 1 - math.exp(-t / m) end,
}

local function atBoss(leg, prof)
  return { yd = prof.length, kind = "boss", pullsDone = #leg.pulls }
end

--[[
PlaceDeath(leg, t, P, opts) -> result
  t     seconds since the clock started (entering the instance, or the previous boss kill)
  P     pace table (missing fields use DEFAULTS)
  opts  { curve = "data" (default) | "tanh" | "hyp" | "exp", knownKill = seconds or nil }
result fields:
  yd, progress (0..1), kind ("walk"|"pull"|"boss"), pull (index into leg.pulls or nil),
  pullsDone, expected (leg seconds), top = { kind, pull, share } (most likely moment),
  samples (array of {yd, kind, pull, w}, weights sum to 1; one sample when deterministic)
]]
function RouteModel.PlaceDeath(leg, t, P, opts)
  P = params(P)
  opts = opts or {}
  local curve, known = opts.curve or "data", opts.knownKill
  local prof = RouteModel.Profile(leg, P)
  local samples = {}

  if known and known > 0 then
    local r = t / known
    if r > 1 then r = 1 end
    local s = RouteModel.StateAt(prof, r * prof.total) or atBoss(leg, prof)
    s.w = 1
    samples[1] = s
  elseif curve ~= "data" then
    local p = RouteModel.CURVES[curve](t, prof.walk)
    local s = RouteModel.StateAt(prof, p * prof.walk) or atBoss(leg, prof)
    s.w = 1
    samples[1] = s
  else
    for _, z in ipairs(ZS) do
      local s = RouteModel.StateAt(prof, t / math.exp(P.spread * z))
      if s then
        local danger
        if s.kind == "walk" then danger = 1
        elseif s.kind == "pull" then danger = P.danger * elitesOf(leg, s.pull)
        else danger = P.danger * RouteModel.BOSS_ELITES end
        s.w = math.exp(-z * z / 2) * danger
        samples[#samples + 1] = s
      end
    end
    if #samples == 0 then
      local s = atBoss(leg, prof)
      s.w = 1
      samples[1] = s
    end
  end

  local total = 0
  for i, s in ipairs(samples) do total = total + s.w; s.order = i end
  for _, s in ipairs(samples) do s.w = s.w / total end

  -- weighted median along the path (ties keep sample order, like the page's stable sort)
  local sorted = {}
  for i, s in ipairs(samples) do sorted[i] = s end
  table.sort(sorted, function(a, b)
    if a.yd ~= b.yd then return a.yd < b.yd end
    return a.order < b.order
  end)
  local acc, median = 0, sorted[#sorted]
  for _, s in ipairs(sorted) do
    acc = acc + s.w
    if acc >= 0.5 then median = s; break end
  end

  -- most likely moment: weight grouped by pull, boss, or walking (first seen wins ties)
  local groups, order = {}, {}
  for _, s in ipairs(samples) do
    local key = s.kind == "pull" and ("pull" .. s.pull) or s.kind
    local g = groups[key]
    if not g then
      g = { kind = s.kind, pull = s.pull, share = 0 }
      groups[key] = g
      order[#order + 1] = key
    end
    g.share = g.share + s.w
  end
  local top
  for _, key in ipairs(order) do
    if not top or groups[key].share > top.share then top = groups[key] end
  end

  return {
    yd = median.yd, progress = median.yd / leg.length, kind = median.kind, pull = median.pull,
    pullsDone = median.pullsDone, expected = prof.total, top = top, samples = samples,
  }
end

-- Game coordinates of a point `yd` yards along the leg's path.
function RouteModel.PointAt(leg, yd)
  local path = leg.path
  local acc = 0
  for i = 2, #path do
    local ax, ay, bx, by = path[i - 1][1], path[i - 1][2], path[i][1], path[i][2]
    local seg = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
    if acc + seg >= yd or i == #path then
      local f = 0
      if seg > 0 then f = (yd - acc) / seg end
      if f < 0 then f = 0 elseif f > 1 then f = 1 end
      return ax + (bx - ax) * f, ay + (by - ay) * f
    end
    acc = acc + seg
  end
  return path[1][1], path[1][2]
end

-- Game coordinates -> pixels on the dungeon's reference image (data.image), via data.transform.
-- For your own map art, fit your own transform (pipeline/tools/fit_dungeon.py) or calibrate in the preview page.
function RouteModel.ToImage(data, x, y)
  local T = data.transform
  return T.a * x + T.b * y + T.c, T.d * x + T.e * y + T.f
end

-- Which leg is open: the first leg whose target boss is not in `killed` (set of boss names).
-- Returns leg index, or nil after the last boss (no next boss to ease towards).
function RouteModel.OpenLeg(data, killed)
  for i, leg in ipairs(data.legs) do
    if not killed[leg.to] then return i end
  end
  return nil
end

if type(ns) == "table" then ns.PaceModel = RouteModel end
return RouteModel
