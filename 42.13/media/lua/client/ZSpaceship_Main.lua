ZSpaceship = ZSpaceship or {}

-- Space cell coordinates
ZSpaceship.SpaceCellX = 78
ZSpaceship.SpaceCellY = 78

-- Cell boundaries (cell is 256x256)
ZSpaceship.SpaceMinX = ZSpaceship.SpaceCellX * 256
ZSpaceship.SpaceMaxX = (ZSpaceship.SpaceCellX + 1) * 256
ZSpaceship.SpaceMinY = ZSpaceship.SpaceCellY * 256
ZSpaceship.SpaceMaxY = (ZSpaceship.SpaceCellY + 1) * 256

-- Ship position (center of cell for teleporting)
ZSpaceship.ShipX = ZSpaceship.SpaceMinX + 128
ZSpaceship.ShipY = ZSpaceship.SpaceMinY + 128
ZSpaceship.ShipZ = 0

-- Sound state for vacuum muting
ZSpaceship.savedSoundVolume = nil
ZSpaceship.savedMusicVolume = nil
ZSpaceship.savedAmbientVolume = nil
ZSpaceship.savedVehicleVolume = nil
ZSpaceship.wasInVacuum = false

-- Check if coordinates are in space (full cell)
function ZSpaceship.isInSpace(x, y)
    return x >= ZSpaceship.SpaceMinX and x < ZSpaceship.SpaceMaxX and
           y >= ZSpaceship.SpaceMinY and y < ZSpaceship.SpaceMaxY
end

function ZSpaceship.TeleportToRandom(player)
    -- Teleport to random location in the county (0 to 15000)
    local x = ZombRand(2000, 13000)
    local y = ZombRand(2000, 13000)
    player:setX(x)
    player:setY(y)
    player:setZ(0)
    player:setLx(x)
    player:setLy(y)
    player:setLz(0)
    
    player:Say("Beam me up, Scotty!")
end

function ZSpaceship.TeleportToShip(player)
    player:setX(ZSpaceship.ShipX)
    player:setY(ZSpaceship.ShipY)
    player:setZ(ZSpaceship.ShipZ)
    player:setLx(ZSpaceship.ShipX)
    player:setLy(ZSpaceship.ShipY)
    player:setLz(ZSpaceship.ShipZ)
    
    player:Say("Energizing...")
end

-- Context Menu for Teleporter (World Object)
local function doWorldContextMenu(playerNum, context, worldobjects, test)
    if test then return end
    local player = getSpecificPlayer(playerNum)
    
    -- Check for static teleporter in world
    local teleporterObj = nil
    for _, obj in ipairs(worldobjects) do
        if obj.getSprite then
            local sprite = obj:getSprite()
            if sprite and sprite:getName() == "blends_street_01_87" then
                teleporterObj = obj
                break
            end
        end
    end

    if teleporterObj then
        -- Only allow in the ship area, in case this sprite exists elsewhere.
        if ZSpaceship.isInSpace(player:getX(), player:getY()) then
            context:addOption("Beam me up, Scotty", player, ZSpaceship.TeleportToRandom)
        end
    end
end

-- Context Menu for Communicator (Inventory Item)
local function doInventoryContextMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    local inv = player:getInventory()
    
    local communicator = inv:getItemFromType("ZSpaceship.Communicator")
    if communicator then
        context:addOption("Return to Spaceship", player, ZSpaceship.TeleportToShip)
    end
end

Events.OnFillWorldObjectContextMenu.Add(doWorldContextMenu)
Events.OnFillInventoryObjectContextMenu.Add(doInventoryContextMenu)

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
                -- North is outside, need north wall on this square
                if not sq:getWall(true) then
                    -- Check for open door instead
                    if northSq then
                        if not checkSquareForOpenDoor(sq, x, y - 1) then
                            -- No wall and no closed door = breach
                            local door = sq:getDoor(true)
                            if not door then
                                return true
                            end
                        else
                            return true -- Open door = breach
                        end
                    else
                        return true -- No square and no wall
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

-- Vacuum Logic
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
            -- Not in any defined room = vacuum
            inVacuum = true
        else
            -- In a room, check if breached (open door, missing wall/floor/roof)
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
        -- Override climate settings to disable weather effects
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
        
        -- Also set WeatherFX directly for immediate effect
        local cell = getCell()
        if cell and cell:getWeatherFX() then
            cell:getWeatherFX():setFogIntensity(0)
            cell:getWeatherFX():setPrecipitationIntensity(0)
        end
    else
        -- Disable admin override when leaving space
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
    -- Restore sound volumes
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
    
    -- Restore climate admin overrides
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
