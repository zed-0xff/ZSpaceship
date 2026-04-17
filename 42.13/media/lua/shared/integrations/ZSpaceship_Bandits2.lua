-- prevent bandits from spawning in the Space
if not getActivatedMods():contains("Bandits2") then return end

local function preventBanditsInSpace()
    if RVInterior and RVInterior.playerInsideInterior then
        -- patch existing function
        zdk.hook({
            RVInterior = {
                playerInsideInterior = function(orig, player, ...)
                    return orig(player, ...) or zsInSpace(player)
                end
            }
        })
    else
        -- define our own
        RVInterior = RVInterior or {}
        RVInterior.playerInsideInterior = zsInSpace
    end
end

Events.OnGameBoot.Add(preventBanditsInSpace)
