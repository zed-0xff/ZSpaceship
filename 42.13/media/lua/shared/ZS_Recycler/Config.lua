ZS_Recycler = ZS_Recycler or {}

ZS_Recycler.EFFICIENCY       = 0.5 -- multiplier for biomass and for reverse_recipe ingredient return amounts
ZS_Recycler.KG_PER_MINUTE    = 2
ZS_Recycler.POWER_PER_MINUTE = 1
ZS_Recycler.SOUND_NAME       = "zs_recycler"

-- Reverse recipes: result fullType -> { recipeName -> { ingredientFullType = count } }. If item has a reverse recipe, recycler returns ingredients (× EFFICIENCY). Multiple recipes: pick random unless item modData has saved recipe.
ZS_Recycler.reverse_recipes  = {
	["Base.Bag_ClothSatchel_Denim"] = {
		["Base.SewClothSatchel"] = { ["Base.FabricRoll_DenimDarkBlue"] = 2 },
	},
	["Base.Trousers_Crafted_Burlap"] = {
		["Base.SewTrousers"] = { ["Base.BurlapPiece"] = 3 },
	},
	["Base.Shirt_NoSleeves_Crafted_DenimBlack"] = {
		["Base.SewShirtSleeveless"] = { ["Base.FabricRoll_DenimBlack"] = 2 },
	},
	["Base.Shirt_NoSleeves_Crafted_Cotton"] = {
		["Base.SewShirtSleeveless"] = { ["Base.FabricRoll_Cotton"] = 2 },
	},
}

-- Items not in organic list (and not in reverse_recipes, not scrapable placeable) are unknown; they are left in the input container.
ZS_Recycler.Items = {
    -- Organic: processed into biomass fluid.
    DisplayCategory = {
        Animal     = true,
        AnimalPart = true,
        Corpse     = true,
        Food       = true,
    },

    FullType = {
        ["LabItems.MatTaintedBlood"] = true,
    }
}
