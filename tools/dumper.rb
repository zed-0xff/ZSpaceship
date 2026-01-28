#!/usr/bin/env ruby
#coding: binary

require 'colorize'
require 'iostruct'
require 'zhexdump'
require 'optparse'
require 'fileutils'

ZHexdump.defaults[:width] = 32

Dir[File.join(File.dirname(__FILE__), "lib", "*.rb")].each do |libf|
  require libf
end

def process_file(fname)
  magic = File.binread(fname, 4)
  case magic
  when "LOTH"
    process_LOTH_file(fname)
  when "LOTP"
    process_LOTP_file(fname)
  when "tdef"
    process_tdef_file(fname)
  when 'PZPK'
    process_PACK_file(fname)
  else
    case fname
    when /\.bin\z/
      process_BIN_file(fname)
    when /\.pack\z/
      process_PACK_file(fname)
    end
  end
end

def process_PACK_file(fname)
  puts "Processing #{fname} (#{File.size(fname)} bytes)".cyan
  TexturePackDevice.open(fname) do |tpd|
    p tpd
    tpd.pages.each_with_index do |p, idx|
      printf "    %4d: %s\n", idx, p.inspect

      p.sub.each_with_index do |sub, sub_idx|
        printf "          %4d: %s\n", sub_idx, sub.to_table
      end

      if @extract
        FileUtils.mkdir_p(@outdir)
        out_fname = File.join(@outdir, p.name + ".png")
        File.open(out_fname, "wb") do |of|
          File.open(fname, "rb") do |f|
            f.seek(p.pngStart)
            data = f.read(p.pngSize)
            of.write(data)
          end
        end
      end
    end
  end
end

def process_tdef_file(fname)
  puts "Processing #{fname} (#{File.size(fname)} bytes)".cyan
  File.open(fname, "rb") do |f|
    magic = f.read(4)
    unless magic == "tdef"
      puts "  Invalid tdef file (bad magic #{magic.inspect})".red
      return
    end

    version = f.read(4).unpack1("L<")
    puts "  Version: #{version}"

    numTilesheets = f.read(4).unpack1("L<")
    puts "  numTilesheets: #{numTilesheets}"

    numTilesheets.times do |ts_idx|
      indent = "      "; name_len = -14

      printf "    Tilesheet %3d:\n", ts_idx
      name = f.gets.chomp
      printf "%s%*s: %s\n", indent, name_len, "name", name

      img_name = f.gets.chomp
      printf "%s%*s: %s\n", indent, name_len, "img_name", img_name

      a,b = f.read(8).unpack("L2")
      printf "%s%*s: %s\n", indent, name_len, "size", "#{a} x #{b}"

      tilesetNumber = f.read(4).unpack1("L<")
      printf "%s%*s: %d\n", indent, name_len, "tilesetNumber", tilesetNumber

      nTiles = f.read(4).unpack1("L<")
      printf "%s%*s: %d\n", indent, name_len, "nTiles", nTiles

      indent += "  "
      nTiles.times do |tile_idx|
        nProps = f.read(4).unpack1("L<")
        #printf "nProps: %d: ", nProps
        props = {}
        nProps.times do |prop_idx|
          prop = f.gets.chomp
          val = f.gets.chomp
          props[prop] = val
        end

        if true # props.any?
          name2 = "%s_%d" % [name, tile_idx]
          printf "%-24s: ", name2
          puts props.map{ |k,v| v == "" ? k : "#{k}:#{v}" }.join(", ")
        end
      end
      puts
    end
  end
end

def process_BIN_file(fname)
  puts "Processing #{fname} (#{File.size(fname)} bytes)".cyan
  coords = fname2coords(fname)
  cdata = POTChunkData.new(*coords.split("_").map(&:to_i), true)
  cdata.load(fname)
  p cdata

  total_chunks = cdata.chunksPerCell
  chunk_dim = cdata.chunkDim
  
  # Find bounds of non-empty squares
  min_sx, max_sx = total_chunks * chunk_dim, 0
  min_sy, max_sy = total_chunks * chunk_dim, 0
  any_data = false

  cdata.chunks.each_with_index do |c, idx|
    next if c.empty?

    any_data = true
    cx = idx % total_chunks
    cy = idx / total_chunks
    
    if c.bits
      c.bits.each_with_index do |b, b_idx|
        if b != 0
          lx = b_idx % chunk_dim
          ly = b_idx / chunk_dim
          sx = cx * chunk_dim + lx
          sy = cy * chunk_dim + ly
          min_sx = [min_sx, sx].min
          max_sx = [max_sx, sx].max
          min_sy = [min_sy, sy].min
          max_sy = [max_sy, sy].max
        end
      end
    else
      # Uniform non-empty chunk
      min_sx = [min_sx, cx * chunk_dim].min
      max_sx = [max_sx, (cx + 1) * chunk_dim - 1].max
      min_sy = [min_sy, cy * chunk_dim].min
      max_sy = [max_sy, (cy + 1) * chunk_dim - 1].max
    end
  end

  unless any_data
    puts "  (empty cell)"
    return
  end

  # Helper to get char for a square
  get_char = lambda do |chunk, lx, ly|
    return "??" unless chunk
    bits = if chunk.bits
      chunk.bits[lx + (ly * chunk_dim)]
    else
      # Handle uniform chunks
      if chunk.counts[POTChunkData::Chunk::SOLID_CHUNK] == chunk.nSqrs
        POTChunkData::Chunk::BIT_SOLID
      elsif chunk.counts[POTChunkData::Chunk::WATER_CHUNK] == chunk.nSqrs
        POTChunkData::Chunk::BIT_WATER
      elsif chunk.counts[POTChunkData::Chunk::ROOM_CHUNK] == chunk.nSqrs
        POTChunkData::Chunk::BIT_ROOM
      elsif chunk.counts[POTChunkData::Chunk::EMPTY_CHUNK] == chunk.nSqrs
        0
      elsif chunk.counts[POTChunkData::Chunk::WILDERNESS_CHUNK] == chunk.nSqrs
        POTChunkData::Chunk::BIT_WILDERNESS
      else
        nil # Invalid or unknown state
      end
    end
    
    bits ? POTChunkData::Chunk.bit2ascii(bits) : "??"
  end

  puts "Bounds: X #{min_sx}..#{max_sx}, Y #{min_sy}..#{max_sy}"
  min_sy.upto(max_sy) do |y_abs|
    cy = y_abs / chunk_dim
    ly = y_abs % chunk_dim
    min_sx.upto(max_sx) do |x_abs|
      cx = x_abs / chunk_dim
      lx = x_abs % chunk_dim
      
      chunk = cdata.chunks[cx + (cy * total_chunks)]
      print get_char.call(chunk, lx, ly)
    end
    puts
  end
end

def fname2coords(fname)
  bname = File.basename(fname).split(".").first
  return bname if bname =~ /\A\d+_\d+\z/

  if bname =~ /_(\d+_\d+)\z/
    return $1
  end

  nil
end

def process_LOTP_file(fname)
  puts "Processing #{fname}".cyan
  coords = fname2coords(fname)
  hdr = @headers[coords]
  lotp = POTLotPack.new(hdr)
  lotp.load(fname)

  minZ = [lotp.lotHeader.minLevel, -32].max
  maxZ = [lotp.lotHeader.maxLevel, 31].min
  minZ.upto(maxZ) do |z|
    lotp.chunkDim.times do |x|
      lotp.chunkDim.times do |y|
        data = lotp.getSquareData(x, y, z)
        if data
          printf "  %4d,%4d,%2d: %s\n", x, y, z, data.inspect
        end
      end
    end
  end
end

@headers = {}
@verbosity = 0
@outdir = "out"

def process_LOTH_file(fname)
  puts "Processing #{fname}".cyan
  coords = fname2coords(fname)
  hdr = POTLotHeader.new(*coords.split("_").map(&:to_i), true)
  hdr.load(fname)
  @headers[coords] = hdr
  pp hdr.buildings
end

OptionParser.new do |opts|
  opts.banner = "Usage: dumper.rb [options] [files...]"

  opts.on("-v", "--verbose", "Increase verbosity") do |v|
    @verbosity += 1
  end
  opts.on("-o", "--output DIR", "Output directory") do |dir|
    @outdir = dir
  end
  opts.on("-x", "--extract", "Extract files") do
    @extract = true
  end
end.parse!

if ARGV.any?
  # load .lotheader files first
  ARGV.find_all{|f| f.end_with?(".lotheader")}.each do |fname|
    process_file(fname)
  end
  ARGV.find_all{|f| !f.end_with?(".lotheader")}.each do |fname|
    process_file(fname)
  end
else
  fnames = "/Users/zed/Library/Application Support/Steam/steamapps/workshop/content/108600/3613501122/mods/modForeverInteriors/common/media/maps/map_xever_interiors/*.lotheader"
  Dir[fnames].each do |fname|
    process_file(fname)
  end
end
