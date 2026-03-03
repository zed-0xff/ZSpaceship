ZS_Recycler = ZS_Recycler or {}

ZS_Recycler.EFFICIENCY       = 0.5 -- percentage of original materials restored / weight converted to biomass
ZS_Recycler.KG_PER_MINUTE    = 2
ZS_Recycler.POWER_PER_MINUTE = 1
ZS_Recycler.SOUND_NAME       = "zs_recycler"
ZS_Recycler.Debug            = false

-- Items not in organic list are unknown; they are left in the input container.
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
