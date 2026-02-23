-- Space suit server-side effects (wetness-to-water conversion)
-- Runs every minute for each player wearing the suit
-- TODO: proper client/server

local WETNESS_TO_WATER_RATIO      = 0.01  -- 1 wetness point = 0.01 fluid units
local REPLENISH_OXYGEN_PER_MINUTE = 0.1

local function autoReplenishOxygen(player, suit)
    if zsInVacuum(player) or (player:getBuilding() and player:getBuilding():isToxic()) then return end

    local curAmt = suit:getUsedDelta()
    if curAmt >= 1.0 then return end

    suit:setUsedDelta(math.min(curAmt + REPLENISH_OXYGEN_PER_MINUTE, 1.0))
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

local plrRunState = {}

local function maybeToggleRunning(player, suit)
    if not player then return end

    local pid = (player.getId and player:getId()) or player

    if suit and suit:hasTag(ZSpaceship.Tags.SuppressRunning) then
        if plrRunState[pid] ~= 'SUPPRESSED' or player:isRunning() or player:isSprinting() then
            plrRunState[pid] = 'SUPPRESSED'
            player:setAllowSprint(false)
            player:setAllowRun(false)
            player:setRunning(false)
            player:setSprinting(false)
        end
        return
    end

    -- no suit or suit allows running, but was previously suppressed - restore
    if plrRunState[pid] == 'SUPPRESSED' then
        plrRunState[pid] = nil
        -- can setAllowSprint/setAllowRun be disabled by any other means?
        player:setAllowSprint(true)
        player:setAllowRun(true)
    end
end

local function updateSuit()
    forEachPlayer(function(player)
        if not player then return end

        local suit = ZSpaceship.getWornSuit(player)
        if suit then
            maybeToggleRunning(player, suit)
            if suit:hasTag(ZSpaceship.Tags.Wetness2Water) then
                convertWetnessToSuitWater(player, suit)
            end
            if suit:hasTag(ZSpaceship.Tags.AutoReplenish) then
                autoReplenishOxygen(player, suit)
            end
        end
    end)
end

Events.EveryOneMinute.Add(updateSuit)


-- TODO: tests
local function onClothingUpdated(chr)
    if not instanceof(chr, 'IsoPlayer') or not chr:isLocalPlayer() then return end

    maybeToggleRunning(chr, ZSpaceship.getWornSuit(chr))
end

Events.OnClothingUpdated.Add(onClothingUpdated)
