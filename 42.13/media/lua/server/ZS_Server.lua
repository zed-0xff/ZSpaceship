local logger = zdk.Logger.new("ZSpaceship")

-- Unlock a door/garage door object
-- TODO: figure out if the door can be created initially unlocked
ZS_Utils.initSpritesOnce("unlockDoor", ZSpaceship.MapData.DoorSprites, function(obj)
    if not zsInSpace(obj) then return end
    logger:debug("Unlocking door %s", tostring(obj))
    
    if obj.setLockedByKey then
        obj:setLockedByKey(false)
    end
    if obj.setLocked then
        obj:setLocked(false)
    end

    return true
end)


-- Remove all animals from the space cell
ZS_Utils.initOnce("removeAnimalsFromSpace", function()
    local cell = getCell()
    if not zsInSpace(cell) then return end

    local removed = 0
    local objects = cell:getObjectList()
    if not objects then return end

    -- Iterate backwards since we're removing
    for i = objects:size() - 1, 0, -1 do
        local obj = objects:get(i)
        if obj and instanceof(obj, "IsoAnimal") and zsInSpace(obj) then
            obj:removeFromWorld()
            obj:removeFromSquare()
            removed = removed + 1
        end
    end
    logger:debug("removed %d animals from space cell", removed)
    return true
end)


local function squareHasFloor(sq)
    if not sq then return false end
    local floorTiles = ZSpaceship.MapData and ZSpaceship.MapData.Tiles and ZSpaceship.MapData.Tiles["Floor"]
    if not floorTiles then return true end
    local tile = sq:getTileFloor()
    if not tile then return false end
    local name = tile:getName()
    if not name then return false end

    return floorTiles[name] ~= nil
end

-- Get ship room bounds from MapData (Default.Rooms or runtime Rooms); z = most frequent z in rooms
local function getShipRoomBounds()
    local rooms = (ZSpaceship.MapData and ZSpaceship.MapData.Rooms) or
        (ZSpaceship.MapData and ZSpaceship.MapData.Default and ZSpaceship.MapData.Default.Rooms)
    if not rooms or #rooms == 0 then return nil end
    local minX, maxX = rooms[1].x, rooms[1].x
    local minY, maxY = rooms[1].y, rooms[1].y
    local zCount = {}
    for i = 1, #rooms do
        local r = rooms[i]
        local z = r.z or 0
        zCount[z] = (zCount[z] or 0) + 1
        if r.x < minX then minX = r.x end
        if r.x > maxX then maxX = r.x end
        if r.y < minY then minY = r.y end
        if r.y > maxY then maxY = r.y end
    end
    local bestZ, bestCount = nil, 0
    for z, count in pairs(zCount) do
        if count > bestCount then bestZ = z; bestCount = count end
    end
    return { minX = minX, maxX = maxX, minY = minY, maxY = maxY, z = bestZ or 0 }
end

--- One-time spawn of N zombies in space suits on the ship.
-- Runs from EveryOneMinute until the space cell is available; then spawns a random
-- count N (between SandboxVars.ZSpaceship.ShipZombieCountMin and ShipZombieCountMax)
-- at random floor positions in ship rooms, using outfit "ZSpaceship_SpaceSuit" (from
-- clothing.xml). Unregisters itself after running once (ZSpaceship.InitialZombiesSpawned).
ZS_Utils.initOnce("initialShipZombieSpawn", function()
    local cell = getCell()
    if not zsInSpace(cell) then return end

    local bounds = getShipRoomBounds()
    if not bounds then return end

    -- Don't require testSq: spawn even if current cell isn't space cell (game may place when chunk loads)
    local minCount, maxCount = 0, 10
    if SandboxVars and SandboxVars.ZSpaceship then
        local v = SandboxVars.ZSpaceship
        if type(v.ShipZombieCountMin) == "number" then minCount = math.max(0, math.min(100, v.ShipZombieCountMin)) end
        if type(v.ShipZombieCountMax) == "number" then maxCount = math.max(0, math.min(100, v.ShipZombieCountMax)) end
    end
    if minCount > maxCount then minCount, maxCount = maxCount, minCount end
    local spawned = 0
    local N = ZombRand(minCount, maxCount + 1)
    if N > 0 then
        local rooms = (ZSpaceship.MapData and ZSpaceship.MapData.Rooms) or
                      (ZSpaceship.MapData and ZSpaceship.MapData.Default and ZSpaceship.MapData.Default.Rooms)
        local maxAttempts = N * 5
        for attempt = 1, maxAttempts do
            if spawned >= N then break end
            local x, y
            local useRoomCenter = false
            if rooms and #rooms > 0 then
                local r = rooms[ZombRand(1, #rooms + 1)]
                x = r.x
                y = r.y
                useRoomCenter = true
            else
                x = ZombRand(bounds.minX, bounds.maxX + 1)
                y = ZombRand(bounds.minY, bounds.maxY + 1)
            end
            local sq = cell:getGridSquare(x, y, bounds.z)
            if useRoomCenter or squareHasFloor(sq) then
                local list = addZombiesInOutfit(x, y, bounds.z, 1, ZSpaceship.ZOMBIE_OUTFIT_ID, 50)
                if list and list.size and list:size() > 0 then
                    spawned = spawned + 1
                end
            end
        end
    end
    logger:debug("Initial spawn: added %d space zombies (sandbox count: %d)", spawned, N)
    return true
end)


Events.OnFillContainer.Add(function(a, b, container)
    if not container then return end
    if not instanceof(container, "ItemContainer") then return end -- it may be a java class: zombie.inventory.ItemPickerJava$ItemPickerContainer

    -- Zombie	            ZSpaceship_SpaceSuit	ItemContainer:[type:inventorymale, parent:IsoDeadBody{ ... }]
    -- Only add Communicator when outfit is space suit AND container already has the space suit (from loot roll), so vanilla zombies never get it.
    if a == "Zombie" then
        local outfit_id = b
        if outfit_id == ZSpaceship.ZOMBIE_OUTFIT_ID then
            local hasSuit = container:getItemFromTag(ZSpaceship.Tags.SpaceSuit, false, true) ~= nil
            if hasSuit then
                if ZSpaceship and ZSpaceship.Debug then
                    logger:debug("Filling container for space zombie: %s", tostring(container))
                end
                container:AddItem("ZSpaceship.Communicator_Left")
                local suit = container:getItemFromTag(ZSpaceship.Tags.SpaceSuit, false, true)
                if suit and suit.setTankType and suit.setUsedDelta then
                    suit:setTankType("Base.Oxygen_Tank")
                    suit:setUsedDelta(ZombRandFloat(0,1))
                end
            end
        else
            if container.RemoveAll then
                container:RemoveAll("ZSpaceship.Communicator_Left")
                container:RemoveAll("ZSpaceship.Communicator_Right")
            end
        end
        return
    end

    local room_name, container_type = a, b

    -- zs_energy_storage	crate	                ItemContainer:[type:crate, parent:null:zspaceship_0:zspaceship_0:zombie.iso.IsoObject@3696d8eb]
    if room_name == "zs_energy_storage" and container_type == "crate" then
        container:AddItem("ZSpaceship.PowerStorageUnit_Schematic")
        container:AddItem("ZSpaceship.SolarPanel_Schematic")
        return
    end

    if room_name == "medical" and ZS_Utils.isRecycler(container) then
        container:removeAllItems()
        if container.setCustomName then
            container:setCustomName(getText("UI_ZS_Recycler")) -- XXX TODO: check in MP
        end
        return
    end
end)
