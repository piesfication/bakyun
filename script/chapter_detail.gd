extends Node2D

signal start_pressed(chapter_number: int, chapter_title: String, scene_path: String)

@onready var anim := $AnimatedSprite2D
@onready var _chapter_number: Label = $Number
@onready var _chapter_title: Label = $ChapterTitle
@onready var _synopsis: Label = $Synopsis
@onready var _click_area: Area2D = $Area2D
@onready var _start_area: CollisionShape2D = $Area2D/StartArea

var _target_scene_path: String = ""
var _chapter_number_value: int = 1

func _ready() -> void:
	if not _click_area.input_event.is_connected(_on_click_area_input_event):
		_click_area.input_event.connect(_on_click_area_input_event)

func set_chapter_data(chapter_number: int, chapter_title: String, synopsis: String, target_scene_path: String) -> void:
	_chapter_number_value = chapter_number
	_chapter_number.text = "%d" % chapter_number
	_chapter_title.text = chapter_title
	_synopsis.text = synopsis
	_target_scene_path = target_scene_path
	
	if (chapter_number == 1 or chapter_number ==3) :
		anim.play("chapter1and3")
	elif (chapter_number == 2 or chapter_number == 4) :
		anim.play("chapter2and4")
	elif (chapter_number == 5 ) :
		anim.play("chapter5")
	
	var tween = create_tween()

	tween.tween_property(self, "scale", Vector2(0.6, 0.6), 0.1)\
	 .set_trans(Tween.TRANS_SINE)\
	 .set_ease(Tween.EASE_OUT)

	tween.tween_property(self, "scale", Vector2(0.55, 0.55), 0.1)\
		 .set_trans(Tween.TRANS_SINE)\
		 .set_ease(Tween.EASE_IN)
		

func _on_click_area_input_event(_viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if _target_scene_path.is_empty():
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	var owner_id := _click_area.shape_find_owner(shape_idx)
	if owner_id == -1:
		return

	var owner_node := _click_area.shape_owner_get_owner(owner_id)
	if owner_node != _start_area:
		return

	start_pressed.emit(_chapter_number_value, _chapter_title.text, _target_scene_path)
