-- ZSpaceship Main - Core constants and utilities

ZSpaceship = ZSpaceship or {}
ZSpaceship.MapData = ZSpaceship.MapData or {}

-- Space cell coordinates (use MapData if available, otherwise defaults)
ZSpaceship.SpaceCellX = ZSpaceship.MapData.CellX or 78
ZSpaceship.SpaceCellY = ZSpaceship.MapData.CellY or 78

-- Cell boundaries (cell is 256x256)
ZSpaceship.SpaceMinX = ZSpaceship.SpaceCellX * 256
ZSpaceship.SpaceMaxX = (ZSpaceship.SpaceCellX + 1) * 256
ZSpaceship.SpaceMinY = ZSpaceship.SpaceCellY * 256
ZSpaceship.SpaceMaxY = (ZSpaceship.SpaceCellY + 1) * 256

-- Teleporter position (from compiled map data)
ZSpaceship.TeleporterX = ZSpaceship.MapData.TeleporterX
ZSpaceship.TeleporterY = ZSpaceship.MapData.TeleporterY
ZSpaceship.TeleporterZ = ZSpaceship.MapData.TeleporterZ

-- Check if coordinates are in space (full cell)
function ZSpaceship.isInSpace(x, y)
    return x >= ZSpaceship.SpaceMinX and x < ZSpaceship.SpaceMaxX and
           y >= ZSpaceship.SpaceMinY and y < ZSpaceship.SpaceMaxY
end
