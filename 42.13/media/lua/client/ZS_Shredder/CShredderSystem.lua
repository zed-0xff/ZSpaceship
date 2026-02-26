-- ZSpaceship Shredder: client GlobalObject system (play processing sound when processing).

if not isClient() then return end

require "Map/CGlobalObjectSystem"
require "ZS_Shredder/Config"
require "ZS_Shredder/CShredderGlobalObject"

ZS_CShredderSystem = CGlobalObjectSystem:derive("ZS_CShredderSystem")

function ZS_CShredderSystem:new()
	local o = CGlobalObjectSystem.new(self, "zs_shredder")
	return o
end

function ZS_CShredderSystem:isValidIsoObject(isoObject)
	return ZS_Utils.isShredder(isoObject)
end

function ZS_CShredderSystem:newLuaObject(globalObject)
	return ZS_CShredderGlobalObject:new(self, globalObject)
end

-- Playing sounds per shredder (key = "x,y,z", value = audio from PlayWorldSound)
ZS_CShredderSystem._shredderSounds = {}

local function updateShredderSounds()
	local instance = ZS_CShredderSystem.instance
	if not instance then return end

	local sounds = instance._shredderSounds
	local toRemove = {}

	for i = 1, instance:getLuaObjectCount() do
		local luaObject = instance:getLuaObjectByIndex(i)
		if luaObject then
			local key = luaObject.x .. "," .. luaObject.y .. "," .. luaObject.z
			if luaObject.processing then
				if not sounds[key] then
					local square = luaObject:getSquare()
					if square then
						local audio = getSoundManager():PlayWorldSound(ZS_Shredder.SOUND_NAME, true, square, 0.0, 15, 1.0, false)
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

CGlobalObjectSystem.RegisterSystemClass(ZS_CShredderSystem)

Events.EveryOneMinute.Add(updateShredderSounds)
