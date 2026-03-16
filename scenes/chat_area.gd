extends Control

@onready var message_list = $MessageList
@onready var icon_baku: Node2D = get_node_or_null(icon_baku_path)
@onready var icon_yuna: Node2D = get_node_or_null(icon_yuna_path)
@onready var baku_sprite: AnimatedSprite2D = _get_icon_sprite(icon_baku)
@onready var yuna_sprite: AnimatedSprite2D = _get_icon_sprite(icon_yuna)

const LevelCard = preload("res://scenes/level_chat.tscn")
const NpcBubble = preload("res://scenes/level_chat_yuna.tscn")

var is_animating: bool = false
var baku_icon_tween: Tween
var yuna_icon_tween: Tween
var baku_move_tween: Tween
var yuna_move_tween: Tween
var baku_pulse_tween: Tween
var yuna_pulse_tween: Tween
var baku_base_position: Vector2
var yuna_base_position: Vector2
var baku_base_scale: Vector2
var yuna_base_scale: Vector2
var baku_sprite_base_scale: Vector2
var yuna_sprite_base_scale: Vector2

@export var jarak_chat: int = -70
@export var langkah_baku: int = 360
@export var langkah_yuna: int = 185
@export var dorong_chat_lama: int = 920
@export var naikkan_posisi_chat: int = 380
@export var icon_baku_path: NodePath
@export var icon_yuna_path: NodePath
@export var icon_masuk_dari_bawah: float = 90.0
@export var icon_keluar_arah: Vector2 = Vector2(0,-1)
@export var icon_keluar_jarak_multiplier: float = 0.35
@export var baku_follow_step_kedua_multiplier: float = 0.67
@export var icon_show_stretch: Vector2 = Vector2(0.88, 1.12)
@export var icon_show_overshoot: Vector2 = Vector2(1.06, 0.94)
@export var icon_hide_stretch: Vector2 = Vector2(1.08, 0.92)
@export var icon_frame2_pulse_scale: float = 1.06
@export var icon_frame2_pulse_up_duration: float = 0.1
@export var icon_frame2_pulse_down_duration: float = 0.12


var current_y = 0  # nanti sesuaikan dengan posisi awal MessageList di editor
var base_y = 0

func _ready():
	message_list.add_theme_constant_override("separation", jarak_chat)
	base_y = message_list.position.y
	current_y = _posisi_awal_chat()
	baku_base_position = icon_baku.position if icon_baku != null else Vector2.ZERO
	yuna_base_position = icon_yuna.position if icon_yuna != null else Vector2.ZERO
	baku_base_scale = icon_baku.scale if icon_baku != null else Vector2.ONE
	yuna_base_scale = icon_yuna.scale if icon_yuna != null else Vector2.ONE
	baku_sprite_base_scale = baku_sprite.scale if baku_sprite != null else Vector2.ONE
	yuna_sprite_base_scale = yuna_sprite.scale if yuna_sprite != null else Vector2.ONE
	_setup_icon_sprite(baku_sprite, true)
	_setup_icon_sprite(yuna_sprite, false)
	_set_icon_hidden(icon_baku)
	_set_icon_hidden(icon_yuna)

func _posisi_awal_chat() -> float:
	return base_y - naikkan_posisi_chat

func tambah_chat(data: Dictionary):
	if is_animating:
		return
	
	is_animating = true

	if message_list.get_child_count() > 0:
		_hide_icons_for_chat_swap()
		var tween_lama = create_tween()
		tween_lama.tween_property(
			message_list,
			"position:y",
			message_list.position.y - dorong_chat_lama,
			0.22
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
		await tween_lama.finished
		_set_icon_hidden(icon_baku)
		_set_icon_hidden(icon_yuna)

	for child in message_list.get_children():
		child.queue_free()

	await get_tree().process_frame
	message_list.position.y = _posisi_awal_chat()
	current_y = _posisi_awal_chat()
	_reset_icons_to_base()
	
	var card = LevelCard.instantiate()
	message_list.add_child(card)
	card.setup(data)
	
	await get_tree().process_frame
	_show_icon_for_chat(icon_baku, true)
	current_y -= langkah_baku
	_pindah_ke(current_y)
	
	await get_tree().create_timer(0.6).timeout
	var bubble = NpcBubble.instantiate()
	message_list.add_child(bubble)
	bubble.setup(data)
	
	await get_tree().process_frame
	_show_icon_for_chat(icon_yuna, false)
	current_y -= langkah_yuna
	_pindah_ke(current_y, baku_follow_step_kedua_multiplier, 1.0)
	
	is_animating = false

func _pindah_ke(target_y: float, baku_multiplier: float = 1.0, yuna_multiplier: float = 1.0):
	var delta_y = target_y - message_list.position.y
	_tween_icons_follow_delta(delta_y, 0.3, baku_multiplier, yuna_multiplier)
	var tween = create_tween()
	tween.tween_property(
		message_list,
		"position:y",
		target_y,
		0.3
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	
#func tambah_chat(data: Dictionary):
	#if is_animating:
		#return
	#
	#is_animating = true
	#
	#var card = LevelCard.instantiate()
	#message_list.add_child(card)
	#card.setup(data)
	#
	#await get_tree().process_frame
	#_scroll_ke_atas(TINGGI_LAYAR)  
	#
	#await get_tree().create_timer(0.6).timeout
	#var bubble = NpcBubble.instantiate()
	#message_list.add_child(bubble)
	#bubble.setup(data)
	#
	#await get_tree().process_frame
	#_scroll_ke_atas(bubble.size.y)  
	#
	#is_animating = false
	#
func _scroll_ke_atas(tinggi_baru: float):
	var tween = create_tween()
	tween.tween_property(
		message_list,
		"position:y",
		message_list.position.y - tinggi_baru,
		0.3
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)

func _set_icon_hidden(icon: Node2D):
	if icon == null:
		return
	icon.modulate.a = 0.0
	icon.position = _get_icon_base_position(icon)
	icon.scale = _get_icon_base_scale(icon)
	var visual_target = _get_icon_visual_target(icon)
	if visual_target != null:
		visual_target.scale = _get_icon_visual_base_scale(icon)

func _hide_icons_for_chat_swap():
	_hide_icon(icon_baku, true)
	_hide_icon(icon_yuna, false)

func _hide_icon(icon: Node2D, is_baku: bool):
	if icon == null:
		return
	var tween_ref = baku_icon_tween if is_baku else yuna_icon_tween
	if tween_ref:
		tween_ref.kill()
	var visual_target = _get_icon_visual_target(icon)
	var visual_base_scale = _get_icon_visual_base_scale(icon)
	var arah_keluar = icon_keluar_arah.normalized()
	if arah_keluar == Vector2.ZERO:
		arah_keluar = Vector2.DOWN
	var keluar_delta = arah_keluar * (icon_masuk_dari_bawah * icon_keluar_jarak_multiplier)
	tween_ref = create_tween()
	tween_ref.set_parallel(true)
	if visual_target != null:
		tween_ref.tween_property(visual_target, "scale", visual_base_scale * icon_hide_stretch, 0.12).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tween_ref.tween_property(icon, "position", icon.position + keluar_delta, 0.18).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tween_ref.tween_property(icon, "modulate:a", 0.0, 0.16)
	if visual_target != null:
		tween_ref.chain().tween_property(visual_target, "scale", visual_base_scale, 0.1).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	if is_baku:
		baku_icon_tween = tween_ref
	else:
		yuna_icon_tween = tween_ref

func _show_icon_for_chat(icon: Node2D, is_baku: bool):
	if icon == null:
		return

	var target_pos = _get_icon_base_position(icon)
	var visual_target = _get_icon_visual_target(icon)
	var visual_base_scale = _get_icon_visual_base_scale(icon)
	_ensure_idle_playing(is_baku)
	var tween_ref = baku_icon_tween if is_baku else yuna_icon_tween
	if tween_ref:
		tween_ref.kill()

	icon.position = target_pos + Vector2(0, icon_masuk_dari_bawah)
	icon.modulate.a = 0.0
	if visual_target != null:
		visual_target.scale = visual_base_scale * icon_show_stretch

	tween_ref = create_tween()
	tween_ref.set_parallel(true)
	tween_ref.tween_property(icon, "position", target_pos, 0.28).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween_ref.tween_property(icon, "modulate:a", 1.0, 0.2)
	if visual_target != null:
		tween_ref.tween_property(visual_target, "scale", visual_base_scale * icon_show_overshoot, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween_ref.chain().tween_property(visual_target, "scale", visual_base_scale, 0.12).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	if is_baku:
		baku_icon_tween = tween_ref
	else:
		yuna_icon_tween = tween_ref

func _get_icon_base_position(icon: Node2D) -> Vector2:
	return baku_base_position if icon == icon_baku else yuna_base_position

func _get_icon_base_scale(icon: Node2D) -> Vector2:
	return baku_base_scale if icon == icon_baku else yuna_base_scale

func _get_icon_visual_target(icon: Node2D) -> Node2D:
	if icon == icon_baku:
		return baku_sprite if baku_sprite != null else icon_baku
	return yuna_sprite if yuna_sprite != null else icon_yuna

func _get_icon_visual_base_scale(icon: Node2D) -> Vector2:
	if icon == icon_baku:
		return baku_sprite_base_scale
	return yuna_sprite_base_scale

func _reset_icons_to_base():
	if icon_baku != null:
		icon_baku.position = baku_base_position
	if icon_yuna != null:
		icon_yuna.position = yuna_base_position

func _tween_icons_follow_delta(delta_y: float, duration: float, baku_multiplier: float = 1.0, yuna_multiplier: float = 1.0):
	if absf(delta_y) <= 0.001:
		return

	if icon_baku != null and icon_baku.modulate.a > 0.0:
		if baku_move_tween:
			baku_move_tween.kill()
		baku_move_tween = create_tween()
		baku_move_tween.tween_property(icon_baku, "position:y", icon_baku.position.y + (delta_y * baku_multiplier), duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)

	if icon_yuna != null and icon_yuna.modulate.a > 0.0:
		if yuna_move_tween:
			yuna_move_tween.kill()
		yuna_move_tween = create_tween()
		yuna_move_tween.tween_property(icon_yuna, "position:y", icon_yuna.position.y + (delta_y * yuna_multiplier), duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)

func _get_icon_sprite(icon: Node2D) -> AnimatedSprite2D:
	if icon == null:
		return null
	return icon.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

func _setup_icon_sprite(sprite: AnimatedSprite2D, is_baku: bool):
	if sprite == null:
		return
	sprite.centered = true
	sprite.offset = Vector2.ZERO
	var cb = Callable(self, "_on_icon_sprite_frame_changed").bind(is_baku)
	if not sprite.frame_changed.is_connected(cb):
		sprite.frame_changed.connect(cb)
	sprite.play("default")

func _ensure_idle_playing(is_baku: bool):
	var sprite = baku_sprite if is_baku else yuna_sprite
	if sprite == null:
		return
	if not sprite.is_playing():
		sprite.play("default")

func _on_icon_sprite_frame_changed(is_baku: bool):
	var icon = icon_baku if is_baku else icon_yuna
	var sprite = baku_sprite if is_baku else yuna_sprite
	if icon == null or sprite == null:
		return
	if icon.modulate.a <= 0.01:
		return
	if sprite.frame != 1:
		return

	var visual_target = _get_icon_visual_target(icon)
	var visual_base_scale = _get_icon_visual_base_scale(icon)
	if visual_target == null:
		return
	var pulse_tween = baku_pulse_tween if is_baku else yuna_pulse_tween
	if pulse_tween:
		pulse_tween.kill()

	pulse_tween = create_tween()
	pulse_tween.tween_property(visual_target, "scale", visual_base_scale * icon_frame2_pulse_scale, icon_frame2_pulse_up_duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	pulse_tween.tween_property(visual_target, "scale", visual_base_scale, icon_frame2_pulse_down_duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

	if is_baku:
		baku_pulse_tween = pulse_tween
	else:
		yuna_pulse_tween = pulse_tween
