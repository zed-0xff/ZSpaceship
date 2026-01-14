class POTChunkData
  attr_reader :chunkDim, :chunksPerCell, :cellDim, :pot, :x, :y, :chunks

  include BetterInspect

  FILE_VERSION = 1

  def initialize(x, y, pot)
    @chunkDim = pot ? 8 : 10
    @chunksPerCell = pot ? 32 : 30
    @cellDim = pot ? 256 : 300
    @pot = pot
    @x = x
    @y = y
    @chunks = Array.new(@chunksPerCell * @chunksPerCell) { Chunk.new(self) }
  end

  def setSquareBits(abs_x, abs_y, bits)
    lx = abs_x % @cellDim
    ly = abs_y % @cellDim
    cx = lx / @chunkDim
    cy = ly / @chunkDim
    sq_x = lx % @chunkDim
    sq_y = ly % @chunkDim
    
    chunk = @chunks[cx + (cy * @chunksPerCell)]
    chunk.set_bits(sq_x, sq_y, bits)
  end

  def save(fname)
    File.open(fname, "wb") do |f|
      f.write([FILE_VERSION].pack("s>"))
      @chunks.each { |c| c.save(f) }
    end
  end

  def load(fname)
    File.open(fname, "rb") do |f|
      version = f.read(2).unpack1("s>")
      raise "unsupported version #{version}" if version != FILE_VERSION

      @chunksPerCell.times do |y|
        @chunksPerCell.times do |x|
          @chunks[x + (y * @chunksPerCell)].load(f)
        end
      end

      pos = f.pos
      tail = f.read(0x100)
      if tail && !tail.empty?
        puts "[?] extra #{f.size - f.pos} bytes at end of file:"
        ZHexdump.dump(tail, add: pos)
        puts
      end
    end
  end

  class Chunk
    attr_reader :parent, :nSqrs, :counts, :bits, :invalid

    BIT_SOLID      = 1
    BIT_WALLN      = 2
    BIT_WALLW      = 4
    BIT_WATER      = 8
    BIT_ROOM       = 0x10
    BIT_WILDERNESS = 0x20 # ?

    def self.bit2ascii b
      return "++" if (b & BIT_WALLN != 0) && (b & BIT_WALLW != 0)

      case b
      when 0
        "  "
      when BIT_SOLID
        "##"
      when BIT_WATER
        "~~"
      when BIT_ROOM
        "rr"
      when BIT_WILDERNESS
        ".."
      when BIT_ROOM | BIT_SOLID
        "RR"
      when BIT_WALLN, (BIT_WALLN | BIT_ROOM)
        "--"
      when (BIT_WALLN | BIT_SOLID), (BIT_WALLN | BIT_SOLID | BIT_ROOM)
        "=="
      when BIT_WALLW, (BIT_WALLW | BIT_ROOM)
        "| "
      when (BIT_WALLW | BIT_SOLID), (BIT_WALLW | BIT_SOLID | BIT_ROOM)
        "||"
      else
        "%02x" % b
      end
    end

    EMPTY_CHUNK      = 0
    SOLID_CHUNK      = 1
    REGULAR_CHUNK    = 2
    WATER_CHUNK      = 3
    ROOM_CHUNK       = 4
    WILDERNESS_CHUNK = 5
    NUM_CHUNK_TYPES  = 6

    include BetterInspect

    def initialize(parent)
      @parent = parent
      @nSqrs = parent.chunkDim * parent.chunkDim
      @counts = [0] * NUM_CHUNK_TYPES
      @counts[0] = @nSqrs
      @invalid = false
    end

    def empty?
      @counts[EMPTY_CHUNK] == @nSqrs && @counts[1..-1].all? { |c| c == 0 }
    end

    def invalid?
      @invalid
    end

    def load(f)
      @counts = [0] * NUM_CHUNK_TYPES
      type = f.read(1).unpack1("C")
      if type == EMPTY_CHUNK || type == SOLID_CHUNK || type == WATER_CHUNK || type == ROOM_CHUNK || type == WILDERNESS_CHUNK
        @counts[type] = @nSqrs
        return
      end

      if type != REGULAR_CHUNK
        $stderr.puts "[?] unknown chunk type #{type}"
        @invalid = true
        return
      end

      @bits = [0] * @nSqrs # TODO: optimize if needed
      @nSqrs.times do |i|
        @bits[i] = f.read(1).unpack1("C")
        type = getTypeOf(@bits[i])
        @counts[type] += 1
      end
    end

    def set_bits(lx, ly, bits)
      @bits ||= [0] * @nSqrs
      idx = lx + (ly * @parent.chunkDim)
      @bits[idx] = bits
      # Recalculate counts would be expensive here, maybe do it on save or just assume REGULAR
    end

    def save(f)
      # Determine if uniform
      if @bits.nil? || @bits.all? { |b| b == @bits[0] }
        val = @bits ? @bits[0] : 0
        type = getTypeOf(val)
        if type == REGULAR_CHUNK
          # Must save as regular if the bit combination isn't a pure uniform type
          f.write([REGULAR_CHUNK].pack("C"))
          bits_to_write = @bits || [0] * @nSqrs
          f.write(bits_to_write.pack("C*"))
        else
          f.write([type].pack("C"))
        end
      else
        f.write([REGULAR_CHUNK].pack("C"))
        f.write(@bits.pack("C*"))
      end
    end

    def parent_chunk_dim
      # This is a bit of a hack since parent isn't stored
      8 # Assuming POT for now
    end

    def getTypeOf(bits)
      case bits
      when 0
        EMPTY_CHUNK
      when BIT_SOLID
        SOLID_CHUNK
      when BIT_WATER
        WATER_CHUNK
      when BIT_ROOM
        ROOM_CHUNK
      when BIT_WILDERNESS
        WILDERNESS_CHUNK
      else
        REGULAR_CHUNK
      end
    end
  end
end
