require "TimedActions/ISBaseTimedAction"

ISZSpaceshipTeleportAction = ISBaseTimedAction:derive("ISZSpaceshipTeleportAction")

function ISZSpaceshipTeleportAction:isValid()
    return self.character:getHealth() > 0 and 
           self.character:getInventory():getItemFromType("ZSpaceship.Communicator") ~= nil
end

function ISZSpaceshipTeleportAction:start()
    self:setActionAnim("Loot")
    self.character:Say(self.startMessage or "Energizing...")
end

function ISZSpaceshipTeleportAction:stop()
    ISBaseTimedAction.stop(self)
end

function ISZSpaceshipTeleportAction:perform()
    ISBaseTimedAction.perform(self)
end

function ISZSpaceshipTeleportAction:complete()
    local targetX = self.targetX
    local targetY = self.targetY
    local targetZ = self.targetZ
    local character = self.character

    -- Delay teleport to next tick, or it doesn't work
    local function doTeleport()
        Events.OnTick.Remove(doTeleport)
        character:teleportTo(targetX, targetY, targetZ)
        character:setForceX(targetX) -- center player on tile
        character:setForceY(targetY) -- center player on tile
        -- Update vacuum state for sound muting
        ZSpaceship.checkAndUpdateVacuumState(character)
    end
    Events.OnTick.Add(doTeleport)

    return true
end

function ISZSpaceshipTeleportAction:new(character, targetX, targetY, targetZ, startMessage, time)
    local o = ISBaseTimedAction.new(self, character)
    o.targetX = targetX
    o.targetY = targetY
    o.targetZ = targetZ
    o.maxTime = time or 100  -- default ~3 seconds
    if character:isTimedActionInstant() then
        o.maxTime = 1
    end
    o.startMessage = startMessage
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = false
    return o
end
