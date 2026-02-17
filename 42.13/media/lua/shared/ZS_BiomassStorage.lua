-- Initialize biomass storage objects with FluidContainer (server-only)
ZSpaceship = ZSpaceship or {}

local function initBiomassStorage(obj)
    print("Initializing biomass storage for: " .. tostring(obj))
    if not obj or not obj.getSquare then return end

    local sq = obj:getSquare()
    if not sq or not ZSpaceship.isInSpace(sq) then return end

    -- Skip if already has FluidContainer (avoid duplicates on reload)
    if obj:getFluidContainer() then return end

    -- Get WaterAmount from sprite properties, fallback to 100
    local waterAmount = 100.0
    if obj:getSprite() and obj:getSprite():getProperties() then
        local props = obj:getSprite():getProperties()
        if props then
            local amountStr = props:get(IsoPropertyType.WaterAmount)
            if amountStr then
                waterAmount = tonumber(amountStr) or 100.0
            end
        end
    end

    -- Create and add FluidContainer component
    local fluidContainer = ComponentType.FluidContainer:CreateComponent()
    fluidContainer:setCapacity(waterAmount)
    fluidContainer:addFluid(Fluid.Get("Biomass"), 10.0)
    GameEntityFactory.AddComponent(obj, true, fluidContainer)

    -- Sync to clients
    if isServer() then
        obj:sync()
    end
end

Events.OnNewGame.Add(function()
    local biomass_storage_tiles = ZSpaceship.MapData and ZSpaceship.MapData.Tiles and ZSpaceship.MapData.Tiles["BiomassStorage"] or {}
    for _, tile_name in ipairs(biomass_storage_tiles) do
        MapObjects.OnNewWithSprite(tile_name, initBiomassStorage, 10)
    end
end)

--- client
local function isBiomassStorage(obj)
    local spriteName = obj:getSprite():getName()
    if not spriteName then return false end

    return ZSpaceship.MapData.Tiles["BiomassStorage"][spriteName] ~= nil
end

local function onFillWorldObjectContextMenu(player, context, worldobjects, _test)
    for _, obj in ipairs(worldobjects) do
        if isBiomassStorage(obj) then
            -- patch icon and name
            microscope = obj
            break
        end
    end
end
Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)