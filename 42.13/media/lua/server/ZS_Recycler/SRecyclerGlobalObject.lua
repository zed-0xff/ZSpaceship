-- ZSpaceship Recycler: server GlobalObject (per-recycler state and processing).

if isClient() then return end

require "Map/SGlobalObject"
require "Moveables/ISMoveableSpriteProps"
require "Moveables/ISMoveableDefinitions"

ZS_SRecyclerGlobalObject = SGlobalObject:derive("ZS_SRecyclerGlobalObject")

local logger = ZSLogger.new("ZS_Recycler")

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

-- Item has a reverse recipe defined (result fullType -> recipe(s) -> ingredients).
local function isReverseRecipe(item)
	if not item then return false end
	local ft = item.getFullType and item:getFullType()
	if not ft then return false end
	local rr = ZS_Recycler.reverse_recipes
	if not rr or not rr[ft] then return false end
	local recipes = rr[ft]
	for _ in pairs(recipes) do return true end
	return false
end

-- Unknown: not organic, not scrapable placeable, not reverse recipe → leave in input.
local function isKnownProcessable(item)
	return isOrganic(item) or isScrapablePlaceable(item) or isReverseRecipe(item)
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
	local kgPerMin = ZS_Recycler.KG_PER_MINUTE or 2
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

-- Get ingredients from reverse recipe for item: pick one recipe at random when multiple, apply EFFICIENCY. Returns { { fullType, count }, ... } or nil.
local function getReverseRecipeIngredients(item)
	if not item then return nil end
	local ft = item.getFullType and item:getFullType()
	local rr = ZS_Recycler.reverse_recipes
	if not rr or not ft or not rr[ft] then return nil end
	local recipes = rr[ft]
	local keys = {}
	for k in pairs(recipes) do keys[#keys + 1] = k end
	if #keys == 0 then return nil end
	local recipeName = keys[ZombRand(1, #keys + 1)]
	local ingredients = recipes[recipeName]
	if not ingredients then return nil end
	local eff = ZS_Recycler.EFFICIENCY or 0.5
	local list = {}
	for fullType, count in pairs(ingredients) do
		local n = math.max(0, math.floor(count * eff + 0.5))
		if n >= 1 then
			list[#list + 1] = { fullType = fullType, count = n }
		end
	end
	return (#list > 0) and list or nil
end

-- Place item list into container or on square. list: { { fullType, count }, ... } or scrapList { usable = { fullType,... }, unusable = { ... } }. setupFn(item, fullType) optional (e.g. for scrap Doorknob/Wire).
local function placeItemList(containerOrSquare, list, isContainer, setupFn)
	if not list then return 0 end
	local items = {}
	if list.usable then
		for _, ft in ipairs(list.usable or {}) do items[#items + 1] = { fullType = ft, count = 1 } end
		for _, ft in ipairs(list.unusable or {}) do items[#items + 1] = { fullType = ft, count = 1 } end
	else
		for _, e in ipairs(list) do items[#items + 1] = { fullType = e.fullType, count = e.count or 1 } end
	end
	local n = 0
	for _, entry in ipairs(items) do
		for _ = 1, entry.count do
			local item = instanceItem(entry.fullType)
			if item then
				if setupFn then setupFn(item, entry.fullType) end
				if isContainer then
					containerOrSquare:AddItem(item)
				else
					containerOrSquare:AddWorldInventoryItem(item, ZombRandFloat(0.1, 0.9), ZombRandFloat(0.1, 0.9), 0)
				end
				n = n + 1
			end
		end
	end
	return n
end

-- Clear processing state and notify client.
local function stopProcessing(self)
	self.processing = false
	self.progress = 0
	self.processDurationSeconds = 0
	self.processingItemId = nil
	self:updateOnClient()
end

-- Resolve current item: by processingItemId or first processable. May clear state if item was removed. Returns currentItem, weightKg or nil, 0.
local function resolveCurrentItem(self, recyclerCont)
	local item, weightKg = nil, 0
	if self.processingItemId then
		item = findItemById(recyclerCont, self.processingItemId)
		if item then
			weightKg = (item.getActualWeight and item:getActualWeight()) or (item.getWeight and item:getWeight()) or 0
		else
			logger:debug("Item ID %s no longer in container (removed?), picking next.", tostring(self.processingItemId))
			stopProcessing(self)
			return nil, 0
		end
	end
	if not item then
		item, weightKg = findFirstProcessableItem(recyclerCont)
	end
	return item, weightKg
end

-- If item is organic, return biomass container with room; else return any adjacent biomass container. Returns nil when organic but no room (wait).
local function getBiomassContainerForOrganic(currentItem, square)
	local biomassCont = ZS_Utils and ZS_Utils.findAdjacentBiomassContainer and ZS_Utils.findAdjacentBiomassContainer(square)
	if not isOrganic(currentItem) then
		return biomassCont
	end
	if not biomassCont or biomassCont:getFreeCapacity() == 0 then
		return nil
	end
	return biomassCont
end

-- Start or continue processing current item; advance progress. Returns true if still in progress (progress < duration), false if complete.
local function startOrContinueItem(self, currentItem, weightKg, organic, deltaSeconds)
	if not self.processing or not self.processDurationSeconds then
		self.processingItemId = currentItem.getID and currentItem:getID() or nil
		self.processDurationSeconds = durationSecondsForWeight(weightKg)
		self.progress = 0
		logger:debug("Start processing '%s' organic=%s weight=%s kg duration=%s s",
			currentItem.getDisplayName and currentItem:getDisplayName() or currentItem:getType() or "?", tostring(organic), tostring(weightKg), tostring(self.processDurationSeconds))
	end
	self.processing = true
	self.progress = (self.progress or 0) + (deltaSeconds or 60)
	return self.progress < (self.processDurationSeconds or 60)
end

-- Re-resolve item by ID after transferring nested items to recycler. Returns consumed item or nil.
local function resolveConsumedAfterNestedTransfer(recyclerCont, processingItemId)
	local consumed = findItemById(recyclerCont, processingItemId)
	if not consumed then return nil end
	local innerCont = consumed.getItemContainer and consumed:getItemContainer()
	if innerCont then
		local n = innerCont:getItems() and innerCont:getItems():size() or 0
		transferAllTo(innerCont, recyclerCont)
		if n > 0 then
			logger:debug("Transferred %d nested items from '%s'", n, consumed.getDisplayName and consumed:getDisplayName() or consumed:getType() or "?")
		end
		consumed = findItemById(recyclerCont, processingItemId)
	end
	return consumed
end

-- Route consumed item to biomass, reverse recipe, scrap, or drop east. Caller must already have removed item from container.
local function dispatchConsumed(consumed, organic, biomassCont, square)
	local w = (consumed.getActualWeight and consumed:getActualWeight()) or (consumed.getWeight and consumed:getWeight()) or 0
	local name = consumed.getDisplayName and consumed:getDisplayName() or consumed:getType() or "?"
	if organic and biomassCont then
		local amount = math.max(1, w * ZS_Recycler.EFFICIENCY)
		biomassCont:addFluid(Fluid.Get("Biomass"), amount)
		logger:info("Consumed organic '%s' -> biomass +%s", name, tostring(amount))
	elseif isReverseRecipe(consumed) then
		local ingredientList = getReverseRecipeIngredients(consumed)
		if not ingredientList then
			logger:warn("Reverse recipe '%s' but no ingredients returned (empty recipe?).", name)
		else
			local cont, parentObj, dropSq = findContainerOrEmptySquare(square)
			if cont then
				local placed = placeItemList(cont, ingredientList, true, nil)
				if parentObj and parentObj.sync then parentObj:sync() end
				logger:info("Reverse recipe '%s' -> %d items into container", name, placed)
			elseif dropSq then
				local placed = placeItemList(dropSq, ingredientList, false, nil)
				logger:info("Reverse recipe '%s' -> %d items on floor", name, placed)
			else
				logger:warn("Reverse recipe '%s' but no container or square for output, item destroyed.", name)
			end
		end
	elseif isScrapablePlaceable(consumed) then
		local spriteName = consumed.getWorldSprite and consumed:getWorldSprite()
		local moveProps = spriteName and ISMoveableSpriteProps.new(spriteName)
		local scrapList = moveProps and getScrapItemsListNoSkill(moveProps)
		if not scrapList or (#(scrapList.usable or {}) == 0 and #(scrapList.unusable or {}) == 0) then
			logger:warn("Scrapable placeable '%s' but no scrap output (empty list), item destroyed.", name)
		else
			local function scrapSetup(item)
				if moveProps and moveProps.keyId and moveProps.keyId ~= -1 and item.getType and item:getType() == "Doorknob" then
					item:setKeyId(moveProps.keyId)
				end
				if item.getType and item:getType() == "Wire" and item.setUsedDelta then
					item:setUsedDelta(0.1)
				end
			end
			local cont, parentObj, dropSq = findContainerOrEmptySquare(square)
			if cont then
				local placed = placeItemList(cont, scrapList, true, scrapSetup)
				if parentObj and parentObj.sync then parentObj:sync() end
				logger:info("Scrapped placeable '%s' -> %d items into container", name, placed)
			elseif dropSq then
				local placed = placeItemList(dropSq, scrapList, false, scrapSetup)
				logger:info("Scrapped placeable '%s' -> %d items on floor", name, placed)
			else
				logger:warn("Scrapable placeable '%s' but no container or square for output, item destroyed.", name)
			end
		end
	else
		local eastSq = getEastSquare(square)
		if eastSq and consumed then
			local dir = IsoDirections and IsoDirections.East
			if dir then
				eastSq:AddWorldInventoryItem(consumed, dir, 0.5, 0.5)
			else
				eastSq:AddWorldInventoryItem(consumed, 0.5, 0.5, 0)
			end
			logger:info("Consumed non-organic '%s' -> dropped east", name)
		else
			logger:warn("Consumed non-organic '%s' but no east square, item destroyed.", name)
		end
	end
end

-- Reset item state; stop if recycler empty; sync and update client.
local function finishTick(self, recyclerCont, isoObject)
	self.progress = 0
	self.processDurationSeconds = 0
	self.processingItemId = nil
	if recyclerCont:getItems():size() == 0 then
		logger:info("Recycler empty, stopping.")
		self.processing = false
	end
	if isoObject and isoObject.sync then
		isoObject:sync()
	end
	self:updateOnClient()
end

function ZS_SRecyclerGlobalObject:tick(deltaSeconds)
	logger:debug("tick() called")
	local isoObject = self:getIsoObject()
	if not isoObject then
		logger:debug("tick: no isoObject (cell not loaded?)")
		return
	end
	local square = self:getSquare()
	if not square then
		logger:debug("tick: no square")
		return
	end
	if not hasPowerAndConsume() then
		logger:warn("tick: no power (ZSpaceship.Power.getAmount < POWER_PER_MINUTE)")
		if self.processing then stopProcessing(self) end
		return
	end
	local recyclerCont = getRecyclerContainer(isoObject)
	local itemCount = recyclerCont and recyclerCont:getItems() and recyclerCont:getItems():size() or 0
	if not recyclerCont or itemCount == 0 then
		logger:debug("tick: no container or empty (itemCount=%s)", tostring(itemCount))
		if self.processing then stopProcessing(self) end
		return
	end

	local currentItem, weightKg = resolveCurrentItem(self, recyclerCont)
	if not currentItem then
		if itemCount > 0 then
			logger:info("No processable item in container (%d items, all unknown?), stopping.", itemCount)
		end
		if self.processing then stopProcessing(self) end
		return
	end

	local organic = isOrganic(currentItem)
	local biomassCont = getBiomassContainerForOrganic(currentItem, square)
	if organic and not biomassCont then
		logger:info("Organic item '%s' but no biomass container with room, waiting.",
			currentItem.getDisplayName and currentItem:getDisplayName() or currentItem:getType() or "?")
		if self.processing then stopProcessing(self) end
		return
	end

	if startOrContinueItem(self, currentItem, weightKg, organic, deltaSeconds) then
		self:updateOnClient()
		return
	end

	local consumed = resolveConsumedAfterNestedTransfer(recyclerCont, self.processingItemId)
	if not consumed then
		logger:warn("Item no longer in container.")
		stopProcessing(self)
		return
	end
	recyclerCont:DoRemoveItem(consumed)
	dispatchConsumed(consumed, organic, biomassCont, square)
	finishTick(self, recyclerCont, isoObject)
end
