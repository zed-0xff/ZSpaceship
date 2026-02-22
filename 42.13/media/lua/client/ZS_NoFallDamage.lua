-- ZSpaceship Space Physics - Zero gravity effects in Space area
-- 1. No fall damage: Uses setbClimbing(true) trick so DoLand()/handleLandingImpact() skip damage
-- 2. No heavy load: Boosts maxWeight so HeavyLoad moodle stays at 0

ZSpaceship = ZSpaceship or {}

local wasFallingInSpace = false
local savedMaxWeight = nil

local function updateSpacePhysics()
    local player = getPlayer()
    if not player then return end
    
    local inSpace = zsInSpace(player)
    
    if not inSpace then
        -- Restore normal state when leaving space
        if wasFallingInSpace then
            player:setbClimbing(false)
            wasFallingInSpace = false
        end
        if savedMaxWeight then
            player:setMaxWeight(savedMaxWeight)
            savedMaxWeight = nil
        end
        return
    end
    
    -- Zero gravity: no heavy load moodle
    local currentMax = player:getMaxWeight()
    if currentMax < 500 then
        savedMaxWeight = savedMaxWeight or currentMax
        player:setMaxWeight(500)
    end
    
    -- Zero gravity: no fall damage
    local isFalling = player:isbFalling() or 
                      player:getVariableBoolean("bFalling") or
                      player:getCurrentState() == PlayerFallingState.instance()
    
    if isFalling then
        if not wasFallingInSpace then
            player:setbClimbing(true)
            wasFallingInSpace = true
        end
    elseif wasFallingInSpace then
        player:setbClimbing(false)
        wasFallingInSpace = false
    end
end

Events.OnPlayerUpdate.Add(updateSpacePhysics)
