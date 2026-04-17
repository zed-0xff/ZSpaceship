-- ZSpaceship Zero-G - Zero gravity effects in Space area
-- 1. No fall damage: setbClimbing(true) trick so DoLand()/handleLandingImpact() skip damage
-- 2. No heavy load: Boosts maxWeight so HeavyLoad moodle stays at 0

ZSpaceship = ZSpaceship or {}

local ZERO_G_MAX_WEIGHT = 500

local wasFallingInSpace = {}

-- see IsoPlayer.java updateEndurance()
local function compensateCorpseDraggingEndurance(player)
    if not player:isMoving() then return end

    local sneakMultiplier = 1.0
    if player:isSneaking() then
        sneakMultiplier = 1.5
    end

    local enduranceReduce = ZomboidGlobals.SprintingEnduranceReduce;
    local enddelta = 1.4

    if player:hasTrait(CharacterTrait.OVERWEIGHT) then enddelta = 2.9 end
    if player:hasTrait(CharacterTrait.ATHLETIC)   then enddelta = 0.8 end

    local enddelta2 = enddelta * 2.3 * player:getPacingMod() * player:getHyperthermiaMod()
    local mod = 0.7
    if player:hasTrait(CharacterTrait.ASTHMATIC)  then mod = 1.0 end

    local delta = enduranceReduce * enddelta2 * 0.5 * mod * GameTime.instance:getMultiplier() * sneakMultiplier
    if delta <= 0 or delta > 25 then return end -- something calculated wrong

    player:getStats():add(CharacterStat.ENDURANCE, delta)
end

local function updateSpacePhysics()
    local player = getPlayer()
    if not player then return end
    
    local pid = player:getID() -- or getPlayerNum() ?
    local inSpace = zsInSpace(player)
    
    if not inSpace then
        if wasFallingInSpace[pid] then
            player:setbClimbing(false)
            wasFallingInSpace[pid] = nil
        end
        return
    end

    -- less endurance reduce when dragging corpses
    if player.isDraggingCorpse and player:isDraggingCorpse() then
        compensateCorpseDraggingEndurance(player)
    end
    
    -- Zero gravity: no heavy load moodle
    -- BodyDamage recalculates maxWeight from maxWeightBase naturally, so no manual restore needed
    if player:getMaxWeight() < ZERO_G_MAX_WEIGHT then
        player:setMaxWeight(ZERO_G_MAX_WEIGHT)
    end
    
    -- Zero gravity: no fall damage
    local isFalling = (player:isbFalling() or player:getVariableBoolean("bFalling") or player:getCurrentState() == PlayerFallingState.instance())
        and not player:getSquare():getFloor()
    
    if isFalling then
        if not wasFallingInSpace[pid] then
            player:setbClimbing(true)
            wasFallingInSpace[pid] = true
        end
    elseif wasFallingInSpace[pid] then
        player:setbClimbing(false)
        wasFallingInSpace[pid] = nil
    end
end

Events.OnPlayerUpdate.Add(updateSpacePhysics)
