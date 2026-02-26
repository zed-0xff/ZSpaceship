-- ZSpaceship Shredder: client GlobalObject (synced state; sound handled in CShredderSystem).

require "Map/CGlobalObject"

ZS_CShredderGlobalObject = CGlobalObject:derive("ZS_CShredderGlobalObject")

function ZS_CShredderGlobalObject:new(luaSystem, globalObject)
	local o = CGlobalObject.new(self, luaSystem, globalObject)
	return o
end
