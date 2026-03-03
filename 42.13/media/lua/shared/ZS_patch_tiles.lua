-- should be applied by vanilla's media/lua/shared/Util/CustomTileProps.lua
if type(CustomTileProps_RemovePair) ~= "table" then
    print("[?] ZS_patch_tiles: CustomTileProps_RemovePair is not a table")
    return
end

-- these are fluorescent wall almost-at-ceiling lamp tiles
-- they shouldn't block placement of any stuff below them
local tiles = {
    "lighting_indoor_02_44",
    "lighting_indoor_02_45",
    "lighting_indoor_02_46",
    "lighting_indoor_02_47",
}

for _, tileName in ipairs(tiles) do
    CustomTileProps_RemovePair[tileName] = { "BlocksPlacement" }
end

-- but vanilla does not call CreateKeySet() after patching, so it stays stale
-- which results in square:getProperties():has("BlocksPlacement") being true
-- even though all of the underlying tiles have it unset
local function onGameStart()
    for _, tileName in ipairs(tiles) do
        local tile = IsoSpriteManager.instance:getSprite(tileName)
        if tile and tile.getProperties then
            local props = tile:getProperties()
            if props and props.CreateKeySet then
                props:CreateKeySet()
            end
        end
    end
end

Events.OnGameStart.Add(onGameStart)
Events.OnServerStarted.Add(onGameStart)

if CustomTileProps_SetPair then
    for i = 24, 27 do
        -- [Recycler] vanilla "IV Stand" tile has the "CanScrap" flag, but no materials
        local tileName = "location_community_medical_01_" .. tostring(i)
        CustomTileProps_SetPair[tileName] = {
            Material  = "MetalPipe",
            Material2 = "MetalScrap",
        }
    end
end
