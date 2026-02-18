-- ZSpaceship Utilities - Shared functions for client and server

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

-- global function to check if coordinates are in space
function zsIsInSpaceXY(x, y)
    if not x or not y then return false end

    return x >= ZSpaceship.SpaceMinX and x < ZSpaceship.SpaceMaxX and
           y >= ZSpaceship.SpaceMinY and y < ZSpaceship.SpaceMaxY
end

-- global function to check if object is in space
function zsIsInSpace(obj)
    if not obj then return false end

    if obj.getSquare then
        local sq = obj:getSquare()
        if sq then
            return sq and zsIsInSpaceXY(sq:getX(), sq:getY())
        end
    end

    -- IsoRoom
    if obj.getRandomSquare then
        local sq = obj:getRandomSquare()
        if sq then
            return zsIsInSpaceXY(sq:getX(), sq:getY())
        end
    end

    -- have to check getX/getY AFTER checking getSquare, because IsoObject has getX/getY,
    -- but may not have a square, so it throws an error if you call getX/getY on it without checking for getSquare first
    return obj.getX and obj.getY and zsIsInSpaceXY(obj:getX(), obj:getY())
end

ZSpaceship.isInSpaceXY = zsIsInSpaceXY
ZSpaceship.isInSpace   = zsIsInSpace

--- Returns true only on the very first new game for this world (not when a dead player respawns on the same save).
-- @param moduleName string Optional. If given, each module gets one run per save; if omitted, first caller sets a single flag.
function ZSpaceship.isInitialNewGame(moduleName)
    if not ModData or not ModData.getOrCreate then return true end
    local modData = ModData.getOrCreate("ZSpaceship")
    local key = moduleName and ("InitialGameSetup_" .. moduleName) or "InitialGameSetupDone"
    if modData[key] then return false end
    modData[key] = true
    return true
end
