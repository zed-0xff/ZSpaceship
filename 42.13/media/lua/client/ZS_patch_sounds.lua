-- client-side only, so getPlayer() is available

local MUTE_SOUNDS = {
    "airdrop", -- mod: randomairdropsASVOD
}

local function isMutedSound(name)
    if type(name) ~= "string" then return false end

    name = name:lower()
    for _, substr in ipairs(MUTE_SOUNDS) do
        if name:contains(substr) then
            return true
        end
    end
    return false
end

local function maybePlaySound(orig, self, name, ...)
    local player = getPlayer()
    if player and zsInSpace(player) and isMutedSound(name) then return nil end

    return orig(self, name, ...)
end

Events.OnCreatePlayer.Add(function(playerIdx, playerObj)
    zbHook({
        [playerObj] = {
            playSound = maybePlaySound
        },
        [getSoundManager()] = {
            PlaySound = maybePlaySound
        },
    })
end)
