-- ZSpaceship No Fall Damage - Prevents fall damage in Space area
-- Uses setbClimbing(true) trick to prevent fall damage when in Space
-- When isClimbing() is true, DoLand() and handleLandingImpact() skip damage calculation

ZSpaceship = ZSpaceship or {}

-- Track previous state to avoid unnecessary updates
local wasFallingInSpace = false

local function preventFallDamageInSpace()
    local player = getPlayer()
    if not player then return end
    
    local inSpace = ZSpaceship.isInSpace(player)
    if not inSpace then
        -- Not in space - clear climbing flag if it was set
        if wasFallingInSpace then
            player:setbClimbing(false)
            wasFallingInSpace = false
        end
        return
    end
    
    -- Check if player is falling
    local isFalling = player:isbFalling() or 
                      player:getVariableBoolean("bFalling") or
                      player:getCurrentState() == PlayerFallingState.instance()
    
    if isFalling then
        -- Player is falling in space - set climbing to prevent fall damage
        if not wasFallingInSpace then
            player:setbClimbing(true)
            wasFallingInSpace = true
        end
    elseif wasFallingInSpace then
        player:setbClimbing(false)
        wasFallingInSpace = false
    end
end

Events.OnPlayerUpdate.Add(preventFallDamageInSpace)
