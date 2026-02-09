-- Vacuum damage handling for ZSpaceship mod
-- Handles creature damage and weather control
-- Breach detection is handled in ZS_VacuumBreach.lua
-- Sound muting is handled in ZS_VacuumSound.lua

ZSpaceship = ZSpaceship or {}

-- Check if room is breached (open door, missing wall, floor, or roof)
-- Delegates to ZSRoom:isBreached() which is the source of truth
function ZSpaceship.isRoomBreached(room)
    if not room then return true end
    
    local zsRoom = ZSRooms.getOrCreate(room)
    if not zsRoom then return true end

    return zsRoom:isBreached()
end

-- Check if player is in vacuum and update sounds accordingly
function ZSpaceship.checkAndUpdateVacuumState(player)
    if not player then return false end
    local sq = player:getCurrentSquare()
    if not sq then return false end
    
    local inVacuum = false
    if ZSpaceship.isInSpace(sq) then
        local room = sq:getRoom()
        inVacuum = not room or ZSpaceship.isRoomBreached(room, {})
    end
    
    ZSpaceship.VacuumSound.updateVacuumSounds(inVacuum)
    return inVacuum
end

-- Check if creature is protected from vacuum
-- Players: need Hazmat suit (SCBA) activated with oxygen in tank
-- Zombies: need Hazmat suit (SCBA) activated (no oxygen needed - they don't breathe)
function ZSpaceship.isProtectedFromVacuum(creature)
    if not creature then return false end
    
    -- God mode = protected
    if creature.isGodMod and creature:isGodMod() then
        return true
    end
    
    local isZombie = instanceof(creature, "IsoZombie")
    
    -- For zombies, check outfit name first (randomly spawned zombies)
    if isZombie then
        local outfitName = creature:getOutfitName()
        if outfitName and string.find(string.lower(outfitName), "hazard") then
            return true
        end
    end
    
    -- Check actual worn items (works for players, animals, and reanimated player zombies)
    local wornItems = creature:getWornItems()
    if not wornItems then return false end
    
    for i = 0, wornItems:size() - 1 do
        local item = wornItems:getItemByIndex(i)
        if item then
            -- Space suit or SCBA (Hazmat) - zombies don't breathe, players need oxygen + intact suit
            local isSuit = item:getFullType() == "ZSpaceship.SpaceSuitA"
            local isSCBA = instanceof(item, "Clothing") and item:hasTag(ItemTag.SCBA)
            if isSuit or isSCBA then
                if isZombie then
                    return true
                end
                local hasOxygen = item:isActivated() and item:hasTank() and item:getUsedDelta() > 0.0
                local isIntact = not item.getHolesNumber or item:getHolesNumber() == 0
                if hasOxygen and isIntact then
                    return true
                end
            end
        end
    end
    
    return false
end

-- Apply vacuum damage to any creature (zombie, animal, player)
local function applyVacuumDamage(creature, mult)
    if not creature or creature:isDead() then return false end
    
    -- Damage multiplier based on creature type (zombies are tougher)
    local damageMult = 1.0
    if instanceof(creature, "IsoZombie") then
        damageMult = 0.5  -- Zombies take 2x longer to die
    end

    if ZSpaceship.isProtectedFromVacuum(creature) then
        return false
    end
    
    -- Player-specific protection checks
    if instanceof(creature, "IsoPlayer") then
        -- Fatigue increase for players
        local stats = creature:getStats()
        if stats and stats:get(CharacterStat.FATIGUE) < 1.0 then
            stats:add(CharacterStat.FATIGUE, 1.0E-4 * mult)
        end
    end
    
    local bodyDamage = creature:getBodyDamage()
    if bodyDamage then
        -- Head damage (eyes/ears bursting from pressure)
        local head = bodyDamage:getBodyPart(BodyPartType.Head)
        if head then
            head:ReduceHealth(0.15 * mult * damageMult)
            head:setBleeding(true)
            head:setBleedingTime(10.0)
        end
        
        -- Torso damage (lungs)
        local torso = bodyDamage:getBodyPart(BodyPartType.Torso_Upper)
        if torso then
            torso:ReduceHealth(0.1 * mult * damageMult)
        end
    end
    
    -- Overall health reduction
    local health = creature:getHealth()
    creature:setHealth(health - 0.005 * mult * damageMult)
    return true
end

-- Check if a creature (zombie/animal) is in vacuum
function ZSpaceship.isCreatureInVacuum(creature)
    if not creature then return false end
    local sq = creature:getSquare()
    if not sq then return false end
    
    -- Must be in space zone
    if not ZSpaceship.isInSpace(sq) then
        return false
    end
    
    local room = sq:getRoom()
    if not room then
        return true -- Not in any room = vacuum
    end
    
    return ZSpaceship.isRoomBreached(room, {})
end

-- Throttle for expensive vacuum checks
local vacuumCheckAccumulator = 0
local VACUUM_CHECK_INTERVAL = 2.0  -- seconds (increased from 1.0)
local soundCheckAccumulator = 0
local SOUND_CHECK_INTERVAL = 0.5  -- seconds (throttle sound checks to twice per second)

-- Cache last vacuum state to avoid expensive checks every tick
ZSpaceship.lastVacuumState = false

-- Vacuum damage and sound muting
local function checkVacuum(ticks)
    local mult = getGameTime():getThirtyFPSMultiplier()
    local cell = getCell()
    
    local player = getPlayer()
    local inVacuum = false
    
    -- Accumulate time for sound checks (throttled to reduce expensive room breach checks)
    soundCheckAccumulator = soundCheckAccumulator + (mult / 30.0)
    local doSoundCheck = soundCheckAccumulator >= SOUND_CHECK_INTERVAL
    if doSoundCheck then
        soundCheckAccumulator = 0
    end
    
    -- Check if player is in vacuum (for sound muting - regardless of protection)
    -- Throttled to reduce expensive room breach checks
    if player and doSoundCheck then
        inVacuum = ZSpaceship.isCreatureInVacuum(player)
        -- Store last vacuum state for caching
        ZSpaceship.lastVacuumState = inVacuum
    elseif player then
        -- Use cached value between checks
        inVacuum = ZSpaceship.lastVacuumState or false
    end
    
    -- Accumulate time for throttled checks
    vacuumCheckAccumulator = vacuumCheckAccumulator + (mult / 30.0)
    local doHeavyChecks = vacuumCheckAccumulator >= VACUUM_CHECK_INTERVAL
    if doHeavyChecks then
        vacuumCheckAccumulator = 0
    end
    
    -- Process all creatures (zombies, animals, players) in vacuum
    -- Only run every VACUUM_CHECK_INTERVAL seconds (currently 2.0 seconds)
    if cell and doHeavyChecks then
        -- Scale damage to account for running at interval instead of every tick
        -- (mult ~= 1.0 at 30fps, so 30 ticks/second * interval = damage per check)
        local damageMult = VACUUM_CHECK_INTERVAL * 30
        
        local objects = cell:getObjectList()
        if objects then
            for i = 0, objects:size() - 1 do
                local obj = objects:get(i)
                if obj and instanceof(obj, "IsoGameCharacter") then
                    if ZSpaceship.isCreatureInVacuum(obj) then
                        local tookDamage = applyVacuumDamage(obj, damageMult)
                        
                        -- Visual bark for player taking damage (every ~2 seconds)
                        if obj == player and tookDamage and player.Say then
                            if not ZSpaceship.lastBreathBark or (getTimestamp() - ZSpaceship.lastBreathBark) > 2000 then
                                player:Say(getText("UI_ZS_CantBreathe"))
                                ZSpaceship.lastBreathBark = getTimestamp()
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Handle vacuum sound muting (like Deaf trait)
    ZSpaceship.VacuumSound.updateVacuumSounds(inVacuum)
end

Events.OnTick.Add(checkVacuum)

-- Disable weather effects in space
local function onPlayerUpdate(player)
    if not player then return end
    local sq = player:getCurrentSquare()
    if not sq then return end
    
    local inSpace = ZSpaceship.isInSpace(sq)
    local climate = getClimateManager()
    
    if inSpace then
        local fogFloat = climate:getClimateFloat(ClimateManager.FLOAT_FOG_INTENSITY)
        local precipFloat = climate:getClimateFloat(ClimateManager.FLOAT_PRECIPITATION_INTENSITY)
        local windFloat = climate:getClimateFloat(ClimateManager.FLOAT_WIND_INTENSITY)
        local cloudFloat = climate:getClimateFloat(ClimateManager.FLOAT_CLOUD_INTENSITY)
        
        if fogFloat then
            fogFloat:setEnableAdmin(true)
            fogFloat:setAdminValue(0)
        end
        if precipFloat then
            precipFloat:setEnableAdmin(true)
            precipFloat:setAdminValue(0)
        end
        if windFloat then
            windFloat:setEnableAdmin(true)
            windFloat:setAdminValue(0)
        end
        if cloudFloat then
            cloudFloat:setEnableAdmin(true)
            cloudFloat:setAdminValue(0)
        end
        
        local cell = getCell()
        if cell and cell:getWeatherFX() then
            cell:getWeatherFX():setFogIntensity(0)
            cell:getWeatherFX():setPrecipitationIntensity(0)
        end
    else
        local fogFloat = climate:getClimateFloat(ClimateManager.FLOAT_FOG_INTENSITY)
        local precipFloat = climate:getClimateFloat(ClimateManager.FLOAT_PRECIPITATION_INTENSITY)
        local windFloat = climate:getClimateFloat(ClimateManager.FLOAT_WIND_INTENSITY)
        local cloudFloat = climate:getClimateFloat(ClimateManager.FLOAT_CLOUD_INTENSITY)
        
        if fogFloat then fogFloat:setEnableAdmin(false) end
        if precipFloat then precipFloat:setEnableAdmin(false) end
        if windFloat then windFloat:setEnableAdmin(false) end
        if cloudFloat then cloudFloat:setEnableAdmin(false) end
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)

-- Restore climate when exiting game (sound is handled in ZS_VacuumSound.lua)
local function restoreOnExit()
    local climate = getClimateManager()
    if climate then
        local fogFloat = climate:getClimateFloat(ClimateManager.FLOAT_FOG_INTENSITY)
        local precipFloat = climate:getClimateFloat(ClimateManager.FLOAT_PRECIPITATION_INTENSITY)
        local windFloat = climate:getClimateFloat(ClimateManager.FLOAT_WIND_INTENSITY)
        local cloudFloat = climate:getClimateFloat(ClimateManager.FLOAT_CLOUD_INTENSITY)
        
        if fogFloat then fogFloat:setEnableAdmin(false) end
        if precipFloat then precipFloat:setEnableAdmin(false) end
        if windFloat then windFloat:setEnableAdmin(false) end
        if cloudFloat then cloudFloat:setEnableAdmin(false) end
    end
end

Events.OnMainMenuEnter.Add(restoreOnExit)
Events.OnDisconnect.Add(restoreOnExit)
