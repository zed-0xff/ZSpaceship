ZSpaceship = ZSpaceship or {}
ZSpaceship.MapData = ZSpaceship.MapData or {}

-- Cell coordinates
ZSpaceship.MapData.CellX = 78
ZSpaceship.MapData.CellY = 78

ZSpaceship.MapData.Default = ZSpaceship.MapData.Default or {}

-- Room centers
ZSpaceship.MapData.Default.Rooms = {
  { x = 20101, y = 20085, z = 10, name = "cockpit" },
  { x = 20097, y = 20089, z = 10, name = "bathroom" },
  { x = 20101, y = 20091, z = 10, name = "zs_longhub" },
  { x = 20105, y = 20089, z = 10, name = "hub" },
  { x = 20097, y = 20093, z = 10, name = "zs_teleport_room" },
  { x = 20105, y = 20093, z = 10, name = "hub" },
  { x = 20090, y = 20097, z = 10, name = "medical" },
  { x = 20097, y = 20097, z = 10, name = "zs_library" },
  { x = 20101, y = 20099, z = 10, name = "zs_longhub" },
  { x = 20105, y = 20097, z = 10, name = "smallR" },
  { x = 20097, y = 20101, z = 10, name = "zs_kitchen" },
  { x = 20105, y = 20101, z = 10, name = "zs_bedroom" },
  { x = 20101, y = 20106, z = 10, name = "zs_energy_storage" },
  { x = 20101, y = 20087, z = 10, name = "hall" },
  { x = 20099, y = 20089, z = 10, name = "hall" },
  { x = 20103, y = 20089, z = 10, name = "hall" },
  { x = 20099, y = 20093, z = 10, name = "hall" },
  { x = 20103, y = 20093, z = 10, name = "hall" },
  { x = 20101, y = 20095, z = 10, name = "hall" },
  { x = 20105, y = 20091, z = 10, name = "hall" },
  { x = 20095, y = 20097, z = 10, name = "hall" },
  { x = 20099, y = 20097, z = 10, name = "hall" },
  { x = 20103, y = 20097, z = 10, name = "hall" },
  { x = 20099, y = 20101, z = 10, name = "hall" },
  { x = 20103, y = 20101, z = 10, name = "hall" },
  { x = 20101, y = 20103, z = 10, name = "hall" },

}

-- Location coordinates (grouped by type)
ZSpaceship.MapData.Default.Locations = {
  ["Generator"] = {
      { x = 20101, y = 20089, z = 10 },
  
  }

}



-- Tiles with flags, grouped by flag
ZSpaceship.MapData.Tiles = {
  ["Airtight"] = {
      ["constructedobjects_01_48"] = true,
      ["constructedobjects_01_49"] = true,
      ["constructedobjects_01_50"] = true,
      ["floors_exterior_street_01_0"] = true,
      ["floors_exterior_tilesandstone_01_13"] = true,
      ["floors_interior_tilesandwood_01_28"] = true,
      ["industry_railroad_05_24"] = true,
      ["industry_railroad_05_25"] = true,
      ["industry_railroad_05_26"] = true,
      ["location_community_medical_01_168"] = true,
      ["location_community_medical_01_169"] = true,
      ["location_community_medical_01_170"] = true,
      ["walls_garage_01_32"] = true,
      ["walls_garage_01_33"] = true,
      ["walls_garage_01_35"] = true,
      ["walls_garage_02_16"] = true,
      ["walls_garage_02_17"] = true,
      ["walls_garage_02_19"] = true,
      ["walls_garage_02_49"] = true,
      ["walls_garage_02_52"] = true,
      ["walls_garage_02_57"] = true,
      ["walls_garage_02_60"] = true,
    },
  ["BiomassStorage"] = {
      ["quarantine_Simon_MD_63"] = true,
    },
  ["CloningPod"] = {
      ["zspaceship_9"] = true,
    },
  ["DoorN"] = {
      ["walls_garage_02_52"] = true,
      ["walls_garage_02_60"] = true,
    },
  ["DoorW"] = {
      ["walls_garage_02_49"] = true,
      ["walls_garage_02_57"] = true,
    },
  ["EnergyStorage"] = {
      ["zspaceship_3"] = true,
    },
  ["Floor"] = {
      ["floors_exterior_street_01_0"] = true,
      ["floors_exterior_street_01_18"] = true,
      ["floors_exterior_tilesandstone_01_13"] = true,
      ["floors_interior_tilesandwood_01_28"] = true,
      ["industry_01_Simon_MD_118"] = true,
    },
  ["OpenDoor"] = {
      ["walls_garage_02_57"] = true,
      ["walls_garage_02_60"] = true,
    },
  ["Recycler"] = {
      ["zspaceship_8"] = true,
    },
  ["SolarPanel"] = {
      ["zspaceship_5"] = true,
    },
  ["Storage"] = {
      ["zspaceship_0"] = true,
    },
  ["WallN"] = {
      ["constructedobjects_01_49"] = true,
      ["constructedobjects_01_50"] = true,
      ["industry_railroad_05_25"] = true,
      ["industry_railroad_05_26"] = true,
      ["location_community_medical_01_169"] = true,
      ["location_community_medical_01_170"] = true,
      ["walls_garage_01_33"] = true,
      ["walls_garage_02_17"] = true,
    },
  ["WallSE"] = {
      ["walls_garage_01_35"] = true,
      ["walls_garage_02_19"] = true,
    },
  ["WallW"] = {
      ["constructedobjects_01_48"] = true,
      ["constructedobjects_01_50"] = true,
      ["industry_railroad_05_24"] = true,
      ["industry_railroad_05_26"] = true,
      ["location_community_medical_01_168"] = true,
      ["location_community_medical_01_170"] = true,
      ["walls_garage_01_32"] = true,
      ["walls_garage_02_16"] = true,
    },
  ["WaterStorage"] = {
      ["quarantine_Simon_MD_54"] = true,
    },
}

-- Generate door sprites from MapData.Tiles (tiles with DoorN or DoorW flags)
ZSpaceship.MapData.DoorSprites = {}
for tile_name in pairs(ZSpaceship.MapData.Tiles.DoorN) do
    ZSpaceship.MapData.DoorSprites[tile_name] = true
end
for tile_name in pairs(ZSpaceship.MapData.Tiles.DoorW) do
    ZSpaceship.MapData.DoorSprites[tile_name] = true
end

local function buildAirtightLookupTable(direction_flag_list)
    local lookup = {}
    for tile_name in pairs(direction_flag_list) do
        if ZSpaceship.MapData.Tiles.Airtight[tile_name] then
            lookup[tile_name] = true
        end
    end
    return lookup
end

-- North/South walls (getWall(true)) - from WallN flag, only if also Airtight
ZSpaceship.MapData.AIRTIGHT_WALLS_NS_LOOKUP = buildAirtightLookupTable(ZSpaceship.MapData.Tiles["WallN"])

-- East/West walls (getWall(false)) - from WallW flag, only if also Airtight
ZSpaceship.MapData.AIRTIGHT_WALLS_EW_LOOKUP = buildAirtightLookupTable(ZSpaceship.MapData.Tiles["WallW"])

-- Door tiles (North/South direction) - from DoorN flag, only if also Airtight
ZSpaceship.MapData.AIRTIGHT_DOORS_NS_LOOKUP = buildAirtightLookupTable(ZSpaceship.MapData.Tiles["DoorN"])

-- Door tiles (East/West direction) - from DoorW flag, only if also Airtight
ZSpaceship.MapData.AIRTIGHT_DOORS_EW_LOOKUP = buildAirtightLookupTable(ZSpaceship.MapData.Tiles["DoorW"])
