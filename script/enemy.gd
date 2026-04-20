extends Node2D

# ==================================================
# VISUAL
# ==================================================
@onready var visual: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var health_visual: AnimatedSprite2D = $Visual/Health
@onready var skill_red3_effect: AnimatedSprite2D = $SkillRed3Effect
@onready var skill_blue3_effect: AnimatedSprite2D = $SkillBlue3Effect
@onready var hitvis := $HitVisual
@onready var hitbox_area: Area2D = $Hitbox
var original_modulate: Color
var _health_base_scale: Vector2 = Vector2.ONE
var _health_squash_tween: Tween

var _pending_nova_pull = null
# State

enum State {
	MOVING,
	DAMAGED,
	ATTACK,
	DEATH
}

var state := State.MOVING

func set_state(new_state: State):
	if state == new_state:
		return
	state = new_state

	match state:
		State.MOVING:
			if nova_pull_time_left <= 0.0:
				visual.modulate = original_modulate
			visual.play("moving")
		State.DAMAGED:
			if nova_pull_time_left <= 0.0:
				visual.modulate = Color(1.0, 0.804, 0.815, 1.0)
			visual.play("damaged")
		State.ATTACK:
			print("attack!")
			pass
		State.DEATH:
			if nova_pull_time_left <= 0.0:
				visual.modulate = Color(1.0, 0.804, 0.815, 1.0)
			visual.play("death")

@export var max_hp := 3
var hp := max_hp
var is_dead := false
var marked := false
@export_range(0.1, 20.0, 0.1, "suffix:s") var mark_duration: float = 3.0
var mark_time_left: float = 0.0
var slow_timer := 0.0
var slow_factor := 1.0
var nova_pull_time_left := 0.0
var nova_pull_target_pos: Vector2 = Vector2.ZERO
var nova_pull_target_depth := 0.5
var nova_pull_speed := 420.0
var nova_pull_depth_lerp_speed := 2.8
var nova_pull_arrive_distance := 10.0

@export var weak_point: Node2D 

# Logic nyerang player

@export var min_attack_cd := 1.2
@export var max_attack_cd := 2.8

@export var attack_damage: int = 1
@export var attack_cooldown: float = 2  # tiap 1,5 detik bisa menyerang lagi
@export var can_attack: bool = true
@export var explode_on_close: bool = false
@export var explode_close_damage: int = 1

var player_node: Node2D
var attack_timer: float = 0.0
var is_attacking: bool = false
var _close_explode_triggered: bool = false

# ===========================
var base_y : float = 0.0
var last_velocity: Vector2 = Vector2.ZERO

var drift_dir: Vector2 = Vector2.ZERO

@export var drift_radius_x := 220.0
@export var drift_radius_y := 60.0

# ==================================================
# DEPTH & SCALE (ILUSI 3D)
# ==================================================
@export var approach_speed: float = 0.07
@export var min_scale: float = 0.06
@export var max_scale: float = 0.3
@export var drift_start_scale: float = 0.065

var depth: float = 1.0   # 1 = jauh, 0 = dekat

# ==================================================
# Z ORDER
# ==================================================
@export var z_far: int = 0
@export var z_front: int = 40
var is_front: bool = false

# Static spawn counter for z_index stacking
static var _spawn_counter: int = 0
static var _global_scale_z_sync_pending: bool = false
static var _global_scale_z_sync_frame: int = -1
var _my_spawn_order: int = 0

# ==================================================
# APPROACH (CURVED KIRI-ATAS)
# ==================================================
@export var approach_move_speed: float = 350.0
@export var curve_amplitude: float = 40.0
@export var curve_frequency: float = 2.0
@export var approach_target: Vector2 = Vector2(640.0, 430.0)
@export var approach_target_random_x: float = 90.0
@export var approach_target_random_y: float = 18.0
@export var approach_target_min_y: float = 395.0
@export var flip_when_moving_right: bool = false

var approach_direction: Vector2
var curve_time: float = 0.0

# ==================================================
# DRIFT (FASE DEKAT) - IMPROVED
# ==================================================
@export var drift_radius: float = 120.0
@export var drift_speed: float = 1.5

# Variasi random untuk drift pattern
@export var drift_pattern_change_interval: float = 3.0  # Ganti pattern tiap X detik
var drift_pattern_timer: float = 0.0
var drift_freq_x: float = 1.0
var drift_freq_y: float = 0.9
var drift_phase_x: float = 0.0
var drift_phase_y: float = 0.0

# Bias ke atas
@export var upward_drift_bias: float = 25.0  # Tambahan gerakan ke atas
@export var vertical_boundary_top: float = 50.0  # Jarak dari atas layar (lebih tinggi)
@export var vertical_boundary_bottom: float = 500.0  # Jarak dari bawah layar (lebih tinggi)

# Kecepatan konstan
@export var drift_move_speed: float = 180.0  # Kecepatan konstan saat drift

var drift_origin: Vector2
var drift_time: float = 0.0
var drifting: bool = false

# Target untuk smooth movement
var drift_target_pos: Vector2 = Vector2.ZERO
var current_drift_direction: Vector2 = Vector2.ZERO
var trigger_zorder_area: Area2D
var trigger_zorder_polygon: CollisionPolygon2D
var trigger_zorder_polygons: Array[CollisionPolygon2D] = []
var has_entered_trigger_zorder: bool = false
@export var background_top_z: int = 30
@export var background_front_z: int = 20
var target_before_drift_shape: CollisionShape2D
var target_before_drift_polygon: CollisionPolygon2D
var target_before_drift_anchor: Node2D
var use_target_before_drift: bool = false
var reached_target_before_drift: bool = false
var _probe_shape: CircleShape2D
var pre_drift_target_point: Vector2 = Vector2.ZERO
var has_pre_drift_target_point: bool = false
@export var pre_drift_steer_strength: float = 3.0
@export var pre_drift_arrive_distance: float = 24.0

# ==================================================
# BIRD FLAPPING (IDLE ANIMATION)
# ==================================================
@export_group("Bird Flapping Animation")
@export var flap_amplitude := 12.0  # Seberapa tinggi naik turun
@export var flap_speed := 11   # Seberapa cepat mengepak
@export var flap_enabled := true  # Toggle on/off

var flap_time := 0.0
var base_position_y := 0.0  # Base Y position untuk flapping



# ==================================================
# BLEND
# ==================================================
@export var drift_blend_speed := 1.5
var drift_blend := 0.0   # 0 = approach, 1 = drift


# ==================================================

func _ready():
	add_to_group("enemy_nodes")
	hp = max_hp
	_probe_shape = CircleShape2D.new()
	_probe_shape.radius = 1.0
	skill_red3_effect.visible = false
	skill_red3_effect.animation_finished.connect(_on_skill_red3_effect_finished)
	_resolve_trigger_zorder_nodes()
	has_entered_trigger_zorder = false
	_resolve_target_before_drift_nodes()
	_pick_target_before_drift_point()
	if health_visual != null:
		_health_base_scale = health_visual.scale
		health_visual.visible = false
		health_visual.stop()
		if not health_visual.animation_finished.is_connected(_on_health_visual_animation_finished):
			health_visual.animation_finished.connect(_on_health_visual_animation_finished)
	if weak_point is Area2D:
		var weak_area := weak_point as Area2D
		weak_area.monitoring = false
		weak_area.monitorable = false
		weak_area.collision_layer = 0
		weak_area.collision_mask = 0
		weak_area.remove_from_group("weak_point")
	#attack_timer = randf_range(0.0, attack_cooldown)
	original_modulate = self.modulate 
	set_state(State.MOVING)

	player_node = _find_player_node()

	base_y = visual.position.y

	visual.play("moving")


	# --- Z ORDER LOGIC: stack by spawn order for non-boss ---
	var is_boss := false
	if "boss" in String(self.name).to_lower():
		is_boss = true

	# Hanya set z_index jika belum di-set oleh spawner (z_index == 0)
	if z_index == 0:
		if not is_boss:
			_my_spawn_order = _spawn_counter
			_spawn_counter += 1
			# Enemy yang spawn duluan (order kecil) dapat z_index lebih tinggi (lebih depan)
			# Tapi tetap selalu di bawah Front (z_index=20) dan Sea (z_index=30)
			var base_z = background_front_z - 10 # e.g. 10 if front is 20
			z_index = base_z + 1000 - _my_spawn_order
			# Clamp agar tidak pernah >= background_front_z
			var min_z = base_z + 1 # di depan Back/Back2
			var max_z = background_front_z - 1 # di belakang Front
			z_index = clamp(z_index, min_z, max_z)
		else:
			z_index = z_front

	scale = Vector2.ONE * 0.15

	# Use a soft approach target for pre-drift steering.
	var base_target := approach_target
	if use_target_before_drift and has_pre_drift_target_point:
		base_target = pre_drift_target_point
	elif target_before_drift_anchor != null:
		base_target = target_before_drift_anchor.global_position
	var target := base_target + Vector2(
		randf_range(-approach_target_random_x, approach_target_random_x),
		randf_range(-approach_target_random_y, approach_target_random_y)
	)
	target.y = maxf(target.y, approach_target_min_y)
	approach_direction = (target - position).normalized()
	if approach_direction == Vector2.ZERO:
		approach_direction = Vector2(-0.9, -0.1).normalized()

	curve_time = randf() * TAU
	drift_origin = position

	# Randomize drift pattern awal
	randomize_drift_pattern()
	
	# Initialize flap time dengan random offset agar tidak semua enemy sync
	flap_time = randf() * TAU
	
	
func _process(delta: float):
	if is_dead:
		return

	if marked:
		mark_time_left = maxf(mark_time_left - delta, 0.0)
		if mark_time_left <= 0.0:
			marked = false

	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			slow_factor = 1.0

	var sim_delta: float = delta * slow_factor

	idle_move(sim_delta)
	update_depth(sim_delta)
	update_scale()

	update_drift_blend(sim_delta)
	update_movement(sim_delta)
	_apply_nova_pull(sim_delta)
	update_scale()
	
	# Apply bird flapping animation AFTER movement
	if flap_enabled:
		apply_bird_flapping(sim_delta)
	
	update_phase_and_z()
	_apply_trigger_zorder_override()
	_request_global_scale_z_sync()
	
	update_flip()
	
	if player_node == null or not is_instance_valid(player_node):
		player_node = _find_player_node()

	if player_node:
		attack_timer -= sim_delta
		if depth == 0 and not is_attacking:
			if explode_on_close:
				_trigger_close_explode()
			elif can_attack and attack_timer <= 0:
				start_attack()

func _find_player_node() -> Node2D:
	var tree := get_tree()
	if tree == null:
		return null

	var root := tree.get_root()
	if root != null:
		var from_main := root.get_node_or_null("Main/Player") as Node2D
		if from_main != null:
			return from_main

		var from_main2 := root.get_node_or_null("Main2/Player") as Node2D
		if from_main2 != null:
			return from_main2

	var scene_root := tree.current_scene
	if scene_root != null:
		var from_scene := scene_root.find_child("Player", true, false) as Node2D
		if from_scene != null:
			return from_scene

	return null
	
func start_attack():
	if is_dead or not can_attack:
		return

	is_attacking = true
	attack_timer = randf_range(min_attack_cd, max_attack_cd)
	set_state(State.ATTACK)
	visual.play("attack")

func _trigger_close_explode() -> void:
	if _close_explode_triggered or is_dead:
		return
	_close_explode_triggered = true

	if player_node != null and is_instance_valid(player_node):
		if player_node.has_method("take_damage"):
			player_node.take_damage(max(explode_close_damage, 0))

	die()

@export var idle_amplitude := 8.0  # Dikurangi karena flapping sudah handle naik turun
@export var idle_speed := 2.5
var idle_time := 0.0

func idle_move(delta):
	idle_time += delta * idle_speed
	
	visual.position.y = base_y + sin(idle_time) * idle_amplitude


func apply_bird_flapping(delta):
	flap_time += delta * flap_speed

	var flap_offset = sin(flap_time) * flap_amplitude
	
	position.y += flap_offset * delta * 10.0


func update_depth(delta):
	depth -= approach_speed * delta
	depth = clamp(depth, 0.0, 1.0)


func update_scale():
	var scale_factor = lerpf(max_scale, min_scale, smoothstep(0.0, 1.0, depth))
	scale = Vector2.ONE * scale_factor
	

func update_drift_blend(delta):
	if drifting:
		drift_blend = move_toward(drift_blend, 1.0, delta * drift_blend_speed)
	else:
		drift_blend = move_toward(drift_blend, 0.0, delta * drift_blend_speed)


func randomize_drift_pattern():
	
	drift_freq_x = randf_range(0.3, 0.8)
	drift_freq_y = randf_range(0.25, 0.7)
	drift_phase_x = randf() * TAU
	drift_phase_y = randf() * TAU


func update_movement(delta):
	if use_target_before_drift and not reached_target_before_drift and has_pre_drift_target_point:
		var desired_direction := (pre_drift_target_point - position).normalized()
		if desired_direction != Vector2.ZERO:
			# Smooth steering so movement feels organic instead of magnet-pulled.
			approach_direction = approach_direction.lerp(desired_direction, minf(delta * pre_drift_steer_strength, 1.0)).normalized()

	
	curve_time += delta * curve_frequency

	var base_move = approach_direction * approach_move_speed * delta

	var perpendicular = Vector2(
		-approach_direction.y,
		 approach_direction.x
	)

	var curve_offset = perpendicular * sin(curve_time) * curve_amplitude * delta

	var approach_velocity = base_move + curve_offset


	# ---------- DRIFT (IMPROVED) ----------
	if drifting:
		# Update timer untuk ganti pattern
		drift_pattern_timer += delta
		if drift_pattern_timer >= drift_pattern_change_interval:
			drift_pattern_timer = 0.0
			randomize_drift_pattern()
	
	drift_time += delta * drift_speed
	var depth_factor = 1.0 - depth

	# Pattern lebih random dengan frekuensi dan fase yang berbeda
	# Perbesar area drift dengan multiplier
	var drift_offset = Vector2(
		sin(drift_time * drift_freq_x + drift_phase_x) * drift_radius_x * depth_factor * 2.0,
		cos(drift_time * drift_freq_y + drift_phase_y) * drift_radius_y * depth_factor * 2.5
	)

	# Bias ke atas yang lebih kuat
	var upward_bias_offset = Vector2(0, -upward_drift_bias * depth_factor)

	drift_target_pos = drift_origin + drift_offset + upward_bias_offset
	
	# Soft boundary correction
	if drift_target_pos.y > vertical_boundary_bottom:
		drift_target_pos.y = vertical_boundary_bottom - 20
	elif drift_target_pos.y > vertical_boundary_bottom - 150:
		# Push ke atas saat mendekati bawah
		var push_strength = (150 - (vertical_boundary_bottom - drift_target_pos.y)) / 150.0
		drift_target_pos.y -= push_strength * 80
	
	if drift_target_pos.y < vertical_boundary_top:
		drift_target_pos.y = vertical_boundary_top + 20
	
	# Hitung direction dengan kecepatan KONSTAN
	var direction_to_target = (drift_target_pos - position).normalized()
	
	# Smooth interpolation untuk direction agar tidak tiba-tiba belok
	current_drift_direction = current_drift_direction.lerp(direction_to_target, delta * 2.0)
	
	# Velocity dengan kecepatan konstan
	var drift_velocity = current_drift_direction * drift_move_speed * delta



	# ---------- BLEND ----------
	var final_velocity = approach_velocity.lerp(
		drift_velocity,
		drift_blend
	)
	
	last_velocity = final_velocity
	position += final_velocity
	
	# Soft clamp posisi horizontal
	if position.x < 30:
		position.x = 30
		current_drift_direction.x = abs(current_drift_direction.x)  # Bounce
	elif position.x > 1250:
		position.x = 1250
		current_drift_direction.x = -abs(current_drift_direction.x)  # Bounce
		
	# Soft clamp posisi vertical
	if position.y < vertical_boundary_top:
		position.y = vertical_boundary_top
		current_drift_direction.y = abs(current_drift_direction.y)  # Bounce
	elif position.y > vertical_boundary_bottom:
		position.y = vertical_boundary_bottom
		current_drift_direction.y = -abs(current_drift_direction.y)  # Bounce


func update_flip():
	if abs(last_velocity.x) < 1.0:
		return

	if flip_when_moving_right:
		visual.flip_h = last_velocity.x > 0
	else:
		visual.flip_h = last_velocity.x < 0
	

func update_curved_approach(delta):
	curve_time += delta * curve_frequency
	
	var base_move = approach_direction * approach_move_speed * delta

	var perpendicular = Vector2(
		-approach_direction.y,
		 approach_direction.x
	)

	var curve_offset = perpendicular * sin(curve_time) * curve_amplitude * delta

	position += base_move + curve_offset
	
	
func update_drift(delta):
	drift_time += delta * drift_speed

	var offset = Vector2(
		sin(drift_time),
		cos(drift_time * 0.8)
	) * drift_radius

	var target_pos = drift_origin + offset

	position = position.lerp(target_pos, 4.0 * delta)

	
	
func update_phase_and_z():
	var current_scale = scale.x
	if use_target_before_drift and not reached_target_before_drift:
		reached_target_before_drift = _is_inside_target_before_drift() or (has_pre_drift_target_point and position.distance_to(pre_drift_target_point) <= pre_drift_arrive_distance)

	var can_start_drift := false
	if use_target_before_drift:
		can_start_drift = reached_target_before_drift
	else:
		can_start_drift = current_scale >= drift_start_scale

	if not drifting and can_start_drift:

		drifting = true
		z_index = z_front
		drift_origin = position
		drift_time = randf() * TAU
		
		# Pindahkan drift_origin lebih ke atas agar enemy terbang di area atas
		drift_origin.y = min(drift_origin.y, 300)  # Maksimal di y=300
		
		# Reset pattern timer
		drift_pattern_timer = 0.0
		randomize_drift_pattern()
		
		# Initialize direction
		current_drift_direction = Vector2(randf_range(-1, 1), -0.5).normalized()
		
		var drift_dir_x := randf_range(-1.0, 1.0)
		var drift_dir_y := -pow(randf(), 2.5)
		drift_dir = Vector2(drift_dir_x, drift_dir_y).normalized()

	_update_z_from_depth()

func _resolve_target_before_drift_nodes() -> void:
	var root := get_tree().current_scene
	if root == null:
		return

	# Accept either CollisionShape2D or CollisionPolygon2D named targetbeforedrift/TargetBeforeDrift.
	var direct_shape := root.find_child("targetbeforedrift", true, false) as CollisionShape2D
	if direct_shape == null:
		direct_shape = root.find_child("TargetBeforeDrift", true, false) as CollisionShape2D
	if direct_shape != null:
		target_before_drift_shape = direct_shape
		target_before_drift_anchor = direct_shape
		use_target_before_drift = true
		return

	var direct_polygon := root.find_child("targetbeforedrift", true, false) as CollisionPolygon2D
	if direct_polygon == null:
		direct_polygon = root.find_child("TargetBeforeDrift", true, false) as CollisionPolygon2D
	if direct_polygon != null:
		target_before_drift_polygon = direct_polygon
		target_before_drift_anchor = direct_polygon
		use_target_before_drift = true
		return

	# Also support Area2D wrapper with collision children.
	var area := root.find_child("targetbeforedrift", true, false) as Area2D
	if area == null:
		area = root.find_child("TargetBeforeDrift", true, false) as Area2D
	if area == null:
		return

	target_before_drift_anchor = area
	for child in area.get_children():
		if child is CollisionShape2D and target_before_drift_shape == null:
			target_before_drift_shape = child as CollisionShape2D
		if child is CollisionPolygon2D and target_before_drift_polygon == null:
			target_before_drift_polygon = child as CollisionPolygon2D

	use_target_before_drift = target_before_drift_shape != null or target_before_drift_polygon != null

func _pick_target_before_drift_point() -> void:
	has_pre_drift_target_point = false
	if not use_target_before_drift:
		return

	if target_before_drift_polygon != null and not target_before_drift_polygon.polygon.is_empty():
		var poly := target_before_drift_polygon.polygon
		var rect := Rect2(poly[0], Vector2.ZERO)
		for p in poly:
			rect = rect.expand(p)

		for i in range(24):
			var candidate_local := Vector2(
				randf_range(rect.position.x, rect.position.x + rect.size.x),
				randf_range(rect.position.y, rect.position.y + rect.size.y)
			)
			if Geometry2D.is_point_in_polygon(candidate_local, poly):
				pre_drift_target_point = target_before_drift_polygon.to_global(candidate_local)
				has_pre_drift_target_point = true
				return

	if target_before_drift_shape != null and target_before_drift_shape.shape != null:
		var local_point := Vector2.ZERO
		if target_before_drift_shape.shape is RectangleShape2D:
			var rect_shape := target_before_drift_shape.shape as RectangleShape2D
			local_point = Vector2(
				randf_range(-rect_shape.size.x * 0.5, rect_shape.size.x * 0.5),
				randf_range(-rect_shape.size.y * 0.5, rect_shape.size.y * 0.5)
			)
		elif target_before_drift_shape.shape is CircleShape2D:
			var circle := target_before_drift_shape.shape as CircleShape2D
			var angle := randf() * TAU
			var r := sqrt(randf()) * circle.radius
			local_point = Vector2(cos(angle), sin(angle)) * r
		elif target_before_drift_shape.shape is CapsuleShape2D:
			var capsule := target_before_drift_shape.shape as CapsuleShape2D
			var half_height := capsule.height * 0.5
			local_point = Vector2(
				randf_range(-capsule.radius, capsule.radius),
				randf_range(-half_height, half_height)
			)

		pre_drift_target_point = target_before_drift_shape.global_transform * local_point
		has_pre_drift_target_point = true
		return

	if target_before_drift_anchor != null:
		pre_drift_target_point = target_before_drift_anchor.global_position
		has_pre_drift_target_point = true

func _is_inside_target_before_drift() -> bool:
	if target_before_drift_polygon != null:
		var local_point := target_before_drift_polygon.to_local(global_position)
		if Geometry2D.is_point_in_polygon(local_point, target_before_drift_polygon.polygon):
			return true

	if target_before_drift_shape == null or target_before_drift_shape.shape == null or _probe_shape == null:
		return false

	var target_xform: Transform2D = target_before_drift_shape.global_transform
	var probe_xform := Transform2D(0.0, global_position)
	return target_before_drift_shape.shape.collide(target_xform, _probe_shape, probe_xform)


func _update_z_from_depth() -> void:
	# depth: 0.0 = dekat (front), 1.0 = jauh (back)
	# Map depth continuously into z-range so NOVA pull also updates layering.
	var mapped_z := lerpf(float(z_front), float(z_far), clampf(depth, 0.0, 1.0))
	z_index = int(round(mapped_z))

func _resolve_trigger_zorder_nodes() -> void:
	var root := get_tree().current_scene
	if root == null:
		return

	trigger_zorder_polygon = null
	trigger_zorder_polygons.clear()

	trigger_zorder_area = root.find_child("triggerzorder", true, false) as Area2D
	if trigger_zorder_area == null:
		trigger_zorder_area = root.find_child("TriggerZOrder", true, false) as Area2D
	if trigger_zorder_area == null:
		return

	for child in trigger_zorder_area.get_children():
		if child is CollisionPolygon2D:
			trigger_zorder_polygons.append(child as CollisionPolygon2D)

	if not trigger_zorder_polygons.is_empty():
		trigger_zorder_polygon = trigger_zorder_polygons[0]

	var detected_background_top := _detect_trigger_background_top_z()
	if detected_background_top > background_top_z:
		background_top_z = detected_background_top

	var detected_front_z := _detect_trigger_front_z()
	if detected_front_z >= 0:
		background_front_z = detected_front_z

func _detect_trigger_background_top_z() -> int:
	if trigger_zorder_area == null:
		return background_top_z

	var background_root := trigger_zorder_area.get_parent()
	if background_root == null:
		return background_top_z

	var max_z := background_top_z
	for child in background_root.get_children():
		if child == trigger_zorder_area:
			continue
		if child is CanvasItem:
			max_z = max(max_z, (child as CanvasItem).z_index)

	return max_z

func _detect_trigger_front_z() -> int:
	if trigger_zorder_area == null:
		return -1

	var background_root := trigger_zorder_area.get_parent()
	if background_root == null:
		return -1

	var front_node := background_root.get_node_or_null("Front") as CanvasItem
	if front_node != null:
		return front_node.z_index

	# Fallback by name search in case Front is nested or named with different case.
	for child in background_root.get_children():
		if child is CanvasItem and String(child.name).to_lower() == "front":
			return (child as CanvasItem).z_index

	return -1

func _is_inside_trigger_zorder() -> bool:
	if trigger_zorder_polygons.is_empty():
		if trigger_zorder_polygon == null:
			return false
		if trigger_zorder_polygon.polygon.is_empty():
			return false

		for probe in _get_trigger_probe_points():
			var local_single := trigger_zorder_polygon.to_local(probe)
			if Geometry2D.is_point_in_polygon(local_single, trigger_zorder_polygon.polygon):
				return true
		return false

	for poly in trigger_zorder_polygons:
		if poly == null or not is_instance_valid(poly):
			continue
		if poly.polygon.is_empty():
			continue

		for probe in _get_trigger_probe_points():
			var local_point := poly.to_local(probe)
			if Geometry2D.is_point_in_polygon(local_point, poly.polygon):
				return true

	return false

func _get_trigger_probe_points() -> Array[Vector2]:
	var points: Array[Vector2] = [global_position]
	if hitbox_area == null:
		return points

	for child in hitbox_area.get_children():
		if not (child is CollisionShape2D):
			continue

		var shape_node := child as CollisionShape2D
		if shape_node.shape == null:
			continue

		var xf := shape_node.global_transform
		points.append(xf.origin)

		if shape_node.shape is RectangleShape2D:
			var rect := shape_node.shape as RectangleShape2D
			var half := rect.size * 0.5
			points.append(xf * Vector2(half.x, 0))
			points.append(xf * Vector2(-half.x, 0))
			points.append(xf * Vector2(0, half.y))
			points.append(xf * Vector2(0, -half.y))
		elif shape_node.shape is CircleShape2D:
			var circle := shape_node.shape as CircleShape2D
			points.append(xf * Vector2(circle.radius, 0))
			points.append(xf * Vector2(-circle.radius, 0))
			points.append(xf * Vector2(0, circle.radius))
			points.append(xf * Vector2(0, -circle.radius))
		elif shape_node.shape is CapsuleShape2D:
			var capsule := shape_node.shape as CapsuleShape2D
			var half_h := capsule.height * 0.5
			points.append(xf * Vector2(0, half_h + capsule.radius))
			points.append(xf * Vector2(0, -(half_h + capsule.radius)))
			points.append(xf * Vector2(capsule.radius, 0))
			points.append(xf * Vector2(-capsule.radius, 0))

	return points

func _apply_trigger_zorder_override() -> void:
	if _is_inside_trigger_zorder():
		has_entered_trigger_zorder = true

	if not has_entered_trigger_zorder:
		var max_pre_trigger_z := background_front_z - 1
		if z_index > max_pre_trigger_z:
			z_index = max_pre_trigger_z
		return

	var min_front_z := background_top_z + 1
	if z_index < min_front_z:
		z_index = min_front_z

func _request_global_scale_z_sync() -> void:
	if _global_scale_z_sync_pending:
		return
	_global_scale_z_sync_pending = true
	call_deferred("_run_global_scale_z_sync")

func _run_global_scale_z_sync() -> void:
	_global_scale_z_sync_pending = false

	var tree := get_tree()
	if tree == null:
		return

	var frame_now: int = Engine.get_process_frames()
	if _global_scale_z_sync_frame == frame_now:
		return
	_global_scale_z_sync_frame = frame_now

	var raw_nodes: Array = tree.get_nodes_in_group("enemy_nodes")
	var pre_trigger_enemies: Array[Node2D] = []
	var trigger_enemies: Array[Node2D] = []

	for node in raw_nodes:
		if node == null or not is_instance_valid(node):
			continue
		if not (node is Node2D):
			continue
		if not node.has_method("_apply_trigger_zorder_override"):
			continue

		var enemy_node := node as Node2D
		var entered_trigger := bool(enemy_node.get("has_entered_trigger_zorder"))
		if entered_trigger:
			trigger_enemies.append(enemy_node)
		else:
			pre_trigger_enemies.append(enemy_node)

	if pre_trigger_enemies.size() > 0:
		_apply_scale_z_band(pre_trigger_enemies, background_front_z - 10, background_front_z - 1)

	if trigger_enemies.size() > 0:
		_apply_scale_z_band(trigger_enemies, background_top_z + 1, background_top_z + 120)

func _apply_scale_z_band(enemies: Array[Node2D], min_z: int, max_z: int) -> void:
	if enemies.is_empty():
		return

	if enemies.size() == 1:
		enemies[0].z_index = clampi(max_z, min_z, max_z)
		return

	enemies.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		var a_scale: float = absf(a.scale.x) + absf(a.scale.y)
		var b_scale: float = absf(b.scale.x) + absf(b.scale.y)
		if is_equal_approx(a_scale, b_scale):
			return a.get_instance_id() < b.get_instance_id()
		return a_scale < b_scale
	)

	var rank_count: int = enemies.size() - 1
	var z_span: int = max_z - min_z
	for i in range(enemies.size()):
		var target_z: int
		if z_span >= rank_count and rank_count > 0:
			target_z = min_z + i
		elif rank_count > 0:
			target_z = int(round(lerpf(float(min_z), float(max_z), float(i) / float(rank_count))))
		else:
			target_z = min_z

		enemies[i].z_index = clampi(target_z, min_z, max_z)

func on_hit(hit_area: Node = null):
	if is_dead:
		return

	apply_damage(1)
		

func apply_damage(amount: int) -> void:
	if is_dead or amount <= 0 or hp <= 0:
		return

	set_state(State.DAMAGED)
	hp -= amount
	_show_health_exclusive()
	_play_health_state_animation()
	_play_health_squeeze_stretch()

	if hp <= 0:
		die()


func instakill(delay: float = 0.0) -> void:
	if is_dead or hp <= 0:
		return

	if delay <= 0.0:
		hp = 0
		_show_health_exclusive()
		_play_health_state_animation()
		die()
		return

	var timer := get_tree().create_timer(delay)
	timer.timeout.connect(func():
		if is_instance_valid(self) and not is_dead and hp > 0:
			hp = 0
			_show_health_exclusive()
			_play_health_state_animation()
			die()
	)


func set_marked(value: bool) -> void:
	marked = value
	if marked:
		mark_time_left = maxf(mark_duration, 0.1)
	else:
		mark_time_left = 0.0


func is_marked() -> bool:
	return marked and mark_time_left > 0.0


func explode_mark(radius: float, damage: int, visited: Array[Node] = []) -> void:
	if not is_marked():
		return
	if damage <= 0:
		return

	# Linked mark hit: when a marked enemy is hit, all other marked enemies also take damage.
	var enemies: Array = get_tree().get_nodes_in_group("enemy_nodes")
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy == self:
			continue
		if enemy.has_method("is_marked") and enemy.is_marked() and enemy.has_method("apply_damage"):
			enemy.apply_damage(damage)


func apply_slow(duration: float, factor: float) -> void:
	slow_timer = max(slow_timer, duration)
	slow_factor = clampf(min(slow_factor, factor), 0.15, 1.0)


func pull_towards(target_pos: Vector2, strength: float = 0.55) -> void:
	global_position = global_position.lerp(target_pos, clampf(strength, 0.0, 1.0))


func apply_nova_pull_effect(target_pos: Vector2, target_depth: float, pull_speed: float, duration: float) -> void:
	if is_dead:
		return

	nova_pull_target_pos = target_pos
	nova_pull_target_depth = clampf(target_depth, 0.0, 1.0)
	nova_pull_speed = maxf(pull_speed, 0.0)
	nova_pull_time_left = maxf(duration, 0.0)
	flap_enabled = true


func _apply_nova_pull(delta: float) -> void:
	
	if nova_pull_time_left > 0.0:
		visual.modulate = Color(0.622, 0.644, 1.0, 1.0) 
	else:
		visual.modulate = original_modulate
		
	if nova_pull_time_left <= 0.0:
		return

	if position.distance_to(nova_pull_target_pos) <= nova_pull_arrive_distance:
		nova_pull_time_left = 0.0
		return

	nova_pull_time_left -= delta
	position = position.move_toward(nova_pull_target_pos, nova_pull_speed * delta)
	depth = move_toward(depth, nova_pull_target_depth, nova_pull_depth_lerp_speed * delta)
	depth = clampf(depth, 0.0, 1.0)
	# Update z-order immediately as depth changes during pull
	_update_z_from_depth()

func play_bluehit_effect() -> float:
	
	if is_dead or hp <= 0:
		return 0.0
	
	hitvis.visible = true
	hitvis.play("hit_blue")
	
	return 0.0
	
func play_redhit_effect() -> float:
	
	if is_dead or hp <= 0:
		return 0.0
	
	hitvis.visible = true
	hitvis.play("hit_red")
	
	return 0.0
	
func _on_hit_visual_animation_finished() -> void:
	hitvis.stop()
	hitvis.visible = false

func play_blue3_effect() -> float:
	if is_dead or hp <= 0:
		return 0.0
		
	if skill_blue3_effect == null:
		return 0.0
		
	skill_blue3_effect.visible = true
	skill_blue3_effect.play("blue3_cast")
	
	return 0.0

func _on_skill_blue_3_effect_animation_finished() -> void:
	skill_blue3_effect.stop()
	skill_blue3_effect.visible = false
	hitvis.visible = false
  
	pass # Replace with function body.
	
func play_red3_effect() -> float:
	if is_dead or hp <= 0:
		return 0.0
		
	if skill_red3_effect == null:
		return 0.0

	skill_red3_effect.visible = true
	skill_red3_effect.frame = 0
	skill_red3_effect.play("red3_cast")

	var frame_count := skill_red3_effect.sprite_frames.get_frame_count("red3_cast")
	var speed := skill_red3_effect.sprite_frames.get_animation_speed("red3_cast")
	if frame_count <= 0 or speed <= 0.0:
		return 0.0

	return frame_count / speed

func _on_skill_red3_effect_finished() -> void:
	skill_red3_effect.stop()
	skill_red3_effect.visible = false
		
		
func die():
	if is_dead:
		return

	is_dead = true
	hp = 0
	marked = false
	is_attacking = false
	_close_explode_triggered = true

	if hitbox_area:
		hitbox_area.monitoring = false
		hitbox_area.monitorable = false
		hitbox_area.collision_layer = 0
		hitbox_area.collision_mask = 0

	if weak_point is Area2D:
		var weak_area := weak_point as Area2D
		weak_area.monitoring = false
		weak_area.monitorable = false
		weak_area.collision_layer = 0
		weak_area.collision_mask = 0

	_show_health_exclusive()
	_play_health_state_animation()

	print("Bakyun!")
	set_state(State.DEATH)

func is_targetable() -> bool:
	return not is_dead and hp > 0

func _hide_health_visual() -> void:
	if health_visual == null:
		return
	health_visual.visible = false
	health_visual.stop()
	health_visual.scale = _health_base_scale

func _show_health_exclusive() -> void:
	if health_visual == null:
		return

	for enemy_node in get_tree().get_nodes_in_group("enemy_nodes"):
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		if enemy_node == self:
			continue
		if enemy_node.has_method("_hide_health_visual"):
			enemy_node.call("_hide_health_visual")

	health_visual.visible = true

func _play_health_state_animation() -> void:
	if health_visual == null or not health_visual.visible:
		return

	if hp <= 0:
		health_visual.play("dead")
		return

	# Prefer exact hp_N animation when available (used by tank enemies like hp_10..hp_1).
	var exact_anim := StringName("hp_%d" % hp)
	if health_visual.sprite_frames != null and health_visual.sprite_frames.has_animation(exact_anim):
		health_visual.play(exact_anim)
		return

	if hp >= 3:
		health_visual.play("hp_3")
	elif hp == 2:
		health_visual.play("hp_2")
	else:
		health_visual.play("hp_1")

func _play_health_squeeze_stretch() -> void:
	if health_visual == null or not health_visual.visible:
		return

	if _health_squash_tween != null and _health_squash_tween.is_valid():
		_health_squash_tween.kill()

	health_visual.scale = _health_base_scale
	_health_squash_tween = create_tween()
	_health_squash_tween.set_trans(Tween.TRANS_BACK)
	_health_squash_tween.set_ease(Tween.EASE_OUT)
	_health_squash_tween.tween_property(health_visual, "scale", Vector2(_health_base_scale.x * 1.18, _health_base_scale.y * 0.84), 0.08)
	_health_squash_tween.tween_property(health_visual, "scale", Vector2(_health_base_scale.x * 0.94, _health_base_scale.y * 1.08), 0.08)
	_health_squash_tween.tween_property(health_visual, "scale", _health_base_scale, 0.10)

func _on_health_visual_animation_finished() -> void:
	if health_visual == null:
		return
	if String(health_visual.animation) != "dead":
		return

	# Hide health UI right after dead animation completes.
	_hide_health_visual()
	
func _on_animated_sprite_2d_animation_finished() -> void:
	if state == State.DAMAGED :
		set_state(State.MOVING)
	elif state == State.ATTACK :
		is_attacking = false
		set_state(State.MOVING)
	elif state == State.DEATH :
		remove_from_group("enemy_nodes")
		queue_free()
	pass # Replace with function body.


func _on_animated_sprite_2d_frame_changed() -> void:
	if state == State.ATTACK and visual.frame == 1:
		if not can_attack:
			return
		if player_node == null or not is_instance_valid(player_node):
			return
		print("aww!")
		player_node.take_damage(attack_damage)
	pass # Replace with function body.
