-- ZSRoom vacuum breach detection methods

-- Helper: Check if any open door leads to space
function ZSRoom:hasOpenDoorToSpace()
    if not self:isValid() or not self.isoRoom then
        return false
    end
    
    local doors = self:getDoors()
    if not doors then return false end
    
    for _, doorData in ipairs(doors) do
        local door = doorData.isoDoor
        local adjSq = doorData.adjSquare
        if door and adjSq and door.IsOpen and door:IsOpen() then
            -- Exterior doors always lead to open space
            if doorData.isExterior then
                return true
            end
            -- Check if adjacent square is open space
            if not adjSq:getRoom() and ZSRoom.isOpenSpace(adjSq) then
                return true
            end
        end
    end
    return false
end


function ZSRoom:propagateBreach()
    if not self.connections then return end

    for adjRoom, doorDataArray in pairs(self.connections) do
        for _, doorData in ipairs(doorDataArray) do
            local door = doorData.isoDoor
            if door and door.IsOpen and door:IsOpen() and adjRoom and adjRoom.vacuumState ~= ZSRoom.State.BREACHED then
                adjRoom.vacuumState = ZSRoom.State.BREACHED
                adjRoom:propagateBreach()
            end
        end
    end
end