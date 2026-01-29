--Events.OnDoTileBuilding2.Add(function(player, bRender, x, y, z, square)
--    print("[d] OnDoTileBuilding2", player, bRender, x, y, z, square)
--end)

Events.OnDoTileBuilding3.Add(function(player, bRender, x, y, z)
    print("[d] OnDoTileBuilding3 ", player, bRender, x, y, z)
end)

Events.OnSeeNewRoom.Add(function(room)
    print("[d] OnSeeNewRoom ", room)
end)
