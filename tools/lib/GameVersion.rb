class GameVersion # verbatim
  attr_reader :m_major, :m_minor, :m_suffix

  def initialize(major, minor, suffix = nil)
    @m_major  = major
    @m_minor  = minor
    @m_suffix = suffix
  end

  def self.parse(str)
    if str =~ /^(\d+)\.(\d+)(.*)$/
      new($1.to_i, $2.to_i, $3)
    else
      raise "invalid game version \"#{str}\""
    end
  end

  def to_s
    "#{@m_major}.#{@m_minor}#{@m_suffix}"
  end

  def getInt()
    @m_major * 1000 + @m_minor
  end

  # non-verbatim
  def > other
    getInt() > other.getInt()
  end

  def >= other
    getInt() >= other.getInt()
  end

  B41   = GameVersion.new(41, 0)
  B42_0 = GameVersion.new(42, 0)
  DEFAULT = B42_0
end
