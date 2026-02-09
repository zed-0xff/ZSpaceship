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

function zsHook(obj, hooks)
    if not obj or not hooks then return end

    for methodName, wrapper in pairs(hooks) do
        local orig = obj[methodName]
        if type(orig) == "function" then
            if  type(wrapper) == "function" then
                obj[methodName] = function(...)
                    return wrapper(orig, ...)
                end
            else
                print("[!] zsHook: " .. tostring(methodName) .. " has no wrapper, but " .. tostring(type(wrapper)))
            end
        else
            print("[?] zsHook: " .. tostring(methodName) .. " is not a function, but " .. tostring(type(orig)))
        end
    end
end

function ZSpaceship.isInSpaceXY(x, y)
    if not x or not y then return false end

    return x >= ZSpaceship.SpaceMinX and x < ZSpaceship.SpaceMaxX and
        y >= ZSpaceship.SpaceMinY and y < ZSpaceship.SpaceMaxY
end

-- Check if coordinates are in space (full cell)
function ZSpaceship.isInSpace(a, b)
    if a and b then
        return ZSpaceship.isInSpaceXY(a, b)
    elseif a then
        if a.getX and a.getY then
            return ZSpaceship.isInSpaceXY(a:getX(), a:getY())
        elseif a.getSquare then
            local sq = a:getSquare()
            if sq then
                return ZSpaceship.isInSpaceXY(sq:getX(), sq:getY())
            end
        elseif a.getRandomSquare then -- IsoRoom
            local sq = a:getRandomSquare()
            if sq then
                return ZSpaceship.isInSpaceXY(sq:getX(), sq:getY())
            end
        end
    end
    return false
end
