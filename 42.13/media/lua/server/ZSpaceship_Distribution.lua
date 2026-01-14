require "Items/ProceduralDistributions"

local function prefillDistribution()
    if ProceduralDistributions and ProceduralDistributions.list then
        if ProceduralDistributions.list["ElectronicsStoreMisc"] then
            table.insert(ProceduralDistributions.list["ElectronicsStoreMisc"].items, "ZSpaceship.Communicator")
            table.insert(ProceduralDistributions.list["ElectronicsStoreMisc"].items, 0.1)
        end
        
        if ProceduralDistributions.list["SurvivalGear"] then
            table.insert(ProceduralDistributions.list["SurvivalGear"].items, "ZSpaceship.Teleporter")
            table.insert(ProceduralDistributions.list["SurvivalGear"].items, 0.05)
        end

        -- Add spaceship parts to industrial or electronics loot
        if ProceduralDistributions.list["ElectronicStoreAppliances"] then
            table.insert(ProceduralDistributions.list["ElectronicStoreAppliances"].items, "ZSpaceship.Spaceship_Battery")
            table.insert(ProceduralDistributions.list["ElectronicStoreAppliances"].items, 0.5)
            table.insert(ProceduralDistributions.list["ElectronicStoreAppliances"].items, "ZSpaceship.Spaceship_SolarPanel")
            table.insert(ProceduralDistributions.list["ElectronicStoreAppliances"].items, 0.5)
        end
    end
end

Events.OnInitGlobalModData.Add(prefillDistribution)
