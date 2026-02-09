-- Vacuum fire suppression for ZSpaceship mod
-- Prevents fires, stoves, and campfires from working in vacuum (no oxygen)

ZSpaceship = ZSpaceship or {}

-- Helper to check if location is in vacuum using cached ZSRoom state
local function isInVacuum(sq)
    if not sq then return false end
    if not ZSpaceship.isInSpace(sq) then return false end
    
    local zsRoom = ZSRooms.find(sq)
    if not zsRoom then return true end  -- No room = vacuum
    
    return zsRoom:isBreached()
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
            playerObj:Say(getText("UI_ZS_NoOxygen"))
        end
        return false
    end
    return true
end

-- Suppress all fires and heat sources in a room when it becomes breached
local function suppressFiresInRoom(zsRoom)
    if not zsRoom or not zsRoom.squares then return end
    
    -- Iterate through cached squares in the room (values are IsoGridSquare objects)
    for _, sq in pairs(zsRoom.squares) do
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
    if not ZSpaceship.isInSpace(sq) then return end
    
    -- Check adjacent rooms for breach using cached ZSRoom state
    local checkedRooms = {}
    for dx = -1, 1 do
        for dy = -1, 1 do
            local adjSq = getSquare(sq:getX() + dx, sq:getY() + dy, sq:getZ())
            if adjSq then
                local zsRoom = ZSRooms.find(adjSq)
                if zsRoom and not checkedRooms[zsRoom] then
                    checkedRooms[zsRoom] = true
                    if zsRoom:isBreached() then
                        suppressFiresInRoom(zsRoom)
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
                        playerObj:Say(getText("UI_ZS_NoOxygen"))
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

-- Hook campfire lightFire to prevent lighting in vacuum
Events.OnGameStart.Add(function()
    if not SCampfireGlobalObject then return end
    
    local originalLightFire = SCampfireGlobalObject.lightFire
    SCampfireGlobalObject.lightFire = function(self)
        local sq = self:getSquare()
        if sq and ZSpaceship.isInSpace(sq) then
            local room = sq:getRoom()
            -- No room or room is breached = vacuum = no fire
            if not room then
                return  -- Don't light
            end
        end
        return originalLightFire(self)
    end
end)

