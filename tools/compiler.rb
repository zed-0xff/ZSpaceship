#!/usr/bin/env ruby
# encoding: utf-8
require 'yaml'
require 'fileutils'
require 'optparse'
require 'set'

Dir[File.join(File.dirname(__FILE__), "lib", "*.rb")].each do |libf|
  load libf
end

# Load MapCompiler modules first
require_relative 'lib/map_compiler/utilities'
require_relative 'lib/map_compiler/map_parser'
require_relative 'lib/map_compiler/palette_processor'
require_relative 'lib/map_compiler/tile_manager'
require_relative 'lib/map_compiler/room_builder'
require_relative 'lib/map_compiler/element_processor'
require_relative 'lib/map_compiler/corridor_handler'
require_relative 'lib/map_compiler/output_generator'

# --- Compiler Logic ---

class MapCompiler
  MAP_SIZE = 256
  
  include MapCompiler::Utilities
  include MapCompiler::MapParser
  include MapCompiler::PaletteProcessor
  include MapCompiler::TileManager
  include MapCompiler::RoomBuilder
  include MapCompiler::ElementProcessor
  include MapCompiler::CorridorHandler
  include MapCompiler::OutputGenerator

  def initialize(yaml_path)
    @config = YAML.safe_load(File.read(yaml_path, encoding: "utf-8"), permitted_classes: [Symbol])
    @cell_x, @cell_y = @config['origin']
    @default_floor = @config['default_floor']
    
    @elements = @config['elements'] || {}
    @metapalette = @config['metapalette'] || {}
    @metamap = @config['metamap'] || ""
    @metamap_gap = @config['metamap_gap'] || 0 # Gap between elements (-1 = share walls)
    
    # Extract and merge defaults into all elements
    @defaults = @elements.delete('defaults') || {}
    
    # Extract tile parameters from defaults (floors:, walls:, etc.)
    @tile_params = {}
    if @defaults['floors'] && @defaults['floors'].is_a?(Hash)
      @defaults['floors'].each do |tile_name, params|
        @tile_params[tile_name] = params.dup if params.is_a?(Hash)
      end
    end
    if @defaults['walls'] && @defaults['walls'].is_a?(Hash)
      @defaults['walls'].each do |tile_name, params|
        # Merge with existing params if tile already has params
        if @tile_params[tile_name]
          if params.is_a?(Hash) && params['replaces'] && @tile_params[tile_name]['replaces']
            @tile_params[tile_name]['replaces'] = (@tile_params[tile_name]['replaces'] + params['replaces']).uniq
          end
          @tile_params[tile_name].merge!(params) if params.is_a?(Hash)
        else
          @tile_params[tile_name] = params.dup if params.is_a?(Hash)
        end
      end
    end
    
    @elements.each do |name, elem|
      @elements[name] = deep_merge(@defaults.dup, elem)
    end
    
    # Pre-calculate maxLevel based on elements with level and roof
    # Note: minLevel must always be 0 (or negative) for game's internal calculations
    max_level = 0
    @elements.each do |name, elem|
      level = elem['level'] || @defaults['level'] || 0
      max_level = [max_level, level].max
      if elem['roof']
        max_level = [max_level, level + 1].max
      end
    end
    
    @header = POTLotHeader.new(@cell_x, @cell_y, true)
    @header.minLevel = 0  # Always start from 0 for game compatibility
    @header.maxLevel = max_level  # Include default_level and any roofs above
    @pack = POTLotPack.new(@header)
    @cdata = POTChunkData.new(@cell_x, @cell_y, true)
    
    # Compute element sizes (use explicit width/height if present, otherwise derive from map)
    @element_sizes = {}
    @elements.each do |name, elem|
      lines = (elem['map'] || "").rstrip.split("\n")
      map_height = lines.length
      map_width = lines.map { |l| l.chars.length }.max || 0
      
      # Respect explicit width/height if present
      width = elem['width'] || map_width
      height = elem['height'] || map_height
      @element_sizes[name] = { width: width, height: height }
    end
    
    # Track replaced tiles per square - these are blocked from being added later
    @replaced_tiles = Hash.new { |h, k| h[k] = Set.new }
    
    # Room counter for unique IDs
    @room_index = 0
    @building_index = 0
    
    # Track special locations (spawn points, etc.)
    @room_spawn_points = []  # Track room centers for spawn points (excluding corridors)
    @all_rooms = []  # Track all room centers including halls (for MapData.DefaultRooms)
    @generators = []  # Track generator coordinates
    
    # Collect door sprites (first entry from each door definition)
    @door_sprites = Set.new
    # Track door tiles (first tile from each door definition) to exclude from wall tracking
    @door_tiles = Set.new
    # Track door tiles by direction (NS and EW) for door lookup tables
    @door_tiles_ns = Set.new
    @door_tiles_ew = Set.new
    
    # Auto corridors config and tracking
    @auto_corridors = @config['auto_corridors'] || {}
    @placed_doors = []  # Track door positions for auto-corridor generation
    @corridor_count = 0  # Counter for corridor instance IDs
    
    # Track wall tiles for airtight wall lists
    @wall_tiles_ns = Set.new  # North/South walls (getWall(true))
    @wall_tiles_ew = Set.new  # East/West walls (getWall(false))
    
    # Single building for the entire spaceship
    @spaceship_building = nil
  end

  def compile(out_dir)
    FileUtils.mkdir_p(out_dir)
    @defined_squares = {}
    
    # Create a single building for all rooms
    @spaceship_building = BuildingDef.new
    @spaceship_building.id = BuildingID.makeID(@cell_x, @cell_y, @building_index)
    @building_index += 1
    @header.buildings << @spaceship_building
    
    placements = parse_metamap
    
    placements.each do |placement|
      process_element_placement(placement)
    end
    
    # Generate auto corridors between adjacent doors
    process_auto_corridors if @auto_corridors['floor']
    
    set_default_floors_for_cell

    @header.save(File.join(out_dir, "#{@cell_x}_#{@cell_y}.lotheader"))
    @pack.save(File.join(out_dir, "world_#{@cell_x}_#{@cell_y}.lotpack"))
    @cdata.save(File.join(out_dir, "chunkdata_#{@cell_x}_#{@cell_y}.bin"))
    
    # Output combined map data and wall tiles Lua file
    save_combined_data_lua(out_dir)
    
    # Output spawn points Lua file
    save_spawnpoints_lua(out_dir)
    
    puts "Compiled cell [#{@cell_x}, #{@cell_y}] to #{out_dir}"
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
