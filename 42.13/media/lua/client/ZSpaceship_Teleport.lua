-- ZSpaceship Teleport - Teleportation functions and context menus
require "TimedActions/ISTimedActionQueue"

-- Energy cost: 10 MJ/kg base, +50% if from/to building
ZSpaceship.TELEPORT_COST_PER_KG = 10  -- MJ/kg
ZSpaceship.TELEPORT_BUILDING_MULT = 1.5

function ZSpaceship.getTeleportMass(player)
    local bodyWeight = player:getNutrition():getWeight()
    local inventoryWeight = player:getInventory():getCapacityWeight()
    return bodyWeight + inventoryWeight
end

function ZSpaceship.isInBuilding(player)
    local sq = player:getCurrentSquare()
    if not sq or not sq:getBuilding() then
        return false
    end
    -- Spaceship doesn't count as a building for teleport cost
    local px, py = math.floor(player:getX()), math.floor(player:getY())
    if ZSpaceship.isInSpace(px, py) then
        return false
    end
    return true
end

function ZSpaceship.getTeleportCost(player, toBuilding)
    local mass = ZSpaceship.getTeleportMass(player)
    local cost = mass * ZSpaceship.TELEPORT_COST_PER_KG
    
    -- +50% if from or to building (spaceship excluded)
    local fromBuilding = ZSpaceship.isInBuilding(player)
    if fromBuilding or toBuilding then
        cost = cost * ZSpaceship.TELEPORT_BUILDING_MULT
    end
    
    return math.floor(cost)
end

function ZSpaceship.TeleportToRandom(player)
    -- Teleport to random location in the county (2000-13000), avoiding water and empty cells
    local x, y
    local maxAttempts = 100
    local metaGrid = getWorld():getMetaGrid()
    local found = false
    
    for i = 1, maxAttempts do
        x = ZombRand(2000, 16000)
        y = ZombRand(2000, 16000)
        
        -- Check if chunk has map data
        local chunkX = math.floor(x / 10)
        local chunkY = math.floor(y / 10)
        if metaGrid:isValidChunk(chunkX, chunkY) then
            -- Check for water zones at this location
            local zones = metaGrid:getZonesAt(x, y, 0)
            local isWater = false
            if zones then
                for j = 0, zones:size() - 1 do
                    local zone = zones:get(j)
                    local zoneType = zone:getType()
                    if zoneType == "DeepWater" or zoneType == "Water" or zoneType == "River" or zoneType == "Lake" then
                        isWater = true
                        break
                    end
                end
            end
            if not isWater then
                found = true
                break
            end
        end
    end
    
    ISTimedActionQueue.add(ISZSpaceshipTeleportAction:new(player, x + 0.5, y + 0.5, 0, "Energizing..."))
end

function ZSpaceship.TeleportToRandomBuilding(player)
    -- Teleport to a random room in a random building (vanilla county area only)
    local metaGrid = getWorld():getMetaGrid()
    local buildings = metaGrid:getBuildings()
    local buildingCount = buildings:size()
    
    -- Vanilla county bounds (avoid mod submaps like RV interiors)
    local minX, maxX = 2000, 16000
    local minY, maxY = 2000, 16000
    
    if buildingCount == 0 then
        print("[ZSpaceship] No buildings found!")
        return
    end
    
    local x, y, z = 0, 0, 0
    local maxAttempts = 100
    
    for i = 1, maxAttempts do
        local building = buildings:get(ZombRand(buildingCount))
        if building and building:getRooms() and building:getRooms():size() > 0 then
            local bx, by = building:getX(), building:getY()
            -- Only use buildings within vanilla county bounds
            if bx >= minX and bx <= maxX and by >= minY and by <= maxY then
                local room = building:getRandomRoom(6)
                if room and room:getW() > 2 and room:getH() > 2 then
                    -- Use center of room (corner might be at a wall)
                    x = room:getX() + math.floor(room:getW() / 2) + 0.5
                    y = room:getY() + math.floor(room:getH() / 2) + 0.5
                    z = room:getZ()
                    break
                end
            end
        end
    end
    
    if x == 0 and y == 0 then
        print("[ZSpaceship] Failed to find a valid building after " .. maxAttempts .. " attempts!")
        return
    end
    
    ISTimedActionQueue.add(ISZSpaceshipTeleportAction:new(player, x, y, z, "Energizing...", 2.0, true))
end

function ZSpaceship.TeleportToShip(player)
    local x = ZSpaceship.TeleporterX + 0.5
    local y = ZSpaceship.TeleporterY + 0.5
    
    -- Longer teleport time if inside a building
    local timeMult = 1.0
    local sq = player:getCurrentSquare()
    if sq and sq:getBuilding() then
        timeMult = 2.0
    end
    
    ISTimedActionQueue.add(ISZSpaceshipTeleportAction:new(player, x, y, ZSpaceship.TeleporterZ, "Beam me up, Scotty!", timeMult))
end

-- Context Menu for Teleporter (World Object)
local function doWorldContextMenu(playerNum, context, worldobjects, test)
    if test then return end
    local player = getSpecificPlayer(playerNum)
    
    -- Check if standing on teleporter pad (exact coordinates from compiled map)
    local px = math.floor(player:getX())
    local py = math.floor(player:getY())
    local pz = math.floor(player:getZ())
    
    if px == ZSpaceship.TeleporterX and py == ZSpaceship.TeleporterY and pz == ZSpaceship.TeleporterZ then
        local costSurface = ZSpaceship.getTeleportCost(player, false)
        local costBuilding = ZSpaceship.getTeleportCost(player, true)
        context:addOption(getText("UI_ZSpaceship_TeleportToCounty") .. " (" .. costSurface .. " MJ)", player, ZSpaceship.TeleportToRandom)
        context:addOption(getText("UI_ZSpaceship_TeleportToBuilding") .. " (" .. costBuilding .. " MJ)", player, ZSpaceship.TeleportToRandomBuilding)
    end
    
    -- Return to Spaceship option when NOT in space and has communicator
    if not ZSpaceship.isInSpace(px, py) then
        local communicator = player:getInventory():getItemFromTag(ZSpaceship.Tags.Communicator, true, true)
        if communicator then
            local costReturn = ZSpaceship.getTeleportCost(player, false)
            context:addOption(getText("UI_ZSpaceship_ReturnToSpaceship") .. " (" .. costReturn .. " MJ)", player, ZSpaceship.TeleportToShip)
        end
    end
end

-- Context Menu for Communicator (Inventory Item)
local function doInventoryContextMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    
    -- Check if right-clicked item is the Communicator
    local clickedCommunicator = false
    for i = 1, #items do
        local item = items[i]
        if not instanceof(item, "InventoryItem") then
            item = item.items[1]
        end
        if item and item:hasTag(ZSpaceship.Tags.Communicator) then
            clickedCommunicator = true
            break
        end
    end
    
    if clickedCommunicator then
        local px, py = math.floor(player:getX()), math.floor(player:getY())
        if not ZSpaceship.isInSpace(px, py) then
            local costReturn = ZSpaceship.getTeleportCost(player, false)
            context:addOption(getText("UI_ZSpaceship_ReturnToSpaceship") .. " (" .. costReturn .. " MJ)", player, ZSpaceship.TeleportToShip)
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(doWorldContextMenu)
Events.OnFillInventoryObjectContextMenu.Add(doInventoryContextMenu)
