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

    local totalMass = 0
    local resolvedItems = {}
    for i = 1, #items do
        local item = resolveItem(items[i])
        if item then
            local m = ZSpaceship.Teleport.getMass(item)
            if m then
                totalMass = totalMass + m
                resolvedItems[#resolvedItems + 1] = item
            end
        end
    end

    if #resolvedItems == 0 then return end
    if totalMass < ZSpaceship.Teleport.MIN_MASS then return end

    local inSpace = zsInSpace(player)
    local cost = ZSpaceship.Teleport.getCost(player, inSpace, true, false, resolvedItems)

    local text = "UI_ZS_BeamItemToShip"
    if #resolvedItems > 1 then
        text = getText("UI_ZS_BeamItemsToShip", #resolvedItems)
    end

    ZSpaceship.Teleport.addTeleportOption(
        context,
        player,
        cost,
        text,
        function(p)
            local sq = p:getCurrentSquare()
            local x = sq and (sq:getX() + 0.5) or p:getX()
            local y = sq and (sq:getY() + 0.5) or p:getY()
            local z = sq and sq:getZ() or p:getZ()
            ISTimedActionQueue.add(
                ISZSpaceshipTeleportAction:new(p, x, y, z, "Energizing...", nil, false, false, resolvedItems)
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
zdk.hook({
    AnimalContextMenu = {
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

        -- playerNum here
        doInventoryMenu = function(orig, player, context, animalInv, ...)
            local result = orig(player, context, animalInv, ...)
            maybeAddTeleportOption(context, player, animalInv)
            return result
        end,
    }
})

Events.OnFillInventoryObjectContextMenu.Add(doBeamUpInventoryContextMenu)
