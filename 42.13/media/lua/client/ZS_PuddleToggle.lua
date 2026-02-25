-- ZSpaceship: client-side set DynamicPuddles to None when player is in Space.
-- Option stays in game options when not in Space; we only override while in Space.
-- Requires ZS_Utils (zsInSpace) and runs only on client.

if not isClient() then return end

local PERF_PUDDLES_NONE = 3

local function checkSpacePuddles()
    local player = getPlayer()
    if not player then return end

    if zsInSpace(player) then
        -- TODO: restore previous value when leaving Space
        getCore():setPerfPuddles(PERF_PUDDLES_NONE)
    end
end

Events.EveryOneMinute.Add(checkSpacePuddles)
