extends "res://main.gd"

@export var boss_spawn_position: Vector2 = Vector2(800, 512)

var boss_spawned: bool = false

func _ready() -> void:
	next_z_index = base_z_index
	_setup_main_runtime_systems()
	_spawn_boss_once()

func _process(_delta: float) -> void:
	# Boss-only level: disable regular enemy wave spawning.
	pass

func _spawn_boss_once() -> void:
	if boss_spawned:
		return
	if enemy_scene == null:
		push_warning("enemy_scene belum diset untuk boss level")
		return

	var boss = enemy_scene.instantiate()
	if boss == null:
		push_warning("Gagal instantiate boss scene")
		return

	boss.position = boss_spawn_position
	boss.z_index = max(next_z_index, z_front_min)
	next_z_index -= 1
	enemy_container.add_child(boss)

	boss_spawned = true
	current_enemy_count = 1
	boss.tree_exited.connect(_on_boss_removed)

func _on_boss_removed() -> void:
	current_enemy_count = 0
