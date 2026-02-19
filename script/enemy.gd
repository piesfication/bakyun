extends Node2D

# ==================================================
# VISUAL
# ==================================================
@onready var visual: AnimatedSprite2D = $Visual/AnimatedSprite2D
var original_modulate: Color
# State

enum State {
	MOVING,
	DAMAGED,
	ATTACK
}

var state := State.MOVING

func set_state(new_state: State):
	if state == new_state:
		return
	state = new_state

	match state:
		State.MOVING:
			visual.modulate = original_modulate
			visual.play("moving")
		State.DAMAGED:
			visual.modulate = Color(1.0, 0.804, 0.815, 1.0)
			visual.play("damaged")
		State.ATTACK:
			print("attack!")
			pass


# Logic weak point

@export var max_hp := 3
var hp := max_hp

@export var weak_point: Node2D   # node anak di enemy yang menandai titik lemah

# Logic nyerang player

@export var min_attack_cd := 1.2
@export var max_attack_cd := 2.8

@export var attack_damage: int = 1
@export var attack_cooldown: float = 2  # tiap 1,5 detik bisa menyerang lagi

var player_node: Node2D
var attack_timer: float = 0.0
var is_attacking: bool = false

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

# ==================================================
# APPROACH (CURVED KIRI-ATAS)
# ==================================================
@export var approach_move_speed: float = 350.0
@export var curve_amplitude: float = 40.0
@export var curve_frequency: float = 2.0

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
	#attack_timer = randf_range(0.0, attack_cooldown)
	original_modulate = self.modulate 
	set_state(State.MOVING)
	
	player_node = get_tree().get_root().get_node("Main/Player")
	
	base_y = visual.position.y

	visual.play("moving")
	z_index = z_far
	
	scale = Vector2.ONE * 0.15
	
	var left_bias: float = randf_range(0.8, 1.0)
	var up_bias: float = randf_range(0.1, 0.1)
	
	approach_direction = Vector2(-left_bias, -up_bias).normalized()
	
	curve_time = randf() * TAU
	drift_origin = position
	
	# Randomize drift pattern awal
	randomize_drift_pattern()
	
	# Initialize flap time dengan random offset agar tidak semua enemy sync
	flap_time = randf() * TAU
	
	
func _process(delta):
	idle_move(delta)
	update_depth(delta)
	update_scale()

	update_drift_blend(delta)
	update_movement(delta)
	
	# Apply bird flapping animation AFTER movement
	if flap_enabled:
		apply_bird_flapping(delta)
	
	update_phase_and_z()
	
	update_flip()
	
	if player_node:
		attack_timer -= delta
		
		if depth == 0 and attack_timer <= 0 and not is_attacking:
			start_attack()
	
func start_attack():
	is_attacking = true
	attack_timer = randf_range(min_attack_cd, max_attack_cd)
	set_state(State.ATTACK)
	visual.play("attack")

@export var idle_amplitude := 8.0  # Dikurangi karena flapping sudah handle naik turun
@export var idle_speed := 2.5
var idle_time := 0.0

func idle_move(delta):
	idle_time += delta * idle_speed
	
	# Idle move lebih subtle karena flapping sudah ada
	visual.position.y = base_y + sin(idle_time) * idle_amplitude


func apply_bird_flapping(delta):
	"""Animasi naik turun seperti burung mengepakkan sayap"""
	flap_time += delta * flap_speed
	
	# Menggunakan sin wave untuk gerakan naik turun yang smooth
	var flap_offset = sin(flap_time) * flap_amplitude
	
	# Apply offset ke posisi Y
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
	"""Randomize frekuensi dan fase untuk pattern drift yang lebih variatif"""
	drift_freq_x = randf_range(0.3, 0.8)
	drift_freq_y = randf_range(0.25, 0.7)
	drift_phase_x = randf() * TAU
	drift_phase_y = randf() * TAU


func update_movement(delta):
	# ---------- APPROACH ----------
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

	if not drifting and current_scale >= drift_start_scale:
		#modulate = Color8(0, 0, 128)
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

#=================== HITBOX

func on_hit(hit_area: Node = null):
	if hit_area == weak_point:
		hp = 0  # langsung mati
		print("Critical Hit!")
	else:
		set_state(State.DAMAGED)
		hp -= 1
		
	
	if hp <= 0:
		die()
		
		
func die():
	print("Bakyun!")
	queue_free()

func _on_animated_sprite_2d_animation_finished() -> void:
	if state == State.DAMAGED :
		set_state(State.MOVING)
	elif state == State.ATTACK :
		is_attacking = false
		set_state(State.MOVING)	
	pass # Replace with function body.


func _on_animated_sprite_2d_frame_changed() -> void:
	if state == State.ATTACK and visual.frame == 1:
		print("aww!")
		player_node.take_damage(0)
	pass # Replace with function body.
