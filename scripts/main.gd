extends Node2D

@export var map_config_screen_scene: PackedScene = preload("res://scenes/mapConfigScreen.tscn")
@export var map_scene: PackedScene = preload("res://scenes/map.tscn")
@export var mapUi_scene = preload("res://scenes/ui/mapUI.tscn")

@onready var camera_2d: Camera2D = $Camera2D
@onready var canvas_layer: CanvasLayer = $CanvasLayer

signal adjust_camera(viewport_size: Rect2)
signal toggle_zoom(toggle: bool)
signal status_change(reason: String)
signal next_phase_triggered
signal phase_change_triggered(new_phase)

var config_screen: Node
var map: Node
var mapUi: Node
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_load_map_config_screen()
	_load_map()

func _input(event):
	if event.is_action_pressed("ravage_triggered"):
		print("ravage triggered")
		status_change.emit("ravage")
	if event.is_action_pressed("build_triggered"):
		print("build triggered")
		status_change.emit("build")
	if event.is_action_pressed("explore_triggered"):
		print("explore triggered")
		status_change.emit("explore")

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
		map.main = self
		add_to_signal_channel(map, "status_change")
		add_to_signal_channel(map, "next_phase_triggered")
		add_to_signal_channel(map, "phase_change_triggered")
		map.map_generated.connect(_on_map_generated)
		map.toggle_zoom.connect(_toggle_zoom)
		map.phase_changed.connect(_on_phase_changed)
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

func _on_next_phase_triggered():
	next_phase_triggered.emit()
	
func _on_phase_changed(new_phase):
	status_change.emit("phase_change")
	phase_change_triggered.emit(new_phase)
	

## Receives signal from map child scene
func _on_map_generated(current_iteration: int, graph_bounding_box: Rect2):
	adjust_camera.emit(graph_bounding_box)
	mapUi = mapUi_scene.instantiate()
	mapUi.main = self
	mapUi.map = map
	mapUi.next_phase.connect(_on_next_phase_triggered)
	add_to_signal_channel(mapUi, "status_change")
	add_to_signal_channel(mapUi, "phase_change_triggered")
	canvas_layer.add_child(mapUi)
	status_change.emit("general")

###### SIGNAL FUNCTIONS ######
func add_to_signal_channel(node, channel):
	if channel == "status_change":
		self.connect("status_change", Callable(node, "_on_status_change"))
		print("node %s added to status change signal" % node.name)
	elif channel == "next_phase_triggered":
		self.connect("next_phase_triggered", Callable(node, "_on_next_phase_trigger"))
		print("node %s added to phase trigger signal" % node.name)
	elif channel == "phase_change_triggered":
		self.connect("phase_change_triggered", Callable(node, "_on_phase_change_trigger"))
		print("node %s added to phase change trigger signal" % node.name)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
