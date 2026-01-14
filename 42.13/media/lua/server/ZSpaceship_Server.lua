-- ZSpaceship = ZSpaceship or {}

-- function ZSpaceship.RandomizeBrokenItems(container)
--     local items = container:getItems()
--     for i=0, items:size()-1 do
--         local item = items:get(i)
--         local type = item:getFullType()
        
--         -- 30% chance to be broken
--         if ZombRand(100) < 30 then
--             if type == "ZSpaceship.Spaceship_Battery" then
--                 container:AddItem("ZSpaceship.Spaceship_Battery_Broken")
--                 container:Remove(item)
--             elseif type == "ZSpaceship.Spaceship_SolarPanel" then
--                 container:AddItem("ZSpaceship.Spaceship_SolarPanel_Broken")
--                 container:Remove(item)
--             end
--         end
--     end
-- end
