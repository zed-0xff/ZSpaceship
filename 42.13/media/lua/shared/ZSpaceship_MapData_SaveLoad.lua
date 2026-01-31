-- ZSpaceship MapData Save/Load
-- Handles saving and loading room and generator coordinates from save file
-- This ensures old saves continue to work even after mod updates

ZSpaceship = ZSpaceship or {}
ZSpaceship.MapData = ZSpaceship.MapData or {}

-- Store default room data (from compiled map data)
local DEFAULT_ROOMS = nil
-- Store default generator data (from compiled map data)
local DEFAULT_GENERATORS = nil

-- Initialize default rooms from MapData.Default.Rooms (called after MapData is loaded)
local function initDefaultRooms()
    if DEFAULT_ROOMS == nil and ZSpaceship.MapData and ZSpaceship.MapData.Default and ZSpaceship.MapData.Default.Rooms then
        DEFAULT_ROOMS = {}
        for i, room in ipairs(ZSpaceship.MapData.Default.Rooms) do
            DEFAULT_ROOMS[i] = {
                x = room.x,
                y = room.y,
                z = room.z,
                name = room.name
            }
        end
    end
    return DEFAULT_ROOMS ~= nil
end

-- Initialize default generators from MapData.Default.Generators (called after MapData is loaded)
local function initDefaultGenerators()
    if DEFAULT_GENERATORS == nil and ZSpaceship.MapData and ZSpaceship.MapData.Default and ZSpaceship.MapData.Default.Generators then
        DEFAULT_GENERATORS = {}
        for i, gen in ipairs(ZSpaceship.MapData.Default.Generators) do
            DEFAULT_GENERATORS[i] = {
                x = gen.x,
                y = gen.y,
                z = gen.z
            }
        end
    end
    return DEFAULT_GENERATORS ~= nil
end

-- Helper: Copy room data from source to MapData.Rooms
local function fillMapDataRooms(sourceRooms)
    if not sourceRooms then
        return false
    end
    
    ZSpaceship.MapData.Rooms = {}
    for i, room in ipairs(sourceRooms) do
        ZSpaceship.MapData.Rooms[i] = {
            x = room.x,
            y = room.y,
            z = room.z,
            name = room.name
        }
    end
    return true
end

-- Helper: Copy generator data from source to MapData.Generators
local function fillMapDataGenerators(sourceGenerators)
    if not sourceGenerators then
        return false
    end
    
    ZSpaceship.MapData.Generators = {}
    for i, gen in ipairs(sourceGenerators) do
        ZSpaceship.MapData.Generators[i] = {
            x = gen.x,
            y = gen.y,
            z = gen.z
        }
    end
    return true
end

-- Load room data from save file or use defaults
-- Always populates MapData.Rooms
local function loadRoomData(isNewGame)
    -- Ensure MapData exists
    if not ZSpaceship.MapData then
        ZSpaceship.MapData = {}
    end
    
    -- Initialize defaults from Default.Rooms
    local hasDefaults = initDefaultRooms()
    
    if isNewGame then
        -- New game: fill MapData.Rooms from Default.Rooms
        if hasDefaults and DEFAULT_ROOMS then
            fillMapDataRooms(DEFAULT_ROOMS)
            print("ZSpaceship: Initialized room data for new game (" .. #ZSpaceship.MapData.Rooms .. " rooms)")
        elseif ZSpaceship.MapData.Default and ZSpaceship.MapData.Default.Rooms then
            -- Fallback: use Default.Rooms directly if DEFAULT_ROOMS not initialized
            fillMapDataRooms(ZSpaceship.MapData.Default.Rooms)
            print("ZSpaceship: Initialized room data for new game from Default.Rooms (" .. #ZSpaceship.MapData.Rooms .. " rooms)")
        end
        return
    end
    
    -- Existing game: try to load from save file
    if ModData and ModData.exists and ModData.get then
        local savedData = ModData.get("ZSpaceship_RoomData")
        if savedData and savedData.Rooms and #savedData.Rooms > 0 then
            -- Load saved room data into MapData.Rooms
            fillMapDataRooms(savedData.Rooms)
            print("ZSpaceship: Loaded room data from save file (" .. #ZSpaceship.MapData.Rooms .. " rooms)")
            return
        end
    end
    
    -- No saved data found: use defaults (for old saves that don't have saved data yet)
    if hasDefaults and DEFAULT_ROOMS then
        fillMapDataRooms(DEFAULT_ROOMS)
        print("ZSpaceship: Using default room data (no saved data found) (" .. #ZSpaceship.MapData.Rooms .. " rooms)")
    elseif ZSpaceship.MapData.Default and ZSpaceship.MapData.Default.Rooms then
        -- Fallback: use Default.Rooms directly
        fillMapDataRooms(ZSpaceship.MapData.Default.Rooms)
        print("ZSpaceship: Using Default.Rooms (no saved data found) (" .. #ZSpaceship.MapData.Rooms .. " rooms)")
    end
end

-- Load generator data from save file or use defaults
-- Always populates MapData.Generators
local function loadGeneratorData(isNewGame)
    -- Ensure MapData exists
    if not ZSpaceship.MapData then
        ZSpaceship.MapData = {}
    end
    
    -- Initialize defaults from Default.Generators
    local hasDefaults = initDefaultGenerators()
    
    if isNewGame then
        -- New game: fill MapData.Generators from Default.Generators
        if hasDefaults and DEFAULT_GENERATORS then
            fillMapDataGenerators(DEFAULT_GENERATORS)
            print("ZSpaceship: Initialized generator data for new game (" .. #ZSpaceship.MapData.Generators .. " generators)")
        elseif ZSpaceship.MapData.Default and ZSpaceship.MapData.Default.Generators then
            -- Fallback: use Default.Generators directly if DEFAULT_GENERATORS not initialized
            fillMapDataGenerators(ZSpaceship.MapData.Default.Generators)
            print("ZSpaceship: Initialized generator data for new game from Default.Generators (" .. #ZSpaceship.MapData.Generators .. " generators)")
        end
        return
    end
    
    -- Existing game: try to load from save file
    if ModData and ModData.exists and ModData.get then
        local savedData = ModData.get("ZSpaceship_RoomData")
        if savedData and savedData.Generators and #savedData.Generators > 0 then
            -- Load saved generator data into MapData.Generators
            fillMapDataGenerators(savedData.Generators)
            print("ZSpaceship: Loaded generator data from save file (" .. #ZSpaceship.MapData.Generators .. " generators)")
            return
        end
    end
    
    -- No saved data found: use defaults (for old saves that don't have saved data yet)
    if hasDefaults and DEFAULT_GENERATORS then
        fillMapDataGenerators(DEFAULT_GENERATORS)
        print("ZSpaceship: Using default generator data (no saved data found) (" .. #ZSpaceship.MapData.Generators .. " generators)")
    elseif ZSpaceship.MapData.Default and ZSpaceship.MapData.Default.Generators then
        -- Fallback: use Default.Generators directly
        fillMapDataGenerators(ZSpaceship.MapData.Default.Generators)
        print("ZSpaceship: Using Default.Generators (no saved data found) (" .. #ZSpaceship.MapData.Generators .. " generators)")
    end
end

-- Save room and generator data to save file
local function saveRoomData()
    if not ModData or not ModData.getOrCreate then
        return
    end
    
    local modData = ModData.getOrCreate("ZSpaceship_RoomData")
    if not modData then
        return
    end
    
    -- Save current room data
    modData.Rooms = {}
    if ZSpaceship.MapData.Rooms then
        for i, room in ipairs(ZSpaceship.MapData.Rooms) do
            modData.Rooms[i] = {
                x = room.x,
                y = room.y,
                z = room.z,
                name = room.name
            }
        end
    end
    
    -- Save current generator data
    modData.Generators = {}
    if ZSpaceship.MapData.Generators then
        for i, gen in ipairs(ZSpaceship.MapData.Generators) do
            modData.Generators[i] = {
                x = gen.x,
                y = gen.y,
                z = gen.z
            }
        end
    end
    
    print("ZSpaceship: Saved room and generator data to save file")
end

-- Initialize on game start
if Events and Events.OnInitGlobalModData then
    Events.OnInitGlobalModData.Add(function(isNewGame)
        loadRoomData(isNewGame)
        loadGeneratorData(isNewGame)
    end)
end

-- Fallback: also try to initialize on game start (in case OnInitGlobalModData fires before MapData loads)
if Events and Events.OnGameStart then
    Events.OnGameStart.Add(function()
        -- Ensure MapData.Rooms is populated if it's not already
        if not ZSpaceship.MapData.Rooms or #ZSpaceship.MapData.Rooms == 0 then
            -- Try to initialize defaults
            if not DEFAULT_ROOMS then
                initDefaultRooms()
            end
            
            -- Check if we have saved data
            local hasSavedData = false
            if ModData and ModData.exists and ModData.get and ModData.exists("ZSpaceship_RoomData") then
                local savedData = ModData.get("ZSpaceship_RoomData")
                if savedData and savedData.Rooms and #savedData.Rooms > 0 then
                    fillMapDataRooms(savedData.Rooms)
                    hasSavedData = true
                    print("ZSpaceship: Loaded room data from save file on GameStart (" .. #ZSpaceship.MapData.Rooms .. " rooms)")
                end
            end
            
            -- If no saved data, use defaults
            if not hasSavedData then
                if DEFAULT_ROOMS then
                    fillMapDataRooms(DEFAULT_ROOMS)
                    print("ZSpaceship: Initialized room data from defaults on GameStart (" .. #ZSpaceship.MapData.Rooms .. " rooms)")
                elseif ZSpaceship.MapData.Default and ZSpaceship.MapData.Default.Rooms then
                    fillMapDataRooms(ZSpaceship.MapData.Default.Rooms)
                    print("ZSpaceship: Initialized room data from Default.Rooms on GameStart (" .. #ZSpaceship.MapData.Rooms .. " rooms)")
                end
            end
        end
        
        -- Ensure MapData.Generators is populated if it's not already
        if not ZSpaceship.MapData.Generators or #ZSpaceship.MapData.Generators == 0 then
            -- Try to initialize defaults
            if not DEFAULT_GENERATORS then
                initDefaultGenerators()
            end
            
            -- Check if we have saved data
            local hasSavedData = false
            if ModData and ModData.exists and ModData.get and ModData.exists("ZSpaceship_RoomData") then
                local savedData = ModData.get("ZSpaceship_RoomData")
                if savedData and savedData.Generators and #savedData.Generators > 0 then
                    fillMapDataGenerators(savedData.Generators)
                    hasSavedData = true
                    print("ZSpaceship: Loaded generator data from save file on GameStart (" .. #ZSpaceship.MapData.Generators .. " generators)")
                end
            end
            
            -- If no saved data, use defaults
            if not hasSavedData then
                if DEFAULT_GENERATORS then
                    fillMapDataGenerators(DEFAULT_GENERATORS)
                    print("ZSpaceship: Initialized generator data from defaults on GameStart (" .. #ZSpaceship.MapData.Generators .. " generators)")
                elseif ZSpaceship.MapData.Default and ZSpaceship.MapData.Default.Generators then
                    fillMapDataGenerators(ZSpaceship.MapData.Default.Generators)
                    print("ZSpaceship: Initialized generator data from Default.Generators on GameStart (" .. #ZSpaceship.MapData.Generators .. " generators)")
                end
            end
        end
    end)
end

-- Save on game save (OnSave is triggered during save, OnPostSave is after)
if Events and Events.OnSave then
    Events.OnSave.Add(function()
        saveRoomData()
    end)
end
