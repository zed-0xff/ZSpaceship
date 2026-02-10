local EnergyStorage = {
    COMM_KEY               = "ZS_EnergyStorage",
    TOTAL_CAPACITY_KEY     = "ES_TOTAL_CAPACITY",
    CONTAINER_TYPE         = "BatteryBank", -- encoded in tile params
    MAX_BATTERIES_PER_RACK = 20,

    -- Car battery capacities, used by client and server
    BATTERIES = {
        ["Base.CarBattery1"] =  50,
        ["Base.CarBattery2"] = 100,
        ["Base.CarBattery3"] =  75,
    },

    BASE_SPRITE = "solarmod_tileset_01_0",
    OVERLAY_SPRITES = {
        solarmod_tileset_01_1 = { 1,  4},
        solarmod_tileset_01_2 = { 5,  8},
        solarmod_tileset_01_3 = { 9, 12},
        solarmod_tileset_01_4 = {13, 16},
        solarmod_tileset_01_5 = {17, 20},
    },
}

ZSpaceship = ZSpaceship or {}
ZSpaceship.EnergyStorage = EnergyStorage