class MapCompiler
  module CorridorHandler
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
      
      # Group tiles by z-level
      tiles_by_z = tiles.group_by { |t| t[2] }
      
      tiles_by_z.each do |z, z_tiles|
        # Compute bounding box
        min_x = z_tiles.map { |t| t[0] }.min
        max_x = z_tiles.map { |t| t[0] }.max
        min_y = z_tiles.map { |t| t[1] }.min
        max_y = z_tiles.map { |t| t[1] }.max
        
        # Create room definition
        room_id = RoomID.makeID(@cell_x, @cell_y, @room_index)
        @room_index += 1
        
        room = RoomDef.new(room_id, room_name)
        room.level = z
        
        rect = Rect.new
        rect.x = min_x
        rect.y = min_y
        rect.w = max_x - min_x + 1
        rect.h = max_y - min_y + 1
        room.rects << rect
        
        # Calculate room center
        center_x = min_x + (max_x - min_x) / 2.0
        center_y = min_y + (max_y - min_y) / 2.0
        room_data = { x: center_x.round, y: center_y.round, z: z, name: room_name }
        
        # Add to all rooms (for MapData.DefaultRooms) but NOT to spawn points
        @all_rooms << room_data
        
        @header.rooms[room_id] = room
        
        # Add room to the single spaceship building
        @spaceship_building.rooms << room
        room.building = @spaceship_building
      end
    end
    
    def place_corridor(abs_x, abs_y, z, direction)
      config = @auto_corridors
      
      # Place floor
      if config['floor']
        # Resolve alias for corridor floor
        actual_floor = resolve_tile_alias(config['floor'])
        tile_params = get_tile_params(actual_floor)
        replaces = tile_params['replaces'] || []
        set_square_tiles(abs_x, abs_y, z, [actual_floor], replaces: replaces, floor_tiles: [actual_floor])
      end
      
      # Place roof
      if config['roof']
        # Resolve alias for corridor roof
        actual_roof = resolve_tile_alias(config['roof'])
        tile_params = get_tile_params(actual_roof)
        replaces = tile_params['replaces'] || []
        set_square_tiles(abs_x, abs_y, z + 1, [actual_roof], replaces: replaces)
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
        
        # Resolve aliases to actual tile names
        tiles = tiles.map { |t| resolve_tile_alias(t) }
        
        # Get replaces from tile params for all tiles
        replaces = []
        floor_tiles_list = []
        tiles.each do |tile_name|
          tile_params = get_tile_params(tile_name)
          if tile_params['replaces']
            replaces = (replaces + tile_params['replaces']).uniq
          end
          # Track if this tile is a floor tile
          floor_tiles_list << tile_name if @floor_tiles_set.include?(tile_name)
        end
        
        ox, oy = wall_offsets[wall_key]
        wall_x, wall_y = abs_x + ox, abs_y + oy
        set_square_tiles(wall_x, wall_y, z, tiles, replaces: replaces, floor_tiles: floor_tiles_list)
        
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
