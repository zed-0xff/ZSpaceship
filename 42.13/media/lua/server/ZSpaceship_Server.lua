ZSpaceship = ZSpaceship or {}

-- Space cell coordinates
ZSpaceship.SpaceCellX = 78
ZSpaceship.SpaceCellY = 78

-- Cell boundaries (cell is 256x256)
ZSpaceship.SpaceMinX = ZSpaceship.SpaceCellX * 256
ZSpaceship.SpaceMaxX = (ZSpaceship.SpaceCellX + 1) * 256
ZSpaceship.SpaceMinY = ZSpaceship.SpaceCellY * 256
ZSpaceship.SpaceMaxY = (ZSpaceship.SpaceCellY + 1) * 256

-- Check if coordinates are in space (full cell)
function ZSpaceship.isInSpace(x, y)
    return x >= ZSpaceship.SpaceMinX and x < ZSpaceship.SpaceMaxX and
           y >= ZSpaceship.SpaceMinY and y < ZSpaceship.SpaceMaxY
end

-- Unlock a door/garage door object
-- TODO: figure out if the door can be created initially unlocked
local function unlockDoor(obj)
    print("Unlocking door: " .. tostring(obj))

    if not obj.getSquare then return end

    local sq = obj:getSquare()
    if not sq or not ZSpaceship.isInSpace(sq:getX(), sq:getY()) then return end
    
    if obj.setLockedByKey then
        obj:setLockedByKey(false)
    end
    if obj.setLocked then
        obj:setLocked(false)
    end
end

-- Register for garage door sprites (walls_garage_01_52 is what we use)
MapObjects.OnNewWithSprite("walls_garage_01_52", unlockDoor, 10)

-- Hook campfire lightFire to prevent lighting in vacuum
Events.OnGameStart.Add(function()
    if not SCampfireGlobalObject then return end
    
    local originalLightFire = SCampfireGlobalObject.lightFire
    SCampfireGlobalObject.lightFire = function(self)
        local sq = self:getSquare()
        if sq and ZSpaceship.isInSpace(sq:getX(), sq:getY()) then
            local room = sq:getRoom()
            -- No room or room is breached = vacuum = no fire
            if not room then
                return  -- Don't light
            end
        end
        return originalLightFire(self)
    end
end)
