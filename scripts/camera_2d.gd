extends Camera2D

# --- Zoom Control Parameters ---
@export var zoom_speed: float = 0.1 # How much to zoom in/out per scroll tick
@export var min_zoom: float = 0.1   # Minimum allowed zoom level (e.g., 10% of original scale)
@export var max_zoom: float = 2.0   # Maximum allowed zoom level (e.g., 200% of original scale)

@onready var main_node = get_parent() as Node2D

func _ready():
	make_current() 
	
	if main_node:
		if main_node.has_signal("adjust camera"):
			main_node.adjust_camera.connect(_on_map_generated)
		else:
			printerr("Main node does not have 'adjust_camera' signal.")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var zoom_factor = 1.0

		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_factor = 1.0 + zoom_speed
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_factor = 1.0 - zoom_speed
			get_viewport().set_input_as_handled()

		if zoom_factor != 1.0:
			var mouse_world_pos_before_zoom = get_global_mouse_position()

			var old_zoom = zoom
			zoom *= zoom_factor
			zoom = zoom.clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))

			if old_zoom != zoom:
				var mouse_world_pos_after_zoom = get_global_mouse_position()
				var diff = mouse_world_pos_before_zoom - mouse_world_pos_after_zoom
				position += diff

# This function is called when the MapGenerator finishes laying out the map
func _on_map_generated(current_iteration: int, graph_bounding_box: Rect2):
	print("Camera: Received map_layout_finished signal from Main!")
	print("Camera: Graph Bounding Box: ", graph_bounding_box)

	# Calculate zoom level to fit the bounding box within the viewport
	var viewport_size = get_viewport_rect().size
	var margin_factor = 1.1

	var target_width = graph_bounding_box.size.x * margin_factor
	var target_height = graph_bounding_box.size.y * margin_factor

	var scale_x = viewport_size.x / target_width
	var scale_y = viewport_size.y / target_height

	var initial_calculated_zoom = min(scale_x, scale_y)
	zoom = Vector2(initial_calculated_zoom, initial_calculated_zoom)
	zoom = zoom.clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))
