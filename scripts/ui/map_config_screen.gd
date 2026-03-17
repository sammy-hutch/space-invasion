extends Control
class_name MapConfigScreen

signal map_configured(map_layout: Dictionary)

@export_dir var available_sectors_directory: String = "res://resources/sectors"
@export var grid_size: Vector2i = Vector2i(5, 5)

var _available_sector_resources: Array[SectorData] = []
var _selected_sector_data: SectorData = null
var _map_layout_data: Dictionary = {}

@onready var sector_selection_list: ItemList = %SectorSelectionList
@onready var map_layout_grid_container: GridContainer = %MapLayoutgrid
@onready var clear_map_button: Button = %ClearMapButton
@onready var generate_map_button: Button = %GenerateMapButton

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
