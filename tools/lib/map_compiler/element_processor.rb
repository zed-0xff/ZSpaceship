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
      
      # Merge defaults palette with element's palette (element overrides default)
      # Note: For named elements, defaults are already merged, but inline elements (corridors) need this
      raw_palette = deep_merge(@defaults['palette'] || {}, element['palette'] || {})
      palette, boundary_chars, door_chars, door_facings, door_offsets, wall_flags, generator_chars = flatten_palette(raw_palette)
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
          
          # Track generator coordinates
          if generator_chars.include?(char)
            @generators << { x: abs_x, y: abs_y, z: z }
          end
          
          # Place floor and roof on interior cells (enclosed by walls/doors)
          if interior_cells && interior_cells.include?([lx, ly])
            if room_floor
              tile_params = get_tile_params(room_floor)
              replaces = tile_params['replaces'] || []
              set_square_tiles(abs_x, abs_y, z, [room_floor], replaces: replaces)
              @defined_squares[[abs_x, abs_y, z]] = true
            end
            if room_roof
              tile_params = get_tile_params(room_roof)
              replaces = tile_params['replaces'] || []
              set_square_tiles(abs_x, abs_y, z + 1, [room_roof], replaces: replaces)
              @defined_squares[[abs_x, abs_y, z + 1]] = true
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
              @defined_squares[[abs_x, abs_y, z]] = true
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
          
          @defined_squares[[abs_x, abs_y, z]] = true

          tiles = val.is_a?(Array) ? val : [val]
          tiles = tiles.select { |t| t.is_a?(String) && !t.empty? && t != "WILDERNESS" }
          
          set_square_tiles(abs_x, abs_y, z, tiles)
        end
      end
    end
  end
end
