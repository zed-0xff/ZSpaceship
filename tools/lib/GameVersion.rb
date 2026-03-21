class GameVersion
  attr_reader :m_major, :m_minor, :m_suffix

  def initialize(major, minor, suffix = nil)
    @m_major  = major
    @m_minor  = minor
    @m_suffix = suffix
  end

  def to_s
    "#{@m_major}.#{@m_minor}#{@m_suffix}"
  end

  def <=>(other)
    return @m_major  <=> other.m_major  if @m_major  != other.m_major
    return @m_minor  <=> other.m_minor  if @m_minor  != other.m_minor
    return @m_suffix <=> other.m_suffix if @m_suffix != other.m_suffix
    0
  end

  def >(other)
    (self <=> other) > 0
  end

  B41 = GameVersion.new(41, 0)
  B42 = GameVersion.new(42, 0)

  DEFAULT = B42
end
