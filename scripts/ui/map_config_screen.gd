extends Control
class_name MapConfigScreen

signal map_configured(map_layout: Dictionary)
signal screen_loaded(screen_rect: Rect2)
signal toggle_zoom(toggle: bool)

@export_file("*.json") var map_styles_path: String
@export_dir var available_sectors_directory: String = "res://resources/sectors/"
@export var grid_size: Vector2i = Vector2i(5, 5)

@onready var sector_selection_list: ItemList = $MainVBox/TopSectionHBox/SectorSelectionPanel/SectorSelectionList
@onready var map_layout_grid_container: GridContainer = $MainVBox/TopSectionHBox/MapLayoutPanel/MapLayoutGrid
@onready var clear_map_button: Button = $MainVBox/BottomButtonsHBox/ClearMapButton
@onready var generate_map_button: Button = $MainVBox/BottomButtonsHBox/GenerateMapButton
@onready var map_style_selection_list: ItemList = $MainVBox/TopSectionHBox/MapSettings/MapStyleSelectionList
@onready var sector_count_selection_list: ItemList = $MainVBox/TopSectionHBox/MapSettings/SectorCountSelectionList

var _available_sector_resources: Array[SectorData] = []
var _available_map_styles: Array = []
var _available_sector_counts: Array = ["1", "2", "3", "4", "5", "6"]
var _selected_sector_data: SectorData = null
var _selected_map_style: String = ""
var _selected_sector_count: String = "1"
var _map_layout_data: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_load_available_sectors()
	_load_available_map_styles()
	
	_setup_sector_selection_list()
	_setup_map_style_selection_list()
	_setup_sector_count_list()
	
	sector_selection_list.item_selected.connect(_on_sector_selection_list_item_selected)
	map_style_selection_list.item_selected.connect(_on_map_style_selection_list_item_selected)
	sector_count_selection_list.item_selected.connect(_on_sector_count_selection_list_item_selected)
	clear_map_button.pressed.connect(_on_clear_map_button_pressed)
	generate_map_button.pressed.connect(_on_generate_map_button_pressed)
	
	if not _available_sector_resources.is_empty():
		sector_selection_list.select(0)
		_on_sector_selection_list_item_selected(0)
	
	if not _available_map_styles.is_empty():
		map_style_selection_list.select(0)
		_on_map_style_selection_list_item_selected(0)
	
	if not _available_sector_counts.is_empty():
		sector_count_selection_list.select(0)
		_on_sector_count_selection_list_item_selected(0)
	
	_update_map_layout_grid()
	
	await get_tree().process_frame
	var screen_global_rect: Rect2 = _get_overall_bounding_rect(self)
	screen_loaded.emit(screen_global_rect)
	
	toggle_zoom.emit(false)


###### LOAD DATA FUNCTIONS ######

## Loads sector resources from directory
func _load_available_sectors():
	var dir = DirAccess.open(available_sectors_directory)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var path = available_sectors_directory + file_name
				var resource = ResourceLoader.load(path)
				if resource is SectorData:
					_available_sector_resources.append(resource)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		push_error("Could not open directory for sectors: %s" % available_sectors_directory)
	_available_sector_resources.sort_custom(func(a,b): return a.sector_id < b.sector_id)

## loads map styles from json data file
func _load_available_map_styles():
	var file = FileAccess.open(map_styles_path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var parse_result = JSON.parse_string(content)
		if parse_result is Dictionary:
			for map_style in parse_result.keys():
				_available_map_styles.append(parse_result[map_style])
		else: 
			printerr("Failed to parse JSON: ", parse_result)
		file.close()
	else: printerr("Failed to open map data file: ", map_styles_path)
	_available_map_styles.sort_custom(func(a,b): return a["style_name"] < b["style_name"])


###### SETUP FUNCTIONS ######

func _setup_sector_selection_list():
	for sector_data in _available_sector_resources:
		var item_idx = sector_selection_list.add_item(sector_data.sector_id, sector_data.preview_texture)

func _setup_map_style_selection_list():
	for map_style in _available_map_styles:
		var item_idx = map_style_selection_list.add_item(map_style["style_name"])

func _setup_sector_count_list():
	for sector_count in _available_sector_counts:
		var item_idx = sector_count_selection_list.add_item(sector_count)
		print("sector count added: ", sector_count)

func _update_map_layout_grid():
	# clear existing settings
	if map_layout_grid_container.get_child_count() != 0:
		for n in map_layout_grid_container.get_children():
			map_layout_grid_container.remove_child(n)
			n.queue_free()
	
	# update grid size
	if _selected_map_style == "standard": 
		grid_size.x = 2
		grid_size.y = ceil(int(_selected_sector_count)/int(2))
	else: 
		grid_size.x = 1
		grid_size.y = int(_selected_sector_count)
	
	# build grid
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


###### HELPER FUNCTIONS ######

## helper function for finding full extent of scene size
func _get_overall_bounding_rect(node: Control) -> Rect2:
	var combined_rect: Rect2
	var is_first_visible_element = true
	
	if node.visible:
		combined_rect = node.get_global_rect()
		is_first_visible_element = false
	
	for child in node.get_children():
		if child.visible:
			if child is Control:
				var child_rect = _get_overall_bounding_rect(child)
				
				if child_rect.size.x > 0 or child_rect.size.y > 0:
					if is_first_visible_element:
						combined_rect = child_rect
						is_first_visible_element = false
					else:
						combined_rect = combined_rect.merge(child_rect)
	
	return combined_rect


###### SIGNAL CALLBACKS ######

func _on_sector_selection_list_item_selected(index: int):
	if index >= 0 and index < _available_sector_resources.size():
		_selected_sector_data = _available_sector_resources[index]
	else:
		_selected_sector_data = null

func _on_map_style_selection_list_item_selected(index: int):
	if index >= 0 and index < _available_map_styles.size():
		_selected_map_style = _available_map_styles[index]["style_name"]
		print("selected map style: ", _selected_map_style	)
	else:
		_selected_map_style = _available_map_styles[0]
	_update_map_layout_grid()

func _on_sector_count_selection_list_item_selected(index: int):
	if index >= 0 and index < _available_sector_counts.size():
		_selected_sector_count = _available_sector_counts[index]
		print("selected sector count: ", _selected_sector_count)
	else:
		_selected_sector_count = _available_sector_counts[0]
		print("else condition")
	_update_map_layout_grid()

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
	
	toggle_zoom.emit(true)
	map_configured.emit(_map_layout_data)
	print(_map_layout_data)
	print("Map configuration emitted. Configuration screen will now close.")
	queue_free()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
