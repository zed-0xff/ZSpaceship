require 'zHook'

local function resolveItem(entry)
    if instanceof(entry, "InventoryItem") or instanceof(entry, "IsoDeadBody") then
        return entry
    end
    if entry and entry.items and #entry.items > 0 then
        return entry.items[1]
    end
    return nil
end

local function doBeamUpInventoryContextMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player then return end

    local communicator = player:getInventory():getItemFromTag(ZSpaceship.Tags.Communicator, true, true)
    if not communicator then return end

    local targetItem = nil
    for i = 1, #items do
        local item = resolveItem(items[i])
        if item then
            local m = ZSpaceship.Teleport.getMass(item)
            if m and m >= ZSpaceship.Teleport.MIN_MASS then
                targetItem = item
                break
            end
        end
    end

    if not targetItem then return end

    local inSpace = zsInSpace(player)
    local cost = ZSpaceship.Teleport.getCost(player, inSpace, true, false, targetItem)

    ZSpaceship.Teleport.addTeleportOption(
        context,
        player,
        cost,
        "UI_ZS_BeamItemToShip",
        function(p)
            local sq = p:getCurrentSquare()
            local x = sq and (sq:getX() + 0.5) or p:getX()
            local y = sq and (sq:getY() + 0.5) or p:getY()
            local z = sq and sq:getZ() or p:getZ()
            ISTimedActionQueue.add(
                ISZSpaceshipTeleportAction:new(p, x, y, z, "Energizing...", nil, false, false, targetItem)
            )
        end,
        communicator,
        ZSpaceship.Teleport.SCIENCE_LEVEL_ITEM
    )
end

local function maybeAddTeleportOption(context, playerNum, animalbody)
    if not context or not playerNum or not animalbody then return end

    doBeamUpInventoryContextMenu(playerNum, context, { animalbody })
end

-- right-clicking an animal body in the world
zHook( AnimalContextMenu, {
    -- playerObj here
    doAnimalBodyMenuFromInv = function(orig, context, playerObj, animalbody, ...)
        local result = orig(context, playerObj, animalbody, ...)
        maybeAddTeleportOption(context, playerObj:getPlayerNum(), animalbody)
        return result
    end,

    -- playerNum here
    doAnimalBodyMenu = function(orig, context, player, animalbody, ...)
        local result = orig(context, player, animalbody, ...)
        maybeAddTeleportOption(context, player, animalbody)
        return result
    end,
})

Events.OnFillInventoryObjectContextMenu.Add(doBeamUpInventoryContextMenu)
