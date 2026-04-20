extends Node2D

signal level_started
signal level_finished

@export var enemy_scene: PackedScene
@export var enemy_2_scene: PackedScene = preload("res://scenes/enemy_2.tscn")
@export var enemy_3_scene: PackedScene = preload("res://scenes/enemy_3.tscn")
@onready var enemy_container = $EnemyContainer
@onready var player_node: Node = $Player
@onready var crosshair_node: Node = $Crosshair
@onready var bird_strike_node: AnimatedSprite2D = $BirdStrike
@onready var bird_strike_alert_node: AnimatedSprite2D = $BirdStrikeAlert
@onready var koisuru_meter_node: Node = $UIKoisuruMeter/KoisuruMeter
@onready var ultimate_anim_node: AnimatedSprite2D = $UltimateAnim
@onready var level_end_overlay: ColorRect = $LevelEndOverlay/ColorRect
@onready var combo_counter_node: Node = $LevelEndOverlay/ComboCounter

@export var max_enemies: int = 20        # Maksimal enemy yang bisa ada sekaligus
@export var spawn_interval: float = 2.0  # Detik per spawn
@export var spawn_batch: int = 1         # Berapa banyak musuh spawn sekaligus
@export var bird_strike_check_interval: float = 8.0
@export var bird_strike_chance: float = 0.1
@export_range(0.0, 20.0, 0.1, "suffix:s") var bird_strike_shoot_lock_duration: float = 4.0
@export_range(0.1, 20.0, 0.1, "suffix:s") var ultimate_boss_weaken_duration: float = 5.0
@export_range(0.0, 10.0, 0.1, "suffix:s") var ultimate_hide_to_kill_delay: float = 0.6
@export_range(0.1, 10.0, 0.1, "suffix:s") var ultimate_kill_wait_timeout: float = 3.0
@export var ultimate_ui_pull_distance: float = 900.0
@export_range(0.1, 5.0, 0.05, "suffix:s") var ultimate_ui_pull_out_anim_duration: float = 1.0
@export var ultimate_ui_return_anim_duration: float = 0.45
@export_range(10.0, 1800.0, 1.0, "suffix:s") var level_duration_seconds: float = 180.0
@export_range(0.0, 10.0, 0.1, "suffix:s") var level_intro_delay_seconds: float = 2.5
@export_range(0.1, 20.0, 0.1, "suffix:s") var level_end_win_delay_seconds: float = 5.0
@export_range(0.1, 20.0, 0.1, "suffix:s") var level_end_lose_delay_seconds: float = 3.0
@export_range(0.0, 20.0, 0.1, "suffix:s") var level_end_ui_pull_delay_seconds: float = 3.0
@export_range(0.1, 5.0, 0.05, "suffix:s") var level_end_lose_fade_duration: float = 1.5
@export_range(0.0, 5.0, 0.05, "suffix:s") var level_end_lose_hold_seconds: float = 2.0

var current_enemy_count: int = 0
var spawn_timer := 0.0
var bird_strike_timer := 0.0
var bird_strike_lock_timer := 0.0
var bird_strike_active := false
var bird_strike_effect_started := false
var ultimate_in_progress: bool = false
var level_running: bool = false
var level_ended: bool = false
var level_end_sequence_running: bool = false
var spawn_allowed: bool = true  # Track if spawn should continue (stops at timer end)
var level_time_left: float = 0.0

@export var base_z_index: int = 100
@export var z_front_min: int = 40
var next_z_index: int
var _ultimate_ui_names: Array[String] = ["CardUI", "UIKoisuruMeter", "UIMahouMeter", "DamageHud", "Player", "Crosshair"]
var _ultimate_ui_original_pos: Dictionary = {}
var _ultimate_ui_pulled_out: bool = false

func _ready():
	next_z_index = base_z_index
	_setup_main_runtime_systems()
	_start_level_intro_flow()

func _start_level_intro_flow() -> void:
	level_running = false
	level_ended = false
	level_end_sequence_running = false
	spawn_allowed = true  # Reset spawn allowance for new level
	level_time_left = maxf(level_duration_seconds, 1.0)

	# Keep combat inactive until intro finishes.
	_set_crosshair_visible(false)
	_set_crosshair_shoot_enabled(false)
	_set_combat_cast_locked(true)

	await _set_ultimate_ui_pulled_out(true, false, true)
	if level_intro_delay_seconds > 0.0:
		await get_tree().create_timer(level_intro_delay_seconds).timeout
	await _set_ultimate_ui_pulled_out(false)

	spawn_timer = 0.0
	bird_strike_timer = 0.0
	bird_strike_lock_timer = 0.0
	level_running = true

	_set_crosshair_visible(true)
	_set_crosshair_shoot_enabled(true)
	_set_combat_cast_locked(false)
	emit_signal("level_started")

func _setup_main_runtime_systems() -> void:
	if bird_strike_node != null:
		bird_strike_node.visible = false
		if not bird_strike_node.animation_finished.is_connected(_on_bird_strike_animation_finished):
			bird_strike_node.animation_finished.connect(_on_bird_strike_animation_finished)
		if not bird_strike_node.frame_changed.is_connected(_on_bird_strike_frame_changed):
			bird_strike_node.frame_changed.connect(_on_bird_strike_frame_changed)

	if bird_strike_alert_node != null:
		bird_strike_alert_node.visible = false
		if not bird_strike_alert_node.animation_finished.is_connected(_on_bird_strike_alert_animation_finished):
			bird_strike_alert_node.animation_finished.connect(_on_bird_strike_alert_animation_finished)

	if ultimate_anim_node != null:
		ultimate_anim_node.visible = false
		if not ultimate_anim_node.animation_finished.is_connected(_on_ultimate_anim_finished):
			ultimate_anim_node.animation_finished.connect(_on_ultimate_anim_finished)

	if koisuru_meter_node != null and koisuru_meter_node.has_signal("ultimate_casted"):
		if not koisuru_meter_node.is_connected("ultimate_casted", Callable(self, "_on_ultimate_casted")):
			koisuru_meter_node.connect("ultimate_casted", Callable(self, "_on_ultimate_casted"))

	if player_node != null and is_instance_valid(player_node) and player_node.has_signal("died"):
		if not player_node.is_connected("died", Callable(self, "_on_player_died")):
			player_node.connect("died", Callable(self, "_on_player_died"))

	if level_end_overlay != null:
		level_end_overlay.visible = false
		level_end_overlay.color = Color(0, 0, 0, 0)

	if combo_counter_node != null and is_instance_valid(combo_counter_node):
		# Assign script if not already assigned
		if combo_counter_node.get_script() == null:
			var combo_script = load("res://script/combo_counter.gd")
			if combo_script != null:
				combo_counter_node.set_script(combo_script)
		# Initialize combo counter
		if combo_counter_node.has_method("reset"):
			combo_counter_node.reset()

func spawn_enemy():
	_spawn_enemy_instance(_pick_random_enemy_scene())


func _pick_random_enemy_scene() -> PackedScene:
	var enemy_pool: Array[PackedScene] = []
	if enemy_scene != null:
		enemy_pool.append(enemy_scene)
	if enemy_2_scene != null:
		enemy_pool.append(enemy_2_scene)
	if enemy_3_scene != null:
		enemy_pool.append(enemy_3_scene)

	if enemy_pool.is_empty():
		return null

	return enemy_pool[randi() % enemy_pool.size()]


func _spawn_enemy_instance(scene_to_spawn: PackedScene) -> bool:
	if scene_to_spawn == null:
		return false

	if current_enemy_count >= max_enemies:
		return false

	var enemy = scene_to_spawn.instantiate()
	if enemy == null:
		return false

	# Bisa spawn di posisi random, tapi masih di screen
	enemy.position = Vector2(800, 512)
	
	enemy.z_front = max(next_z_index, z_front_min)
	next_z_index -= 1
	enemy_container.add_child(enemy)

	current_enemy_count += 1

	# Jika enemy mati, kurangi counter (di script enemy)
	enemy.connect("tree_exited", Callable(self, "_on_enemy_removed"))
	return true


func _process(delta):
	if level_ended:
		_ensure_bird_strike_alert_hidden_when_idle()
		return

	if not level_running:
		_ensure_bird_strike_alert_hidden_when_idle()
		return

# update timer
	level_time_left = maxf(level_time_left - delta, 0.0)
	if level_time_left <= 0.0 and spawn_allowed:
		_finish_spawn()  # Stop spawn, but don't end level yet

	spawn_timer += delta
	bird_strike_timer += delta
	_ensure_bird_strike_alert_hidden_when_idle()

	if bird_strike_lock_timer > 0.0:
		bird_strike_lock_timer = maxf(bird_strike_lock_timer - delta, 0.0)
		if bird_strike_lock_timer <= 0.0:
			_set_crosshair_shoot_enabled(true)
			_set_combat_cast_locked(false)
			_set_player_damage_hud_forced(false)
			_set_transition_crt_discolor(false)
			bird_strike_active = false
			bird_strike_effect_started = false

	if spawn_timer >= spawn_interval and spawn_allowed:
		spawn_timer = 0.0
		spawn_batch_enemies()

	if bird_strike_timer >= maxf(bird_strike_check_interval, 0.1):
		bird_strike_timer = 0.0
		_try_trigger_bird_strike_event()

	# Check if all enemies killed and spawn stopped - truly end level
	if not spawn_allowed and current_enemy_count <= 0 and not level_ended:
		_begin_level_end_sequence(false)

func _finish_spawn() -> void:
	# Stop spawn when timer ends, but don't end level yet
	spawn_allowed = false

	# Stop bird strike spawning chance
	_set_bird_strike_allowed(false)

func _truly_end_level() -> void:
	_begin_level_end_sequence(false)


func _on_player_died() -> void:
	_begin_level_end_sequence(true)


func _begin_level_end_sequence(is_loss: bool) -> void:
	if level_end_sequence_running or level_ended:
		return

	level_end_sequence_running = true
	bird_strike_active = false
	bird_strike_effect_started = false
	bird_strike_lock_timer = 0.0
	spawn_allowed = false
	
	# Fade out combo counter
	combo_counter_fade_out()

	_set_bird_strike_allowed(false, true, true)
	_set_crosshair_shoot_enabled(false)
	_set_crosshair_visible(false)
	_set_combat_cast_locked(true)
	_set_player_input_locked(true)
	if level_end_overlay != null and is_instance_valid(level_end_overlay):
		level_end_overlay.visible = true
		level_end_overlay.color = Color(0, 0, 0, 1) if is_loss else Color(1, 1, 1, 1)
		level_end_overlay.modulate = Color(1, 1, 1, 0)

	var total_delay := level_end_lose_delay_seconds if is_loss else level_end_win_delay_seconds
	total_delay = maxf(total_delay, 0.0)
	var pull_delay := clampf(level_end_ui_pull_delay_seconds, 0.0, total_delay)
	if pull_delay > 0.0:
		await get_tree().create_timer(pull_delay).timeout

	await _set_ultimate_ui_pulled_out(true, true)

	var remaining_delay := maxf(total_delay - pull_delay, 0.0)
	if remaining_delay > 0.0:
		await get_tree().create_timer(remaining_delay).timeout

	if is_loss:
		await _play_level_end_screen_fade(Color(0, 0, 0, 1))
	else:
		await _play_level_end_screen_fade(Color(1, 1, 1, 1))

	level_ended = true
	level_running = false
	emit_signal("level_finished")

	if not is_inside_tree():
		return

	LoadingManager.set_target_scene("res://scenes/level_menu.tscn")
	get_tree().change_scene_to_file("res://scenes/loading_screen.tscn")


func _play_level_end_screen_fade(target_color: Color) -> void:
	if level_end_overlay == null or not is_instance_valid(level_end_overlay):
		return

	level_end_overlay.visible = true
	level_end_overlay.color = target_color
	level_end_overlay.modulate = Color(1, 1, 1, 0)

	var fade_tween := create_tween()
	fade_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	fade_tween.tween_property(level_end_overlay, "modulate:a", 1.0, maxf(level_end_lose_fade_duration, 0.01))
	await fade_tween.finished

	var hold_time := maxf(level_end_lose_hold_seconds, 0.0)
	if hold_time > 0.0:
		await get_tree().create_timer(hold_time).timeout

func _ensure_bird_strike_alert_hidden_when_idle() -> void:
	if bird_strike_alert_node == null or not is_instance_valid(bird_strike_alert_node):
		return

	if not bird_strike_alert_node.is_playing():
		bird_strike_alert_node.visible = false

func spawn_batch_enemies():
	for i in spawn_batch:
		if current_enemy_count >= max_enemies:
			break  # Jangan spawn lebih dari max
		spawn_enemy()
		
func _on_enemy_removed():
	current_enemy_count = max(current_enemy_count - 1, 0)

func on_player_hit(character: String = "baku") -> void:
	"""Called when player successfully hits a target"""
	if combo_counter_node != null and is_instance_valid(combo_counter_node):
		if combo_counter_node.has_method("on_hit"):
			combo_counter_node.on_hit(character)

func on_player_miss() -> void:
	"""Called when player shoots but misses"""
	if combo_counter_node != null and is_instance_valid(combo_counter_node):
		if combo_counter_node.has_method("on_miss"):
			combo_counter_node.on_miss()

func combo_counter_fade_out() -> void:
	"""Called when combo counter should fade out due to UI events (like ultimate)"""
	if combo_counter_node != null and is_instance_valid(combo_counter_node):
		if combo_counter_node.has_method("fade_out"):
			combo_counter_node.fade_out()

func _try_trigger_bird_strike_event() -> void:
	if ultimate_in_progress:
		return
	if bird_strike_active:
		return
	if randf() > clampf(bird_strike_chance, 0.0, 1.0):
		return

	bird_strike_active = true
	bird_strike_effect_started = false
	_play_bird_strike_alert_then_strike()

func _play_bird_strike_alert_then_strike() -> void:
	if bird_strike_alert_node != null and is_instance_valid(bird_strike_alert_node):
		bird_strike_alert_node.visible = true
		bird_strike_alert_node.play("popup")
		return

	_start_bird_strike_now()

func _on_bird_strike_alert_animation_finished() -> void:
	if bird_strike_alert_node != null and is_instance_valid(bird_strike_alert_node):
		bird_strike_alert_node.visible = false

	if not bird_strike_active:
		return

	_start_bird_strike_now()

func _start_bird_strike_now() -> void:
	if bird_strike_node != null:
		bird_strike_node.visible = true
		bird_strike_node.frame = 0
		bird_strike_node.frame_progress = 0.0
		bird_strike_node.play("strike")

func _on_bird_strike_frame_changed() -> void:
	if not bird_strike_active or bird_strike_effect_started:
		return
	if bird_strike_node == null or not is_instance_valid(bird_strike_node):
		return
	if bird_strike_node.animation != StringName("strike"):
		return
	if bird_strike_node.frame < 5:
		return

	bird_strike_effect_started = true
	bird_strike_lock_timer = maxf(bird_strike_shoot_lock_duration, 0.0)
	_set_crosshair_shoot_enabled(false)
	_set_combat_cast_locked(true)
	_set_player_damage_hud_forced(true)
	_set_transition_crt_discolor(false)
	if Transition != null and Transition.has_method("play_crt_glitch_burst"):
		Transition.play_crt_glitch_burst()
	_schedule_transition_discolor_after_impact()
	if player_node != null and is_instance_valid(player_node) and player_node.has_method("trigger_screen_shake"):
		player_node.trigger_screen_shake()

func _on_bird_strike_animation_finished() -> void:
	if bird_strike_node != null:
		bird_strike_node.visible = false
	if bird_strike_lock_timer <= 0.0:
		bird_strike_active = false
		bird_strike_effect_started = false
		_set_transition_crt_discolor(false)

func _set_crosshair_shoot_enabled(enabled: bool) -> void:
	if crosshair_node != null and is_instance_valid(crosshair_node) and crosshair_node.has_method("set_shoot_enabled"):
		crosshair_node.set_shoot_enabled(enabled)

func _set_crosshair_visible(visible_state: bool) -> void:
	if crosshair_node == null or not is_instance_valid(crosshair_node):
		return

	if crosshair_node.has_method("set_force_hidden"):
		crosshair_node.set_force_hidden(not visible_state)
		return

	if crosshair_node is CanvasItem:
		(crosshair_node as CanvasItem).visible = visible_state


func _set_player_input_locked(locked: bool) -> void:
	if player_node != null and is_instance_valid(player_node) and player_node.has_method("set_input_locked"):
		player_node.set_input_locked(locked)

func _on_ultimate_casted() -> void:
	if not level_running or level_ended:
		return
	if ultimate_in_progress:
		return
	ultimate_in_progress = true
	_set_crosshair_visible(false)
	_set_player_invulnerable(true)
	_set_bird_strike_allowed(false)

	await _set_ultimate_ui_pulled_out(true)
	_play_ultimate_anim()
	await _wait_for_ultimate_anim_frame(8)
	if player_node != null and is_instance_valid(player_node) and player_node.has_method("trigger_screen_shake"):
		player_node.trigger_screen_shake()
	var killed_targets := _kill_non_boss_enemies_in_viewport()
	_force_boss_weakened_state()
	await _wait_until_targets_cleared(killed_targets)

	await _set_ultimate_ui_pulled_out(false)
	_stop_ultimate_anim()
	_set_bird_strike_allowed(true)
	_set_crosshair_visible(true)
	_set_player_invulnerable(false)
	ultimate_in_progress = false

func _play_ultimate_anim() -> void:
	if ultimate_anim_node == null or not is_instance_valid(ultimate_anim_node):
		return

	ultimate_anim_node.visible = true
	ultimate_anim_node.frame = 0

	var anim_name := StringName("cast_ult")
	if ultimate_anim_node.sprite_frames != null and ultimate_anim_node.sprite_frames.has_animation(anim_name):
		ultimate_anim_node.play(anim_name)
		return

	if ultimate_anim_node.animation != StringName(""):
		ultimate_anim_node.play(ultimate_anim_node.animation)
		return

	if ultimate_anim_node.sprite_frames != null:
		var names := ultimate_anim_node.sprite_frames.get_animation_names()
		if names.size() > 0:
			ultimate_anim_node.play(names[0])

func _wait_for_ultimate_anim_frame(target_frame: int) -> void:
	if ultimate_anim_node == null or not is_instance_valid(ultimate_anim_node):
		return

	var guard := 240
	while guard > 0:
		if not is_instance_valid(ultimate_anim_node):
			return
		if ultimate_anim_node.frame >= target_frame:
			return
		await get_tree().process_frame
		guard -= 1

func _stop_ultimate_anim() -> void:
	if ultimate_anim_node == null or not is_instance_valid(ultimate_anim_node):
		return

	ultimate_anim_node.stop()
	ultimate_anim_node.visible = false

func _on_ultimate_anim_finished() -> void:
	if ultimate_anim_node == null or not is_instance_valid(ultimate_anim_node):
		return

	ultimate_anim_node.stop()
	ultimate_anim_node.visible = false

func _set_player_invulnerable(enabled: bool) -> void:
	if player_node != null and is_instance_valid(player_node) and player_node.has_method("set_invulnerable"):
		player_node.set_invulnerable(enabled)

func _set_player_damage_hud_forced(enabled: bool) -> void:
	if player_node != null and is_instance_valid(player_node) and player_node.has_method("set_damage_hud_forced"):
		player_node.set_damage_hud_forced(enabled)

func _set_combat_cast_locked(locked: bool) -> void:
	var root := get_tree().current_scene
	if root == null:
		return

	var mahou_meter := root.find_child("UIMahouMeter", true, false)
	if mahou_meter != null and is_instance_valid(mahou_meter) and mahou_meter.has_method("set_cast_locked"):
		mahou_meter.set_cast_locked(locked)

	if koisuru_meter_node != null and is_instance_valid(koisuru_meter_node) and koisuru_meter_node.has_method("set_ultimate_locked"):
		koisuru_meter_node.set_ultimate_locked(locked)

func _set_bird_strike_allowed(allowed: bool, preserve_input_state: bool = false, preserve_damage_hud_state: bool = false) -> void:
	if allowed:
		return

	bird_strike_active = false
	bird_strike_effect_started = false
	bird_strike_lock_timer = 0.0
	if not preserve_input_state:
		_set_combat_cast_locked(false)
	if not preserve_damage_hud_state:
		_set_player_damage_hud_forced(false)
	_set_transition_crt_discolor(false)
	if bird_strike_alert_node != null and is_instance_valid(bird_strike_alert_node):
		bird_strike_alert_node.stop()
		bird_strike_alert_node.visible = false
	if bird_strike_node != null and is_instance_valid(bird_strike_node):
		bird_strike_node.stop()
		bird_strike_node.visible = false
	if not preserve_input_state:
		_set_crosshair_shoot_enabled(true)

func _set_transition_crt_discolor(enabled: bool) -> void:
	if Transition != null and Transition.has_method("set_crt_discolor"):
		Transition.set_crt_discolor(enabled)

func _schedule_transition_discolor_after_impact() -> void:
	var delay := _get_transition_crt_burst_duration()
	if delay <= 0.0:
		_on_bird_strike_impact_window_finished()
		return

	var timer := get_tree().create_timer(delay)
	timer.timeout.connect(Callable(self, "_on_bird_strike_impact_window_finished"), CONNECT_ONE_SHOT)

func _on_bird_strike_impact_window_finished() -> void:
	if not bird_strike_active:
		return
	if bird_strike_lock_timer <= 0.0:
		return
	_set_transition_crt_discolor(true)

func _get_transition_crt_burst_duration() -> float:
	if Transition != null and Transition.has_method("get_crt_glitch_burst_duration"):
		return float(Transition.call("get_crt_glitch_burst_duration"))
	return 0.0

func _kill_non_boss_enemies_in_viewport() -> Array[Node]:
	var targets: Array[Node] = []
	var viewport_rect := get_viewport_rect()
	for enemy in get_tree().get_nodes_in_group("enemy_nodes"):
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.has_method("force_weakened_state"):
			continue
		if not (enemy is Node2D):
			continue

		var enemy_node := enemy as Node2D
		if not viewport_rect.has_point(enemy_node.global_position):
			continue

		targets.append(enemy)

		if enemy.has_method("instakill"):
			enemy.instakill()
		elif enemy.has_method("die"):
			enemy.die()

	return targets

func _wait_until_targets_cleared(targets: Array[Node]) -> void:
	if targets.is_empty():
		return

	var timeout := maxf(ultimate_kill_wait_timeout, 0.1)
	while timeout > 0.0:
		var all_cleared := true
		for target in targets:
			if target == null:
				continue
			if not is_instance_valid(target):
				continue

			all_cleared = false
			break

		if all_cleared:
			return

		await get_tree().process_frame
		timeout -= get_process_delta_time()

func _force_boss_weakened_state() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy_nodes"):
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.has_method("force_weakened_state"):
			enemy.force_weakened_state(maxf(ultimate_boss_weaken_duration, 0.1))

func _set_ultimate_ui_pulled_out(pulled: bool, skip_damage_hud: bool = false, instant: bool = false) -> void:
	if _ultimate_ui_pulled_out == pulled:
		return

	var root := get_tree().current_scene
	if root == null:
		return

	# Fade out combo counter when pulling UI
	if pulled:
		combo_counter_fade_out()

	var viewport_rect := get_viewport_rect()
	var pull_dist := maxf(ultimate_ui_pull_distance, viewport_rect.size.y + 220.0)
	var pull_tween: Tween = null
	var restore_tween: Tween = null
	if not instant and pulled and ultimate_ui_pull_out_anim_duration > 0.0:
		pull_tween = create_tween()
		pull_tween.set_trans(Tween.TRANS_CUBIC)
		pull_tween.set_ease(Tween.EASE_IN_OUT)
		pull_tween.set_parallel(true)
	elif not instant and not pulled and ultimate_ui_return_anim_duration > 0.0:
		restore_tween = create_tween()
		restore_tween.set_trans(Tween.TRANS_CUBIC)
		restore_tween.set_ease(Tween.EASE_OUT)
		restore_tween.set_parallel(true)

	for name in _ultimate_ui_names:
		if skip_damage_hud and name == "DamageHud":
			continue

		var node := root.find_child(name, true, false)
		if node == null:
			continue

		var pull_vec := Vector2(0.0, pull_dist)
		if name == "UIMahouMeter":
			pull_vec = Vector2(0.0, -pull_dist)
		elif name == "CardUI":
			pull_vec = Vector2(-pull_dist, pull_dist)

		if node is Node2D:
			var n2d := node as Node2D
			if pulled:
				if not _ultimate_ui_original_pos.has(name):
					_ultimate_ui_original_pos[name] = n2d.position
				var target_pos := (_ultimate_ui_original_pos[name] as Vector2) + pull_vec
				if pull_tween != null:
					pull_tween.tween_property(n2d, "position", target_pos, ultimate_ui_pull_out_anim_duration)
				else:
					n2d.position = target_pos
			elif _ultimate_ui_original_pos.has(name):
				var target_pos := _ultimate_ui_original_pos[name] as Vector2
				if restore_tween != null:
					restore_tween.tween_property(n2d, "position", target_pos, ultimate_ui_return_anim_duration)
				else:
					n2d.position = target_pos
			continue

		if node is CanvasLayer:
			var layer := node as CanvasLayer
			if pulled:
				if not _ultimate_ui_original_pos.has(name):
					_ultimate_ui_original_pos[name] = layer.offset
				var target_offset := (_ultimate_ui_original_pos[name] as Vector2) + pull_vec
				if pull_tween != null:
					pull_tween.tween_property(layer, "offset", target_offset, ultimate_ui_pull_out_anim_duration)
				else:
					layer.offset = target_offset
			elif _ultimate_ui_original_pos.has(name):
				var target_offset := _ultimate_ui_original_pos[name] as Vector2
				if restore_tween != null:
					restore_tween.tween_property(layer, "offset", target_offset, ultimate_ui_return_anim_duration)
				else:
					layer.offset = target_offset

	_ultimate_ui_pulled_out = pulled

	if pull_tween != null:
		await pull_tween.finished
	elif restore_tween != null:
		await restore_tween.finished
