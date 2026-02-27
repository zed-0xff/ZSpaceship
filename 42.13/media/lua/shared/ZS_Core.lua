ZSpaceship = ZSpaceship or {}

ZSpaceship.ZOMBIE_OUTFIT_ID = "ZSpaceship_SpaceSuit"  -- defined in clothing.xml
ZSpaceship.SPACE_SUIT_ID    = "ZSpaceship.SpaceSuitA" -- prefer using tags instead

-- Teleport: Science perk level requirements (shared by client and server)
ZSpaceship.Teleport = ZSpaceship.Teleport or {}
ZSpaceship.Teleport.SCIENCE_LEVEL_MIN      = 1  -- Minimum Science level for basic teleports
ZSpaceship.Teleport.SCIENCE_LEVEL_BUILDING = 2  -- Science level required for building teleports
ZSpaceship.Teleport.SCIENCE_LEVEL_ITEM     = 4  -- Science level required for teleporting items
