-- ZSRoom vacuum breach detection methods

-- Helper: Check if any open door leads to space
local function hasOpenDoorToSpace(doors)
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

-- Calculate and cache vacuum breach state for this room
-- Called by updateAllFast() to update vacuum state for all rooms
function ZSRoom:calculateVacuumState(visited)
    if not self:isValid() or not self.isoRoom then
        self.vacuumState = true
        return true
    end
    
    local roomId = tostring(self.isoRoom)
    if not roomId then
        self.vacuumState = true
        return true
    end
    
    visited = visited or {}
    if visited[roomId] == "checking" then
        -- Cycle: check only direct breaches
        self.vacuumState = not self.airtight or hasOpenDoorToSpace(self:getDoors())
        return self.vacuumState
    elseif visited[roomId] then
        -- Use cached result from visited table
        self.vacuumState = (visited[roomId] == "breached")
        return self.vacuumState
    end

    visited[roomId] = "checking"

    -- Not airtight = breached
    if not self.airtight then
        self.vacuumState = true
        visited[roomId] = "breached"
        return true
    end

    -- Check open doors to space
    if hasOpenDoorToSpace(self:getDoors()) then
        self.vacuumState = true
        visited[roomId] = "breached"
        return true
    end
    
    -- Check connections to other rooms
    if self.connections then
        for adjRoom, doorDataArray in pairs(self.connections) do
            -- Check if any door is open
            local hasOpen = false
            for _, doorData in ipairs(doorDataArray) do
                local door = doorData.isoDoor
                if door and door.IsOpen and door:IsOpen() then
                    hasOpen = true
                    break
                end
            end
            
            if hasOpen then
                -- adjRoom is already a ZSRoom object, check if it's breached
                if adjRoom and adjRoom.calculateVacuumState then
                    if adjRoom:calculateVacuumState(visited) then
                        self.vacuumState = true
                        visited[roomId] = "breached"
                        return true
                    end
                end
            end
        end
    end
    
    self.vacuumState = false
    visited[roomId] = "sealed"
    return false
end
