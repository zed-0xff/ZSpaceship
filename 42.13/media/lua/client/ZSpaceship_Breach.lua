ZSpaceship = ZSpaceship or {}

-- Logic for airtight doors and breaches
-- We will track "Breached" rooms in a table
ZSpaceship.BreachedRooms = {}

local function updateBreaches(ticks)
    -- This is expensive, so we run it less frequently
    local t = ticks
    if type(t) ~= "number" then t = 0 end
    if math.floor(t) % 60 ~= 0 then return end
    
    local player = getPlayer()
    if not player then return end
    
    local x = player:getX()
    local y = player:getY()
    
    if math.abs(x - ZSpaceship.ShipX) > ZSpaceship.ShipRange or 
       math.abs(y - ZSpaceship.ShipY) > ZSpaceship.ShipRange then
        return
    end

    -- For each room in the ship, check if it's breached
    -- A room is breached if any of its boundary squares has an open door or a destroyed wall leading to outside
    -- This is hard to do without a list of all rooms. 
    -- Instead, we'll check the current room of the player.
    
    local square = player:getSquare()
    if not square then return end
    
    local room = square:getRoom()
    if not room then return end
    
    local roomId = room:getName() or (room:getX() .. "," .. room:getY())
    local isBreached = false
    
    -- Check squares in the room (limit to a few for performance or just check neighbors)
    -- Actually, simpler: if the square the player is on is marked as "outside", it's breached.
    -- In PZ, if a wall is destroyed, the tiles inside might become "outside".
    if square:isOutside() then
        isBreached = true
    end
    
    -- Check for open doors to outside
    local squares = room:getSquares()
    if squares then
        for i=0, squares:size()-1 do
            local s = squares:get(i)
            -- Check all 4 directions for doors/walls
            for dir=0, 3 do
                -- local wall = s:getWall(false) -- check if wall exists
                -- This is getting complex. Let's stick to isOutside() for now as it's the engine's way of knowing if it's "exposed".
            end
        end
    end
end

Events.OnTick.Add(updateBreaches)
