class RoomDef
  attr_accessor :id, :name, :rects, :objects, :level, :building

  def initialize(id, name)
    @id = id
    @name = name
    @rects = []
    @objects = []
  end
end
