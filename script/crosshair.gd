extends Node2D

@onready var indicator = $"../UIMahouMeter"
@onready var indicator_mahou = $"../UIKoisuruMeter/KoisuruMeter"

const PIERCE_PROJECTILE_SCENE = preload("res://scenes/pierce_projectile.tscn")

enum SkillShot {
	NONE,
	OVERDRIVE,
	PIERCE,
	CHAIN,
	NOVA
}

var queued_skill: SkillShot = SkillShot.NONE

const SKILL_DELAY_OVERDRIVE := 0.28
const SKILL_PIERCE_SPLIT_RANGE := 620.0
const SKILL_PIERCE_PROJECTILE_SPEED := 920.0
const SKILL_PIERCE_PROJECTILE_RADIUS := 28.0
const SKILL_CHAIN_MARK_RADIUS := 240.0
const SKILL_CHAIN_EXPLOSION_RADIUS := 220.0
const SKILL_NOVA_PULL_RADIUS := 280.0
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
		set_state(State.SHOOT)
		shoot()
		
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
	check_aim_target()


@onready var hand_baku := $"../Player/BakuMahou/AnimatedSprite2D2"
@onready var hand_yuna := $"../Player/YunaMahou/AnimatedSprite2D"

func shoot():
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
			if enemy.is_marked():
				enemy.explode_mark(SKILL_CHAIN_EXPLOSION_RADIUS, 1)
			enemy.on_hit(hitbox)
		else:
			apply_skill_shot(enemy, hitbox, get_global_mouse_position())
		indicator.add_slot("baku")
		indicator_mahou.add_baku()

func shoot_yuna():
	sprite.play("shooting_yuna")
	hand_yuna.play("shooting")

	var hitbox = get_enemy_under_cursor()
	if hitbox:
		var enemy = hitbox.get_parent()
		if queued_skill == SkillShot.NONE:
			if enemy.is_marked():
				enemy.explode_mark(SKILL_CHAIN_EXPLOSION_RADIUS, 1)
			enemy.on_hit(hitbox)
		else:
			apply_skill_shot(enemy, hitbox, get_global_mouse_position())
		indicator.add_slot("yuna")
		indicator_mahou.add_yuna()

func get_enemy_under_cursor():
	var space = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = get_global_mouse_position()
	query.collide_with_areas = true
	query.collision_mask = 1 << 1

	var result = space.intersect_point(query)
	if result.size() > 0:
		return result[0].collider
	
	return null
	
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
	# PILIH TARGET PALING DEPAN
	# ==========================
	var best: Area2D = null
	var best_z := -INF

	for r in results:
		var c = r.collider
		if not c:
			continue

		# Ambil z_index parent enemy
		var z := 0
		if c.has_method("get_parent"):
			z = c.get_parent().z_index

		if z > best_z:
			best_z = z
			best = c

	if best == null:
		set_aim_state(AimState.NONE)
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
	elif queued_skill != SkillShot.PIERCE:
		enemy = find_nearest_enemy_to_cursor(SKILL_AUTO_TARGET_RADIUS)

	if enemy == null and queued_skill != SkillShot.PIERCE:
		# Jangan konsumsi skill kalau benar-benar tidak ada target.
		return

	apply_skill_shot(enemy, hitbox, get_global_mouse_position())


func apply_skill_shot(enemy: Node, hitbox: Node, cast_position: Vector2) -> void:
	if enemy == null and queued_skill != SkillShot.PIERCE:
		return

	match queued_skill:
		SkillShot.OVERDRIVE:
			var overdrive_delay := SKILL_DELAY_OVERDRIVE
			if enemy.has_method("play_red3_effect"):
				overdrive_delay = enemy.play_red3_effect()
			enemy.instakill(overdrive_delay)

		SkillShot.PIERCE:
			var projectile_origin := cast_position
			if enemy != null:
				enemy.apply_damage(2)
				projectile_origin = enemy.global_position
			spawn_pierce_projectiles(projectile_origin, enemy)

		SkillShot.CHAIN:
			apply_chain_mark(enemy)

		SkillShot.NOVA:
			enemy.apply_damage(1)
			apply_nova_pull(enemy)

	queued_skill = SkillShot.NONE


func find_nearest_enemy_to_cursor(radius: float) -> Node:
	var cursor_pos: Vector2 = get_global_mouse_position()
	var best_enemy: Node = null
	var best_dist: float = radius

	var enemies: Array = get_tree().get_nodes_in_group("enemy_nodes")
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue

		var dist: float = enemy.global_position.distance_to(cursor_pos)
		if dist <= best_dist:
			best_dist = dist
			best_enemy = enemy

	return best_enemy


func spawn_pierce_projectiles(origin: Vector2, source_enemy: Node = null) -> void:
	var split_dirs: Array[Vector2] = [
		Vector2.UP,
		Vector2(-0.8, 0.6).normalized(),
		Vector2(0.8, 0.6).normalized()
	]

	for dir: Vector2 in split_dirs:
		var projectile := PIERCE_PROJECTILE_SCENE.instantiate()
		get_tree().current_scene.add_child(projectile)
		projectile.setup(origin, dir, source_enemy)
		projectile.speed = SKILL_PIERCE_PROJECTILE_SPEED
		projectile.max_distance = SKILL_PIERCE_SPLIT_RANGE
		projectile.hit_radius = SKILL_PIERCE_PROJECTILE_RADIUS


func apply_chain_mark(center_enemy: Node) -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemy_nodes")
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(center_enemy.global_position) <= SKILL_CHAIN_MARK_RADIUS:
			enemy.set_marked(true)


func apply_nova_pull(center_enemy: Node) -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemy_nodes")
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy == center_enemy:
			continue

		if enemy.global_position.distance_to(center_enemy.global_position) <= SKILL_NOVA_PULL_RADIUS:
			enemy.pull_towards(center_enemy.global_position)
			enemy.apply_slow(SKILL_NOVA_SLOW_DURATION, SKILL_NOVA_SLOW_FACTOR)
