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

    local cont = obj.getContainer and obj:getContainer()
    if cont then return getSquareFromObj(cont) end

    -- IsoObject should already be covered by previous checks AND IsoObject:getX() may throw NPE if object.square is nil
    if not instanceof(obj, 'IsoObject') and obj.getX and obj.getY and obj.getZ then
        local x, y, z = obj:getX(), obj:getY(), obj:getZ()
        if type(x) == "number" and type(y) == "number" and type(z) == "number" then
            return getSquare(x, y, z)
        end
    end
    return nil
end

ZS_Utils.getSquare = getSquareFromObj

-- global function to check if object is in space
function zsInSpace(obj)
    if not obj then return false end
    local sq = getSquareFromObj(obj)
    if sq then
        return zsInSpaceXY(sq:getX(), sq:getY())
    end
    -- XXX are there objects with getX/getY, but not getZ ?
    return nil
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
function ZS_Utils.isRecycler(obj)
    if not obj.getSprite then
      obj = obj.getParent and obj:getParent()
      if not obj then return false end
    end

    local sprite = obj.getSprite and obj:getSprite()
    if not sprite then return false end

    local name = sprite.getName and sprite:getName()
    if not name then return false end

    return ZSpaceship.MapData.Tiles.Recycler[name]
end

-- obj can be a tile or the parent object of a container
function ZS_Utils.isBiomassStorage(obj)
    if not obj then return false end
    if not obj.getSprite then
        obj = obj.getParent and obj:getParent()
        if not obj then return false end
    end
    local sprite = obj.getSprite and obj:getSprite()
    if not sprite then return false end
    local name = sprite.getName and sprite:getName()
    if not name then return false end
    return ZSpaceship.MapData and ZSpaceship.MapData.Tiles and ZSpaceship.MapData.Tiles.BiomassStorage and ZSpaceship.MapData.Tiles.BiomassStorage[name]
end

-- Returns the first adjacent ItemContainer that is a biomass storage, or nil.
-- Uses IsoDirections for getAdjacentSquare (Java expects enum, not number).
function ZS_Utils.findAdjacentBiomassContainer(recyclerSquare)
    if not recyclerSquare then return nil end
    local adjSquares = {}
    for _, dir in ipairs({ IsoDirections.N, IsoDirections.E, IsoDirections.S, IsoDirections.W }) do
        local adj = recyclerSquare:getAdjacentSquare(dir)
        if adj then adjSquares[#adjSquares + 1] = adj end
    end
    for _, adj in ipairs(adjSquares) do
        for i = 0, adj:getObjects():size() - 1 do
            local obj = adj:getObjects():get(i)
            if obj and ZS_Utils.isBiomassStorage(obj) then
                local cont = obj.getFluidContainer and obj:getFluidContainer()
                if cont then return cont end
            end
        end
    end
    return nil
end

function ZS_Utils.squareToTable(sq)
    if not sq then return nil end
    return { x = sq:getX(), y = sq:getY(), z = sq:getZ() }
end

function ZS_Utils.tableToSquare(table)
    if not table then return nil end
    return getSquare(table.x, table.y, table.z)
end
