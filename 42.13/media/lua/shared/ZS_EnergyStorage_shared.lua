require "ZS_MapData"
require "ZS_EnergyStorage_constants"
-- TODO: split to client/server

local EnergyStorage = ZSpaceship.EnergyStorage

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

local function isCarBattery(item) -- used by client, server: TBD
    if not item then return false end
    local fullType = item:getFullType()
    return EnergyStorage.BATTERIES[fullType] ~= nil
end
EnergyStorage.isCarBattery = isCarBattery

-- Ah for an item (0 if not a car battery). Exposed for UI or power logic.
function EnergyStorage.getBatteryAh(item)
    if not item then return 0 end
    return EnergyStorage.BATTERIES[item:getFullType()] or 0
end

-- Count car batteries in a container
function EnergyStorage.countCarBatteries(container)
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

function EnergyStorage.calcTotalCapacity(container)
    if not container then return 0 end
    local capacity = 0
    for i = 0, container:getItems():size() - 1 do
        local item = container:getItems():get(i)
        capacity = capacity + EnergyStorage.getBatteryAh(item)
    end
    return capacity
end

-- Only car batteries; max 20 per rack.
function EnergyStorage.AcceptItem(container, item)
    if not isCarBattery(item) then return false end
    return EnergyStorage.countCarBatteries(container) < EnergyStorage.MAX_BATTERIES_PER_RACK
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
