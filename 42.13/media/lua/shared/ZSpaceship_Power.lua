ZSpaceship = ZSpaceship or {}
ZSpaceship.Power = {}

local _maxAmount = 3000
local _consumptionPerTick = 0.1
local _maxProductionPerTick = 0.2 -- TODO: count number of solar panels

-- Default power amount (used for new games)
local DEFAULT_POWER = 1000

-- Get current power from ModData (synced between client/server)
local function getCurrentAmountFromModData()
    if ModData and ModData.getOrCreate then
        local modData = ModData.getOrCreate("ZSpaceship_Power")
        if modData and modData.currentAmount then
            return modData.currentAmount
        end
    end
    return DEFAULT_POWER
end

-- Set current power in ModData (synced between client/server)
local function setCurrentAmountInModData(amount)
    if ModData and ModData.getOrCreate then
        local modData = ModData.getOrCreate("ZSpaceship_Power")
        if modData then
            modData.currentAmount = amount
        end
    end
end

function ZSpaceship.Power.getCurrentAmount()
    local amount = getCurrentAmountFromModData()
    return math.floor(amount)
end

function ZSpaceship.Power.getMaxAmount()
    return _maxAmount
end

function ZSpaceship.Power.consume(amount)
    if amount <= 0 then return end

    local current = getCurrentAmountFromModData()
    current = current - amount
    if current < 0 then
        current = 0
    end
    setCurrentAmountInModData(current)
end

function ZSpaceship.Power.add(amount)
    if amount <= 0 then return end

    local current = getCurrentAmountFromModData()
    current = current + amount
    if current > _maxAmount then
        current = _maxAmount
    end
    setCurrentAmountInModData(current)
end

-- Power update (client-only, uses getClimateManager)
local function updatePower()
    -- Only run on client (getClimateManager is client-only)
    if not getClimateManager then return end
    
    local current = getCurrentAmountFromModData()
    local prod = _maxProductionPerTick * getClimateManager():getDayLightStrength()

    current = current + prod - _consumptionPerTick

    if current >= _maxAmount then
        current = _maxAmount
    elseif current < 0 then
        current = 0
    end
    
    setCurrentAmountInModData(current)
end

-- Only add the update event on client
if Events and Events.OnTick and getClimateManager then
    Events.OnTick.Add(updatePower)
end

-- Initialize power on game start
if Events and Events.OnInitGlobalModData then
    Events.OnInitGlobalModData.Add(function(isNewGame)
        if isNewGame then
            -- New game: set default power
            setCurrentAmountInModData(DEFAULT_POWER)
        else
            -- Existing game: ensure ModData exists (will load from save)
            if ModData and ModData.getOrCreate then
                local modData = ModData.getOrCreate("ZSpaceship_Power")
                if not modData.currentAmount then
                    modData.currentAmount = DEFAULT_POWER
                end
            end
        end
    end)
end
