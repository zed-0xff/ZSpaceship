-- ZSpaceship No Fall Damage - Prevents fall damage in Space area
-- Uses setbClimbing(true) trick to prevent fall damage when in Space
-- When isClimbing() is true, DoLand() and handleLandingImpact() skip damage calculation

ZSpaceship = ZSpaceship or {}

-- Track previous state to avoid unnecessary updates
local wasFallingInSpace = false

local function preventFallDamageInSpace()
    local player = getPlayer()
    if not player then return end
    
    local px, py = math.floor(player:getX()), math.floor(player:getY())
    local inSpace = ZSpaceship.isInSpace(px, py)
    
    -- Check if player is falling (using multiple methods for reliability)
    local isFalling = player:isbFalling() or 
                      player:getVariableBoolean("bFalling") or
                      (player:getCurrentState() and 
                       player:getCurrentState():equals(PlayerFallingState.instance()))
    
    if inSpace and isFalling then
        -- Player is falling in Space - set climbing to prevent fall damage
        if not wasFallingInSpace then
            player:setbClimbing(true)
            wasFallingInSpace = true
        end
    else
        -- Player is not falling or not in Space - clear climbing flag
        if wasFallingInSpace then
            player:setbClimbing(false)
            wasFallingInSpace = false
        end
    end
end

Events.OnPlayerUpdate.Add(preventFallDamageInSpace)
