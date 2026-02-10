-- Room cache and connection tracking for ZSpaceship mod
-- Caches room data (airtight status, connections) and tracks paths to breached rooms/open space

ZSRooms = ZSRooms or {}

-- Cache structure:
-- roomCache[roomId] = ZSRoom object (contains all room properties: isoRoom, airtight, connections, doors, etc.)

local roomCache = {}
local squareCache = {}
local nameCache = {}

-- Get room ID from room object
local function getRoomId(room)
    if not room then return nil end
    -- Use tostring(room) for unique ID since multiple rooms can have the same name
    return tostring(room)
end

local function getOrCreateInternal(roomId, room) -- roomId not null, room IsoRoom not null
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

local function initRooms()
    if not ZSpaceship or not ZSpaceship.MapData or not ZSpaceship.MapData.Rooms then return end

    for _, r in pairs(ZSpaceship.MapData.Rooms) do
        local sq = getSquare(r.x, r.y, r.z)
        if sq and sq.getRoom then
            local room = sq:getRoom()
            if room then
                local roomId = getRoomId(room)
                if roomId then
                    getOrCreateInternal(roomId, room)
                end
            end
        end
    end

    ZSRooms.updateAllSlow()
end

-- Get or create cache entry for a room
function ZSRooms.getOrCreate(room) -- IsoRoom
    local roomId = getRoomId(room)
    if not roomId then return nil end

    if room.getRandomSquare then
        local sq = room:getRandomSquare()
        if not sq then return nil end
        if not ZSpaceship.isInSpace(sq) then return nil end
    end

    if #roomCache == 0 then
        initRooms()
    end

    return getOrCreateInternal(roomId, room)
end

-- Find room from IsoGridSquare, IsoPlayer, or x,y,z coordinates
-- Returns cached ZSRoom object or nil
-- never creates new rooms
function ZSRooms.find(arg1, arg2, arg3)
    local square = nil
    local isoRoom = nil
    
    if arg1 and type(arg1) == "string" then
        return nameCache[arg1]
    end

    if instanceof(arg1, "IsoGridSquare") then
        local key = ZSRoom.getSquareKey(arg1)
        if key then
            return squareCache[key]
        end
    end

    -- Check if first argument is IsoPlayer (has getCurrentSquare method)
    if arg1 and arg1.getCurrentSquare then
        square = arg1:getCurrentSquare()
        if square then
            local key = ZSRoom.getSquareKey(square)
            if key then
                return squareCache[key]
            end
        end
    -- Otherwise, treat as x, y, z coordinates
    elseif arg1 and arg2 and arg3 then
        local x, y, z = arg1, arg2, arg3
        local key = ZSRoom.getSquareKeyFromCoords(x, y, z)
        if key then
            return squareCache[key]
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
    nameCache = {}

    for roomId, zsRoom in pairs(roomCache) do
        if zsRoom and zsRoom.update then
            zsRoom:update()
            local name = zsRoom:getName()
            if name then
                nameCache[name] = zsRoom
            end
            if zsRoom.squares then
                for sqKey, sq in pairs(zsRoom.squares) do
                    if sq and sqKey then
                        squareCache[sqKey] = zsRoom
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

function ZSRooms.dbgPrintCache()
    print("roomCache:")
    for roomId, zsRoom in pairs(roomCache) do
        print("  " .. roomId .. ": " .. zsRoom:getName())
    end
    print("squareCache:")
    for squareId, zsRoom in pairs(squareCache) do
        print("  " .. squareId .. ": " .. zsRoom:getName())
    end
    print("nameCache:")
    for name, zsRoom in pairs(nameCache) do
        print("  " .. name .. ": " .. zsRoom:getName())
    end
end

local function onObjAddRemove(obj)
    if ZSpaceship.isInSpace(obj) then
        ZSRooms.updateAllSlow()
    end
end

Events.OnTileRemoved.Add(onObjAddRemove)
Events.OnObjectAdded.Add(onObjAddRemove)

-- door is toggled, but we don't know which one
Events.OnContainerUpdate.Add(function()
    if not ZSpaceship.isAnyPlayerInSpace() then return end

    ZSRooms.updateAllFast()
end)

-- may fail to create rooms if current map is not "Space"
Events.OnGameStart.Add(initRooms)
