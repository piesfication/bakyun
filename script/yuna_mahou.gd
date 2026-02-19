extends Node2D

@export var move_range := Vector2(40, 25) * 5 # batas gerak senjata
@export var smooth := 0.12

var base_pos: Vector2


func _ready():
	base_pos = position


func _process(delta):
	var viewport_size = get_viewport_rect().size
	var screen_center = viewport_size * 0.5

	var mouse_pos = get_viewport().get_mouse_position()

	# 1. hitung jarak mouse dari tengah layar
	var offset = mouse_pos - screen_center

	# 2. normalisasi ke -1 .. 1
	var normalized = Vector2(
		offset.x / (viewport_size.x * 0.5),
		offset.y / (viewport_size.y * 0.5)
	)
	normalized = normalized.clamp(Vector2(-1, -1), Vector2(1, 1))

	# 3. gerak proporsional + dibatasi
	var target_pos = base_pos + Vector2(
		normalized.x * move_range.x,
		normalized.y * move_range.y
	)

	# 4. halusin
	position = position.lerp(target_pos, smooth)
