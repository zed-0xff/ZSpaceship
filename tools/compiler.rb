#!/usr/bin/env ruby
# encoding: utf-8
require 'yaml'
require 'fileutils'
require 'optparse'
require 'set'

Dir[File.join(File.dirname(__FILE__), "lib", "*.rb")].each do |libf|
  load libf
end

# --- Compiler Logic ---

class MapCompiler
  def initialize(yaml_path)
    @config = YAML.safe_load(File.read(yaml_path, encoding: "utf-8"))
    @cell_x, @cell_y = @config['map']['origin']
    
    @header = POTLotHeader.new(@cell_x, @cell_y, true)
    @pack = POTLotPack.new(@header)
    @cdata = POTChunkData.new(@cell_x, @cell_y, true)
    
    @palette = @config['palette']
    resolve_palette_references
  end

  def compile(out_dir)
    FileUtils.mkdir_p(out_dir)
    
    # Set levels from config
    @header.minLevel = 0
    @header.maxLevel = (@config['map']['levels'] || 1) - 1

    # Track which squares we've explicitly defined
    @defined_squares = {}
    
    @config['grid'].each do |level_key, chunks|
      z = level_key.split('_').last.to_i
      chunks.each do |chunk_key, grid_str|
        # Parse chunk_X_Y from YAML
        # User wants: chunk_4_5 below chunk_4_4 (same X, higher Y)
        # In setSquareBits: cx = lx / chunkDim (column/X), cy = ly / chunkDim (row/Y)
        # So for chunk_4_5 to be below: cx=4 (same column), cy=5 (next row)
        # YAML chunk_X_Y: first number is X (cx), second is Y (cy)
        nums = chunk_key.scan(/\d+/).map(&:to_i)
        cx, cy = nums[0], nums[1]  # YAML: chunk_X_Y means cx=X, cy=Y
        process_chunk(cx, cy, z, grid_str)
      end
    end
    
    # Set default floor for all squares in the cell that weren't explicitly defined
    # This ensures the blending system can access floors on all squares
    set_default_floors_for_cell

    @header.save(File.join(out_dir, "#{@cell_x}_#{@cell_y}.lotheader"))
    @pack.save(File.join(out_dir, "world_#{@cell_x}_#{@cell_y}.lotpack"))
    @cdata.save(File.join(out_dir, "chunkdata_#{@cell_x}_#{@cell_y}.bin"))
    
    puts "Compiled cell [#{@cell_x}, #{@cell_y}] to #{out_dir}"
  end

  private
  
  def append_square_tile(x, y, z, new_tile)
    # Get existing tiles at this position
    existing = @pack.getSquareData(x, y, z) || []
    # Append the new tile (avoid duplicates)
    all_tiles = existing + [new_tile]
    all_tiles = all_tiles.uniq  # Remove duplicates
    @pack.set_square_data(x, y, z, all_tiles)
  end
  
  def resolve_palette_references
    # Resolve symbol references: if a palette value is a string that matches
    # another palette key, replace it with that key's value (recursively)
    @palette.each do |key, value|
      if value.is_a?(String) && @palette.key?(value)
        @palette[key] = resolve_reference(value)
      elsif value.is_a?(Array)
        @palette[key] = value.map do |v|
          if v.is_a?(String) && @palette.key?(v)
            resolve_reference(v)
          else
            v
          end
        end
      end
    end
  end
  
  def resolve_reference(symbol, visited = Set.new)
    # Prevent infinite loops
    return @palette[symbol] if visited.include?(symbol)
    visited.add(symbol)
    
    value = @palette[symbol]
    if value.is_a?(String) && @palette.key?(value)
      resolve_reference(value, visited)
    else
      value
    end
  end
  
  def process_chunk(cx, cy, z, grid_str)
    lines = grid_str.strip.split("\n")
    
    # Process grid directly without transposition
    # YAML row index → game Y, YAML column index → game X
    lines.each_with_index do |line, ly|
      # Unicode-aware character iteration
      line.chars.each_with_index do |char, lx|
        val = @palette[char]
        
        # If character is not in palette, treat as interior cell with default floor
        if val.nil?
          val = "floors_exterior_street_01_17"
        end
        
        # Support for offset-based wall syntax:
        # { "tile": "tile_name", "x": +1 } - place west wall on the cell to the right
        # { "tile": "tile_name", "y": +1 } - place north wall on the cell below
        # { "tile": "tile_name" } - place tile at current position (no wall bits, regular tile)
        if val.is_a?(Hash) && val.key?('tile')
          wall_tile = val['tile']
          default_floor = "floors_exterior_street_01_17"
          has_offset = false
          
          # Handle x offset: place west wall on the cell to the right
          if val.key?('x') && val['x'] != 0
            has_offset = true
            target_lx = lx + val['x']
            target_ly = ly
            
            # Check bounds
            if target_lx >= 0 && target_lx < (lines.map(&:length).max || 0)
              abs_x = @cell_x * 256 + cx * 8 + target_lx
              abs_y = @cell_y * 256 + cy * 8 + target_ly
              # Set wall on west edge
              bits = POTChunkData::Chunk::BIT_WALLW
              @cdata.setSquareBits(abs_x, abs_y, bits)
              # Get existing tiles and append wall tile
              existing = @pack.getSquareData(abs_x, abs_y, z) || []
              all_tiles = existing + [wall_tile]
              all_tiles = all_tiles.uniq
              # Ensure floor exists
              if !all_tiles.any? { |t| t && t.include?("floor") }
                all_tiles.unshift(default_floor)
              end
              # Ensure floor is first
              floor_tiles = all_tiles.select { |t| t && t.include?("floor") }
              non_floor_tiles = all_tiles.reject { |t| t && t.include?("floor") }
              all_tiles = floor_tiles + non_floor_tiles
              @pack.set_square_data(abs_x, abs_y, z, all_tiles)
              @defined_squares[[abs_x, abs_y, z]] = true
            end
          end
          
          # Handle y offset: place north wall on the cell below
          if val.key?('y') && val['y'] != 0
            has_offset = true
            target_lx = lx
            target_ly = ly + val['y']
            
            # Check bounds
            if target_ly >= 0 && target_ly < lines.length
              abs_x = @cell_x * 256 + cx * 8 + target_lx
              abs_y = @cell_y * 256 + cy * 8 + target_ly
              # Set wall on north edge
              bits = POTChunkData::Chunk::BIT_WALLN
              @cdata.setSquareBits(abs_x, abs_y, bits)
              # Get existing tiles and append wall tile
              existing = @pack.getSquareData(abs_x, abs_y, z) || []
              all_tiles = existing + [wall_tile]
              all_tiles = all_tiles.uniq
              # Ensure floor exists
              if !all_tiles.any? { |t| t && t.include?("floor") }
                all_tiles.unshift(default_floor)
              end
              # Ensure floor is first
              floor_tiles = all_tiles.select { |t| t && t.include?("floor") }
              non_floor_tiles = all_tiles.reject { |t| t && t.include?("floor") }
              all_tiles = floor_tiles + non_floor_tiles
              @pack.set_square_data(abs_x, abs_y, z, all_tiles)
              @defined_squares[[abs_x, abs_y, z]] = true
            end
          end
          
          # If no offsets, place tile at current position as a regular tile
          if !has_offset
            # Continue to regular processing - replace val with the tile string
            val = wall_tile
          else
            # We handled offsets, skip current position
            next
          end
        end
        
        next if val.nil?
        
        # For interior cells (letters, floor tiles, etc.), use grid position directly
        # For wall characters, also use grid position (they occupy cells)
        # YAML column (lx) → game X, YAML row (ly) → game Y
        abs_x = @cell_x * 256 + cx * 8 + lx
        abs_y = @cell_y * 256 + cy * 8 + ly
        
        # Mark this square as defined
        @defined_squares[[abs_x, abs_y, z]] = true
        
        # 1. Update Collision (chunkdata.bin)
        bits = 0
        if val == "WILDERNESS"
          bits |= POTChunkData::Chunk::BIT_WILDERNESS 
        elsif val.is_a?(String)
          bits |= POTChunkData::Chunk::BIT_WATER if val.include?("water")
          bits |= POTChunkData::Chunk::BIT_SOLID if val.include?("wall") || val.include?("solid")
          bits |= POTChunkData::Chunk::BIT_WALLN if val.include?("wall_n") || val.include?("walls_interior_house_01_0")
          bits |= POTChunkData::Chunk::BIT_WALLW if val.include?("wall_w") || val.include?("walls_interior_house_01_1")
        elsif val.is_a?(Array)
          val.each do |v|
            if v.is_a?(String)
              bits |= POTChunkData::Chunk::BIT_SOLID if v.include?("wall") || v.include?("solid")
              bits |= POTChunkData::Chunk::BIT_WALLN if v.include?("wall_n") || v.include?("walls_interior_house_01_0")
              bits |= POTChunkData::Chunk::BIT_WALLW if v.include?("wall_w") || v.include?("walls_interior_house_01_1")
            end
          end
        end
        @cdata.setSquareBits(abs_x, abs_y, bits)

        # 2. Update Visuals (.lotpack)
        tiles = val.is_a?(Array) ? val : [val]
        # Remove meta-constants like WILDERNESS from tile list
        new_tiles = tiles.select { |t| t.is_a?(String) && !t.empty? && t != "WILDERNESS" }
        
        # Get existing tiles at this position
        existing_tiles = @pack.getSquareData(abs_x, abs_y, z) || []
        
        # Merge existing and new tiles, ensuring floor is first
        all_tiles = existing_tiles + new_tiles
        all_tiles = all_tiles.uniq  # Remove duplicates
        
        # Ensure first tile is a floor tile (has solidfloor flag)
        # If no floor tile is present, prepend a default floor
        floor_tiles = all_tiles.select { |t| t && t.include?("floor") }
        non_floor_tiles = all_tiles.reject { |t| t && t.include?("floor") }
        
        if floor_tiles.empty?
          default_floor = "floors_exterior_street_01_17"
          all_tiles = [default_floor] + non_floor_tiles
        else
          all_tiles = floor_tiles + non_floor_tiles
        end
        
        @pack.set_square_data(abs_x, abs_y, z, all_tiles)
      end
    end
  end
  
  def set_default_floors_for_cell
    # Set a default floor tile for all squares in the cell that weren't explicitly defined
    # This prevents the blending system from crashing when accessing squares without floors
    default_floor = "floors_exterior_street_01_17"
    
    # Only set floors for level 0 (ground level) to avoid unnecessary work
    z = 0
    256.times do |x|
      256.times do |y|
        abs_x = @cell_x * 256 + x
        abs_y = @cell_y * 256 + y
        
        # Skip if we already defined this square
        next if @defined_squares[[abs_x, abs_y, z]]
        
        # Set default floor for undefined squares
        @pack.set_square_data(abs_x, abs_y, z, [default_floor])
      end
    end
  end
end

if __FILE__ == $0
  options = {
    output: "output_map"
  }

  OptionParser.new do |opts|
    opts.banner = "Usage: compiler.rb [options] <map.yaml>"

    opts.on("-o", "--output DIR", "Output directory (default: output_map)") do |o|
      options[:output] = o
    end

    opts.on("-h", "--help", "Prints this help") do
      puts opts
      exit
    end
  end.parse!

  yaml_path = ARGV[0]
  if yaml_path.nil? || !File.exist?(yaml_path)
    puts "Error: Map YAML file not found."
    puts "Usage: #{$0} [options] <map.yaml>"
    exit 1
  end

  compiler = MapCompiler.new(yaml_path)
  compiler.compile(options[:output])
end

