ZSpaceship = ZSpaceship or {}

-- Spaceship cell bounds
ZSpaceship.CellX = 78
ZSpaceship.CellY = 78

-- Check if coordinates are in our spaceship cell
local function isInSpaceship(x, y)
    local cellX = math.floor(x / 256)
    local cellY = math.floor(y / 256)
    return cellX == ZSpaceship.CellX and cellY == ZSpaceship.CellY
end

-- Unlock a door/garage door object
-- TODO: figure out if the door can be created initially unlocked
local function unlockDoor(obj)
    print("Unlocking door: " .. tostring(obj))

    if not obj.getSquare then return end

    local sq = obj:getSquare()
    if not sq or not isInSpaceship(sq:getX(), sq:getY()) then return end
    
    if obj.setLockedByKey then
        obj:setLockedByKey(false)
    end
    if obj.setLocked then
        obj:setLocked(false)
    end
end

-- Register for garage door sprites (walls_garage_01_52 is what we use)
MapObjects.OnNewWithSprite("walls_garage_01_52", unlockDoor, 10)
