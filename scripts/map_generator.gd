extends Node2D
class_name MapGenerator

signal map_generated(current_iteration: int, graph_bounding_box: Rect2)

@export_file("*.json") var map_data_path: String
@export var zone_radius: float = 50.0
@export var line_width: float = 2.0
@export var sector_color: Color = Color.GREEN_YELLOW
@export var zone_color: Color = Color.CORNFLOWER_BLUE
@export var line_color: Color = Color.WHITE
@export var sector_label_color: Color = Color.BLACK
@export var zone_label_color: Color = Color.BLACK
@export var layout_radius: float = 200.0 # Used for initial random placement
@export var sector_font: Font
@export var zone_font: Font
@export var sector_font_size: int = 20
@export var zone_font_size: int = 20

# Fruchterman-Reingold Layout parameters
@export_group("FR Layout Parameters")
@export var fr_iterations: int = 200
@export var fr_initial_temperature: float = 400.0
@export var fr_cooling_rate: float = 0.99
@export var fr_k_factor: float = 175.0
@export var fr_max_displacement_limit: float = 50.0
@export var fr_bounding_box_padding: float = 50.0

var SectorNodeScript = preload("res://scripts/sector_node.gd")
var ZoneNodeScript = preload("res://scripts/zone_node.gd")

var map_data: Dictionary = {} # Dict of maps.json data file
var sector_nodes: Dictionary = {} # Dict of sector_node.gd Node2D objects
var zone_nodes: Dictionary = {} # Dict of zone_node.gd Node2D objects
var zone_positions: Dictionary = {}
var zone_displacements: Dictionary = {}

var current_temperature: float
var current_iteration: int = 0
var is_layout_running: bool = false
var internal_sector_ids: Array = []
var internal_zone_ids: Array = []

var map_style = "standard"

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
	print("map layout: ", map_layout)
	if map_data_path:
		load_map_data(map_layout)
		if map_data:
			configure_map_layout()
			start_fr_layout()
	else:
		printerr("Error: Please assign a 'Map Data Path' in the inspector.")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_layout_running:
		run_fr_iteration()
		update_line_positions() # remove this later

func load_map_data(map_layout: Dictionary):
	var file = FileAccess.open(map_data_path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var parse_result = JSON.parse_string(content)
		if parse_result is Dictionary:
			for position in map_layout.keys():
				var sector_data: SectorData = map_layout[position]
				var sector_id: String = sector_data.sector_id
				if parse_result.has(sector_id):
					map_data[sector_id] = parse_result[sector_id]
					map_data[sector_id]["grid_pos"] = position
					map_data[sector_id]["neighbours"] = {}
					print(map_data[sector_id]["grid_pos"])
				else:
					print("no data found for sector id %s in map_data file" % sector_id)
				print("Map data loaded successfully.")
			print("map data: ", map_data)
		else: 
			printerr("Failed to parse JSON: ", parse_result)
		file.close()
	else: printerr("Failed to open map data file: ", map_data_path)

func configure_map_layout():
	# --- 1. Identify Sector Neighbours ---
	print("--- Identifying Sector Neighbours ---")
	for u_sector_key in map_data:
		var u_sector_data = map_data[u_sector_key]
		var u_pos = u_sector_data["grid_pos"]

		for v_sector_key in map_data:
			if u_sector_key == v_sector_key: continue

			var v_sector_data = map_data[v_sector_key]
			var v_pos = v_sector_data["grid_pos"]

			if v_pos.x == u_pos.x + 1 and v_pos.y == u_pos.y: u_sector_data["neighbours"]["E"] = v_sector_key
			elif v_pos.x == u_pos.x - 1 and v_pos.y == u_pos.y: u_sector_data["neighbours"]["W"] = v_sector_key
			elif v_pos.x == u_pos.x and v_pos.y == u_pos.y + 1: u_sector_data["neighbours"]["S"] = v_sector_key
			elif v_pos.x == u_pos.x and v_pos.y == u_pos.y - 1: u_sector_data["neighbours"]["N"] = v_sector_key

		print("Sector: ", u_sector_key, " Neighbours: ", u_sector_data["neighbours"])

	# --- 2. Apply Layout Logic (Rotation) ---
	print("\n--- Applying Layout Logic (Rotation) ---")
	if map_style == "standard":
		for u_sector_key in map_data:
			var u_sector_data = map_data[u_sector_key]
			if "W" in u_sector_data["neighbours"]:
				print("Rotating Sector ", u_sector_key, " 180 degrees due to East neighbour.")
				rotate_sector(u_sector_key)
	elif map_style == "frontier":
		pass # TODO: add logic for other types

	# --- 3. Identify Connections Across Sectors ---
	print("\n--- Identifying Connections Across Sectors ---")
	var border_connection_rules = {
		"E": {  # If v_sector is East of u_sector
			"NE": "NW", # u's NW connects to v's NE
			"E":  "W",  # u's W connects to v's E
			"SE": "SW"   # u's SW connects to v's SE
		},
		"W": {  # If v_sector is West of u_sector
			"NW": "NE",
			"W":  "E",
			"SW": "SE"
		},
		"N": {  # If v_sector is North of u_sector
			"NE": "SE",
			"N":  "S",
			"NW": "SW"
		},
		"S": {  # If v_sector is South of u_sector
			"SE": "NE",
			"S":  "N",
			"SW": "NW"
		}
	}

	for u_sector_key in map_data:
		var u_sector_data = map_data[u_sector_key]

		for neighbour_direction in u_sector_data["neighbours"]:
			var v_sector_key = u_sector_data["neighbours"][neighbour_direction]
			var v_sector_data = map_data[v_sector_key]

			var rules_for_this_border = border_connection_rules[neighbour_direction]

			# Iterate through all zones in u_sector
			for u_zone_key in u_sector_data["zones"]:
				var u_zone_data = u_sector_data["zones"][u_zone_key]
				if not ("positions" in u_zone_data): continue

				var u_zone_positions = u_zone_data["positions"]

				# Iterate through all zones in v_sector
				for v_zone_key in v_sector_data["zones"]:
					var v_zone_data = v_sector_data["zones"][v_zone_key]
					if not ("positions" in v_zone_data): continue

					var v_zone_positions = v_zone_data["positions"]

					# Check for matching positions based on rules
					for u_pos in u_zone_positions:
						for v_pos in v_zone_positions:
							if rules_for_this_border.has(u_pos) and rules_for_this_border[u_pos] == v_pos:
								if not v_zone_key in u_zone_data["connections"]:
									u_zone_data["connections"].append(v_zone_key)
								# Optional: If connections are bidirectional, add the reverse
								# if not u_zone_key in v_zone_data["connections"]:
								#	v_zone_data["connections"].append(u_zone_key)
								print("  Connection found: ", u_sector_key, ":", u_zone_key, "(", u_pos, ") <-> ", v_sector_key, ":", v_zone_key, "(", v_pos, ")")

func rotate_sector(sector_key: String):
	# This function performs a 180-degree rotation (N<->S, E<->W, etc.)
	var sector_data = map_data[sector_key]
	var rotation_map = {
		"N": "S", "NE": "SW", "E": "W", "SE": "NW",
		"S": "N", "SW": "NE", "W": "E", "NW": "SE",
		"C": "C" # Center position often remains unchanged
	}

	for zone_key in sector_data["zones"]:
		var zone_data = sector_data["zones"][zone_key]
		if "positions" in zone_data:
			var new_positions = []
			for original_pos in zone_data["positions"]:
				if rotation_map.has(original_pos):
					new_positions.append(rotation_map[original_pos])
				else:
					new_positions.append(original_pos)
			zone_data["positions"] = new_positions

func start_fr_layout():
	for child in get_children():
		child.queue_free()
	sector_nodes.clear()
	zone_nodes.clear()
	zone_positions.clear()
	zone_displacements.clear()
	internal_sector_ids.clear()
	internal_zone_ids.clear()

	# 1. Initialise Sector & Zone Nodes with random positions around (0,0)

	var sector_ids_from_data = map_data.keys()
	for sector_id_str in sector_ids_from_data:
		if map_data.has(sector_id_str) and typeof(map_data[sector_id_str]) == TYPE_DICTIONARY:
			internal_sector_ids.append(sector_id_str)
			
			var sector_node = Node2D.new()
			sector_node.set_script(SectorNodeScript)
			sector_node.name = sector_id_str
			add_child(sector_node)
			sector_nodes[sector_id_str] = sector_node
			sector_node.setup(sector_id_str, sector_color, sector_label_color, sector_font, sector_font_size)

			var sector_data = map_data[sector_id_str]
			var zone_ids = sector_data["zones"].keys()
			for zone_id_str in zone_ids:
				if sector_data["zones"].has(zone_id_str) and typeof(sector_data["zones"][zone_id_str]) == TYPE_DICTIONARY:
					internal_zone_ids.append(zone_id_str)
					
					var zone_node = Node2D.new()
					zone_node.set_script(ZoneNodeScript)
					zone_node.name = zone_id_str
					sector_node.add_child(zone_node)
					zone_nodes[zone_id_str] = zone_node

					zone_node.setup(zone_id_str, zone_radius, zone_color, zone_label_color, zone_font, zone_font_size)

					var rand_x = randf_range(-layout_radius, layout_radius)
					var rand_y = randf_range(-layout_radius, layout_radius)
					var initial_pos = Vector2(rand_x, rand_y)
					zone_positions[zone_id_str] = initial_pos
					zone_displacements[zone_id_str] = Vector2.ZERO

	# Set initial visual positions for sectors and zones based on their absolute calculated positions
	_update_sector_positions_and_zone_relatives()

	# 2. Create Line2D nodes
	var drawn_connections = {}
	for sector_id in map_data:
		for zone_id in map_data[sector_id]["zones"]:
			var connections = map_data[sector_id]["zones"][zone_id]["connections"]
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

	# 3. Adjust drawing order (lines behind nodes)
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
		
		var final_bounding_box = _calculate_graph_bounding_box()
		_adjust_node_positions_to_origin(final_bounding_box)
		_update_sector_positions_and_zone_relatives()
		update_line_positions()
		map_generated.emit(current_iteration, final_bounding_box)
		print("Map Generation emitted. Generation complete.")
		return

	for zone_id in internal_zone_ids:
		zone_displacements[zone_id] = Vector2.ZERO

	# Repulsion calculations
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

	# Attraction calculations
	for sector_id in map_data:
		for u_id in map_data[sector_id]["zones"]:
			var connections = map_data[sector_id]["zones"][u_id]["connections"]
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

	# Update absolute positions based on displacement and temperature
	for zone_id in internal_zone_ids:
		var displacement = zone_displacements[zone_id]
		var disp_length = displacement.length()

		var actual_displacement = displacement.normalized() * min(disp_length, current_temperature, fr_max_displacement_limit)
		zone_positions[zone_id] += actual_displacement

	_update_sector_positions_and_zone_relatives()

	# Cooldown
	current_temperature *= fr_cooling_rate
	current_iteration += 1

func _update_sector_positions_and_zone_relatives():
	# Update the position of each SectorNode
	for sector_id in internal_sector_ids:
		var sector_node = sector_nodes[sector_id]
		var zones_in_sector_positions = []
		
		for zone_id in map_data[sector_id]["zones"].keys():
			if internal_zone_ids.has(zone_id):
				zones_in_sector_positions.append(zone_positions[zone_id])
		
		if zones_in_sector_positions.is_empty():
			sector_node.position = Vector2.ZERO
			continue

		var avg_pos = Vector2.ZERO
		for pos in zones_in_sector_positions:
			avg_pos += pos
		sector_node.position = avg_pos / zones_in_sector_positions.size()

	# Update the position of each ZoneNode relative to its parent SectorNode
	for zone_id in internal_zone_ids:
		var zone_node = zone_nodes[zone_id]
		var sector_node = zone_node.get_parent() as Node2D
		if sector_node:
			zone_node.position = zone_positions[zone_id] - sector_node.position
		else:
			zone_node.position = zone_positions[zone_id]

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
					line.set_point_position(0, zone_positions[zone_id])
					line.set_point_position(1, zone_positions[target_id])
				else:
					line.visible = false

func _calculate_graph_bounding_box() -> Rect2:
	if internal_zone_ids.is_empty():
		return Rect2(0, 0, 0, 0)
		print("no zones in internal_zone_ids!")

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

	min_x -= fr_bounding_box_padding
	max_x += fr_bounding_box_padding
	min_y -= fr_bounding_box_padding
	max_y += fr_bounding_box_padding

	var size = Vector2(max_x - min_x, max_y - min_y)
	return Rect2(min_x, min_y, size.x, size.y)

func _adjust_node_positions_to_origin(bounding_box: Rect2):
	var offset = -bounding_box.position 

	for zone_id in internal_zone_ids:
		zone_positions[zone_id] += offset
