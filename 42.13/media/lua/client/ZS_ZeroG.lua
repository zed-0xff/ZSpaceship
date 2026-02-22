-- ZSpaceship Zero-G - Zero gravity effects in Space area
-- 1. No fall damage: setbClimbing(true) trick so DoLand()/handleLandingImpact() skip damage
-- 2. No heavy load: Boosts maxWeight so HeavyLoad moodle stays at 0

ZSpaceship = ZSpaceship or {}

local ZERO_G_MAX_WEIGHT = 500
local wasFallingInSpace = false

local function updateSpacePhysics()
    local player = getPlayer()
    if not player then return end
    
    local inSpace = zsInSpace(player)
    
    if not inSpace then
        if wasFallingInSpace then
            player:setbClimbing(false)
            wasFallingInSpace = false
        end
        return
    end
    
    -- Zero gravity: no heavy load moodle
    -- BodyDamage recalculates maxWeight from maxWeightBase naturally, so no manual restore needed
    if player:getMaxWeight() < ZERO_G_MAX_WEIGHT then
        player:setMaxWeight(ZERO_G_MAX_WEIGHT)
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
