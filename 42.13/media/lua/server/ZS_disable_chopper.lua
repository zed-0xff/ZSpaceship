-- Disable the helicopter event when its target is in the space cell (no chopper in space).
-- Runs every 10 in-game minutes on the server.

local function checkChopperInSpace()
    if not IsoWorld or not IsoWorld.instance or not IsoWorld.instance.helicopter then
        return
    end
    local heli = IsoWorld.instance.helicopter
    if not heli.isActive or not heli:isActive() then
        return
    end
    local target = heli.target
    if not target then
        return
    end
    if zsInSpace and zsInSpace(target) then
        heli:deactivate()
    end
end

Events.EveryTenMinutes.Add(checkChopperInSpace)
