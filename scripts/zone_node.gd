extends Node2D

@export var zone_radius: float = 50.0
@export var zone_color: Color = Color.CORNFLOWER_BLUE
@export var zone_label_color: Color = Color.BLACK
@export var zone_font: Font
@export var zone_font_size: int = 20

@export var unit_font: Font
@export var unit_font_size: int = 15
@export var unit_label_color: Color = Color.WHITE

var zone_id_str: String
var zone_data: Dictionary
var type: String = "neutral"
var zone_name: String = ""
var connections: Array = []
var positions: Array = []
var starting_units: Array = []

######  Units Scenes ######
var capital_scene = preload("res://scenes/units/capital.tscn")
var corruption_scene = preload("res://scenes/units/corruption.tscn")
var factory_scene = preload("res://scenes/units/factory.tscn")
var garrison_scene = preload("res://scenes/units/garrison.tscn")
var scout_scene = preload("res://scenes/units/scout.tscn")

var unit_map: Dictionary = {
	"capital": {
		"scene": capital_scene,
		"position": Vector2.ZERO,
		"count": 0
		},
	"corruption": {
		"scene": corruption_scene,
		"position": Vector2.ZERO,
		"count": 0
		},
	"factory": {
		"scene": factory_scene,
		"position": Vector2.ZERO,
		"count": 0
		},
	"garrison": {
		"scene": garrison_scene,
		"position": Vector2.ZERO,
		"count": 0
		},
	"scout": {
		"scene": scout_scene,
		"position": Vector2.ZERO,
		"count": 0
		}
}

var color_map: Dictionary = {
	"legendary": Color.GOLD,
	"hazardous": Color.RED,
	"cultural": Color.BLUE,
	"industrial": Color.GREEN
}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	queue_redraw()


func _draw():
	# Draw Zone circle
	draw_circle(Vector2.ZERO, zone_radius, zone_color)
	
	# Prepare font
	var current_font = zone_font
	if current_font == null:
		current_font = ThemeDB.fallback_font
	if current_font == null:
		printerr("No font available for drawing labels")
		return
	
	# Draw zone label
	var text_size = current_font.get_string_size(str(name), HORIZONTAL_ALIGNMENT_CENTER, -1, zone_font_size)
	var text_pos = Vector2(-text_size.x/2, -current_font.get_height(zone_font_size)/2)
	draw_string(current_font, text_pos, name, HORIZONTAL_ALIGNMENT_CENTER, -1, zone_font_size, zone_label_color)
	
	# Draw unit labels
	_draw_unit_labels()


func setup():
	name = zone_id_str
	if zone_data.has("type"):
		type = zone_data["type"]
		zone_color = color_map[type]
	if zone_data.has("name"):
		zone_name = zone_data["name"]
		name = zone_name + " (" + zone_id_str + ")"
	if zone_data.has("connections"):
		connections = zone_data["connections"]
	if zone_data.has("positions"):
		positions = zone_data["positions"]
	if zone_data.has("starting_units"):
		starting_units = zone_data["starting_units"]
		for unit in starting_units:
			_add_new_unit_to_zone(unit)
			
	
	queue_redraw()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _add_new_unit_to_zone(unit_type):
	# Create child node
	var new_unit = unit_map[unit_type]["scene"].instantiate()
	unit_map[unit_type]["count"] += 1
	add_child(new_unit)
	
	# Position child node
	if unit_map[unit_type]["position"] == Vector2.ZERO:
		_calculate_new_unit_position(unit_type)
	new_unit.position += unit_map[unit_type]["position"]
	

func _calculate_new_unit_position(unit_type):
	var new_pos = Vector2.ZERO
	while new_pos == Vector2.ZERO:
		new_pos = Vector2(randi_range(-zone_radius, zone_radius), randi_range(-zone_radius, zone_radius))
	unit_map[unit_type]["position"] = new_pos


func _draw_unit_labels():
	for unit_type in unit_map:
		if unit_map[unit_type]["count"] > 1:
			var label_text = str(unit_map[unit_type]["count"])
			
			# Prepare font
			var current_font = unit_font
			if current_font == null:
				current_font = ThemeDB.fallback_font
			if current_font == null:
				printerr("No font available for drawing labels")
				return
			
			# Draw unit label
			var text_size = current_font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, unit_font_size)
			var text_pos = unit_map[unit_type]["position"]
			text_pos += Vector2(-text_size.x/2, -current_font.get_height(unit_font_size)/2)
			draw_string(current_font, text_pos, label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, unit_font_size, unit_label_color)
