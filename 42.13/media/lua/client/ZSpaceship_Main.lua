ZSpaceship = ZSpaceship or {}
ZSpaceship.ShipX = 20000
ZSpaceship.ShipY = 20000
ZSpaceship.ShipZ = 0

-- Range around ShipX, ShipY that is considered "Spaceship Zone"
ZSpaceship.ShipRange = 100 

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
        if math.abs(player:getX() - ZSpaceship.ShipX) < ZSpaceship.ShipRange and
           math.abs(player:getY() - ZSpaceship.ShipY) < ZSpaceship.ShipRange then
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

-- Vacuum Logic
local function checkVacuum(ticks)
    local player = getPlayer()
    if not player or not player:getSquare() then return end
    
    local x = player:getX()
    local y = player:getY()
    
    -- Check if in spaceship zone
    if math.abs(x - ZSpaceship.ShipX) < ZSpaceship.ShipRange and 
       math.abs(y - ZSpaceship.ShipY) < ZSpaceship.ShipRange then
        
        local square = player:getSquare()
        local building = square:getBuilding()
        local isVacuum = square:isOutside() or (square:getRoom() == nil)
        
        -- Reuse vanilla building toxicity for indoor vacuum
        if building then
            building:setToxic(isVacuum)
        end
        
        -- Character is in vacuum if outside OR in a toxic building
        local inVacuum = isVacuum or (building and building:isToxic())
        
        if inVacuum then
            -- Check protection without draining (drain is handled by the engine if in toxic building)
            -- If we are outside, the engine doesn't automatically drain, so we might need to handle it.
            -- However, Build 42 is adding more systemic protection.
            local isProtected = player:isProtectedFromToxic(false)
            
            if not isProtected then
                -- Apply manual damage ONLY if outside (engine handles indoor toxic damage)
                if isVacuum and not (building and building:isToxic()) then
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
end

Events.OnTick.Add(checkVacuum)
