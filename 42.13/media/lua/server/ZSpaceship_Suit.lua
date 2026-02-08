-- Space suit environmental effects
-- Runs every 10 minutes for each player wearing the suit

local WETNESS_TO_WATER_RATIO = 0.01  -- 1 wetness point = 0.01 fluid units
local NORMAL_TEMP = 37.0             -- normal body temperature in Celsius
local TEMP_LERP_RATE = 0.5           -- move 50% closer to normal each tick

local function getWornSuit(player)
    local wornItems = player:getWornItems()
    for i = 0, wornItems:size() - 1 do
        local item = wornItems:getItemByIndex(i)
        if item and item:getFullType() == "ZSpaceship.SpaceSuitA" then
            return item
        end
    end
end

-- Convert wetness to water in the suit's fluid container
local function convertWetnessToSuitWater(player, suit)
    local stats = player:getStats()
    local wetness = stats:get(CharacterStat.WETNESS)
    if wetness <= 0 then return end

    local fc = suit:getFluidContainer()
    if not fc then return end

    local space = fc:getCapacity() - fc:getAmount()
    if space <= 0 then return end

    local waterToAdd = math.min(wetness * WETNESS_TO_WATER_RATIO, space)
    local wetnessUsed = waterToAdd / WETNESS_TO_WATER_RATIO

    fc:addFluid(FluidType.Water, waterToAdd)
    stats:set(CharacterStat.WETNESS, wetness - wetnessUsed)
end

-- Gradually normalize body temperature toward 37°C
local function normalizeTemperature(player)
    local stats = player:getStats()
    local temp = stats:get(CharacterStat.TEMPERATURE)
    if math.abs(temp - NORMAL_TEMP) <= 0.5 then return end

    local newTemp = temp + (NORMAL_TEMP - temp) * TEMP_LERP_RATE
    stats:set(CharacterStat.TEMPERATURE, newTemp)
end

local function forEachPlayer(fn)
    if isClient() or isServer() then
        local players = getOnlinePlayers()
        if not players then return end
        for i = 0, players:size() - 1 do
            fn(players:get(i))
        end
    else
        fn(getPlayer())
    end
end

local function updateSuit()
    forEachPlayer(function(player)
        if not player then return end
        local suit = getWornSuit(player)
        if suit then
            convertWetnessToSuitWater(player, suit)
            normalizeTemperature(player)
        end
    end)
end

Events.EveryOneMinute.Add(updateSuit)
