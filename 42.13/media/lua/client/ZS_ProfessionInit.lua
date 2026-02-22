local function onNewGame(player, square)
    local prof = player:getDescriptor():getCharacterProfession()
    if prof and prof == ZSpaceship.Professions.Astronaut then
        local inv = player:getInventory()
        
        -- Remove default clothes
        inv:clear()
        
        -- Add space suit
        local suit = inv:AddItem("ZSpaceship.SpaceSuitA")
        
        -- Wear it
        player:setWornItem(suit:getBodyLocation(), suit)
        
        -- fill the oxygen tank
        if suit.setTankType then
            suit:setTankType("Base.Oxygen_Tank")
        end
        suit:setUsedDelta(1.0) -- full tank
        suit:setActivated(true)

        local fluidContainer = suit:getComponent(ComponentType.FluidContainer)
        if fluidContainer and fluidContainer.addFluid then
            fluidContainer:addFluid(FluidType.Water, 1.0)
        end
        
        -- Add Screwdriver to inventory
        inv:AddItem("Base.Screwdriver")
        
        -- Add Wrench and put it in the primary hand
        local wrench = inv:AddItem("Base.Wrench")
        player:setPrimaryHandItem(wrench)
        
        -- Add Flashlight and put it in the secondary hand
        local torch = inv:AddItem("Base.Torch")
        player:setSecondaryHandItem(torch)
        
        -- Add Communicator and wear it
        local comm = inv:AddItem("ZSpaceship.Communicator_Left")
        if comm then
            player:setWornItem(comm:getBodyLocation(), comm)
        end
    end
end

Events.OnNewGame.Add(onNewGame)
