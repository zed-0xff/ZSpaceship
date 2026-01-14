#!/usr/bin/env ruby
# encoding: utf-8
require 'yaml'
require 'fileutils'
require 'optparse'

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
  end

  def compile(out_dir)
    FileUtils.mkdir_p(out_dir)
    
    # Set levels from config
    @header.minLevel = 0
    @header.maxLevel = (@config['map']['levels'] || 1) - 1

    @config['grid'].each do |level_key, chunks|
      z = level_key.split('_').last.to_i
      chunks.each do |chunk_key, grid_str|
        cx, cy = chunk_key.scan(/\d+/).map(&:to_i)
        process_chunk(cx, cy, z, grid_str)
      end
    end

    @header.save(File.join(out_dir, "#{@cell_x}_#{@cell_y}.lotheader"))
    @pack.save(File.join(out_dir, "world_#{@cell_x}_#{@cell_y}.lotpack"))
    @cdata.save(File.join(out_dir, "chunkdata_#{@cell_x}_#{@cell_y}.bin"))
    
    puts "Compiled cell [#{@cell_x}, #{@cell_y}] to #{out_dir}"
  end

  private
  def process_chunk(cx, cy, z, grid_str)
    lines = grid_str.strip.split("\n")
    lines.each_with_index do |line, ly|
      # Unicode-aware character iteration
      line.chars.each_with_index do |char, lx|
        val = @palette[char]
        next if val.nil?

        abs_x = @cell_x * 256 + cx * 8 + lx
        abs_y = @cell_y * 256 + cy * 8 + ly
        
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
        real_tiles = tiles.select { |t| t.is_a?(String) && !t.empty? && t != "WILDERNESS" }
        @pack.set_square_data(abs_x, abs_y, z, real_tiles)
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

