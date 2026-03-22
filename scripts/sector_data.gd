extends Resource
class_name SectorData

@export var sector_name: String = "New Sector"
@export var sector_id: String = "Sector_X"
@export_file("*.tscn") var sector_scene_path: String = ""
@export var preview_texture: Texture2D = null

func _to_string():
	return "SectorData: %s" % sector_name
