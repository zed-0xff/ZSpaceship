-- Space suit server-side effects (wetness-to-water conversion)
-- Runs every minute for each player wearing the suit

local WETNESS_TO_WATER_RATIO = 0.01  -- 1 wetness point = 0.01 fluid units

local function getWornSuit(player)
    local wornItems = player:getWornItems()
    for i = 0, wornItems:size() - 1 do
        local item = wornItems:getItemByIndex(i)
        if item and item:getFullType() == "ZSpaceship.SpaceSuitA" then
            return item
        end
    end
end

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

local function toggleRunning(player, bAllow)
    if not player then return end

    player:setAllowSprint(bAllow)
    player:setAllowRun(bAllow)

    if not bAllow then
        player:setRunning(false)
        player:setSprinting(false)
    end
end

local function updateSuit()
    forEachPlayer(function(player)
        if not player then return end

        local suit = getWornSuit(player)
        if suit then
            convertWetnessToSuitWater(player, suit)
            toggleRunning(player, false)
        end
    end)
end

Events.EveryOneMinute.Add(updateSuit)


-- TODO: tests
local function onClothingUpdated(chr)
    if not instanceof(chr, 'IsoPlayer') or not chr:isLocalPlayer() then return end

    local suit = getWornSuit(chr)
    toggleRunning(chr, suit ~= nil)
end

Events.OnClothingUpdated.Add(onClothingUpdated)
