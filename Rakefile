task :default => [:tiles, :map]

desc "build map"
task :map do
  sh "./tools/compiler.rb map.yml -o 42.13/media/maps/ZSpaceship/"
end

desc "build tiles"
task :tiles do
  sh "./tools/tilepacker.rb tiles/zspaceship_*.{json,png} --name zspaceship --pack-out ./common/media/texturepacks/zspaceship.pack --tiles-out ./common/media/zspaceship.tiles"
end
