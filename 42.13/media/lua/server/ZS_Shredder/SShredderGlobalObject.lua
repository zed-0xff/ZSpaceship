-- ZSpaceship Shredder: server GlobalObject (per-shredder state and processing).

if isClient() then return end

require "Map/SGlobalObject"

ZS_SShredderGlobalObject = SGlobalObject:derive("ZS_SShredderGlobalObject")

function ZS_SShredderGlobalObject:new(luaSystem, globalObject)
	local o = SGlobalObject.new(self, luaSystem, globalObject)
	return o
end

function ZS_SShredderGlobalObject:initNew()
	self.processing = false
	self.progress = 0
	self.processDurationSeconds = 0
end

function ZS_SShredderGlobalObject:stateFromIsoObject(isoObject)
	self.processing = false
	self.progress = 0
	self.processDurationSeconds = 0
end

function ZS_SShredderGlobalObject:stateToIsoObject(isoObject)
	-- No sprite/state to push to iso; state lives in GlobalObject modData.
end

-- Check ship power and consume for this minute. Uses ZSpaceship.Power.getAmount/consume.
local function hasPowerAndConsume()
	local power = ZSpaceship and ZSpaceship.Power and ZSpaceship.Power.getAmount and ZSpaceship.Power.getAmount()
	local need = (ZS_Shredder and ZS_Shredder.POWER_PER_MINUTE) or 1
	if not power or power < need then return false end
	if ZSpaceship.Power.consume then
		ZSpaceship.Power.consume(need)
	end
	return true
end

-- Add fluid (biomass) to the biomass storage object. Uses getWaterAmount/setWaterAmount.
local function addBiomassFluid(obj, amount)
	if not obj or not obj.getWaterAmount or not obj.setWaterAmount or amount <= 0 then return end
	local max = obj.getWaterMax and obj:getWaterMax() or 0
	local current = obj:getWaterAmount() or 0
	local add = math.min(math.floor(amount), math.max(0, max - current))
	if add > 0 then
		obj:setWaterAmount(current + add)
		if obj.transmitModData then obj:transmitModData() end
	end
end

-- Get shredder's input container (first container on the thumpable).
local function getShredderContainer(isoObject)
	if not isoObject then return nil end
	local cont = isoObject.getContainer and isoObject:getContainer()
	return cont
end

-- Organic: ZS_Shredder.Items.DisplayCategory[itemDisplayCategory] == true.
local function isOrganic(item)
	if not item then return false end
	local cat = nil
	if item.getScriptItem then
		local si = item:getScriptItem()
		if si and si.getDisplayCategory then cat = si:getDisplayCategory() end
	end
	return cat and ZS_Shredder and ZS_Shredder.Items and ZS_Shredder.Items.DisplayCategory and ZS_Shredder.Items.DisplayCategory[cat] == true
end

-- Get first item and its weight (kg); returns item, weightKg or nil.
local function peekFirstItem(container)
	if not container then return nil, 0 end
	local items = container:getItems()
	if not items or items:size() == 0 then return nil, 0 end
	local item = items:get(0)
	local w = (item.getActualWeight and item:getActualWeight()) or (item.getWeight and item:getWeight()) or 0
	return item, w
end

-- Remove first item from container; returns the item (before remove) or nil.
local function consumeFirstItem(container)
	if not container then return nil end
	local items = container:getItems()
	if not items or items:size() == 0 then return nil end
	local item = items:get(0)
	container:DoRemoveItem(item)
	return item
end

-- Processing time: ZS_Shredder.KG_PER_MINUTE kg per game-minute, minimum 1 minute. Returns seconds.
local function durationSecondsForWeight(weightKg)
	local kgPerMin = (ZS_Shredder and ZS_Shredder.KG_PER_MINUTE) or 2
	local minutes = math.max(1, weightKg / kgPerMin)
	return math.max(60, math.ceil(minutes * 60))
end

-- Transfer all items from container A into container B (so nested items get processed).
local function transferAllTo(fromCont, toCont)
	if not fromCont or not toCont then return end
	local items = fromCont:getItems()
	if not items then return end
	local i = items:size() - 1
	while i >= 0 do
		local item = items:get(i)
		if item then
			fromCont:DoRemoveItem(item)
			toCont:AddItem(item)
		end
		i = i - 1
	end
end

-- East square from shredder (for non-organic drop). Use coordinates to avoid getE() IsoDirections issues.
local function getEastSquare(shredderSquare)
	if not shredderSquare then return nil end
	local x, y, z = shredderSquare:getX(), shredderSquare:getY(), shredderSquare:getZ()
	local cell = getCell()
	return cell and cell:getGridSquare(x + 1, y, z) or nil
end

function ZS_SShredderGlobalObject:tick(deltaSeconds)
	if ZS_Shredder and ZS_Shredder.Debug then
		print("[ZS_Shredder] tick() called")
	end
	local isoObject = self:getIsoObject()
	if not isoObject then
		if ZS_Shredder and ZS_Shredder.Debug then
			print("[ZS_Shredder] tick: no isoObject (cell not loaded?)")
		end
		return
	end
	local square = self:getSquare()
	if not square then
		if ZS_Shredder and ZS_Shredder.Debug then
			print("[ZS_Shredder] tick: no square")
		end
		return
	end

	-- No ship power or can't consume -> stop
	if not hasPowerAndConsume() then
		if ZS_Shredder and ZS_Shredder.Debug then
			print("[ZS_Shredder] tick: no power (ZSpaceship.Power.getAmount < POWER_PER_MINUTE)")
		end
		if self.processing then
			self.processing = false
			self.progress = 0
			self.processDurationSeconds = 0
			self:updateOnClient()
		end
		return
	end

	local shredderCont = getShredderContainer(isoObject)
	local itemCount = shredderCont and shredderCont:getItems() and shredderCont:getItems():size() or 0
	if not shredderCont or itemCount == 0 then
		if ZS_Shredder and ZS_Shredder.Debug then
			print("[ZS_Shredder] tick: no container or empty (itemCount=" .. tostring(itemCount) .. ")")
		end
		if self.processing then
			self.processing = false
			self.progress = 0
			self.processDurationSeconds = 0
			self:updateOnClient()
		end
		return
	end

	local firstItem, weightKg = peekFirstItem(shredderCont)
	if not firstItem then
		if ZS_Shredder and ZS_Shredder.Debug then
			print("[ZS_Shredder] No first item, stopping.")
		end
		self.processing = false
		self.progress = 0
		self.processDurationSeconds = 0
		self:updateOnClient()
		return
	end

	local organic = isOrganic(firstItem)
	local biomassCont = ZS_Utils.findAdjacentBiomassContainer(square)
	-- Fluid API is on the fluid container (findAdjacent returns getFluidContainer) or its parent
	local biomassObj = (biomassCont and biomassCont.getParent and biomassCont:getParent()) or biomassCont

	-- Organic items need biomass storage object with room for fluid
	if organic then
		local noRoom = not biomassCont
		if biomassCont then
			if biomassCont.getFreeCapacity and biomassCont:getFreeCapacity() == 0 then noRoom = true
			elseif biomassCont.getWaterAmount and biomassCont.getWaterMax then
				local cur, max = biomassCont:getWaterAmount() or 0, biomassCont:getWaterMax() or 0
				if cur >= max then noRoom = true end
			end
		end
		if noRoom then
			if ZS_Shredder and ZS_Shredder.Debug then
				local name = firstItem.getDisplayName and firstItem:getDisplayName() or firstItem:getType() or "?"
				print("[ZS_Shredder] Organic item '" .. tostring(name) .. "' but no biomass container with room, waiting.")
			end
			if self.processing then
				self.processing = false
				self.progress = 0
				self.processDurationSeconds = 0
				self:updateOnClient()
			end
			return
		end
	end
	-- Non-organic needs east square for scrap (always exists if we have a square)

	-- Start or continue current item
	if not self.processing or not self.processDurationSeconds then
		self.processDurationSeconds = durationSecondsForWeight(weightKg)
		self.progress = 0
		if ZS_Shredder and ZS_Shredder.Debug then
			local name = firstItem.getDisplayName and firstItem:getDisplayName() or firstItem:getType() or "?"
			print("[ZS_Shredder] Start processing '" .. tostring(name) .. "' organic=" .. tostring(organic) .. " weight=" .. tostring(weightKg) .. "kg duration=" .. tostring(self.processDurationSeconds) .. "s")
		end
	end
	self.processing = true
	self.progress = (self.progress or 0) + (deltaSeconds or 60)

	if self.progress < (self.processDurationSeconds or 60) then
		self:updateOnClient()
		return
	end

	-- Peek first item and transfer nested items into shredder before consuming (so they are processed separately).
	local firstItem = peekFirstItem(shredderCont)
	if firstItem then
		local innerCont = firstItem.getItemContainer and firstItem:getItemContainer()
		if innerCont then
			local n = innerCont:getItems() and innerCont:getItems():size() or 0
			transferAllTo(innerCont, shredderCont)
			if ZS_Shredder and ZS_Shredder.Debug and n > 0 then
				local name = firstItem.getDisplayName and firstItem:getDisplayName() or firstItem:getType() or "?"
				print("[ZS_Shredder] Transferred " .. tostring(n) .. " nested items from '" .. tostring(name) .. "'")
			end
		end
	end

	local consumed = consumeFirstItem(shredderCont)
	if not consumed then
		if ZS_Shredder and ZS_Shredder.Debug then
			print("[ZS_Shredder] consumeFirstItem returned nil.")
		end
		self.processing = false
		self.progress = 0
		self.processDurationSeconds = 0
		self:updateOnClient()
		return
	end

	local w = (consumed.getActualWeight and consumed:getActualWeight()) or (consumed.getWeight and consumed:getWeight()) or 0
	local cName = consumed.getDisplayName and consumed:getDisplayName() or consumed:getType() or "?"
	-- Use organic from start of processing (same item we timed); isOrganic(consumed) can differ after transfer.
	if organic and biomassObj then
		local coef = (ZS_Shredder and ZS_Shredder.BIOMASS_COEFF) or 0.5
		local amount = math.max(1, w * coef)
		addBiomassFluid(biomassObj, amount)
		if ZS_Shredder and ZS_Shredder.Debug then
			print("[ZS_Shredder] Consumed organic '" .. tostring(cName) .. "' -> biomass +" .. tostring(amount))
		end
	else
		-- Non-organic: drop item on the tile to the east. API expects (item, direction, offsetX, offsetY) - direction must be IsoDirections, not a number.
		local eastSq = getEastSquare(square)
		if eastSq and consumed then
			local dir = IsoDirections and IsoDirections.East
			if dir then
				eastSq:AddWorldInventoryItem(consumed, dir, 0.5, 0.5)
			else
				eastSq:AddWorldInventoryItem(consumed, 0.5, 0.5, 0)
			end
		end
		if ZS_Shredder and ZS_Shredder.Debug then
			print("[ZS_Shredder] Consumed non-organic '" .. tostring(cName) .. "' -> dropped east")
		end
	end

	self.progress = 0
	self.processDurationSeconds = 0

	-- More items? Next tick will peek and set new duration.
	if shredderCont:getItems():size() == 0 then
		if ZS_Shredder and ZS_Shredder.Debug then
			print("[ZS_Shredder] Shredder empty, stopping.")
		end
		self.processing = false
	end

	self:updateOnClient()
end
