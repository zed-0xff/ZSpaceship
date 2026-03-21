class GameVersion # verbatim
  attr_reader :m_major, :m_minor, :m_suffix

  def initialize(major, minor, suffix = nil)
    @m_major  = major
    @m_minor  = minor
    @m_suffix = suffix
  end

  def to_s
    "#{@m_major}.#{@m_minor}#{@m_suffix}"
  end

  def getInt()
    @m_major * 1000 + @m_minor
  end

  def isGreaterThan(other)
    getInt() > other.getInt()
  end

  # non-verbatim
  B41 = GameVersion.new(41, 0)
  B42 = GameVersion.new(42, 0)
  DEFAULT = B42
end
