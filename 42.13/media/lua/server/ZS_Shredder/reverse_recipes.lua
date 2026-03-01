ZS_Shredder = ZS_Shredder or {}

ZS_Shredder.reverse_recipes = ZS_Shredder.reverse_recipes or {}

local tbl = ZS_Shredder.reverse_recipes

local function process_recipe(recipe)
    if recipe:getCategory() == "Packing" then return end

    local recipe_id = recipe:getScriptObjectFullType()
    if recipe_id == "Base.MakeJar" then return end
    if recipe_id == "Base.PutSeedsInPacket" then return end
--    print("recipe", recipe:getName())

    local outputs = recipe:getOutputs()
    for j = 0, outputs:size() - 1 do
        local output = outputs:get(j)
--        print("    ", "output", output)

        local res_items = output:getPossibleResultItems()
        for k = 0, res_items:size() - 1 do
            local res_item = res_items:get(k)
            local dst_item_id = res_item:getFullName()
--            print("    ", "", "res_item", dst_item_id)

            local patterns = output:getOutputMapper():getPatternForResult(res_item)
            for l = 0, patterns:size() - 1 do
                local pattern = patterns:get(l)
--                print("    ", "", "", "pattern", pattern, pattern:getFullName())

                local inputs = recipe:getInputs()
                for k = 0, inputs:size() - 1 do
                    local input = inputs:get(k)
                    if not input:isKeep() and input:canUseItem(pattern:getFullName()) then
                        local possible_inputs = input:getPossibleInputItems()
                        for l = 0, possible_inputs:size() - 1 do
                            local possible_input = possible_inputs:get(l)
                            if possible_input == pattern then
                                local amt = input:getAmount(l)
                                if amt > 1 and amt > output:getAmount() then
                                    local src_item_id = possible_input:getFullName()
--                                    print("    ", "", "idx", l, "amt", amt)
                                    tbl[dst_item_id] = tbl[dst_item_id] or {}
                                    tbl[dst_item_id][recipe_id] = tbl[dst_item_id][recipe_id] or {}
                                    tbl[dst_item_id][recipe_id][src_item_id] = amt
--                                    tbl[dst_item_id][recipe_id].category = recipe:getCategory()
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

local recipes = CraftRecipeManager.queryRecipes("*")
for i = 0, recipes:size() - 1 do
    process_recipe(recipes:get(i))
end
