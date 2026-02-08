class MapCompiler
  class Square
    attr_accessor :x, :y, :z
    attr_accessor :wallN, :wallW, :floor
    attr_accessor :tiles, :bits
    attr_accessor :is_interior, :is_defined
    
    def initialize(x, y, z)
      @x = x
      @y = y
      @z = z
      @tiles = []
      @bits = 0
      @is_interior = false
      @is_defined = false
      @wallN = false
      @wallW = false
      @floor = nil
    end

    def resolve_conflict(cur_tile, new_tile)
      return new_tile if cur_tile.nil?
      return cur_tile if new_tile.equal?(cur_tile)
      return new_tile if new_tile.replaces?(cur_tile)
      return cur_tile if cur_tile.replaces?(new_tile)

      raise "Conflict resolution failed for #{cur_tile.inspect} and #{new_tile.inspect}"
    end
    
    def add_tile(tile)
      raise ArgumentError, "tile must be a Tile object" unless tile.is_a?(MapCompiler::Tile)

      if tile.floor?
        old_floor = @floor
        @floor = resolve_conflict(@floor, tile)
        # Remove the losing floor from @tiles so it doesn't leak as a non-floor tile
        if old_floor && @floor.name != old_floor.name
          @tiles.reject! { |t| t.name == old_floor.name }
        end
      end

      # Remove any existing tiles that this new tile replaces
      @tiles.reject! { |t| tile.replaces?(t) } if tile.needs_replacement?

      @tiles << tile unless @tiles.any? { |t| t.name == tile.name }
    end
    
    def add_tiles(tile_list)
      tile_list.each { |t| add_tile(t) }
    end
    
    def set_wall_north
      @wallN = true
    end
    
    def set_wall_west
      @wallW = true
    end
    
    def key
      [@x, @y, @z]
    end
    
    def has_floor?
      @floor || @tiles.any? { |t| t.floor? }
    end
    
    def has_wall?
      @wallN || @wallW || @bits != 0
    end
    
    def has_tiles?
      !@tiles.empty?
    end
    
    def get_floor_tiles
      if @floor
        name = @floor.is_a?(MapCompiler::Tile) ? @floor.name : @floor
        floor_tile = MapCompiler::Tile.new(name)
        floor_tile.set_floor
        [floor_tile]
      else
        @tiles.select { |t| t.floor? }
      end
    end
    
    def get_non_floor_tiles
      floor_names = get_floor_tiles.map(&:name)
      @tiles.reject { |t| floor_names.include?(t.name) }
    end
    
    def valid?
      # A square is valid if it has tiles or is marked as defined
      has_tiles? || @is_defined
    end
    
    def to_s
      "Square(#{@x}, #{@y}, #{@z})"
    end
  end
end
