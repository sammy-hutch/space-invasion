extends Node2D

var zone_id_str: String
var radius: float
var zone_color: Color
var label_color: Color
var font: Font
var font_size: int = 20

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	queue_redraw()


func _draw():
	draw_circle(Vector2.ZERO, radius, zone_color)
	
	var current_font = font
	if current_font == null:
		current_font = ThemeDB.fallback_font
	if current_font == null:
		printerr("No font available for drawing labels")
		return
	
	var text_size = current_font.get_string_size(zone_id_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos = Vector2(-text_size.x/2, -current_font.get_height(font_size)/2)
	draw_string(current_font, text_pos, zone_id_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, label_color)


func setup(id: String, r: float, z_color: Color, l_color: Color, f: Font = null, f_size: int = 20):
	zone_id_str = id
	radius = r
	zone_color = z_color
	label_color = l_color
	font = f
	font_size = f_size
	name = "Zone_" + zone_id_str
	queue_redraw()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
