-- ZSRoom vacuum breach detection methods

-- True only when an open door leads to open space (vacuum), not to another room.
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
            -- Adjacent has another room = door to another room, not to space
            if adjSq:getRoom() then
                -- do nothing
            elseif ZSRoom.isOpenSpace(adjSq) then
                return true
            end
        end
    end
    return false
end

-- True if any perimeter segment has no wall/door and the adjacent square is open space.
function ZSRoom:hasMissingWallToSpace()
    if not self:isValid() or not getSquare then return false end

    local sides = {
        { squares = self:getSquaresN(), dx = 0,  dy = -1 },
        { squares = self:getSquaresS(), dx = 0,  dy = 1 },
        { squares = self:getSquaresE(), dx = 1,  dy = 0 },
        { squares = self:getSquaresW(), dx = -1, dy = 0 },
    }
    for _, side in ipairs(sides) do
        for _, sq in ipairs(side.squares) do
            if sq then
                local wall = nil
                if side.dy == -1 then
                    wall = sq:getDoor(true) or sq:getWall(true)
                elseif side.dy == 1 then
                    local s = getSquare(sq:getX(), sq:getY() + 1, sq:getZ())
                    wall = s and (s:getDoor(true) or s:getWall(true))
                elseif side.dx == 1 then
                    local s = getSquare(sq:getX() + 1, sq:getY(), sq:getZ())
                    wall = s and (s:getDoor(false) or s:getWall(false))
                else
                    wall = sq:getDoor(false) or sq:getWall(false)
                end
                if not wall then
                    local adjSq = getSquare(sq:getX() + side.dx, sq:getY() + side.dy, sq:getZ())
                    if adjSq and not adjSq:getRoom() and ZSRoom.isOpenSpace(adjSq) then
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- True if the room has any opening (open door or missing wall) to open space (vacuum).
function ZSRoom:hasOpeningToSpace()
    return self:hasOpenDoorToSpace() or self:hasMissingWallToSpace()
end

function ZSRoom:propagateBreach()
    if not self.connections then return end

    for adjRoom, doorDataArray in pairs(self.connections) do
        if not adjRoom or adjRoom.vacuumState == ZSRoom.State.BREACHED then
            -- already breached
        else
            for _, doorData in ipairs(doorDataArray) do
                local door = doorData.isoDoor
                local isOpen = (door == nil) or (door.IsOpen and door:IsOpen())
                if isOpen then
                    adjRoom.vacuumState = ZSRoom.State.BREACHED
                    adjRoom:propagateBreach()
                    break
                end
            end
        end
    end
end