#coding: binary
require 'iostruct'

module TexturePackPage
  def self.ReadString(io)
    len = readInt(io)
    raise "0x#{io.tell.to_s(16)}: invalid length 0x#{len.to_s(16)}" if len < 0 || len > 65536
    io.read(len)
  end

  def self.WriteString(io, str)
    io.write([str.length, str].pack("iA*"))
  end

  def self.readInt(io)
    io.read(4).unpack1('i')
  end

  def self.readIntByteUntil(io, term)
    v = io.read(4).unpack1('I')
    while v != term
      v = (v >> 8) | (io.read(1).unpack1('C') << 24)
    end
  end

  class SubTextureInfo < IOStruct.new("i8", :x, :y, :w, :h, :ox, :oy, :fx, :fy, :name, inspect: :dec)
    def self.read(io)
      name = TexturePackPage.ReadString(io)
      super(io).tap do |x|
        x.name = name
      end
    end

    def write(io)
      TexturePackPage.WriteString(io, name)
      io.write(pack)
    end
  end
end

class TexturePackDevice
  def self.open(fname, &block)
    File.open(fname, "rb") do |f|
      yield TexturePackDevice.new(f)
    end
  end

  MAGIC = 'PZPK'

  attr_reader :version, :count, :pages

  def initialize(io = nil)
    if io
      magic = io.read(4)
      if magic == MAGIC
        @version = TexturePackPage.readInt(io)
        raise "invalid .pack file version #{@version}" unless @version == 1

        @count = TexturePackPage.readInt(io)
      else
        @version = 0
        @count = magic.unpack1('i')
      end

      @pages = @count.times.map{ readPage(io) }
    else
      @version = 1
      @count = 0
      @pages = []
    end
  end

  def write(io)
    io.write([MAGIC, @version, @count].pack("A4ii"))
    @pages.each do |page|
      page.write(io)
    end
  end

  def inspect
    "#<TexturePackDevice version=%d, count=%d, pages=[...]>" % [@version, @count]
  end

  class Page
    attr_accessor :name, :hasAlpha, :numEntries, :sub, :pngStart, :pngSize

    def initialize
      @sub = []
      @numEntries = 0
    end

    def create_sub *args, **kwargs
      sub = TexturePackPage::SubTextureInfo.new(*args, **kwargs)
      @sub << sub
      @numEntries += 1
      sub
    end

    def write(io)
      io.write([@name.length, @name, @numEntries, @hasAlpha ? 1 : 0].pack("iA*ii"))
      @sub.each do |s|
        s.write(io)
      end
      io.write([@pngSize].pack("i"))
    end

    def inspect
      "#<Page name=%p, hasAlpha=%p, numEntries=%d, sub=[...], pngStart=0x%x, pngSize=0x%x>" % [@name, @hasAlpha, @numEntries, @pngStart, @pngSize]
    end
  end

  def readPage(io)
    page = Page.new
    page.name       = TexturePackPage.ReadString(io)
    page.numEntries = TexturePackPage.readInt(io)
    page.hasAlpha   = TexturePackPage.readInt(io) != 0
    page.sub        = page.numEntries.times.map{ TexturePackPage::SubTextureInfo.read(io) }
    if @version == 0
      page.pngStart = io.tell
      TexturePackPage.readIntByteUntil(io, 0xDEADBEEF)
    else
      length = TexturePackPage.readInt(io)
      page.pngStart = io.tell
      io.seek(length, IO::SEEK_CUR)
    end
    page.pngSize = io.tell - page.pngStart
    page
  end

  def create_page name
    page = Page.new
    page.name = name
    page.hasAlpha = true
    page.numEntries = 0
    @pages << page
    @count = @pages.size
    page
  end
end
