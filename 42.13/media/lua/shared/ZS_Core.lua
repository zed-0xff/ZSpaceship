ZSpaceship = ZSpaceship or {}

ZSpaceship.ZOMBIE_OUTFIT_ID = "ZSpaceship_SpaceSuit"  -- defined in clothing.xml
ZSpaceship.SPACE_SUIT_ID    = "ZSpaceship.SpaceSuitA" -- prefer using tags instead

-- gets the space suit, not any suit
function ZSpaceship.getWornSuit(player)
    local wornItems = player:getWornItems()
    for i = 0, wornItems:size() - 1 do
        local item = wornItems:getItemByIndex(i)
        if item and item:getFullType() == ZSpaceship.SPACE_SUIT_ID then
            return item
        end
    end
    return nil
end
