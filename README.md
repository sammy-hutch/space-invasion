# space-invasion
Spirit Island gameplay with a Twilight Imperium Theme


## TODO
map_generator.gd:
- generate_map_from_config() / load_map_data() / start_fr_layot(): need to add new logic to use the map_layout passed from config screen, rather than takign single sector from dictionary
map_config_screen.gd:
- how to work with the sector scenes
- how to rotate sectors in the grid, and pass rotation info in map layout
sector scenes:
- load info from maps.json
- are they necessary?