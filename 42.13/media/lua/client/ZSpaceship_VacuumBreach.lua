-- Vacuum breach detection for ZSpaceship mod
-- Handles detection of breached rooms (missing walls, floors, roofs, or open doors to vacuum)

ZSpaceship = ZSpaceship or {}

-- Check if room is breached (open door, missing wall, floor, or roof)
-- Delegates to ZSRoom:isBreached() which is the source of truth
function ZSpaceship.isRoomBreached(room)
    if not room then return true end
    
    local zsRoom = ZSRooms.getOrCreate(room)
    if not zsRoom then return true end

    return zsRoom:isBreached({})
end

