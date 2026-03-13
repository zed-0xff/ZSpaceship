-- Server-side teleport/beam logic: teleporter-room crate, item buffer, BeamItemToShip, FlushBeamBuffer.

ZSpaceship = ZSpaceship or {}

-- Hidden buffer container item used to hold beamed items while the ship cell isn't loaded.
local TPB_ITEM_ID = "ZSpaceship.TPBufferContainer"

-- Only valid when the space cell is loaded, i.e. when player is in the space cell.
local function findTeleportRoomCrateContainer(player)
    if not player or not zsInSpace(player) then return nil end

    local room = ZSRooms.find("zs_teleport_room")
    if not room then return nil end

    for _, sq in pairs(room:getSquares()) do
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

-- Find the buffer container for player (nil if not present).
local function getBufferContainer(player)
    local items = player:getInventory():getItemsFromFullType(TPB_ITEM_ID)
    if items:size() > 0 then
        return items:get(0):getItemContainer()
    end
end

-- Get or create the hidden TPBufferContainer in the player's inventory.
local function getOrCreateBufferContainer(player)
    local container = getBufferContainer(player)
    if container then return container end

    local item = instanceItem(TPB_ITEM_ID)
    player:getInventory():AddItem(item)
    return item:getItemContainer()
end


local function bufferItem(player, item)
    local bufCont = getOrCreateBufferContainer(player)
    if not bufCont or not item then return end
    ISTransferAction:transferItem( player, item, item:getContainer(), bufCont )
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
        player:getInventory():RemoveAll(TPB_ITEM_ID)
    end
end

function ZSpaceship.flushBeamBufferToShip(targetCont, player)
    if not targetCont then
        targetCont = findTeleportRoomCrateContainer(player)
        if not targetCont then return end
    end
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
        if item.becomeCorpseItem then
            item = item:becomeCorpseItem() -- convert IsoDeadBody to InventoryItem
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
        local parent = srcCont.getParent and srcCont:getParent()
        if parent and parent.sync then parent:sync() end
    else
        local worldItem = item.getWorldItem and item:getWorldItem() or nil
        if worldItem and worldItem.getSquare then
            local sq = worldItem:getSquare()
            if sq and sq.transmitRemoveItemFromSquare then
                sq:transmitRemoveItemFromSquare(worldItem)
                if sq.flagForHotSave then sq:flagForHotSave() end
            end
        end
    end

    targetCont:AddItem(item)
    if targetCont.setDrawDirty then
        targetCont:setDrawDirty(true)
    end

    if targetCont.sync then
        targetCont:sync()
    end

    return true
end

local function tryFindItem(cont, itemID)
    if not cont or not itemID then return nil end

    if cont.getID and cont:getID() == itemID then
        return cont
    end
    if cont.getItemById and cont:getItemById(itemID) then
        return cont:getItemById(itemID)
    end
    if cont.getItem then
        local it = cont:getItem()
        if it and it.getID and it:getID() == itemID then
            return it
        end
    end
    if cont.getItemContainer then
        local subCont = cont:getItemContainer()
        if subCont then
            local it = tryFindItem(subCont, itemID)
            if it then return it end
        end
    end
    if cont.getItems then
        local items = cont:getItems()
        if items then
            local it = tryFindItem(items, itemID)
            if it then return it end
        end
    end

    if cont.size and cont.get then
        for i = 0, cont:size() - 1 do
            local it = tryFindItem(cont:get(i), itemID)
            if it then return it end
        end
    end
    if zsIsArray(cont) then
        for _, v in ipairs(cont) do
            local it = tryFindItem(v, itemID)
            if it then return it end
        end
    end
end

-- Find an InventoryItem by ID, optionally scoped to a specific square table; falls back to near player.
local function findItemById(player, itemID, square)
    if not player or not itemID or not square then return nil end

    local searchables = {
        square.getWorldObjects and square:getWorldObjects(),
        square.getObjects and square:getObjects(),
        square.getStaticMovingObjects and square:getStaticMovingObjects(),
        square.getMovingObjects and square:getMovingObjects(),
        VehicleUtils.getContainers and VehicleUtils.getContainers(player:getPlayerNum()), -- TODO: test on MP. (includes player inventory)
    }

    for _, cont in ipairs(searchables) do
        local it = tryFindItem(cont, itemID)
        if it then return it end
    end

    -- Fallback: player inventory
    return tryFindItem(player:getInventory(), itemID)
end

-- Handle client commands (MP/SP): beam items to the ship's teleporter-room crate.
Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= "ZSpaceship" then return end

    if command == "BeamItemToShip" then
        if not player or not args then return end
        for sqID, itemID in pairs(args) do
            local item = findItemById(player, itemID, zsSquareFromString(sqID))
            if item then
                ZSpaceship.beamItemToShip(player, item)
            else
                print("[ZSpaceship] Failed to find item " .. tostring(itemID) .. " at " .. tostring(sqID))
            end
        end
    elseif command == "FlushBeamBuffer" then
        ZSpaceship.flushBeamBufferToShip(nil, player)
    end
end)

local function onLoadStorage(object)
    if not object or not object.getSquare then return end

    local sq = object:getSquare()
    print("[d] onLoadStorage", object, sq, sq:getRoom())

    local room = sq:getRoom()
    if room then
        print("[d] Room name: " .. tostring(room:getName()))
    end
    if room and room:getName() == "zs_teleport_room" then
        print("[d] Found teleport room storage on load, flushing buffer...")
        ZSpaceship.flushBeamBufferToShip(object:getItemContainer(), nil)
    end
end

-- when Space cell loads after player teleported to it, flush any buffered items into the teleporter room crate
for tileName in pairs(ZSpaceship.MapData.Tiles.Storage) do
    MapObjects.OnLoadWithSprite(tileName, onLoadStorage, 100)
end

-- fallback
Events.EveryTenMinutes.Add(function()
    local player = getPlayer()
    if zsInSpace(player) then
        ZSpaceship.flushBeamBufferToShip(nil, player)
    end
end)
