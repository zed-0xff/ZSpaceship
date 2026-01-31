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
  end
end
