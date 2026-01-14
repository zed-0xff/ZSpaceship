class MetaObject
  attr_accessor :type
  attr_accessor :x
  attr_accessor :y
  attr_accessor :room_def
  attr_accessor :used

  def initialize(type, x, y, room_def)
    @type = MetaObjectEnum.id2sym(type)
    @x = x
    @y = y
    @room_def = room_def
    @used = false
  end
end
