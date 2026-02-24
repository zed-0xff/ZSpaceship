local function onPlayerUpdate(player)
    if player:isDead() then return end

    local suit = ZSpaceship.getWornSuit(player)
    if not suit then return end

    local isIntact = not suit.getHolesNumber or suit:getHolesNumber() == 0
    if not isIntact then return end

    if not suit:canBeActivated() then return end

    local inVacuum = zsInVacuum(player)

    -- 'or false' to ensure boolean, getBuilding() may return nil and setActivated(nil) would throw error
    local newAct = (
        inVacuum
        or (player:getBuilding() and player:getBuilding():isToxic())
        or (player:getBodyDamage():GetBaseCorpseSickness() > 0)
        or false
    )
    local curAct = suit:isActivated()

    if newAct ~= curAct then
        suit:setActivated(newAct)
        ZSpaceship.VacuumSound.updateVacuumSounds(inVacuum)
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
