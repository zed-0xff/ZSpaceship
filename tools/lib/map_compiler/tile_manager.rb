class MapCompiler
  module TileManager
    def get_tile_params(tile_name)
      return {} unless tile_name && @tile_params
      @tile_params[tile_name] || {}
    end
    
    def set_square_tiles(abs_x, abs_y, z, new_tiles, replaces: [])
      key = [abs_x, abs_y, z]
      existing = @pack.getSquareData(abs_x, abs_y, z) || []
      
      # Track replaced tiles - they can't be added later
      replaces.each { |t| @replaced_tiles[key].add(t) }
      
      # Remove tiles that should be replaced (both from tracking and current replaces list)
      existing = existing.reject { |t| @replaced_tiles[key].include?(t) || replaces.include?(t) }
      
      # Filter out new tiles that were previously replaced or in current replaces list
      new_tiles = new_tiles.reject { |t| @replaced_tiles[key].include?(t) || replaces.include?(t) }
      
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
    
    def process_offset_tile(val, local_x, local_y, z, char = nil, wall_flags = {}, door_chars = Set.new, door_facings = {})
      # Support both 'tile' (single) and 'tiles' (array)
      tiles = val['tiles'] || [val['tile']]
      tiles = [tiles] unless tiles.is_a?(Array)
      tiles = tiles.select { |t| t.is_a?(String) && !t.empty? && t != "WILDERNESS" }
      return if tiles.empty?
      
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
      
      # Get replaces from tile params for all tiles
      replaces = []
      tiles.each do |tile_name|
        tile_params = get_tile_params(tile_name)
        if tile_params['replaces']
          replaces = (replaces + tile_params['replaces']).uniq
        end
      end
      
      set_square_tiles(abs_x, abs_y, z, tiles, replaces: replaces)
      @defined_squares[[abs_x, abs_y, z]] = true
      
      # Track wall/door tiles for airtight lists
      # Only track tiles that have wall flags or are door characters (actual walls/doors), not decorative/lighting tiles at offsets
      # Only track the first tile (the actual wall/door tile, not decorative/lighting tiles)
      if !tiles.empty?
        track_first_tile(tiles.first, char, wall_flags, door_chars, door_facings)
      end
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
end
