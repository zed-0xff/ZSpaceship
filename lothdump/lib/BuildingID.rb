class BuildingID
  class << self
    def makeID(cellX, cellY, idx)
      hi = cellX | (cellY << 16)
      (hi << 32) | idx
    end
  end
end
