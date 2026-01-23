ZSpaceship = ZSpaceship or {}
ZSpaceship.Power = {}

local _currentAmount = 1000
local _maxAmount = 3000
local _consumptionPerTick = 0.1
local _maxProductionPerTick = 0.2 -- TODO: count number of solar panels

function ZSpaceship.Power.getCurrentAmount()
    return math.floor(_currentAmount)
end

function ZSpaceship.Power.getMaxAmount()
    return _maxAmount
end

function ZSpaceship.Power.consume(amount)
    _currentAmount = _currentAmount - amount
    if _currentAmount < 0 then
        _currentAmount = 0
    end
end

local function updatePower()
    local prod = _maxProductionPerTick * getClimateManager():getDayLightStrength()

    _currentAmount = _currentAmount + prod - _consumptionPerTick

    if _currentAmount >= _maxAmount then
        _currentAmount = _maxAmount
    elseif _currentAmount < 0 then
        _currentAmount = 0
    end
end

Events.OnTick.Add(updatePower)