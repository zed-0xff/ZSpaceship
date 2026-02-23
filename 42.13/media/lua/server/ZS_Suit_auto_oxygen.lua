local function onPlayerUpdate(player)
    if player:isDead() then return end

    local suit = ZSpaceship.getWornSuit(player)
    if not suit then return end

    local isIntact = not suit.getHolesNumber or suit:getHolesNumber() == 0
    if not isIntact then return end

    if not suit:canBeActivated() then return end

    local curAct = suit:isActivated()
    local newAct = zsInVacuum(player) or (player:getBuilding() and player:getBuilding():isToxic())

    if newAct ~= curAct then
        suit:setActivated(newAct)
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
