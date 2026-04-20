extends Node2D

# Colors for different characters
const COLOR_BAKU = Color("#ff536d")
const COLOR_YUNA = Color("#5e5add")

# References
var label_outline: Label  # Outline/shadow label
var label_main: Label      # Main label

# Combo state
var combo_count: int = 0
var is_visible: bool = false
var fade_timer: float = 0.0
var fade_duration: float = 0.3
var hide_timeout: float = 2.0
var hide_timer: float = 0.0
var current_character: String = "baku"  # "baku" or "yuna"
var _squash_tween: Tween = null

func _ready() -> void:
	# Find labels by name since @onready won't work with dynamic script loading
	_find_labels()
	# Initialize as hidden
	set_combo_visible(false)
	modulate = Color(1, 1, 1, 0)  # Start completely transparent
	_setup_label()

func _find_labels() -> void:
	"""Find label children dynamically"""
	if combocounter == null:
		combocounter = find_child("ComboCounter")
	if label_outline == null:
		label_outline = find_child("Label2")
	if label_main == null:
		label_main = find_child("Label")

func _process(delta: float) -> void:
	# Handle hide timeout
	if is_visible and hide_timer > 0:
		hide_timer -= delta
		if hide_timer <= 0:
			fade_out()

func _setup_label() -> void:
	# Ensure both labels are properly configured
	_find_labels()
	if label_main:
		label_main.text = ""
		label_main.add_theme_color_override("font_color", COLOR_BAKU)
	if label_outline:
		label_outline.text = ""
		label_outline.add_theme_color_override("font_color", Color.BLACK)
	call_deferred("_refresh_label_pivot")

@onready var combocounter := $LevelEndOverlay/ComboCounter
func _refresh_label_pivot() -> void:
	label_main.pivot_offset = label_main.size * 0.5
	label_outline.pivot_offset = label_outline.size * 0.5

func set_character_color(character: String) -> void:
	"""Set combo counter color based on character"""
	_find_labels()
	current_character = character.to_lower()
	var color = COLOR_BAKU if current_character == "baku" else COLOR_YUNA
	if label_main:
		if label_main.label_settings != null:
			var settings := label_main.label_settings.duplicate()
			settings.font_color = color
			label_main.label_settings = settings
		label_main.add_theme_color_override("font_color", color)

func on_hit(character: String = "baku") -> void:
	"""Called when player hits a target"""
	_find_labels()
	set_character_color(character)
	combo_count += 1
	show_combo_hit()
	_apply_squeeze_and_stretch()
	hide_timer = hide_timeout  # Reset hide timer

func on_miss() -> void:
	"""Called when player shoots but misses"""
	_find_labels()
	_show_miss()
	_apply_squeeze_and_stretch()
	combo_count = 0
	hide_timer = 0  # Start fading out immediately

func show_combo_hit() -> void:
	"""Display the combo counter with hit text"""
	await get_tree().process_frame
	_refresh_label_pivot()
	_find_labels()
	var hit_text = "1 HIT!" if combo_count == 1 else "%d HITS!" % combo_count
	if label_main:
		label_main.text = hit_text
	if label_outline:
		label_outline.text = hit_text
	call_deferred("_refresh_label_pivot")
	
	if not is_visible:
		fade_in()

func _show_miss() -> void:
	"""Display MISS text and start fading"""
	_find_labels()
	if label_main:
		label_main.text = "MISS!"
	if label_outline:
		label_outline.text = "MISS!"
	call_deferred("_refresh_label_pivot")
	set_combo_visible(true)
	modulate = Color(1, 1, 1, 1)  # Make sure it's fully visible before fading
	is_visible = true
	fade_out()

func fade_in() -> void:
	"""Fade in the combo counter"""
	is_visible = true
	set_combo_visible(true)
	modulate = Color(1, 1, 1, 0)  # Start from transparent
	
	# Create tween for fade in
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, fade_duration)

func fade_out() -> void:
	"""Fade out the combo counter"""
	if not is_visible:
		return
	
	is_visible = false
	
	# Create tween for fade out
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	await tween.finished
	set_combo_visible(false)

func set_combo_visible(visible: bool) -> void:
	"""Control visibility of combo counter"""
	_find_labels()
	self.visible = visible
	# Update both labels
	if label_main:
		label_main.visible = visible
	if label_outline:
		label_outline.visible = visible

func _apply_squeeze_and_stretch() -> void:
	_find_labels()
	_refresh_label_pivot()

	label_main.scale = Vector2.ONE
	label_outline.scale = Vector2.ONE

	if _squash_tween != null and _squash_tween.is_running():
		_squash_tween.kill()

	_squash_tween = create_tween()
	_squash_tween.set_trans(Tween.TRANS_BACK)
	_squash_tween.set_ease(Tween.EASE_OUT)

	# STEP 1
	_squash_tween.parallel().tween_property(label_main, "scale", Vector2(1.5, 0.75), 0.08)
	_squash_tween.parallel().tween_property(label_outline, "scale", Vector2(1.5, 0.75), 0.08)

	_squash_tween.chain()

	# STEP 2
	_squash_tween.parallel().tween_property(label_main, "scale", Vector2(0.85, 1.15), 0.08)
	_squash_tween.parallel().tween_property(label_outline, "scale", Vector2(0.85, 1.15), 0.08)

	_squash_tween.chain()

	# STEP 3
	_squash_tween.parallel().tween_property(label_main, "scale", Vector2.ONE * 0.75 , 0.1)
	_squash_tween.parallel().tween_property(label_outline, "scale", Vector2.ONE * 0.75 , 0.1)
	

func reset() -> void:
	"""Reset combo counter to initial state"""
	_find_labels()
	combo_count = 0
	hide_timer = 0
	if label_main:
		label_main.text = ""
	if label_outline:
		label_outline.text = ""
	fade_out()

func get_combo_count() -> int:
	"""Return current combo count"""
	return combo_count
