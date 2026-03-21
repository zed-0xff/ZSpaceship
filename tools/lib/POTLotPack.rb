class POTLotPack
  attr_reader :lotHeader, :pot, :x, :y, :chunkDim, :chunksPerCell, :cellDim, :loadedChunks, :offsetInData

  include BetterInspect

  # pot = true for B42+, false for B41
  def initialize(lotHeader)
    @data = []

    @lotHeader     = lotHeader
    @pot           = lotHeader.pot
    @x             = lotHeader.x
    @y             = lotHeader.y

    @chunkDim      = @pot ?  8 : 10
    @chunksPerCell = @pot ? 32 : 30
    @cellDim       = @chunkDim * @chunksPerCell

    # @loadedChunks = [false] * (@chunksPerCell * @chunksPerCell) # unused
    @offsetInData  = [-1] * (@cellDim * @cellDim * ((lotHeader.maxLevel - lotHeader.minLevel) + 1))

    @version = @pot ? 1 : 0
  end

  def set_square_data(x, y, z, tiles)
    # x, y are absolute
    lx, ly = x % @cellDim, y % @cellDim
    squareXYZ = lx + (ly * @cellDim) + ((z - @lotHeader.minLevel) * @cellDim * @cellDim)
    @offsetInData[squareXYZ] = @data.size
    @data << tiles.size
    tiles.each { |t| @data << @lotHeader.get_tile_index(t) }
  end

  def save(fname)
    File.open(fname, "wb") do |f|
      if @version > 0
        f.write(LotHeader::LOTPACK_MAGIC)
        f.write([@version].pack("L"))
      end

      # Build 42 expects an extra 4 bytes here (chunkDim in squares, typically 8)
      # because IsoLot seeks to (8 + 4 + index*8) when version >= 1.
      f.write([@chunkDim].pack("L"))

      # Chunk Table: chunksPerCell*chunksPerCell entries, 8 bytes each.
      # IsoLot reads the first 4 bytes (int pos) and ignores the next 4 bytes.
      table_pos = f.tell
      f.write("\x00" * (@chunksPerCell * @chunksPerCell * 8))
      
      offsets = Array.new(@chunksPerCell * @chunksPerCell)
      @chunksPerCell.times do |cx|
        @chunksPerCell.times do |cy|
          idx = (cx * @chunksPerCell) + cy
          offsets[idx] = f.tell
          write_chunk_data(f, cx, cy)
        end
      end
      
      f.seek(table_pos)
      offsets.each do |o|
        # 8 bytes per entry: (int pos) + (int unused)
        f.write([o].pack("L<"))
        f.write([0].pack("L<"))
      end
    end
  end

  def write_chunk_data(f, cx, cy)
    # Simplest valid encoding: write a 4-byte count per square.
    # - count == 0 means empty square.
    # - count == N+1 means N tiles follow (plus one unused int), matching IsoLot.load().
    #
    # This avoids the tricky -1 skip encoding (which is inclusive in the reader).
    minZ = [@lotHeader.minLevel, -32].max
    maxZ = [@lotHeader.maxLevel, 31].min

    minZ.upto(maxZ) do |z|
      # Game reads tiles in X-outer, Y-inner order
      @chunkDim.times do |x|
      @chunkDim.times do |y|
          abs_x = (@x * @cellDim) + (cx * @chunkDim) + x
          abs_y = (@y * @cellDim) + (cy * @chunkDim) + y
          
          squareXYZ = (abs_x % @cellDim) + ((abs_y % @cellDim) * @cellDim) + ((z - @lotHeader.minLevel) * @cellDim * @cellDim)
          offset = @offsetInData[squareXYZ]
          
          if offset == -1 || offset.nil?
            f.write([0].pack("l")) # empty square
          else
            # Write tile data
            count = @data[offset]
            f.write([count + 1].pack("l"))
            f.write([0].pack("l")) # Dummy/Unused
            count.times do |i|
              f.write([@data[offset + 1 + i]].pack("l"))
            end
          end
        end
      end
    end
  end

  def load(fname)
    File.open(fname, "rb") do |f|
      @in = f
      @version = nil
      magic = f.read(4)
      if magic == LotHeader::LOTPACK_MAGIC
        @version = f.read(4).unpack1("L")
      else
        f.seek(0)
        @version = 0
      end

      puts "  Version: #{@version}"
      raise "unsupported version #{@version}" if @version != 0 && @version != 1

      @chunksPerCell.times do |chunkX|
        @chunksPerCell.times do |chunkY|
          loadChunk((@x * @chunksPerCell) + chunkX, (@y * @chunksPerCell) + chunkY)
        end
      end
    end
  end

  def loadChunk(chunkX, chunkY)
    skip = 0;
    lwx = chunkX - (@x * @chunksPerCell);
    lwy = chunkY - (@y * @chunksPerCell);
    index = (lwx * @chunksPerCell) + lwy;
    @in.seek((@version >= 1 ? 8 : 0) + 4 + (index * 8))
    pos = @in.read(4).unpack1("L")
    @in.seek(pos)

    minZ = [@lotHeader.minLevel, -32].max
    maxZ = [@lotHeader.maxLevel, 31].min
    maxZ-=1 if @version == 0

    minZ.upto(maxZ) do |z|
      @chunkDim.times do |x|
        @chunkDim.times do |y|
          squareXYZ = x + (y * @cellDim) + (lwx * @chunkDim) + (lwy * @chunkDim * @cellDim) + ((z - @lotHeader.minLevel) * @cellDim * @cellDim);
          @offsetInData[squareXYZ] = -1;
          if skip > 0
            skip -= 1
          else
            count = @in.read(4).unpack1("l")
            if count == -1
              skip = @in.read(4).unpack1("l")
              if skip > 0
                skip -= 1
              end
            elsif count > 0
              @offsetInData[squareXYZ] = @data.size();
              @data.append(count - 1);
              @in.read(4) # unused
              (count-1).times do
                tileIndex = @in.read(4).unpack1("l")
                @data.append(tileIndex)
              end
            end
          end
        end
      end
    end
  end

  def getSquareData(squareX, squareY, z)
    squareXYZ = (squareX - @lotHeader.getMinSquareX()) + ((squareY - @lotHeader.getMinSquareY()) * @cellDim) + ((z - @lotHeader.minLevel) * @cellDim * @cellDim);
    offset = @offsetInData[squareXYZ];
    return nil if offset == -1 || offset.nil?

    count = @data[offset];
    result = [nil] * count
  
    count.times do |i|
      result[i] = @lotHeader.tilesUsed[@data[offset + 1 + i]];
    end

    result
  end
end

