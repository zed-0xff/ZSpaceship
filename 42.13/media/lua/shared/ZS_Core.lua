require 'ZS_MapData'

ZSpaceship = ZSpaceship or {}
ZSpaceship.logger = zdk.Logger.new("ZSpaceship", zdk.Logger.DEBUG)

ZSpaceship.ZOMBIE_OUTFIT_ID = "ZSpaceship_SpaceSuit"  -- defined in clothing.xml
ZSpaceship.SPACE_SUIT_ID    = "ZSpaceship.SpaceSuitA" -- prefer using tags instead

ZSpaceship.Teleport = ZSpaceship.Teleport or {}

ZSpaceship.Teleport.SCIENCE_LEVEL_MIN      = 1  -- Minimum Science level for basic teleports
ZSpaceship.Teleport.SCIENCE_LEVEL_BUILDING = 2  -- Science level required for building teleports
ZSpaceship.Teleport.SCIENCE_LEVEL_ITEM     = 4  -- Science level required for teleporting items

ZSpaceship.Teleport.MIN_MASS               = 5.0
ZSpaceship.Teleport.COST_PER_KG            = 10  -- MJ/kg
ZSpaceship.Teleport.BUILDING_MULT          = 1.5
ZSpaceship.Teleport.SPACE2SPACE_MULT       = 0.2  -- cheaper cost when teleporting from space

-- Space cell coordinates (from compiled map data)
ZSpaceship.SpaceCellX = ZSpaceship.MapData.CellX or 78
ZSpaceship.SpaceCellY = ZSpaceship.MapData.CellY or 78

-- Cell boundaries (cell is 256x256)
ZSpaceship.SpaceMinX = ZSpaceship.SpaceCellX * 256
ZSpaceship.SpaceMaxX = (ZSpaceship.SpaceCellX + 1) * 256
ZSpaceship.SpaceMinY = ZSpaceship.SpaceCellY * 256
ZSpaceship.SpaceMaxY = (ZSpaceship.SpaceCellY + 1) * 256

