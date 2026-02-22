class MapCompiler
  module CorridorHandler
    # Process auto corridors between adjacent doors
    def process_auto_corridors
      return unless @auto_corridors['floor']
      
      puts "[AutoCorridor] Processing #{@placed_doors.length} doors"
      if @placed_doors.empty?
        puts "  [AutoCorridor] WARNING: No doors found! Check door character detection."
        return
      end
      @placed_doors.each { |d| puts "  Door at #{d[:x]},#{d[:y]} facing #{d[:facing]} (element: #{d[:element]})" }
      
      placed = Set.new
      corridor_tiles = []  # Track all corridor tiles for room creation
      max_gap = 2
      
      @placed_doors.each do |d1|
        @placed_doors.each do |d2|
          next if d1 == d2 || d1[:z] != d2[:z] || d1[:element] == d2[:element]
          
          gap_x, gap_y = d2[:x] - d1[:x], d2[:y] - d1[:y]
          
          # Same position: create a single corridor tile
          if gap_x == 0 && gap_y == 0
            if placed.add?([d1[:x], d1[:y], d1[:z]])
              # Determine corridor type based on door facings
              corridor_type = (d1[:facing] == :north || d1[:facing] == :south || d2[:facing] == :north || d2[:facing] == :south) ? "V" : "H"
              puts "  Corridor #{corridor_type} at #{d1[:x]},#{d1[:y]} (shared door position from #{d1[:element]} and #{d2[:element]})"
              place_corridor(d1[:x], d1[:y], d1[:z], corridor_type == "V" ? :vertical : :horizontal)
              corridor_tiles << [d1[:x], d1[:y], d1[:z]]
            end
          # Horizontal corridor: doors on same Y, within max_gap
          elsif gap_y == 0 && gap_x.abs <= max_gap
            # Create corridor tiles between the two doors (inclusive)
            start_x = [d1[:x], d2[:x]].min
            end_x = [d1[:x], d2[:x]].max
            (start_x..end_x).each do |x|
              if placed.add?([x, d1[:y], d1[:z]])
                puts "  Corridor H at #{x},#{d1[:y]} (doors at #{d1[:x]},#{d1[:y]} and #{d2[:x]},#{d2[:y]})"
                place_corridor(x, d1[:y], d1[:z], :horizontal)
                corridor_tiles << [x, d1[:y], d1[:z]]
              end
            end
          # Vertical corridor: doors on same X, within max_gap
          elsif gap_x == 0 && gap_y.abs <= max_gap
            # Create corridor tiles between the two doors (inclusive)
            start_y = [d1[:y], d2[:y]].min
            end_y = [d1[:y], d2[:y]].max
            (start_y..end_y).each do |y|
              if placed.add?([d1[:x], y, d1[:z]])
                puts "  Corridor V at #{d1[:x]},#{y} (doors at #{d1[:x]},#{d1[:y]} and #{d2[:x]},#{d2[:y]})"
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
        
        # Room center is the tile itself
        room_data = { x: abs_x, y: abs_y, z: z, name: room_name }
        
        # Add to all rooms (for MapData.DefaultRooms, but not spawnpoints)
        @all_rooms << room_data
        
        @header.rooms[room_id] = room
        
        # Add to the single spaceship building
        @root_building.rooms << room
        room.building = @root_building
      end
      
      puts "  Created #{tiles.uniq.length} corridor rooms '#{room_name}'"
    end
    
    def place_corridor(abs_x, abs_y, z, direction)
      config = @auto_corridors
      
      # Place floor
      if config['floor']
        # Validate and resolve alias for corridor floor
        actual_floor = validate_tile_defined(config['floor'])
        tile_params = get_tile_params(actual_floor)
        replaces = tile_params['replaces'] || []
        set_square_tiles(abs_x, abs_y, z, [actual_floor], replaces: replaces)
      end
      
      # Place roof
      if config['roof']
        # Validate and resolve alias for corridor roof
        actual_roof = validate_tile_defined(config['roof'])
        tile_params = get_tile_params(actual_roof)
        replaces = tile_params['replaces'] || []
        set_square_tiles(abs_x, abs_y, z + 1, [actual_roof], replaces: replaces)
        @header.maxLevel = [(@header.maxLevel || 0), z + 1].max
      end
      
      # Wall offsets: [x_offset, y_offset] - where to place the wall tiles
      # For horizontal corridors (E-W): walls on north and south sides
      # For vertical corridors (N-S): walls on west and east sides
      wall_offsets = {
        'north_wall' => [0, 1],   # north edge (y+1) - for horizontal corridors
        'south_wall' => [0, 0],   # south edge (y, same as corridor) - for horizontal corridors
        'west_wall'  => [0, 0],   # west edge (same as corridor) - for vertical corridors
        'east_wall'  => [1, 0]    # east edge (x+1) - for vertical corridors
      }
      
      # Only place relevant walls based on corridor direction
      # For horizontal (E-W) corridors: walls on north and south sides (use north_wall/south_wall configs with WallN tiles)
      # For vertical (N-S) corridors: walls on west and east sides (use west_wall/east_wall configs with WallW tiles)
      walls_to_place = direction == :horizontal ? ['north_wall', 'south_wall'] : ['west_wall', 'east_wall']
      
      walls_to_place.each do |wall_key|
        tiles = config[wall_key]
        next unless tiles
        
        tiles = [tiles] unless tiles.is_a?(Array)
        tiles = tiles.select { |t| t.is_a?(String) && !t.empty? }
        next if tiles.empty?
        
        # Validate and resolve aliases to actual tile names
        tiles = tiles.map { |t| validate_tile_defined(t) }
        
        # Get replaces from tile params for all tiles
        replaces = []
        tiles.each do |tile_name|
          tile_params = get_tile_params(tile_name)
          if tile_params['replaces']
            replaces = (replaces + tile_params['replaces']).uniq
          end
        end
        
        ox, oy = wall_offsets[wall_key]
        wall_x, wall_y = abs_x + ox, abs_y + oy
        set_square_tiles(wall_x, wall_y, z, tiles, replaces: replaces)
        
        # Track wall tiles for airtight wall lists
        # Only track the first tile (the actual wall tile, not decorative/lighting tiles)
        first_tile = tiles.first
        if first_tile && !first_tile.empty?
          # Determine direction from wall_key
          is_ns_wall = ['north_wall', 'south_wall'].include?(wall_key)
          is_ew_wall = ['east_wall', 'west_wall'].include?(wall_key)
          
          # Check if this is a door tile - if so, add to door lists instead of wall lists
          if @door_tiles.include?(first_tile)
            @door_tiles_ns.add(first_tile) if is_ns_wall
            @door_tiles_ew.add(first_tile) if is_ew_wall
          else
            # Add to wall lists (not a door)
            @wall_tiles_ns.add(first_tile) if is_ns_wall
            @wall_tiles_ew.add(first_tile) if is_ew_wall
          end
        end
      end
    end
  end
end
