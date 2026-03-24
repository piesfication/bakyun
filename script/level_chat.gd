extends Control

@onready var difficulty_icon = $Difficulty
@onready var difficulty_easy_icon: Sprite2D = $Difficulty/Easy
@onready var difficulty_medium_icon: Sprite2D = $Difficulty/Medium
@onready var difficulty_hard_icon: Sprite2D = $Difficulty/Hard
@onready var start_button = $StartButton
@onready var start_click_zone: Button = $StartClickZone
@onready var anim = $StartButton/AnimatedSprite2D
@onready var message_label = $MessageLabel

var current_level_data: Dictionary = {}
var _start_in_progress: bool = false

signal start_pressed
signal level_confirmation_requested(level_data: Dictionary)

func _ready():
	if start_button:
		start_button.input_event.connect(_on_start_clicked)
	if start_click_zone:
		start_click_zone.pressed.connect(_on_start_button_pressed)

func setup(data: Dictionary):
	message_label.text = data.line_baku
	_set_difficulty_icon(String(data.get("difficulty", "easy")))
	current_level_data = data.duplicate()


func _set_difficulty_icon(difficulty: String) -> void:
	if difficulty_icon != null:
		difficulty_icon.texture = null

	if difficulty_easy_icon != null:
		difficulty_easy_icon.visible = false
	if difficulty_medium_icon != null:
		difficulty_medium_icon.visible = false
	if difficulty_hard_icon != null:
		difficulty_hard_icon.visible = false

	match difficulty:
		"easy":
			if difficulty_easy_icon != null:
				difficulty_easy_icon.visible = true
		"medium":
			if difficulty_medium_icon != null:
				difficulty_medium_icon.visible = true
		"hard":
			if difficulty_hard_icon != null:
				difficulty_hard_icon.visible = true
		_:
			if difficulty_easy_icon != null:
				difficulty_easy_icon.visible = true

func _on_start_clicked(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed:
		_trigger_start()

func _on_start_button_pressed() -> void:
	_trigger_start()

func _trigger_start() -> void:
	if _start_in_progress:
		return
	_start_in_progress = true
	anim.play("click")
	await get_tree().create_timer(0.12).timeout
	level_confirmation_requested.emit(current_level_data)
	start_pressed.emit()
	_start_in_progress = false
