-- ZSpaceship Vacuum Sound - Handles sound muting in vacuum
-- Extracted from ZSpaceship_VacuumDamage.lua

ZSpaceship = ZSpaceship or {}
ZSpaceship.VacuumSound = ZSpaceship.VacuumSound or {}

-- Track if we're currently in vacuum
ZSpaceship.VacuumSound.wasInVacuum = false

-- Update vacuum sound muting state (call after teleporting or state change)
function ZSpaceship.VacuumSound.updateVacuumSounds(inVacuum)
    local soundManager = getSoundManager()
    if not soundManager then return end
    
    if inVacuum and not ZSpaceship.VacuumSound.wasInVacuum then
        -- Entering vacuum: mute only main sound volume (keep music, ambient, vehicle)
        soundManager:setSoundVolume(0)
        ZSpaceship.VacuumSound.wasInVacuum = true
    elseif not inVacuum and ZSpaceship.VacuumSound.wasInVacuum then
        -- Leaving vacuum: restore main sound volume from game options
        local core = getCore()
        if core then
            -- Get sound volume from game options (0-10 range, convert to 0.0-1.0)
            local soundVol = core:getOptionSoundVolume() / 10.0
            soundManager:setSoundVolume(soundVol)
        end
        ZSpaceship.VacuumSound.wasInVacuum = false
    end
end

-- Restore sound volumes when exiting game (get from options, don't remember)
local function restoreOnExit()
    if ZSpaceship.VacuumSound.wasInVacuum then
        local soundManager = getSoundManager()
        local core = getCore()
        
        if soundManager and core then
            -- Restore main sound volume from game options
            local soundVol = core:getOptionSoundVolume() / 10.0
            soundManager:setSoundVolume(soundVol)
        end
        
        ZSpaceship.VacuumSound.wasInVacuum = false
    end
end

Events.OnMainMenuEnter.Add(restoreOnExit)
Events.OnDisconnect.Add(restoreOnExit)
