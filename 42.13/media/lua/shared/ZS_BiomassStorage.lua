require 'ZS_MapData'
require 'ZS_Utils'

ZSpaceship = ZSpaceship or {}

-- Initialize biomass storage objects with FluidContainer (server-only)
ZS_Utils.initSpritesOnce("initBiomassStorage", ZSpaceship.MapData.Tiles.BiomassStorage, function(obj)
    ZSpaceship.logger:debug("Initializing biomass storage for %s", tostring(obj))
    if not zsInSpace(obj) then return end

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
    fluidContainer:setContainerName("BiomassContainer") -- translated in Fluids_EN.txt
    fluidContainer:setCapacity(waterAmount)
    fluidContainer:addFluid(Fluid.Get("Biomass"), 10.0)

    GameEntityFactory.AddComponent(obj, true, fluidContainer)

    -- Sync to clients
    if isServer() then
        obj:sync()
    end
    return true
end)

--- client

local function isBiomassStorage(obj)
    local spriteName = obj:getSprite():getName()
    if not spriteName then return false end

    return ZSpaceship.MapData.Tiles.BiomassStorage[spriteName] ~= nil
end

local BIOHAZARD_ICON = getTexture("media/ui/biohazard_icon.png")

local function onFillWorldObjectContextMenu(player, context, worldobjects, _test)
    for _, obj in ipairs(worldobjects) do
        if isBiomassStorage(obj) then
            -- patch icon and name
            for _, option in ipairs(context.options) do
                -- "Water Supply Container" is hardcoded in the tile
                if option.name == "Water Supply Container" then
                    option.name = getText("Fluid_Container_BiomassContainer")
                    option.iconTexture = BIOHAZARD_ICON
                end
            end
            break
        end
    end
end
Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
