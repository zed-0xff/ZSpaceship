local logger = zdk.Logger.new("ZSpaceship")

ZS_Utils = ZS_Utils or {}
ZSpaceship = ZSpaceship or {}

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

function zsIsArray(obj)
    if type(obj) ~= "table" then return false end
    local count = 0
    for k, _ in pairs(obj) do
        if type(k) ~= "number" then return false end
        count = count + 1
    end
    return count == #obj
end

function zsSquareToString(sq)
    if not sq then return nil end
    local x, y, z = sq:getX(), sq:getY(), sq:getZ()
    if x and y and z then
        return x .. ":" .. y .. ":" .. z
    end
    return nil
end

function zsSquareFromString(str)
    if type(str) ~= "string" then return nil end
    local a = str:split(":")
    if #a == 3 then
        local x = tonumber(a[1])
        local y = tonumber(a[2])
        local z = tonumber(a[3])
        if x and y and z then
            return getSquare(x, y, z)
        end
    end
    return nil
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
    if instanceof(obj, 'IsoCell') then
        return zsInSpaceXY(obj:getMinX(), obj:getMinY()) and zsInSpaceXY(obj:getMaxX(), obj:getMaxY())
    end

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

    if not room:checkSquares() then
        ZSRooms.updateAllSlow()
    end

    return room:isBreached()
end

ZSpaceship.isInVacuum = zsInVacuum

function ZS_Utils.IsInitialSetupDone(key)
    local zsModData = ModData.getOrCreate("ZSpaceship")
    zsModData.InitialSetupDone = zsModData.InitialSetupDone or {}
    return zsModData.InitialSetupDone[key]
end

function ZS_Utils.SetInitialSetupDone(key)
    local zsModData = ModData.getOrCreate("ZSpaceship")
    zsModData.InitialSetupDone = zsModData.InitialSetupDone or {}
    zsModData.InitialSetupDone[key] = true
end

local _wrappers = {}

-- Runs task on EveryOneMinute until task() returns true, then unregisters.
-- Use for one-shot setup that must wait for cell/conditions.
function ZS_Utils.initOnce(key, func)
    if ZS_Utils.IsInitialSetupDone(key) then
        logger:debug("initOnce: %s already done", key)
        return
    end

    logger:debug("initOnce: registering %s", key)

    local wrapper = function()
        if ZS_Utils.IsInitialSetupDone(key) then
            logger:debug("initOnce: %s wrapper: already done (%s)", key, _wrappers[key])
        elseif func(key) then
            Events.EveryOneMinute.Remove(_wrappers[key])
            ZS_Utils.SetInitialSetupDone(key)
            logger:debug("initOnce: %s done", key)
        end
    end
    _wrappers[key] = wrapper
    Events.EveryOneMinute.Add(wrapper)
end

function ZS_Utils.initSpritesAlways(key, sprites, func)
    for sprite in pairs(sprites) do
        MapObjects.OnNewWithSprite(sprite, func, 10)
        MapObjects.OnLoadWithSprite(sprite, func, 10)
    end
end

-- sprite names are KEYS of sprites tbl
function ZS_Utils.initSpritesOnce(key, sprites, func)
    if ZS_Utils.IsInitialSetupDone(key) then
        logger:debug("initSpritesOnce: %s already done", key)
        return
    end

    logger:debug("initSpritesOnce: registering %s for %s", key, sprites)

    local wrapper = function(obj)
        -- not checking IsInitialSetupDone here because it's expected to fire once per tile (square)
        if func(obj, key) then
            if not ZS_Utils.IsInitialSetupDone(key) then
                ZS_Utils.SetInitialSetupDone(key)
                logger:debug("initSpritesOnce: %s done", key)
            end
        end
    end

    ZS_Utils.initSpritesAlways(key, sprites, wrapper)
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
