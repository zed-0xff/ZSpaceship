-- Initialize water storage objects with FluidContainer (server-only)
ZSpaceship = ZSpaceship or {}

ZS_Utils.initSpritesOnce("initWaterStorage", ZSpaceship.MapData.Tiles.WaterStorage, function(obj)
    ZSpaceship.logger:debug("Initializing water storage for %s", tostring(obj))
    if not obj or not obj.getSquare then return end

    local sq = obj:getSquare()
    if not sq or not zsInSpace(sq) then return end

    -- Skip if already has FluidContainer (avoid duplicates on reload)
    if obj:getFluidContainer() then return end

    -- Get WaterAmount from sprite properties, fallback to 100
    local waterAmount = 100.0
    if obj:getSprite() and obj:getSprite():getProperties() then
        local props = obj:getSprite():getProperties()
        if props then
            local amountStr = props:get(IsoPropertyType.WaterAmount or IsoPropertyType.WATER_AMOUNT) -- latter is 42.14
            if amountStr then
                waterAmount = tonumber(amountStr) or 100.0
            end
        end
    end

    -- Create and add FluidContainer component
    local fluidContainer = ComponentType.FluidContainer:CreateComponent()
    fluidContainer:setCapacity(waterAmount)
    fluidContainer:addFluid(FluidType.Water, 30.0)
    GameEntityFactory.AddComponent(obj, true, fluidContainer)

    -- Sync to clients
    if isServer() then
        obj:sync()
    end
    return true
end)
