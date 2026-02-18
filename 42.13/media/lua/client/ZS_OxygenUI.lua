-- Oxygen level UI for ZSpaceship mod
-- Displays oxygen level progress bar above character when in vacuum

ZSpaceship = ZSpaceship or {}
ZSpaceship.OxygenUI = ZSpaceship.OxygenUI or {}

-- Progress bar dimensions
local BAR_WIDTH = 64
local BAR_HEIGHT = 8
local BAR_OFFSET_Y = -80  -- Offset above character head

-- Get oxygen level from SCBA suit (returns nil if no SCBA suit)
local function getOxygenLevel(player)
    -- Check for SCBA suit with oxygen tank
    local wornItems = player:getWornItems()
    if wornItems then
        for i = 0, wornItems:size() - 1 do
            local item = wornItems:getItemByIndex(i)
            if item and instanceof(item, "Clothing") and item:hasTag(ItemTag.SCBA) then
                if item:isActivated() and item:hasTank() then
                    -- Use SCBA suit's oxygen level
                    return item:getUsedDelta()
                end
            end
        end
    end
    
    -- No SCBA suit - no oxygen tracking
    return nil
end

-- Draw progress bar above character
local function drawOxygenBar(player)
    if not player then return end
    
    local sq = player:getCurrentSquare()
    if not sq then return end
    
    -- Check if in vacuum
    local inVacuum = false
    if zsIsInSpace(sq) then
        local room = sq:getRoom()
        if ZSpaceship.isRoomBreached and room then
            local breached = ZSpaceship.isRoomBreached(room)
            inVacuum = (breached == true)  -- Ensure boolean conversion
        elseif not room then
            -- No room = open space = vacuum
            inVacuum = true
        end
    end
    
    -- Get oxygen level from SCBA suit (only if player has one)
    local oxygenLevel = getOxygenLevel(player)

    if oxygenLevel == nil then
        oxygenLevel = 0
    end
    
    -- Only draw if in vacuum and player has SCBA suit
    if not inVacuum then return end
    -- Check for nil explicitly (not "not oxygenLevel" because 0 is falsy)
    if oxygenLevel == nil or type(oxygenLevel) ~= "number" then return end
    if oxygenLevel < 0 or oxygenLevel > 1 then return end
    -- Note: oxygenLevel can be 0 (depleted), we'll draw a red empty bar in that case
    
    -- Convert world coordinates to screen coordinates
    if not IsoUtils or not getCameraOffX or not getCameraOffY then return end
    
    local x, y, z = player:getX(), player:getY(), player:getZ()
    local sx = IsoUtils.XToScreen(x, y, z, 0) - getCameraOffX()
    local sy = IsoUtils.YToScreen(x, y, z, 0) - getCameraOffY()
    
    -- Adjust for zoom
    local core = getCore()
    if not core then return end
    local zoom = core:getZoom(0)
    if not zoom or zoom == 0 then return end
    sx = sx / zoom
    sy = sy / zoom
    
    -- Ensure sx and sy are valid numbers
    if not sx or not sy or type(sx) ~= "number" or type(sy) ~= "number" then return end
    
    -- Position bar above character head (centered horizontally)
    -- Offset scales with zoom to maintain consistent visual distance
    local barX = sx - (BAR_WIDTH / 2)
    local barY = sy - (125 / zoom)  -- Offset scales with zoom
    
    -- Ensure barX and barY are valid numbers
    if not barX or not barY or type(barX) ~= "number" or type(barY) ~= "number" then return end
    
    -- Draw progress bar background (dark gray border)
    if SpriteRenderer and SpriteRenderer.instance then
        SpriteRenderer.instance:render(nil, barX - 1, barY - 1, BAR_WIDTH + 2, BAR_HEIGHT, 0.25, 0.25, 0.25, 1.0, nil)
        
        -- Draw progress bar fill
        local fillWidth = math.floor(BAR_WIDTH * oxygenLevel)
        -- Ensure fillWidth is valid (math.floor always returns a number, but check type anyway)
        if type(fillWidth) ~= "number" then return end
        
        -- Special case: if oxygen is completely depleted (0 or very close to 0), draw entire bar as red
        if oxygenLevel <= 0.001 or fillWidth <= 0 then
            -- Draw entire bar as red when depleted
            SpriteRenderer.instance:render(nil, barX, barY, BAR_WIDTH, BAR_HEIGHT - 2, 1.0, 0.2, 0.2, 1.0, nil)
        else
            -- Draw filled portion
            if fillWidth > 0 then
                -- Color: cyan/blue when high, orange when medium, red when low
                local r, g, b = 0.0, 0.8, 1.0  -- Cyan/blue (high)
                if oxygenLevel < 0.3 then
                    r, g, b = 1.0, 0.2, 0.2  -- Red (low)
                elseif oxygenLevel < 0.6 then
                    r, g, b = 1.0, 0.6, 0.0  -- Orange (medium)
                end
                SpriteRenderer.instance:render(nil, barX, barY, fillWidth, BAR_HEIGHT - 2, r, g, b, 1.0, nil)
            end
            
            -- Draw remaining/empty portion (gray)
            if fillWidth < BAR_WIDTH then
                local remainingWidth = BAR_WIDTH - fillWidth
                SpriteRenderer.instance:render(nil, barX + fillWidth, barY, remainingWidth, BAR_HEIGHT - 2, 0.5, 0.5, 0.5, 1.0, nil)
            end
        end
    end
end

-- Hook into OnPostUIDraw to render the oxygen bar
Events.OnPostUIDraw.Add(function()
    -- Don't draw during game exit or if core functions aren't available
    local core = getCore()
    if not core then return end
    
    local player = getPlayer()
    if not player then return end
    
    -- Safely call drawOxygenBar with error handling
    local success, err = pcall(drawOxygenBar, player)
    if not success then
        -- Silently fail during exit/transition states
    end
end)
