# from lua/server/Map/MetaEnum.lua
class MetaObjectEnum
    @@hash = {
      DoorW: 1,
      DoorE: 2,
      DoorN: 3,
      DoorS: 4,
      Chair: 5,
      Bed:   6,
    }
    @@rhash = @@hash.invert

  class << self
    def id2sym(id)
      @@rhash[id]
    end

    def sym2id(sym)
      @@hash[sym]
    end
  end
end
