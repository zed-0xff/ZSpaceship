class MapCompiler
  class Tile
    attr_accessor :name
    attr_accessor :replaces, :is_wall, :is_door, :is_floor, :facing
    attr_accessor :wall_direction, :is_decorative
    
    def initialize(name)
      @name = name
      @replaces = []
      @is_wall = false
      @is_door = false
      @is_floor = false
      @facing = nil
      @wall_direction = nil  # :north, :west, or both
      @is_decorative = false
    end
    
    def add_replace(tile_name)
      @replaces << tile_name unless @replaces.include?(tile_name)
    end
    
    def add_replaces(tile_names)
      tile_names.each { |t| add_replace(t) }
    end
    
    def set_wall(direction = nil)
      @is_wall = true
      @wall_direction = direction
    end
    
    def set_door(facing = nil)
      @is_door = true
      @facing = facing
    end
    
    def set_floor
      @is_floor = true
    end
    
    def floor?
      @is_floor
    end
    
    def wall?
      @is_wall
    end
    
    def door?
      @is_door
    end
    
    def structural?
      wall? || door? || floor?
    end
    
    def needs_replacement?
      !@replaces.empty?
    end

    def equal?(other)
      return false unless other.is_a?(MapCompiler::Tile)
      @name == other.name &&
        @replaces.sort == other.replaces.sort &&
        @is_wall == other.is_wall &&
        @is_door == other.is_door &&
        @is_floor == other.is_floor &&
        @facing == other.facing &&
        @wall_direction == other.wall_direction &&
        @is_decorative == other.is_decorative
    end
    
    def to_s
      type_str = []
      type_str << "wall" if wall?
      type_str << "door" if door?
      type_str << "floor" if floor?
      type_str = type_str.empty? ? "" : " [#{type_str.join(',')}]"
      "#{@name}#{type_str}"
    end
  end
end
