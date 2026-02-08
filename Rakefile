task :default => [:tiles, :map]

task :map do
  sh "./tools/compiler.rb spaceship.yaml -o 42.13/media/maps/ZSpaceship/"
end

task :tiles do
  sh "./tools/tilepacker.rb tiles/zspaceship_* --name zspaceship --pack-out ./common/media/texturepacks/zspaceship.pack --tiles-out ./common/media/zspaceship.tiles"
end
