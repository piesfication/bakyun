extends Node2D

@export var speed := 2
var time := 0.0

@onready var char := $CanvasLayer/AnimatedSprite2D
@onready var baku := $CanvasLayer/Node2D/BakuIcon
@onready var yuna := $CanvasLayer/Node2D/YunaIcon
@onready var text := $Text
@onready var textValue := $Text/Label
@onready var textBorder := $Text/OuterBorder

var base_pos := {}

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	randomize()
	show_random_line()
	base_pos[char] = char.position
	base_pos[baku] = baku.position
	base_pos[yuna] = yuna.position
	base_pos[text] = text.position
	# Mulai timer transisi otomatis
	call_deferred("_start_auto_transition")

func _start_auto_transition():
	await get_tree().create_timer(5.0).timeout
	var target_scene = LoadingManager.get_target_scene()
	get_tree().change_scene_to_file(target_scene)
	LoadingManager.reset_target()

func _process(delta):
	time += delta * speed
	char.position.y = base_pos[char].y + sin(time * 1.5) * 10
	baku.position.y = base_pos[baku].y + sin(time * 1) * 10
	yuna.position.y = base_pos[yuna].y + sin(time * 1) * 10
	text.position.y = base_pos[text].y + sin(time * 1) * 10

func show_random_line():
	var data = LoadingDialogue.get_random_line()
	textValue.text = "\"" + data.text + "\""
	textBorder.text = "\"" + data.text + "\""
	baku.visible = data.speaker == "baku"
	yuna.visible = data.speaker == "yuna"
