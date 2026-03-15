extends Node2D

@export var enemy_scene: PackedScene
@onready var enemy_container = $EnemyContainer
@onready var player = $Player
@onready var damaged_hud = $DamagedHUD

@export var max_enemies: int = 20        # Maksimal enemy yang bisa ada sekaligus
@export var spawn_interval: float = 2.0  # Detik per spawn
@export var spawn_batch: int = 1         # Berapa banyak musuh spawn sekaligus

var current_enemy_count: int = 0
var spawn_timer := 0.0

@export var base_z_index: int = 100
@export var z_front_min: int = 40
var next_z_index: int

@export var damage_hud_duration: float = 0.2
var damage_hud_timer: float = 0.0

@export var screen_shake_duration: float = 0.3
@export var screen_shake_strength: float = 14.0
var screen_shake_timer: float = 0.0
var base_position: Vector2

func _ready():
	next_z_index = base_z_index
	base_position = position
	if player.has_signal("hp_changed"):
		player.connect("hp_changed", Callable(self, "_on_player_hp_changed"))

	damaged_hud.visible = false

func spawn_enemy():
	var enemy = enemy_scene.instantiate()

	# Bisa spawn di posisi random, tapi masih di screen
	enemy.position = Vector2(800, 512)
	
	enemy.z_front = max(next_z_index, z_front_min)
	next_z_index -= 1
	enemy_container.add_child(enemy)

	current_enemy_count += 1

	# Jika enemy mati, kurangi counter (di script enemy)
	enemy.connect("tree_exited", Callable(self, "_on_enemy_removed"))


func _process(delta):
	if damage_hud_timer > 0.0:
		damage_hud_timer -= delta
		if damage_hud_timer <= 0.0:
			damaged_hud.visible = false

	update_screen_shake(delta)

	# update timer
	spawn_timer += delta

	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		spawn_batch_enemies()

func spawn_batch_enemies():
	for i in spawn_batch:
		if current_enemy_count >= max_enemies:
			break  # Jangan spawn lebih dari max
		spawn_enemy()
		
func _on_enemy_removed():
	current_enemy_count = max(current_enemy_count - 1, 0)

func _on_player_hp_changed(old_hp: int, new_hp: int):
	if new_hp >= old_hp:
		return

	damaged_hud.visible = true
	damage_hud_timer = damage_hud_duration
	trigger_screen_shake()

func trigger_screen_shake():
	screen_shake_timer = screen_shake_duration

func update_screen_shake(delta: float):
	if screen_shake_timer <= 0.0:
		position = base_position
		return

	screen_shake_timer -= delta
	var progress := clampf(screen_shake_timer / max(screen_shake_duration, 0.001), 0.0, 1.0)
	var strength := screen_shake_strength * progress
	position = base_position + Vector2(
		randf_range(-strength, strength),
		randf_range(-strength, strength)
	)

	if screen_shake_timer <= 0.0:
		position = base_position
