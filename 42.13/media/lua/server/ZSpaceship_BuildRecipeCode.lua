-- Build recipe callbacks for ZSpaceship mod

if not ZSpaceship then
    ZSpaceship = {}
end

function ZSpaceship.PSU_OnCreate(params)
    local thumpable = params.thumpable
    local character = params.character
    
    -- Mark this as a ZSpaceship Power Storage Unit
    thumpable:setName("Power Storage Unit")
    thumpable:setCanPassThrough(true)  -- Allow walking through
    thumpable:getModData().ZSpaceshipPowerStorage = true
    thumpable:getModData().energyStored = 0
    thumpable:getModData().energyCapacity = 1000  -- 1000 MJ capacity
    
    print("[ZSpaceship] Power Storage Unit created at " .. tostring(thumpable:getX()) .. ", " .. tostring(thumpable:getY()))
end
