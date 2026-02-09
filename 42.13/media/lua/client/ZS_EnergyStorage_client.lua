-- in /client because ISInventoryTransferAction is in /client
require "TimedActions/ISInventoryTransferAction"
require "ZS_EnergyStorage_shared"
require "ZS_Utils"

local EnergyStorage = ZSpaceship.EnergyStorage

local function getContainerType(container)
    if not container then return nil end
    if not container.getType then return nil end
    return container:getType()
end

local function serializeCoords(x)
    if not x then return nil end
    if not x.getSquare then return nil end
    local sq = x:getSquare()
    if not sq then return nil end
    return {
        x = sq:getX(),
        y = sq:getY(),
        z = sq:getZ(),
    }
end

local function maybeUpdateStorage(action)
    if not action then return end
    if not action.item then return end
    if not action.character then return end
    if not EnergyStorage.isCarBattery(action.item) then return end

    local srcType = getContainerType(action.srcContainer)
    if srcType == EnergyStorage.CONTAINER_TYPE then
        sendClientCommand(
            action.character, 
            EnergyStorage.COMM_KEY, 
            "updateStorage", 
            serializeCoords(action.srcContainer)
        )
    end

    local destType = getContainerType(action.destContainer)
    if destType == EnergyStorage.CONTAINER_TYPE then
        sendClientCommand(
            action.character, 
            EnergyStorage.COMM_KEY, 
            "updateStorage", 
            serializeCoords(action.destContainer)
        )
    end
end

zsHook(ISInventoryTransferAction, {
    perform = function(orig, self)
        pcall(maybeUpdateStorage, self)
        orig(self) -- XXX may overwrite self.item and other fields!
    end
})