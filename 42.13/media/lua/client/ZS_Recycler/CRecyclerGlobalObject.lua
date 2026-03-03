-- ZSpaceship Recycler: client GlobalObject (synced state; sound handled in CRecyclerSystem).

require "Map/CGlobalObject"

ZS_CRecyclerGlobalObject = CGlobalObject:derive("ZS_CRecyclerGlobalObject")

function ZS_CRecyclerGlobalObject:new(luaSystem, globalObject)
	local o = CGlobalObject.new(self, luaSystem, globalObject)
	return o
end
