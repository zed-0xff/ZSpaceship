-- Vacuum fire suppression for ZSpaceship mod
-- Prevents fires, stoves, and campfires from working in vacuum (no oxygen)
require 'zsHook'
require "ZS_Utils"

-- Extinguish fires when created in vacuum (no oxygen)
Events.OnNewFire.Add(function(fire)
    if not fire then return end
    
    local sq = fire:getSquare()
    if zsInVacuum(sq) then
        sq:stopFire()
    end
end)


-- Periodic check to extinguish any fires that end up in vacuum
local function checkFiresInVacuum()
    local fireStack = IsoFireManager.FireStack
    if not fireStack then return end
    
    for i = fireStack:size() - 1, 0, -1 do
        local fire = fireStack:get(i)
        if fire then
            local sq = fire:getSquare()
            if zsInVacuum(sq) then
                sq:stopFire()
            end
        end
    end
end
Events.EveryTenMinutes.Add(checkFiresInVacuum)


-- Prevent stoves from being activated in vacuum
zsHook(ISToggleStoveAction, {
    isValid = function(orig, self)
        if not orig(self) then return false end
        -- original isValid() returned true
        local stove = self.object
        if not stove then return true end -- ISToggleStoveAction changed?
        if stove.Activated and stove:Activated() then return true end -- Allow turning OFF
        return not zsInVacuum(stove)
    end
})

-- Check if a campfire/target can be lit
local function canLightFire(target, playerObj)
    if not target then return true end
    if not target.getSquare then return true end

    if zsInVacuum(target) then
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
    if not zsInSpace(sq) then return end
    
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

local function onGameStart()
    -- Hook campfire lighting functions
    zsHook(ISCampingMenu, {
        onLightFromLiterature = function(orig, playerObj, itemType, lighter, target, ...)
            if not canLightFire(target, playerObj) then return end
            return orig(playerObj, itemType, lighter, target, ...)
        end,
        onLightFromKindle = function(orig, playerObj, percedWood, stickOrBranch, target, ...)
            if not canLightFire(target, playerObj) then return end
            return orig(playerObj, percedWood, stickOrBranch, target, ...)
        end,
        onLightFromPetrol = function(orig, playerObj, lighter, petrol, target, ...)
            if not canLightFire(target, playerObj) then return end
            return orig(playerObj, lighter, petrol, target, ...)
        end
    })
    
    zsHook(ISBBQMenu, {
        onToggle = function(orig, worldobjects, player, bbq, ...)
            if bbq and not bbq:isLit() then
                local sq = bbq:getSquare()
                if sq and zsInVacuum(sq) then
                    local playerObj = getSpecificPlayer(player)
                    if playerObj and playerObj.Say then
                        playerObj:Say(getText("UI_ZS_NoOxygen"))
                    end
                    return
                end
            end
            return orig(worldobjects, player, bbq, ...)
        end
    })
    
    zsHook(ISOpenCloseDoor, {
        complete = function(orig, self, ...)
            local result = orig(self, ...)
            
            -- Check if this door is in space and now causes a breach
            local door = self.item
            if door and door.IsOpen and door:IsOpen() then
                checkBreachAtSquare(door:getSquare())
            end
            
            return result
        end
    })

    -- Hook campfire lightFire to prevent lighting in vacuum
    zsHook(SCampfireGlobalObject, {
        lightFire = function(orig, self, ...)
            if not zsInVacuum(self) then return orig(self, ...) end
        end 
    })
end

Events.OnGameStart.Add(onGameStart)

-- Check breach and suppress fires when a wall/door is destroyed
Events.OnDestroyIsoThumpable.Add(function(thumpable, owner)
    if not thumpable then return end
    checkBreachAtSquare(thumpable:getSquare())
end)
