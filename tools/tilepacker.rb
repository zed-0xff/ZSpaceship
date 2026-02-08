#!/usr/bin/env ruby

Dir[File.join(File.dirname(__FILE__), "lib", "*.rb")].each do |libf|
  require libf
end

require 'fileutils'
require 'optparse'
require 'json'
require 'zpng'

def create_tex_pack(pngs)
  imgs = {}
  pngs.each do |fname|
    imgs[fname] = ZPNG::Image.load(fname)
  end
  result = ZPNG::Image.new(
    width:  imgs.values.map(&:width).inject(&:+),
    height: imgs.values.map(&:height).max
  )
  x = 0
  imgs.each do |fname, img|
    result.copy_from(img, dst_x: x)
    x += img.width
  end
  FileUtils.mkdir_p(@outdir)
  page_name = @name + '0'

  ofname = File.join(@outdir, "#{page_name}.png")
  result.save(ofname)
  #puts "[=] #{ofname}"

  tpd = TexturePackDevice.new
  page = tpd.create_page(page_name)
  page.pngStart = 0
  page.pngSize = File.size(ofname)
  x = 0
  imgs.each do |fname, img|
    ox = oy = 0
    img.scanlines.each do |sl|
      if sl.pixels.all?(&:transparent?)
        oy += 1
      else
        break
      end
    end
    page.create_sub(x, oy, img.width, img.height-oy, ox, oy, img.width, img.height, File.basename(fname, ".png"))
    x += img.width
  end

  if @verbosity > 0
    pp tpd
    tpd.pages.each do |p|
      printf "    %s\n", p.inspect
      p.sub.each do |sub|
        printf "          %s\n", sub.to_table
      end
    end
  end

  ofname = @pack_output || File.join(@outdir, "#{@name}.pack")
  puts "[=] #{ofname}"
  File.open(ofname, "wb") do |f|
    tpd.write(f)
    result.save(f)
  end
end

def create_tiles(jsons)
  ofname = @tiles_output || File.join(@outdir, "#{@name}.tiles")
  puts "[=] #{ofname}"
  File.open(ofname, "wb") do |f|
    magic = 'tdef'
    version = 1
    numTilesheets = 1

    # file header
    f.write([magic, version, numTilesheets].pack("A4ii"))

    # tilesheet header
    f << @name << "\n"
    f << @name << ".png" << "\n"
    w = jsons.size
    h = 1
    tilesetNumber = 1
    nTiles = jsons.size
    f.write([w, h, tilesetNumber, nTiles].pack("iiii"))

    jsons.each do |fname|
      props = JSON.parse(File.read(fname))
      nprops = props.size
      f.write([nprops].pack("i"))
      props.each do |k, v|
        f << k << "\n"
        f << v.to_s << "\n"
      end
    end
  end
end

@outdir = "out"
@name = "tiles"
@verbosity = 0

parser = OptionParser.new do |opts|
  opts.banner = "Usage: tilepacker.rb [options] [files...]"

  opts.on("-v", "--verbose", "Increase verbosity") do |v|
    @verbosity += 1
  end
  opts.on("-o", "--output DIR", "Output directory") do |dir|
    @outdir = dir
  end
  opts.on("--tiles-out FNAME", "Output file name for tiles") do |fname|
    @tiles_output = fname
  end
  opts.on("--pack-out FNAME", "Output file name for texture pack") do |fname|
    @pack_output = fname
  end
  opts.on("--name NAME", "Texture pack name") do |name|
    @name = name
  end
end
parser.parse!

if ARGV.empty?
  puts parser
  exit
end

src_files = []
ARGV.each do |fname|
  if File.directory?(fname)
    src_files.concat(Dir.glob(File.join(fname, "*.{png,json}")))
  else
    src_files << fname
  end
end

jsons = []
pngs = []

src_files.sort.each do |fname|
  if fname.end_with?(".json")
    jsons << fname
  elsif fname.end_with?(".png")
    pngs << fname
  else
    raise "Unknown file type: #{fname}"
  end
end

create_tex_pack(pngs) if pngs.any?
create_tiles(jsons) if jsons.any?
