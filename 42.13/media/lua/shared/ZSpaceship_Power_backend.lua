-- ZSpaceship Power Backend
-- Configures vanilla generators that are already placed in the map
-- Makes them invisible and sets their condition, fuel, connected, and activated states

ZSpaceship = ZSpaceship or {}
ZSpaceship.Power = ZSpaceship.Power or {}

-- Configure or spawn a generator at the specified coordinates (at z-1)
local function initGenerator(x, y, z)
    -- Check at z-1 (one level below)
    local targetZ = z - 1
    local square = getCell():getGridSquare(x, y, targetZ)
    if not square then
        return false
    end
    
    local gen = square:getGenerator()
    
    -- If generator doesn't exist, spawn it
    if not gen then
        if isClient() then
            return false
        end
        
        local generatorItem = instanceItem("Base.Generator")
        if not generatorItem then
            print("[ZSpaceship] Failed to create generator item at " .. x .. ", " .. y .. ", " .. targetZ)
            return false
        end
        
        generatorItem:setCondition(100)
        generatorItem:getModData().fuel = 10.0  -- Full fuel
        
        local cell = getWorld():getCell()
        gen = IsoGenerator.new(generatorItem, cell, square)
        if not gen then
            print("[ZSpaceship] Failed to create generator object at " .. x .. ", " .. y .. ", " .. targetZ)
            return false
        end
        
        gen:transmitCompleteItemToClients()
        print("[ZSpaceship] Spawned generator at " .. x .. ", " .. y .. ", " .. targetZ)
    end
    
    -- Make generator invisible
    if gen.setTargetAlpha then  
        gen:setTargetAlpha(0.0)
    end
    if gen.setAlpha then
        gen:setAlpha(0.0)
    end
    
    -- Set condition (100 = perfect condition)
    gen:setCondition(100)
    
    -- Set fuel (10.0 = full tank)
    gen:setFuel(10.0)
    
    if not gen:isConnected() then
        gen:setConnected(true)
    end

    if not gen:isActivated() then
        if ZSpaceship.Power.getCurrentAmount() >= 1.0 then
            gen:setActivated(true)
        end
    else
        if ZSpaceship.Power.getCurrentAmount() <= 0 then
            gen:setActivated(false)
        end
    end
    
    return true
end

-- Configure all generators from MapData.Default.Locations["Generator"]
local function checkGenerators()
    if not ZSpaceship.MapData or not ZSpaceship.MapData.Default or not ZSpaceship.MapData.Default.Locations then
        return
    end
    
    local generators = ZSpaceship.MapData.Default.Locations["Generator"]
    if not generators then
        return
    end
    
    for i, gen in ipairs(generators) do
        initGenerator(gen.x, gen.y, gen.z)
    end
end

Events.OnGameStart.Add(checkGenerators)
Events.EveryTenMinutes.Add(checkGenerators)