ZS_Shredder = ZS_Shredder or {}

ZS_Shredder.BIOMASS_COEFF    = 0.75
ZS_Shredder.KG_PER_MINUTE    = 2
ZS_Shredder.POWER_PER_MINUTE = 1
ZS_Shredder.SOUND_NAME       = "zs_shredder"
ZS_Shredder.Debug            = false

-- DisplayCategory entries set to true are treated as organic (processed into biomass fluid).
ZS_Shredder.Items = {
    -- means item:getDisplayCategory() returns one of the following strings.
    DisplayCategory = {
        Animal     = true,
        AnimalPart = true,
        Corpse     = true,
        Food       = true,
    }
}
