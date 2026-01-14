class RoomID
  class << self
    def makeID(cellX, cellY, idx)
      hi = (cellY << 16) | cellX
      (hi << 32) | idx
    end

    def getIndex(id)
      id & 0xFFFFFFFF
    end
  end
end
