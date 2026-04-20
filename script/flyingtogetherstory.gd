extends Node2D

@export var speed := 2
var time := 0.0
var first_speak

@onready var chapter2background = $Chap2Sky
@onready var flyingtogether = $CanvasLayer3/SpriteChar
@onready var bakuTalking = $CanvasLayer3/SpriteChar/BakuTalking
@onready var yunaTalking = $CanvasLayer3/SpriteChar/YunaTalking

@onready var overlay = $CanvasLayer3/Overlay
@onready var bg = $Background

@onready var grass = $GrassField
@onready var char = $GrassField/Char

var base_pos := {}

func _ready():
	Dialogic.signal_event.connect(on_dialogic_signal);
	Dialogic.start("res://timeline/timeline_2.dtl")
	base_pos[chapter2background] = chapter2background.position
	base_pos[flyingtogether] = flyingtogether.position

func _process(delta):
	time += delta * speed
	chapter2background.position.y = base_pos[chapter2background].y + sin(time * 1) * 10
	
	if (is_moving == false):
		flyingtogether.position.y = base_pos[flyingtogether].y + sin(time * 2) * 20

func on_dialogic_signal(arg: String):
	if (arg == "start chapter 2") :
		chapter2background.visible = true
		bakuTalking.play("default")
		yunaTalking.play("default")
		
	if (arg == "start convo"):
		
		overlay.modulate.a = 0.0
		overlay.visible = true
		await get_tree().create_timer(0.3).timeout
		fade_overlay(1.0, 1.0) # fade in
		await get_tree().create_timer(1).timeout
		
		fade_in(chapter2background,2)
		flyingtogether.visible = true
		flyingtogether.modulate.a = 0
		fade_in(flyingtogether,2)
		move_to(Vector2(843, 403), flyingtogether, 2)
		fade_out(bg, 2)
		
		await get_tree().create_timer(1).timeout
		
		await get_tree().create_timer(0.3).timeout
		fade_overlay(0, 1.0)
		
	if (arg == "bt"):
		
		bakuTalking.visible = true
		
		yunaTalking.visible = false
		flyingtogether.visible = true
		if (first_speak) == false :
			squash_stretch(flyingtogether)
		else: first_speak = false
		
	if (arg == "yt"):
		bakuTalking.visible = false
		yunaTalking.visible = true
		flyingtogether.visible = true
		if (first_speak) == false :
			squash_stretch(flyingtogether)
		else: first_speak = false
		
	if (arg == "out") :
		move_to(Vector2(843, 932), flyingtogether, 2)
		fade_out(flyingtogether,0.4)
	if (arg == "in") :
		move_to(Vector2(843, 523),flyingtogether, 0)
		move_to(Vector2(843, 403), flyingtogether, 1)
		fade_in(flyingtogether, 1)
		
	if (arg == "start grass field") :
		
		overlay.modulate.a = 0.0
		overlay.visible = true
		await get_tree().create_timer(0.3).timeout
		fade_overlay(1.0, 1.0) # fade in
		await get_tree().create_timer(1).timeout
		
		grass.modulate.a = 0
		grass.visible = true
		fade_in(grass, 1)
		fade_out(chapter2background, 1)
		
		await get_tree().create_timer(1).timeout
		
		flyingtogether.visible = false
		
		await get_tree().create_timer(0.3).timeout
		fade_overlay(0, 1.0)
		
	if (arg == "start convo grass field") :
		fade_out(char, 1)
		
	if (arg == "level menu") :
		LoadingManager.set_target_scene("res://scenes/level_menu.tscn")
		await Transition.fade_out()
		get_tree().change_scene_to_file("res://scenes/loading_screen.tscn")
		await Transition.fade_in() # fade out
		
var tween: Tween

func fade_overlay(to: float, duration: float):
	
	if tween:
		tween.kill()
	
	tween = create_tween()
	tween.tween_property(overlay, "modulate:a", to, duration)
	
func fade_in(arg, dur):
	var tween = create_tween()
	tween.tween_property(arg, "modulate:a", 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func fade_out(arg, dur):
	var tween = create_tween()
	tween.tween_property(arg, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func squash_stretch(arg):
	var tween = create_tween()

	# Stretch (lonjong ke atas)
	tween.tween_property(arg, "scale", Vector2(0.63, 0.63), 0.1)

	# Balik ke normal
	tween.tween_property(arg, "scale", Vector2(0.6, 0.6), 0.1)

var is_moving = false
func move_to(target_pos: Vector2, arg, dur):
	is_moving = true
	
	var tween = create_tween()
	tween.tween_property(arg, "global_position", target_pos, dur)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	
	tween.finished.connect(func():
		base_pos[arg] = arg.position
		is_moving = false
	)
