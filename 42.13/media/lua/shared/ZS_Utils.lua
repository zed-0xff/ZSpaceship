-- ZSpaceship Utilities - Shared functions for client and server

ZS_Utils = ZS_Utils or {}

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

function zsClamp(_value, _min, _max)
    if _min > _max then _min, _max = _max, _min; end;
    return math.min(math.max(_value, _min), _max);
end

-- global function to check if coordinates are in space
function zsInSpaceXY(x, y)
    if not x or not y then return false end

    return x >= ZSpaceship.SpaceMinX and x < ZSpaceship.SpaceMaxX and
           y >= ZSpaceship.SpaceMinY and y < ZSpaceship.SpaceMaxY
end

-- Resolve IsoGridSquare from player, square, room, or object with getX/getY/getZ (same order as zsInSpace).
local function getSquareFromObj(obj)
    if not obj then return nil end
    local sq = (obj.getCurrentSquare and obj:getCurrentSquare()) or
              (obj.getSquare and obj:getSquare()) or
              (obj.getRandomSquare and obj:getRandomSquare())
    if sq then return sq end
    if obj.getX and obj.getY and obj.getZ then
        local x, y, z = obj:getX(), obj:getY(), obj:getZ()
        if type(x) == "number" and type(y) == "number" and type(z) == "number" then
            return getSquare(x, y, z)
        end
    end
    return nil
end

-- global function to check if object is in space
function zsInSpace(obj)
    if not obj then return false end
    local sq = getSquareFromObj(obj)
    if sq then
        return zsInSpaceXY(sq:getX(), sq:getY())
    end
    -- getX/getY after getSquare so IsoObject with square nil doesn't throw
    return obj.getX and obj.getY and zsInSpaceXY(obj:getX(), obj:getY())
end

ZSpaceship.isInSpaceXY = zsInSpaceXY
ZSpaceship.isInSpace   = zsInSpace

-- Helper to check if location is in vacuum using cached ZSRoom state
function zsInVacuum(obj)
    if not obj then return false end
    if not zsInSpace(obj) then return false end

    local sq = getSquareFromObj(obj)
    -- Chunk not loaded or invalid coords: assume NOT vacuum for safety
    if not sq then return false end

    local room = ZSRooms and ZSRooms.find(sq)
    -- Fallback: square not in cache (e.g. room not in MapData); try IsoRoom from square
    if not room and sq.getRoom and ZSRooms and ZSRooms.getOrCreate then
        local isoRoom = sq:getRoom()
        if isoRoom then
            room = ZSRooms.getOrCreate(isoRoom)
            if room and ZSRooms.updateAllFast then
                ZSRooms.updateAllFast()
            end
        end
    end
    -- No room (or could not resolve): treat as vacuum
    if not room then return true end

    return room:isBreached()
end

ZSpaceship.isInVacuum = zsInVacuum

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

-- gets the space suit, not any suit
function ZSpaceship.getWornSuit(player)
    local wornItems = player:getWornItems()
    for i = 0, wornItems:size() - 1 do
        local item = wornItems:getItemByIndex(i)
        if item and item:getFullType() == ZSpaceship.SPACE_SUIT_ID then
            return item
        end
    end
    return nil
end

-- obj can be a tile or a container
function ZS_Utils.isShredder(obj)
    if not obj.getSprite then
      obj = obj.getParent and obj:getParent()
      if not obj then return false end
    end

    local sprite = obj.getSprite and obj:getSprite()
    if not sprite then return false end

    local name = sprite.getName and sprite:getName()
    if not name then return false end

    return ZSpaceship.MapData.Tiles.Shredder[name]
end
