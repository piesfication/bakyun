extends Area2D

@export var speed: float = 900.0
@export var max_distance: float = 620.0
@export var hit_radius: float = 26.0
@export var damage: int = 1
@export var max_depth_difference: float = 0.3
@export var projectile_scale: Vector2 = Vector2(0.65, 0.2)
@export var projectile_color: Color = Color(1.0, 0.48, 0.55, 0.92)

@onready var visual: Sprite2D = $Visual

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


func _physics_process(delta: float) -> void:
	if direction == Vector2.ZERO:
		queue_free()
		return

	var move_step: float = speed * delta
	global_position += direction * move_step
	traveled_distance += move_step
	rotation = direction.angle()

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

	if visual.texture == null:
		visual.texture = create_placeholder_texture()


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

		hit_enemies.append(enemy)
		enemy.apply_damage(damage)
