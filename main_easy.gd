extends "res://main.gd"

@export var enemy_2_scene: PackedScene = preload("res://scenes/enemy_2.tscn")
@export var enemy_3_scene: PackedScene = preload("res://scenes/enemy_3.tscn")
@export_range(0.01, 2.0, 0.01, "suffix:s") var burst_spawn_interval: float = 0.14
@export_range(0.05, 3.0, 0.01, "suffix:s") var phase_gap_interval: float = 0.5
@export_range(0.1, 20.0, 0.1, "suffix:s") var batch_spawn_cooldown: float = 5.5

# Weighted batches for easy mode.
# Higher weight = chosen more often.
const BATCH_WEIGHT_ENEMY3_X5 := 1
const BATCH_WEIGHT_ENEMY3_THEN_ENEMY2_X5 := 1
const BATCH_WEIGHT_NORMAL_X6 := 1
const BATCH_WEIGHT_NORMAL2_ENEMY3_2 := 1
const BATCH_WEIGHT_ENEMY2_3_NORMAL3 := 1
const BATCH_WEIGHT_RANDOM_X1 := 4
const BATCH_WEIGHT_ENEMY3_3_THEN_ENEMY2_X5 := 1
const BATCH_WEIGHT_RANDOM_X3 := 3
const BATCH_WEIGHT_123_X3 := 1

var _batch_spawning: bool = false
var _batch_cooldown_timer: float = 0.0

func spawn_enemy():
	# Keep compatibility if another flow still calls spawn_enemy directly.
	_spawn_enemy_instance(_pick_random_enemy_scene())

func _process(delta: float) -> void:
	if _batch_cooldown_timer > 0.0:
		_batch_cooldown_timer = maxf(_batch_cooldown_timer - delta, 0.0)

	super._process(delta)

func spawn_batch_enemies() -> void:
	if _batch_spawning:
		return
	if _batch_cooldown_timer > 0.0:
		return

	_batch_spawning = true
	await _run_random_weighted_batch()
	_batch_spawning = false
	_batch_cooldown_timer = maxf(batch_spawn_cooldown, 0.0)

func _run_random_weighted_batch() -> void:
	if current_enemy_count >= max_enemies:
		return

	match _pick_weighted_batch_id():
		0:
			await _spawn_repeated(enemy_3_scene, 5)
		1:
			await _spawn_repeated(enemy_3_scene, 1)
			await _wait_phase_gap()
			await _spawn_repeated(enemy_2_scene, 5)
		2:
			await _spawn_repeated(enemy_scene, 6)
		3:
			await _spawn_repeated(enemy_scene, 2)
			await _spawn_repeated(enemy_3_scene, 2)
		4:
			await _spawn_repeated(enemy_2_scene, 3)
			await _spawn_repeated(enemy_scene, 3)
		5:
			await _spawn_random_repeated(1)
		6:
			await _spawn_repeated(enemy_3_scene, 3)
			await _wait_phase_gap()
			await _spawn_repeated(enemy_2_scene, 5)
		7:
			await _spawn_random_repeated(3)
		8:
			await _spawn_pattern_123_x3()

func _pick_weighted_batch_id() -> int:
	var weights: Array[int] = [
		BATCH_WEIGHT_ENEMY3_X5,
		BATCH_WEIGHT_ENEMY3_THEN_ENEMY2_X5,
		BATCH_WEIGHT_NORMAL_X6,
		BATCH_WEIGHT_NORMAL2_ENEMY3_2,
		BATCH_WEIGHT_ENEMY2_3_NORMAL3,
		BATCH_WEIGHT_RANDOM_X1,
		BATCH_WEIGHT_ENEMY3_3_THEN_ENEMY2_X5,
		BATCH_WEIGHT_RANDOM_X3,
		BATCH_WEIGHT_123_X3
	]

	var total := 0
	for w in weights:
		total += max(w, 0)

	if total <= 0:
		return 5

	var roll := randi() % total
	var running := 0
	for i in range(weights.size()):
		running += max(weights[i], 0)
		if roll < running:
			return i

	return weights.size() - 1

func _spawn_repeated(scene_to_spawn: PackedScene, amount: int) -> void:
	if scene_to_spawn == null:
		return

	for i in range(amount):
		if current_enemy_count >= max_enemies:
			return

		if _spawn_enemy_instance(scene_to_spawn) and i < amount - 1:
			await _wait_burst_gap()

func _spawn_random_repeated(amount: int) -> void:
	for i in range(amount):
		if current_enemy_count >= max_enemies:
			return

		if _spawn_enemy_instance(_pick_random_enemy_scene()) and i < amount - 1:
			await _wait_burst_gap()

func _spawn_pattern_123_x3() -> void:
	for i in range(3):
		if current_enemy_count >= max_enemies:
			return
		if _spawn_enemy_instance(enemy_scene):
			await _wait_burst_gap()

		if current_enemy_count >= max_enemies:
			return
		if _spawn_enemy_instance(enemy_2_scene):
			await _wait_burst_gap()

		if current_enemy_count >= max_enemies:
			return
		if _spawn_enemy_instance(enemy_3_scene) and i < 2:
			await _wait_burst_gap()

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
	enemy.position = Vector2(800, 512)
	enemy.z_front = max(next_z_index, z_front_min)
	next_z_index -= 1
	enemy_container.add_child(enemy)

	current_enemy_count += 1
	enemy.connect("tree_exited", Callable(self, "_on_enemy_removed"))
	return true

func _wait_burst_gap() -> void:
	var gap := maxf(burst_spawn_interval, 0.01)
	await get_tree().create_timer(gap).timeout

func _wait_phase_gap() -> void:
	var gap := maxf(phase_gap_interval, burst_spawn_interval)
	await get_tree().create_timer(gap).timeout
