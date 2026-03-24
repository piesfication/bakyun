extends CanvasLayer

signal skill_casted(skill_name: String)

@onready var slots := [
	$MahouMeter/TextureRect/Control/SlotLeft, 
	$MahouMeter/TextureRect/Control/SlotMid,
	$MahouMeter/TextureRect/Control/SlotRight
]

const COLOR_EMPTY = Color("afcac1") # hijau
const COLOR_BAKU  = Color("ff536d") # merah
const COLOR_YUNA  = Color("5d5add") # biru

var slot_states := ["empty", "empty", "empty"]
var current_cast_skill := "NONE"
var cast_locked: bool = false
var _mahou_base_position: Vector2 = Vector2.ZERO
var _mahou_bounce_tween: Tween

@onready var anim := $CastAnimation

func _ready():
	anim.visible = false
	_mahou_base_position = $MahouMeter.position
	for i in range(3):
		update_slot_visual(i)

func update_slot_visual(index):
	match slot_states[index]:
		"empty":
			slots[index].modulate = COLOR_EMPTY
		"baku":
			slots[index].modulate = COLOR_BAKU
		"yuna":
			slots[index].modulate = COLOR_YUNA

func play_bounce(slot: Control):
	slot.pivot_offset = slot.size / 2
	slot.scale = Vector2.ONE
	if slot == $MahouMeter:
		if _mahou_bounce_tween != null and _mahou_bounce_tween.is_valid():
			_mahou_bounce_tween.kill()
		slot.position = _mahou_base_position

	var start_pos := slot.position

	var tween := create_tween()
	if slot == $MahouMeter:
		_mahou_bounce_tween = tween
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)

	# Membesar + turun
	tween.parallel().tween_property(slot, "scale", Vector2(1.12, 1.12), 0.12)
	tween.parallel().tween_property(slot, "position", start_pos + Vector2(0, 10), 0.12)

	# Mental balik
	tween.tween_property(slot, "scale", Vector2(0.96, 0.96), 0.08)

	# Balik normal
	tween.parallel().tween_property(slot, "scale", Vector2.ONE, 0.1)
	tween.parallel().tween_property(slot, "position", start_pos, 0.1)


func add_slot(type: String):
	# geser ke kanan
	for i in range(2, 0, -1):
		slot_states[i] = slot_states[i - 1]

	# isi slot kiri
	slot_states[0] = type

	# update visual
	for i in range(3):
		update_slot_visual(i)
		
	play_bounce($MahouMeter)	
	
	
func get_combo_key() -> String:
	var baku := 0
	var yuna := 0

	for s in slot_states:
		if s == "baku":
			baku += 1
		elif s == "yuna":
			yuna += 1

	return "%d_baku_%d_yuna" % [baku, yuna]

func resolve_combo() -> String:
	match get_combo_key():
		"3_baku_0_yuna":
			return "OVERDRIVE"
		"2_baku_1_yuna":
			return "PIERCE"
		"1_baku_2_yuna":
			return "CHAIN"
		"0_baku_3_yuna":
			return "NOVA"
		_:
			return "NONE"

func _input(event):
	handle_right_click_cast(event)


func _unhandled_input(event):
	handle_right_click_cast(event)


func handle_right_click_cast(event) -> void:
	if cast_locked:
		return

	if not (event is InputEventMouseButton):
		return

	if event.button_index != MOUSE_BUTTON_RIGHT or not event.pressed:
		return

	try_cast()

func set_cast_locked(locked: bool) -> void:
	cast_locked = locked
	

func try_cast():
	if current_cast_skill != "NONE":
		return

	if slot_states.has("empty"):
		return

	var skill := resolve_combo()
	if skill == "NONE":
		return

	start_cast(skill)

func start_cast(skill: String):
	current_cast_skill = skill
	emit_signal("skill_casted", current_cast_skill)
	
	$MahouMeter.visible = false
	anim.visible = true
	anim.play("cast") # nama animasi = nama skill
	
func _on_cast_animation_animation_finished() -> void:
	anim.visible = false
	$MahouMeter.visible = true
	current_cast_skill = "NONE"
	reset_slots()
	pass # Replace with function body.

func reset_slots():
	for i in range(3):
		slot_states[i] = "empty"
		update_slot_visual(i)
