require "Items/Distributions"
require "Items/ProceduralDistributions"

ProceduralDistributions.list["zsSpaceStuff"] = {
    ignoreZombieDensity = true,
    rolls = 2,
    items = {
        "ZSpaceship.SpaceSuitA",         1,
        "ZSpaceship.Communicator_Left",  4,
        "ZSpaceCrate",                   1,
        "ZScienceSkill.BookScience1",    1,
        "ZScienceSkill.BookScience2",    0.5,
        "Base.LargeMeteorite",           0.01,
        "Base.Crowbar",                  3,
    },
}

local zsDistr = {
    zs_longhub = {
        crate = {
            procedural = true,
            procList = {
                {name="zsSpaceStuff",           min=0, max= 1, weightChance=10},
                {name="ArmyStorageElectronics", min=0, max=99, weightChance=50},
                {name="Chemistry",              min=0, max=99, weightChance=100},
                {name="CrateVHSTapes",          min=0, max= 4, weightChance=10},
                {name="EngineerTools",          min=0, max= 4, weightChance=60},
                {name="GarageMetalwork",        min=0, max=99, weightChance=100},
                {name="ScienceMisc",            min=0, max=99, weightChance=100},
                {name="TestingLab",             min=0, max=99, weightChance=100},
            },
            dontSpawnAmmo = true,
        },
    },

    zs_kitchen = {
        -- vanilla
        counter = {
            procedural = true,
            procList = {
                {name="KitchenBottles",    min=0, max=1, weightChance=40},
                {name="KitchenBaking",     min=0, max=1, weightChance=40},
                {name="KitchenBreakfast",  min=0, max=1, weightChance=80},
                {name="KitchenCannedFood", min=0, max=1, weightChance=100},
                {name="KitchenDishes",     min=0, max=1, weightChance=80},
                {name="KitchenDryFood",    min=0, max=1, weightChance=100},
                {name="KitchenPots",       min=0, max=1, weightChance=80},
                {name="KitchenRandom",     min=0, max=1, weightChance=20},
            },
        },
        -- vanilla
        overhead = {
            procedural = true,
            procList = {
                {name="KitchenBaking",     min=0, max=1, weightChance=40},
                {name="KitchenBottles",    min=0, max=1, weightChance=40},
                {name="KitchenBreakfast",  min=0, max=1, weightChance=80},
                {name="KitchenCannedFood", min=0, max=2, weightChance=100},
                {name="KitchenDishes",     min=1, max=1, weightChance=100},
                {name="KitchenDryFood",    min=0, max=4, weightChance=100},
            }
        },
        crate = {
            ignoreZombieDensity = true,
            rolls = 5,
            items = {
                "CannedBolognese",      40,
                "CannedChili",          40,
                "CannedCornedBeef",     40,
                "CannedCorn",           30,
                "CannedPeas",           30,
                "CannedCarrots2",       30,
                "CannedPeaches",        30,
                "CannedFruitCocktail",  30,
                "CannedMushroomSoup",   30,
                "CannedTomato2",        30,
                "CannedMilk",           20,
                "Cereal",               20,
                "Oatmeal",              20,
                "Pasta",                30,
                "Rice",                 30,
                "Flour",                15,
                "Sugar",                15,
                "WaterBottleFull",      40,
            },
        },
        freezer = {
            procedural = true,
            procList = {
                {name="FreezerFrozenFood", min=1, max=99, weightChance=100},
                {name="FreezerGeneric",    min=1, max=99, weightChance= 50},
                {name="SafehouseFreezer",  min=1, max=99, weightChance= 20},
            }
        },
    },

    zs_bedroom = {
        locker = {
            procedural = true,
            procList = {
                {name="zsSpaceStuff",        min=0, max= 1, weightChance=10},
                {name="MechanicShelfOutfit", min=0, max= 1, weightChance=10},
                {name="LaboratoryLockers",   min=0, max= 1, weightChance=10},
                {name="ArmyStorageOutfit",   min=0, max= 1, weightChance=10},
                {name="ArmyHangarOutfit",    min=0, max= 1, weightChance=10},
            },
            dontSpawnAmmo = true,
        },
    },

    zs_library = {
        crate = {
            procedural = true,
            procList = {
              {name="zsSpaceStuff",     min=0, max= 1, weightChance=10},
              {name="LibraryScience",   min=1, max= 5, weightChance=80},
              {name="LibraryBooks",     min=1, max= 5, weightChance=80},
              {name="LibraryMagazines", min=1, max= 5, weightChance=80},
              {name="CrateVHSTapes",    min=0, max=99, weightChance=30},
            },
        },
    },

    zs_teleport_room = {
        crate = {
            ignoreZombieDensity = true,
            rolls = 6,
            items = {
                "ZSpaceship.SpaceSuitA",        10,
                "ZSpaceship.Communicator_Left", 50,
                "Base.LargeMeteorite",           0.01,
            },
        },
    },

    zs_energy_storage = {
        crate = {
            ignoreZombieDensity = true,
            rolls = 10,
            items = {
                "Base.ElectricWire",     75,
                "Base.ElectronicsScrap", 20,
                "Base.SheetMetal",        5,
                "Base.CarBattery2",       1,
            },
        },
    },
}

table.insert(Distributions, zsDistr)
