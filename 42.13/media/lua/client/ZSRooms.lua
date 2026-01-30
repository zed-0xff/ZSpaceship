-- Room cache and connection tracking for ZSpaceship mod
-- Caches room data (airtight status, connections) and tracks paths to breached rooms/open space

ZSRooms = ZSRooms or {}

-- Cache structure:
-- roomCache[roomId] = ZSRoom object (contains all room properties: isoRoom, airtight, connections, doors, etc.)

local roomCache = {}
local squareCache = {}

-- Get room ID from room object
local function getRoomId(room)
    if not room then return nil end
    -- Use tostring(room) for unique ID since multiple rooms can have the same name
    return tostring(room)
end

-- Get or create cache entry for a room
function ZSRooms.getOrCreate(room) -- IsoRoom
    local roomId = getRoomId(room)
    if not roomId then return nil end

    if not roomCache[roomId] then
        -- Create ZSRoom object from the room
        local zsRoom = nil
        if ZSRoom and room then
            if room.getSquares then
                local squares = room:getSquares()
                if squares and squares.size and squares:size() > 0 then
                    local firstSquare = squares:get(0)
                    if firstSquare then
                        zsRoom = ZSRoom:new(firstSquare)
                    end
                end
            end
        end
        
        roomCache[roomId] = zsRoom
    end
    
    return roomCache[roomId]
end

-- Find room from IsoGridSquare, IsoPlayer, or x,y,z coordinates
-- Returns cached ZSRoom object or nil
-- never creates new rooms
function ZSRooms.find(arg1, arg2, arg3)
    local square = nil
    local isoRoom = nil
    

    if instanceof(arg1, "IsoGridSquare") then
        return squareCache[arg1:getID()]
    end

    -- Check if first argument is IsoPlayer (has getCurrentSquare method)
    if arg1 and arg1.getCurrentSquare then
        square = arg1:getCurrentSquare()
        if square then
            return squareCache[square:getID()]
        end
    -- Otherwise, treat as x, y, z coordinates
    elseif arg1 and arg2 and arg3 then
        local x, y, z = arg1, arg2, arg3
        if getSquare then
            square = getSquare(x, y, z)
            if square then
                return squareCache[square:getID()]
            end
        end
    end
    
    return nil
end

-- Clear cache (call when map changes)
-- function ZSRooms.clear()
--     roomCache = {}
--     squareCache = {}
-- end

-- Get all cached rooms
function ZSRooms.all()
    return roomCache
end

-- Calculate vacuum breach flags for all rooms
function ZSRooms.updateAllFast()
    local unknownRooms = {}
    local breachedRooms = {}
    for roomId, room in pairs(roomCache) do
        if room then
            if room.airtight then
                if room:isAllDoorsClosed() then
                    room.vacuumState = room.State.SEALED
                elseif room:hasOpenDoorToSpace() then
                    room.vacuumState = room.State.BREACHED
                    breachedRooms[#breachedRooms + 1] = room
                else
                    room.vacuumState = room.State.UNKNOWN
                    unknownRooms[#unknownRooms + 1] = room
                end
            else 
                room.vacuumState = room.State.BREACHED
                breachedRooms[#breachedRooms + 1] = room
            end
        end
    end

    for _, room in ipairs(breachedRooms) do
        room:propagateBreach()
    end

    local maxPasses = 10
    local pass = 0
    local updated = true
    while pass < maxPasses and #unknownRooms > 0 and updated do
        pass = pass + 1
        updated = false
        local unknownRooms2 = {}
        for _, room in ipairs(unknownRooms) do
            if room.vacuumState == room.State.UNKNOWN and room.connections then
                for adjRoom, doorDataArray in pairs(room.connections) do
                    if adjRoom and adjRoom.vacuumState == ZSRoom.State.BREACHED then
                        for _, doorData in ipairs(doorDataArray) do
                            local door = doorData.isoDoor
                            if door and door.IsOpen and door:IsOpen() then
                                room.vacuumState = ZSRoom.State.BREACHED
                                room:propagateBreach()
                                updated = true
                                break
                            end
                        end
                    end
                end
            end
            if room.vacuumState == room.State.UNKNOWN then
                unknownRooms2[#unknownRooms2 + 1] = room
            end
        end
        unknownRooms = unknownRooms2
    end 

    for _, room in ipairs(unknownRooms) do
        if room.vacuumState == room.State.UNKNOWN then
            room.vacuumState = room.State.SEALED
        end
    end
end

function ZSRooms.updateAllSlow()
    squareCache = {}

    for roomId, zsRoom in pairs(roomCache) do
        if zsRoom and zsRoom.update then
            zsRoom:update()
            if zsRoom.squares then
                for i = 0, zsRoom.squares:size() - 1 do
                    local sq = zsRoom.squares:get(i)
                    if sq then
                        squareCache[sq:getID()] = zsRoom
                    end
                end
            end
        end
    end

    for roomId, zsRoom in pairs(roomCache) do
        if zsRoom and zsRoom.buildConnections then
            zsRoom:buildConnections() -- requires ALL rooms to be updated first
        end
    end

    ZSRooms.updateAllFast()
end

Events.OnTileRemoved.Add(function(sq) -- IsoGridSquare
    if sq and sq.getX and sq.getY and ZSpaceship.isInSpace(sq:getX(), sq:getY()) then
        ZSRooms.updateAllSlow()
    end
end)

Events.OnObjectAdded.Add(function(obj)
    if obj and obj.getSquare then
        local sq = obj:getSquare()
        if sq and sq.getX and sq.getY and ZSpaceship.isInSpace(sq:getX(), sq:getY()) then
            ZSRooms.updateAllSlow()
        end
    end
end)

-- door is toggled, but we don't know which one
Events.OnContainerUpdate.Add(function()
    if not ZSpaceship.isAnyPlayerInSpace() then return end

    ZSRooms.updateAllFast()
end)

Events.OnGameTimeLoaded.Add(function()
end)

Events.OnGameStart.Add(function()
    for _, r in pairs(ZSpaceship.MapData.Rooms) do
        local sq = getSquare(r.x, r.y, r.z)
        if sq and sq.getRoom then
            local room = sq:getRoom()
            if room then
                ZSRooms.getOrCreate(room)
            end
        end
    end

    ZSRooms.updateAllSlow()
end)