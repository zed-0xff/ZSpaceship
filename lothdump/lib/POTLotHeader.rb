class POTLotHeader
  attr_reader :pot, :x, :y, :tilesUsed, :rooms, :buildings
  attr_accessor :version, :width, :height, :minLevel, :maxLevel

  include BetterInspect

  # cell's x, y
  def initialize(x, y, pot)
    @minLevel = -32
    @maxLevel = 31

    @rooms = {}
    @buildings = []
    @tilesUsed = []
    @indexToTile = {}

    @chunkDim = pot ? 8 : 10
    @chunksPerCell = pot ? 32 : 30
    @cellDim = pot ? 256 : 300
    @pot = pot
    @x = x
    @y = y
    @width = @chunkDim
    @height = @chunkDim
    @zombieDensity = [0] * (@chunksPerCell * @chunksPerCell)
  end

  def get_tile_index(name)
    @indexToTile[name] ||= begin
      @tilesUsed << name
      @tilesUsed.size - 1
    end
  end

  def save(fname)
    File.open(fname, "wb") do |f|
      f.write("LOTH")
      f.write([@version || 1].pack("L"))
      f.write([@tilesUsed.size].pack("L"))
      @tilesUsed.each { |t| f.puts(t) }
      f.write([@width, @height].pack("LL"))
      f.write([@minLevel, @maxLevel].pack("ll"))
      
      rooms_array = @rooms.values
      f.write([rooms_array.size].pack("L"))
      rooms_array.each_with_index do |room, idx|
        f.puts(room.name)
        f.write([room.level].pack("l"))
        f.write([room.rects.size].pack("L"))
        room.rects.each { |r| f.write([r.x - getMinSquareX, r.y - getMinSquareY, r.w, r.h].pack("l4")) }
        f.write([room.objects.size].pack("l"))
        room.objects.each do |obj|
          type_id = MetaObjectEnum.sym2id(obj.type) || 0
          f.write([type_id, obj.x - (@x * @cellDim), obj.y - (@y * @cellDim)].pack("l3"))
        end
      end
      
      f.write([@buildings.size].pack("l"))
      @buildings.each do |bld|
        f.write([bld.rooms.size].pack("l"))
        bld.rooms.each { |r| f.write([RoomID.getIndex(r.id)].pack("l")) }
      end
      
      f.write(@zombieDensity.pack("C*"))
    end
  end

  def getMinSquareX()
    @x * @cellDim
  end

  def getMinSquareY()
    @y * @cellDim
  end

  def get_tile_index(name)
    @indexToTile[name] ||= begin
      @tilesUsed << name
      @tilesUsed.size - 1
    end
  end

  def save(fname)
    File.open(fname, "wb") do |f|
      f.write("LOTH")
      f.write([@version || 1].pack("L"))
      f.write([@tilesUsed.size].pack("L"))
      @tilesUsed.each { |t| f.puts(t) }
      f.write([@width, @height].pack("LL"))
      f.write([@minLevel, @maxLevel].pack("ll"))
      
      rooms_array = @rooms.values
      f.write([rooms_array.size].pack("L"))
      rooms_array.each do |room|
        f.puts(room.name)
        f.write([room.level].pack("l"))
        f.write([room.rects.size].pack("L"))
        room.rects.each { |r| f.write([r.x - getMinSquareX, r.y - getMinSquareY, r.w, r.h].pack("l4")) }
        f.write([room.objects.size].pack("l"))
        room.objects.each do |obj|
          type_id = MetaObjectEnum.sym2id(obj.type) || 0
          f.write([type_id, obj.x - (@x * @cellDim), obj.y - (@y * @cellDim)].pack("l3"))
        end
      end
      
      f.write([@buildings.size].pack("l"))
      @buildings.each do |bld|
        f.write([bld.rooms.size].pack("l"))
        bld.rooms.each { |r| f.write([RoomID.getIndex(r.id)].pack("l")) }
      end
      
      # Zombie Intensity Map (Placeholder 0x400 bytes)
      f.write("\x00" * (@chunksPerCell * @chunksPerCell))
    end
  end

  def load(fname)
    File.open(fname, "rb") do |f|
      magic = f.read(4)
      if magic != "LOTH"
        puts "[?] unexpected magic #{magic.inspect}"
        return
      end

      @version = f.read(4).unpack1("L")
      puts "  Version: #{@version}"

      tile_count = f.read(4).unpack1("L")
      printf "  Tile count: %d (0x%X)\n", tile_count, tile_count
      tile_count.times do |i|
        name = f.gets.chomp
        printf "    Tile %03x: %s\n", i, name
        @tilesUsed << name
        @indexToTile[name] = i
      end
      #    tile_names = tile_count.times.map{ f.gets.chomp }
      #    p tile_names

      @width, @height = f.read(8).unpack("LL")
      puts "  Width: #{@width}, Height: #{@height}"

      @minLevel, @maxLevel = f.read(8).unpack("ll")
      puts "  minLevel: #{@minLevel}, maxLevel: #{@maxLevel}"

      numRooms = f.read(4).unpack1("L")
      puts "  Room count: #{numRooms}"

      puts
      numRooms.times do |room_idx|
        room_name = f.gets.chomp
        roomID = RoomID.makeID(@x, @y, room_idx)

        room = RoomDef.new(roomID, room_name)
        @rooms[room.id] = room
        printf "    room %3d: %-20s", room_idx, room.name

        room.level = f.read(4).unpack1("l")
        printf "lv %2d ", room.level

        room.rects = []
        nRect = f.read(4).unpack1("L")
        printf "nRect %2d: ", nRect
        nRect.times do |rect_idx|
          rect = Rect.read(f)
          room.rects << rect
          printf "%-40s", rect.to_s
        end
        nObjs = f.read(4).unpack1("l")
        printf " nObjs %d: ", nObjs
        nObjs.times do |obj_idx|
          e, x2, y2 = f.read(3*4).unpack("l*")
          obj = MetaObject.new(e, (x2 + (@x * @cellDim)) , (y2 + (@y * @cellDim)), room)
          room.objects << obj
          printf "%-30s", obj.inspect
        end
        puts
      end

      numBuildings = f.read(4).unpack1("l")
      printf "  numBuildings: %d\n", numBuildings

      numBuildings.times do |i|
        buildingDef = BuildingDef.new;
        buildingDef.id = BuildingID.makeID(@x, @y, i);

        numRooms2 = f.read(4).unpack1("l")
        numRooms2.times do |x3|
          roomIndex = f.read(4).unpack1("l")
          roomID2 = RoomID.makeID(@x, @y, roomIndex);
          roomDef2 = @rooms[roomID2]
          # roomDef2.building = buildingDef # XXX skip settings backrefs for now
          buildingDef.rooms << roomDef2
        end
        @buildings << buildingDef
      end

      pos = f.tell
      data = f.read(0x1000)
      if !data.empty? && data != "\x00" * 0x400
        puts
        printf "Zombie Intensity Map (%x bytes):\n", data.size
        ZHexdump.dump(data, add: pos, indent: 4)
      end
    end
    puts
  end
end

