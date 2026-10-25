-- Eye overlays: the infected (yellow) layers and the bloodshot (red) layers.
-- Both are worn on stacked slots over the eye and lash layers.
--
-- Infected layers come from zombie infection (stored 0-100): 10-20% adds 1,
-- 21-40% adds 2, 41-60% adds 3, 61-80% adds 4, 81-100% adds 5. Sickness at
-- 90% or worse adds the sixth. They are drawn under the bloodshot layers.
--
-- Bloodshot layers come from:
--
--   * intoxication above 30% / 50% / 70% (the stat is stored 0-100), adding
--     1 / 2 / 3 layers,
--   * sickness at 75% or 90% or worse, adding 1 / 2 layers, or
--   * angry at 75% or worse, adding 1 layer.
--
-- The total is capped at hydEyesData.BloodshotLayers (6).
--
-- The state is polled rather than event-driven: PZ has no stat-changed
-- event, and the moodles only report a level, not the thresholds wanted
-- here. Polling is throttled because re-wearing an item rebuilds the model,
-- and hydEyesData.refreshOverlays() only touches the slots when the wanted
-- state differs from what is already worn.

require("hydEyesData")

-- Ticks between checks (OnPlayerUpdate runs every tick).
local CHECK_TICKS = 15

local ticks = 0

local function check(player)
    if not player then return end
    pcall(function() hydEyesData.refreshOverlays(player) end)
end

local function onPlayerUpdate(player)
    ticks = ticks + 1
    if ticks < CHECK_TICKS then return end
    ticks = 0
    check(player)
end

if Events and Events.OnPlayerUpdate then
    Events.OnPlayerUpdate.Add(onPlayerUpdate)
end
