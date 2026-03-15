extends Control

@onready var difficulty_icon = $Difficulty
@onready var start_button = $StartButton
@onready var anim = $StartButton/AnimatedSprite2D
@onready var message_label = $MessageLabel

const ICON_EASY = preload("res://assets/menu/Hp/Difficulty/icon_easy.png")
const ICON_MEDIUM = preload("res://assets/menu/Hp/Difficulty/icon_medium.png")
const ICON_HARD = preload("res://assets/menu/Hp/Difficulty/icon_hard.png")

signal start_pressed

func setup(data: Dictionary):
	message_label.text = data.line_baku
	
	match data.difficulty:
		"easy":   difficulty_icon.texture = ICON_EASY
		"medium": difficulty_icon.texture = ICON_MEDIUM
		"hard":   difficulty_icon.texture = ICON_HARD
	
	start_button.input_event.connect(_on_start_clicked)

func _on_start_clicked(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed:
		anim.play("click")
		await anim.animation_finished
		start_pressed.emit()
