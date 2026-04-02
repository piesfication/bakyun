extends Node2D

@onready var indicator = $"../UIMahouMeter"
@onready var indicator_mahou = $"../UIKoisuruMeter/KoisuruMeter"

const PIERCE_PROJECTILE_SCENE = preload("res://scenes/pierce_projectile.tscn")
const CHAIN_PROJECTILE_SCENE = preload("res://scenes/chain_projectile.tscn")

enum SkillShot {
	NONE,
	OVERDRIVE,
	PIERCE,
	CHAIN,
	NOVA
}

var queued_skill: SkillShot = SkillShot.NONE

const SKILL_DELAY_OVERDRIVE := 0.28
const SKILL_PIERCE_SPLIT_RANGE := 1500.0
const SKILL_PIERCE_PROJECTILE_SPEED := 750.0
const SKILL_PIERCE_PROJECTILE_RADIUS := 62.0
const SKILL_CHAIN_MARK_RADIUS := 240.0
const SKILL_CHAIN_EXPLOSION_RADIUS := 220.0
const SKILL_CHAIN_PROJECTILE_SPEED := 900.0
const SKILL_CHAIN_PROJECTILE_SCALE := Vector2(1, 1) * 0.1
const SKILL_CHAIN_TARGET_SEARCH_RADIUS := 760.0
const SKILL_CHAIN_MAX_DEPTH_DIFFERENCE := 0.35
const SKILL_NOVA_PULL_RADIUS := 430.0
const SKILL_NOVA_PULL_SPEED := 760.0
const SKILL_NOVA_PULL_DURATION := 0.9
const SKILL_NOVA_SLOW_DURATION := 1.8
const SKILL_NOVA_SLOW_FACTOR := 0.35
const SKILL_AUTO_TARGET_RADIUS := 260.0

enum CharacterMode {
	CHAR_BAKU,
	CHAR_YUNA
}

var current_mode := CharacterMode.CHAR_BAKU

enum State {
	IDLE,
	SHOOT
}

enum AimState {
	NONE,
	ENEMY,
	WEAKNESS
}

enum AimLock {
	NONE,
	ENEMY,
	WEAKNESS
}

var locked_aim := AimLock.NONE
var shoot_enabled: bool = true
@export_range(0.02, 0.3, 0.01, "suffix:s") var shoot_lock_flicker_interval: float = 0.08
var force_hidden: bool = false

var _shoot_lock_flicker_timer: float = 0.0
var _shoot_lock_flicker_visible: bool = true

var aim_state := AimState.NONE

var state := State.IDLE
@onready var sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	current_mode = CharacterMode.CHAR_BAKU
	state = State.IDLE
	if indicator.has_signal("skill_casted"):
		indicator.connect("skill_casted", Callable(self, "_on_skill_casted"))
	update_crosshair_visual()
	#current_mode = CharacterMode.CHAR_BAKU

func set_state(new_state: State):
	if state == new_state:
		return
	state = new_state

	match state:
		State.IDLE:
			#if current_mode == CharacterMode.CHAR_BAKU:
				#sprite.play("default_baku")
			#if current_mode == CharacterMode.CHAR_YUNA:
				#sprite.play("default_yuna")
			pass
		State.SHOOT:
			#if current_mode == CharacterMode.CHAR_BAKU:
				#sprite.play("shooting_baku")
			#if current_mode == CharacterMode.CHAR_YUNA:
				#sprite.play("shooting_yuna")
			pass

func _input(event):
	
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SHIFT:
			switch_character()
			
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not shoot_enabled:
			return
		set_state(State.SHOOT)
		shoot()

func set_shoot_enabled(enabled: bool) -> void:
	shoot_enabled = enabled
	_shoot_lock_flicker_timer = 0.0
	_shoot_lock_flicker_visible = true
	if not force_hidden:
		visible = true

func set_force_hidden(hidden_state: bool) -> void:
	force_hidden = hidden_state
	if force_hidden:
		visible = false
		return

	if shoot_enabled:
		visible = true
	else:
		visible = _shoot_lock_flicker_visible
		
func switch_character():
	if current_mode == CharacterMode.CHAR_BAKU:
		current_mode = CharacterMode.CHAR_YUNA
	else:
		current_mode = CharacterMode.CHAR_BAKU

	update_crosshair_visual()
	
func update_crosshair_visual():
	if state != State.IDLE:
		return
	update_aim_from_lock()

func _on_animated_sprite_2d_animation_finished():
	if state == State.SHOOT:
		set_state(State.IDLE)
		update_crosshair_visual()
		

func _process(delta):
	global_position = get_global_mouse_position()
	if force_hidden:
		if visible:
			visible = false
		return
	_update_shoot_lock_flicker(delta)
	
	# Only check aim target when level is actively running to prevent spurious aim changes during intro/spawn
	var is_level_running := true
	var level_controller = get_tree().current_scene
	if level_controller != null and is_instance_valid(level_controller):
		# Check if level_running property exists
		for prop in level_controller.get_property_list():
			if String(prop.get("name", "")) == "level_running":
				is_level_running = bool(level_controller.get("level_running"))
				break
	
	if is_level_running:
		check_aim_target()

func _update_shoot_lock_flicker(delta: float) -> void:
	if shoot_enabled:
		if not visible:
			visible = true
		return

	_shoot_lock_flicker_timer += delta
	if _shoot_lock_flicker_timer >= shoot_lock_flicker_interval:
		_shoot_lock_flicker_timer = 0.0
		_shoot_lock_flicker_visible = not _shoot_lock_flicker_visible
		visible = _shoot_lock_flicker_visible


@onready var hand_baku := $"../Player/BakuMahou/AnimatedSprite2D2"
@onready var hand_yuna := $"../Player/YunaMahou/AnimatedSprite2D"

func shoot():
	if not shoot_enabled:
		return
	set_state(State.SHOOT)
	match current_mode:
		CharacterMode.CHAR_BAKU:
			shoot_baku()
			
		CharacterMode.CHAR_YUNA:
			shoot_yuna()
			

func shoot_baku():
	sprite.play("shooting_baku")
	hand_baku.play("shooting")
	
	var hitbox = get_enemy_under_cursor()
	if hitbox:
		var enemy = hitbox.get_parent()
		if queued_skill == SkillShot.NONE:
			# Check if this is a weakness point
			if hitbox.is_in_group("weak_point"):
				# For weakness points, go up the hierarchy: Area2D -> WeaknessPoint -> SetOfWeakness -> EnemyBoss
				var weak_parent = enemy.get_parent()  # SetOfWeakness
				var boss = weak_parent.get_parent() if weak_parent else null  # EnemyBoss
				if boss and is_instance_valid(boss) and boss.has_method("on_hit"):
					boss.on_hit(hitbox)
			else:
				# For regular enemies
				if enemy.has_method("is_marked") and enemy.is_marked():
					enemy.explode_mark(SKILL_CHAIN_EXPLOSION_RADIUS, 1)
				if enemy.has_method("on_hit"):
					enemy.on_hit(hitbox)
		else:
			apply_skill_shot(enemy, hitbox, get_global_mouse_position())
		
		if not _is_boss_enemy(enemy, hitbox):
			indicator.add_slot("baku")
			indicator_mahou.add_baku()

func shoot_yuna():
	sprite.play("shooting_yuna")
	hand_yuna.play("shooting")

	var hitbox = get_enemy_under_cursor()
	if hitbox:
		var enemy = hitbox.get_parent()
		if queued_skill == SkillShot.NONE:
			# Check if this is a weakness point
			if hitbox.is_in_group("weak_point"):
				# For weakness points, go up the hierarchy: Area2D -> WeaknessPoint -> SetOfWeakness -> EnemyBoss
				var weak_parent = enemy.get_parent()  # SetOfWeakness
				var boss = weak_parent.get_parent() if weak_parent else null  # EnemyBoss
				if boss and is_instance_valid(boss) and boss.has_method("on_hit"):
					boss.on_hit(hitbox)
			else:
				# For regular enemies
				if enemy.has_method("is_marked") and enemy.is_marked():
					enemy.explode_mark(SKILL_CHAIN_EXPLOSION_RADIUS, 1)
				if enemy.has_method("on_hit"):
					enemy.on_hit(hitbox)
		else:
			apply_skill_shot(enemy, hitbox, get_global_mouse_position())
			
		if not _is_boss_enemy(enemy, hitbox):
			indicator.add_slot("yuna")
			indicator_mahou.add_yuna()

func _is_boss_enemy(enemy: Node, hitbox: Node = null) -> bool:
	# cek dari weak_point naik ke boss
	if hitbox != null and hitbox.is_in_group("weak_point"):
		return true
	# cek langsung dari enemy
	if enemy != null and enemy.is_in_group("boss"):
		return true
	# cek via method khas boss
	if enemy != null and enemy.has_method("force_weakened_state"):
		return true
	return false
	
func get_enemy_under_cursor():
	var space = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = get_global_mouse_position()
	query.collide_with_areas = true
	query.collision_mask = 1 << 1

	var result = space.intersect_point(query, 16)
	if result.is_empty():
		return null

	var best_any: Area2D = null
	var best_any_z := -INF
	var best_any_order := -INF

	for r in result:
		var collider: Variant = r.get("collider")
		if not (collider is Area2D):
			continue

		var hit_area := collider as Area2D
		var enemy := hit_area.get_parent()
		if enemy == null:
			continue
		if not _is_enemy_targetable(enemy):
			continue

		var z := _get_effective_z_index(enemy)
		var order := float(enemy.get_index())

		if z > best_any_z or (z == best_any_z and order > best_any_order):
			best_any_z = z
			best_any_order = order
			best_any = hit_area
	if best_any != null:
		return best_any
	
	return null

func _is_enemy_targetable(enemy: Node) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false

	if enemy.has_method("is_targetable"):
		return bool(enemy.call("is_targetable"))

	if enemy.has_method("is_dead"):
		if bool(enemy.call("is_dead")):
			return false

	for prop in enemy.get_property_list():
		var prop_name := String(prop.get("name", ""))
		if prop_name == "is_dead" and bool(enemy.get("is_dead")):
			return false
		if prop_name == "hp" and int(enemy.get("hp")) <= 0:
			return false

	if _is_enemy_behind_background(enemy):
		return false

	return true

func _is_enemy_behind_background(enemy: Node) -> bool:
	# Only apply this rule to actual enemy nodes, not arbitrary helper nodes.
	var has_background_top_prop := false
	for prop in enemy.get_property_list():
		if String(prop.get("name", "")) == "background_top_z":
			has_background_top_prop = true
			break

	if not enemy.is_in_group("enemy_nodes") and not has_background_top_prop:
		return false

	if not (enemy is CanvasItem):
		return false

	var background_top_z := 30.0
	if has_background_top_prop:
		background_top_z = float(enemy.get("background_top_z"))

	return _get_effective_z_index(enemy) <= background_top_z

func _get_effective_z_index(node: Node) -> float:
	if not (node is CanvasItem):
		return 0.0

	var effective_z := 0.0
	var current: Node = node
	while current != null and current is CanvasItem:
		var item := current as CanvasItem
		effective_z += float(item.z_index)
		if not item.z_as_relative:
			break
		current = item.get_parent()

	return effective_z
	
# =========== Logic aim dan weakness

var aim_timer := 0.0
var pending_aim_state := AimState.NONE
const AIM_DELAY := 0.05
var exit_timer := 0.0
const AIM_EXIT_DELAY := 0.06

func check_aim_target():
	var space = get_world_2d().direct_space_state

	var query := PhysicsPointQueryParameters2D.new()
	query.position = get_global_mouse_position()
	query.collide_with_areas = true
	query.collision_mask = 1 << 1

	var results = space.intersect_point(query, 8)

	if results.is_empty():
		set_locked_aim(AimLock.NONE)
		return

	# ==========================
	# PILIH TARGET PALING DEPAN (matching get_enemy_under_cursor logic)
	# ==========================
	var best: Area2D = null
	var best_z := -INF
	var best_order := -INF

	for r in results:
		var collider = r.get("collider")
		if not (collider is Area2D):
			continue

		var hit_area := collider as Area2D
		var enemy := hit_area.get_parent()
		if enemy == null:
			continue
		if not _is_enemy_targetable(enemy):
			continue

		# Use same z-index calculation as get_enemy_under_cursor
		var z := _get_effective_z_index(enemy)
		var order := float(enemy.get_index())

		if z > best_z or (z == best_z and order > best_order):
			best_z = z
			best_order = order
			best = hit_area

	if best == null:
		set_locked_aim(AimLock.NONE)
		return

	# ==========================
	# PRIORITAS WEAKNESS DARI TARGET TERDEPAN
	# ==========================
	if best.is_in_group("weak_point"):
		set_locked_aim(AimLock.WEAKNESS)
	elif best.is_in_group("enemy"):
		set_locked_aim(AimLock.ENEMY)
	else:
		set_locked_aim(AimLock.NONE)
		
var unlock_timer := 0.0
const UNLOCK_DELAY := 0.08


func set_aim_state(new_state: AimState):
	if aim_state == new_state:
		return

	aim_state = new_state

	# Jangan ganggu animasi nembak
	if state != State.IDLE:
		return
					
func set_locked_aim(new_lock: AimLock):
	if locked_aim == AimLock.WEAKNESS and new_lock == AimLock.ENEMY:
		unlock_timer += get_process_delta_time()
		if unlock_timer < UNLOCK_DELAY:
			return
	else:
		unlock_timer = 0.0

	if new_lock == locked_aim:
		return

	locked_aim = new_lock
	update_aim_from_lock()

func update_aim_from_lock():
	if state != State.IDLE:
		return

	match current_mode:
		CharacterMode.CHAR_BAKU:
			match locked_aim:
				AimLock.NONE:
					play_anim_safe("default_baku")
				AimLock.ENEMY:
					play_anim_safe("aim_baku")
				AimLock.WEAKNESS:
					play_anim_safe("aim_weakness_baku")

		CharacterMode.CHAR_YUNA:
			match locked_aim:
				AimLock.NONE:
					play_anim_safe("default_yuna")
				AimLock.ENEMY:
					play_anim_safe("aim_yuna")
				AimLock.WEAKNESS:
					play_anim_safe("aim_weakness_yuna")
					
func play_anim_safe(anim: String):
	if sprite.animation == anim:
		return
	sprite.play(anim)


func _on_skill_casted(skill_name: String) -> void:
	match skill_name:
		"OVERDRIVE":
			queued_skill = SkillShot.OVERDRIVE
		"PIERCE":
			queued_skill = SkillShot.PIERCE
		"CHAIN":
			queued_skill = SkillShot.CHAIN
		"NOVA":
			queued_skill = SkillShot.NOVA
		_:
			queued_skill = SkillShot.NONE

	cast_skill_shot_now()


func cast_skill_shot_now() -> void:
	if queued_skill == SkillShot.NONE:
		return

	set_state(State.SHOOT)
	match current_mode:
		CharacterMode.CHAR_BAKU:
			sprite.play("shooting_baku")
			hand_baku.play("shooting")
		CharacterMode.CHAR_YUNA:
			sprite.play("shooting_yuna")
			hand_yuna.play("shooting")

	var hitbox = get_enemy_under_cursor()
	var enemy: Node = null
	if hitbox:
		enemy = hitbox.get_parent()
	elif queued_skill == SkillShot.OVERDRIVE:
		# OVERDRIVE must be cast directly on a hit target.
		queued_skill = SkillShot.NONE
		return
	elif queued_skill == SkillShot.NOVA:
		# NOVA must be cast directly on a hit target.
		queued_skill = SkillShot.NONE
		return
	elif queued_skill == SkillShot.CHAIN:
		enemy = find_nearest_enemy_to_position(get_global_mouse_position(), SKILL_CHAIN_TARGET_SEARCH_RADIUS)
	elif queued_skill != SkillShot.PIERCE and queued_skill != SkillShot.NOVA:
		enemy = find_nearest_enemy_to_cursor(SKILL_AUTO_TARGET_RADIUS)

	if enemy == null and queued_skill != SkillShot.PIERCE and queued_skill != SkillShot.NOVA:
		# Jangan konsumsi skill kalau benar-benar tidak ada target.
		return

	apply_skill_shot(enemy, hitbox, get_global_mouse_position())


func apply_skill_shot(enemy: Node, hitbox: Node, cast_position: Vector2) -> void:
	if enemy == null and queued_skill != SkillShot.PIERCE and queued_skill != SkillShot.NOVA:
		return

	match queued_skill:
		SkillShot.OVERDRIVE:
			var overdrive_delay := SKILL_DELAY_OVERDRIVE
			if enemy.has_method("play_red3_effect"):
				overdrive_delay = enemy.play_red3_effect()
			if enemy.has_method("play_redhit_effect"):
					enemy.play_redhit_effect()
			enemy.instakill(overdrive_delay)

		SkillShot.PIERCE:
			var projectile_origin := cast_position
			if enemy != null:
				if enemy.has_method("play_redhit_effect"):
					enemy.play_redhit_effect()
				if enemy.has_method("apply_damage"):
					enemy.apply_damage(2)
				projectile_origin = enemy.global_position
			spawn_pierce_projectiles(projectile_origin, enemy)

		SkillShot.CHAIN:
			if enemy.has_method("play_bluehit_effect"):
					enemy.play_bluehit_effect()
			apply_chain_mark(enemy)

		SkillShot.NOVA:
			var center_pos := cast_position
			var target_depth := 0.5
			
			if enemy.get("visual") != null:
				enemy.visual.modulate = Color(0.622, 0.644, 1.0, 1.0)
			
			if enemy.has_method("play_blue3_effect"):
					enemy.play_blue3_effect()
					 
					
			if enemy != null:
				enemy.apply_damage(1)
				center_pos = enemy.global_position
				target_depth = _extract_enemy_depth_or_default(enemy, 0.5)
				
			
			apply_nova_pull(center_pos, enemy, target_depth)

	queued_skill = SkillShot.NONE

func find_nearest_enemy_to_cursor(radius: float) -> Node:
	return find_nearest_enemy_to_position(get_global_mouse_position(), radius)


func find_nearest_enemy_to_position(
	center_pos: Vector2,
	radius: float = INF,
	excluded: Array[Node] = [],
	reference_depth: Variant = null,
	max_depth_difference: float = INF
) -> Node:
	var best_enemy: Node = null
	var best_dist: float = radius

	var enemies: Array = get_tree().get_nodes_in_group("enemy_nodes")
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not _is_enemy_targetable(enemy):
			continue
		if excluded.has(enemy):
			continue
		if reference_depth != null and not is_inf(max_depth_difference):
			var enemy_depth := _extract_enemy_depth_or_default(enemy, float(reference_depth))
			if absf(enemy_depth - float(reference_depth)) > max_depth_difference:
				continue

		var dist: float = enemy.global_position.distance_to(center_pos)
		if dist <= best_dist:
			best_dist = dist
			best_enemy = enemy

	return best_enemy


func spawn_pierce_projectiles(origin: Vector2, source_enemy: Node = null) -> void:
	var split_dirs: Array[Vector2] = []
	var base_dir := Vector2.UP
	for i in range(5):
		split_dirs.append(base_dir.rotated(deg_to_rad(float(i) * 72.0)))

	var source_depth := 0.5
	if source_enemy != null and is_instance_valid(source_enemy):
		for prop in source_enemy.get_property_list():
			if String(prop.get("name", "")) == "depth":
				source_depth = float(source_enemy.get("depth"))
				break

	for dir: Vector2 in split_dirs:
		var projectile := PIERCE_PROJECTILE_SCENE.instantiate()
		get_tree().current_scene.add_child(projectile)
		projectile.setup(origin, dir, source_enemy, source_depth)
		projectile.speed = SKILL_PIERCE_PROJECTILE_SPEED
		projectile.max_distance = SKILL_PIERCE_SPLIT_RANGE
		projectile.hit_radius = SKILL_PIERCE_PROJECTILE_RADIUS


func _extract_enemy_depth_or_default(enemy: Node, fallback_depth: float = 0.5) -> float:
	if enemy == null or not is_instance_valid(enemy):
		return fallback_depth

	for prop in enemy.get_property_list():
		if String(prop.get("name", "")) == "depth":
			return float(enemy.get("depth"))

	return fallback_depth


func apply_chain_mark(center_enemy: Node) -> void:
	if center_enemy == null or not is_instance_valid(center_enemy):
		return

	_run_chain_mark_sequence(center_enemy)

const SKILL_CHAIN_MAX_BOUNCES: int = 5

func _run_chain_mark_sequence(start_enemy: Node) -> void:
	var visited: Array[Node] = []
	var current: Node = start_enemy
	var bounce_count: int = 0 
	
	if start_enemy.has_method("apply_damage"):
		if start_enemy.has_method("play_bluehit_effect"):
			start_enemy.play_bluehit_effect()
			start_enemy.apply_damage(1)

	var damage: int = 2
	
	while current != null and is_instance_valid(current):
		if visited.has(current):
			break
			
		if bounce_count >= SKILL_CHAIN_MAX_BOUNCES:  # ← cek batas
			break

		visited.append(current)
		
		var current_depth := _extract_enemy_depth_or_default(current, 0.5)
		var next_enemy := find_nearest_enemy_to_position(
			(current as Node2D).global_position,
			SKILL_CHAIN_TARGET_SEARCH_RADIUS,
			visited,
			current_depth,
			SKILL_CHAIN_MAX_DEPTH_DIFFERENCE
		)
		if next_enemy == null or not is_instance_valid(next_enemy):
			break

		await _play_chain_projectile((current as Node2D).global_position, (next_enemy as Node2D).global_position, next_enemy )
		
		if next_enemy.has_method("apply_damage"):
			next_enemy.apply_damage(damage)

		damage += 1
		
		if next_enemy.has_method("play_bluehit_effect"):
			next_enemy.play_bluehit_effect()

		bounce_count += 1  # ← tambah setiap lompat
		current = next_enemy

const ENEMY_MAX_SCALE: float = 0.3      # scale maksimal enemy
const PROJECTILE_MAX_SCALE: float = 0.5  # scale maksimal projectile chain

func _play_chain_projectile(start_pos: Vector2, end_pos: Vector2, target_enemy: Node = null) -> void:
	var root := get_tree().current_scene
	if root == null:
		return

	if CHAIN_PROJECTILE_SCENE == null:
		return

	var projectile := CHAIN_PROJECTILE_SCENE.instantiate()
	if projectile == null:
		return

	root.add_child(projectile)

	for prop in projectile.get_property_list():
		var prop_name := String(prop.get("name", ""))
		if prop_name == "speed":
			projectile.set("speed", SKILL_CHAIN_PROJECTILE_SPEED)
		elif prop_name == "projectile_scale":
			projectile.set("projectile_scale", SKILL_CHAIN_PROJECTILE_SCALE)
			
	if target_enemy != null and is_instance_valid(target_enemy) and projectile.has_method("set_interpolation_targets"):
		const ENEMY_MIN_SCALE: float = 0.06
		const ENEMY_MAX_SCALE: float = 0.3
		const PROJECTILE_MAX_SCALE: float = 0.4

		const PROJECTILE_MIN_SCALE: float = PROJECTILE_MAX_SCALE * (ENEMY_MIN_SCALE / ENEMY_MAX_SCALE)
		
		var enemy_scale := (target_enemy as Node2D).scale.x
		
		var ratio := clampf((enemy_scale - ENEMY_MIN_SCALE) / (ENEMY_MAX_SCALE - ENEMY_MIN_SCALE), 0.0, 1.0)
		var scale_factor := lerpf(PROJECTILE_MIN_SCALE, PROJECTILE_MAX_SCALE, ratio)
		var target_proj_scale := SKILL_CHAIN_PROJECTILE_SCALE * (scale_factor / SKILL_CHAIN_PROJECTILE_SCALE.x)
				
		var target_z := (target_enemy as Node2D).z_index -1
		projectile.set_interpolation_targets(target_proj_scale, target_z)

	if projectile.has_method("play_between"):
		await projectile.play_between(start_pos, target_enemy as Node2D)


func apply_nova_pull(center_pos: Vector2, center_enemy: Node, target_depth: float) -> void:
	
	# Apply nova pull ke center_enemy juga
	var target_scale = center_enemy.scale if center_enemy != null and is_instance_valid(center_enemy) else Vector2.ONE
	if center_enemy != null and is_instance_valid(center_enemy):
		if center_enemy.has_method("apply_nova_pull_effect"):
			center_enemy.apply_nova_pull_effect(center_pos, target_depth, SKILL_NOVA_PULL_SPEED, SKILL_NOVA_PULL_DURATION)
	var enemies: Array = get_tree().get_nodes_in_group("enemy_nodes")
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy == center_enemy:
			continue
			
		if enemy.is_in_group("boss"):
			continue

		if enemy.global_position.distance_to(center_pos) <= SKILL_NOVA_PULL_RADIUS:
			if enemy.has_method("apply_nova_pull_effect"):
				enemy.apply_nova_pull_effect(center_pos, target_depth, SKILL_NOVA_PULL_SPEED, SKILL_NOVA_PULL_DURATION)
				enemy.scale = target_scale
			elif enemy.has_method("pull_towards"):
				if enemy.is_in_group("boss"):
					continue
				enemy.pull_towards(center_pos)
			enemy.apply_slow(SKILL_NOVA_SLOW_DURATION, SKILL_NOVA_SLOW_FACTOR)
		
