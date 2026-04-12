extends Node2D

@export var zone_radius: float = 50.0
@export var zone_color: Color = Color.CORNFLOWER_BLUE
@export var zone_label_color: Color = Color.BLACK
@export var zone_font: Font
@export var zone_font_size: int = 20

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
	"capital": capital_scene,
	"corruption": corruption_scene,
	"factory": factory_scene,
	"garrison": garrison_scene,
	"scout": scout_scene
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
	draw_circle(Vector2.ZERO, zone_radius, zone_color)
	
	var current_font = zone_font
	if current_font == null:
		current_font = ThemeDB.fallback_font
	if current_font == null:
		printerr("No font available for drawing labels")
		return
	
	var text_size = current_font.get_string_size(zone_id_str, HORIZONTAL_ALIGNMENT_CENTER, -1, zone_font_size)
	var text_pos = Vector2(-text_size.x/2, -current_font.get_height(zone_font_size)/2)
	draw_string(current_font, text_pos, name, HORIZONTAL_ALIGNMENT_CENTER, -1, zone_font_size, zone_label_color)


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
			var new_unit = unit_map[unit].instantiate()
			add_child(new_unit)
			print("new unit added: ", new_unit)
			
	
	queue_redraw()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
