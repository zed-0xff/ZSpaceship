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
  DEFAULT_FLOOR = "floors_exterior_street_01_17"
  
  def initialize(yaml_path)
    @config = YAML.safe_load(File.read(yaml_path, encoding: "utf-8"), permitted_classes: [Symbol])
    @cell_x, @cell_y = @config['origin']
    
    @header = POTLotHeader.new(@cell_x, @cell_y, true)
    @pack = POTLotPack.new(@header)
    @cdata = POTChunkData.new(@cell_x, @cell_y, true)
    
    @elements = @config['elements'] || {}
    @metapalette = @config['metapalette'] || {}
    @metamap = @config['metamap'] || ""
    
    # Compute element sizes (standard: width=chars, height=lines)
    @element_sizes = {}
    @elements.each do |name, elem|
      lines = (elem['map'] || "").rstrip.split("\n")
      height = lines.length
      width = lines.map { |l| l.chars.length }.max || 0
      @element_sizes[name] = { width: width, height: height }
    end
  end

  def compile(out_dir)
    FileUtils.mkdir_p(out_dir)
    
    @header.minLevel = 0
    @header.maxLevel = 0
    @defined_squares = {}
    
    placements = parse_metamap
    
    placements.each do |placement|
      process_element_placement(placement)
    end
    
    set_default_floors_for_cell

    @header.save(File.join(out_dir, "#{@cell_x}_#{@cell_y}.lotheader"))
    @pack.save(File.join(out_dir, "world_#{@cell_x}_#{@cell_y}.lotpack"))
    @cdata.save(File.join(out_dir, "chunkdata_#{@cell_x}_#{@cell_y}.bin"))
    
    puts "Compiled cell [#{@cell_x}, #{@cell_y}] to #{out_dir}"
  end

  private
  
  # Convert local offsets to world coords (no transpose)
  def to_world(local_x, local_y)
    abs_x = @cell_x * 256 + local_x
    abs_y = @cell_y * 256 + local_y
    [abs_x, abs_y]
  end
  
  def parse_metamap
    lines = @metamap.rstrip.split("\n")
    return [] if lines.empty?
    
    element_refs = []
    
    lines.each_with_index do |line, meta_y|
      line.chars.each_with_index do |char, meta_x|
        next if char == ' ' || char == "\t"
        element_name = @metapalette[char]
        next unless element_name && @elements[element_name]
        element_refs << {
          meta_x: meta_x,
          meta_y: meta_y,
          element_name: element_name
        }
      end
    end
    
    max_meta_x = element_refs.map { |r| r[:meta_x] }.max || 0
    max_meta_y = element_refs.map { |r| r[:meta_y] }.max || 0
    
    # Column widths (for X positioning in metamap)
    col_widths = Array.new(max_meta_x + 1, 0)
    # Row heights (for Y positioning in metamap)
    row_heights = Array.new(max_meta_y + 1, 0)
    
    element_refs.each do |ref|
      size = @element_sizes[ref[:element_name]]
      col_widths[ref[:meta_x]] = [col_widths[ref[:meta_x]], size[:width]].max
      row_heights[ref[:meta_y]] = [row_heights[ref[:meta_y]], size[:height]].max
    end
    
    col_offsets = [0]
    col_widths.each { |w| col_offsets << col_offsets.last + w }
    
    row_offsets = [0]
    row_heights.each { |h| row_offsets << row_offsets.last + h }
    
    # Calculate total size and center offset
    total_width = col_offsets.last
    total_height = row_offsets.last
    center_offset_x = (256 - total_width) / 2
    center_offset_y = (256 - total_height) / 2
    
    placements = element_refs.map do |ref|
      {
        element_name: ref[:element_name],
        local_x: col_offsets[ref[:meta_x]] + center_offset_x,
        local_y: row_offsets[ref[:meta_y]] + center_offset_y
      }
    end
    
    placements
  end
  
  def process_element_placement(placement)
    element_name = placement[:element_name]
    base_local_x = placement[:local_x]
    base_local_y = placement[:local_y]
    
    element = @elements[element_name]
    return unless element
    
    palette = element['palette'] || {}
    map_str = element['map'] || ""
    z = 0
    
    lines = map_str.rstrip.split("\n")
    lines.each_with_index do |line, ly|
      line.chars.each_with_index do |char, lx|
        val = palette[char]
        next if val.nil?
        
        local_x = base_local_x + lx
        local_y = base_local_y + ly
        
        if val.is_a?(Hash) && val.key?('tile')
          process_offset_tile(val, local_x, local_y, z)
          next
        end
        
        abs_x, abs_y = to_world(local_x, local_y)
        
        @defined_squares[[abs_x, abs_y, z]] = true
        bits = compute_collision_bits(val)
        @cdata.setSquareBits(abs_x, abs_y, bits)
        
        tiles = val.is_a?(Array) ? val : [val]
        tiles = tiles.select { |t| t.is_a?(String) && !t.empty? && t != "WILDERNESS" }
        
        set_square_tiles(abs_x, abs_y, z, tiles)
      end
    end
  end
  
  def process_offset_tile(val, local_x, local_y, z)
    wall_tile = val['tile']
    has_offset = false
    
    # x offset: move right, places west wall on target cell
    if val.key?('x') && val['x'] != 0
      has_offset = true
      target_local_x = local_x + val['x']
      abs_x, abs_y = to_world(target_local_x, local_y)
      
      bits = POTChunkData::Chunk::BIT_WALLW
      @cdata.setSquareBits(abs_x, abs_y, bits)
      set_square_tiles(abs_x, abs_y, z, [wall_tile])
      @defined_squares[[abs_x, abs_y, z]] = true
    end
    
    # y offset: move down, places north wall on target cell
    if val.key?('y') && val['y'] != 0
      has_offset = true
      target_local_y = local_y + val['y']
      abs_x, abs_y = to_world(local_x, target_local_y)
      
      bits = POTChunkData::Chunk::BIT_WALLN
      @cdata.setSquareBits(abs_x, abs_y, bits)
      set_square_tiles(abs_x, abs_y, z, [wall_tile])
      @defined_squares[[abs_x, abs_y, z]] = true
    end
    
    unless has_offset
      abs_x, abs_y = to_world(local_x, local_y)
      @defined_squares[[abs_x, abs_y, z]] = true
      set_square_tiles(abs_x, abs_y, z, [wall_tile])
    end
  end
  
  def compute_collision_bits(val)
    bits = 0
    values = val.is_a?(Array) ? val : [val]
    
    values.each do |v|
      next unless v.is_a?(String)
      bits |= POTChunkData::Chunk::BIT_WILDERNESS if v == "WILDERNESS"
      bits |= POTChunkData::Chunk::BIT_WATER if v.include?("water")
      bits |= POTChunkData::Chunk::BIT_SOLID if v.include?("wall") || v.include?("solid")
      bits |= POTChunkData::Chunk::BIT_WALLN if v.include?("wall_n") || v.include?("walls_interior_house_01_0")
      bits |= POTChunkData::Chunk::BIT_WALLW if v.include?("wall_w") || v.include?("walls_interior_house_01_1")
    end
    
    bits
  end
  
  def set_square_tiles(abs_x, abs_y, z, new_tiles)
    existing = @pack.getSquareData(abs_x, abs_y, z) || []
    all_tiles = (existing + new_tiles).uniq
    
    floor_tiles = all_tiles.select { |t| t && t.include?("floor") }
    non_floor_tiles = all_tiles.reject { |t| t && t.include?("floor") }
    
    if floor_tiles.empty?
      all_tiles = [DEFAULT_FLOOR] + non_floor_tiles
    else
      all_tiles = floor_tiles + non_floor_tiles
    end
    
    @pack.set_square_data(abs_x, abs_y, z, all_tiles)
  end
  
  def set_default_floors_for_cell
    z = 0
    256.times do |x|
      256.times do |y|
        abs_x = @cell_x * 256 + x
        abs_y = @cell_y * 256 + y
        
        next if @defined_squares[[abs_x, abs_y, z]]
        
        @pack.set_square_data(abs_x, abs_y, z, [DEFAULT_FLOOR])
      end
    end
  end
end

if __FILE__ == $0
  options = { output: "output_map" }

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
