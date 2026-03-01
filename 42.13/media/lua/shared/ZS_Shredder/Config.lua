ZS_Shredder = ZS_Shredder or {}

ZS_Shredder.BIOMASS_COEFF    = 0.75
ZS_Shredder.KG_PER_MINUTE    = 2
ZS_Shredder.POWER_PER_MINUTE = 1
ZS_Shredder.SOUND_NAME       = "zs_shredder"
ZS_Shredder.Debug            = false

-- Items not in organic list are unknown; they are left in the input container.
ZS_Shredder.Items = {
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
