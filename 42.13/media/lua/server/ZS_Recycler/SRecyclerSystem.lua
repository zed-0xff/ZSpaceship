-- ZSpaceship Recycler: server GlobalObject system.
-- State: processing, progress. When power on + input item + biomass container has space,
-- processes for PROCESS_DURATION then consumes one item and adds biomass to adjacent container.

if isClient() then return end

require "Map/SGlobalObjectSystem"
require "ZS_Recycler/Config"
require "ZS_Recycler/SRecyclerGlobalObject"

ZS_SRecyclerSystem = SGlobalObjectSystem:derive("ZS_SRecyclerSystem")

local logger = ZBLogger.new("ZS_Recycler")

function ZS_SRecyclerSystem:new()
	local o = SGlobalObjectSystem.new(self, "zs_recycler")
	return o
end

function ZS_SRecyclerSystem:initSystem()
	SGlobalObjectSystem.initSystem(self)

    -- Specify GlobalObjectSystem fields that should be saved.
	self.system:setModDataKeys(nil)

    -- Specify GlobalObject fields that should be saved.
	self.system:setObjectModDataKeys({'processing', 'progress', 'processDurationSeconds', 'processingItemId'})

    -- Specify GlobalObject fields that should be synced on clients.
	self.system:setObjectSyncKeys({'processing', 'progress', 'processDurationSeconds', 'processingItemId'})
end

function ZS_SRecyclerSystem:newLuaObject(globalObject)
	return ZS_SRecyclerGlobalObject:new(self, globalObject)
end

function ZS_SRecyclerSystem:isValidIsoObject(isoObject)
	return ZS_Utils.isRecycler(isoObject)
end

-- Register a recycler IsoObject with the recycler system (creates GlobalObject if needed).
local function tryLoadRecycler(isoObject)
	if not isoObject or not ZS_Utils or not ZS_Utils.isRecycler or not ZS_Utils.isRecycler(isoObject) then return end
	local instance = ZS_SRecyclerSystem.instance
	if not instance or not instance.loadIsoObject then return end
	instance:loadIsoObject(isoObject)
end
Events.OnObjectAdded.Add(tryLoadRecycler)

for tile in pairs(ZSpaceship.MapData.Tiles.Recycler) do
    MapObjects.OnNewWithSprite(tile, tryLoadRecycler, 10)
end


-- When a grid square loads, register any recycler on it (map-placed recyclers).
local function onLoadGridsquare(square)
	if not square or not ZS_SRecyclerSystem.instance then return end
	local objects = square.getObjects and square:getObjects()
	if not objects then return end
	for i = 0, objects:size() - 1 do
		local obj = objects:get(i)
		tryLoadRecycler(obj)
	end
end
Events.LoadGridsquare.Add(onLoadGridsquare)

local function updateRecyclers()
	local instance = ZS_SRecyclerSystem.instance
	if not instance then
        logger:debug("updateRecyclers: no instance")
		return
	end
	local n = instance:getLuaObjectCount()
    logger:debug("updateRecyclers: %d recycler(s)", n)
	for i = 1, n do
		local luaObject = instance:getLuaObjectByIndex(i)
		if luaObject and luaObject.tick then
			luaObject:tick(60)  -- 60 seconds per minute
		end
	end
end

SGlobalObjectSystem.RegisterSystemClass(ZS_SRecyclerSystem)

Events.EveryOneMinute.Add(updateRecyclers)
