require "TimedActions/ISBaseTimedAction"

ISZSpaceshipTeleportAction = ISBaseTimedAction:derive("ISZSpaceshipTeleportAction")

local BASE_DURATION = 1000

function ISZSpaceshipTeleportAction:isValid()
    if self.character:getHealth() <= 0 then
        return false
    end
    
    if not self.character:getInventory():getItemFromTag(ZSpaceship.Tags.Communicator, true, true) then
        return false
    end
    
    -- Check Science perk level (requiredPerkLevel is set in :new())
    if self.requiredPerkLevel and self.character:getPerkLevel(Perks.Science) < self.requiredPerkLevel then
        return false
    end
    
    -- Check if there's enough power
    if ZSpaceship and ZSpaceship.Power then
        local curPower = ZSpaceship.Power.getAmount()
        if curPower < self.powerCost then
            return false
        end
    end
    
    -- Abort if player coordinates changed (e.g., falling in open space)
    if self.startX and self.startY and self.startZ then
        local curX = math.floor(self.character:getX())
        local curY = math.floor(self.character:getY())
        local curZ = math.floor(self.character:getZ())
        
        -- Allow small movement (1 tile) but abort on larger changes
        if math.abs(curX - self.startX) > 1 or math.abs(curY - self.startY) > 1 or curZ ~= self.startZ then
            return false
        end
    end
    
    return true
end

function ISZSpaceshipTeleportAction:start()
    -- Store initial coordinates to detect movement
    self.startX = math.floor(self.character:getX())
    self.startY = math.floor(self.character:getY())
    self.startZ = math.floor(self.character:getZ())
    
    self:setActionAnim("Loot")
    self.character:Say(self.startMessage or "Energizing...")
    local emitter = self.character:getEmitter()
    self.sound = emitter:playSound("modem")
    emitter:setVolume(self.sound, 0.5)
    -- Pitch scales with duration: short (50) = 1.5x, long (400) = 0.7x
    local t = (self.maxTime - 50) / 350  -- 0..1 (fast..slow)
    emitter:setPitch(self.sound, 1.5 - t * 0.8)
end

function ISZSpaceshipTeleportAction:stop()
    self.character:stopOrTriggerSound(self.sound)
    ISBaseTimedAction.stop(self)
end

function ISZSpaceshipTeleportAction:perform()
    self.character:stopOrTriggerSound(self.sound)
    ISBaseTimedAction.perform(self)
end

function ISZSpaceshipTeleportAction:complete()
    -- Consume power before teleporting
    if ZSpaceship and ZSpaceship.Power and self.powerCost then
        local powerBefore = ZSpaceship.Power.getAmount()
        ZSpaceship.Power.consume(self.powerCost)
        local powerAfter = ZSpaceship.Power.getAmount()
    end

    -- If this action was started for an object (e.g., item/movable) instead of a player teleport,
    -- just beam that object via server command and skip character repositioning.
    if self.object ~= self.character and self.object and self.object.getID then
        local sq = nil
        -- Try container parent square first
        local cont = self.object.getContainer and self.object:getContainer() or nil
        if cont and cont.getParent then
            local parent = cont:getParent()
            if parent and parent.getSquare then
                sq = parent:getSquare()
            end
        end
        -- Fallback: world inventory object square
        if not sq and self.object.getWorldItem then
            local wi = self.object:getWorldItem()
            if wi and wi.getSquare then
                sq = wi:getSquare()
            end
        end
        -- Final fallback: player's current square
        if not sq and self.character.getCurrentSquare then
            sq = self.character:getCurrentSquare()
        end

        local args = {
            itemID = self.object:getID(),
            square = ZS_Utils.squareToTable(sq),
        }
        sendClientCommand(self.character, "ZSpaceship", "BeamItemToShip", args)
        return true
    end

    local targetX = self.targetX
    local targetY = self.targetY
    local targetZ = self.targetZ
    local character = self.character
    local findFreeTile = self.findFreeTile

    local function finalizeTeleport()
        Events.OnTick.Remove(finalizeTeleport)

        ZSpaceship.checkAndUpdateVacuumState(character)
        local sndVolume = 2.0 - character:getPerkLevel(Perks.Science) * 0.2
        character:DoFootstepSound(sndVolume)
    end

    -- Delay teleport to next tick, or it doesn't work
    local function doTeleport()
        Events.OnTick.Remove(doTeleport)
        character:teleportTo(targetX, targetY, targetZ)

        if findFreeTile then
            -- Wait for cell to load at target location, then find a free tile in the room
            local tickCount = 0
            local function adjustPosition()
                tickCount = tickCount + 1
                -- Use target coordinates, not character position (which may not have updated yet)
                local sq = getCell():getGridSquare(targetX, targetY, targetZ)
                if sq and sq:getRoom() then
                    local roomDef = sq:getRoom():getRoomDef()
                    if roomDef then
                        local freeSq = getCell():getFreeTile(roomDef)
                        -- Fallback: manually search for a walkable tile in the room
                        if not freeSq then
                            local z = roomDef:getZ()
                            for x = roomDef:getX(), roomDef:getX2() do
                                for y = roomDef:getY(), roomDef:getY2() do
                                    local testSq = getCell():getGridSquare(x, y, z)
                                    if testSq and not testSq:isSolid() and not testSq:isSolidTrans() then
                                        freeSq = testSq
                                        break
                                    end
                                end
                                if freeSq then break end
                            end
                        end
                        if freeSq then
                            print("[ZSpaceship] Found free tile: " .. freeSq:getX() .. ", " .. freeSq:getY() .. ", " .. freeSq:getZ() .. ", ticks: " .. tickCount)
                            character:setX(freeSq:getX() + 0.5)
                            character:setY(freeSq:getY() + 0.5)
                            character:setZ(freeSq:getZ())
                        else
                            print("[ZSpaceship] No free tile found in room, ticks: " .. tickCount)
                        end
                    end
                    Events.OnTick.Remove(adjustPosition)
                    Events.OnTick.Add(finalizeTeleport)
                elseif tickCount > 60 then
                    print("[ZSpaceship] Failed to find a free tile after 60 ticks")
                    Events.OnTick.Remove(adjustPosition)
                    Events.OnTick.Add(finalizeTeleport)
                end
            end
            Events.OnTick.Add(adjustPosition)
        else
            character:setForceX(targetX)
            character:setForceY(targetY)
            Events.OnTick.Add(finalizeTeleport)
        end
    end
    Events.OnTick.Add(doTeleport)

    return true
end

function ISZSpaceshipTeleportAction:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    local duration = BASE_DURATION
    if self.fromSpace then
        duration = duration / 2
    end
    duration = duration - self.character:getPerkLevel(Perks.Science) * 60
    if self.timeMult then
        duration = duration * self.timeMult
    end
    if ZItemTiers and ZItemTiers.GetItemTierIndex then
        local comm = self.character:getInventory():getItemFromTag(ZSpaceship.Tags.Communicator, true, true)
        if comm then
            local tier = ZItemTiers.GetItemTierIndex(comm)
            if tier and tier > 1 then
                duration = duration * (1 - (tier-1) * 0.1)  -- Each tier after the first reduces time by 10%
            end
        end
    end
    return zsClamp(duration, 50, 1000)
end

function ISZSpaceshipTeleportAction:new(character, targetX, targetY, targetZ, startMessage, timeMult, findFreeTile, toBuilding, object)
    local o = ISBaseTimedAction.new(self, character)
    o.targetX = targetX
    o.targetY = targetY
    o.targetZ = targetZ
    o.timeMult = timeMult
    o.startMessage = startMessage
    o.findFreeTile = findFreeTile or false
    o.object = object or character  -- generic source object (player, item, movable, etc.)
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = false
    
    -- Set required Science perk level: level 2 for building teleports, level 1 for others
    o.requiredPerkLevel = ZSpaceship.Teleport.SCIENCE_LEVEL_MIN
    if toBuilding then
        o.requiredPerkLevel = math.max(o.requiredPerkLevel, ZSpaceship.Teleport.SCIENCE_LEVEL_BUILDING)
    end
    if o.object ~= character then
        o.requiredPerkLevel = math.max(o.requiredPerkLevel, ZSpaceship.Teleport.SCIENCE_LEVEL_ITEM)
    end
    
    -- Calculate and store power cost
    -- Check if teleporting from/to space
    o.fromSpace = zsInSpace(character)
    local toSpace = zsInSpaceXY(targetX, targetY)
    o.powerCost = ZSpaceship.Teleport.getCost(character, o.fromSpace, toSpace, toBuilding or false, object)
    
    o.maxTime = o:getDuration()
    
    return o
end
