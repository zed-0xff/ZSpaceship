#!/usr/bin/env ruby
#coding: binary

require 'colorize'
require 'iostruct'
require 'zhexdump'

ZHexdump.defaults[:width] = 32

Dir[File.join(File.dirname(__FILE__), "lib", "*.rb")].each do |libf|
  require libf
end

Rect = IOStruct.new("l4", :x, :y, :w, :h, inspect: to_s)
Ass  = IOStruct.new("L2", :bld_id, :room_id, inspect: to_s)
Obj  = IOStruct.new("l3")

def process_file(fname)
  magic = File.binread(fname, 4)
  case magic
  when "LOTH"
    process_LOTH_file(fname)
  when "LOTP"
    process_LOTP_file(fname)
  else
    if fname.end_with?(".bin")
      process_BIN_file(fname)
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

def process_LOTH_file(fname)
  puts "Processing #{fname}".cyan
  coords = fname2coords(fname)
  hdr = POTLotHeader.new(*coords.split("_").map(&:to_i), true)
  hdr.load(fname)
  @headers[coords] = hdr
  pp hdr.buildings
end

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
