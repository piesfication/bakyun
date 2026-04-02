
extends Area2D
@export var background_top_z: int = 30
var first_hit_enemy: Node = null

@export var speed: float = 3500.0
@export var max_distance: float = 1200.0
var max_scale_proyektil := 0.4
var max_distance_default := 1200.0
var scale_proyektil := 1.0
@export var hit_radius: float = 26.0
@export var damage: int = 1
@export var max_depth_difference: float = 0.3
@export var projectile_scale: Vector2 = Vector2(0.25,0.25)
@export var projectile_color: Color = Color(1.0, 0.48, 0.55, 0.92)

@onready var visual: AnimatedSprite2D = $Visual

var direction: Vector2 = Vector2.ZERO
var traveled_distance: float = 0.0
var ignored_enemy: Node = null
var hit_enemies: Array[Node] = []
var source_depth_plane: float = 0.5



func _ready() -> void:
	monitoring = false
	monitorable = false
	z_index = 1100
	setup_visual()
	if visual != null:
		visual.animation = "launch"
		visual.play()
		visual.connect("animation_finished", Callable(self, "_on_visual_animation_finished"))
func _on_visual_animation_finished() -> void:
	if visual.animation == "launch":
		visual.animation = "travel"
		visual.play()


func _physics_process(delta: float) -> void:
	if direction == Vector2.ZERO:
		queue_free()
		return

	var move_step: float = speed * delta
	global_position += direction * move_step
	traveled_distance += move_step
	rotation = direction.angle()

	# Setelah terkena musuh, z_index proyektil tetap seperti saat pertama kena

	deal_damage_on_overlap()

	if traveled_distance >= max_distance:
		queue_free()


func setup(start_pos: Vector2, move_direction: Vector2, source_enemy: Node = null, source_depth: float = 0.5) -> void:
	global_position = start_pos
	direction = move_direction.normalized()
	ignored_enemy = source_enemy
	source_depth_plane = source_depth
	traveled_distance = 0.0
	hit_enemies.clear()


func _extract_enemy_depth(enemy: Node) -> Variant:
	if enemy == null or not is_instance_valid(enemy):
		return null

	for prop in enemy.get_property_list():
		if String(prop.get("name", "")) == "depth":
			return enemy.get("depth")

	return null


func setup_visual() -> void:
	if visual == null:
		return

	visual.scale = projectile_scale
	visual.modulate = projectile_color
	# AnimatedSprite2D tidak punya property 'texture', jadi tidak perlu create_placeholder_texture


func create_placeholder_texture() -> ImageTexture:
	var image := Image.create(56, 12, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)


func deal_damage_on_overlap() -> void:
	var circle := CircleShape2D.new()
	circle.radius = hit_radius

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, global_position)
	query.collide_with_areas = true
	query.collision_mask = 1 << 1

	var results := get_world_2d().direct_space_state.intersect_shape(query)
	# Kumpulkan semua musuh valid
	var enemy_hits := []
	for result in results:
		var hit_area: Variant = result.get("collider")
		if not (hit_area is Area2D):
			continue
		var enemy: Node = hit_area.get_parent()
		if enemy == null or enemy == ignored_enemy:
			continue
		if hit_enemies.has(enemy):
			continue
		if not enemy.has_method("apply_damage"):
			continue
		var enemy_depth: Variant = _extract_enemy_depth(enemy)
		if enemy_depth != null:
			if absf(float(enemy_depth) - source_depth_plane) > max_depth_difference:
				continue
		var enemy_z := 0
		if "z_index" in enemy:
			enemy_z = enemy.z_index
		enemy_hits.append({"enemy": enemy, "z": enemy_z})

	# Urutkan musuh berdasarkan z_index menurun (paling depan dulu)
	enemy_hits.sort_custom(func(a, b): return b["z"] - a["z"])

	for hit in enemy_hits:
		var enemy = hit["enemy"]
		# Samakan z_index projectile dengan z_index musuh yang kena
		var new_z_index = z_index
		if "z_index" in enemy:
			new_z_index = enemy.z_index
		# Simpan reference ke musuh pertama yang kena
		if first_hit_enemy == null:
			first_hit_enemy = enemy

		# Scale proyektil proporsional: scale = scale_lawan * 0.8 (maksimal)
		var enemy_scale := Vector2.ONE
		if "scale" in enemy:
			enemy_scale = enemy.scale
		elif enemy.has_method("get_scale"):
			enemy_scale = enemy.get_scale()
		var scale_val = max_scale_proyektil * (enemy_scale.x / 0.3)
		scale_val = min(scale_val, max_scale_proyektil)
		scale_proyektil = scale_val
		# Update max_distance proporsional terhadap scale
		max_distance = max_distance_default * (scale_proyektil / max_scale_proyektil)

		# Sinkronkan ke semua proyektil aktif
		var parent = get_parent()
		if parent:
			for child in parent.get_children():
				if child != self and child.has_method("set_projectile_visual_sync"):
					child.set_projectile_visual_sync(new_z_index, scale_val)
		# Set untuk diri sendiri
		z_index = new_z_index
		visual.scale = Vector2.ONE * scale_val

		hit_enemies.append(enemy)
		enemy.apply_damage(damage)

func set_projectile_visual_sync(new_z_index: int, scale_val: float) -> void:
	z_index = new_z_index
	visual.scale = Vector2.ONE * scale_val
