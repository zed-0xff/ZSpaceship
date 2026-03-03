-- ZSpaceship Recycler: server GlobalObject (per-recycler state and processing).

if isClient() then return end

require "Map/SGlobalObject"
require "Moveables/ISMoveableSpriteProps"
require "Moveables/ISMoveableDefinitions"

ZS_SRecyclerGlobalObject = SGlobalObject:derive("ZS_SRecyclerGlobalObject")

function ZS_SRecyclerGlobalObject:new(luaSystem, globalObject)
	local o = SGlobalObject.new(self, luaSystem, globalObject)
	return o
end

function ZS_SRecyclerGlobalObject:initNew()
	self.processing = false
	self.progress = 0
	self.processDurationSeconds = 0
	self.processingItemId = nil
end

function ZS_SRecyclerGlobalObject:stateFromIsoObject(isoObject)
	self.processing = false
	self.progress = 0
	self.processDurationSeconds = 0
	self.processingItemId = nil
end

function ZS_SRecyclerGlobalObject:stateToIsoObject(isoObject)
	-- No sprite/state to push to iso; state lives in GlobalObject modData.
end

-- Check ship power and consume for this minute. Uses ZSpaceship.Power.getAmount/consume.
local function hasPowerAndConsume()
	local power = ZSpaceship and ZSpaceship.Power and ZSpaceship.Power.getAmount and ZSpaceship.Power.getAmount()
	local need = ZS_Recycler.POWER_PER_MINUTE
	if not power or power < need then return false end
	if ZSpaceship.Power.consume then
		ZSpaceship.Power.consume(need)
	end
	return true
end

-- Get recycler's input container (first container on the thumpable).
local function getRecyclerContainer(isoObject)
	if not isoObject then return nil end
	local cont = isoObject.getItemContainer and isoObject:getItemContainer()
	return cont
end

-- Organic: ZS_Recycler.Items.DisplayCategory[itemDisplayCategory] or FullType.
local function isOrganic(item)
	if not item then return false end
	local ft = item.getFullType and item:getFullType()
	if ft and ZS_Recycler.Items and ZS_Recycler.Items.FullType and ZS_Recycler.Items.FullType[ft] == true then
		return true
	end
	local cat = nil
	if item.getScriptItem then
		local si = item:getScriptItem()
		if si and si.getDisplayCategory then cat = si:getDisplayCategory() end
	end
	return cat and ZS_Recycler.Items and ZS_Recycler.Items.DisplayCategory and ZS_Recycler.Items.DisplayCategory[cat] == true
end

-- Placeable (moveable) item with CanScrap sprite property: use ISMoveableSpriteProps scrap logic (no tools/skills).
local function isScrapablePlaceable(item)
	if not item then return false end
	if not instanceof(item, "Moveable") then return false end
	local spriteName = item.getWorldSprite and item:getWorldSprite()
	if not spriteName then return false end
	local moveProps = ISMoveableSpriteProps.new(spriteName)
	return moveProps and moveProps.canScrap == true
end

-- Unknown: not organic and not scrapable placeable → leave in input.
local function isKnownProcessable(item)
	return isOrganic(item) or isScrapablePlaceable(item)
end

-- Find first processable item by iterating; returns item, weightKg or nil.
local function findFirstProcessableItem(container)
	if not container then return nil, 0 end
	local items = container:getItems()
	if not items then return nil, 0 end
	for i = 0, items:size() - 1 do
		local item = items:get(i)
		if item and isKnownProcessable(item) then
			local w = (item.getActualWeight and item:getActualWeight()) or (item.getWeight and item:getWeight()) or 0
			return item, w
		end
	end
	return nil, 0
end

-- Find item in container by ID; returns item or nil.
local function findItemById(container, itemId)
	if not container or not itemId then return nil end
	local items = container:getItems()
	if not items then return nil end
	for i = 0, items:size() - 1 do
		local item = items:get(i)
		if item and item.getID and item:getID() == itemId then
			return item
		end
	end
	return nil
end

-- Processing time: ZS_Recycler.KG_PER_MINUTE kg per game-minute, minimum 1 minute. Returns seconds.
local function durationSecondsForWeight(weightKg)
	local kgPerMin = (ZS_Recycler and ZS_Recycler.KG_PER_MINUTE) or 2
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

-- East square from recycler (for non-organic drop). Use coordinates to avoid getE() IsoDirections issues.
local function getEastSquare(recyclerSquare)
	if not recyclerSquare then return nil end
	local x, y, z = recyclerSquare:getX(), recyclerSquare:getY(), recyclerSquare:getZ()
	local cell = getCell()
	return cell and cell:getGridSquare(x + 1, y, z) or nil
end

-- Adjacent squares in order E, S, W, N (for container / drop search).
local function getAdjacentSquaresESWN(recyclerSquare)
	if not recyclerSquare then return {} end
	local x, y, z = recyclerSquare:getX(), recyclerSquare:getY(), recyclerSquare:getZ()
	local cell = getCell()
	if not cell then return {} end
	return {
		cell:getGridSquare(x + 1, y, z), -- E
		cell:getGridSquare(x, y + 1, z), -- S
		cell:getGridSquare(x - 1, y, z), -- W
		cell:getGridSquare(x, y - 1, z), -- N
	}
end

-- Find first object on square that has getItemContainer(); returns container, parentObj (for sync) or nil, nil.
local function findContainerOnSquare(square)
	if not square then return nil, nil end
	local wobs = square:getWorldObjects()
	if not wobs then return nil, nil end
	for i = 0, wobs:size() - 1 do
		local obj = wobs:get(i)
		if obj and obj.getItemContainer then
			local cont = obj:getItemContainer()
			if cont then
				return cont, obj
			end
		end
	end
	return nil, nil
end

-- Find nearby container (E, S, W, N) or first empty tile in that order for floor drop. Returns (container, parentObj, nil), (nil, nil, dropSquare), or (nil, nil, nil).
local function findContainerOrEmptySquare(recyclerSquare)
	local adj = getAdjacentSquaresESWN(recyclerSquare)
	for _, sq in ipairs(adj) do
		if sq then
			local cont, parentObj = findContainerOnSquare(sq)
			if cont then
				return cont, parentObj, nil
			end
		end
	end
	-- No container: use first adjacent as drop tile (E then S then W then N).
	for _, sq in ipairs(adj) do
		if sq then
			return nil, nil, sq
		end
	end
	return nil, nil, nil
end

-- Build scrap output list from moveable sprite props (no tools/skills: use chance 100). Returns { usable = { fullType, ... }, unusable = { ... } } or nil.
local function getScrapItemsListNoSkill(moveProps)
	if not moveProps or not moveProps.canScrap then return nil end
	local materials = {}
	if moveProps.material then table.insert(materials, moveProps.material) end
	if moveProps.material2 then table.insert(materials, moveProps.material2) end
	if moveProps.material3 then table.insert(materials, moveProps.material3) end
	if #materials == 0 then return nil end

	local items = { usable = {}, unusable = {} }
	local defs = ISMoveableDefinitions:getInstance()
	local chance = 100

	for _, mat in ipairs(materials) do
		local scrapDef = defs.getScrapDefinition and defs:getScrapDefinition(mat)
		if scrapDef then
			local returnItems = scrapDef.returnItemsStatic or scrapDef.returnItems
			if returnItems and #returnItems > 0 then
				for _, v in ipairs(returnItems) do
					local amount = v.maxAmount or 0
					if moveProps.scrapSize == "Small" then
						amount = (amount / 2 >= 1) and (amount / 2) or 1
					elseif moveProps.scrapSize == "Large" then
						amount = amount * 2
					end
					local rollChance = v.chancePerRoll or 100
					for _ = 1, amount do
						if ZombRandFloat(0, 101) < rollChance then
							table.insert(items.usable, v.returnItem)
						end
					end
				end
			end
			if #items.usable == 0 and scrapDef.unusableItem then
				for _ = 1, ZombRand(1, 3) do
					table.insert(items.unusable, scrapDef.unusableItem)
				end
			end
		end
	end
	return items
end

-- Place scrap item list into container or on square. moveProps optional (for keyId/Wire; recycler has no keyId).
local function placeScrapItems(containerOrSquare, scrapList, moveProps, isContainer)
	if not scrapList then return 0 end
	local n = 0
	for _, fullType in ipairs(scrapList.usable or {}) do
		local item = instanceItem(fullType)
		if item then
			if moveProps and moveProps.keyId and moveProps.keyId ~= -1 and item.getType and item:getType() == "Doorknob" then
				item:setKeyId(moveProps.keyId)
			end
			if item.getType and item:getType() == "Wire" and item.setUsedDelta then
				item:setUsedDelta(0.1)
			end
			if isContainer then
				containerOrSquare:AddItem(item)
			else
				containerOrSquare:AddWorldInventoryItem(item, ZombRandFloat(0.1, 0.9), ZombRandFloat(0.1, 0.9), 0)
			end
			n = n + 1
		end
	end
	for _, fullType in ipairs(scrapList.unusable or {}) do
		local item = instanceItem(fullType)
		if item then
			if isContainer then
				containerOrSquare:AddItem(item)
			else
				containerOrSquare:AddWorldInventoryItem(item, ZombRandFloat(0.1, 0.9), ZombRandFloat(0.1, 0.9), 0)
			end
			n = n + 1
		end
	end
	return n
end

function ZS_SRecyclerGlobalObject:tick(deltaSeconds)
	if ZS_Recycler.Debug then
		print("[ZS_Recycler] tick() called")
	end
	local isoObject = self:getIsoObject()
	if not isoObject then
		if ZS_Recycler.Debug then
			print("[ZS_Recycler] tick: no isoObject (cell not loaded?)")
		end
		return
	end
	local square = self:getSquare()
	if not square then
		if ZS_Recycler.Debug then
			print("[ZS_Recycler] tick: no square")
		end
		return
	end

	-- No ship power or can't consume -> stop
	if not hasPowerAndConsume() then
		if ZS_Recycler.Debug then
			print("[ZS_Recycler] tick: no power (ZSpaceship.Power.getAmount < POWER_PER_MINUTE)")
		end
		if self.processing then
			self.processing = false
			self.progress = 0
			self.processDurationSeconds = 0
			self.processingItemId = nil
			self:updateOnClient()
		end
		return
	end

	local recyclerCont = getRecyclerContainer(isoObject)
	local itemCount = recyclerCont and recyclerCont:getItems() and recyclerCont:getItems():size() or 0
	if not recyclerCont or itemCount == 0 then
		if ZS_Recycler.Debug then
			print("[ZS_Recycler] tick: no container or empty (itemCount=" .. tostring(itemCount) .. ")")
		end
		if self.processing then
			self.processing = false
			self.progress = 0
			self.processDurationSeconds = 0
			self.processingItemId = nil
			self:updateOnClient()
		end
		return
	end

	-- Resolve current item: either one we're already processing (by ID) or first processable from iteration.
	local currentItem, weightKg = nil, 0
	if self.processingItemId then
		currentItem = findItemById(recyclerCont, self.processingItemId)
		if currentItem then
			weightKg = (currentItem.getActualWeight and currentItem:getActualWeight()) or (currentItem.getWeight and currentItem:getWeight()) or 0
		else
			-- Item was removed (e.g. by player); clear state and pick next
			self.processingItemId = nil
			self.processing = false
			self.progress = 0
			self.processDurationSeconds = 0
		end
	end
	if not currentItem then
		currentItem, weightKg = findFirstProcessableItem(recyclerCont)
	end
	if not currentItem then
		if self.processing then
			self.processing = false
			self.progress = 0
			self.processDurationSeconds = 0
			self.processingItemId = nil
			self:updateOnClient()
		end
		return
	end

	local organic = isOrganic(currentItem)
	local biomassCont = ZS_Utils.findAdjacentBiomassContainer(square)

	-- Organic items need biomass storage object with room for fluid
	if organic then
		local noRoom = not biomassCont or biomassCont:getFreeCapacity() == 0
		if noRoom then
			if ZS_Recycler.Debug then
				local name = currentItem.getDisplayName and currentItem:getDisplayName() or currentItem:getType() or "?"
				print("[ZS_Recycler] Organic item '" .. tostring(name) .. "' but no biomass container with room, waiting.")
			end
			if self.processing then
				self.processing = false
				self.progress = 0
				self.processDurationSeconds = 0
				self.processingItemId = nil
				self:updateOnClient()
			end
			return
		end
	end
	-- Non-organic needs east square for scrap (always exists if we have a square)

	-- Start or continue current item
	if not self.processing or not self.processDurationSeconds then
		self.processingItemId = currentItem.getID and currentItem:getID() or nil
		self.processDurationSeconds = durationSecondsForWeight(weightKg)
		self.progress = 0
		if ZS_Recycler.Debug then
			local name = currentItem.getDisplayName and currentItem:getDisplayName() or currentItem:getType() or "?"
			print("[ZS_Recycler] Start processing '" .. tostring(name) .. "' organic=" .. tostring(organic) .. " weight=" .. tostring(weightKg) .. "kg duration=" .. tostring(self.processDurationSeconds) .. "s")
		end
	end
	self.processing = true
	self.progress = (self.progress or 0) + (deltaSeconds or 60)

	if self.progress < (self.processDurationSeconds or 60) then
		self:updateOnClient()
		return
	end

	-- Re-resolve item by ID (may have shifted after nested transfer) and transfer nested items before consuming.
	local consumed = findItemById(recyclerCont, self.processingItemId)
	if consumed then
		local innerCont = consumed.getItemContainer and consumed:getItemContainer()
		if innerCont then
			local n = innerCont:getItems() and innerCont:getItems():size() or 0
			transferAllTo(innerCont, recyclerCont)
			if ZS_Recycler.Debug and n > 0 then
				local name = consumed.getDisplayName and consumed:getDisplayName() or consumed:getType() or "?"
				print("[ZS_Recycler] Transferred " .. tostring(n) .. " nested items from '" .. tostring(name) .. "'")
			end
			consumed = findItemById(recyclerCont, self.processingItemId)
		end
	end
	if not consumed then
		if ZS_Recycler.Debug then
			print("[ZS_Recycler] Item no longer in container.")
		end
		self.processing = false
		self.progress = 0
		self.processDurationSeconds = 0
		self.processingItemId = nil
		self:updateOnClient()
		return
	end
	recyclerCont:DoRemoveItem(consumed)

	local w = (consumed.getActualWeight and consumed:getActualWeight()) or (consumed.getWeight and consumed:getWeight()) or 0
	-- Use organic from start of processing (same item we timed); isOrganic(consumed) can differ after transfer.
	if organic and biomassCont then
		local amount = math.max(1, w * ZS_Recycler.BIOMASS_COEFF)
        biomassCont:addFluid(Fluid.Get("Biomass"), amount)
		if ZS_Recycler.Debug then
            local cName = consumed.getDisplayName and consumed:getDisplayName() or consumed:getType() or "?"
			print("[ZS_Recycler] Consumed organic '" .. tostring(cName) .. "' -> biomass +" .. tostring(amount))
		end
	elseif isScrapablePlaceable(consumed) then
		-- Placeable with canScrap: use ISMoveableSpriteProps scrap logic (no tools/skills), output to nearby container or floor.
		local spriteName = consumed.getWorldSprite and consumed:getWorldSprite()
		local moveProps = spriteName and ISMoveableSpriteProps.new(spriteName)
		local scrapList = moveProps and getScrapItemsListNoSkill(moveProps)
		if scrapList and (#(scrapList.usable or {}) > 0 or #(scrapList.unusable or {}) > 0) then
			local cont, parentObj, dropSq = findContainerOrEmptySquare(square)
			if cont then
				local placed = placeScrapItems(cont, scrapList, moveProps, true)
				if parentObj and parentObj.sync then parentObj:sync() end
				if ZS_Recycler.Debug then
					local cName = consumed.getDisplayName and consumed:getDisplayName() or consumed:getType() or "?"
					print("[ZS_Recycler] Scrapped placeable '" .. tostring(cName) .. "' -> " .. tostring(placed) .. " items into container")
				end
			elseif dropSq then
				local placed = placeScrapItems(dropSq, scrapList, moveProps, false)
				if ZS_Recycler.Debug then
					local cName = consumed.getDisplayName and consumed:getDisplayName() or consumed:getType() or "?"
					print("[ZS_Recycler] Scrapped placeable '" .. tostring(cName) .. "' -> " .. tostring(placed) .. " items on floor")
				end
			end
		end
		-- If no scrap list or no container/square, item is still consumed (destroyed).
	else
		-- Non-organic, not scrapable placeable: drop item on the tile to the east.
		local eastSq = getEastSquare(square)
		if eastSq and consumed then
			local dir = IsoDirections and IsoDirections.East
			if dir then
				eastSq:AddWorldInventoryItem(consumed, dir, 0.5, 0.5)
			else
				eastSq:AddWorldInventoryItem(consumed, 0.5, 0.5, 0)
			end
		end
		if ZS_Recycler.Debug then
            local cName = consumed.getDisplayName and consumed:getDisplayName() or consumed:getType() or "?"
			print("[ZS_Recycler] Consumed non-organic '" .. tostring(cName) .. "' -> dropped east")
		end
	end

	self.progress = 0
	self.processDurationSeconds = 0
	self.processingItemId = nil

	-- More items? Next tick will find first processable and set new duration.
	if recyclerCont:getItems():size() == 0 then
		if ZS_Recycler.Debug then
			print("[ZS_Recycler] Recycler empty, stopping.")
		end
		self.processing = false
	end

	-- Sync recycler inventory to clients after container changes
	if isoObject and isoObject.sync then
		isoObject:sync()
	end
	self:updateOnClient()
end
