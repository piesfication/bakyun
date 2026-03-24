extends Node2D

signal travel_finished

@export var speed: float = 560.0
@export var min_duration: float = 0.05
@export var projectile_scale: Vector2 = Vector2(1.2, 0.36)
@export var projectile_color: Color = Color(0.52, 0.74, 1.0, 0.96)
@export var z_order: int = 1150

@onready var visual: Sprite2D = $Visual

func _ready() -> void:
	z_index = z_order
	_setup_visual()


func play_between(start_pos: Vector2, end_pos: Vector2) -> void:
	global_position = start_pos

	var travel := end_pos - start_pos
	if travel.length_squared() > 0.001:
		rotation = travel.angle()

	var distance := start_pos.distance_to(end_pos)
	var duration := maxf(distance / maxf(speed, 1.0), min_duration)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", end_pos, duration)
	await tween.finished

	emit_signal("travel_finished")
	queue_free()


func _setup_visual() -> void:
	if visual == null:
		return

	visual.scale = projectile_scale
	visual.modulate = projectile_color

	if visual.texture == null:
		visual.texture = _create_placeholder_texture()


func _create_placeholder_texture() -> ImageTexture:
	var image := Image.create(56, 12, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)
