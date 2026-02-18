-- Initialize biomass storage objects with FluidContainer (server-only)
ZSpaceship = ZSpaceship or {}

local function initBiomassStorage(obj)
    print("Initializing biomass storage for: " .. tostring(obj))
    if not obj or not obj.getSquare then return end

    local sq = obj:getSquare()
    if not sq or not zsIsInSpace(sq) then return end

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
    if not ZSpaceship.isInitialNewGame("BiomassStorage") then return end

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

local BIOHAZARD_ICON = getTexture("media/ui/biohazard_icon.png")

local function onFillWorldObjectContextMenu(player, context, worldobjects, _test)
    for _, obj in ipairs(worldobjects) do
        if isBiomassStorage(obj) then
            -- patch icon and name
            for _, option in ipairs(context.options) do
                if option.name == "Water Supply Container" then
                    option.name = "Biomass Container"
                    option.iconTexture = BIOHAZARD_ICON
                end
            end
            break
        end
    end
end
Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
