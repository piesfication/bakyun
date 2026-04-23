extends "res://scenes/level_menu_float.gd"

@onready var _chapter_detail: Node2D = $CanvasLayer2/ChapterDetail
@onready var _overlay: ColorRect = $CanvasLayer2/Overlay
@onready var _confirmation_container: Control = $CanvasLayer2/LevelConfirmationContainer
@onready var _confirmation: Node2D = $CanvasLayer2/LevelConfirmationContainer/LevelConfirmation
@onready var _confirmation_title: Label = $"CanvasLayer2/LevelConfirmationContainer/LevelConfirmation/Sprite2D/Level Title"
@onready var _confirmation_text: Label = $CanvasLayer2/LevelConfirmationContainer/LevelConfirmation/Sprite2D/confirmationText
@onready var _confirm_button: BaseButton = $CanvasLayer2/LevelConfirmationContainer/LevelConfirmation/Button
@onready var _cancel_button: BaseButton = $CanvasLayer2/LevelConfirmationContainer/LevelConfirmation/Button2
@onready var _confirm_button_label: Label = $CanvasLayer2/LevelConfirmationContainer/LevelConfirmation/Button/Label2
@onready var _note: Node2D = $CanvasLayer2/ChapterDetail

@export var note_float_amplitude: float = 6.0
@export var note_float_speed: float = 2.0

var note_position: Vector2
var _selected_icon: Node = null
var _is_loading: bool = false
var _chapter_confirmation_open: bool = false
var _pending_scene_path: String = ""
var _pending_chapter_number: int = 1
var _pending_chapter_title: String = ""
var _pending_locked: bool = false

var _chapter_config: Dictionary = {
	"Chapter1": {
		"number": 1,
		"title": "Strange Arrival",
		"synopsis": "\" This city never has guests. So when someone arrives at the gate, claiming she’s been transferred here, something feels… off. There’s something in that word — and in the way she stands there — that I recognize. \"",
		"scene": "res://scenes/story.tscn"
	},
	"Chapter2": {
		"number": 2,
		"title": "Pure Instinct",
		"synopsis": "\" It’s been two weeks, and I still don’t understand Baku. There’s no system, no structure — just instinct that somehow always works. I try to fix it. She ignores it. And somehow, she’s still right. \"",
		"scene": "res://scenes/story_2.tscn"
	},
	"Chapter3": {
		"number": 3,
		"title": "Getting Closer",
		"synopsis": "\" The alpha is getting closer. I can feel it. Yuna feels it too, even if she doesn’t say it. But that’s not what stays with me. It’s the question she asked — and the answer I didn’t mean to give. \"",
		"scene": "res://scenes/story_3.tscn"
	},
	"Chapter4": {
		"number": 4,
		"title": "Storm Center",
		"synopsis": "\" This is the moment we’ve been preparing for. The alpha is here. But somewhere along the way, something changed. I’m no longer sure what I want after this ends. \"",
		"scene": "res://scenes/story_4.tscn"
	},
	"Chapter5": {
		"number": 5,
		"title": "Above Ground",
		"synopsis": "\" The city is quiet for the first time in years. There’s nothing left to chase, nothing left to prove. She stayed — and I chose to stay. And somehow, without either of us saying it out loud, this place finally feels like home. \"",
		"scene": "res://scenes/story_5.tscn"
	}
}

func _process(_delta: float) -> void:
	if _note != null:
		var t := Time.get_ticks_msec() * 0.001
		_note.position = note_position + Vector2(0.0, sin(t * note_float_speed) * note_float_amplitude)

func _ready() -> void:
	super()
	if _note != null:
		note_position = _note.position
	_connect_story_icons()
	if _chapter_detail.has_signal("start_pressed") and not _chapter_detail.start_pressed.is_connected(_on_start_pressed):
		_chapter_detail.start_pressed.connect(_on_start_pressed)
	if _confirm_button != null and not _confirm_button.pressed.is_connected(_on_confirm_pressed):
		_confirm_button.pressed.connect(_on_confirm_pressed)
	if _cancel_button != null and not _cancel_button.pressed.is_connected(_on_cancel_pressed):
		_cancel_button.pressed.connect(_on_cancel_pressed)
	if has_node("/root/StoryProgress") and not StoryProgress.progress_changed.is_connected(_refresh_chapter_visibility):
		StoryProgress.progress_changed.connect(_refresh_chapter_visibility)
	_refresh_chapter_visibility()
	_close_chapter_confirmation()
	if _chapter_config.has("Chapter1"):
		_apply_chapter("Chapter1")

func _connect_story_icons() -> void:
	for icon in $StorySelectionIcon.get_children():
		if not icon.has_signal("chapter_selected"):
			continue
		if not icon.chapter_selected.is_connected(_on_chapter_selected):
			icon.chapter_selected.connect(_on_chapter_selected)

func _refresh_chapter_visibility() -> void:
	var visible_limit := 1
	if has_node("/root/StoryProgress"):
		visible_limit = max(1, StoryProgress.get_visible_chapter_limit())

	for icon in $StorySelectionIcon.get_children():
		var chapter_number := _get_chapter_number(icon.name)
		if chapter_number <= 0:
			continue
		icon.visible = chapter_number <= visible_limit

	if _selected_icon != null and not _selected_icon.visible:
		_selected_icon = null

func _get_chapter_number(icon_name: String) -> int:
	if not icon_name.begins_with("Chapter"):
		return -1
	return int(icon_name.trim_prefix("Chapter"))

func _on_chapter_selected(chapter_name: String) -> void:
	_apply_chapter(chapter_name)

func _apply_chapter(chapter_name: String) -> void:
	if not _chapter_config.has(chapter_name):
		return

	var icon := get_node_or_null("StorySelectionIcon/%s" % chapter_name)
	if icon != null and not icon.visible:
		return

	if _selected_icon != null and _selected_icon != icon:
		if _selected_icon.has_method("on_deselected"):
			_selected_icon.on_deselected()

	if icon != null and icon.has_method("on_selected"):
		icon.on_selected()
	_selected_icon = icon

	var data: Dictionary = _chapter_config[chapter_name]
	if _chapter_detail.has_method("set_chapter_data"):
		_chapter_detail.set_chapter_data(
			int(data.get("number", 0)),
			str(data.get("title", "")),
			str(data.get("synopsis", "")),
			str(data.get("scene", ""))
		)

func _on_start_pressed(chapter_number: int, chapter_title: String, scene_path: String) -> void:
	if _is_loading:
		return
	if scene_path.is_empty():
		return

	_open_chapter_confirmation(chapter_number, chapter_title, scene_path)

func _open_chapter_confirmation(chapter_number: int, chapter_title: String, scene_path: String) -> void:
	_pending_chapter_number = chapter_number
	_pending_scene_path = scene_path
	_pending_chapter_title = chapter_title
	_pending_locked = false
	if has_node("/root/StoryProgress"):
		_pending_locked = StoryProgress.is_chapter_locked(chapter_number)

	_chapter_confirmation_open = true

	if _overlay != null:
		_overlay.visible = true
		_overlay.color.a = 0.0
		var overlay_tween := create_tween()
		overlay_tween.tween_property(_overlay, "color:a", 0.5, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	if _confirmation_container != null:
		_confirmation_container.visible = true
	if _confirmation != null:
		_confirmation.visible = true
		_confirmation.modulate.a = 0.0
		var base_scale := _confirmation.scale
		_confirmation.scale = Vector2(base_scale.x * 1.08, base_scale.y * 0.88)
		var popup_tween := create_tween()
		popup_tween.set_parallel(true)
		popup_tween.tween_property(_confirmation, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		popup_tween.tween_property(_confirmation, "scale", base_scale, 0.18).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)

	if _confirmation_title != null:
		_confirmation_title.text = "\" %s \"" % chapter_title

	if _pending_locked and has_node("/root/StoryProgress"):
		if _confirmation_text != null:
			_confirmation_text.text = StoryProgress.get_chapter_progress_text(chapter_number)
		if _confirm_button_label != null:
			_confirm_button_label.text = StoryProgress.get_confirm_button_text(chapter_number)
		if _confirm_button != null:
			_confirm_button.disabled = true
	else:
		if _confirmation_text != null:
			_confirmation_text.text = "Shall we start?"
		if _confirm_button_label != null:
			_confirm_button_label.text = "WE BALL!"
		if _confirm_button != null:
			_confirm_button.disabled = false

func _on_confirm_pressed() -> void:
	if _pending_scene_path.is_empty() or _is_loading or _pending_locked:
		return

	_is_loading = true
	LoadingManager.set_target_scene(_pending_scene_path)
	await Transition.fade_out()
	get_tree().change_scene_to_file("res://scenes/loading_screen.tscn")
	await Transition.fade_in()

func _on_cancel_pressed() -> void:
	_close_chapter_confirmation()

func _close_chapter_confirmation() -> void:
	_pending_scene_path = ""
	_pending_chapter_title = ""
	_pending_chapter_number = 1
	_pending_locked = false
	_chapter_confirmation_open = false

	if _overlay != null:
		_overlay.visible = false
		_overlay.color.a = 0.0
	if _confirmation_container != null:
		_confirmation_container.visible = false
	if _confirmation != null:
		_confirmation.visible = false
		_confirmation.modulate.a = 0.0
	if _confirm_button != null:
		_confirm_button.disabled = false
	if _confirm_button_label != null:
		_confirm_button_label.text = "WE BALL!"
