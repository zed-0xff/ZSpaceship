-- ZSpaceship Teleport - Teleportation functions and context menus
require "TimedActions/ISTimedActionQueue"

function ZSpaceship.TeleportToRandom(player)
    -- Teleport to random location in the county (2000-13000), avoiding water
    local x, y
    local maxAttempts = 100
    for i = 1, maxAttempts do
        x = ZombRand(2000, 13000)
        y = ZombRand(2000, 13000)
        local sq = getCell():getGridSquare(x, y, 0)
        if sq and sq:getProperties() and not sq:getProperties():has(IsoFlagType.water) then
            break
        end
    end
    
    ISTimedActionQueue.add(ISZSpaceshipTeleportAction:new(player, x + 0.5, y + 0.5, 0, "Energizing..."))
end

function ZSpaceship.TeleportToShip(player)
    local x = ZSpaceship.TeleporterX + 0.5
    local y = ZSpaceship.TeleporterY + 0.5
    
    ISTimedActionQueue.add(ISZSpaceshipTeleportAction:new(player, x, y, ZSpaceship.TeleporterZ, "Beam me up, Scotty!"))
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
        context:addOption("Teleport to County", player, ZSpaceship.TeleportToRandom)
    end
    
    -- Return to Spaceship option when NOT in space and has communicator
    if not ZSpaceship.isInSpace(px, py) then
        local communicator = player:getInventory():getItemFromType("ZSpaceship.Communicator")
        if communicator then
            context:addOption("Return to Spaceship", player, ZSpaceship.TeleportToShip)
        end
    end
end

-- Context Menu for Communicator (Inventory Item)
local function doInventoryContextMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    local inv = player:getInventory()
    
    local communicator = inv:getItemFromType("ZSpaceship.Communicator")
    if communicator then
        context:addOption("Return to Spaceship", player, ZSpaceship.TeleportToShip)
    end
end

Events.OnFillWorldObjectContextMenu.Add(doWorldContextMenu)
Events.OnFillInventoryObjectContextMenu.Add(doInventoryContextMenu)
