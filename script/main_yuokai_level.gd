extends "res://script/main_boss_level.gd"

func _ready() -> void:
	super._ready()
	_configure_baku_only_mode()

func _configure_baku_only_mode() -> void:
	if player_node != null and is_instance_valid(player_node):
		if player_node.has_method("set_current_character"):
			player_node.set_current_character("baku")
		if player_node.has_method("set_switch_locked"):
			player_node.set_switch_locked(true)

	if crosshair_node != null and is_instance_valid(crosshair_node):
		if crosshair_node.has_method("set_character_mode"):
			crosshair_node.set_character_mode("baku")
		if crosshair_node.has_method("set_switch_locked"):
			crosshair_node.set_switch_locked(true)

	_set_combat_cast_locked(true)

func _spawn_boss_once() -> void:
	if boss_spawned:
		return
	if enemy_scene == null:
		push_warning("enemy_scene belum diset untuk main_yuokai")
		return

	var boss = enemy_scene.instantiate()
	if boss == null:
		push_warning("Gagal instantiate bakumono boss scene")
		return

	boss.position = boss_spawn_position
	boss.z_index = max(next_z_index, z_front_min)
	next_z_index -= 1
	enemy_container.add_child(boss)

	boss_spawned = true
	current_enemy_count = 1
	boss.tree_exited.connect(_on_boss_removed)
