-- TODO: proper client/server

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

    local inVacuum = zsInVacuum(player)
    ZSpaceship.VacuumSound.updateVacuumSounds(inVacuum)
    return inVacuum
end

-- Check if creature is protected from vacuum
-- Players: need suit with ZSpaceship.Tags.SpaceSuit
-- Zombies: should wear ZSpaceship.ZOMBIE_OUTFIT_ID bc they don't have same item system as players
-- TODO: check reanimated player zombies
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
        if outfitName == ZSpaceship.ZOMBIE_OUTFIT_ID then
            return true
        end
    end
    
    -- Check actual worn items (works for players, animals, and reanimated player zombies)
    local wornItems = creature:getWornItems()
    if not wornItems then return false end
    
    for i = 0, wornItems:size() - 1 do
        local item = wornItems:getItemByIndex(i)
        if item then
            -- zombies don't breathe, players need oxygen + intact suit
            local isSuit = item:hasTag(ZSpaceship.Tags.SpaceSuit)
            if isSuit then
                if isZombie then
                    return true
                end
                local hasOxygen = item:isActivated() and item:hasTank() and item:getUsedDelta() > 0
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
    mult = mult or 100 -- should scale with the frequency on applyVacuumDamage() calls

    print("Applying vacuum damage to " .. creature:getDisplayName() .. " (mult=" .. mult .. ")")
    
    -- Damage multiplier based on creature type (zombies are tougher)
    local damageMult = 1.0
    if instanceof(creature, "IsoZombie") then
        damageMult = 0.5  -- Zombies take 2x longer to die; TODO: check with bandits
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
    
    local bodyDamage = creature:getBodyDamage() or creature:getBodyDamageRemote()
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

-- Vacuum damage and sound muting
local function checkVacuum()
    local cell = getCell()
    if not cell then return end
    
    local player = getPlayer()
    local inVacuum = false
    
    -- Check if player is in vacuum (for sound muting - regardless of protection)
    if player then
        if not zsInSpace(player) then return end -- Only check for vacuum if player is in space, otherwise skip expensive checks
        inVacuum = zsInVacuum(player)
    end
    
    -- Handle vacuum sound muting (like Deaf trait)
    ZSpaceship.VacuumSound.updateVacuumSounds(inVacuum)
    
    -- Process all creatures (zombies, animals, players) in vacuum
    local objects = cell:getObjectList()
    if objects then
        for i = 0, objects:size() - 1 do
            local obj = objects:get(i)
            if obj and instanceof(obj, "IsoGameCharacter") then
                if zsInVacuum(obj) then
                    local tookDamage = applyVacuumDamage(obj)

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

Events.EveryOneMinute.Add(checkVacuum)

-- Disable weather effects in space
local function onPlayerUpdate(player)
    if not player then return end

    local sq = player:getCurrentSquare()
    if not sq then return end
    
    local inSpace = zsInSpace(sq)
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
