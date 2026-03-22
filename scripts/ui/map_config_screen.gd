extends Control
class_name MapConfigScreen

signal map_configured(map_layout: Dictionary)

@export_dir var available_sectors_directory: String = "res://resources/sectors/"
@export var grid_size: Vector2i = Vector2i(5, 5)

var _available_sector_resources: Array[SectorData] = []
var _selected_sector_data: SectorData = null
var _map_layout_data: Dictionary = {}

@onready var sector_selection_list: ItemList = $MainVBox/TopSectionHBox/SectorSelectionPanel/SectorSelectionList
@onready var map_layout_grid_container: GridContainer = $MainVBox/TopSectionHBox/MapLayoutPanel/MapLayoutGrid
@onready var clear_map_button: Button = $MainVBox/BottomButtonsHBox/ClearMapButton
@onready var generate_map_button: Button = $MainVBox/BottomButtonsHBox/GenerateMapButton

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_load_available_sectors()
	_setup_sector_selection_list()
	_setup_map_layout_grid()
	
	sector_selection_list.item_selected.connect(_on_sector_selection_list_item_selected)
	clear_map_button.pressed.connect(_on_clear_map_button_pressed)
	generate_map_button.pressed.connect(_on_generate_map_button_pressed)
	
	if not _available_sector_resources.is_empty():
		sector_selection_list.select(0)
		_on_sector_selection_list_item_selected(0)

func _load_available_sectors():
	var dir = DirAccess.open(available_sectors_directory)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			print("file name: ", file_name)
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var path = available_sectors_directory + file_name
				print("path: ", path)
				var resource = ResourceLoader.load(path)
				if resource is SectorData:
					_available_sector_resources.append(resource)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		push_error("Could not open directory for sectors: %s" % available_sectors_directory)
	_available_sector_resources.sort_custom(func(a,b): return a.sector_id < b.sector_id)
	for i in _available_sector_resources:
		print("available resource name: ", i.sector_id)

func _setup_sector_selection_list():
	# sector_selection_list.clear()
	for sector_data in _available_sector_resources:
		var item_idx = sector_selection_list.add_item(sector_data.sector_id, sector_data.preview_texture)

func _setup_map_layout_grid():
	#for child in map_layout_grid_container.get_children():
		#child.queue_free()
	#_map_layout_data.clear()
	
	map_layout_grid_container.columns = grid_size.x
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var cell = preload("res://scenes/mapGridCell.tscn").instantiate() as MapGridCell
			cell.grid_position = Vector2(x,y)
			cell.cell_clicked.connect(_on_map_grid_cell_clicked)
			map_layout_grid_container.add_child(cell)
			cell.update_display()

func _get_cell_at_position(position: Vector2) -> MapGridCell:
	var index = int(position.y * grid_size.x + position.x)
	if index >= 0 and index < map_layout_grid_container.get_child_count():
		return map_layout_grid_container.get_child(index) as MapGridCell
	return null


###### SIGNAL CALLBACKS ######
func _on_sector_selection_list_item_selected(index: int):
	if index >= 0 and index < _available_sector_resources.size():
		_selected_sector_data = _available_sector_resources[index]
	else:
		_selected_sector_data = null

func _on_map_grid_cell_clicked(position: Vector2):
	var cell = _get_cell_at_position(position)
	if not cell: return
	
	if _map_layout_data.has(position):
		_map_layout_data.erase(position)
		cell.assigned_sector_data = null
		print("Removed sector at ", position)
	elif _selected_sector_data:
		_map_layout_data[position] = _selected_sector_data
		cell.assigned_sector_data = _selected_sector_data
		print("Placed '%s' at %s" % [_selected_sector_data.sector_id, position])
	else:
		print("No sector selected to place.")

func _on_clear_map_button_pressed():
	_map_layout_data.clear()
	for child in map_layout_grid_container.get_children():
		if child is MapGridCell:
			child.assigned_sector_data = null
	print("Map layout cleared.")

func _on_generate_map_button_pressed():
	if _map_layout_data.is_empty():
		print("Warning: No sectors placed. Generating an empty map.")
	
	map_configured.emit(_map_layout_data)
	print(_map_layout_data)
	print("Map configuration emitted. Configuration screen will now close.")
	queue_free()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
