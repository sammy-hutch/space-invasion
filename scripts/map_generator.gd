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

var ZoneNodeScript = preload("res://scripts/zone_node.gd")

var map_data: Dictionary = {}
var zone_nodes: Dictionary = {}


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if map_data_path:
		load_map_data()
		if map_data:
			generate_map()
	else:
		printerr("Error: Please assign a 'Map Data Path' in the inspector.")


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


func generate_map():
	for child in get_children():
		child.queue_free()
	zone_nodes.clear()
	
	# 1. Create and position zone nodes
	var zone_ids = map_data.keys()
	zone_ids.sort()
	var num_zones = zone_ids.size()
	var angle_step = TAU / num_zones
	
	for i in range(num_zones):
		var zone_id = zone_ids[i]
		var zone_node = Node2D.new()
		zone_node.set_script(ZoneNodeScript)
		add_child(zone_node)
		zone_nodes[zone_id] = zone_node
		
		zone_node.setup(zone_id, zone_radius, zone_color, zone_label_color, zone_font, zone_font_size)
		
		var angle = i * angle_step
		zone_node.position = Vector2(cos(angle), sin(angle)) * layout_radius + get_viewport_rect().size / 2
		
	# 2. Create connection lines
	var drawn_connections = {}
	for zone_id in map_data:
		var current_zone_node = zone_nodes[zone_id]
		var connections = map_data[zone_id]["connections"]
		
		for connected_zone_id in connections:
			if not zone_nodes.has(connected_zone_id):
				print("Skipping external connection '%s' from zone '%s'." % [connected_zone_id, zone_id])
				continue
			
			var target_zone_node = zone_nodes[connected_zone_id]
			
			var id1 = str(zone_id)
			var id2 = str(connected_zone_id)
			var connection_key = ""
			if id1 < id2:
				connection_key = "%s_%s" % [id1, id2]
			else:
				connection_key = "%s_%s" % [id2, id1]
			
			if connection_key in drawn_connections:
				continue
			drawn_connections[connection_key] = true
			
			var line = Line2D.new()
			line.add_point(current_zone_node.position)
			line.add_point(target_zone_node.position)
			line.width = line_width
			line.default_color = line_color
			add_child(line)
	
	# 3. Adjust drawing order
	for child in get_children():
		if child is Line2D:
			move_child(child, 0)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
