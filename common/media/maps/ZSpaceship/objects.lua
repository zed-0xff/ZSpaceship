objects = {
    -- NoPowerOrWater zone for the entire spaceship cell
    -- This disables grid electricity and piped water in the space area
    {
        name = "ZS_NoPowerOrWater",
        type = "NoPowerOrWater",
        x = 19968,  -- SpaceMinX (cell 78 * 256)
        y = 19968,  -- SpaceMinY (cell 78 * 256)
        z = 0,      -- Ground level (zone applies to all Z levels)
        width = 256,
        height = 256
    }
}

