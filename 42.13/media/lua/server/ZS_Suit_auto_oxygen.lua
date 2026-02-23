local function onPlayerUpdate(player)
    if player:isDead() then return end

    local suit = ZSpaceship.getWornSuit(player)
    if not suit then return end

    local isIntact = not suit.getHolesNumber or suit:getHolesNumber() == 0
    if not isIntact then return end

    if not suit:canBeActivated() then return end

    local inVacuum = zsInVacuum(player)
    local newAct = inVacuum or (player:getBuilding() and player:getBuilding():isToxic())
    local curAct = suit:isActivated()

    if newAct ~= curAct then
        suit:setActivated(newAct)
        ZSpaceship.VacuumSound.updateVacuumSounds(inVacuum)
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
