require "ZSpaceship_MapData"

-- Battery racks: accept only car batteries, max 20 per rack. Reuses vanilla Ah capacities.
ZSpaceship = ZSpaceship or {}
local EnergyStorage = {}
ZSpaceship.EnergyStorage = EnergyStorage

-- Car battery capacities (Ah), matching vanilla
EnergyStorage.batteryAh = {
    ["Base.CarBattery1"] = 50,
    ["Base.CarBattery2"] = 100,
    ["Base.CarBattery3"] = 75,
}

EnergyStorage.MAX_BATTERIES_PER_RACK = 20

-- Rack sprite(s) from ZSpaceship.MapData.Tiles.EnergyStorage (built at load time)
local function buildRackSprites()
    local tiles = ZSpaceship.MapData and ZSpaceship.MapData.Tiles and ZSpaceship.MapData.Tiles.EnergyStorage
    if tiles then
        local set = {}
        for _, name in ipairs(tiles) do
            set[name] = true
        end
        return set
    end
    print("[ZSpaceship] No energy storage tiles found!")
    return {}
end
EnergyStorage.rackSprites = buildRackSprites()

local function isRackObject(isoObject)
    if not isoObject then return false end
    local name = isoObject:getTextureName()
    return name and EnergyStorage.rackSprites[name] or false
end
EnergyStorage.isRackObject = isRackObject

local function isCarBattery(item)
    if not item then return false end
    local fullType = item:getFullType()
    return EnergyStorage.batteryAh[fullType] ~= nil
end
EnergyStorage.isCarBattery = isCarBattery

-- Ah for an item (0 if not a car battery). Exposed for UI or power logic.
function EnergyStorage.getBatteryAh(item)
    if not item then return 0 end
    return EnergyStorage.batteryAh[item:getFullType()] or 0
end

-- Count car batteries in a container
local function countCarBatteries(container)
    if not container then return 0 end
    local n = 0
    for i = 0, container:getItems():size() - 1 do
        local item = container:getItems():get(i)
        if isCarBattery(item) then
            n = n + 1
        end
    end
    return n
end

-- Only car batteries; max 20 per rack.
function EnergyStorage.AcceptItem(container, item)
    if not isCarBattery(item) then return false end
    return countCarBatteries(container) < EnergyStorage.MAX_BATTERIES_PER_RACK
end

local function configureRack(isoObject)
    if not isoObject then return end
    local container = isoObject:getContainer()
    if not container and isoObject.createContainersFromSpriteProperties then
        isoObject:createContainersFromSpriteProperties()
        container = isoObject:getContainer()
    end
    if container then
        container:setAcceptItemFunction("ZSpaceship.EnergyStorage.AcceptItem")
    end
end

-- Player-built objects
local function onObjectAdded(isoObject)
    if not ZSpaceship.isInSpace(isoObject) then return end
    if not isRackObject(isoObject) then return end

    configureRack(isoObject)
end
Events.OnObjectAdded.Add(onObjectAdded)

-- Map-created objects (initial load)
if MapObjects and MapObjects.OnNewWithSprite then
    for spriteName, _ in pairs(EnergyStorage.rackSprites) do
        MapObjects.OnNewWithSprite(spriteName, onObjectAdded, 50)
    end
end
