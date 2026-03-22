# space-invasion
Spirit Island gameplay with a Twilight Imperium Theme


## TODO
map_generator.gd:
- generate_map_from_config() / load_map_data() / start_fr_layot(): need to add new logic to use the map_layout passed from config screen, rather than takign single sector from dictionary
- run generation all as one load step, rather than as part of process
map_config_screen.gd:
- how to work with the sector scenes
- add number of boards item list determines grid size
- add map styles item list, which determines grid layout:
    - standard: boards face back-to-back where possible, try to form as condensed a shape as possible
    - border: boards line up in single file, all facing same way
    - frontier: boards line up in single file but alternate which way they face
sector scenes:
- load info from maps.json
- are they necessary?