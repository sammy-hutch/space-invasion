# space-invasion
Spirit Island gameplay with a Twilight Imperium Theme


## TODO
map_generator.gd:
- pull custom data about zones (colour etc) from maps.json instead of as vars on map_generator script
- improve Fruchterman-Reingold so nodes & lines don't overlap each other so much (reduce repulsion force, add a minimum distance each node needs to be from each other)
map_config_screen.gd:
- how to work with the sector scenes
- add number of boards item list determines grid size
- add map styles item list, which determines grid layout:
    - standard: boards face back-to-back where possible, try to form as condensed a shape as possible
    - border: boards line up in single file, all facing same way
    - frontier: boards line up in single file but alternate which way they face
- can only select each sector once
sector scenes:
- load info from maps.json
- are they necessary?