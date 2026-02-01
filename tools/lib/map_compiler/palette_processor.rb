class MapCompiler
  module PaletteProcessor
    def flatten_palette(palette)
      flat = {}
      boundary_chars = Set.new
      door_chars = Set.new
      door_facings = {}  # char -> facing direction
      door_offsets = {}  # char -> [x_offset, y_offset]
      wall_flags = {}  # char -> :north or :west based on WallN/WallW flags
      
      # Extract wall flags from palette.flags
      flags = palette['flags'] || {}
      walln_chars = Set.new
      wallw_chars = Set.new
      
      # Process WallN flag: extract characters and tile names
      if flags['WallN'] && flags['WallN'].is_a?(Array)
        flags['WallN'].each do |item|
          next unless item.is_a?(String)
          if item.length == 1
            # It's a character - add to walln_chars
            walln_chars.add(item)
          else
            # It's a tile name - add to wall tiles list
            @wall_tiles_ns.add(item)
          end
        end
      end
      
      # Process WallW flag: extract characters and tile names
      if flags['WallW'] && flags['WallW'].is_a?(Array)
        flags['WallW'].each do |item|
          next unless item.is_a?(String)
          if item.length == 1
            # It's a character - add to wallw_chars
            wallw_chars.add(item)
          else
            # It's a tile name - add to wall tiles list
            @wall_tiles_ew.add(item)
          end
        end
      end
      
      # Extract generator flag - array containing generator characters
      generator_chars = Set.new
      if flags['Generator'] && flags['Generator'].is_a?(Array)
        flags['Generator'].each do |item|
          generator_chars.add(item) if item.is_a?(String) && item.length == 1
        end
      end
      
      # Extract location characters from locations mapping (locations is at root level, not in palette)
      location_chars = Set.new
      # Note: locations will be passed separately, not from palette
      
      # Extract door flags (DoorN, DoorS, DoorW, DoorE) - arrays containing characters and tile names
      # Only include flags that are actually defined
      door_flags = {}
      ['DoorN', 'DoorS', 'DoorW', 'DoorE'].each do |flag_name|
        door_flags[flag_name] = flags[flag_name] if flags[flag_name]
      end
      
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
      
      # Palette is now flat - no categories like 'walls', 'doors', 'floors'
      palette.each do |key, value|
        case key
        when 0..9
          key = key.to_s # Convert numeric keys to strings
        end

        # Skip non-tile keys (like 'flags')
        next if key == 'flags'
        
        # Direct char -> tile mapping
        flat[key] = value
        
        # Extract first tile name from value to check if it has wall flags
        first_tile = nil
        if value.is_a?(String)
          first_tile = value
        elsif value.is_a?(Array)
          # Find first string tile name in array, or extract from hash structures
          value.each do |item|
            if item.is_a?(String)
              first_tile = item
              break
            elsif item.is_a?(Hash)
              first_tile = item['tile'] || (item['tiles'] && item['tiles'].first)
              break if first_tile
            end
          end
        elsif value.is_a?(Hash)
          first_tile = value['tile'] || (value['tiles'] && value['tiles'].first)
        end
        
        # Resolve alias if needed
        if first_tile && @tile_aliases && @tile_aliases[first_tile]
          first_tile = @tile_aliases[first_tile]
        end
        
        # Check if this character has wall flags (can be in both)
        directions = []
        directions << :north if walln_chars.include?(key)
        directions << :west if wallw_chars.include?(key)
        
        # Also check if the tile this character maps to has wall flags
        if first_tile && @tile_params && @tile_params[first_tile]
          tile_flags = @tile_params[first_tile]['flags'] || []
          # Handle both string and symbol flags
          directions << :north if tile_flags.include?('WallN') || tile_flags.include?(:WallN)
          directions << :west if tile_flags.include?('WallW') || tile_flags.include?(:WallW)
        end
        
        wall_flags[key] = directions unless directions.empty?
        
        # Add wall characters to boundary_chars (they enclose interior cells)
        if walln_chars.include?(key) || wallw_chars.include?(key) || !directions.empty?
          boundary_chars.add(key)
        end
        
        # Check if this character is a door (from flags)
        # Only check for flags that are actually defined
        is_door = false
        if flags['DoorN'] && flags['DoorN'].include?(key)
          door_chars.add(key)
          door_facings[key] = :north unless door_facings.key?(key)
          is_door = true
        elsif flags['DoorW'] && flags['DoorW'].include?(key)
          door_chars.add(key)
          door_facings[key] = :west unless door_facings.key?(key)
          is_door = true
        end
        # Note: DoorS and DoorE are not currently defined in the flags list
        
        # Also check if the tile this character maps to has door flags
        if !is_door && first_tile && @tile_params && @tile_params[first_tile]
          tile_flags = @tile_params[first_tile]['flags'] || []
          # Handle both string and symbol flags
          # Only check for flags that are actually defined (DoorN and DoorW)
          if tile_flags.include?('DoorN') || tile_flags.include?(:DoorN)
            door_chars.add(key)
            door_facings[key] = :north unless door_facings.key?(key)
            is_door = true
          elsif tile_flags.include?('DoorW') || tile_flags.include?(:DoorW)
            door_chars.add(key)
            door_facings[key] = :west unless door_facings.key?(key)
            is_door = true
          end
          # Note: DoorS and DoorE are not currently defined in the flags list
        end
        
        # Add doors to boundary_chars (they also enclose interior cells)
        if is_door
          boundary_chars.add(key)
        end
        
        # Track door offsets and sprites
        if door_chars.include?(key)
          if value.is_a?(Hash)
            door_offsets[key] = [value['x'] || 0, value['y'] || 0]
          else
            door_offsets[key] = [0, 0]
          end
          # Collect first sprite from door definition
          if value.is_a?(Array) && value.first.is_a?(String)
            @door_sprites.add(value.first)
            @door_tiles.add(value.first)
          elsif value.is_a?(Hash) && value['tiles'].is_a?(Array) && value['tiles'].first.is_a?(String)
            @door_sprites.add(value['tiles'].first)
            @door_tiles.add(value['tiles'].first)
          elsif value.is_a?(Hash) && value['tile'].is_a?(String)
            @door_sprites.add(value['tile'])
            @door_tiles.add(value['tile'])
          elsif value.is_a?(String)
            @door_sprites.add(value)
            @door_tiles.add(value)
          end
        end
      end
      [flat, boundary_chars, door_chars, door_facings, door_offsets, wall_flags, generator_chars, location_chars]
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
    
    # Helper: Track a door tile based on facing direction
    def track_door_tile(tile, facing, door_chars, door_facings)
      return unless tile.is_a?(String) && !tile.empty?
      
      facing = facing || :south
      is_ns_door = (facing == :north || facing == :south)
      is_ew_door = (facing == :east || facing == :west)
      
      @door_tiles.add(tile)
      @door_tiles_ns.add(tile) if is_ns_door
      @door_tiles_ew.add(tile) if is_ew_door
    end
    
    # Helper: Track a wall tile based on wall flags
    def track_wall_tile(tile, wall_flags, char)
      return unless tile.is_a?(String) && !tile.empty?
      return unless char && wall_flags[char]
      
      directions = wall_flags[char]
      directions = [directions] unless directions.is_a?(Array)
      is_ns_wall = directions.include?(:north)
      is_ew_wall = directions.include?(:west)
      
      # Check if this is a door tile - if so, add to door lists instead of wall lists
      if @door_tiles.include?(tile)
        @door_tiles_ns.add(tile) if is_ns_wall
        @door_tiles_ew.add(tile) if is_ew_wall
      else
        # Add to wall lists (not a door)
        @wall_tiles_ns.add(tile) if is_ns_wall
        @wall_tiles_ew.add(tile) if is_ew_wall
      end
    end
    
    # Helper: Track first tile as door or wall (unified logic)
    def track_first_tile(first_tile, char, wall_flags, door_chars, door_facings)
      return unless first_tile.is_a?(String) && !first_tile.empty?
      
      # Check if this is a door character
      if door_chars.include?(char)
        facing = door_facings[char] || :south
        track_door_tile(first_tile, facing, door_chars, door_facings)
      # Check if this is a wall character with wall flags
      elsif char && wall_flags[char]
        track_wall_tile(first_tile, wall_flags, char)
      end
    end
  end
end
