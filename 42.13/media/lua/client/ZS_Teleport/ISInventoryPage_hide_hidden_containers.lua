-- for hidden teleport buffer container when beaming items up.
-- in OnGameStart to hook CleanUI's copy of ISInventoryPage (meh)
Events.OnGameStart.Add(function()
    zbHook({
        ISInventoryPage = {
            addContainerButton = function(orig, self, container, ...)
                if container.getContainingItem then
                    local item = container:getContainingItem()
                    if item and item.isHidden and item:isHidden() then
                        return
                    end
                end

                return orig(self, container, ...)
            end
        }
    })
end)
