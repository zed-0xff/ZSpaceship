class MapCompiler
  module TileManager
    def get_tile_params(tile_name)
      return {} unless tile_name && @tile_params
      
      # Check exact match first
      return @tile_params[tile_name] if @tile_params[tile_name]
      
      # Check wildcard patterns
      if @wildcard_patterns
        @wildcard_patterns.each do |pattern_key, pattern_data|
          if pattern_data[:pattern].match?(tile_name)
            return pattern_data[:definition]
          end
        end
      end
      
      {}
    end
    
    # Resolve tile alias to actual tile name
    def resolve_tile_alias(tile_name)
      return tile_name unless tile_name && @tile_aliases
      @tile_aliases[tile_name] || tile_name
    end

    # Expand a replaces list to include both aliases and their resolved tile names
    def expand_replaces(replaces_list)
      replaces_list.flat_map { |t| [t, resolve_tile_alias(t)] }.uniq
    end
    
    # Validate that a tile is defined in tiles: section
    def validate_tile_defined(tile_name)
      resolved = resolve_tile_alias(tile_name)
      
      # Check exact match
      return resolved if @defined_tiles.include?(resolved)
      
      # Check wildcard patterns
      if @wildcard_patterns
        @wildcard_patterns.each do |pattern_key, pattern_data|
          if pattern_data[:pattern].match?(resolved)
            return resolved
          end
        end
      end
      
      raise "Tile '#{tile_name}' (resolved: '#{resolved}') is not defined in tiles: section"
    end
    
    # Get or create a Square object for the given coordinates
    def get_or_create_square(abs_x, abs_y, z)
      key = [abs_x, abs_y, z]
      @squares[key] ||= MapCompiler::Square.new(abs_x, abs_y, z)
    end
    
    def set_square_tiles(abs_x, abs_y, z, new_tiles, replaces: [])
      square = get_or_create_square(abs_x, abs_y, z)
      square.is_defined = true
      
      # Expand replaces to include both aliases and resolved actual tile names
      expanded_replaces = expand_replaces(replaces)
      
      # Track replaced tiles globally - they can't be added later
      key = [abs_x, abs_y, z]
      expanded_replaces.each { |t| @replaced_tiles[key].add(t) }
      
      # Validate and resolve aliases to actual tile names
      new_tiles = new_tiles.map { |t| validate_tile_defined(t) }
      
      # Filter out new tiles that were previously replaced or in current replaces list
      new_tiles = new_tiles.reject { |t| @replaced_tiles[key].include?(t) || expanded_replaces.include?(t) }
      
      # Create Tile objects with proper flags and replaces
      tile_objects = new_tiles.map do |tile_name|
        tile = MapCompiler::Tile.new(tile_name)
        
        # Get tile definition from tiles: section (check wildcards too)
        tile_def = @tile_definitions[tile_name] || get_tile_params(tile_name)
        
        # Set alias from tile definition
        if tile_def['alias']
          tile.alias = tile_def['alias']
        end
        
        # Get replaces from tile params, expanded to include resolved aliases
        tile_params = get_tile_params(tile_name)
        if tile_params['replaces']
          tile.add_replaces(expand_replaces(tile_params['replaces']))
        end
        
        # Also add expanded replaces passed as parameter (from local definition)
        tile.add_replaces(expanded_replaces) if !expanded_replaces.empty?
        
        # Apply flags from tile definition
        if tile_def['flags'] && tile_def['flags'].is_a?(Array)
          tile.set_floor if tile_def['flags'].include?('Floor')
          tile.set_wall if tile_def['flags'].include?('Wall')
          tile.set_door if tile_def['flags'].include?('Door')
        end
        
        # Floor flag is set from tile definition flags above
        # No need to check floor_tiles parameter since it was removed
        
        tile
      end
      
      # Add tiles to square
      square.add_tiles(tile_objects)
    end
    
    def process_offset_tile(val, local_x, local_y, z, char = nil, wall_flags = {}, door_chars = Set.new, door_facings = {})
      # Support both 'tile' (single) and 'tiles' (array)
      tiles = val['tiles'] || [val['tile']]
      tiles = [tiles] unless tiles.is_a?(Array)
      tiles = tiles.select { |t| t.is_a?(String) && !t.empty? && t != "WILDERNESS" }
      return if tiles.empty?
      
      # Validate and resolve aliases to actual tile names
      tiles = tiles.map { |t| validate_tile_defined(t) }
      
      x_offset = val['x'] || 0
      y_offset = val['y'] || 0
      target_local_x = local_x + x_offset
      target_local_y = local_y + y_offset
      abs_x, abs_y = to_world(target_local_x, target_local_y)
      
      square = get_or_create_square(abs_x, abs_y, z)
      square.is_defined = true
      
      # Determine collision bits based on offset direction or wall flags
      if char && wall_flags[char]
        # Use wall flags if available (can be an array of directions)
        directions = wall_flags[char]
        directions = [directions] unless directions.is_a?(Array)
        square.set_wall_north if directions.include?(:north)
        square.set_wall_west if directions.include?(:west)
      else
        # Fallback to offset-based detection
        square.set_wall_west if x_offset != 0
        square.set_wall_north if y_offset != 0
      end
      
      # Get replaces from tile params for all tiles (after alias resolution)
      replaces = []
      tiles.each do |tile_name|
        tile_params = get_tile_params(tile_name)
        if tile_params['replaces']
          replaces = (replaces + tile_params['replaces']).uniq
        end
      end
      
      set_square_tiles(abs_x, abs_y, z, tiles, replaces: replaces)
      
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
          
          square = get_or_create_square(abs_x, abs_y, 0)
          next if square.is_defined
          
          # Add default floor to undefined squares (validate and resolve alias first)
          actual_default_floor = validate_tile_defined(@default_floor)
          default_tile = MapCompiler::Tile.new(actual_default_floor)
          default_tile.set_floor
          square.add_tile(default_tile)
          square.floor = actual_default_floor
        end
      end
    end
    
    # Finalize all Square objects: convert to final output format
    def finalize_squares
      @squares.each do |key, square|
        abs_x, abs_y, z = square.x, square.y, square.z
        
        # Get existing tiles from pack (for squares that weren't fully replaced)
        existing = @pack.getSquareData(abs_x, abs_y, z) || []
        
        # Collect all replaces from all tiles in this square
        all_replaces = square.tiles.flat_map { |t| t.replaces }.uniq
        
        # Remove tiles that should be replaced (both from tracking and tile's replaces lists)
        existing = existing.reject { |t| @replaced_tiles[key].include?(t) || all_replaces.include?(t) }
        
        # Filter out square tiles that were previously replaced
        square_tile_names = square.tiles.map(&:name).reject { |t| @replaced_tiles[key].include?(t) || all_replaces.include?(t) }
        
        # Combine existing and new tiles
        all_tiles = (existing + square_tile_names).uniq
        
        # Ensure floor tiles are first, and add default floor if none present
        # Use Square's explicit floor tracking via Tile objects
        floor_tile_names = square.get_floor_tiles.map(&:name)
        non_floor_tile_names = square.get_non_floor_tiles.map(&:name)
        
        # Combine floor tiles from square with existing tiles (existing tiles are already filtered)
        # Note: We can't determine if existing tiles are floors without name parsing,
        # but we prioritize square's explicit floor tracking
        all_floor_tiles = floor_tile_names.dup
        all_non_floor_tiles = (non_floor_tile_names + existing).uniq.reject { |t| all_floor_tiles.include?(t) }
        
        if all_floor_tiles.empty?
          # Resolve alias for default floor
          actual_default_floor = resolve_tile_alias(@default_floor)
          all_tiles = [actual_default_floor] + all_non_floor_tiles
        else
          all_tiles = all_floor_tiles + all_non_floor_tiles
        end
        
        # Write to pack
        @pack.set_square_data(abs_x, abs_y, z, all_tiles)
        
        # Set collision bits if walls are present
        bits = square.bits
        bits |= POTChunkData::Chunk::BIT_WALLN if square.wallN
        bits |= POTChunkData::Chunk::BIT_WALLW if square.wallW
        @cdata.setSquareBits(abs_x, abs_y, bits) if bits != 0
      end
    end
    
    # Gather statistics about compiled squares and tiles
    def get_compilation_stats
      all_tile_names = @squares.values.flat_map { |sq| sq.tiles.map(&:name) }
      stats = {
        total_squares: @squares.length,
        defined_squares: @squares.values.count { |sq| sq.is_defined },
        squares_with_floor: @squares.values.count { |sq| sq.has_floor? },
        squares_with_walls: @squares.values.count { |sq| sq.has_wall? },
        total_tiles: @squares.values.sum { |sq| sq.tiles.length },
        unique_tiles: all_tile_names.uniq.length,
        squares_by_z: {}
      }
      
      # Count squares by z-level
      @squares.values.each do |sq|
        stats[:squares_by_z][sq.z] ||= 0
        stats[:squares_by_z][sq.z] += 1
      end
      
      stats
    end
  end
end
