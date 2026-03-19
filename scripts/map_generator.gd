extends Node2D
class_name MapGenerator

signal map_generated(current_iteration: int)

@export_file("*.json") var map_data_path: String
@export var zone_radius: float = 50.0
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
@export var fr_initial_temperature: float = 400.0
@export var fr_cooling_rate: float = 0.99
@export var fr_k_factor: float = 175.0
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

# Tuning Tips for FR Parameters
# - fr_k_factor: higher = wider node spacing, lower = tighter packed nodes. good heuristic: k = sqrt(ViewportArea / NumberOfNodes)
# - fr_initial_temperature: higher = better overall result, lower = faster settling
# - fr_cooling_rate: higher = more iterations but takes longer. range perhaps 0.98 to 0.995
# - fr_iterations: need upper bound to prevent infinite loops


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


func generate_map_from_config(map_layout: Dictionary):
	print("MapGenerator: Starting map generation with custom config...")
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
		update_line_positions() # remove this later
		center_layout_on_screen() # remove this later


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


func run_fr_iteration():
	# Exit if complete
	if current_iteration >= fr_iterations or current_temperature <= 0.1:
		print("FR layout finished after %d iterations. Final temperature: %f" % [current_iteration, current_temperature])
		is_layout_running = false
		center_layout_on_screen()
		update_line_positions()
		map_generated.emit(current_iteration)
		print("Map Generation emitted. Generation complete.")
		return
	
	for zone_id in internal_zone_ids:
		zone_displacements[zone_id] = Vector2.ZERO
	
	# Repulsion calcs
	for i in range(internal_zone_ids.size()):
		var u_id = internal_zone_ids[i]
		for j in range(i+1, internal_zone_ids.size()):
			var v_id = internal_zone_ids[j]
			var p_u = zone_positions[u_id]
			var p_v = zone_positions[v_id]

			var delta = p_u - p_v
			var distance = max(0.001, delta.length())
			var force_magnitude = (fr_k_factor * fr_k_factor) / distance
			var force_vector = delta.normalized() * force_magnitude

			zone_displacements[u_id] += force_vector
			zone_displacements[v_id] -= force_vector
	
	# Attraction calcs
	for u_id in internal_zone_ids:
		var connections = map_data[u_id]["connections"]
		for v_id in connections:
			if not internal_zone_ids.has(v_id):
				continue
			
			var p_u = zone_positions[u_id]
			var p_v = zone_positions[v_id]

			var delta = p_u - p_v
			var distance = max(0.001, delta.length())
			var force_magnitude = (distance * distance) / fr_k_factor
			var force_vector = delta.normalized() * force_magnitude

			zone_displacements[u_id] -= force_vector
			zone_displacements[v_id] += force_vector
	
	# Positioning
	var viewport_rect = get_viewport_rect()
	for zone_id in internal_zone_ids:
		var displacement = zone_displacements[zone_id]
		var disp_length = displacement.length()

		var actual_displacement = displacement.normalized() * min(disp_length, current_temperature, fr_max_displacement_limit)
		zone_positions[zone_id] += actual_displacement
		zone_positions[zone_id].x = clamp(zone_positions[zone_id].x, fr_boundary_padding, viewport_rect.size.x - fr_boundary_padding)
		zone_positions[zone_id].y = clamp(zone_positions[zone_id].y, fr_boundary_padding, viewport_rect.size.y - fr_boundary_padding)

		zone_nodes[zone_id].position = zone_positions[zone_id]
	
	# Cooldown
	current_temperature *= fr_cooling_rate
	current_iteration += 1


func update_line_positions():
	for zone_id in internal_zone_ids:
		var node = zone_nodes[zone_id]
		if node.has_meta("connections"):
			var connections_data = node.get_meta("connections")
			for conn in connections_data:
				var line: Line2D = conn["line"]
				var target_id = conn["target"]
				if internal_zone_ids.has(target_id): 
					var target_node = zone_nodes[target_id]
					line.set_point_position(0, node.position)
					line.set_point_position(1, target_node.position)
				else:
					line.visible = false


func center_layout_on_screen():
	if internal_zone_ids.is_empty():
		return
	
	var min_x = INF
	var max_x = -INF
	var min_y = INF
	var max_y = -INF

	for zone_id in internal_zone_ids:
		var pos = zone_positions[zone_id]
		min_x = min(min_x, pos.x)
		max_x = max(max_x, pos.x)
		min_y = min(min_y, pos.y)
		max_y = max(max_y, pos.y)
	
	var graph_center = Vector2((min_x + max_x) / 2, (min_y + max_y) / 2)
	var viewport_center = get_viewport_rect().size / 2
	var offset = viewport_center - graph_center

	for zone_id in internal_zone_ids:
		zone_positions[zone_id] += offset
		zone_nodes[zone_id].position = zone_positions[zone_id]
	
	var viewport_rect = get_viewport_rect()
	for zone_id in internal_zone_ids:
		zone_positions[zone_id].x = clamp(zone_positions[zone_id].x, fr_boundary_padding, viewport_rect.size.x - fr_boundary_padding)
		zone_positions[zone_id].y = clamp(zone_positions[zone_id].y, fr_boundary_padding, viewport_rect.size.y - fr_boundary_padding)
		zone_nodes[zone_id].position = zone_positions[zone_id]
