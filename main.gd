extends Node2D

@export var enemy_scene: PackedScene
@onready var enemy_container = $EnemyContainer

@export var max_enemies: int = 20        # Maksimal enemy yang bisa ada sekaligus
@export var spawn_interval: float = 2.0  # Detik per spawn
@export var spawn_batch: int = 1         # Berapa banyak musuh spawn sekaligus

var current_enemy_count: int = 0
var spawn_timer := 0.0

@export var base_z_index: int = 100
@export var z_front_min: int = 40
var next_z_index: int

func _ready():
	next_z_index = base_z_index

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
