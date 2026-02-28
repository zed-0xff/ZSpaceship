ZSpaceship = ZSpaceship or {}

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
