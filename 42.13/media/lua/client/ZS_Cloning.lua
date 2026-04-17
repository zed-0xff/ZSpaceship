--[[
ZSpaceship = ZSpaceship or {}
ZSpaceship.Cloning = ZSpaceship.Cloning or {}

-- Perk level requirements by operation
ZSpaceship.Cloning.OP_Clone = {
    SCI_LEVEL = 2,
    MED_LEVEL = 2
}

ZSpaceship.Cloning.OP_Recycle = {
    SCI_LEVEL = 0,
    MED_LEVEL = 0
}

ZSpaceship.Cloning.OP_Sync = {
    SCI_LEVEL = 3,
    MED_LEVEL = 0
}

-- Get clone data for a player
function ZSpaceship.Cloning.getCloneData(player)
    if not player then return nil end
    local username = player:getUsername()
    if not username or username == "" then return nil end
    
    if not ModData or not ModData.getOrCreate then return nil end
    local modData = ModData.getOrCreate("ZS_Cloning")
    if not modData then return nil end
    
    return modData[username]
end

-- Check if player has a clone
function ZSpaceship.Cloning.hasClone(player)
    local cloneData = ZSpaceship.Cloning.getCloneData(player)
    return cloneData ~= nil
end

-- Clone yourself
function ZSpaceship.Cloning.cloneSelf(player)
    local scienceLevel = player:getPerkLevel(Perks.Science)
    local medicalLevel = player:getPerkLevel(Perks.Doctor)
    
    if scienceLevel < ZSpaceship.Cloning.OP_Clone.SCI_LEVEL then
        player:Say(getText("UI_ZS_ScienceRequired", ZSpaceship.Cloning.OP_Clone.SCI_LEVEL))
        return
    end
    
    if medicalLevel < ZSpaceship.Cloning.OP_Clone.MED_LEVEL then
        player:Say(getText("UI_ZS_MedicalRequired", ZSpaceship.Cloning.OP_Clone.MED_LEVEL))
        return
    end
    
    -- TODO: Implement actual cloning logic
    player:Say("Cloning initiated...")
end

-- Recycle/Dispose clone
function ZSpaceship.Cloning.recycleClone(player)
    if not ZSpaceship.Cloning.hasClone(player) then
        player:Say(getText("UI_ZS_NoClone"))
        return
    end
    
    -- TODO: Implement clone disposal logic
    player:Say("Clone disposed.")
end

-- Synchronize/Update clone
function ZSpaceship.Cloning.synchronizeClone(player)
    local scienceLevel = player:getPerkLevel(Perks.Science)
    
    if scienceLevel < ZSpaceship.Cloning.OP_Sync.SCI_LEVEL then
        player:Say(getText("UI_ZS_ScienceRequired", ZSpaceship.Cloning.OP_Sync.SCI_LEVEL))
        return
    end
    
    if not ZSpaceship.Cloning.hasClone(player) then
        player:Say(getText("UI_ZS_NoClone"))
        return
    end
    
    -- TODO: Implement clone synchronization logic
    player:Say("Clone synchronized.")
end

-- Helper function to add context menu option with perk check
local function addCloningOption(context, player, textKey, cb, requiredScienceLevel, requiredMedicalLevel)
    requiredScienceLevel = requiredScienceLevel or 0
    requiredMedicalLevel = requiredMedicalLevel or 0
    
    local scienceLevel = player:getPerkLevel(Perks.Science)
    local medicalLevel = player:getPerkLevel(Perks.Doctor)
    local text = getText(textKey)
    local opt = context:addOption(text, player, cb)
    
    local notAvailable = false
    local tooltip = nil
    
    if requiredScienceLevel > 0 and scienceLevel < requiredScienceLevel then
        notAvailable = true
        tooltip = ISToolTip:new()
        tooltip:setName(getText("UI_ZS_ScienceRequired", requiredScienceLevel))
    elseif requiredMedicalLevel > 0 and medicalLevel < requiredMedicalLevel then
        notAvailable = true
        tooltip = ISToolTip:new()
        tooltip:setName(getText("UI_ZS_MedicalRequired", requiredMedicalLevel))
    end
    
    opt.notAvailable = notAvailable
    opt.toolTip = tooltip
end

-- Context Menu for Cloning Console (World Object)
local function doWorldContextMenu(playerNum, context, worldobjects, test)
    if test then return end
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    
    -- Check if standing in medical room
    local room = ZSRooms.find(player)
    if not room or room:getName() ~= "medical" then return end
    
    local hasClone = ZSpaceship.Cloning.hasClone(player)
    
    -- Clone yourself - needs Science 2 and Medical 2
    if not hasClone then
        addCloningOption(context, player, "UI_ZS_CloneSelf", 
            ZSpaceship.Cloning.cloneSelf, 
            ZSpaceship.Cloning.OP_Clone.SCI_LEVEL, 
            ZSpaceship.Cloning.OP_Clone.MED_LEVEL)
    end
    
    -- Recycle/Dispose clone - no requirements
    if hasClone then
        context:addOption(getText("UI_ZS_RecycleClone"), player, ZSpaceship.Cloning.recycleClone)
    end
    
    -- Synchronize/Update clone - needs Science 3
    if hasClone then
        addCloningOption(context, player, "UI_ZS_SynchronizeClone", 
            ZSpaceship.Cloning.synchronizeClone, 
            ZSpaceship.Cloning.OP_Sync.SCI_LEVEL, 
            ZSpaceship.Cloning.OP_Sync.MED_LEVEL)
    end
end

Events.OnFillWorldObjectContextMenu.Add(doWorldContextMenu)
]]--
