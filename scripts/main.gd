extends Node2D

@export var map_config_screen_scene: PackedScene = preload("res://scenes/mapConfigScreen.tscn")
@export var map_generator_scene: PackedScene = preload("res://scenes/map_generator.tscn")

@onready var camera_2d: Camera2D = $Camera2D

signal adjust_camera(viewport_size: Rect2)

var config_screen: Node
var map_generator: Node

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_load_map_config_screen()
	_load_map_generator()


###### INSTANTIATE CHILDREN FUNCTIONS ######
func _load_map_config_screen():
	config_screen = map_config_screen_scene.instantiate() as MapConfigScreen
	if config_screen:
		add_child(config_screen)
		config_screen.map_configured.connect(_on_map_configured)
	else:
		push_error("Failed to instantiate MapConfigScreen.")

func _load_map_generator():
	map_generator = map_generator_scene.instantiate() as MapGenerator
	if map_generator:
		add_child(map_generator)
		map_generator.map_generated.connect(_on_map_generated)
	else:
		push_error("Failed to instantiate MapGenerator")


###### RUN CHILDREN FUNCTIONS ######
func _run_map_generator(map_layout: Dictionary):
	if map_generator:
		if map_generator.has_method("generate_map_from_config"):
			map_generator.generate_map_from_config(map_layout)
		else:
			push_error("MapGenerationNode does not have 'generate_map_from_config' method!")
	else:
		push_error("MapGenerationNode reference is null after configuration.")
	

###### SIGNAL CALLBACKS ######
func _on_map_configured(map_layout: Dictionary):
	print("Received map configuration from screen")
	_run_map_generator(map_layout)

func _on_map_generated(current_iteration: int, graph_bounding_box: Rect2):
	print("Map generated after %d iterations" % current_iteration)
	print("Graph Bounding Box: ", graph_bounding_box)
	emit_signal("adjust camera", graph_bounding_box)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
