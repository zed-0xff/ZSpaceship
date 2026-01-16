-- ZSpaceship Main - Core functionality
-- Teleportation and context menus

ZSpaceship = ZSpaceship or {}

-- Space cell coordinates
ZSpaceship.SpaceCellX = 78
ZSpaceship.SpaceCellY = 78

-- Cell boundaries (cell is 256x256)
ZSpaceship.SpaceMinX = ZSpaceship.SpaceCellX * 256
ZSpaceship.SpaceMaxX = (ZSpaceship.SpaceCellX + 1) * 256
ZSpaceship.SpaceMinY = ZSpaceship.SpaceCellY * 256
ZSpaceship.SpaceMaxY = (ZSpaceship.SpaceCellY + 1) * 256

-- Ship position (center of cell for teleporting)
ZSpaceship.ShipX = ZSpaceship.SpaceMinX + 128
ZSpaceship.ShipY = ZSpaceship.SpaceMinY + 128
ZSpaceship.ShipZ = 0

-- Check if coordinates are in space (full cell)
function ZSpaceship.isInSpace(x, y)
    return x >= ZSpaceship.SpaceMinX and x < ZSpaceship.SpaceMaxX and
           y >= ZSpaceship.SpaceMinY and y < ZSpaceship.SpaceMaxY
end

function ZSpaceship.TeleportToRandom(player)
    -- Teleport to random location in the county (0 to 15000)
    local x = ZombRand(2000, 13000)
    local y = ZombRand(2000, 13000)
    player:setX(x)
    player:setY(y)
    player:setZ(0)
    player:setLx(x)
    player:setLy(y)
    player:setLz(0)
    
    player:Say("Beam me up, Scotty!")
end

function ZSpaceship.TeleportToShip(player)
    player:setX(ZSpaceship.ShipX)
    player:setY(ZSpaceship.ShipY)
    player:setZ(ZSpaceship.ShipZ)
    player:setLx(ZSpaceship.ShipX)
    player:setLy(ZSpaceship.ShipY)
    player:setLz(ZSpaceship.ShipZ)
    
    player:Say("Energizing...")
end

-- Context Menu for Teleporter (World Object)
local function doWorldContextMenu(playerNum, context, worldobjects, test)
    if test then return end
    local player = getSpecificPlayer(playerNum)
    
    -- Check for static teleporter in world
    local teleporterObj = nil
    for _, obj in ipairs(worldobjects) do
        if obj.getSprite then
            local sprite = obj:getSprite()
            if sprite and sprite:getName() == "blends_street_01_87" then
                teleporterObj = obj
                break
            end
        end
    end

    if teleporterObj then
        -- Only allow in the ship area, in case this sprite exists elsewhere.
        if ZSpaceship.isInSpace(player:getX(), player:getY()) then
            context:addOption("Beam me up, Scotty", player, ZSpaceship.TeleportToRandom)
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
