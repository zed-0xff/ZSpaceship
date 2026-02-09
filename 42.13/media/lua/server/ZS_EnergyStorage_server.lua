require "ZS_EnergyStorage_shared"

local EnergyStorage = ZSpaceship.EnergyStorage

local commands = {
    updateStorage = function(player, coords)
        if not coords or not coords.x or not coords.y or not coords.z then return end
        local sq = getSquare(coords.x, coords.y, coords.z)
        if not sq then return end

        local obj = sq:getObjectWithSprite(EnergyStorage.BASE_SPRITE)
        if obj and obj.getContainer then
            local container = obj:getContainer()
            if container and container:getType() == EnergyStorage.CONTAINER_TYPE then
                local count = EnergyStorage.countCarBatteries(container)
                if count == 0 then
                    obj:setOverlaySprite(nil)
                else
                    local chosenSprite = nil
                    local maxSprite = nil
                    for spriteName, range in pairs(EnergyStorage.OVERLAY_SPRITES) do
                        maxSprite = spriteName
                        if count >= range[1] and count <= range[2] then
                            chosenSprite = spriteName
                            break
                        end
                    end
                    obj:setOverlaySprite(chosenSprite or maxSprite)
                end
                -- TODO: update clients
            end
        end
    end
}

local function onClientCommand(module, command, player, args)
    if module ~= EnergyStorage.COMM_KEY then return end

    if commands[command] then
        commands[command](player, args)
    else
        print("[?} unknown command", module, command, player, args)
    end
end

if Events and Events.OnClientCommand and Events.OnClientCommand.Add then
    Events.OnClientCommand.Add(onClientCommand)
end