ZSpaceship = ZSpaceship or {}

ZSpaceship.Professions = ZSpaceship.Professions or {}
ZSpaceship.Professions.Astronaut = CharacterProfession.register("ZSpaceship:Astronaut")

--ZSpaceship.BodyLocations = ZSpaceship.BodyLocations or {}
--ZSpaceship.BodyLocations.Communicator = ItemBodyLocation.register("ZSpaceship:CommunicatorSlot")
--
--local group = BodyLocations.getGroup("Human")
--if group then
--    group:getOrCreateLocation(ZSpaceship.BodyLocations.Communicator)
--else
--    print("BodyLocations group 'Human' not found.")
--end

ZSpaceship.Tags = ZSpaceship.Tags or {}
ZSpaceship.Tags.Communicator    = ItemTag.register("ZSpaceship:CommunicatorTag")
ZSpaceship.Tags.SpaceSuit       = ItemTag.register("ZSpaceship:SpaceSuitTag")
ZSpaceship.Tags.Wetness2Water   = ItemTag.register("ZSpaceship:Wetness2WaterTag")
ZSpaceship.Tags.SuppressRunning = ItemTag.register("ZSpaceship:SuppressRunningTag")
