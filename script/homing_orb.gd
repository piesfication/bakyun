extends Node2D

@export var contact_damage: int = 1
@export var approach_speed: float = 0.18
@export var min_scale: float = 0.05
@export var max_scale: float = 0.8
@export var drift_speed: float = 2.6
@export var drift_move_speed: float = 320.0
@export var leader_wave_amplitude: float = 44.0
@export var leader_wave_frequency: float = 2.4
@export var leader_turn_speed: float = 1.5
@export var max_turn_rate_radians: float = 3.2
@export var leader_wander_strength: float = 0.75
@export var boundary_turn_influence: float = 0.85
@export var boundary_steer_decay: float = 5.5
@export var boundary_soft_zone: float = 180.0
@export var boundary_avoid_influence: float = 1.6
@export var boundary_vertical_avoid_scale: float = 0.55
@export var boundary_correction_speed: float = 420.0
@export var boundary_edge_epsilon: float = 10.0
@export var boundary_inward_bias: float = 0.32
@export var predictive_lookahead_time: float = 0.7
@export var predictive_margin: float = 26.0
@export var predictive_turn_influence: float = 0.92
@export var vertical_motion_scale: float = 0.62
@export var downward_motion_scale: float = 1.0
@export var max_vertical_slope: float = 0.42
@export var safe_margin_x: float = 180.0
@export var safe_margin_y: float = 120.0
@export var safe_margin_ratio: float = 0.12
@export var roam_retarget_min: float = 1.5
@export var roam_retarget_max: float = 2.8
@export var roam_target_reach: float = 40.0
@export var roam_wander_strength: float = 0.22
@export var roam_center_pull: float = 0.22
@export var slither_frequency: float = 4.8
@export var slither_strength: float = 0.20
@export var edge_wave_damping: float = 0.85
@export var corner_escape_influence: float = 0.85
@export var boundary_retarget_cooldown: float = 0.28
@export var boundary_guard_padding: float = 14.0
@export var follow_distance: float = 42.0
@export var neutral_anchor_lifetime: float = 9.0

@onready var visual: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Area2D

enum OrbColor {
	RED,
	BLUE
}

@export var randomize_color_on_spawn: bool = true
@export var fixed_orb_color: OrbColor = OrbColor.RED

var hp: int = 1
var is_dead: bool = false
var marked: bool = false
var player_node: Node2D
var neutralized: bool = false
var orb_color: OrbColor = OrbColor.RED
var spawn_anim_done: bool = false
var exploding: bool = false

var depth: float = 1.0
var drift_origin: Vector2 = Vector2.ZERO
var drift_time: float = 0.0
var initialized: bool = false
var leader_direction: Vector2 = Vector2.ZERO
var boundary_steer: Vector2 = Vector2.ZERO
var lifetime: float = 0.0
var roam_target: Vector2 = Vector2.ZERO
var roam_retarget_timer: float = 0.0
var boundary_retarget_timer: float = 0.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var batch_seed: int = 0
var time_offset: float = 0.0
var follow_target: Node2D

func _ready() -> void:
	add_to_group("enemy_nodes")
	add_to_group("orb_nodes")
	hp = 1
	scale = Vector2.ONE * min_scale
	if batch_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = batch_seed
	orb_color = _pick_orb_color()
	drift_time = _rng.randf() * TAU
	leader_direction = _make_initial_leader_direction()
	_pick_new_roam_target(true)
	initialized = true

	if player_node == null:
		player_node = _find_player()

	if visual:
		if not visual.animation_finished.is_connected(_on_visual_animation_finished):
			visual.animation_finished.connect(_on_visual_animation_finished)
		_play_spawn_animation()

func setup(target_player: Node2D, target_follow: Node2D = null) -> void:
	player_node = target_player
	follow_target = target_follow

func _process(delta: float) -> void:
	if not initialized or is_dead:
		return
	if exploding:
		return
	if not spawn_anim_done:
		return

	lifetime += delta
	if boundary_retarget_timer > 0.0:
		boundary_retarget_timer -= delta
	if neutralized and lifetime >= neutral_anchor_lifetime and not _has_followers():
		queue_free()
		return

	# Approach ke kamera: scale membesar saat depth menurun.
	depth -= approach_speed * delta
	depth = clamp(depth, 0.0, 1.0)

	var t := smoothstep(0.0, 1.0, 1.0 - depth)
	scale = Vector2.ONE * lerpf(min_scale, max_scale, t)

	if follow_target != null and is_instance_valid(follow_target):
		var to_leader := follow_target.global_position - global_position
		var dist := to_leader.length()
		if dist > 0.001:
			var desired_pos := follow_target.global_position - to_leader.normalized() * follow_distance
			var to_slot := desired_pos - global_position
			var slot_dist := to_slot.length()
			if slot_dist > 0.001:
				var step := minf(slot_dist, drift_move_speed * delta)
				global_position += to_slot.normalized() * step
		else:
			# Overlap persis di spawn: nudge acak kecil agar tidak bias ke satu arah.
			global_position += Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.5, 0.5)).normalized() * 0.01
	else:
		_update_leader_direction(delta)
		drift_time += delta * leader_wave_frequency
		var bounds := _get_inner_safe_bounds()
		var edge_factor := _edge_proximity(bounds)
		var perp := Vector2(-leader_direction.y, leader_direction.x)
		var wave_move := perp * (sin(drift_time) * leader_wave_amplitude * delta)
		wave_move.y *= vertical_motion_scale
		if wave_move.y > 0.0:
			wave_move.y *= downward_motion_scale
		wave_move *= (1.0 - edge_factor * edge_wave_damping)

		var move_vec := (leader_direction * drift_move_speed * delta) + wave_move
		var candidate := global_position + move_vec
		# Saat keluar batas, hilangkan wave agar steering boundary dari _update_leader_direction bekerja murni.
		if not _is_inside_bounds(candidate, bounds):
			move_vec = leader_direction * drift_move_speed * delta
			candidate = global_position + move_vec

		global_position = _clamp_to_bounds(candidate, bounds)

	if depth <= 0.0 and not neutralized:
		_explode()

func on_hit(_area: Node = null) -> void:
	apply_damage(1)

func apply_damage(amount: int) -> void:
	if is_dead or neutralized or amount <= 0:
		return
	if not _can_take_damage_from_current_character():
		return
	hp -= amount
	if hp <= 0:
		_neutralize_anchor()

func instakill(delay: float = 0.0) -> void:
	if is_dead or neutralized:
		return
	if delay <= 0.0:
		hp = 0
		_neutralize_anchor()
		return

	var timer := get_tree().create_timer(delay)
	timer.timeout.connect(func():
		if is_instance_valid(self) and not is_dead and not neutralized:
			hp = 0
			_neutralize_anchor()
	)

func set_marked(value: bool) -> void:
	marked = value

func is_marked() -> bool:
	return marked

func explode_mark(radius: float, damage: int) -> void:
	if not marked:
		return
	marked = false
	for enemy in get_tree().get_nodes_in_group("enemy_nodes"):
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(global_position) <= radius:
			enemy.apply_damage(damage)

func apply_slow(_duration: float, _factor: float) -> void:
	pass

func pull_towards(target_pos: Vector2, strength: float = 0.55) -> void:
	global_position = global_position.lerp(target_pos, clampf(strength, 0.0, 1.0))

func _explode() -> void:
	if neutralized:
		return
	if is_instance_valid(player_node) and player_node.has_method("take_damage"):
		player_node.take_damage(contact_damage)
	_neutralize_anchor()

func _neutralize_anchor() -> void:
	if is_dead or neutralized or exploding:
		return

	neutralized = true
	exploding = true
	lifetime = 0.0
	hp = 0
	marked = false

	if hitbox:
		hitbox.monitoring = false
		hitbox.monitorable = false
		hitbox.collision_layer = 0
		hitbox.collision_mask = 0

	if is_in_group("enemy_nodes"):
		remove_from_group("enemy_nodes")

	_play_explode_animation()

func die() -> void:
	if is_dead or exploding:
		return
	is_dead = true
	if hitbox:
		hitbox.monitoring = false
		hitbox.monitorable = false
	queue_free()

func _pick_orb_color() -> OrbColor:
	if not randomize_color_on_spawn:
		return fixed_orb_color
	# Mix beberapa sumber agar varian warna tetap acak antarsummon.
	var roll := int(get_instance_id()) + int(time_offset * 1000.0) + batch_seed + int(Time.get_ticks_usec() & 1023)
	return OrbColor.RED if (roll & 1) == 0 else OrbColor.BLUE

func _moving_anim_name() -> StringName:
	return &"moving_red" if orb_color == OrbColor.RED else &"moving_blue"

func _enlarge_anim_name() -> StringName:
	return &"enlarge_red" if orb_color == OrbColor.RED else &"enlarge_blue"

func _explode_anim_name() -> StringName:
	return &"explode_red" if orb_color == OrbColor.RED else &"explode_blue"

func _play_spawn_animation() -> void:
	spawn_anim_done = false
	if visual == null or visual.sprite_frames == null:
		spawn_anim_done = true
		return

	var enlarge := _enlarge_anim_name()
	if visual.sprite_frames.has_animation(enlarge):
		visual.play(enlarge)
		return

	# Fallback untuk asset lama.
	spawn_anim_done = true
	var moving := _moving_anim_name()
	if visual.sprite_frames.has_animation(moving):
		visual.play(moving)
	elif visual.sprite_frames.has_animation(&"moving"):
		visual.play(&"moving")

func _play_explode_animation() -> void:
	if visual == null or visual.sprite_frames == null:
		queue_free()
		return

	var explode_anim := _explode_anim_name()
	if visual.sprite_frames.has_animation(explode_anim):
		visual.play(explode_anim)
		return

	queue_free()

func _on_visual_animation_finished() -> void:
	if visual == null:
		return

	if visual.animation == _enlarge_anim_name():
		spawn_anim_done = true
		var moving := _moving_anim_name()
		if visual.sprite_frames and visual.sprite_frames.has_animation(moving):
			visual.play(moving)
		elif visual.sprite_frames and visual.sprite_frames.has_animation(&"moving"):
			visual.play(&"moving")
		return

	if visual.animation == _explode_anim_name():
		queue_free()

func _can_take_damage_from_current_character() -> bool:
	if player_node == null or not is_instance_valid(player_node):
		player_node = _find_player()
	if player_node == null or not player_node.has_method("get_current_character_name"):
		return true

	var shooter_char := String(player_node.get_current_character_name())
	if orb_color == OrbColor.RED:
		return shooter_char == "baku"
	return shooter_char == "yuna"

func can_be_hit_by_character(character_name: String) -> bool:
	if character_name == "":
		return true
	if orb_color == OrbColor.RED:
		return character_name == "baku"
	return character_name == "yuna"

func _find_player() -> Node2D:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.find_child("Player", true, false) as Node2D

func _make_initial_leader_direction() -> Vector2:
	var dir := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.8, 0.8)).normalized()
	dir.y = clampf(dir.y * vertical_motion_scale, -max_vertical_slope, max_vertical_slope)
	if dir.y > 0.0:
		dir.y = minf(dir.y, max_vertical_slope * downward_motion_scale)
	dir = dir.normalized()
	if dir.length() <= 0.001:
		dir = Vector2.RIGHT
	return dir

func _update_leader_direction(delta: float) -> void:
	if leader_direction.length() <= 0.001:
		leader_direction = Vector2.RIGHT

	roam_retarget_timer -= delta
	if roam_retarget_timer <= 0.0 or global_position.distance_to(roam_target) <= roam_target_reach:
		_pick_new_roam_target()

	# Target direction.
	var to_target := roam_target - global_position
	var desired := to_target.normalized() if to_target.length() > 0.001 else leader_direction

	# Gentle long-period wander — frekuensi sangat rendah agar tidak osilasi cepat.
	var wander_phase := lifetime * 0.38 + float(batch_seed % 23) * 0.27 + time_offset
	var wander := Vector2(cos(wander_phase), sin(wander_phase * 1.17)).normalized()
	desired = (desired + wander * roam_wander_strength).normalized()

	# Boundary repulsion: blend desired ke arah menjauhi tepi secara proporsional.
	var edge_avoid := _compute_boundary_avoidance()
	if edge_avoid.length() > 0.001:
		var blend := clampf(edge_avoid.length() * boundary_avoid_influence * 0.6, 0.0, 1.0)
		desired = desired.lerp(edge_avoid.normalized(), blend)
		if desired.length() > 0.001:
			desired = desired.normalized()

	if desired.length() <= 0.001:
		desired = leader_direction

	# Turn rate konstan — tidak ada multiplier urgency agar belokan halus dan konsisten.
	leader_direction = _rotate_toward_dir(leader_direction, desired, max_turn_rate_radians * leader_turn_speed * delta)
	leader_direction = leader_direction.normalized()

func _apply_screen_bounds_bounce(delta: float) -> void:
	var bounds := _get_inner_safe_bounds()
	var min_x := bounds.position.x
	var max_x := bounds.end.x
	var min_y := bounds.position.y
	var max_y := bounds.end.y

	var clamped := Vector2(
		clampf(global_position.x, min_x, max_x),
		clampf(global_position.y, min_y, max_y)
	)
	var correction := clamped - global_position
	if correction.length() <= 0.001:
		return

	global_position += correction.limit_length(boundary_correction_speed * delta)
	if boundary_retarget_timer <= 0.0:
		var to_center := (bounds.get_center() - global_position).normalized()
		if to_center.length() > 0.001:
			leader_direction = leader_direction.lerp(to_center, corner_escape_influence).normalized()
			boundary_steer = to_center
		roam_retarget_timer = 0.0
		boundary_retarget_timer = boundary_retarget_cooldown
		_pick_new_roam_target(true, true)

func _edge_proximity(bounds: Rect2) -> float:
	var dist_left := absf(global_position.x - bounds.position.x)
	var dist_right := absf(bounds.end.x - global_position.x)
	var dist_top := absf(global_position.y - bounds.position.y)
	var dist_bottom := absf(bounds.end.y - global_position.y)
	var nearest := minf(minf(dist_left, dist_right), minf(dist_top, dist_bottom))
	return clampf(1.0 - (nearest / maxf(boundary_soft_zone, 0.001)), 0.0, 1.0)

# Mengembalikan urgency quadratic (0 = aman, 1 = dekat sekali tepi).
func _compute_edge_urgency(bounds: Rect2) -> float:
	var dist_left := global_position.x - bounds.position.x
	var dist_right := bounds.end.x - global_position.x
	var dist_top := global_position.y - bounds.position.y
	var dist_bottom := bounds.end.y - global_position.y
	var nearest := minf(minf(dist_left, dist_right), minf(dist_top, dist_bottom))
	var t := clampf(1.0 - (nearest / maxf(boundary_soft_zone, 0.001)), 0.0, 1.0)
	return t * t

func _is_inside_bounds(pos: Vector2, bounds: Rect2) -> bool:
	return pos.x >= bounds.position.x and pos.x <= bounds.end.x and pos.y >= bounds.position.y and pos.y <= bounds.end.y

func _clamp_to_bounds(pos: Vector2, bounds: Rect2) -> Vector2:
	return Vector2(
		clampf(pos.x, bounds.position.x, bounds.end.x),
		clampf(pos.y, bounds.position.y, bounds.end.y)
	)

func _compute_predictive_boundary_avoidance() -> Vector2:
	var bounds := _get_inner_safe_bounds()
	var projected := global_position + leader_direction * drift_move_speed * predictive_lookahead_time
	var steer := Vector2.ZERO

	var min_x := bounds.position.x + predictive_margin
	var max_x := bounds.end.x - predictive_margin
	var min_y := bounds.position.y + predictive_margin
	var max_y := bounds.end.y - predictive_margin

	if projected.x < min_x:
		steer.x += 1.0 - clampf((projected.x - bounds.position.x) / maxf((min_x - bounds.position.x), 0.001), 0.0, 1.0)
	elif projected.x > max_x:
		steer.x -= 1.0 - clampf((bounds.end.x - projected.x) / maxf((bounds.end.x - max_x), 0.001), 0.0, 1.0)

	if projected.y < min_y:
		steer.y += (1.0 - clampf((projected.y - bounds.position.y) / maxf((min_y - bounds.position.y), 0.001), 0.0, 1.0)) * boundary_vertical_avoid_scale
	elif projected.y > max_y:
		steer.y -= (1.0 - clampf((bounds.end.y - projected.y) / maxf((bounds.end.y - max_y), 0.001), 0.0, 1.0)) * boundary_vertical_avoid_scale

	return steer

func _rotate_toward_dir(current: Vector2, target: Vector2, max_step: float) -> Vector2:
	if current.length() <= 0.001:
		return target.normalized()
	if target.length() <= 0.001:
		return current.normalized()

	var current_angle := current.angle()
	var target_angle := target.angle()
	var diff := wrapf(target_angle - current_angle, -PI, PI)
	var step := clampf(diff, -max_step, max_step)
	return Vector2.RIGHT.rotated(current_angle + step).normalized()

func _pick_new_roam_target(_force_random: bool = false, _prefer_center: bool = false) -> void:
	var bounds := _get_safe_bounds()
	roam_retarget_timer = _rng.randf_range(roam_retarget_min, roam_retarget_max)

	# Selalu pilih dari inner 60% safe zone agar orb tidak pernah mengincar pojok/tepi.
	var pad_x := bounds.size.x * 0.20
	var pad_y := bounds.size.y * 0.20
	roam_target = Vector2(
		_rng.randf_range(bounds.position.x + pad_x, bounds.end.x - pad_x),
		_rng.randf_range(bounds.position.y + pad_y, bounds.end.y - pad_y)
	)

func _compute_boundary_avoidance() -> Vector2:
	var bounds := _get_safe_bounds()
	var steer := Vector2.ZERO

	# Quadratic falloff: gaya kecil saat mulai masuk soft zone, semakin kuat saat mepet tepi.
	var left_dist := global_position.x - bounds.position.x
	if left_dist < boundary_soft_zone:
		var t := 1.0 - clampf(left_dist / maxf(boundary_soft_zone, 0.001), 0.0, 1.0)
		steer.x += t * t

	var right_dist := bounds.end.x - global_position.x
	if right_dist < boundary_soft_zone:
		var t := 1.0 - clampf(right_dist / maxf(boundary_soft_zone, 0.001), 0.0, 1.0)
		steer.x -= t * t

	var top_dist := global_position.y - bounds.position.y
	if top_dist < boundary_soft_zone:
		var t := 1.0 - clampf(top_dist / maxf(boundary_soft_zone, 0.001), 0.0, 1.0)
		steer.y += (t * t) * boundary_vertical_avoid_scale

	var bottom_dist := bounds.end.y - global_position.y
	if bottom_dist < boundary_soft_zone:
		var t := 1.0 - clampf(bottom_dist / maxf(boundary_soft_zone, 0.001), 0.0, 1.0)
		steer.y -= (t * t) * boundary_vertical_avoid_scale

	return steer

func _get_safe_bounds() -> Rect2:
	var viewport_rect := get_viewport_rect()
	var dynamic_margin_x := maxf(safe_margin_x, viewport_rect.size.x * safe_margin_ratio)
	var dynamic_margin_y := maxf(safe_margin_y, viewport_rect.size.y * safe_margin_ratio)
	var min_x := dynamic_margin_x
	var max_x := viewport_rect.size.x - dynamic_margin_x
	var min_y := dynamic_margin_y
	var max_y := viewport_rect.size.y - dynamic_margin_y

	if max_x <= min_x:
		min_x = viewport_rect.size.x * 0.2
		max_x = viewport_rect.size.x * 0.8
	if max_y <= min_y:
		min_y = viewport_rect.size.y * 0.2
		max_y = viewport_rect.size.y * 0.8

	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func _get_inner_safe_bounds() -> Rect2:
	var b := _get_safe_bounds()
	var min_x := b.position.x + boundary_guard_padding
	var min_y := b.position.y + boundary_guard_padding
	var max_x := b.end.x - boundary_guard_padding
	var max_y := b.end.y - boundary_guard_padding
	if max_x <= min_x:
		min_x = b.position.x
		max_x = b.end.x
	if max_y <= min_y:
		min_y = b.position.y
		max_y = b.end.y
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func _has_followers() -> bool:
	for orb in get_tree().get_nodes_in_group("orb_nodes"):
		if orb == null or not is_instance_valid(orb):
			continue
		if orb == self:
			continue
		if orb.get("follow_target") == self:
			return true
	return false
