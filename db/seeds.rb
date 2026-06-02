# Load seed files in deterministic order so local setup remains repeatable.
Dir[Rails.root.join("db/seeds/*.rb")].sort.each do |seed_file|
  load seed_file
end
