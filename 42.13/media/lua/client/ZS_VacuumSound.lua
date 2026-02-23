-- ZSpaceship Vacuum Sound - Handles sound muting in vacuum

ZSpaceship = ZSpaceship or {}
ZSpaceship.VacuumSound = ZSpaceship.VacuumSound or {}

local function toggleMute(bMute)
    local soundManager = getSoundManager()
    local core = getCore()

    if soundManager and core then
        local mult = bMute and 0 or 0.1
        soundManager:setAmbientVolume(core:getOptionAmbientVolume() * mult)
        soundManager:setSoundVolume(core:getOptionSoundVolume() * mult)
    end
end

-- Update vacuum sound muting state (call after teleporting or state change)
function ZSpaceship.VacuumSound.updateVacuumSounds(inVacuum)
    toggleMute(inVacuum)
end

-- Restore sound volumes when exiting game
local function restoreOnExit()
    toggleMute(false)
end

Events.OnMainMenuEnter.Add(restoreOnExit)
Events.OnDisconnect.Add(restoreOnExit)
