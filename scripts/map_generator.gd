extends Node2D

@export_file("*.json") var map_data_path: String
@export var zone_radius: float = 30.0
@export var line_width: float = 2.0
@export var zone_color: Color = Color.CORNFLOWER_BLUE
@export var line_color: Color = Color.WHITE
@export var zone_label_color: Color = Color.BLACK
@export var layout_radius: float = 200.0
@export var zone_font: Font
@export var zone_font_size: int = 20

# Fruchterman-Reingold Layout parameters
@export_group("FR Layout Parameters")
@export var fr_iterations: int = 200
@export var fr_initial_temperature: float = 300.0
@export var cooling_rate: float = 0.99
@export var fr__k_factor: float = 0.5
@export var fr_max_displacement_limit: float = 50.0
@export var fr_boundary_padding: float = 50.0

var ZoneNodeScript = preload("res://scripts/zone_node.gd")

var map_data: Dictionary = {}
var zone_nodes: Dictionary = {}
var zone_positions: Dictionary = {}
var zone_displacements: Dictionary = {}

var current_temperature: float
var current_iteration: int = 0
var is_layout_running: bool = false
var internal_zone_ids: Array = []


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if map_data_path:
		load_map_data()
		if map_data:
			start_fr_layout()
	else:
		printerr("Error: Please assign a 'Map Data Path' in the inspector.")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_layout_running:
		run_fr_iteration()
		update_line_positions()
		center_layout_on_screen()


func load_map_data():
	var file = FileAccess.open(map_data_path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var parse_result = JSON.parse_string(content)
		if parse_result is Dictionary:
			if parse_result.has("A"):
				map_data = parse_result["A"]
			else:
				map_data = parse_result
			print("Map data loaded successfully.")
		else: 
			printerr("Failed to parse JSON: ", parse_result)
		file.close()
	else: printerr("Failed to open map data file: ", map_data_path)


func start_fr_layout():
	for child in get_children():
		child.queue_free()
	zone_nodes.clear()
	zone_positions.clear()
	zone_displacements.clear()
	internal_zone_ids.clear()

	# 1. Initialise Zone Nodes
	var zone_ids = map_data.keys()
	internal_zone_ids = []
	for zone_id_str in zone_ids:
		if map_data.has(zone_id_str) and typeof(map_data[zone_id_str]) == TYPE_DICTIONARY:
			internal_zone_ids.append(zone_id_str)
	
	var viewport_size = get_viewport_rect().size
	for zone_id in internal_zone_ids:
		var zone_node = Node2D.new()
		zone_node.set_script(ZoneNodeScript)
		add_child(zone_node)
		zone_nodes[zone_id] = zone_node

		zone_node.setup(zone_id, zone_radius, zone_color, zone_label_color, zone_font, zone_font_size)

		var rand_x = randf_range(fr_boundary_padding, viewport_size.x - fr_boundary_padding)
		var rand_y = randf_range(fr_boundary_padding, viewport_size.y - fr_boundary_padding)
		var initial_pos = Vector2(rand_x, rand_y)
		zone_positions[zone_id] = initial_pos
		zone_node.position = initial_pos

		zone_displacements[zone_id] = Vector2.ZERO
	
	# 2. Create Line2D nodes
	var drawn_connections = {}
	for zone_id in map_data:
		var connections = map_data[zone_id]["connections"]
		for connected_zone_id in connections:
			if not internal_zone_ids.has(zone_id) or not internal_zone_ids.has(connected_zone_id):
				print("Skipping external connection '%s' from zone '%s'." % [connected_zone_id, zone_id])
				continue
			
			var id1 = str(zone_id)
			var id2 = str(connected_zone_id)
			var connection_key = ""
			if id1 < id2:
				connection_key = "%s-%s" % [id1, id2]
			else:
				connection_key = "%s-%s" % [id2, id1]
			
			if connection_key in drawn_connections:
				continue
			drawn_connections[connection_key] = true
			
			var line = Line2D.new()
			line.add_point(Vector2.ZERO)
			line.add_point(Vector2.ZERO)
			line.width = line_width
			line.default_color = line_color
			add_child(line)

			if not zone_nodes[zone_id].has_meta("connections"):
				zone_nodes[zone_id].set_meta("connections", [])
			zone_nodes[zone_id].get_meta("connections").append({ "line": line, "target": connected_zone_id})
	
	# 3. Adjust drawing order
	for child in get_children():
		if child is Line2D:
			move_child(child, 0)
	
	current_temperature = fr_initial_temperature
	current_iteration = 0
	is_layout_running = true
	print("FR layout started for %d zones." % internal_zone_ids.size())



# func generate_map():
# 	for child in get_children():
# 		child.queue_free()
# 	zone_nodes.clear()
	
# 	# 1. Create and position zone nodes
# 	var zone_ids = map_data.keys()
# 	zone_ids.sort()
# 	var num_zones = zone_ids.size()
# 	var angle_step = TAU / num_zones
	
# 	for i in range(num_zones):
# 		var zone_id = zone_ids[i]
# 		var zone_node = Node2D.new()
# 		zone_node.set_script(ZoneNodeScript)
# 		add_child(zone_node)
# 		zone_nodes[zone_id] = zone_node
		
# 		zone_node.setup(zone_id, zone_radius, zone_color, zone_label_color, zone_font, zone_font_size)
		
# 		var angle = i * angle_step
# 		zone_node.position = Vector2(cos(angle), sin(angle)) * layout_radius + get_viewport_rect().size / 2
		
# 	# 2. Create connection lines
# 	var drawn_connections = {}
# 	for zone_id in map_data:
# 		var current_zone_node = zone_nodes[zone_id]
# 		var connections = map_data[zone_id]["connections"]
		
# 		for connected_zone_id in connections:
# 			if not zone_nodes.has(connected_zone_id):
# 				print("Skipping external connection '%s' from zone '%s'." % [connected_zone_id, zone_id])
# 				continue
			
# 			var target_zone_node = zone_nodes[connected_zone_id]
			
# 			var id1 = str(zone_id)
# 			var id2 = str(connected_zone_id)
# 			var connection_key = ""
# 			if id1 < id2:
# 				connection_key = "%s_%s" % [id1, id2]
# 			else:
# 				connection_key = "%s_%s" % [id2, id1]
			
# 			if connection_key in drawn_connections:
# 				continue
# 			drawn_connections[connection_key] = true
			
# 			var line = Line2D.new()
# 			line.add_point(current_zone_node.position)
# 			line.add_point(target_zone_node.position)
# 			line.width = line_width
# 			line.default_color = line_color
# 			add_child(line)
	
# 	# 3. Adjust drawing order
# 	for child in get_children():
# 		if child is Line2D:
# 			move_child(child, 0)
