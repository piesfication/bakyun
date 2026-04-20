extends Node2D

signal hp_changed(old_hp: int, new_hp: int)
signal character_switched(character_name: String)
signal died

@export var max_hp := 30000000
var current_hp := max_hp
var invulnerable: bool = false

@onready var baku := $BakuMahou
@onready var yuna := $YunaMahou

var current_weapon: Node2D
var input_locked: bool = false
var switch_locked: bool = false

@export var damage_shake_duration: float = 0.24
@export var damage_shake_strength: float = 26.0
@export var damage_shake_frequency: float = 95.0
@export var bird_strike_shake_duration: float = 0.68
@export var bird_strike_shake_strength: float = 95.0
@export var bird_strike_shake_frequency: float = 155.0
@export var bird_strike_shake_falloff_power: float = 0.55
@export var damage_hud_path: NodePath = NodePath("../DamageHud")
@export var damage_hud_flash_duration: float = 0.22
@export_range(0.02, 0.3, 0.01, "suffix:s") var bird_strike_hud_flicker_interval: float = 0.14

var _shake_time_left: float = 0.0
var _shake_prev_offset: Vector2 = Vector2.ZERO
var _shake_phase: float = 0.0
var _shake_duration_current: float = 0.24
var _shake_strength_current: float = 26.0
var _shake_frequency_current: float = 95.0
var _shake_falloff_power_current: float = 2.0
var _shake_target: Node2D
var _damage_hud: CanvasItem
var _damage_hud_time_left: float = 0.0
var _damage_hud_forced: bool = false
var _damage_hud_flicker_timer: float = 0.0
var _damage_hud_flicker_visible: bool = true


func _ready():
	current_hp = max_hp
	_shake_target = get_tree().current_scene as Node2D
	if has_node(damage_hud_path):
		_damage_hud = get_node(damage_hud_path) as CanvasItem
	if _damage_hud != null:
		_damage_hud.visible = false

	baku.visible = true
	yuna.visible = false
	current_weapon = baku
	
	emit_signal("character_switched", get_current_character_name())

func _process(delta: float) -> void:
	_update_damage_shake(delta)
	_update_damage_hud(delta)


func _input(event):
	if input_locked or switch_locked:
		return
	if event.is_action_pressed("switch"):
		switch_weapon()

func switch_weapon():
	if input_locked or switch_locked:
		return
	current_weapon.visible = false

	if current_weapon == baku:
		current_weapon = yuna
	else:
		current_weapon = baku

	current_weapon.visible = true
	emit_signal("character_switched", get_current_character_name())


func set_current_character(character_name: String) -> void:
	var normalized_character := character_name.to_lower()
	var target_weapon: Node2D = baku
	if normalized_character == "yuna":
		target_weapon = yuna

	if current_weapon == target_weapon:
		return

	if current_weapon != null and is_instance_valid(current_weapon):
		current_weapon.visible = false

	current_weapon = target_weapon
	current_weapon.visible = true
	emit_signal("character_switched", get_current_character_name())


func get_current_character_name() -> String:
	if current_weapon == yuna:
		return "yuna"
	return "baku"


# ===== HP TETAP =====
func take_damage(amount: int):
	if invulnerable:
		return
	if amount <= 0:
		return

	var old_hp := current_hp
	current_hp = clamp(current_hp - amount, 0, max_hp)

	if current_hp != old_hp:
		emit_signal("hp_changed", old_hp, current_hp)
		_start_damage_shake()
		_trigger_damage_hud()

	print("Player HP:", current_hp)

	if current_hp <= 0:
		die()


func die():
	print("GAME OVER")
	emit_signal("died")


func set_input_locked(locked: bool) -> void:
	input_locked = locked


func set_switch_locked(locked: bool) -> void:
	switch_locked = locked

func set_invulnerable(enabled: bool) -> void:
	invulnerable = enabled

func set_damage_hud_forced(enabled: bool) -> void:
	_damage_hud_forced = enabled
	_damage_hud_flicker_timer = 0.0
	_damage_hud_flicker_visible = true
	if _damage_hud == null or not is_instance_valid(_damage_hud):
		if has_node(damage_hud_path):
			_damage_hud = get_node(damage_hud_path) as CanvasItem
		if _damage_hud == null:
			return

	if _damage_hud_forced:
		_damage_hud.visible = true
		return

	if current_hp <= 1:
		_damage_hud.visible = true
		return

	if _damage_hud_time_left <= 0.0:
		_damage_hud.visible = false

func _start_damage_shake() -> void:
	Transition.play_crt_glitch_burst()
	if _shake_target == null or not is_instance_valid(_shake_target):
		_shake_target = get_tree().current_scene as Node2D
	if _shake_target == null:
		return

	_shake_duration_current = maxf(damage_shake_duration, 0.001)
	_shake_strength_current = maxf(damage_shake_strength, 0.0)
	_shake_frequency_current = maxf(damage_shake_frequency, 0.0)
	_shake_falloff_power_current = 2.0
	_shake_time_left = maxf(_shake_time_left, _shake_duration_current)
	_shake_phase = randf() * TAU

func trigger_screen_shake() -> void:
	if _shake_target == null or not is_instance_valid(_shake_target):
		_shake_target = get_tree().current_scene as Node2D
	if _shake_target == null:
		return

	_shake_duration_current = maxf(bird_strike_shake_duration, 0.001)
	_shake_strength_current = maxf(bird_strike_shake_strength, 0.0)
	_shake_frequency_current = maxf(bird_strike_shake_frequency, 0.0)
	_shake_falloff_power_current = maxf(bird_strike_shake_falloff_power, 0.1)
	_shake_time_left = maxf(_shake_time_left, _shake_duration_current)
	_shake_phase = randf() * TAU

func _update_damage_shake(delta: float) -> void:
	if _shake_target == null or not is_instance_valid(_shake_target):
		return

	if _shake_time_left <= 0.0:
		if _shake_prev_offset != Vector2.ZERO:
			_shake_target.position -= _shake_prev_offset
			_shake_prev_offset = Vector2.ZERO
		return

	_shake_time_left -= delta
	var life_t := clampf(_shake_time_left / maxf(_shake_duration_current, 0.001), 0.0, 1.0)
	var falloff := pow(life_t, _shake_falloff_power_current)
	_shake_phase += delta * _shake_frequency_current

	var base_dir := Vector2(cos(_shake_phase), sin(_shake_phase * 1.37)).normalized()
	var noise := Vector2(randf_range(-0.35, 0.35), randf_range(-0.35, 0.35))
	var mixed := base_dir + noise
	if mixed.length() > 0.001:
		mixed = mixed.normalized()
	var new_offset := mixed * (_shake_strength_current * falloff)

	_shake_target.position += new_offset - _shake_prev_offset
	_shake_prev_offset = new_offset

func _trigger_damage_hud() -> void:
	if _damage_hud == null or not is_instance_valid(_damage_hud):
		if has_node(damage_hud_path):
			_damage_hud = get_node(damage_hud_path) as CanvasItem
		if _damage_hud == null:
			return

	if current_hp <= 1:
		_damage_hud.visible = true
		_damage_hud_time_left = 0.0
		return

	_damage_hud.visible = true
	_damage_hud_time_left = damage_hud_flash_duration

func _update_damage_hud(delta: float) -> void:
	if _damage_hud == null or not is_instance_valid(_damage_hud):
		return

	if _damage_hud_forced:
		_damage_hud_flicker_timer += delta
		if _damage_hud_flicker_timer >= bird_strike_hud_flicker_interval:
			_damage_hud_flicker_timer = 0.0
			_damage_hud_flicker_visible = not _damage_hud_flicker_visible
		_damage_hud.visible = _damage_hud_flicker_visible
		return

	if current_hp <= 1:
		_damage_hud.visible = true
		return

	if _damage_hud_time_left > 0.0:
		_damage_hud_time_left -= delta
		if _damage_hud_time_left <= 0.0:
			_damage_hud.visible = false
