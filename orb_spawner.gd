extends Node2D

enum Pattern {
	RANDOM,
	LINE_H,
	LINE_V,
	ARC,
	CIRCLE,
	V_SHAPE,
	DIAMOND,
}

@export var target_scene: PackedScene
@export var randomize_pattern: bool = true
@export var forced_pattern: Pattern = Pattern.LINE_H
@export var min_count: int = 3
@export var max_count: int = 6
@export var formation_spacing: float = 80.0
@export var random_radius: float = 200.0
@export var auto_spawn: bool = false
@export var batch_interval: float = 5.0
@export var spawn_stagger: float = 0.4
@export var base_z_index: int = 50  # z order dasar orb, harus lebih tinggi dari boss

var _batch_timer: float = 0.0
var _is_spawning: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var player_node: Node2D

func _ready() -> void:
	_rng.randomize()
	player_node = _find_player()
	if auto_spawn:
		_spawn_batch()

func _process(delta: float) -> void:
	if not auto_spawn:
		return
	_batch_timer += delta
	if _batch_timer >= batch_interval:
		_batch_timer = 0.0
		_spawn_batch()

func spawn_batch(count: int, pattern: int) -> void:
	if _is_spawning:
		return
	if target_scene == null:
		push_error("Spawner: target_scene belum di-assign!")
		return
	if player_node == null or not is_instance_valid(player_node):
		player_node = _find_player()

	_is_spawning = true
	var batch_seed := _rng.randi()
	var offsets := _generate_offsets(pattern, count)

	for i in count:
		var t: Node2D = target_scene.instantiate()
		t.set("batch_seed", batch_seed)
		t.set("player_node", player_node)
		t.set("time_offset", i * spawn_stagger)
		# Orb pertama z order tertinggi, makin belakang makin rendah
		t.z_index = base_z_index - i
		get_tree().current_scene.add_child(t)
		t.global_position = global_position
		t.set("drift_origin", global_position)
		t.z_index = 100

	_is_spawning = false

func _spawn_batch() -> void:
	var count := _rng.randi_range(min_count, max_count)
	var pattern := _pick_pattern()
	spawn_batch(count, pattern)

func _pick_pattern() -> Pattern:
	if not randomize_pattern:
		return forced_pattern
	return _rng.randi_range(0, Pattern.size() - 1) as Pattern

func _generate_offsets(pattern: Pattern, count: int) -> Array[Vector2]:
	var offsets: Array[Vector2] = []
	var s := formation_spacing

	match pattern:
		Pattern.RANDOM:
			for i in count:
				var angle := _rng.randf() * TAU
				var dist := _rng.randf_range(0.0, random_radius)
				offsets.append(Vector2(cos(angle), sin(angle)) * dist)
		Pattern.LINE_H:
			var total_width := s * (count - 1)
			for i in count:
				offsets.append(Vector2(i * s - total_width * 0.5, 0.0))
		Pattern.LINE_V:
			var total_height := s * (count - 1)
			for i in count:
				offsets.append(Vector2(0.0, i * s - total_height * 0.5))
		Pattern.ARC:
			var radius := s * count / PI
			for i in count:
				var t_val := float(i) / float(count - 1) if count > 1 else 0.5
				var angle := lerpf(0.0, PI, t_val)
				offsets.append(Vector2(cos(angle) * radius, sin(angle) * radius * 0.5))
		Pattern.CIRCLE:
			var radius := s * count / TAU
			for i in count:
				var angle := (float(i) / float(count)) * TAU
				offsets.append(Vector2(cos(angle), sin(angle)) * radius)
		Pattern.V_SHAPE:
			var half := count / 2
			for i in count:
				if i < half:
					var step := half - i
					offsets.append(Vector2(-step * s * 0.8, -step * s * 0.5))
				else:
					var step := i - half
					offsets.append(Vector2(step * s * 0.8, -step * s * 0.5))
		Pattern.DIAMOND:
			if count <= 4:
				var dirs: Array[Vector2] = [
					Vector2(0, -1), Vector2(1, 0),
					Vector2(0, 1), Vector2(-1, 0)
				]
				for i in count:
					offsets.append(dirs[i] * s)
			else:
				var corners: Array[Vector2] = [
					Vector2(0, -s), Vector2(s, 0),
					Vector2(0, s), Vector2(-s, 0),
				]
				var sides := 4
				var per_side := count / sides
				for side in sides:
					var a := corners[side]
					var b := corners[(side + 1) % sides]
					for j in per_side:
						var tt := float(j) / float(per_side)
						offsets.append(a.lerp(b, tt))

	return offsets

func _find_player() -> Node2D:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.find_child("Player", true, false) as Node2D
