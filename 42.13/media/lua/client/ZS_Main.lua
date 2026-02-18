-- ZSpaceship Main - Core constants and utilities

ZSpaceship = ZSpaceship or {}
ZSpaceship.MapData = ZSpaceship.MapData or {}

-- Teleporter position (from room data)
-- Gets coordinates from teleport_room using ZSRooms.find, with fallback to MapData
function ZSpaceship.getTeleporterCoords()
    -- First try: use ZSRooms cache
    if ZSRooms then
        local teleportRoom = ZSRooms.find("zs_teleport_room")
        if teleportRoom and teleportRoom.center then
            return teleportRoom.center.x, teleportRoom.center.y, teleportRoom.center.z
        end
    end
    
    -- Second try: search in MapData.Rooms (runtime data, may be from save file)
    if ZSpaceship.MapData and ZSpaceship.MapData.Rooms then
        for _, room in ipairs(ZSpaceship.MapData.Rooms) do
            if room.name == "zs_teleport_room" then
                return room.x, room.y, room.z
            end
        end
    end
    
    -- Third try: search in MapData.Default.Rooms (compiled data)
    if ZSpaceship.MapData and ZSpaceship.MapData.Default and ZSpaceship.MapData.Default.Rooms then
        for _, room in ipairs(ZSpaceship.MapData.Default.Rooms) do
            if room.name == "zs_teleport_room" then
                return room.x, room.y, room.z
            end
        end
    end
    
    return nil, nil, nil
end

function ZSpaceship.isAnyPlayerInSpace()
    local players = IsoPlayer.getPlayers()
    for i=0, players:size() -1 do
        local player = players:get(i)
        if player ~= nil and zsIsInSpace(player) then
            return true
        end
    end
    return false
end
