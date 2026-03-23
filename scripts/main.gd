extends Node2D

@export var map_config_screen_scene: PackedScene = preload("res://scenes/mapConfigScreen.tscn")
@export var map_scene: PackedScene = preload("res://scenes/map.tscn")

@onready var camera_2d: Camera2D = $Camera2D

signal adjust_camera(viewport_size: Rect2)
signal toggle_zoom(toggle: bool)

var config_screen: Node
var map: Node

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_load_map_config_screen()
	_load_map()


###### INSTANTIATE CHILDREN FUNCTIONS ######

## Instantiates map_config_screen scene and adds it as child of main
func _load_map_config_screen():
	config_screen = map_config_screen_scene.instantiate() as MapConfigScreen
	if config_screen:
		add_child(config_screen)
		config_screen.map_configured.connect(_on_map_configured)
		config_screen.screen_loaded.connect(_on_screen_loaded)
		config_screen.toggle_zoom.connect(_toggle_zoom)
	else:
		push_error("Failed to instantiate MapConfigScreen.")

## Instantiates map scene and adds it as child of main
func _load_map():
	map = map_scene.instantiate() as Map
	if map:
		add_child(map)
		map.map_generated.connect(_on_map_generated)
		map.toggle_zoom.connect(_toggle_zoom)
	else:
		push_error("Failed to instantiate MapGenerator")


###### RUN CHILDREN FUNCTIONS ######

## Triggers the generate_map_from_config() function of map scene.
## Accepts map_layout from map_config_screen.
func _run_map_generator(map_layout: Dictionary):
	if map:
		if map.has_method("generate_map_from_config"):
			map.generate_map_from_config(map_layout)
		else:
			push_error("MapGenerationNode does not have 'generate_map_from_config' method!")
	else:
		push_error("MapGenerationNode reference is null after configuration.")


###### SIGNAL CALLBACKS ######

## Toggles zoom by accepting bool value (true = zoom allowed)
func _toggle_zoom(toggle: bool):
	toggle_zoom.emit(toggle)

## Recieves signal from map_config_screen child scene, prompting generation of map in map scene.
func _on_map_configured(map_layout: Dictionary):
	_run_map_generator(map_layout)

## Recieves signal from any child node prompting adjustment of camera to match new screen parameters
func _on_screen_loaded(screen_rect: Rect2):
	print("Received 'screen_loaded' signal from config screen")
	print("screen rect: ", screen_rect)
	adjust_camera.emit(screen_rect)

## Receives signal from map child scene
func _on_map_generated(current_iteration: int, graph_bounding_box: Rect2):
	adjust_camera.emit(graph_bounding_box)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
