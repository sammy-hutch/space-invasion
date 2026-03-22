extends Node2D

@export var map_config_screen_scene: PackedScene = preload("res://scenes/mapConfigScreen.tscn")
@export var map_scene: PackedScene = preload("res://scenes/map.tscn")

@onready var camera_2d: Camera2D = $Camera2D

signal adjust_camera(viewport_size: Rect2)

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
	else:
		push_error("Failed to instantiate MapConfigScreen.")

## Instantiates map scene and adds it as child of main
func _load_map():
	map = map_scene.instantiate() as Map
	if map:
		add_child(map)
		map.map_generated.connect(_on_map_generated)
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

## Recieves signal from map_config_screen child scene, prompting generation of map in map scene.
func _on_map_configured(map_layout: Dictionary):
	_run_map_generator(map_layout)

## Receives signal from map child scene
func _on_map_generated(current_iteration: int, graph_bounding_box: Rect2):
	adjust_camera.emit(graph_bounding_box)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
