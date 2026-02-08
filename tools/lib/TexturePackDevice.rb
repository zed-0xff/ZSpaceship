#coding: binary
require 'iostruct'

module TexturePackPage
  def self.ReadString(io)
    len = readInt(io)
    raise "0x#{io.tell.to_s(16)}: invalid length 0x#{len.to_s(16)}" if len < 0 || len > 65536
    io.read(len)
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

  def initialize(io)
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
  end

  def inspect
    "#<TexturePackDevice version=%d, count=%d, pages=[...]>" % [@version, @count]
  end

  class Page
    attr_accessor :name, :hasAlpha, :numEntries, :sub, :pngStart, :pngSize

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
end
