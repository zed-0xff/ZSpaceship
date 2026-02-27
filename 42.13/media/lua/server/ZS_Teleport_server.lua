-- Server-side teleport/beam logic: teleporter-room crate, item buffer, BeamItemToShip, FlushBeamBuffer.

ZSpaceship = ZSpaceship or {}

-- Hidden buffer container item used to hold beamed items while the ship cell isn't loaded.
local TELEPORT_BUFFER_FULL_TYPE = "ZSpaceship.TeleportBufferContainer"

-- Only valid when the space cell is loaded, i.e. when player is in the space cell.
local function findTeleportRoomCrateContainer(player)
    if not player or not zsInSpace(player) then return nil end
    local zsRoom = ZSRooms.find("zs_teleport_room")
    if not zsRoom or not zsRoom.squares then return nil end

    for _, sq in ipairs(zsRoom:getSquares()) do
        if sq and sq.getObjects then
            local objects = sq:getObjects()
            if objects then
                for k = 0, objects:size() - 1 do
                    local obj = objects:get(k)
                    if obj and obj.getItemContainer then
                        local cont = obj:getItemContainer()
                        if cont and cont:getType() == "crate" then
                            return cont
                        end
                    end
                end
            end
        end
    end

    return nil
end

-- Get or create the hidden TeleportBufferContainer in the player's inventory.
local function getOrCreateBufferContainer(player)
    if not player or not player.getInventory then return nil end
    local inv = player:getInventory()
    if not inv or not inv.getItems then return nil end

    local items = inv:getItems()
    if items then
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            if it and it.getFullType and it:getFullType() == TELEPORT_BUFFER_FULL_TYPE and it.getItemContainer then
                return it:getItemContainer()
            end
        end
    end

    local bufferItem = instanceItem(TELEPORT_BUFFER_FULL_TYPE)
    if not bufferItem then return nil end

    inv:AddItem(bufferItem)
    return bufferItem:getItemContainer()
end

-- Find the buffer container in player inventory (nil if not present).
local function getBufferContainer(player)
    if not player or not player.getInventory then return nil end
    local inv = player:getInventory()
    if not inv or not inv.getItems then return nil end
    local items = inv:getItems()
    if not items then return nil end

    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if it and it.getFullType and it:getFullType() == TELEPORT_BUFFER_FULL_TYPE and it.getItemContainer then
            return it:getItemContainer()
        end
    end

    return nil
end

local function bufferItem(player, item)
    local bufCont = getOrCreateBufferContainer(player)
    if not bufCont or not item then return end
    bufCont:AddItem(item)
end

local function flushBeamBuffer(targetCont, player)
    if not targetCont or not player then return end
    local bufCont = getBufferContainer(player)
    if not bufCont or not bufCont.getItems then return end

    local items = bufCont:getItems()
    if not items then return end

    -- Copy to Lua table first since we'll be mutating the container.
    local list = {}
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if it then
            table.insert(list, it)
        end
    end

    for _, it in ipairs(list) do
        if bufCont.DoRemoveItem then
            bufCont:DoRemoveItem(it)
        else
            bufCont:Remove(it)
        end
        targetCont:AddItem(it)
    end

    -- If the buffer container is now empty, remove the hidden item from the player's inventory.
    if bufCont.isEmpty and bufCont:isEmpty() then
        local inv = player.getInventory and player:getInventory() or nil
        if inv and inv.RemoveAll then
            inv:RemoveAll(TELEPORT_BUFFER_FULL_TYPE)
        end
    end
end

function ZSpaceship.flushBeamBufferToShip(player)
    local targetCont = findTeleportRoomCrateContainer(player)
    if not targetCont then return end
    flushBeamBuffer(targetCont, player)
end

-- Server-side helper: beam a single item to the spaceship teleporter-room crate.
-- Returns true on success, false on failure.
function ZSpaceship.beamItemToShip(player, item)
    if not player or not item then return false end

    local requiredLevel = ZSpaceship.Teleport.SCIENCE_LEVEL_ITEM
    if Perks and Perks.Science and player.getPerkLevel then
        if player:getPerkLevel(Perks.Science) < requiredLevel then
            if player.Say then
                player:Say(getText("UI_ZS_ScienceRequired", requiredLevel))
            end
            return false
        end
    end

    local targetCont = findTeleportRoomCrateContainer(player)
    if not targetCont then
        -- Teleporter room not loaded yet: remove the item from the world and stash it in the hidden buffer.
        local srcCont = item.getItemContainer and item:getItemContainer() or nil
        if srcCont and srcCont.DoRemoveItem then
            srcCont:DoRemoveItem(item)
        else
            local worldItem = item.getWorldItem and item:getWorldItem() or nil
            if worldItem and worldItem.getSquare then
                local sq = worldItem:getSquare()
                if sq and sq.transmitRemoveItemFromSquare then
                    sq:transmitRemoveItemFromSquare(worldItem)
                end
            end
        end

        bufferItem(player, item)
        return true
    end

    -- If crate is available, first flush any buffered items into it.
    flushBeamBuffer(targetCont, player)

    -- Remove this item from its current location (inventory/container or world).
    local srcCont = item.getItemContainer and item:getItemContainer() or nil
    if srcCont and srcCont.DoRemoveItem then
        srcCont:DoRemoveItem(item)
    else
        local worldItem = item.getWorldItem and item:getWorldItem() or nil
        if worldItem and worldItem.getSquare then
            local sq = worldItem:getSquare()
            if sq and sq.transmitRemoveItemFromSquare then
                sq:transmitRemoveItemFromSquare(worldItem)
            end
        end
    end

    targetCont:AddItem(item)

    return true
end

-- Find an InventoryItem by ID, optionally scoped to a specific square table; falls back to near player.
local function findItemById(player, itemID, square)
    if not player or not itemID or not square then return nil end

    local function searchSquare(sq)
        if not sq then return nil end

        -- World inventory objects on the square
        local worldObjs = sq.getWorldObjects and sq:getWorldObjects()
        if worldObjs then
            for i = 0, worldObjs:size() - 1 do
                local wo = worldObjs:get(i)
                if wo and wo.getItem then
                    local it = wo:getItem()
                    if it and it.getID and it:getID() == itemID then
                        return it
                    end
                end
            end
        end

        -- Items inside containers on the square (e.g. corpses, crates, movables)
        local objects = sq.getObjects and sq:getObjects()
        if objects then
            for i = 0, objects:size() - 1 do
                local obj = objects:get(i)
                if obj and obj.getItemContainer then
                    local cont = obj:getItemContainer()
                    if cont and cont.getItems then
                        local items = cont:getItems()
                        if items then
                            for j = 0, items:size() - 1 do
                                local it = items:get(j)
                                if it and it.getID and it:getID() == itemID then
                                    return it
                                end
                            end
                        end
                    end
                end
            end
        end

        return nil
    end

    local found = searchSquare(square)
    if found then return found end

    -- Fallback: player inventory
    local inv = player:getInventory()
    if inv and inv.getItemById then
        local item = inv:getItemById(itemID)
        if item then return item end
    end

    return nil
end

-- Handle client commands (MP/SP): beam items to the ship's teleporter-room crate.
Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= "ZSpaceship" then return end

    if command == "BeamItemToShip" then
        if not player or not args or not args.itemID then return end

        local item = findItemById(player, args.itemID, ZS_Utils.tableToSquare(args.square))
        if item then
            ZSpaceship.beamItemToShip(player, item)
        else
            print("[ZSpaceship] Failed to find item by ID: " .. serialize(args))
        end
    elseif command == "FlushBeamBuffer" then
        ZSpaceship.flushBeamBufferToShip(player)
    end
end)
