extends Node2D

@onready var birdstrike := $BirdStrike

@export var speed := 2
var time := 0.0

@onready var char = $AnimatedSprite2D

var _shake_time_left: float = 0.0
var _shake_prev_offset: Vector2 = Vector2.ZERO
var _shake_phase: float = 0.0
var _shake_duration_current: float = 0.24
var _shake_strength_current: float = 26.0
var _shake_frequency_current: float = 95.0
var _shake_falloff_power_current: float = 2.0
var _shake_target: Node2D

@export var bird_strike_shake_duration: float = 0.68
@export var bird_strike_shake_strength: float = 95.0
@export var bird_strike_shake_frequency: float = 155.0
@export var bird_strike_shake_falloff_power: float = 0.55

@onready var overlay = $CanvasLayer3/Overlay

var base_pos := {}

	

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Dialogic.signal_event.connect(on_dialogic_signal);
	Dialogic.start("res://timeline/timeline.dtl")
	overlay.visible = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	time += delta * speed
	
	if _shake_target == null:
		return
		
	else:
		pass

	# Reset offset sebelumnya
	_shake_target.position -= _shake_prev_offset
	_shake_prev_offset = Vector2.ZERO

	if _shake_time_left > 0.0:
		_shake_time_left -= delta
		
		if _shake_time_left <= 0.0:
			return
		
		var t: float = clamp(_shake_time_left / _shake_duration_current, 0.0, 1.0)
		
		if is_nan(t):
			return
		
		var falloff := pow(t, _shake_falloff_power_current)

		_shake_phase += delta * _shake_frequency_current
		
		var offset := Vector2(
			cos(_shake_phase),
			sin(_shake_phase)
		) * _shake_strength_current * falloff

		_shake_target.position += offset
		_shake_prev_offset = offset
	


func on_dialogic_signal(arg: String):
	if (arg == "bird strike") :
		birdstrike.visible = true
		birdstrike.play("strike")
		
	if (arg == "yuna wake up") :
		print("wake")
		fade_overlay(0.0, 1.0) # fade out
		
	if (arg == "level menu") :
		if has_node("/root/StoryProgress"):
			StoryProgress.mark_chapter_completed(1)
		LoadingManager.set_target_scene("res://scenes/level_menu.tscn")
		await Transition.fade_out()
		get_tree().change_scene_to_file("res://scenes/loading_screen.tscn")
		await Transition.fade_in() # fade out


func _on_bird_strike_animation_finished() -> void:
	birdstrike.visible = false
	pass # Replace with function body.

func trigger_screen_shake() -> void:
	if _shake_target == null or not is_instance_valid(_shake_target):
		_shake_target = get_tree().current_scene as Node2D
	if _shake_target == null:
		return

	_shake_duration_current = maxf(bird_strike_shake_duration, 0.001)
	_shake_strength_current = maxf(bird_strike_shake_strength, 0.0)
	_shake_frequency_current = maxf(bird_strike_shake_frequency, 0.0)
	_shake_falloff_power_current = maxf(bird_strike_shake_falloff_power, 0.1)
	_shake_time_left = maxf(_shake_time_left, _shake_duration_current)
	_shake_phase = randf() * TAU
	
	

func _on_bird_strike_frame_changed() -> void:
	if birdstrike.animation == "strike" and birdstrike.frame == 5:
		trigger_screen_shake()
		Transition.play_crt_glitch_burst()
		
		overlay.modulate.a = 0.0
		overlay.visible = true
		await get_tree().create_timer(0.3).timeout
	
		fade_overlay(1.0, 1.0) # fade in
		
		
		#LoadingManager.set_target_scene("res://scenes/level_menu.tscn")
		#await Transition.fade_out()
		#get_tree().change_scene_to_file("res://scenes/loading_screen.tscn")
		#await Transition.fade_in()
		
var tween: Tween

func fade_overlay(to: float, duration: float):
	if tween:
		tween.kill()
	
	tween = create_tween()
	tween.tween_property(overlay, "modulate:a", to, duration)
