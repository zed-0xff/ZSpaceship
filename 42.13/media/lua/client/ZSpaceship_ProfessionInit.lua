local function onNewGame(player, square)
    local prof = player:getDescriptor():getCharacterProfession()
    if prof and tostring(prof) == "zspaceship:astronaut" then
        local inv = player:getInventory()
        
        -- Remove default clothes
        inv:clear()
        
        -- Add vanilla Hazmat Suit (required for protection in B42)
        local suit = inv:AddItem("Base.HazmatSuit")
        
        -- Wear it
        player:setWornItem(suit:getBodyLocation(), suit)
        
        -- Activate the suit (required for SCBA/Hazmat protection in B42)
        if suit.setTankType then
            suit:setTankType("Base.Oxygen_Tank")
        end
        suit:setUsedDelta(ZombRandFloat(0.5, 1.0))
        suit:setActivated(true)
        
        -- Add Communicator and Screwdriver to inventory
        inv:AddItem("ZSpaceship.Communicator")
        inv:AddItem("Base.Screwdriver")
        
        -- Add Wrench and put it in the primary hand
        local wrench = inv:AddItem("Base.Wrench")
        player:setPrimaryHandItem(wrench)
        
        -- Add Flashlight and put it in the secondary hand
        local torch = inv:AddItem("Base.Torch")
        player:setSecondaryHandItem(torch)
        
        -- Add Digital Watch and wear it
        local watch = inv:AddItem("Base.WristWatch_Left_DigitalBlack")
        if watch then
            player:setWornItem(watch:getBodyLocation(), watch)
        end
    end
end

Events.OnNewGame.Add(onNewGame)
