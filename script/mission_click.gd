extends Area2D

var _clicked := false

func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed:
		if _clicked:
			return
		if event is InputEventMouseButton and event.pressed:
			_clicked = true
			LoadingManager.set_target_scene("res://scenes/level_menu.tscn")
			await Transition.fade_out()  
			get_tree().change_scene_to_file("res://scenes/loading_screen.tscn")  # 2. pindah
			await Transition.fade_in()  
