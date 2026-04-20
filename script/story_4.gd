extends Node2D

@onready var alph = $Alpha


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Dialogic.signal_event.connect(on_dialogic_signal);
	Dialogic.start("res://timeline/timeline_4.dtl")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func on_dialogic_signal(arg: String):
	
	if (arg == "boss fight"):
		LoadingManager.set_target_scene("res://scenes/main_boss.tscn")
		await Transition.fade_out()
		get_tree().change_scene_to_file("res://scenes/main_boss.tscn")
		await Transition.fade_in() # fade out
	pass
