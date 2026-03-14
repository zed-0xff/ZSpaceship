-- ZSpaceship Recycler: client GlobalObject system (play processing sound when processing).

require "Map/CGlobalObjectSystem"
require "ZS_Recycler/Config"
require "ZS_Recycler/CRecyclerGlobalObject"

ZS_CRecyclerSystem = CGlobalObjectSystem:derive("ZS_CRecyclerSystem")

local logger = ZBLogger.new("ZS_Recycler")

function ZS_CRecyclerSystem:new()
	local o = CGlobalObjectSystem.new(self, "zs_recycler")
	return o
end

function ZS_CRecyclerSystem:isValidIsoObject(isoObject)
	return ZS_Utils.isRecycler(isoObject)
end

function ZS_CRecyclerSystem:newLuaObject(globalObject)
    logger:debug("Creating new LuaObject for GlobalObject %s", tostring(globalObject))
	return ZS_CRecyclerGlobalObject:new(self, globalObject)
end

-- Playing sounds per recycler (key = "x,y,z", value = audio from PlayWorldSound)
ZS_CRecyclerSystem._recyclerSounds = {}

local function updateRecyclerSounds()
	local instance = ZS_CRecyclerSystem.instance
	if not instance then return end

	local sounds = instance._recyclerSounds
	local toRemove = {}

	for i = 1, instance:getLuaObjectCount() do
		local luaObject = instance:getLuaObjectByIndex(i)
        logger:debug("updateRecyclerSounds: luaObject = %s", tostring(luaObject))
		if luaObject then
            logger:debug("updateRecyclerSounds: processing=%s at (%d,%d,%d)", tostring(luaObject.processing), luaObject.x or -1, luaObject.y or -1, luaObject.z or -1)
			local key = luaObject.x .. "," .. luaObject.y .. "," .. luaObject.z
			if luaObject.processing then
				if not sounds[key] then
					local square = luaObject:getSquare()
					if square then
                        local loop = true
                        local pitch = 0.8
                        local radius = 15
                        local maxGain = 1.0
                        local ignoreOutside = true
						local audio = getSoundManager():PlayWorldSound(ZS_Recycler.SOUND_NAME, loop, square, pitch, radius, maxGain, ignoreOutside)
						if audio then sounds[key] = audio end
					end
				end
			else
				if sounds[key] then
					getSoundManager():StopSound(sounds[key])
					toRemove[key] = true
				end
			end
		end
	end

	for k in pairs(toRemove) do
		sounds[k] = nil
	end
end

CGlobalObjectSystem.RegisterSystemClass(ZS_CRecyclerSystem)

Events.EveryOneMinute.Add(updateRecyclerSounds)
