class MapCompiler
  module ElementProcessor
    def process_element_placement(placement)
      element_name = placement[:element_name]
      instance_id = placement[:instance_id] || 1
      element_instance = "#{element_name}##{instance_id}"  # Unique identifier for each placement
      base_local_x = placement[:local_x]
      base_local_y = placement[:local_y]
      
      # Support inline element definition (for auto-corridors) or lookup by name
      element = placement[:element] || @elements[element_name]
      return unless element
      
      # Merge element-specific tiles with root-level tiles (element tiles override root tiles)
      element_tiles = element['tiles'] || {}
      original_tile_definitions = @tile_definitions.dup
      original_wildcard_patterns = @wildcard_patterns.dup
      
      if !element_tiles.empty?
        # Merge element tiles into tile definitions (element tiles override root tiles)
        element_tiles.each do |tile_name, definition|
          if tile_name.include?('*')
            # Wildcard pattern - store for pattern matching
            pattern = tile_name.gsub('*', '.*')
            wildcard_def = definition.is_a?(Hash) ? definition.dup : {}
            
            # Validate flags in wildcard definition
            if wildcard_def['flags'] && wildcard_def['flags'].is_a?(Array)
              validate_flags(wildcard_def['flags'], "element '#{element_name}' tile '#{tile_name}'")
            end
            
            @wildcard_patterns[tile_name] = {
              pattern: Regexp.new("^#{pattern}$"),
              definition: wildcard_def
            }
          elsif definition.is_a?(Hash)
            # Validate flags
            if definition['flags'] && definition['flags'].is_a?(Array)
              validate_flags(definition['flags'], "element '#{element_name}' tile '#{tile_name}'")
            end
            
            # Merge with existing definition if it exists
            existing = @tile_definitions[tile_name] || get_tile_params(tile_name)
            merged_def = existing.is_a?(Hash) ? existing.merge(definition) : definition
            @tile_definitions[tile_name] = merged_def
            @tile_params[tile_name] = merged_def.dup
            
            # Track aliases
            if merged_def['alias']
              alias_name = merged_def['alias']
              @tile_aliases[alias_name] = tile_name
            end
            
            # Track tiles with flags for export
            if merged_def['flags'] && merged_def['flags'].is_a?(Array) && !merged_def['flags'].empty?
              @tiles_with_flags[tile_name] = {
                flags: merged_def['flags'].dup
              }
            end
            
            # Add to defined tiles
            @defined_tiles.add(tile_name)
          else
            # Empty definition (just tile name) - still add to defined tiles
            @tile_params[tile_name] = {} unless @tile_params[tile_name]
            @tile_definitions[tile_name] = {} unless @tile_definitions[tile_name]
            @defined_tiles.add(tile_name)
          end
        end
      end
      
      # Merge defaults palette and boundaries with element's (element overrides default)
      # Note: For named elements, defaults are already merged, but inline elements (corridors) need this
      raw_palette = deep_merge(@defaults['palette'] || {}, element['palette'] || {})
      palette, boundary_chars, door_chars, door_facings, door_offsets, wall_flags, generator_chars, location_chars = flatten_palette(raw_palette)
      
      # Merge boundaries (element overrides defaults)
      boundaries = deep_merge(@defaults['boundaries'] || {}, element['boundaries'] || {})
      
      # Merge locations (element overrides defaults)
      element_locations = deep_merge(@root_locations || {}, element['locations'] || {})
      
      # Extract location characters from merged locations
      location_chars = Set.new
      if element_locations && element_locations.is_a?(Hash)
        element_locations.each do |char, location_type|
          location_chars.add(char) if char.is_a?(String) && char.length == 1
        end
      end
      map_str = element['map'] || ""
      # Get level from element, fallback to defaults, then 0
      z = element['level'] || @defaults['level'] || 0
      
      # Room floor, roof, and name (defaults to element name)
      room_floor = element['floor']
      room_roof = element['roof']
      room_name = element['name'] || element_name
      # Check room flag - if explicitly false, don't create room; otherwise create it
      # This handles defaults merge where room: true from defaults should make should_create_room true
      should_create_room = element['room'] != false
      
      lines = map_str.rstrip.split("\n")
      
      # Validate that all characters in the map are defined in the palette
      lines.each_with_index do |line, ly|
        line.chars.each_with_index do |char, lx|
          # Skip whitespace
          next if char == ' ' || char == "\t" || char == "\n" || char == "\r"
          
          unless palette.key?(char)
            raise "Undefined character '#{char}' found in map for element '#{element_name}' at line #{ly + 1}, column #{lx + 1}"
          end
        end
      end
      
      # Detect interior cells using explicit boundaries
      interior_cells = detect_interior_cells(lines, boundaries) if should_create_room
      
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
          
          # Track location coordinates by type (including generators)
          if location_chars.include?(char)
            location_type = element_locations && element_locations[char]
            if location_type
              @locations_by_type[location_type] << { x: abs_x, y: abs_y, z: z }
            end
          end
          
          # Place floor and roof on interior cells (enclosed by walls/doors)
          if interior_cells && interior_cells.include?([lx, ly])
            if room_floor
              # Resolve alias for room floor
              actual_floor = resolve_tile_alias(room_floor)
              tile_params = get_tile_params(actual_floor)
              replaces = tile_params['replaces'] || []
              set_square_tiles(abs_x, abs_y, z, [actual_floor], replaces: replaces)
            end
            if room_roof
              # Resolve alias for room roof
              actual_roof = resolve_tile_alias(room_roof)
              tile_params = get_tile_params(actual_roof)
              replaces = tile_params['replaces'] || []
              set_square_tiles(abs_x, abs_y, z + 1, [actual_roof], replaces: replaces)
              @header.maxLevel = [(@header.maxLevel || 0), z + 1].max
            end
          end
          
          # Skip if no tile definition for this char
          next if val.nil?

          # Support nested hash syntax: [tile1, tile2, ..., { offset, tiles }] - independent tiles
          if val.is_a?(Array)
            # Collect all string tiles for current position
            current_tiles = []
            offset_hashes = []
            
            val.each do |item|
              if item.is_a?(String)
                current_tiles << item
              elsif item.is_a?(Hash) && (item.key?('tile') || item.key?('tiles'))
                offset_hashes << item
              end
            end
            
            # Place tiles at current position if any
            if !current_tiles.empty?
              # Validate and resolve aliases to actual tile names
              current_tiles = current_tiles.map { |t| validate_tile_defined(t) }
              
              # Get replaces from tile params for all tiles
              replaces = []
              current_tiles.each do |tile_name|
                tile_params = get_tile_params(tile_name)
                if tile_params['replaces']
                  replaces = (replaces + tile_params['replaces']).uniq
                end
              end
              set_square_tiles(abs_x, abs_y, z, current_tiles, replaces: replaces)
              
              # Track first tile only (not decorative/lighting tiles)
              if !current_tiles.empty?
                track_first_tile(current_tiles.first, char, wall_flags, door_chars, door_facings)
              end
            end
            
            # Process offset tiles
            offset_hashes.each do |offset_hash|
              process_offset_tile(offset_hash, local_x, local_y, z, char, wall_flags, door_chars, door_facings)
            end
            
            next if !current_tiles.empty? || !offset_hashes.empty?
          end

          if val.is_a?(Hash) && (val.key?('tile') || val.key?('tiles'))
            # Process tiles if present
            if val.key?('tile') || val.key?('tiles')
              process_offset_tile(val, local_x, local_y, z, char, wall_flags, door_chars, door_facings)
            end
            next
          end
          
          # If character has wall flags and val is a simple string/array, process it as a wall
          if char && wall_flags[char] && (val.is_a?(String) || val.is_a?(Array))
            # Convert simple string/array to hash format for process_offset_tile
            wall_def = val.is_a?(Array) ? { 'tiles' => val } : { 'tile' => val }
            process_offset_tile(wall_def, local_x, local_y, z, char, wall_flags, door_chars, door_facings)
            next
          end

          tiles = val.is_a?(Array) ? val : [val]
          tiles = tiles.select { |t| t.is_a?(String) && !t.empty? && t != "WILDERNESS" }
          
          # Validate and resolve aliases to actual tile names
          tiles = tiles.map { |t| validate_tile_defined(t) }
          
          set_square_tiles(abs_x, abs_y, z, tiles)
        end
      end
      
      # Restore original tile definitions after processing this element
      if !element_tiles.empty?
        @tile_definitions = original_tile_definitions
        @wildcard_patterns = original_wildcard_patterns
        # Note: We keep @tile_params, @tile_aliases, and @defined_tiles updated
        # so element tiles remain available for subsequent elements
      end
    end
  end
end
