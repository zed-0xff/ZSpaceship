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
            playerObj:Say("No oxygen to start a fire!")
        end
        return false
    end
    return true
end

Events.OnGameStart.Add(function()
    -- Hook stove toggle action
    if ISToggleStoveAction then
        local originalIsValid = ISToggleStoveAction.isValid
        ISToggleStoveAction.isValid = function(self)
            if not originalIsValid(self) then return false end
            return canToggleStoveOn(self.object)
        end
        
        local originalComplete = ISToggleStoveAction.complete
        ISToggleStoveAction.complete = function(self)
            if not canToggleStoveOn(self.object) then
                return false
            end
            return originalComplete(self)
        end
    end
    
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
end)
