extends Node2D

@onready var indicator = $"../UIMahouMeter"
@onready var indicator_mahou = $"../UIKoisuruMeter/KoisuruMeter"

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
			
	if event is InputEventMouseButton and event.pressed:
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
	
#=================== SHOOT
#func shoot():
	#var space = get_world_2d().direct_space_state
	#var mouse_pos = get_global_mouse_position()
#
	#var query = PhysicsPointQueryParameters2D.new()
	#query.position = mouse_pos
	#query.collide_with_areas = true
	#query.collision_mask = 1 << 1 # Layer Enemy
#
	#var result = space.intersect_point(query)
#
	#if result.size() > 0:
		## Collider adalah Area2D hitbox
		#var hitbox = result[0].collider
		#var enemy = hitbox.get_parent()
	#
		#if enemy.has_method("on_hit"):
			#enemy.on_hit(hitbox)
			

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
		enemy.on_hit(hitbox)
		indicator.add_slot("baku")
		indicator_mahou.add_baku()

func shoot_yuna():
	sprite.play("shooting_yuna")
	hand_yuna.play("shooting")

	var hitbox = get_enemy_under_cursor()
	if hitbox:
		var enemy = hitbox.get_parent()
		enemy.on_hit(hitbox)
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

	#match current_mode:
		#CharacterMode.CHAR_BAKU:
			#match aim_state:
				#AimState.NONE:
					#sprite.play("default_baku")
				#AimState.ENEMY:
					#sprite.play("aim_baku")
				#AimState.WEAKNESS:
					#sprite.play("aim_weakness_baku")
#
		#CharacterMode.CHAR_YUNA:
			#match aim_state:
				#AimState.NONE:
					#sprite.play("default_yuna")
				#AimState.ENEMY:
					#sprite.play("aim_yuna")
				#AimState.WEAKNESS:
					#sprite.play("aim_weakness_yuna")
					
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

	
