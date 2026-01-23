require "TimedActions/ISBaseTimedAction"

ISZSpaceshipTeleportAction = ISBaseTimedAction:derive("ISZSpaceshipTeleportAction")

function ISZSpaceshipTeleportAction:isValid()
    return self.character:getHealth() > 0 and 
           self.character:getInventory():getItemFromTag(ZSpaceship.Tags.Communicator, true, true) ~= nil
end

function ISZSpaceshipTeleportAction:start()
    self:setActionAnim("Loot")
    self.character:Say(self.startMessage or "Energizing...")
    self.sound = self.character:playSound("PZ_Owl_02")
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
    local targetX = self.targetX
    local targetY = self.targetY
    local targetZ = self.targetZ
    local character = self.character
    local findFreeTile = self.findFreeTile

    local function finalizeTeleport()
        ZSpaceship.checkAndUpdateVacuumState(character)
        character:DoFootstepSound(2.0)
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
                    finalizeTeleport()
                elseif tickCount > 60 then
                    print("[ZSpaceship] Failed to find a free tile after 60 ticks")
                    Events.OnTick.Remove(adjustPosition)
                    finalizeTeleport()
                end
            end
            Events.OnTick.Add(adjustPosition)
        else
            character:setForceX(targetX)
            character:setForceY(targetY)
            finalizeTeleport()
        end
    end
    Events.OnTick.Add(doTeleport)

    return true
end

function ISZSpaceshipTeleportAction:new(character, targetX, targetY, targetZ, startMessage, timeMult, findFreeTile)
    local o = ISBaseTimedAction.new(self, character)
    o.targetX = targetX
    o.targetY = targetY
    o.targetZ = targetZ
    o.maxTime = 100  -- ticks (~3 seconds)
    if character:isTimedActionInstant() then
        o.maxTime = 1
    elseif timeMult then
        o.maxTime = o.maxTime * timeMult
    end
    o.startMessage = startMessage
    o.findFreeTile = findFreeTile or false
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = false
    return o
end
