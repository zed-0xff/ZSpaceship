-- ZSpaceship Main - Core constants and utilities

ZSpaceship = ZSpaceship or {}
ZSpaceship.MapData = ZSpaceship.MapData or {}

-- Space cell coordinates (use MapData if available, otherwise defaults)
ZSpaceship.SpaceCellX = ZSpaceship.MapData.CellX or 78
ZSpaceship.SpaceCellY = ZSpaceship.MapData.CellY or 78

-- Cell boundaries (cell is 256x256)
ZSpaceship.SpaceMinX = ZSpaceship.SpaceCellX * 256
ZSpaceship.SpaceMaxX = (ZSpaceship.SpaceCellX + 1) * 256
ZSpaceship.SpaceMinY = ZSpaceship.SpaceCellY * 256
ZSpaceship.SpaceMaxY = (ZSpaceship.SpaceCellY + 1) * 256

-- Teleporter position (from room data)
-- Gets coordinates from teleport_room using ZSRooms.find, with fallback to MapData
function ZSpaceship.getTeleporterCoords()
    -- First try: use ZSRooms cache
    if ZSRooms then
        local teleportRoom = ZSRooms.find("teleport_room")
        if teleportRoom and teleportRoom.center then
            return teleportRoom.center.x, teleportRoom.center.y, teleportRoom.center.z
        end
    end
    
    -- Second try: search in MapData.Rooms (runtime data, may be from save file)
    if ZSpaceship.MapData and ZSpaceship.MapData.Rooms then
        for _, room in ipairs(ZSpaceship.MapData.Rooms) do
            if room.name == "teleport_room" then
                return room.x, room.y, room.z
            end
        end
    end
    
    -- Third try: search in MapData.DefaultRooms (compiled data)
    if ZSpaceship.MapData and ZSpaceship.MapData.DefaultRooms then
        for _, room in ipairs(ZSpaceship.MapData.DefaultRooms) do
            if room.name == "teleport_room" then
                return room.x, room.y, room.z
            end
        end
    end
    
    return nil, nil, nil
end

-- Check if coordinates are in space (full cell)
function ZSpaceship.isInSpace(x, y)
    return x >= ZSpaceship.SpaceMinX and x < ZSpaceship.SpaceMaxX and
           y >= ZSpaceship.SpaceMinY and y < ZSpaceship.SpaceMaxY
end

function ZSpaceship.isAnyPlayerInSpace()
    local players = IsoPlayer.getPlayers()
    for i=0, players:size() -1 do
        local player = players:get(i)
        if player ~= nil and ZSpaceship.isInSpace(player:getX(), player:getY()) then
            return true
        end
    end
    return false
end