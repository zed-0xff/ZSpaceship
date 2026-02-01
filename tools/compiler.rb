#!/usr/bin/env ruby
# encoding: utf-8
require 'yaml'
require 'fileutils'
require 'optparse'
require 'set'

Dir[File.join(File.dirname(__FILE__), "lib", "**", "*.rb")].each do |libf|
  load libf
end

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
    
    # Load locations from defaults (moved from defaults.palette.locations to defaults.locations)
    @root_locations = @defaults['locations'] || {}
    
    # Load allowed flags list from root-level 'flags:' section
    @allowed_flags = Set.new(@config['flags'] || [])
    
    # Load tile definitions from root-level 'tiles:' section
    @tile_definitions = @config['tiles'] || {}
    
    # Track all tiles with their flags for export
    @tiles_with_flags = {}  # tile_name => { flags: [...], airtight: bool, replaces: [...] }
    
    # Track wildcard patterns for tile matching
    @wildcard_patterns = {}  # Map wildcard pattern -> { pattern: Regexp, definition: Hash }
    
    # Build tile_params and tile_aliases from tile_definitions only
    # All tiles must be defined in tiles: section
    @tile_params = {}
    @tile_aliases = {}  # Map alias -> actual tile name
    @tile_definitions.each do |tile_name, definition|
      if tile_name.include?('*')
        # Wildcard pattern - store for pattern matching
        pattern = tile_name.gsub('*', '.*')
        wildcard_def = definition.is_a?(Hash) ? definition.dup : {}
        
        # Validate flags in wildcard definition
        if wildcard_def['flags'] && wildcard_def['flags'].is_a?(Array)
          validate_flags(wildcard_def['flags'], "tile '#{tile_name}'")
        end
        
        @wildcard_patterns[tile_name] = {
          pattern: Regexp.new("^#{pattern}$"),
          definition: wildcard_def
        }
      elsif definition.is_a?(Hash)
        # Validate flags
        if definition['flags'] && definition['flags'].is_a?(Array)
          validate_flags(definition['flags'], "tile '#{tile_name}'")
        end
        
        @tile_params[tile_name] = definition.dup
        
        # Track aliases
        if definition['alias']
          alias_name = definition['alias']
          @tile_aliases[alias_name] = tile_name
        end
        
        # Track tiles with flags for export
        if definition['flags'] && definition['flags'].is_a?(Array) && !definition['flags'].empty?
          @tiles_with_flags[tile_name] = {
            flags: definition['flags'].dup
          }
        end
      end
    end
    
    # Track all defined tile names (including aliases) for validation
    @defined_tiles = Set.new(@tile_definitions.keys.reject { |k| k.include?('*') })
    @defined_tiles.merge(@tile_aliases.keys)  # Add aliases as valid tile names
    
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
    
    # Intermediate representation: Square objects keyed by [x, y, z]
    @squares = {}
    
    # Room counter for unique IDs
    @room_index = 0
    @building_index = 0
    
    # Track special locations (spawn points, etc.)
    @room_spawn_points = []  # Track room centers for spawn points (excluding corridors)
    @all_rooms = []  # Track all room centers including halls (for MapData.DefaultRooms)
    @locations_by_type = Hash.new { |h, k| h[k] = [] }  # Track location coordinates by type
    
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
  
  # Validate flags against allowed flags list
  def validate_flags(flags, context = "")
    return if flags.empty? || @allowed_flags.empty?
    
    invalid_flags = flags.reject { |f| @allowed_flags.include?(f) }
    unless invalid_flags.empty?
      raise "Invalid flags #{invalid_flags.inspect} in #{context}. Allowed flags: #{@allowed_flags.to_a.sort.inspect}"
    end
  end

  def compile(out_dir)
    FileUtils.mkdir_p(out_dir)
    
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
    
    # Finalize all Square objects: convert to final output format
    finalize_squares
    
    # Print compilation statistics
    stats = get_compilation_stats
    puts "\nCompilation Statistics:"
    puts "  Total squares: #{stats[:total_squares]}"
    puts "  Defined squares: #{stats[:defined_squares]}"
    puts "  Squares with floors: #{stats[:squares_with_floor]}"
    puts "  Squares with walls: #{stats[:squares_with_walls]}"
    puts "  Total tiles placed: #{stats[:total_tiles]}"
    puts "  Unique tile types: #{stats[:unique_tiles]}"
    puts "  Squares by z-level: #{stats[:squares_by_z].sort.map { |z, count| "z#{z}=#{count}" }.join(', ')}"

    @header.save(File.join(out_dir, "#{@cell_x}_#{@cell_y}.lotheader"))
    @pack.save(File.join(out_dir, "world_#{@cell_x}_#{@cell_y}.lotpack"))
    @cdata.save(File.join(out_dir, "chunkdata_#{@cell_x}_#{@cell_y}.bin"))
    
    # Output combined map data and wall tiles Lua file
    save_combined_data_lua(out_dir)
    
    # Output spawn points Lua file
    save_spawnpoints_lua(out_dir)
    
    puts "\nCompiled cell [#{@cell_x}, #{@cell_y}] to #{out_dir}"
  end
end

if __FILE__ == $0
  options = { output: "out" }

  OptionParser.new do |opts|
    opts.banner = "Usage: compiler.rb [options] <map.yaml>"

    opts.on("-o", "--output DIR", "Output directory (default: out)") do |o|
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
