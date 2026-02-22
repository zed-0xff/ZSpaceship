class MapCompiler
  module RoomBuilder
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
      
      # Add to all rooms (for MapData.DefaultRooms)
      @all_rooms << room_data
      
      # Add to spawn points only if not a corridor (exclude corridors from spawnpoints)
      corridor_name = @auto_corridors['name'] || 'hall'
      if name != corridor_name
        @spawnpoints['unemployed'] ||= []
        @spawnpoints['unemployed'] << [room_data[:x], room_data[:y], room_data[:z]]
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
      @root_building.rooms << room
      room.building = @root_building
      
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
    
    # Detect interior cells using explicit boundaries
    # Returns Set of [x, y] coordinates that are inside the boundaries
    def detect_interior_cells(lines, boundaries)
      return Set.new if lines.empty?
      
      height = lines.length
      width = lines.map { |l| l.length }.max || 0
      return Set.new if width == 0
      
      # Trivially small maps (1x1) - treat all cells as interior (for corridors)
      if width == 1 && height == 1
        return Set.new([[0, 0]])
      end
      
      # Find boundary positions
      top_left = nil
      bottom_right = nil
      
      lines.each_with_index do |line, ly|
        line.chars.each_with_index do |char, lx|
          boundary_type = boundaries[char]
          case boundary_type
          when 'TopLeft'
            top_left = [lx, ly]
          when 'BottomRight'
            bottom_right = [lx, ly]
          end
        end
      end
      
      # If we have corner boundaries, use them to define the interior rectangle
      if top_left && bottom_right
        # Interior is all cells between top_left and bottom_right (exclusive of boundaries)
        min_x = [top_left[0], bottom_right[0]].min
        max_x = [top_left[0], bottom_right[0]].max
        min_y = [top_left[1], bottom_right[1]].min
        max_y = [top_left[1], bottom_right[1]].max
        
        interior = Set.new
        (min_y + 1).upto(max_y - 1) do |ly|
          (min_x + 1).upto(max_x - 1) do |lx|
            interior.add([lx, ly])
          end
        end
        return interior
      end
      
      # Fallback: if no boundaries found, return empty set
      Set.new
    end
  end
end
