require "ZS_MapData"

ZSpaceship = ZSpaceship or {}
ZSpaceship.Power = {
    batteryTiles = ZSpaceship.MapData.Tiles.EnergyStorage,
    batteries = {},
}

local MIN_CAPACITY  = 1000 -- with 0 batteries
local DEFAULT_POWER = 1000 -- Default power amount (used for new games)
local BATTERY_SIZE  = 1000

local _capacity               = MIN_CAPACITY
local _consumptionPerMinute   =  6 -- default batteries should last for a night if on full charge
local _maxProductionPerMinute = 20 -- TODO: count number of solar panels

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

local function getModData()
    return ModData and ModData.getOrCreate and ModData.getOrCreate("ZS_Power") or nil
end

local function setCapacityInModData(capacity)
    local modData = getModData()
    if modData then
        modData.capacity = capacity
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
            setCurrentAmountInModData(DEFAULT_POWER)
            setCapacityInModData(MIN_CAPACITY)
        else
            local modData = getModData()
            if modData then
                if not modData.currentAmount then
                    modData.currentAmount = DEFAULT_POWER
                end
                if modData.capacity then
                    _capacity = modData.capacity
                end
            end
        end
    end)
end

local function updateCapacity()
    _capacity = MIN_CAPACITY
    -- can't use # because batteries is a table, not an array T_T
    for _ in pairs(ZSpaceship.Power.batteries) do
        _capacity = _capacity + BATTERY_SIZE
    end
    setCapacityInModData(_capacity)
    print("ZS_Power.updateCapacity: " .. tostring(_capacity))
end

local function square2str(sq)
    return sq:getX() .. ":" .. sq:getY() .. ":" .. sq:getZ()
end

local function maybeAddBattery(isoObject)
    if not zsInSpace(isoObject) then return end
    if not isBattery(isoObject) then return end

    ZSpaceship.Power.batteries[square2str(isoObject:getSquare())] = isoObject
    updateCapacity()
end

for tileName in pairs(ZSpaceship.Power.batteryTiles) do
    MapObjects.OnNewWithSprite(tileName, maybeAddBattery, 100)  -- map loading
    MapObjects.OnLoadWithSprite(tileName, maybeAddBattery, 100) -- map loading?
end

-- called from scripts/entities/ZS_SolarPanel.txt
-- params = {
--     square            = zombie.iso.IsoGridSquare@3ac64f9,
--     tileInfo          = zombie.entity.components.spriteconfig.SpriteConfigManager$TileInfo@3e6312e3,
--     north             = true,
--     canBuildOverWater = false,
--     testCollisions    = true,
--     facing            = "single"
--  }
function ZSpaceship.Power.onIsValid(params)
    return BuildRecipeCode.floor.OnIsValid(params) and zsInSpace(params.square) and params.square:has(IsoFlagType.exterior)
end

-- called from scripts/entities/ZS_PSU.txt and ZS_SolarPanel.txt
-- params = {
--     thumpable       = ZS_PSU:zspaceship_3:zspaceship_3:zombie.iso.objects.IsoThumpable@3a34bc20, 
--     craftRecipeData = zombie.entity.components.crafting.recipe.CraftRecipeData@559ce917, 
--     character       = IsoPlayer{  Name:null,  ID:45 }, 
--     facing          = "single"
-- }
function ZSpaceship.Power.onCreate(params)
    maybeAddBattery(params.thumpable)
end

local function maybeRemoveBattery(isoObject)
    if not zsInSpace(isoObject) then return end
    if not isBattery(isoObject) then return end
    ZSpaceship.Power.batteries[square2str(isoObject:getSquare())] = nil
    updateCapacity()
end

Events.OnObjectAdded.Add(maybeAddBattery)
Events.OnTileRemoved.Add(maybeRemoveBattery)
