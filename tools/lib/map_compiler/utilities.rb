class MapCompiler
  module Utilities
    # Deep merge two hashes (right overrides left)
    def deep_merge(left, right)
      result = left.dup
      right.each do |key, right_val|
        if result.key?(key) && result[key].is_a?(Hash) && right_val.is_a?(Hash)
          result[key] = deep_merge(result[key], right_val)
        else
          result[key] = right_val
        end
      end
      result
    end
    
    # Convert local offsets to world coords (no transpose)
    def to_world(local_x, local_y)
      abs_x = @cell_x * MAP_SIZE + local_x
      abs_y = @cell_y * MAP_SIZE + local_y
      [abs_x, abs_y]
    end
    
    # Convert world coords to local offsets
    def from_world(abs_x, abs_y)
      local_x = abs_x - @cell_x * MAP_SIZE
      local_y = abs_y - @cell_y * MAP_SIZE
      [local_x, local_y]
    end
  end
end
