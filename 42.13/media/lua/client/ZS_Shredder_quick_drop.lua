--- CLIENT: drop dragged corpse into shredder when "Interact" key is held for 500ms

local KEYSTATE = {}

local function find_shredder_at(playerObj, square)
    if not square then return end

    local squareContainers = playerObj:getSuitableContainersToDropCorpseInSquare(square) -- works even if reachable diagonally
    if squareContainers:size() > 0 then
        for i=0, squareContainers:size()-1 do
            local container = squareContainers:get(i)
            if container and ZS_Utils.isShredder(container) then
                return container
            end
        end
    end
end

local function find_shredder(playerObj)
    local square = playerObj:getCurrentSquare()
    return find_shredder_at(playerObj, square) or
           find_shredder_at(playerObj, square:getAdjacentSquare(IsoDirections.W)) or
           find_shredder_at(playerObj, square:getAdjacentSquare(IsoDirections.N)) or
           find_shredder_at(playerObj, square:getAdjacentSquare(IsoDirections.E)) or
           find_shredder_at(playerObj, square:getAdjacentSquare(IsoDirections.S)) or
           find_shredder_at(playerObj, square:getAdjacentSquare(IsoDirections.NW)) or
           find_shredder_at(playerObj, square:getAdjacentSquare(IsoDirections.NE)) or
           find_shredder_at(playerObj, square:getAdjacentSquare(IsoDirections.SE)) or
           find_shredder_at(playerObj, square:getAdjacentSquare(IsoDirections.SW))
end

local function try_shred_corpse(playerObj)
    -- guaranteed input:
    --  * player is not nil
    --  * player is alive
    --  * player is dragging corpse
    --  * player is in space
    --  * player is not currently busy (not in action queue or current action is not "busy")
    --  * player is pressing "Interact" key for at least 500ms

    local shredder = find_shredder(playerObj)
    if not shredder then return end

    ISTimedActionQueue.add(ISDropCorpseIntoContainer:new(playerObj, shredder))
    return true
end

local function checkKey(key)
    if not getCore():isKey("Interact", key) then
        return false
    end

    local playerObj = getSpecificPlayer(0)
    if not playerObj or playerObj:isDead() then
        return false
    end

    if not zsInSpace(playerObj) then
        return false
    end

    local queue = ISTimedActionQueue.queues[playerObj]
    if queue and #queue.queue > 0 then
        if playerObj:isCurrentlyBusy() then
            return false
        end
    end

    return playerObj:isDraggingCorpse()
end

local function onKeyStartPressed(key)
    if not checkKey(key) then return end

    KEYSTATE.keyPressedMS = getTimestampMs()
end

local function onKeyKeepPressed(key)
    if not checkKey(key) then return end
    if not KEYSTATE.keyPressedMS then
        return
    end

    local delay = 500
    if (getTimestampMs() - KEYSTATE.keyPressedMS >= delay) then
        if try_shred_corpse(getSpecificPlayer(0)) then
            KEYSTATE.keyPressedMS = nil
        end
    end
end

local function onKeyReleased(key)
    if not checkKey(key) then return end

    KEYSTATE.keyPressedMS = nil
end

Events.OnKeyStartPressed.Add(onKeyStartPressed)
Events.OnKeyKeepPressed.Add(onKeyKeepPressed)
Events.OnKeyPressed.Add(onKeyReleased)
