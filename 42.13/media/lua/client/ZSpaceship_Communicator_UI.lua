-- Simple UI element for drawing progress bars
local ProgressBarUI = ISUIElement:derive("ProgressBarUI")

function ProgressBarUI:render()
    ISUIElement.render(self)
    
    -- Only render if player has communicator
    local player = getPlayer()
    if not player or not player:getInventory():getItemFromTag(ZSpaceship.Tags.Communicator, true, true) then return end
    
    local clock = UIManager.getClock()
    if not clock or not clock:isVisible() then return end

    -- Progress bar dimensions
    local barWidth = self:getWidth()
    local barHeight = self:getHeight()
    
    local progress = 0
    local currentPower = 0
    if ZSpaceship and ZSpaceship.Power then
        local maxAmount = ZSpaceship.Power.getMaxAmount()
        currentPower = ZSpaceship.Power.getCurrentAmount()
        if maxAmount and maxAmount > 0 then
            progress = currentPower / maxAmount
        end
    end
    
    -- Check if power is insufficient for teleporting to/from surface
    local insufficientPower = false
    if player and ZSpaceship and ZSpaceship.Teleport and ZSpaceship.isInSpace then
        local inSpace = ZSpaceship.isInSpace(player:getX(), player:getY())
        -- Calculate cost for teleporting to/from surface
        local cost = ZSpaceship.Teleport.getCost(player, false, inSpace)
        if currentPower < cost then
            insufficientPower = true
        end
    end
    
    -- Foreground color: orange/yellow if insufficient power, otherwise cyan/blue-green
    local fgColor
    if insufficientPower then
        -- Orange/yellow color (not red) when power is insufficient
        fgColor = {r = 255/255, g = 165/255, b = 0/255, a = 1.0}  -- Orange
    else
        -- Normal cyan/blue-green similar to clock
        fgColor = {r = 100/255, g = 200/255, b = 210/255, a = 1.0}
    end
    
    -- Draw the progress bar at position 0,0 relative to this UI element
    self:drawProgressBar(0, 0, barWidth, barHeight, progress, fgColor)
end

local progressBarUI = nil

local function removePowerIndicator()
    if progressBarUI then
        progressBarUI:removeFromUIManager()
        progressBarUI = nil
    end
end

local function updatePowerIndicator(player)
    if not player:getInventory():getItemFromTag(ZSpaceship.Tags.Communicator, true, true) then 
        -- Remove UI if player doesn't have communicator
        removePowerIndicator()
        return
    end
    
    local clock = UIManager.getClock()
    if not clock or not clock:isVisible() then
        -- Hide UI if clock is not visible
        if progressBarUI then
            progressBarUI:setVisible(false)
        end
        return
    end
    
    -- Calculate position below the clock
    local clockX = clock:getX()
    local clockY = clock:getY()
    local clockHeight = clock:getHeight()
    local barWidth = clock:getWidth() - 2
    local barHeight = 10
    local barX = clockX + 1
    local barY = clockY + clockHeight + 1

    local speedCtl = UIManager.getSpeedControls()
    if speedCtl then
        barHeight = speedCtl:getY() - barY
    end
    
    -- Create or update UI element
    if not progressBarUI then
        progressBarUI = ProgressBarUI:new(barX, barY, barWidth, barHeight)
        progressBarUI:initialise()
        progressBarUI:addToUIManager()
    else
        -- Update position to follow clock
        progressBarUI:setX(barX)
        progressBarUI:setY(barY)
        progressBarUI:setVisible(true)
    end
end

Events.OnPlayerUpdate.Add(updatePowerIndicator)

-- because clock size might be changed in settings, so we need to recreate
Events.OnMainMenuEnter.Add(removePowerIndicator)