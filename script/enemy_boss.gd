extends Node2D

signal bossfight_started
signal boss_defeated
signal boss_hp_changed(old_hp: int, new_hp: int)

enum BossState {
	INTRO,
	SUMMON,
	WEAKNESS,
	ATTACK,
	DEAD
}

const ORB_COLOR_RED := 0
const ORB_COLOR_BLUE := 1

@export var homing_orb_scene: PackedScene = preload("res://scenes/homing_orb.tscn")
@export var vortex_red_modulate: Color = Color(1.0, 0.45, 0.45, 1.0)
@export var vortex_blue_modulate: Color = Color(0.45, 0.7, 1.0, 1.0)

@export var hp_per_layer: int = 10
@export var layer_count: int = 2

@export var intro_speed: float = 280.0
@export var intro_start_distance: float = 340.0
@export var intro_spawn_above_margin: float = 220.0
@export var intro_arrive_threshold: float = 8.0
@export var intro_ui_return_delay: float = 1.1
@export var intro_ui_pull_distance: float = 900.0
@export var intro_ui_return_anim_duration: float = 0.45

@export var move_area_left: float = 80.0
@export var move_area_right: float = 1200.0
@export var move_area_top: float = 70.0
@export var move_area_bottom: float = 600.0
@export var move_speed_layer2_min: float = 95.0
@export var move_speed_layer2_max: float = 150.0
@export var move_speed_layer1_min: float = 145.0
@export var move_speed_layer1_max: float = 210.0
@export var move_target_change_min: float = 0.45
@export var move_target_change_max: float = 1.1

@export var weakness_move_target_change_min: float = 1.5
@export var weakness_move_target_change_max: float = 2.5
@export var weakness_move_speed_factor: float = 0.6

@export var summons_before_weakness_layer2: int = 3
@export var summons_before_weakness_layer1: int = 2
@export var summon_gap_min: float = 6.0
@export var summon_gap_max: float = 7.0
@export var summon_orb_count_min: int = 3
@export var summon_orb_count_max: int = 6
@export var spawn_stagger: float = 0.55
@export var weakened_state_interval: float = 8.0
@export var weakened_state_duration: float = 4.0

@export var weakness_count: int = 3
@export var weakness_duration_layer2: float = 6.0
@export var weakness_duration_layer1: float = 3.5

@export var weakness_approach_duration: float = 1.2
@export var weakness_approach_distance: float = 120.0
@export var weakness_approach_scale: float = 1.1
@export var weakness_retreat_duration: float = 1.0

@export var attack_damage: int = 1
@export var attack_anim_duration: float = 0.8

@export var flap_amplitude: float = 55.0
@export var flap_frequency: float = 1.6

@onready var body_anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var top_anim: AnimatedSprite2D = $AnimatedSprite2D/TopAnim
@onready var bot_anim: AnimatedSprite2D = $AnimatedSprite2D/BotAnim
@onready var mid_anim: AnimatedSprite2D = $AnimatedSprite2D/MidAnim
@onready var vortex_top: AnimatedSprite2D = $AnimatedSprite2D/TopAnim/VortexTop
@onready var vortex_mid: AnimatedSprite2D = $AnimatedSprite2D/MidAnim/VortexMid
@onready var top_orb_container: Node2D = $AnimatedSprite2D/TopAnim/VortexTop/OrbContainer
@onready var mid_orb_container: Node2D = $AnimatedSprite2D/MidAnim/VortexMid/OrbContainer
@onready var weakness_set: Area2D = $SetOfWeakness

var state: BossState = BossState.INTRO
var max_hp: int = 1
var hp: int = 1
var current_layer: int = 2

var player_node: Node2D
var crosshair_node: Node

var move_target: Vector2 = Vector2.ZERO
var move_speed_current: float = 120.0
var move_target_timer: float = 0.0

var weakness_active: bool = false
var weak_parent: Node2D
var active_weak_areas: Array[Area2D] = []

var intro_target_position: Vector2 = Vector2.ZERO
var weakness_original_position: Vector2 = Vector2.ZERO
var weakness_original_scale: Vector2 = Vector2.ONE

var _flap_time: float = 0.0
var _prev_flap_y: float = 0.0
var _container_turn: int = 0
var _template_weak_shapes: Array[Node2D] = []
var _template_to_required_character: Dictionary = {}
var _global_orb_spawn_order: int = 0
var _battle_ui_names: Array[String] = [
	"CardUI",
	"UIKoisuruMeter",
	"UIMahouMeter",
	"DamageHud",
	"Player",
	"Crosshair"
]
var _battle_ui_original_pos: Dictionary = {}
var _battle_ui_pulled_out: bool = false
var _forced_weakness_pending: bool = false
var _forced_weakness_duration: float = 5.0

var hitbox_area: Area2D

func _ready() -> void:
	add_to_group("enemy_nodes")
	max_hp = hp_per_layer * layer_count
	hp = max_hp
	current_layer = layer_count

	if body_anim != null:
		body_anim.play("idle")

	_collect_weakness_templates()
	_setup_hitbox()
	_set_summon_fx_idle()

	player_node = _find_player_node()
	crosshair_node = _find_crosshair_node()
	_set_battle_ui_pulled_out(true)
	_set_player_action_enabled(false)

	await _run_intro_phase()
	if state == BossState.DEAD:
		return

	await _set_battle_ui_pulled_out(false)
	if intro_ui_return_delay > 0.0:
		await get_tree().create_timer(intro_ui_return_delay).timeout
	_set_player_action_enabled(true)
	emit_signal("bossfight_started")
	_choose_new_move_target()
	await _run_boss_loop()

func _physics_process(delta: float) -> void:
	if state == BossState.DEAD:
		return

	if player_node == null or not is_instance_valid(player_node):
		player_node = _find_player_node()

	# Flapping biasa (sinusoidal), tanpa baca frame animasi.
	_flap_time += delta
	var flap_y := sin(_flap_time * flap_frequency * TAU) * flap_amplitude
	global_position.y += flap_y - _prev_flap_y
	_prev_flap_y = flap_y

	match state:
		BossState.INTRO:
			_update_intro_movement(delta)
		BossState.SUMMON, BossState.WEAKNESS, BossState.ATTACK:
			_update_random_movement(delta)

func on_hit(hit_area: Node = null) -> void:
	if state == BossState.DEAD:
		return
	if not weakness_active:
		return
	if hit_area == null or not (hit_area is Area2D) or not is_instance_valid(hit_area):
		return

	var weak_area := hit_area as Area2D
	if weak_area == null or not is_instance_valid(weak_area) or not active_weak_areas.has(weak_area):
		return

	var weak_parent := weak_area.get_parent() as Node2D
	if weak_parent == null or not is_instance_valid(weak_parent):
		return

	var required_char := String(weak_parent.get_meta("required_character", ""))
	if required_char == "":
		required_char = "baku"

	var shooter_char := _get_current_character_name()
	if shooter_char != required_char:
		return

	_remove_active_weakpoint(weak_area)
	_apply_boss_damage(1)

func can_be_hit_by_character(_character_name: String) -> bool:
	return weakness_active

func apply_damage(_amount: int) -> void:
	return

func instakill(_delay: float = 0.0) -> void:
	return

func set_marked(_value: bool) -> void:
	pass

func is_marked() -> bool:
	return false

func explode_mark(_radius: float, _damage: int) -> void:
	pass

func apply_slow(_duration: float, _factor: float) -> void:
	pass

func pull_towards(_target_pos: Vector2, _strength: float = 0.55) -> void:
	pass

func _run_intro_phase() -> void:
	state = BossState.INTRO
	_setup_intro_entry_path()
	while state == BossState.INTRO:
		if global_position.distance_to(intro_target_position) <= intro_arrive_threshold:
			global_position = intro_target_position
			state = BossState.SUMMON
			break
		await get_tree().process_frame

func _setup_intro_entry_path() -> void:
	var viewport_rect := get_viewport_rect()
	var center := viewport_rect.size * 0.5
	var target_x := clampf(center.x, move_area_left, move_area_right)
	var target_y := clampf(center.y, move_area_top, move_area_bottom)
	intro_target_position = Vector2(target_x, target_y)

	# Spawn awal selalu di atas viewport lalu turun masuk layar.
	global_position = Vector2(target_x, -intro_spawn_above_margin)
	_update_facing(1.0)

func _run_boss_loop() -> void:
	while state != BossState.DEAD:
		state = BossState.SUMMON
		var phase_timer := get_tree().create_timer(maxf(weakened_state_interval, 0.1))
		while state != BossState.DEAD and phase_timer.time_left > 0.0:
			if _forced_weakness_pending:
				break
			await _summon_orb_batch()
			if state == BossState.DEAD:
				break
			if _forced_weakness_pending:
				break
			var interrupted := await _wait_with_forced_check(randf_range(summon_gap_min, summon_gap_max))
			if interrupted:
				break

		if state == BossState.DEAD:
			break
		if _forced_weakness_pending:
			var forced_duration := _forced_weakness_duration
			_forced_weakness_pending = false
			await _run_weakness_phase(forced_duration, false)
			if state == BossState.DEAD:
				break
			continue

		await _run_weakness_phase()
		if state == BossState.DEAD:
			break

func _wait_with_forced_check(duration: float) -> bool:
	var remaining := maxf(duration, 0.0)
	while remaining > 0.0:
		if state == BossState.DEAD:
			return true
		if _forced_weakness_pending:
			return true
		await get_tree().process_frame
		remaining -= get_physics_process_delta_time()
	return false

func _run_summon_phase() -> void:
	state = BossState.SUMMON

	var summon_cycles := summons_before_weakness_layer2 if current_layer == 2 else summons_before_weakness_layer1
	for i in summon_cycles:
		if state == BossState.DEAD:
			return
		await _summon_orb_batch()
		if i < summon_cycles - 1:
			await get_tree().create_timer(randf_range(summon_gap_min, summon_gap_max)).timeout

func _run_weakness_phase(duration_override: float = -1.0, allow_early_clear: bool = true) -> bool:
	# Store original state before approaching
	weakness_original_position = global_position
	weakness_original_scale = scale
	
	# Approach screen and scale up
	await _approach_weakness_state()
	
	# Now enter weakness state
	state = BossState.WEAKNESS
	weakness_active = true
	_set_hitbox_enabled(false)
	_spawn_weakness_points()

	var weakness_duration := weakened_state_duration if duration_override <= 0.0 else duration_override
	var timeout_timer := get_tree().create_timer(maxf(weakness_duration, 0.1))

	while true:
		if state == BossState.DEAD:
			return false
		if allow_early_clear and active_weak_areas.is_empty():
			weakness_active = false
			_clear_weakness_points()
			_set_hitbox_enabled(true)
			break
		if timeout_timer.time_left <= 0.0:
			break
		await get_tree().process_frame

	# Retreat and scale back
	await _retreat_from_weakness_state()
	
	weakness_active = false
	var success := active_weak_areas.is_empty()
	_clear_weakness_points()
	_set_hitbox_enabled(true)
	return success

func force_weakened_state(duration: float = 5.0) -> void:
	if state == BossState.DEAD:
		return
	_forced_weakness_duration = maxf(duration, 0.1)
	_forced_weakness_pending = true

func _approach_weakness_state() -> void:
	"""Smoothly scale up before weakness state while continuing random movement"""
	var elapsed := 0.0
	var start_scale := scale
	
	while elapsed < weakness_approach_duration:
		if state == BossState.DEAD or not is_instance_valid(self):
			return
		
		elapsed += get_physics_process_delta_time()
		var progress := minf(elapsed / weakness_approach_duration, 1.0)
		
		scale = start_scale.lerp(start_scale * weakness_approach_scale, progress)
		
		await get_tree().process_frame

func _retreat_from_weakness_state() -> void:
	"""Smoothly scale down after weakness state while continuing random movement"""
	var elapsed := 0.0
	var current_scale := scale
	
	while elapsed < weakness_retreat_duration:
		if state == BossState.DEAD or not is_instance_valid(self):
			return
		
		elapsed += get_physics_process_delta_time()
		var progress := minf(elapsed / weakness_retreat_duration, 1.0)
		
		scale = current_scale.lerp(weakness_original_scale, progress)
		
		await get_tree().process_frame

func _run_attack_punish_phase() -> void:
	if state == BossState.DEAD:
		return
	state = BossState.ATTACK

	if body_anim != null:
		body_anim.play("attack")
	await get_tree().create_timer(attack_anim_duration).timeout

	if player_node != null and is_instance_valid(player_node) and player_node.has_method("take_damage"):
		player_node.take_damage(attack_damage)

	if body_anim != null:
		body_anim.play("idle")

	if state != BossState.DEAD:
		state = BossState.SUMMON

func _summon_orb_batch() -> void:
	var containers: Array[Node2D] = []
	if current_layer == 2:
		containers.append(top_orb_container if _container_turn == 0 else mid_orb_container)
		_container_turn = 1 - _container_turn
	else:
		containers = [top_orb_container, mid_orb_container]

	_play_summon_fx(containers)

	if containers.is_empty():
		_set_summon_fx_idle()
		return

	var total_orbs: int = randi_range(summon_orb_count_min, summon_orb_count_max)
	var remaining: int = total_orbs

	for idx in containers.size():
		var container := containers[idx]
		if container == null:
			continue

		var containers_left: int = containers.size() - idx
		var count_for_this: int = int(ceil(float(remaining) / float(maxi(containers_left, 1))))
		count_for_this = maxi(1, count_for_this)
		remaining = maxi(0, remaining - count_for_this)

		var leader: Node2D = null
		for i in count_for_this:
			leader = _spawn_single_orb(container, leader)
			if i < count_for_this - 1 and spawn_stagger > 0.0:
				await get_tree().create_timer(spawn_stagger).timeout

	_set_summon_fx_idle()

func _spawn_single_orb(container: Node2D, follow_leader: Node2D = null) -> Node2D:
	if homing_orb_scene == null:
		return follow_leader
	if container == null:
		return follow_leader

	var orb := homing_orb_scene.instantiate()
	if orb == null:
		return follow_leader

	var orb_color := _pick_spawn_orb_color()
	_apply_vortex_color(container, orb_color)

	if orb.has_method("set"):
		orb.set("batch_seed", randi())
		orb.set("time_offset", float(_global_orb_spawn_order) * 0.11)
		orb.set("randomize_color_on_spawn", false)
		orb.set("fixed_orb_color", orb_color)

	var spawn_parent := get_parent()
	if spawn_parent == null:
		spawn_parent = get_tree().current_scene
	if spawn_parent == null:
		return follow_leader

	spawn_parent.add_child(orb)
	orb.global_position = container.global_position
	orb.z_index = z_index + 200 - _global_orb_spawn_order
	_global_orb_spawn_order += 1

	if orb.has_method("setup"):
		orb.setup(player_node, follow_leader)

	return orb

func _pick_spawn_orb_color() -> int:
	return ORB_COLOR_RED if randf() < 0.5 else ORB_COLOR_BLUE

func _apply_vortex_color(container: Node2D, orb_color: int) -> void:
	var target_vortex: AnimatedSprite2D = null
	if container == top_orb_container:
		target_vortex = vortex_top
	elif container == mid_orb_container:
		target_vortex = vortex_mid

	if target_vortex == null:
		return

	target_vortex.modulate = vortex_red_modulate if orb_color == ORB_COLOR_RED else vortex_blue_modulate

func _play_summon_fx(containers: Array[Node2D]) -> void:
	_set_summon_fx_idle()

	var use_top := containers.has(top_orb_container)
	var use_mid := containers.has(mid_orb_container)

	if use_top:
		if top_anim != null:
			top_anim.play("summon")
		if vortex_top != null:
			vortex_top.visible = true
			vortex_top.play("default")

	if use_mid:
		if mid_anim != null:
			mid_anim.play("summon")
		if vortex_mid != null:
			vortex_mid.visible = true
			vortex_mid.play("default")

func _spawn_weakness_points() -> void:
	_clear_weakness_points()
	if _template_weak_shapes.is_empty():
		return

	var pool: Array = _template_weak_shapes.duplicate()
	# Remove any freed/invalid nodes before using pool
	pool = pool.filter(func(n): return is_instance_valid(n))
	pool.shuffle()
	var count: int = mini(3, pool.size())

	for i in count:
		var weak_parent: Node2D = pool[i] as Node2D
		if weak_parent == null:
			continue

		# Find or show the Area2D child
		var area: Area2D = null
		var sprite: AnimatedSprite2D = null
		for child in weak_parent.get_children():
			if child is Area2D and area == null:
				area = child as Area2D
			elif child is AnimatedSprite2D and sprite == null:
				sprite = child as AnimatedSprite2D

		if area == null or sprite == null:
			continue

		# Enable the area and set it up
		area.collision_layer = 1 << 1
		area.collision_mask = 0
		area.monitoring = true
		area.monitorable = true
		area.add_to_group("weak_point")

		# Determine weakness type and play appropriate animation
		var weak_type := _determine_weakness_type(i)
		var required_char: String = String(weak_type["character"])
		weak_parent.set_meta("required_character", required_char)

		# Play looping animation based on type
		var anim_name := "weak_red" if weak_type["is_red"] else "weak_blue"
		if sprite.sprite_frames.has_animation(anim_name):
			sprite.play(anim_name)

		active_weak_areas.append(area)
		weak_parent.show()

func _remove_active_weakpoint(area: Area2D) -> void:
	if not active_weak_areas.has(area):
		return
	active_weak_areas.erase(area)

	# Play explode animation before removal
	var weak_parent := area.get_parent() as Node2D
	if weak_parent != null:
		_play_weakness_explode(weak_parent)

func _clear_weakness_points() -> void:
	for area in active_weak_areas:
		if is_instance_valid(area):
			# Disable the area
			area.monitoring = false
			area.monitorable = false
			area.collision_layer = 0
			area.collision_mask = 0
			area.remove_from_group("weak_point")

			# Hide parent weak point
			var weak_parent := area.get_parent() as Node2D
			if weak_parent != null and is_instance_valid(weak_parent):
				weak_parent.hide()

	active_weak_areas.clear()

func _collect_weakness_templates() -> void:
	if weakness_set == null:
		return

	weakness_set.monitoring = false
	weakness_set.monitorable = false
	weakness_set.collision_layer = 0
	weakness_set.collision_mask = 0

	for child in weakness_set.get_children():
		if child is Node2D and not (child is Area2D) and not (child is AnimatedSprite2D):
			# This is a WeaknessPoint container node
			var weak_point := child as Node2D
			weak_point.hide()  # Hide initially

			# Find the Area2D child and disable it
			for grandchild in weak_point.get_children():
				if grandchild is Area2D:
					var area := grandchild as Area2D
					area.monitoring = false
					area.monitorable = false
					area.collision_layer = 0
					area.collision_mask = 0
					area.remove_from_group("weak_point")

			_template_weak_shapes.append(weak_point)

func _determine_weakness_type(index: int) -> Dictionary:
	# Returns {"is_red": bool, "character": string}
	# Alternate red/blue each time for variety
	var is_red := (index % 2) == 0

	return {
		"is_red": is_red,
		"character": "baku" if is_red else "yuna"
	}

func _play_weakness_explode(weak_parent: Node2D) -> void:
	# Find the sprite and play explode animation
	var sprite: AnimatedSprite2D = null
	for child in weak_parent.get_children():
		if child is AnimatedSprite2D:
			sprite = child as AnimatedSprite2D
			break

	if sprite == null:
		weak_parent.hide()
		return

	# Determine which explode animation to play
	var current_anim := sprite.animation
	var is_red := current_anim == "weak_red"
	var explode_anim := "explode_red" if is_red else "explode_blue"

	if not sprite.sprite_frames.has_animation(explode_anim):
		weak_parent.hide()
		return

	# Play explode animation and hide (not free) when done so node can be reused
	sprite.animation_finished.connect(
		func():
			if is_instance_valid(weak_parent):
				weak_parent.hide()
	,
		ConnectFlags.CONNECT_ONE_SHOT
	)

	sprite.play(explode_anim)

func _setup_hitbox() -> void:
	hitbox_area = Area2D.new()
	hitbox_area.name = "Hitbox"
	hitbox_area.collision_layer = 1 << 1
	hitbox_area.collision_mask = 0
	hitbox_area.add_to_group("enemy")
	add_child(hitbox_area)

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 430.0
	col.shape = shape
	hitbox_area.add_child(col)

func _set_summon_fx_idle() -> void:
	if top_anim != null:
		top_anim.play("idle")
	if bot_anim != null:
		bot_anim.play("idle")
	if mid_anim != null:
		mid_anim.play("idle")
	if vortex_top != null:
		vortex_top.visible = false
		vortex_top.modulate = Color.WHITE
		vortex_top.stop()
	if vortex_mid != null:
		vortex_mid.visible = false
		vortex_mid.modulate = Color.WHITE
		vortex_mid.stop()

func _update_intro_movement(delta: float) -> void:
	var to_target := intro_target_position - global_position
	if to_target.length() <= 0.001:
		return
	global_position += to_target.normalized() * intro_speed * delta
	_update_facing(to_target.x)

func _update_random_movement(delta: float) -> void:
	move_target_timer -= delta
	if move_target_timer <= 0.0:
		_choose_new_move_target()

	var dx := move_target.x - global_position.x
	if global_position.distance_to(move_target) > 2.0:
		var dir := (move_target - global_position).normalized()
		var speed := move_speed_current
		
		# Reduce speed during weakness phase for more stable movement
		if weakness_active:
			speed *= weakness_move_speed_factor
		
		global_position += dir * speed * delta
		_update_facing(dx)

	global_position.x = clampf(global_position.x, move_area_left, move_area_right)
	global_position.y = clampf(global_position.y, move_area_top, move_area_bottom)

func _choose_new_move_target() -> void:
	# Use longer intervals and slower speed during weakness phase
	if weakness_active:
		move_target_timer = randf_range(weakness_move_target_change_min, weakness_move_target_change_max)
	else:
		move_target_timer = randf_range(move_target_change_min, move_target_change_max)
	
	move_speed_current = randf_range(_get_move_speed_min(), _get_move_speed_max())
	
	# 70% chance for horizontal movement (left/right across screen)
	# 30% chance for vertical movement (up/down with reduced range)
	var x_center := (move_area_left + move_area_right) * 0.5
	var y_center := (move_area_top + move_area_bottom) * 0.5
	# Horizontal travel is 60% of half-width from center, keeping boss away from edges
	var x_half := (move_area_right - move_area_left) * 0.3

	if randf() < 0.7:
		# Horizontal movement - swing left or right from center, but not to the edge
		var side := 1.0 if randf() < 0.5 else -1.0
		var target_x := x_center + side * randf_range(x_half * 0.4, x_half)

		# Keep Y in a narrow middle band
		var y_range := (move_area_bottom - move_area_top) * 0.2
		var target_y := y_center + randf_range(-y_range, y_range)

		move_target = Vector2(target_x, target_y)
	else:
		# Free movement - still stays within a centered region
		var target_x := x_center + randf_range(-x_half, x_half)
		var y_range := (move_area_bottom - move_area_top) * 0.3
		var target_y := y_center + randf_range(-y_range, y_range)

		move_target = Vector2(target_x, target_y)

func _update_facing(horizontal_delta: float) -> void:
	if absf(horizontal_delta) < 1.0:
		return
	var face_left := horizontal_delta < 0.0
	for spr in [body_anim, top_anim, bot_anim, mid_anim]:
		if spr != null:
			spr.flip_h = face_left

func _get_move_speed_min() -> float:
	return move_speed_layer2_min if current_layer == 2 else move_speed_layer1_min

func _get_move_speed_max() -> float:
	return move_speed_layer2_max if current_layer == 2 else move_speed_layer1_max

func _apply_boss_damage(amount: int) -> void:
	if state == BossState.DEAD or amount <= 0:
		return

	var old_hp := hp
	hp = max(hp - amount, 0)
	emit_signal("boss_hp_changed", old_hp, hp)

	if hp <= hp_per_layer and current_layer == 2:
		current_layer = 1

	if hp <= 0:
		_die()

func _die() -> void:
	if state == BossState.DEAD:
		return
	state = BossState.DEAD
	weakness_active = false
	_clear_weakness_points()
	await _set_battle_ui_pulled_out(false)
	_set_player_action_enabled(true)

	if hitbox_area != null:
		hitbox_area.monitoring = false
		hitbox_area.monitorable = false
		hitbox_area.collision_layer = 0

	emit_signal("boss_defeated")
	queue_free()

func _set_player_action_enabled(enabled: bool) -> void:
	if crosshair_node != null:
		crosshair_node.set_process(enabled)
		crosshair_node.set_physics_process(enabled)
		crosshair_node.set_process_input(enabled)
	if player_node != null:
		player_node.set_process_input(enabled)

func _get_current_character_name() -> String:
	if player_node != null and player_node.has_method("get_current_character_name"):
		return String(player_node.get_current_character_name())
	return "baku"

func _set_hitbox_enabled(enabled: bool) -> void:
	if hitbox_area == null:
		return
	hitbox_area.monitoring = enabled
	hitbox_area.monitorable = enabled
	hitbox_area.collision_layer = (1 << 1) if enabled else 0

func _find_player_node() -> Node2D:
	var root := get_tree().current_scene
	if root == null:
		return null
	return root.find_child("Player", true, false) as Node2D

func _find_crosshair_node() -> Node:
	var root := get_tree().current_scene
	if root == null:
		return null
	return root.find_child("Crosshair", true, false)

func _set_battle_ui_pulled_out(pulled: bool) -> void:
	if _battle_ui_pulled_out == pulled:
		return

	var root := get_tree().current_scene
	if root == null:
		return

	var viewport_rect := get_viewport_rect()
	var pull_dist := maxf(intro_ui_pull_distance, viewport_rect.size.y + 220.0)
	var restore_tween: Tween = null
	if not pulled and intro_ui_return_anim_duration > 0.0:
		restore_tween = create_tween()
		restore_tween.set_trans(Tween.TRANS_CUBIC)
		restore_tween.set_ease(Tween.EASE_OUT)
		restore_tween.set_parallel(true)

	for name in _battle_ui_names:
		var node := root.find_child(name, true, false)
		if node == null:
			continue

		# UIMahouMeter ditarik ke atas; elemen lain ditarik ke bawah.
		var pull_vec := Vector2(0.0, pull_dist)
		if name == "UIMahouMeter":
			pull_vec = Vector2(0.0, -pull_dist)
		elif name == "CardUI":
			pull_vec = Vector2(-pull_dist, pull_dist)
		elif name == "Player":
			pull_vec = Vector2(pull_dist, pull_dist)

		if node is Node2D:
			var n2d := node as Node2D
			if pulled:
				if not _battle_ui_original_pos.has(name):
					_battle_ui_original_pos[name] = n2d.position
				n2d.position = (_battle_ui_original_pos[name] as Vector2) + pull_vec
			elif _battle_ui_original_pos.has(name):
				var target_pos := _battle_ui_original_pos[name] as Vector2
				if restore_tween != null:
					restore_tween.tween_property(n2d, "position", target_pos, intro_ui_return_anim_duration)
				else:
					n2d.position = target_pos
			continue

		if node is CanvasLayer:
			var layer := node as CanvasLayer
			if pulled:
				if not _battle_ui_original_pos.has(name):
					_battle_ui_original_pos[name] = layer.offset
				layer.offset = (_battle_ui_original_pos[name] as Vector2) + pull_vec
			elif _battle_ui_original_pos.has(name):
				var target_offset := _battle_ui_original_pos[name] as Vector2
				if restore_tween != null:
					restore_tween.tween_property(layer, "offset", target_offset, intro_ui_return_anim_duration)
				else:
					layer.offset = target_offset

	_battle_ui_pulled_out = pulled

	if restore_tween != null:
		await restore_tween.finished
