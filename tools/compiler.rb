#!/usr/bin/env ruby
# encoding: utf-8
require 'yaml'
require 'fileutils'
require 'optparse'
require 'set'

Dir[File.join(File.dirname(__FILE__), "lib", "*.rb")].each do |libf|
  load libf
end

# --- Compiler Logic ---

class MapCompiler
  MAP_SIZE = 256

  def initialize(yaml_path)
    @config = YAML.safe_load(File.read(yaml_path, encoding: "utf-8"), permitted_classes: [Symbol])
    @cell_x, @cell_y = @config['origin']
    @default_floor = @config['default_floor']
    
    @elements = @config['elements'] || {}
    @metapalette = @config['metapalette'] || {}
    @metamap = @config['metamap'] || ""
    @metamap_gap = @config['metamap_gap'] || 0 # Gap between elements (-1 = share walls)
    
    # Extract and merge defaults into all elements
    @defaults = @elements.delete('defaults') || {}
    @elements.each do |name, elem|
      @elements[name] = deep_merge(@defaults.dup, elem)
    end
    
    # Pre-calculate maxLevel based on elements with level and roof
    # Note: minLevel must always be 0 (or negative) for game's internal calculations
    max_level = 0
    @elements.each do |name, elem|
      level = elem['level'] || @defaults['level'] || 0
      max_level = [max_level, level].max
      if elem['roof']
        max_level = [max_level, level + 1].max
      end
    end
    
    @header = POTLotHeader.new(@cell_x, @cell_y, true)
    @header.minLevel = 0  # Always start from 0 for game compatibility
    @header.maxLevel = max_level  # Include default_level and any roofs above
    @pack = POTLotPack.new(@header)
    @cdata = POTChunkData.new(@cell_x, @cell_y, true)
    
    # Compute element sizes (use explicit width/height if present, otherwise derive from map)
    @element_sizes = {}
    @elements.each do |name, elem|
      lines = (elem['map'] || "").rstrip.split("\n")
      map_height = lines.length
      map_width = lines.map { |l| l.chars.length }.max || 0
      
      # Respect explicit width/height if present
      width = elem['width'] || map_width
      height = elem['height'] || map_height
      @element_sizes[name] = { width: width, height: height }
    end
    
    # Track replaced tiles per square - these are blocked from being added later
    @replaced_tiles = Hash.new { |h, k| h[k] = Set.new }
    
    # Room counter for unique IDs
    @room_index = 0
    @building_index = 0
    
    # Track special locations (teleporter, spawn points, etc.)
    @teleporter_coords = nil
    @room_spawn_points = []  # Track room centers for spawn points (excluding corridors)
    @all_rooms = []  # Track all room centers including halls (for MapData.Rooms)
    
    # Collect door sprites (first entry from each door definition)
    @door_sprites = Set.new
    # Track door tiles (first tile from each door definition) to exclude from wall tracking
    @door_tiles = Set.new
    # Track door tiles by direction (NS and EW) for door lookup tables
    @door_tiles_ns = Set.new
    @door_tiles_ew = Set.new
    
    # Auto corridors config and tracking
    @auto_corridors = @config['auto_corridors'] || {}
    @placed_doors = []  # Track door positions for auto-corridor generation
    @corridor_count = 0  # Counter for corridor instance IDs
    
    # Track wall tiles for airtight wall lists
    @wall_tiles_ns = Set.new  # North/South walls (getWall(true))
    @wall_tiles_ew = Set.new  # East/West walls (getWall(false))
    
    # Single building for the entire spaceship
    @spaceship_building = nil
  end

  def compile(out_dir)
    FileUtils.mkdir_p(out_dir)
    @defined_squares = {}
    
    # Create a single building for all rooms
    @spaceship_building = BuildingDef.new
    @spaceship_building.id = BuildingID.makeID(@cell_x, @cell_y, @building_index)
    @building_index += 1
    @header.buildings << @spaceship_building
    
    placements = parse_metamap
    
    placements.each do |placement|
      process_element_placement(placement)
    end
    
    # Generate auto corridors between adjacent doors
    process_auto_corridors if @auto_corridors['floor']
    
    set_default_floors_for_cell

    @header.save(File.join(out_dir, "#{@cell_x}_#{@cell_y}.lotheader"))
    @pack.save(File.join(out_dir, "world_#{@cell_x}_#{@cell_y}.lotpack"))
    @cdata.save(File.join(out_dir, "chunkdata_#{@cell_x}_#{@cell_y}.bin"))
    
    # Output map data Lua file
    save_map_data_lua(out_dir)
    
    # Output spawn points Lua file
    save_spawnpoints_lua(out_dir)
    
    # Output wall tile lists Lua file
    save_wall_tiles_lua(out_dir)
    
    puts "Compiled cell [#{@cell_x}, #{@cell_y}] to #{out_dir}"
  end
  
  def save_map_data_lua(out_dir)
    # Output to shared lua folder (relative to map output dir)
    # out_dir is like .../media/maps/ZSpaceship, we want .../media/lua/shared
    base_dir = File.dirname(File.dirname(out_dir))  # Go up from maps/ZSpaceship to media
    lua_dir = File.join(base_dir, "lua", "shared")
    FileUtils.mkdir_p(lua_dir)
    lua_path = File.join(lua_dir, "ZSpaceship_MapData.lua")
    
    lua_content = <<~LUA
      -- Auto-generated by compiler.rb - DO NOT EDIT
      -- Map data for ZSpaceship
      
      ZSpaceship = ZSpaceship or {}
      ZSpaceship.MapData = ZSpaceship.MapData or {}
      
      -- Cell coordinates
      ZSpaceship.MapData.CellX = #{@cell_x}
      ZSpaceship.MapData.CellY = #{@cell_y}
    LUA
    
    if @teleporter_coords
      lua_content += <<~LUA
        
        -- Teleporter location (center of teleport room)
        ZSpaceship.MapData.TeleporterX = #{@teleporter_coords[:x]}
        ZSpaceship.MapData.TeleporterY = #{@teleporter_coords[:y]}
        ZSpaceship.MapData.TeleporterZ = #{@teleporter_coords[:z]}
      LUA
    end
    
    if !@door_sprites.empty?
      sprites_lua = @door_sprites.to_a.map { |s| "  [\"#{s}\"] = true" }.join(",\n")
      lua_content += <<~LUA
        
        -- Door sprites (first entry from each door definition in YAML)
        ZSpaceship.MapData.DoorSprites = {
        #{sprites_lua}
        }
      LUA
    end
    
    if !@all_rooms.empty?
      rooms_lua = @all_rooms.map { |room| "  { x = #{room[:x]}, y = #{room[:y]}, z = #{room[:z]}, name = \"#{room[:name]}\" }" }.join(",\n")
      lua_content += <<~LUA
        
        -- Room centers (includes all rooms, including halls)
        ZSpaceship.MapData.Rooms = {
        #{rooms_lua}
        }
      LUA
    end
    
    File.write(lua_path, lua_content)
    puts "Wrote map data to #{lua_path}"
  end
  
  def save_spawnpoints_lua(out_dir)
    # Output to maps directory (same as out_dir)
    # out_dir is like .../media/maps/ZSpaceship
    spawnpoints_path = File.join(out_dir, "spawnpoints.lua")
    
    # Generate spawn points for each room center (excluding corridors)
    spawn_points = []
    @room_spawn_points.each do |spawn|
      spawn_points << "                  { posX = #{spawn[:x]}, posY = #{spawn[:y]}, posZ = #{spawn[:z]} }"
    end
    
    spawnpoints_list = spawn_points.join(",\n")
    
    spawnpoints_content = <<~LUA
      -- Auto-generated by compiler.rb - DO NOT EDIT
      function SpawnPoints()
          return {
              unemployed = {
      #{spawnpoints_list}
              }
          }
      end
    LUA
    
    File.write(spawnpoints_path, spawnpoints_content)
    puts "Wrote #{@room_spawn_points.length} spawn points to #{spawnpoints_path}"
  end
  
  def save_wall_tiles_lua(out_dir)
    # Output to client lua folder (relative to map output dir)
    # out_dir is like .../media/maps/ZSpaceship, we want .../media/lua/client
    base_dir = File.dirname(File.dirname(out_dir))  # Go up from maps/ZSpaceship to media
    lua_dir = File.join(base_dir, "lua", "client")
    FileUtils.mkdir_p(lua_dir)
    lua_path = File.join(lua_dir, "ZSpaceship_WallTiles.lua")
    
    # Sort tiles for consistent output (exclude door tiles from wall lists)
    ns_wall_tiles = (@wall_tiles_ns - @door_tiles_ns).to_a.sort
    ew_wall_tiles = (@wall_tiles_ew - @door_tiles_ew).to_a.sort
    ns_door_tiles = @door_tiles_ns.to_a.sort
    ew_door_tiles = @door_tiles_ew.to_a.sort
    
    # Generate lookup tables for faster validation
    ns_wall_lookup = ns_wall_tiles.uniq.sort.map { |t| "    [\"#{t}\"] = true" }.join(",\n")
    ew_wall_lookup = ew_wall_tiles.uniq.sort.map { |t| "    [\"#{t}\"] = true" }.join(",\n")
    ns_door_lookup = ns_door_tiles.uniq.sort.map { |t| "    [\"#{t}\"] = true" }.join(",\n")
    ew_door_lookup = ew_door_tiles.uniq.sort.map { |t| "    [\"#{t}\"] = true" }.join(",\n")
    
    lua_content = <<~LUA
      -- Auto-generated by compiler.rb - DO NOT EDIT
      -- Airtight wall tile lists for ZSpaceship
      -- This file is generated from the map YAML configuration
      
      ZSRoom = ZSRoom or {}
      
      -- Lookup tables for faster validation (O(1) instead of O(n))
      -- North/South walls (getWall(true))
      ZSRoom.AIRTIGHT_WALLS_NS_LOOKUP = {
      #{ns_wall_lookup}
      }
      
      -- East/West walls (getWall(false))
      ZSRoom.AIRTIGHT_WALLS_EW_LOOKUP = {
      #{ew_wall_lookup}
      }
      
      -- Door tiles (North/South direction)
      ZSRoom.AIRTIGHT_DOORS_NS_LOOKUP = {
      #{ns_door_lookup}
      }
      
      -- Door tiles (East/West direction)
      ZSRoom.AIRTIGHT_DOORS_EW_LOOKUP = {
      #{ew_door_lookup}
      }
    LUA
    
    File.write(lua_path, lua_content)
    puts "Wrote #{ns_wall_tiles.length} N/S wall tiles, #{ew_wall_tiles.length} E/W wall tiles, #{ns_door_tiles.length} N/S door tiles, and #{ew_door_tiles.length} E/W door tiles to #{lua_path}"
  end

  private
  
  # Deep merge two hashes (right overrides left)
  def deep_merge(left, right)
    result = left.dup
    right.each do |key, right_val|
      if result.key?(key) && result[key].is_a?(Hash) && right_val.is_a?(Hash)
        result[key] = deep_merge(result[key], right_val)
      else
        result[key] = right_val
      end
    end
    result
  end
  
  # Convert local offsets to world coords (no transpose)
  def to_world(local_x, local_y)
    abs_x = @cell_x * MAP_SIZE + local_x
    abs_y = @cell_y * MAP_SIZE + local_y
    [abs_x, abs_y]
  end
  
  def parse_metamap
    lines = @metamap.rstrip.split("\n")
    return [] if lines.empty?
    
    element_refs = []
    
    lines.each_with_index do |line, meta_y|
      line.chars.each_with_index do |char, meta_x|
        next if char == ' ' || char == "\t"
        element_name = @metapalette[char]
        next unless element_name && @elements[element_name]
        element_refs << {
          meta_x: meta_x,
          meta_y: meta_y,
          element_name: element_name
        }
      end
    end
    
    max_meta_x = element_refs.map { |r| r[:meta_x] }.max || 0
    
    # Column widths (for X positioning) - only consider room elements
    col_widths = Array.new(max_meta_x + 1, 0)
    element_refs.each do |ref|
      element = @elements[ref[:element_name]]
      next unless element['room']
      size = @element_sizes[ref[:element_name]]
      col_widths[ref[:meta_x]] = [col_widths[ref[:meta_x]], size[:width]].max
    end
    
    col_offsets = [0]
    col_widths.each_with_index { |w, i| col_offsets << col_offsets.last + w + (i < col_widths.length - 1 ? @metamap_gap : 0) }
    
    # Track each column's current bottom position (for vertical stacking)
    col_bottoms = Array.new(max_meta_x + 1, 0)
    
    # Process elements row by row
    instance_counts = Hash.new(0)
    placements = []
    
    element_refs.group_by { |ref| ref[:meta_y] }.sort.each do |meta_y, row_elements|
      # All elements in the same row start at the same Y (max col_bottom of columns in this row)
      row_cols = row_elements.map { |ref| ref[:meta_x] }
      row_start_y = row_cols.map { |col| col_bottoms[col] }.max
      
      row_elements.each do |ref|
        element = @elements[ref[:element_name]]
        size = @element_sizes[ref[:element_name]]
        col = ref[:meta_x]
        
        instance_counts[ref[:element_name]] += 1
        placements << {
          element_name: ref[:element_name],
          instance_id: instance_counts[ref[:element_name]],
          local_x: col_offsets[col],
          local_y: row_start_y
        }
        
        # Update column bottom (only room elements affect stacking)
        col_bottoms[col] = row_start_y + size[:height] + @metamap_gap if element['room']
      end
    end
    
    # Calculate total size and center everything
    total_width = col_offsets.last
    total_height = col_bottoms.max || 0
    center_offset_x = (MAP_SIZE - total_width) / 2
    center_offset_y = (MAP_SIZE - total_height) / 2
    
    placements.each do |p|
      p[:local_x] += center_offset_x
      p[:local_y] += center_offset_y
    end
    
    placements
  end
  
  def process_element_placement(placement)
    element_name = placement[:element_name]
    instance_id = placement[:instance_id] || 1
    element_instance = "#{element_name}##{instance_id}"  # Unique identifier for each placement
    base_local_x = placement[:local_x]
    base_local_y = placement[:local_y]
    
    # Support inline element definition (for auto-corridors) or lookup by name
    element = placement[:element] || @elements[element_name]
    return unless element
    
    # Merge defaults palette with element's palette (element overrides default)
    # Note: For named elements, defaults are already merged, but inline elements (corridors) need this
    raw_palette = deep_merge(@defaults['palette'] || {}, element['palette'] || {})
    palette, boundary_chars, door_chars, door_facings, door_offsets, wall_flags = flatten_palette(raw_palette)
    map_str = element['map'] || ""
    # Get level from element, fallback to defaults, then 0
    z = element['level'] || @defaults['level'] || 0
    
    # Room floor, roof, and name (defaults to element name)
    room_floor = element['floor']
    room_roof = element['roof']
    room_name = element['name'] || element_name
    should_create_room = element['room'] == true
    
    lines = map_str.rstrip.split("\n")
    
    # Detect interior cells (enclosed by walls/doors) using flood-fill
    interior_cells = detect_interior_cells(lines, boundary_chars) if should_create_room
    
    # Collect door positions for room metadata and auto-corridors
    door_positions = []
    lines.each_with_index do |line, ly|
      line.chars.each_with_index do |char, lx|
        if door_chars.include?(char)
          door_positions << { lx: lx, ly: ly, char: char }
          # Track for auto-corridors at character position (not sprite position)
          abs_x, abs_y = to_world(base_local_x + lx, base_local_y + ly)
          facing = door_facings[char] || :unknown
          @placed_doors << { x: abs_x, y: abs_y, z: z, facing: facing, char: char, element: element_instance }
        end
      end
    end
    
    # Create room definition if there are interior cells
    room = nil
    if interior_cells && !interior_cells.empty?
      room = create_room(room_name, interior_cells, base_local_x, base_local_y, z, door_positions, lines)
    end
    
    lines.each_with_index do |line, ly|
      line.chars.each_with_index do |char, lx|
        local_x = base_local_x + lx
        local_y = base_local_y + ly
        abs_x, abs_y = to_world(local_x, local_y)
        
        val = palette[char]
        
        # Place floor and roof on interior cells (enclosed by walls/doors)
        if interior_cells && interior_cells.include?([lx, ly])
          if room_floor
            set_square_tiles(abs_x, abs_y, z, [room_floor])
            @defined_squares[[abs_x, abs_y, z]] = true
          end
          if room_roof
            set_square_tiles(abs_x, abs_y, z + 1, [room_roof])
            @defined_squares[[abs_x, abs_y, z + 1]] = true
            @header.maxLevel = [(@header.maxLevel || 0), z + 1].max
          end
        end
        
        # Skip if no tile definition for this char
        next if val.nil?

        if val.is_a?(Hash) && (val.key?('tile') || val.key?('tiles') || val.key?('teleporter'))
          # Check for teleporter marker
          if val['teleporter']
            @teleporter_coords = { x: abs_x, y: abs_y, z: z }
            puts "Found teleporter at #{abs_x}, #{abs_y}, #{z}"
          end
          
          # Process tiles if present
          if val.key?('tile') || val.key?('tiles')
            process_offset_tile(val, local_x, local_y, z, char, wall_flags)
          end
          next
        end
        
        # If character has wall flags and val is a simple string/array, process it as a wall
        if char && wall_flags[char] && (val.is_a?(String) || val.is_a?(Array))
          # Convert simple string/array to hash format for process_offset_tile
          wall_def = val.is_a?(Array) ? { 'tiles' => val } : { 'tile' => val }
          process_offset_tile(wall_def, local_x, local_y, z, char, wall_flags)
          next
        end
        
        @defined_squares[[abs_x, abs_y, z]] = true

        tiles = val.is_a?(Array) ? val : [val]
        tiles = tiles.select { |t| t.is_a?(String) && !t.empty? && t != "WILDERNESS" }
        
        set_square_tiles(abs_x, abs_y, z, tiles)
      end
    end
  end
  
  # Process auto corridors between adjacent doors
  def process_auto_corridors
    return unless @auto_corridors['floor']
    
    puts "[AutoCorridor] #{@placed_doors.length} doors"
    @placed_doors.each { |d| puts "  #{d[:x]},#{d[:y]} #{d[:facing]} (#{d[:element]})" }
    
    placed = Set.new
    corridor_tiles = []  # Track all corridor tiles for room creation
    max_gap = 2
    
    @placed_doors.each do |d1|
      @placed_doors.each do |d2|
        next if d1 == d2 || d1[:z] != d2[:z] || d1[:element] == d2[:element]
        
        gap_x, gap_y = d2[:x] - d1[:x], d2[:y] - d1[:y]
        facings = [d1[:facing], d2[:facing]].sort
        
        # Horizontal corridor: east meets west
        if gap_y == 0 && gap_x.abs <= max_gap && facings == [:east, :west]
          ([d1[:x], d2[:x]].min..[d1[:x], d2[:x]].max).each do |x|
            if placed.add?([x, d1[:y], d1[:z]])
              puts "  Corridor H at #{x},#{d1[:y]}"
              place_corridor(x, d1[:y], d1[:z], :horizontal)
              corridor_tiles << [x, d1[:y], d1[:z]]
            end
          end
        end
        
        # Vertical corridor: south meets north
        if gap_x == 0 && gap_y.abs <= max_gap && facings == [:north, :south]
          ([d1[:y], d2[:y]].min..[d1[:y], d2[:y]].max).each do |y|
            if placed.add?([d1[:x], y, d1[:z]])
              puts "  Corridor V at #{d1[:x]},#{y}"
              place_corridor(d1[:x], y, d1[:z], :vertical)
              corridor_tiles << [d1[:x], y, d1[:z]]
            end
          end
        end
      end
    end
    
    # Create room definition for corridors
    create_corridor_rooms(corridor_tiles) unless corridor_tiles.empty?
  end
  
  def create_corridor_rooms(tiles)
    return if tiles.empty?
    
    room_name = @auto_corridors['name'] || 'hall'
    
    # Create a separate 1x1 room for each corridor tile
    tiles.uniq.each do |tile|
      abs_x, abs_y, z = tile
      
      room_id = RoomID.makeID(@cell_x, @cell_y, @room_index)
      @room_index += 1
      
      room = RoomDef.new(room_id, room_name)
      room.level = z
      
      # 1x1 room at this tile
      rect = Rect.new
      rect.x = abs_x
      rect.y = abs_y
      rect.w = 1
      rect.h = 1
      room.rects << rect
      
      # Add room center to all rooms (for MapData.Rooms, but not spawnpoints)
      @all_rooms << { x: abs_x, y: abs_y, z: z, name: room_name }
      
      @header.rooms[room_id] = room
      
      # Add to the single spaceship building
      @spaceship_building.rooms << room
      room.building = @spaceship_building
    end
    
    puts "  Created #{tiles.length} corridor rooms '#{room_name}'"
  end
  
  def place_corridor(abs_x, abs_y, z, direction)
    config = @auto_corridors
    
    # Place floor
    if config['floor']
      set_square_tiles(abs_x, abs_y, z, [config['floor']])
      @defined_squares[[abs_x, abs_y, z]] = true
    end
    
    # Place roof
    if config['roof']
      set_square_tiles(abs_x, abs_y, z + 1, [config['roof']])
      @defined_squares[[abs_x, abs_y, z + 1]] = true
      @header.maxLevel = [(@header.maxLevel || 0), z + 1].max
    end
    
    # Wall offsets: [x_offset, y_offset] - where to place the wall tiles
    wall_offsets = {
      'north_wall' => [0, 1],   # north edge (y+1)
      'south_wall' => [0, 0],   # south edge (no offset)
      'west_wall'  => [0, 0],   # west edge (no offset)
      'east_wall'  => [1, 0]    # east edge (x+1)
    }
    
    # Only place relevant walls based on corridor direction
    walls_to_place = direction == :horizontal ? ['north_wall', 'south_wall'] : ['west_wall', 'east_wall']
    
    walls_to_place.each do |wall_key|
      tiles = config[wall_key]
      next unless tiles
      
      tiles = [tiles] unless tiles.is_a?(Array)
      tiles = tiles.select { |t| t.is_a?(String) && !t.empty? }
      next if tiles.empty?
      
      ox, oy = wall_offsets[wall_key]
      wall_x, wall_y = abs_x + ox, abs_y + oy
      set_square_tiles(wall_x, wall_y, z, tiles)
      
      # Track wall tiles for airtight wall lists
      # Only track the first tile (the actual wall tile, not decorative/lighting tiles)
      # Check if this is a door tile - if so, add to door lists instead of wall lists
      # north_wall/south_wall = N/S walls (getWall(true))
      # east_wall/west_wall = E/W walls (getWall(false))
      first_tile = tiles.first
      if first_tile && !first_tile.empty?
        if @door_tiles.include?(first_tile)
          # Add to door lists based on direction
          if ['north_wall', 'south_wall'].include?(wall_key)
            @door_tiles_ns.add(first_tile)
          elsif ['east_wall', 'west_wall'].include?(wall_key)
            @door_tiles_ew.add(first_tile)
          end
        else
          # Add to wall lists (not a door)
          if ['north_wall', 'south_wall'].include?(wall_key)
            @wall_tiles_ns.add(first_tile)
          elsif ['east_wall', 'west_wall'].include?(wall_key)
            @wall_tiles_ew.add(first_tile)
          end
        end
      end
    end
  end
  
  # Convert world coordinates back to local (inverse of to_world)
  def from_world(abs_x, abs_y)
    local_x = abs_x - @cell_x * MAP_SIZE
    local_y = abs_y - @cell_y * MAP_SIZE
    [local_x, local_y]
  end
  
  
  # Create a room definition from interior cells
  def create_room(name, interior_cells, base_local_x, base_local_y, z, door_positions = [], lines = [])
    return nil if interior_cells.empty?
    
    room_id = RoomID.makeID(@cell_x, @cell_y, @room_index)
    @room_index += 1
    
    room = RoomDef.new(room_id, name)
    room.level = z
    
    # Convert interior cells to absolute coordinates and create rectangles
    # For simplicity, compute bounding box of all interior cells
    min_x = min_y = Float::INFINITY
    max_x = max_y = -Float::INFINITY
    
    interior_cells.each do |lx, ly|
      abs_x, abs_y = to_world(base_local_x + lx, base_local_y + ly)
      min_x = [min_x, abs_x].min
      max_x = [max_x, abs_x].max
      min_y = [min_y, abs_y].min
      max_y = [max_y, abs_y].max
    end
    
    # Create a single rectangle covering the bounding box
    rect = Rect.new
    rect.x = min_x
    rect.y = min_y
    rect.w = max_x - min_x + 1
    rect.h = max_y - min_y + 1
    room.rects << rect
    
    # Calculate room center
    center_x = min_x + (max_x - min_x) / 2.0
    center_y = min_y + (max_y - min_y) / 2.0
    room_data = { x: center_x.round, y: center_y.round, z: z, name: name }
    
    # Add to all rooms (for MapData.Rooms)
    @all_rooms << room_data
    
    # Add to spawn points only if not a corridor (exclude corridors from spawnpoints)
    corridor_name = @auto_corridors['name'] || 'hall'
    if name != corridor_name
      @room_spawn_points << room_data
    end
    
    # Add door objects
    door_positions.each do |door|
      abs_x, abs_y = to_world(base_local_x + door[:lx], base_local_y + door[:ly])
      door_type = determine_door_type(door[:lx], door[:ly], interior_cells, lines)
      
      obj = MetaObject.new(MetaObjectEnum.sym2id(door_type), abs_x, abs_y, room)
      room.objects << obj
    end
    
    @header.rooms[room_id] = room
    
    # Add room to the single spaceship building
    @spaceship_building.rooms << room
    room.building = @spaceship_building
    
    room
  end
  
  # Determine door direction based on adjacent interior cells
  def determine_door_type(door_lx, door_ly, interior_cells, lines)
    # Check which direction the interior is relative to the door
    # Interior to the south (ly+1) = door faces north (DoorN)
    # Interior to the north (ly-1) = door faces south (DoorS)
    # Interior to the east (lx+1) = door faces west (DoorW)
    # Interior to the west (lx-1) = door faces east (DoorE)
    
    if interior_cells.include?([door_lx, door_ly + 1])
      :DoorN
    elsif interior_cells.include?([door_lx, door_ly - 1])
      :DoorS
    elsif interior_cells.include?([door_lx + 1, door_ly])
      :DoorW
    elsif interior_cells.include?([door_lx - 1, door_ly])
      :DoorE
    else
      # Default based on wall orientation - check surrounding characters
      :DoorN
    end
  end
  
  # Detect interior cells using flood-fill from outside
  # Returns Set of [x, y] coordinates that are enclosed by walls/doors
  def detect_interior_cells(lines, boundary_chars)
    return Set.new if lines.empty?
    
    height = lines.length
    width = lines.map { |l| l.length }.max || 0
    return Set.new if width == 0
    
    # Trivially small maps (1x1) - treat all cells as interior (for corridors)
    if width == 1 && height == 1
      return Set.new([[0, 0]])
    end
    
    # Pad grid by 1 on each side to allow flood-fill from outside
    padded_width = width + 2
    padded_height = height + 2
    
    # Build grid: true = blocked (wall/door), false = open
    blocked = Array.new(padded_height) { Array.new(padded_width, false) }
    lines.each_with_index do |line, ly|
      line.chars.each_with_index do |char, lx|
        blocked[ly + 1][lx + 1] = boundary_chars.include?(char)
      end
    end
    
    # Flood-fill from (0,0) to find all exterior cells
    exterior = Set.new
    queue = [[0, 0]]
    exterior.add([0, 0])
    
    while !queue.empty?
      x, y = queue.shift
      [[0, 1], [0, -1], [1, 0], [-1, 0]].each do |dx, dy|
        nx, ny = x + dx, y + dy
        next if nx < 0 || nx >= padded_width || ny < 0 || ny >= padded_height
        next if blocked[ny][nx]
        next if exterior.include?([nx, ny])
        exterior.add([nx, ny])
        queue << [nx, ny]
      end
    end
    
    # Interior = cells that are not exterior and not blocked (in original coords)
    interior = Set.new
    height.times do |ly|
      width.times do |lx|
        padded_x, padded_y = lx + 1, ly + 1
        next if blocked[padded_y][padded_x]  # Skip walls/doors
        next if exterior.include?([padded_x, padded_y])  # Skip exterior
        interior.add([lx, ly])
      end
    end
    
    interior
  end
  
  # Flatten nested palette categories into a single char -> value hash
  # Also returns set of boundary characters (walls, doors) and door characters
  def flatten_palette(palette)
    flat = {}
    boundary_chars = Set.new
    door_chars = Set.new
    door_facings = {}  # char -> facing direction
    door_offsets = {}  # char -> [x_offset, y_offset]
    wall_flags = {}  # char -> :north or :west based on WallN/WallW flags
    
    # Extract wall flags from palette.flags
    flags = palette['flags'] || {}
    walln_chars = (flags['WallN'] || []).to_set
    wallw_chars = (flags['WallW'] || []).to_set
    
    # Extract door flags (DoorN, DoorS, DoorW, DoorE) - arrays containing characters and tile names
    door_flags = {
      'DoorN' => flags['DoorN'] || [],
      'DoorS' => flags['DoorS'] || [],
      'DoorW' => flags['DoorW'] || [],
      'DoorE' => flags['DoorE'] || []
    }
    
    # Process door flags: extract characters and open door sprites
    door_flags.each do |flag_name, flag_value|
      next unless flag_value.is_a?(Array) && !flag_value.empty?
      
      # Map flag name to facing direction
      facing_map = {
        'DoorN' => :north,
        'DoorS' => :south,
        'DoorW' => :west,
        'DoorE' => :east
      }
      facing = facing_map[flag_name]
      
      # Process each element in the door flag array
      flag_value.each_with_index do |item, index|
        next unless item.is_a?(String)
        
        # Check if it's a single character (door symbol) or a tile name
        if item.length == 1
          # It's a character - add to door_chars, boundary_chars, and set facing
          door_chars.add(item)
          boundary_chars.add(item)
          door_facings[item] = facing
        else
          # It's a tile name - if it's the last item, it's the open door sprite
          if index == flag_value.length - 1
            @door_sprites.add(item)
            @door_tiles.add(item)
            # Add to appropriate door lookup table based on direction
            if flag_name == 'DoorN' || flag_name == 'DoorS'
              @door_tiles_ns.add(item)
            elsif flag_name == 'DoorW' || flag_name == 'DoorE'
              @door_tiles_ew.add(item)
            end
          end
        end
      end
    end
    
    palette.each do |key, value|
      case key
      when 0..9
        key = key.to_s # Convert numeric keys to strings
      end

      if value.is_a?(Hash) && !value.key?('tile') && !value.key?('tiles')
        # It's a category (like 'walls', 'doors'), flatten its contents
        is_boundary = %w[walls doors].include?(key)
        is_door = key == 'doors'
        value.each do |k, v|
          flat[k] = v
          boundary_chars.add(k) if is_boundary
          if is_door
            door_chars.add(k)
            # Determine facing from definition (only if not already set from flags)
            door_facings[k] = infer_door_facing(k, v) unless door_facings.key?(k)
            # Track offset for corridor matching
            if v.is_a?(Hash)
              door_offsets[k] = [v['x'] || 0, v['y'] || 0]
            else
              door_offsets[k] = [0, 0]
            end
            # Collect first sprite from door definition
            if v.is_a?(Array) && v.first.is_a?(String)
              @door_sprites.add(v.first)
              @door_tiles.add(v.first)
            elsif v.is_a?(Hash) && v['tiles'].is_a?(Array) && v['tiles'].first.is_a?(String)
              @door_sprites.add(v['tiles'].first)
              @door_tiles.add(v['tiles'].first)
            elsif v.is_a?(Hash) && v['tile'].is_a?(String)
              @door_sprites.add(v['tile'])
              @door_tiles.add(v['tile'])
            end
          end
          
          # Check if this character has wall flags (can be in both)
          directions = []
          directions << :north if walln_chars.include?(k)
          directions << :west if wallw_chars.include?(k)
          wall_flags[k] = directions unless directions.empty?
        end
      else
        # Direct char -> tile mapping - NOT a boundary (only walls/doors categories are)
        flat[key] = value
        
        # Check if this character has wall flags (can be in both)
        directions = []
        directions << :north if walln_chars.include?(key)
        directions << :west if wallw_chars.include?(key)
        wall_flags[key] = directions unless directions.empty?
      end
    end
    [flat, boundary_chars, door_chars, door_facings, door_offsets, wall_flags]
  end
  
  # Infer door facing from its definition
  def infer_door_facing(char, definition)
    # 1. Explicit facing property
    if definition.is_a?(Hash) && definition['facing']
      return definition['facing'].to_sym
    end
    
    # 2. Infer from offset: y+1 = north, x+1 = west, no offset = south/east
    if definition.is_a?(Hash)
      y_offset = definition['y'] || 0
      x_offset = definition['x'] || 0
      return :north if y_offset > 0
      return :west if x_offset > 0
      # No offset means south (horizontal) or east (vertical) wall
      return :south if y_offset == 0 && x_offset == 0
    end
    
    # Array form without offset = south/east wall (default position)
    :south
  end
  
  def process_offset_tile(val, local_x, local_y, z, char = nil, wall_flags = {})
    # Support both 'tile' (single) and 'tiles' (array)
    tiles = val['tiles'] || [val['tile']]
    tiles = [tiles] unless tiles.is_a?(Array)
    tiles = tiles.compact
    
    replaces = val['replaces'] || []
    
    x_offset = val['x'] || 0
    y_offset = val['y'] || 0
    
    target_local_x = local_x + x_offset
    target_local_y = local_y + y_offset
    abs_x, abs_y = to_world(target_local_x, target_local_y)
    
    # Determine collision bits based on offset direction or wall flags
    bits = 0
    if char && wall_flags[char]
      # Use wall flags if available (can be an array of directions)
      directions = wall_flags[char]
      directions = [directions] unless directions.is_a?(Array)
      bits |= POTChunkData::Chunk::BIT_WALLN if directions.include?(:north)
      bits |= POTChunkData::Chunk::BIT_WALLW if directions.include?(:west)
    else
      # Fallback to offset-based detection
    bits |= POTChunkData::Chunk::BIT_WALLW if x_offset != 0
    bits |= POTChunkData::Chunk::BIT_WALLN if y_offset != 0
    end
    
    @cdata.setSquareBits(abs_x, abs_y, bits) if bits != 0
    set_square_tiles(abs_x, abs_y, z, tiles, replaces: replaces)
    @defined_squares[[abs_x, abs_y, z]] = true
    
    # Track wall tiles for airtight wall lists
    # Use wall flags if available, otherwise fallback to offset-based detection
    # Only track the first tile (the actual wall tile, not decorative/lighting tiles)
    # Include doors if they have wall flags or offsets (same logic as walls)
    if bits != 0 && !tiles.empty?  # Only track if it's actually a wall
      first_tile = tiles.first
      if first_tile.is_a?(String) && !first_tile.empty?
        # Determine wall direction from flags or offset
        is_ns_wall = false
        is_ew_wall = false
        
        if char && wall_flags[char]
          # wall_flags[char] can be an array of directions
          directions = wall_flags[char]
          directions = [directions] unless directions.is_a?(Array)
          is_ns_wall = directions.include?(:north)
          is_ew_wall = directions.include?(:west)
        else
          # Fallback to offset-based detection
          is_ns_wall = (y_offset != 0)
          is_ew_wall = (x_offset != 0)
        end
        
        # Check if this is a door tile - if so, add to door lists instead of wall lists
        if @door_tiles.include?(first_tile)
          # Add to door lists based on direction
          if is_ns_wall
            @door_tiles_ns.add(first_tile)
          end
          if is_ew_wall
            @door_tiles_ew.add(first_tile)
          end
        else
          # Add to wall lists (not a door)
          if is_ns_wall
            @wall_tiles_ns.add(first_tile)
          end
          if is_ew_wall
            @wall_tiles_ew.add(first_tile)
    end
        end
      end
    end
  end
  
  def set_square_tiles(abs_x, abs_y, z, new_tiles, replaces: [])
    key = [abs_x, abs_y, z]
    existing = @pack.getSquareData(abs_x, abs_y, z) || []
    
    # Track replaced tiles - they can't be added later
    replaces.each { |t| @replaced_tiles[key].add(t) }
    
    # Remove tiles that should be replaced
    existing = existing.reject { |t| @replaced_tiles[key].include?(t) }
    
    # Filter out new tiles that were previously replaced
    new_tiles = new_tiles.reject { |t| @replaced_tiles[key].include?(t) }
    
    all_tiles = (existing + new_tiles).uniq
    
    floor_tiles = all_tiles.select { |t| t && t.include?("floor") }
    non_floor_tiles = all_tiles.reject { |t| t && t.include?("floor") }
    
    if floor_tiles.empty?
      all_tiles = [@default_floor] + non_floor_tiles
    else
      all_tiles = floor_tiles + non_floor_tiles
    end
    
    @pack.set_square_data(abs_x, abs_y, z, all_tiles)
  end
  
  def set_default_floors_for_cell
    # Initialize squares at z=0 with default floor for any undefined squares
    # This ensures the game can access the base level
    MAP_SIZE.times do |x|
      MAP_SIZE.times do |y|
        abs_x = @cell_x * MAP_SIZE + x
        abs_y = @cell_y * MAP_SIZE + y
        
        next if @defined_squares[[abs_x, abs_y, 0]]
        
        # Initialize square at z=0 (game needs this for level calculations)
        @cdata.setSquareBits(abs_x, abs_y, 0)
        @pack.set_square_data(abs_x, abs_y, 0, [@default_floor])
        @defined_squares[[abs_x, abs_y, 0]] = true
      end
    end
  end
end

if __FILE__ == $0
  options = { output: "output_map" }

  OptionParser.new do |opts|
    opts.banner = "Usage: compiler.rb [options] <map.yaml>"

    opts.on("-o", "--output DIR", "Output directory (default: output_map)") do |o|
      options[:output] = o
    end

    opts.on("-h", "--help", "Prints this help") do
      puts opts
      exit
    end
  end.parse!

  yaml_path = ARGV[0]
  if yaml_path.nil? || !File.exist?(yaml_path)
    puts "Error: Map YAML file not found."
    puts "Usage: #{$0} [options] <map.yaml>"
    exit 1
  end

  compiler = MapCompiler.new(yaml_path)
  compiler.compile(options[:output])
end
