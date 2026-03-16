extends PanelContainer
class_name MapGridCell

signal cell_clicked(position: Vector2)

var grid_position: Vector2 = Vector2.ZERO
var assigned_sector_data: SectorData = null:
	set(value):
		assigned_sector_data = value
		update_display()

@onready var sector_name_label: Label = %SectorNameLabel
@onready var preview_image: TextureRect = %PreviewImage


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	update_display()


func update_display():
	if assigned_sector_data:
		sector_name_label.text = assigned_sector_data.sector_name
		preview_image.texture = assigned_sector_data.preview_texture
		add_theme_stylebox_override("panel", preload("res://ui/styles/cell_filled_stylebox.tres") if ResourceLoader.exists("res://ui/styles/cell_filled_stylebox.tres") else null)
	else:
		sector_name_label.text = "Empty"
		preview_image.texture = null
		add_theme_stylebox_override("panel", preload("res://ui/styles/cell_empty_stylebox.tres") if ResourceLoader.exists("res://ui/styles/cell_empty_stylebox.tres") else null)


func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		cell_clicked.emit(grid_position)
		get_viewport().set_input_as_handled()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
