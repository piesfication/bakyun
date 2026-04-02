extends "res://main_easy.gd"

@export var boss_scene: PackedScene = preload("res://scenes/enemy_boss.tscn")
@export var boss_spawn_position: Vector2 = Vector2(800, 512)
@export_range(0.1, 20.0, 0.1, "suffix:s") var hard_batch_spawn_cooldown: float = 3.2
@export_range(0.0, 1.0, 0.01) var hard_bird_strike_chance: float = 0.3

const HARD_BATCH_WEIGHT_ENEMY3_X5 := 1
const HARD_BATCH_WEIGHT_ENEMY3_THEN_ENEMY2_X5 := 1
const HARD_BATCH_WEIGHT_NORMAL_X6 := 1
const HARD_BATCH_WEIGHT_NORMAL2_ENEMY3_2 := 1
const HARD_BATCH_WEIGHT_ENEMY2_3_NORMAL3 := 1
const HARD_BATCH_WEIGHT_RANDOM_X1 := 3
const HARD_BATCH_WEIGHT_ENEMY3_3_THEN_ENEMY2_X5 := 1
const HARD_BATCH_WEIGHT_RANDOM_X3 := 3
const HARD_BATCH_WEIGHT_123_X3 := 1
const HARD_BATCH_WEIGHT_SPIKE_MIX := 2

var _hard_boss_spawned: bool = false
var _hard_boss_phase_active: bool = false

func _ready() -> void:
	batch_spawn_cooldown = maxf(hard_batch_spawn_cooldown, 0.1)
	bird_strike_chance = clampf(hard_bird_strike_chance, 0.0, 1.0)
	super._ready()

func _finish_spawn() -> void:
	if _hard_boss_phase_active:
		return

	spawn_allowed = false
	_hard_boss_phase_active = true
	_set_bird_strike_allowed(false)
	_spawn_hard_boss_once()

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
		9:
			await _spawn_hard_spike_mix_batch()

func _pick_weighted_batch_id() -> int:
	var weights: Array[int] = [
		HARD_BATCH_WEIGHT_ENEMY3_X5,
		HARD_BATCH_WEIGHT_ENEMY3_THEN_ENEMY2_X5,
		HARD_BATCH_WEIGHT_NORMAL_X6,
		HARD_BATCH_WEIGHT_NORMAL2_ENEMY3_2,
		HARD_BATCH_WEIGHT_ENEMY2_3_NORMAL3,
		HARD_BATCH_WEIGHT_RANDOM_X1,
		HARD_BATCH_WEIGHT_ENEMY3_3_THEN_ENEMY2_X5,
		HARD_BATCH_WEIGHT_RANDOM_X3,
		HARD_BATCH_WEIGHT_123_X3,
		HARD_BATCH_WEIGHT_SPIKE_MIX
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

func _spawn_hard_spike_mix_batch() -> void:
	await _spawn_repeated(enemy_3_scene, 2)
	await _wait_phase_gap()
	await _spawn_random_repeated(4)
	await _wait_phase_gap()
	await _spawn_repeated(enemy_2_scene, 2)

func _spawn_hard_boss_once() -> void:
	if _hard_boss_spawned:
		return
	if boss_scene == null:
		push_warning("boss_scene belum diset untuk main_hard")
		return

	var boss = boss_scene.instantiate()
	if boss == null:
		push_warning("Gagal instantiate boss scene di main_hard")
		return

	boss.position = boss_spawn_position
	boss.z_index = max(next_z_index, z_front_min)
	next_z_index -= 1
	enemy_container.add_child(boss)
	current_enemy_count += 1
	boss.tree_exited.connect(Callable(self, "_on_enemy_removed"))

	if boss.has_signal("boss_defeated"):
		boss.connect("boss_defeated", Callable(self, "_on_hard_boss_defeated"))

	_hard_boss_spawned = true

func _on_hard_boss_defeated() -> void:
	if level_ended:
		return
	_truly_end_level()
