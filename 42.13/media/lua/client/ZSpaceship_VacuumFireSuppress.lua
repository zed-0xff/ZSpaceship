-- Vacuum fire suppression for ZSpaceship mod
-- Prevents fires, stoves, and campfires from working in vacuum (no oxygen)

ZSpaceship = ZSpaceship or {}

-- Helper to check if location is in vacuum
local function isInVacuum(sq)
    if not sq then return false end
    if not ZSpaceship.isInSpace(sq:getX(), sq:getY()) then return false end
    
    local room = sq:getRoom()
    if not room then return true end
    
    return ZSpaceship.isRoomBreached(room)
end

-- Extinguish fires when created in vacuum (no oxygen)
local function onNewFire(fire)
    if not fire then return end
    
    local sq = fire:getSquare()
    if isInVacuum(sq) then
        sq:stopFire()
    end
end

Events.OnNewFire.Add(onNewFire)

-- Periodic check to extinguish any fires that end up in vacuum
local fireCheckAccumulator = 0
local FIRE_CHECK_INTERVAL = 1.0  -- seconds

local function checkFiresInVacuum()
    local mult = getGameTime():getThirtyFPSMultiplier()
    
    fireCheckAccumulator = fireCheckAccumulator + (mult / 30.0)
    if fireCheckAccumulator < FIRE_CHECK_INTERVAL then return end
    fireCheckAccumulator = 0
    
    local fireStack = IsoFireManager.FireStack
    if not fireStack then return end
    
    for i = fireStack:size() - 1, 0, -1 do
        local fire = fireStack:get(i)
        if fire then
            local sq = fire:getSquare()
            if isInVacuum(sq) then
                sq:stopFire()
            end
        end
    end
end

Events.OnTick.Add(checkFiresInVacuum)

-- Prevent stoves from being activated in vacuum
local function canToggleStoveOn(stove)
    if not stove then return true end
    if stove:Activated() then return true end  -- Allow turning OFF
    
    local sq = stove:getSquare()
    if isInVacuum(sq) then
        return false  -- Can't turn on in vacuum
    end
    return true
end

-- Check if a campfire/target can be lit
local function canLightFire(target, playerObj)
    if not target then return true end
    local sq = target:getSquare()
    if isInVacuum(sq) then
        if playerObj and playerObj.Say then
            playerObj:Say(getText("UI_ZSpaceship_NoOxygen"))
        end
        return false
    end
    return true
end

-- Suppress all fires and heat sources in a room when it becomes breached
local function suppressFiresInRoom(room)
    if not room then return end
    local squares = room:getSquares()
    if not squares then return end
    
    for i = 0, squares:size() - 1 do
        local sq = squares:get(i)
        if sq then
            -- Stop any fires on this square
            sq:stopFire()
            
            -- Check objects on this square for heat sources
            local objects = sq:getObjects()
            if objects then
                for j = 0, objects:size() - 1 do
                    local obj = objects:get(j)
                    if obj then
                        -- Turn off lit fireplaces (includes campfires, fire pits)
                        if instanceof(obj, "IsoFireplace") and obj:isLit() then
                            obj:extinguish()
                        end
                        -- Turn off lit BBQs (all types need oxygen)
                        if instanceof(obj, "IsoBarbecue") and obj:isLit() then
                            obj:setLit(false)
                        end
                    end
                end
            end
        end
    end
end

-- Check for breach at a square and suppress fires in affected rooms
local function checkBreachAtSquare(sq)
    if not sq then return end
    if not ZSpaceship.isInSpace(sq:getX(), sq:getY()) then return end
    
    -- Check adjacent rooms for breach
    local checkedRooms = {}
    for dx = -1, 1 do
        for dy = -1, 1 do
            local adjSq = getSquare(sq:getX() + dx, sq:getY() + dy, sq:getZ())
            if adjSq then
                local room = adjSq:getRoom()
                if room and not checkedRooms[room] then
                    checkedRooms[room] = true
                    if ZSpaceship.isRoomBreached(room) then
                        suppressFiresInRoom(room)
                    end
                end
            end
        end
    end
end

Events.OnGameStart.Add(function()
    -- Hook campfire lighting functions
    if ISCampingMenu then
        local origLightFromLiterature = ISCampingMenu.onLightFromLiterature
        ISCampingMenu.onLightFromLiterature = function(playerObj, itemType, lighter, target, timedAction)
            if not canLightFire(target, playerObj) then return end
            return origLightFromLiterature(playerObj, itemType, lighter, target, timedAction)
        end
        
        local origLightFromKindle = ISCampingMenu.onLightFromKindle
        ISCampingMenu.onLightFromKindle = function(playerObj, percedWood, stickOrBranch, target, timedAction)
            if not canLightFire(target, playerObj) then return end
            return origLightFromKindle(playerObj, percedWood, stickOrBranch, target, timedAction)
        end
        
        local origLightFromPetrol = ISCampingMenu.onLightFromPetrol
        ISCampingMenu.onLightFromPetrol = function(playerObj, lighter, petrol, target, timedAction)
            if not canLightFire(target, playerObj) then return end
            return origLightFromPetrol(playerObj, lighter, petrol, target, timedAction)
        end
    end
    
    -- Hook BBQ toggle
    if ISBBQMenu then
        local origOnToggle = ISBBQMenu.onToggle
        ISBBQMenu.onToggle = function(worldobjects, player, bbq, tank)
            if bbq and not bbq:isLit() then
                local sq = bbq:getSquare()
                if sq and isInVacuum(sq) then
                    local playerObj = getSpecificPlayer(player)
                    if playerObj and playerObj.Say then
                        playerObj:Say(getText("UI_ZSpaceship_NoOxygen"))
                    end
                    return
                end
            end
            return origOnToggle(worldobjects, player, bbq, tank)
        end
    end
    
    -- Hook door open/close to check for breach
    if ISOpenCloseDoor then
        local originalDoorComplete = ISOpenCloseDoor.complete
        ISOpenCloseDoor.complete = function(self)
            local result = originalDoorComplete(self)
            
            -- Check if this door is in space and now causes a breach
            local door = self.item
            if door and door.IsOpen and door:IsOpen() then
                checkBreachAtSquare(door:getSquare())
            end
            
            return result
        end
    end
end)

-- Check breach and suppress fires when a wall/door is destroyed
Events.OnDestroyIsoThumpable.Add(function(thumpable, owner)
    if not thumpable then return end
    checkBreachAtSquare(thumpable:getSquare())
end)
