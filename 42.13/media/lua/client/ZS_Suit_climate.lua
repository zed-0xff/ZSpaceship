-- Space suit client-side effects (temperature regulation)
-- Runs every tick via OnPlayerUpdate to prevent moodle flicker
-- TODO: proper client/server

local NORMAL_TEMP = 37.0
local TEMP_LERP_RATE = 0.02  -- gentle per-tick lerp (OnPlayerUpdate fires ~60x/sec)

local function updateSuitClimate()
    local player = getPlayer()
    if not player then return end
    if not ZSpaceship.getWornSuit(player) then return end

    local stats = player:getStats()
    local temp = stats:get(CharacterStat.TEMPERATURE)
    if math.abs(temp - NORMAL_TEMP) <= 0.1 then return end
    stats:set(CharacterStat.TEMPERATURE, temp + (NORMAL_TEMP - temp) * TEMP_LERP_RATE)
end

Events.OnPlayerUpdate.Add(updateSuitClimate)
