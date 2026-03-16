extends Control

@onready var difficulty_easy = $Difficulty/Easy
@onready var difficulty_medium = $Difficulty/Medium
@onready var difficulty_hard = $Difficulty/Hard
@onready var start_button = $StartButton
@onready var anim = $StartButton/AnimatedSprite2D
@onready var message_label = $MessageLabel

signal start_pressed

func setup(data: Dictionary):
	message_label.text = data.line_baku

	difficulty_easy.visible = false
	difficulty_medium.visible = false
	difficulty_hard.visible = false

	match data.difficulty:
		"easy":
			difficulty_easy.visible = true
		"medium":
			difficulty_medium.visible = true
		"hard":
			difficulty_hard.visible = true
		_:
			difficulty_easy.visible = true
	
	start_button.input_event.connect(_on_start_clicked)

func _on_start_clicked(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed:
		anim.play("click")
		await anim.animation_finished
		start_pressed.emit()
