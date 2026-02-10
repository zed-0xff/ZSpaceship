require "ZS_MapData"

ZSpaceship = ZSpaceship or {}
ZSpaceship.Power = {
    batteryTiles = {},
    batteries = {},
}

local _capacity = 0
local _consumptionPerMinute   = 25
local _maxProductionPerMinute = 50 -- TODO: count number of solar panels

local DEFAULT_POWER = 1000 -- Default power amount (used for new games)
local BATTERY_SIZE  = 1000

for _, tile in pairs(ZSpaceship.MapData.Tiles.EnergyStorage) do
    ZSpaceship.Power.batteryTiles[tile] = true
end

local function isBattery(obj)
    if not obj then return false end
    if not obj.getSprite then return false end

    local sprite = obj:getSprite()
    if not sprite then return false end

    local spriteName = sprite.getName and sprite:getName()
    if not spriteName then return false end

    return ZSpaceship.Power.batteryTiles[spriteName]
end

-- Get current power from ModData (synced between client/server)
local function getAmountFromModData()
    if ModData and ModData.getOrCreate then
        local modData = ModData.getOrCreate("ZS_Power")
        if modData and modData.currentAmount then
            return modData.currentAmount
        end
    end
    return DEFAULT_POWER
end

-- Set current power in ModData (synced between client/server)
local function setCurrentAmountInModData(amount)
    if ModData and ModData.getOrCreate then
        local modData = ModData.getOrCreate("ZS_Power")
        if modData then
            modData.currentAmount = amount
        end
    end
end

function ZSpaceship.Power.getAmount()
    local amount = getAmountFromModData()
    return math.floor(amount)
end

function ZSpaceship.Power.getCapacity()
    return _capacity
end

function ZSpaceship.Power.consume(amount)
    if amount <= 0 then return end

    local current = getAmountFromModData()
    current = current - amount
    if current < 0 then
        current = 0
    end
    setCurrentAmountInModData(current)
end

function ZSpaceship.Power.add(amount)
    if amount <= 0 then return end

    local current = getAmountFromModData()
    current = current + amount
    if current > _capacity then
        current = _capacity
    end
    setCurrentAmountInModData(current)
end

-- Power update (client-only, uses getClimateManager)
local function updatePower()
    local current = getAmountFromModData()
    local prod = _maxProductionPerMinute * getClimateManager():getDayLightStrength()

    current = current + prod - _consumptionPerMinute

    if current >= _capacity then
        current = _capacity
    elseif current < 0 then
        current = 0
    end
    
    setCurrentAmountInModData(current)
end

Events.EveryOneMinute.Add(updatePower)

-- Initialize power on game start
if Events and Events.OnInitGlobalModData then
    Events.OnInitGlobalModData.Add(function(isNewGame)
        if isNewGame then
            -- New game: set default power
            setCurrentAmountInModData(DEFAULT_POWER)
        else
            -- Existing game: ensure ModData exists (will load from save)
            if ModData and ModData.getOrCreate then
                local modData = ModData.getOrCreate("ZS_Power")
                if not modData.currentAmount then
                    modData.currentAmount = DEFAULT_POWER
                end
            end
        end
    end)
end

local function updateCapacity()
    _capacity = 0
    -- can't use # because batteries is a table, not an array T_T
    for _ in pairs(ZSpaceship.Power.batteries) do
        _capacity = _capacity + BATTERY_SIZE
    end
end

local function square2str(sq)
    return sq:getX() .. ":" .. sq:getY() .. ":" .. sq:getZ()
end

local function maybeAddBattery(isoObject)
    print("maybeAddBattery", isoObject)
    print("sprite name", isoObject:getSprite():getName())
    if not ZSpaceship.isInSpace(isoObject) then return end
    if not isBattery(isoObject) then return end
    ZSpaceship.Power.batteries[square2str(isoObject:getSquare())] = isoObject
    updateCapacity()
end

for tileName in pairs(ZSpaceship.Power.batteryTiles) do
    MapObjects.OnNewWithSprite(tileName, maybeAddBattery, 100)  -- map loading
    MapObjects.OnLoadWithSprite(tileName, maybeAddBattery, 100) -- map loading?
end

local function maybeRemoveBattery(isoObject)
    if not ZSpaceship.isInSpace(isoObject) then return end
    if not isBattery(isoObject) then return end
    ZSpaceship.Power.batteries[square2str(isoObject:getSquare())] = nil
    updateCapacity()
end

Events.OnObjectAdded.Add(maybeAddBattery)
Events.OnTileRemoved.Add(maybeRemoveBattery)
