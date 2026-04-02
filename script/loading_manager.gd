extends Node

# Target scene path yang akan dituju setelah loading screen
var target_scene_path: String = "res://scenes/level_menu.tscn"

var titleOpenedFirstTime := false

func gettitleOpened():
	return titleOpenedFirstTime
	
func setOpenedTrue():
	titleOpenedFirstTime = true

func set_target_scene(scene_path: String) -> void:
	"""Set scene target untuk loading screen"""
	target_scene_path = scene_path

func get_target_scene() -> String:
	"""Get scene target, default ke level_menu jika tidak di-set"""
	return target_scene_path

func reset_target() -> void:
	"""Reset ke default target"""
	target_scene_path = "res://scenes/level_menu.tscn"
