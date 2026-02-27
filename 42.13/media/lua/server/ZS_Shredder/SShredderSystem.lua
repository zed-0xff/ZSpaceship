-- ZSpaceship Shredder: server GlobalObject system.
-- State: processing, progress. When power on + input item + biomass container has space,
-- processes for PROCESS_DURATION then consumes one item and adds biomass to adjacent container.

if isClient() then return end

require "Map/SGlobalObjectSystem"
require "ZS_Shredder/Config"
require "ZS_Shredder/SShredderGlobalObject"

ZS_SShredderSystem = SGlobalObjectSystem:derive("ZS_SShredderSystem")

function ZS_SShredderSystem:new()
	local o = SGlobalObjectSystem.new(self, "zs_shredder")
	return o
end

function ZS_SShredderSystem:initSystem()
	SGlobalObjectSystem.initSystem(self)

    -- Specify GlobalObjectSystem fields that should be saved.
	self.system:setModDataKeys(nil)

    -- Specify GlobalObject fields that should be saved.
	self.system:setObjectModDataKeys({'processing', 'progress', 'processDurationSeconds'})

    -- Specify GlobalObject fields that should be synced on clients.
	self.system:setObjectSyncKeys({'processing', 'progress', 'processDurationSeconds'})
end

function ZS_SShredderSystem:newLuaObject(globalObject)
	return ZS_SShredderGlobalObject:new(self, globalObject)
end

function ZS_SShredderSystem:isValidIsoObject(isoObject)
	return ZS_Utils.isShredder(isoObject)
end

-- Register a shredder IsoObject with the shredder system (creates GlobalObject if needed).
local function tryLoadShredder(isoObject)
	if not isoObject or not ZS_Utils or not ZS_Utils.isShredder or not ZS_Utils.isShredder(isoObject) then return end
	local instance = ZS_SShredderSystem.instance
	if not instance or not instance.loadIsoObject then return end
	instance:loadIsoObject(isoObject)
end
Events.OnObjectAdded.Add(tryLoadShredder)

for tile in pairs(ZSpaceship.MapData.Tiles.Shredder) do
    MapObjects.OnNewWithSprite(tile, tryLoadShredder, 10)
end


-- When a grid square loads, register any shredder on it (map-placed shredders).
local function onLoadGridsquare(square)
	if not square or not ZS_SShredderSystem.instance then return end
	local objects = square.getObjects and square:getObjects()
	if not objects then return end
	for i = 0, objects:size() - 1 do
		local obj = objects:get(i)
		tryLoadShredder(obj)
	end
end
Events.LoadGridsquare.Add(onLoadGridsquare)

local function updateShredders()
	local instance = ZS_SShredderSystem.instance
	if not instance then
        if ZS_Shredder.Debug then
            print("[ZS_Shredder] updateShredders: no instance")
        end
		return
	end
	local n = instance:getLuaObjectCount()
    if ZS_Shredder.Debug then
        print("[ZS_Shredder] updateShredders: " .. tostring(n) .. " shredder(s)")
    end
	for i = 1, n do
		local luaObject = instance:getLuaObjectByIndex(i)
		if luaObject and luaObject.tick then
			luaObject:tick(60)  -- 60 seconds per minute
		end
	end
end

SGlobalObjectSystem.RegisterSystemClass(ZS_SShredderSystem)

Events.EveryOneMinute.Add(updateShredders)
