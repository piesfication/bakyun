extends "res://script/main_boss_level.gd"

func _ready() -> void:
	super._ready()
	_configure_yuna_only_mode()

func _configure_yuna_only_mode() -> void:
	if player_node != null and is_instance_valid(player_node):
		if player_node.has_method("set_current_character"):
			player_node.set_current_character("yuna")
		if player_node.has_method("set_switch_locked"):
			player_node.set_switch_locked(true)

	if crosshair_node != null and is_instance_valid(crosshair_node):
		if crosshair_node.has_method("set_character_mode"):
			crosshair_node.set_character_mode("yuna")
		if crosshair_node.has_method("set_switch_locked"):
			crosshair_node.set_switch_locked(true)

	_set_combat_cast_locked(true)

func _spawn_boss_once() -> void:
	super._spawn_boss_once()
	
@onready var overlay_bakumono = $CanvasLayer3/Overlay
func on_dialogic_signal(arg: String):
	super.on_dialogic_signal(arg)
	
	if (arg == "remove overlay") :
		
		fade_out(overlay_bakumono, 3)

		pass
	
	if (arg == "show overlay") :
		
		fade_in(overlay_bakumono, 2)
		
	if (arg == "post bakumono"):
		LoadingManager.set_target_scene("res://scenes/story_4_1.tscn")
		await Transition.fade_out()
		get_tree().change_scene_to_file("res://scenes/loading_screen.tscn")
		await Transition.fade_in() # fade out
		
	
func fade_in(arg, dur):
	var tween = create_tween()
	tween.tween_property(arg, "modulate:a", 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func fade_out(arg, dur):
	var tween = create_tween()
	tween.tween_property(arg, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
