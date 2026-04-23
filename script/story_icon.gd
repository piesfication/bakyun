extends Node2D

signal chapter_selected(chapter_name: String)

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D

var _is_selected: bool = false

func _ready() -> void:
	_anim.play("idle")

func on_selected() -> void:
	_is_selected = true
	_anim.play("clicked")
	await _anim.animation_finished
	_anim.play("idle_after_clicked")

func on_deselected() -> void:
	_is_selected = false
	_anim.play("return_to_idle")
	await _anim.animation_finished
	_anim.play("idle")

func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		chapter_selected.emit(name)
