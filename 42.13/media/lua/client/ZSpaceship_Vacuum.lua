-- Vacuum handling for ZSpaceship mod
-- Handles breach detection, damage, sound blocking, and weather control

ZSpaceship = ZSpaceship or {}

-- Sound state for vacuum muting
ZSpaceship.savedSoundVolume = nil
ZSpaceship.savedMusicVolume = nil
ZSpaceship.savedAmbientVolume = nil
ZSpaceship.savedVehicleVolume = nil
ZSpaceship.wasInVacuum = false

-- Check a square for open doors, given direction from room
local function checkSquareForOpenDoor(sq, fromX, fromY)
    if not sq then return false end
    local specials = sq:getSpecialObjects()
    
    for j = 0, specials:size() - 1 do
        local obj = specials:get(j)
        local isDoor = instanceof(obj, "IsoDoor") or 
                      (instanceof(obj, "IsoThumpable") and obj:isDoor())
        
        if isDoor and obj:IsOpen() then
            -- Check the square on the OPPOSITE side from the room
            local dx = sq:getX() - fromX
            local dy = sq:getY() - fromY
            local outsideSq = getSquare(sq:getX() + dx, sq:getY() + dy, sq:getZ())
            if not outsideSq or not outsideSq:isInARoom() then
                return true
            end
        end
    end
    return false
end

-- Check if room is breached (open door, missing wall, floor, or roof)
local function isRoomBreached(room)
    if not room then return true end
    local squares = room:getSquares()
    if not squares then return true end
    
    -- Build a set of room squares for quick lookup
    local roomSquares = {}
    for i = 0, squares:size() - 1 do
        local sq = squares:get(i)
        if sq then
            roomSquares[sq:getX() .. "," .. sq:getY()] = true
        end
    end
    
    for i = 0, squares:size() - 1 do
        local sq = squares:get(i)
        if sq then
            local x, y, z = sq:getX(), sq:getY(), sq:getZ()
            
            -- Check floor
            if not sq:getFloor() then
                return true
            end
            
            -- Check roof (floor tile at z+1)
            local roofSq = getSquare(x, y, z + 1)
            if not roofSq or not roofSq:getFloor() then
                return true
            end
            
            -- Check walls on boundary (adjacent squares not in room)
            -- North boundary: need wall on current square facing north
            local northSq = getSquare(x, y - 1, z)
            if not northSq or not roomSquares[x .. "," .. (y-1)] then
                if not sq:getWall(true) then
                    if northSq then
                        if not checkSquareForOpenDoor(sq, x, y - 1) then
                            local door = sq:getDoor(true)
                            if not door then
                                return true
                            end
                        else
                            return true -- Open door = breach
                        end
                    else
                        return true
                    end
                end
            end
            
            -- West boundary: need wall on current square facing west  
            local westSq = getSquare(x - 1, y, z)
            if not westSq or not roomSquares[(x-1) .. "," .. y] then
                if not sq:getWall(false) then
                    if westSq then
                        if not checkSquareForOpenDoor(sq, x - 1, y) then
                            local door = sq:getDoor(false)
                            if not door then
                                return true
                            end
                        else
                            return true
                        end
                    else
                        return true
                    end
                end
            end
            
            -- South boundary: need wall on south square facing north
            local southSq = getSquare(x, y + 1, z)
            if southSq and not roomSquares[x .. "," .. (y+1)] then
                if not southSq:getWall(true) then
                    if not checkSquareForOpenDoor(southSq, x, y) then
                        local door = southSq:getDoor(true)
                        if not door then
                            return true
                        end
                    else
                        return true
                    end
                end
            end
            
            -- East boundary: need wall on east square facing west
            local eastSq = getSquare(x + 1, y, z)
            if eastSq and not roomSquares[(x+1) .. "," .. y] then
                if not eastSq:getWall(false) then
                    if not checkSquareForOpenDoor(eastSq, x, y) then
                        local door = eastSq:getDoor(false)
                        if not door then
                            return true
                        end
                    else
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- Expose for other modules
ZSpaceship.isRoomBreached = isRoomBreached

-- Check if a creature (zombie/animal) is in vacuum
function ZSpaceship.isCreatureInVacuum(creature)
    if not creature then return false end
    local sq = creature:getSquare()
    if not sq then return false end
    
    -- Must be in space zone
    if not ZSpaceship.isInSpace(sq:getX(), sq:getY()) then
        return false
    end
    
    local room = sq:getRoom()
    if not room then
        return true -- Not in any room = vacuum
    end
    
    return isRoomBreached(room)
end

-- Hook global addSound to block sounds in vacuum
local originalAddSound = nil

local function hookAddSound()
    if originalAddSound then return end
    originalAddSound = addSound
    
    addSound = function(source, x, y, z, radius, volume)
        -- Check if in space zone
        if ZSpaceship.isInSpace(x, y) then
            local sq = getSquare(x, y, z)
            if sq then
                local room = sq:getRoom()
                if not room or isRoomBreached(room) then
                    -- In vacuum - block sound entirely
                    return nil
                end
            end
        end
        return originalAddSound(source, x, y, z, radius, volume)
    end
end

Events.OnGameStart.Add(hookAddSound)

-- Vacuum damage and sound muting
local function checkVacuum(ticks)
    local player = getPlayer()
    if not player then return end
    
    local square = player:getSquare()
    if not square then return end
    
    local inVacuum = false
    
    -- Check if in spaceship zone
    if ZSpaceship.isInSpace(square:getX(), square:getY()) then
        local room = square:getRoom()
        
        if not room then
            inVacuum = true
        else
            inVacuum = isRoomBreached(room)
        end
        
        if inVacuum then
            local isProtected = player:isProtectedFromToxic(false)
            
            if not isProtected then
                local stats = player:getStats()
                local bodyDamage = player:getBodyDamage()
                local mult = getGameTime():getThirtyFPSMultiplier()
                
                -- Fatigue increase
                if stats:get(CharacterStat.FATIGUE) < 1.0 then
                    stats:add(CharacterStat.FATIGUE, 1.0E-4 * mult)
                end
                
                -- Health damage to Upper Torso
                local torso = bodyDamage:getBodyPart(BodyPartType.Torso_Upper)
                if torso then torso:ReduceHealth(0.1 * mult) end
                
                -- Health damage to Head if very fatigued
                if stats:get(CharacterStat.FATIGUE) > 0.8 then
                    local head = bodyDamage:getBodyPart(BodyPartType.Head)
                    if head then head:ReduceHealth(0.1 * mult) end
                end
                
                -- Visual bark
                local t = ticks
                if type(t) ~= "number" then t = 0 end
                if math.floor(t) % 60 == 0 then
                    if player.Say then
                        player:Say("I can't breathe!")
                    end
                end
            end
        end
    end
    
    -- Handle vacuum sound muting (like Deaf trait)
    local soundManager = getSoundManager()
    if inVacuum and not ZSpaceship.wasInVacuum then
        -- Entering vacuum: save current volumes and mute all sounds
        ZSpaceship.savedSoundVolume = soundManager:getSoundVolume()
        ZSpaceship.savedMusicVolume = soundManager:getMusicVolume()
        ZSpaceship.savedAmbientVolume = soundManager:getAmbientVolume()
        ZSpaceship.savedVehicleVolume = soundManager:getVehicleEngineVolume()
        soundManager:setSoundVolume(0)
        soundManager:setMusicVolume(0)
        soundManager:setAmbientVolume(0)
        soundManager:setVehicleEngineVolume(0)
        ZSpaceship.wasInVacuum = true
    elseif not inVacuum and ZSpaceship.wasInVacuum then
        -- Leaving vacuum: restore saved volumes
        if ZSpaceship.savedSoundVolume then
            soundManager:setSoundVolume(ZSpaceship.savedSoundVolume)
        end
        if ZSpaceship.savedMusicVolume then
            soundManager:setMusicVolume(ZSpaceship.savedMusicVolume)
        end
        if ZSpaceship.savedAmbientVolume then
            soundManager:setAmbientVolume(ZSpaceship.savedAmbientVolume)
        end
        if ZSpaceship.savedVehicleVolume then
            soundManager:setVehicleEngineVolume(ZSpaceship.savedVehicleVolume)
        end
        ZSpaceship.wasInVacuum = false
    end
end

Events.OnTick.Add(checkVacuum)

-- Disable weather effects in space
local function onPlayerUpdate(player)
    if not player then return end
    local sq = player:getCurrentSquare()
    if not sq then return end
    
    local inSpace = ZSpaceship.isInSpace(sq:getX(), sq:getY())
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

-- Restore sound volumes and climate when exiting game
local function restoreOnExit()
    if ZSpaceship.wasInVacuum then
        local soundManager = getSoundManager()
        if ZSpaceship.savedSoundVolume then
            soundManager:setSoundVolume(ZSpaceship.savedSoundVolume)
        end
        if ZSpaceship.savedMusicVolume then
            soundManager:setMusicVolume(ZSpaceship.savedMusicVolume)
        end
        if ZSpaceship.savedAmbientVolume then
            soundManager:setAmbientVolume(ZSpaceship.savedAmbientVolume)
        end
        if ZSpaceship.savedVehicleVolume then
            soundManager:setVehicleEngineVolume(ZSpaceship.savedVehicleVolume)
        end
        ZSpaceship.wasInVacuum = false
    end
    
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
