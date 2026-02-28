-- ZSpaceship Teleport - Teleportation functions and context menus
require "TimedActions/ISTimedActionQueue"

ZSpaceship = ZSpaceship or {}
ZSpaceship.Teleport = ZSpaceship.Teleport or {}

local function addTeleportOption(context, player, cost, textKey, cb, comm, requiredPerkLevel)
    requiredPerkLevel = requiredPerkLevel or ZSpaceship.Teleport.SCIENCE_LEVEL_MIN
    local currentPower = 0
    if ZSpaceship and ZSpaceship.Power then
        currentPower = ZSpaceship.Power.getAmount()
    end
    local scienceLevel = player:getPerkLevel(Perks.Science)
    local text = getText(textKey, cost, currentPower)
    local opt = context:addOption(text, player, cb)
    
    -- Check perk level and power requirements
    local notAvailable = false
    local tooltip = nil
    if scienceLevel < requiredPerkLevel then
        notAvailable = true
        tooltip = ISToolTip:new()
        tooltip:setName(getText("UI_ZS_ScienceRequired", requiredPerkLevel))
    elseif currentPower < cost then
        notAvailable = true
        tooltip = ISToolTip:new()
        tooltip:setName(getText("UI_ZS_InsufficientPower", cost, currentPower))
    end
    
    opt.notAvailable = notAvailable
    opt.toolTip = tooltip
    
    if comm then
        local scriptItem = comm.getScriptItem and comm:getScriptItem() or nil
        if scriptItem and scriptItem.getNormalTexture then
            opt.iconTexture = scriptItem:getNormalTexture()
        end
    end
end

ZSpaceship.Teleport.addTeleportOption = addTeleportOption

local function addReturnToShipOption(context, player, communicator)
    local inSpace = zsInSpace(player)
    local z = player:getZ() or 0
    if not inSpace and z < 0 then
        local opt = context:addOption(getText("UI_ZS_TeleportBlockedSubsurface"), player, function() end)
        opt.notAvailable = true
        opt.toolTip = ISToolTip:new()
        opt.toolTip:setName(getText("UI_ZS_TeleportBlockedSubsurface"))
    else
        local costReturn = ZSpaceship.Teleport.getCost(player, inSpace, true, false)
        addTeleportOption(context, player, costReturn, "UI_ZS_ReturnToSpaceship", function(p) ZSpaceship.Teleport.toShip(p, inSpace) end, communicator, ZSpaceship.Teleport.SCIENCE_LEVEL_MIN)
    end
end

function ZSpaceship.Teleport.getMass(obj)
    if not obj then return 0 end

    -- Player or any character with nutrition + inventory
    if obj.getNutrition and obj.getInventory then
        local bodyWeight = 0
        local invWeight = 0
        local nutrition = obj:getNutrition()
        if nutrition and nutrition.getWeight then
            bodyWeight = nutrition:getWeight()
        end
        local inv = obj:getInventory()
        if inv and inv.getCapacityWeight then
            invWeight = inv:getCapacityWeight()
        end
        return bodyWeight + invWeight
    end

    -- Inventory item
    if instanceof(obj, "InventoryItem") then
        local w = (obj.getActualWeight and obj:getActualWeight()) or (obj.getWeight and obj:getWeight()) or 0
        return w
    end

    -- World inventory object (wrapper around InventoryItem)
    if obj.getItem then
        local item = obj:getItem()
        if item then
            return ZSpaceship.Teleport.getMass(item)
        end
    end

    -- Any IsoObject with a container (e.g. movable with internal inventory)
    if obj.getItemContainer then
        local cont = obj:getItemContainer()
        if cont and cont.getCapacityWeight then
            return cont:getCapacityWeight()
        end
    end

    -- Fallback: treat unknown objects as negligible mass
    return 0
end

function ZSpaceship.Teleport.isInBuilding(obj)
    local sq = ZS_Utils.getSquare(obj)
    if not sq then return nil end

    if not sq:getBuilding() then return false end

    -- Spaceship doesn't count as a building for teleport cost
    return not zsInSpace(obj)
end

-- Calculate teleport cost
-- @param player: The player teleporting
-- @param fromSpace: Whether teleporting FROM space (spaceship)
-- @param toSpace: Whether teleporting TO space (spaceship)
-- @param toBuilding: Whether teleporting TO a building (only valid when toSpace is false)
function ZSpaceship.Teleport.getCost(player, fromSpace, toSpace, toBuilding, object)
    object = object or player
    toBuilding = toBuilding or false
    local mass = ZSpaceship.Teleport.getMass(object)
    local cost = mass * ZSpaceship.Teleport.COST_PER_KG
    
    -- Much cheaper if teleporting within space (both from and to space)
    if fromSpace and toSpace then
        cost = cost * ZSpaceship.Teleport.SPACE2SPACE_MULT
    else
        -- +50% if from or to building (spaceship excluded)
        local fromBuilding = false
        if not fromSpace then
            fromBuilding = ZSpaceship.Teleport.isInBuilding(object)
        end
        if fromBuilding or toBuilding then
            cost = cost * ZSpaceship.Teleport.BUILDING_MULT
        end
    end
    
    -- Apply Science perk discount: 5% per level
    local scienceLevel = player:getPerkLevel(Perks.Science)
    local discount = scienceLevel * 0.05  -- 5% per level
    cost = cost * (1 - discount)

    if ZItemTiers and ZItemTiers.GetItemTierIndex then
        local comm = player:getInventory():getItemFromTag(ZSpaceship.Tags.Communicator, true, true)
        if comm then
            local tier = ZItemTiers.GetItemTierIndex(comm)
            if tier and tier > 1 then
                cost = cost * (1 - (tier-1) * 0.1)  -- Each tier after the first reduces cost by 10%
            end
        end
    end
    
    return zsClamp(math.floor(cost), 100, 2000)
end

function ZSpaceship.Teleport.toRandom(player)
    -- Check Science perk level
    if player:getPerkLevel(Perks.Science) < ZSpaceship.Teleport.SCIENCE_LEVEL_MIN then
        player:Say(getText("UI_ZS_ScienceRequired", ZSpaceship.Teleport.SCIENCE_LEVEL_MIN))
        return
    end
    
    -- Check power before teleporting (from space, to surface, not to building)
    local cost = ZSpaceship.Teleport.getCost(player, true, false, false)
    if ZSpaceship and ZSpaceship.Power then
        local currentPower = ZSpaceship.Power.getAmount()
        if currentPower < cost then
            player:Say(getText("UI_ZS_InsufficientPower", cost, currentPower))
            return
        end
    end
    
    -- Teleport to random location in the county (2000-13000), avoiding water and empty cells
    -- Bias toward civilization: prefer locations near buildings (50% of attempts)
    local x, y
    local maxAttempts = 100
    local metaGrid = getWorld():getMetaGrid()
    local found = false
    local buildings = metaGrid:getBuildings()
    local buildingCount = buildings and buildings:size() or 0
    
    for i = 1, maxAttempts do
        -- 50% of attempts: try to land near buildings (civilization)
        -- 50% of attempts: pure random (still looks random)
        if buildingCount > 0 and ZombRand(100) < 50 then
            -- Pick a random building and land near it (30-150 tiles away)
            local building = buildings:get(ZombRand(buildingCount))
            if building then
                local bx, by = building:getX(), building:getY()
                -- Only use buildings within vanilla county bounds
                if bx >= 2000 and bx <= 16000 and by >= 2000 and by <= 16000 then
                    -- Random offset from building (30-150 tiles away)
                    local angle = ZombRandFloat(0, 2 * math.pi)
                    local distance = ZombRandFloat(10, 150)
                    x = math.floor(bx + math.cos(angle) * distance)
                    y = math.floor(by + math.sin(angle) * distance)
                    -- Clamp to valid range
                    x = math.max(2000, math.min(16000, x))
                    y = math.max(2000, math.min(16000, y))
                else
                    -- Building out of bounds, fallback to random
                    x = ZombRand(2000, 16000)
                    y = ZombRand(2000, 16000)
                end
            else
                -- Fallback to random
                x = ZombRand(2000, 16000)
                y = ZombRand(2000, 16000)
            end
        else
            -- Pure random
            x = ZombRand(2000, 16000)
            y = ZombRand(2000, 16000)
        end
        
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
    
    ISTimedActionQueue.add(ISZSpaceshipTeleportAction:new(player, x + 0.5, y + 0.5, 0, "Energizing...", nil, false, false))
end

function ZSpaceship.Teleport.toRandomBuilding(player)
    -- Check Science perk level
    if player:getPerkLevel(Perks.Science) < ZSpaceship.Teleport.SCIENCE_LEVEL_BUILDING then
        player:Say(getText("UI_ZS_ScienceRequired", ZSpaceship.Teleport.SCIENCE_LEVEL_BUILDING))
        return
    end
    
    -- Check power before teleporting (from space, to surface, to building)
    local cost = ZSpaceship.Teleport.getCost(player, true, false, true)
    if ZSpaceship and ZSpaceship.Power then
        local currentPower = ZSpaceship.Power.getAmount()
        if currentPower < cost then
            player:Say(getText("UI_ZS_InsufficientPower", cost, currentPower))
            return
        end
    end
    
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
    
    ISTimedActionQueue.add(ISZSpaceshipTeleportAction:new(player, x, y, z, "Energizing...", 2.0, true, true))
end

function ZSpaceship.Teleport.toShip(player, fromSpace)
    -- Check Science perk level
    if player:getPerkLevel(Perks.Science) < ZSpaceship.Teleport.SCIENCE_LEVEL_MIN then
        player:Say(getText("UI_ZS_ScienceRequired", ZSpaceship.Teleport.SCIENCE_LEVEL_MIN))
        return
    end
    
    -- Check power before teleporting (from surface or space, to space)
    local cost = ZSpaceship.Teleport.getCost(player, fromSpace, true, false)
    if ZSpaceship and ZSpaceship.Power then
        local currentPower = ZSpaceship.Power.getAmount()
        if currentPower < cost then
            player:Say(getText("UI_ZS_InsufficientPower", cost, currentPower))
            return
        end
    end
    
    local tx, ty, tz = ZSpaceship.getTeleporterCoords()
    if not tx or not ty or not tz then
        player:Say(getText("UI_ZS_TeleporterNotFound"))
        return
    end
    
    -- Get the square at the teleporter coordinates and center the player in it
    local x, y, z
    local sq = getSquare(math.floor(tx), math.floor(ty), tz)
    if sq then
        -- Use square's integer coordinates and add 0.5 to center
        x = sq:getX() + 0.5
        y = sq:getY() + 0.5
        z = sq:getZ()
    else
        -- Fallback: use provided coordinates and add 0.5
        x = math.floor(tx) + 0.5
        y = math.floor(ty) + 0.5
        z = tz
    end
    
    -- Longer teleport time if inside a building (but not if coming from space)
    local timeMult = 1.0
    if not fromSpace then
    local sq = player:getCurrentSquare()
    if sq and sq:getBuilding() then
        timeMult = 2.0
        end
    end
    
    ISTimedActionQueue.add(ISZSpaceshipTeleportAction:new(player, x, y, z, "Beam me up, Scotty!", timeMult, false, false))
end

-- Context Menu for Teleporter (World Object)
local function doWorldContextMenu(playerNum, context, worldobjects, test)
    if test then return end

    local player = getSpecificPlayer(playerNum)
    if not player then return end
    
    -- Only add teleport options if right-clicked on player or player's cell (including adjacent squares x-1, y-1)
    local isPlayerCell = false
    local playerSquare = player:getCurrentSquare()
    
    if playerSquare then
        local playerX = playerSquare:getX()
        local playerY = playerSquare:getY()
        local playerZ = playerSquare:getZ()
        
        -- Get adjacent squares (x-1, y-1, and both)
        local adjacentSquares = {}
        adjacentSquares[playerSquare] = true
        local adjSq1 = getSquare(playerX - 1, playerY, playerZ)
        if adjSq1 then adjacentSquares[adjSq1] = true end
        local adjSq2 = getSquare(playerX, playerY - 1, playerZ)
        if adjSq2 then adjacentSquares[adjSq2] = true end
        local adjSq3 = getSquare(playerX - 1, playerY - 1, playerZ)
        if adjSq3 then adjacentSquares[adjSq3] = true end
        
        for i = 1, #worldobjects do
            local obj = worldobjects[i]
            if obj then
                -- Check if object is the player
                if instanceof(obj, "IsoPlayer") and obj == player then
                    isPlayerCell = true
                    break
                end
                -- Check if object is on player's square or adjacent squares
                local objSquare = nil
                if obj.getSquare then
                    objSquare = obj:getSquare()
                elseif obj.getCurrentSquare then
                    objSquare = obj:getCurrentSquare()
                end
                if objSquare and adjacentSquares[objSquare] then
                    isPlayerCell = true
                    break
                end
            end
        end
    end
    
    if not isPlayerCell then return end
    
    -- Check if standing in teleport room
    local room = ZSRooms.find(player)
    
    if room and room:getName() == "zs_teleport_room" then
        local communicator = player:getInventory():getItemFromTag(ZSpaceship.Tags.Communicator, true, true)
        local costSurface = ZSpaceship.Teleport.getCost(player, true, false, false)  -- from space, to surface, not to building
        local costBuilding = ZSpaceship.Teleport.getCost(player, true, false, true)   -- from space, to surface, to building
        addTeleportOption(context, player, costSurface, "UI_ZS_TeleportToCounty", ZSpaceship.Teleport.toRandom, communicator, ZSpaceship.Teleport.SCIENCE_LEVEL_MIN)
        addTeleportOption(context, player, costBuilding, "UI_ZS_TeleportToBuilding", ZSpaceship.Teleport.toRandomBuilding, communicator, ZSpaceship.Teleport.SCIENCE_LEVEL_BUILDING)
    else
        local communicator = player:getInventory():getItemFromTag(ZSpaceship.Tags.Communicator, true, true)
        if communicator then
            addReturnToShipOption(context, player, communicator)
        end
    end
end

-- Context Menu for Communicator (Inventory Item)
local function doInventoryContextMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    
    -- Check if right-clicked item is the Communicator
    local clickedCommunicator = nil
    for i = 1, #items do
        local item = items[i]
        if not instanceof(item, "InventoryItem") then
            item = item.items[1]
        end
        if item and item:hasTag(ZSpaceship.Tags.Communicator) then
            clickedCommunicator = item
            break
        end
    end
    
    if clickedCommunicator then
        addReturnToShipOption(context, player, clickedCommunicator)
    end
end

Events.OnFillWorldObjectContextMenu.Add(doWorldContextMenu)
Events.OnFillInventoryObjectContextMenu.Add(doInventoryContextMenu)
