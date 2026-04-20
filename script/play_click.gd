extends Area2D

var _clicked := false

func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed:
		if _clicked:
			return
		var current_scene: Node = get_tree().current_scene
		var is_blocked_click := false
		if current_scene and current_scene.has_method("_is_click_blocked_for_start"):
			is_blocked_click = bool(current_scene.call("_is_click_blocked_for_start", event.position))
		elif current_scene and current_scene.has_method("_is_click_on_character_area"):
			is_blocked_click = bool(current_scene.call("_is_click_on_character_area", event.position))
		if is_blocked_click:
			return
		_clicked = true
		#LoadingManager.set_target_scene("res://scenes/story.tscn")
		LoadingManager.set_target_scene("res://scenes/level_menu.tscn")
		await Transition.fade_out()
		get_tree().change_scene_to_file("res://scenes/loading_screen.tscn")
		await Transition.fade_in()
