extends Node2D
signal travel_finished

@export var speed: float = 560.0
@export var min_duration: float = 0.05
@export var projectile_scale: Vector2 = Vector2(1, 1) * 0.3
@export var z_order: int = 1150
@export var animation_name: String = "default"  # ganti sesuai nama animasi di SpriteFrames

var _target_visual_scale: Vector2 = Vector2.ZERO
var _start_visual_scale: Vector2 = Vector2.ZERO
var _target_z: int = 0
var _start_z: int = 0
var _is_travelling: bool = false
var _travel_duration: float = 0.0
var _travel_elapsed: float = 0.0

@onready var visual: AnimatedSprite2D = $Visual

func _ready() -> void:
	z_index = z_order
	_setup_visual()
	
var _target_node: Node2D = null

func play_between(start_pos: Vector2, target_node: Node2D) -> void:
	_target_node = target_node
	global_position = start_pos
	
	_start_visual_scale = projectile_scale
	_start_z = z_index
	_is_travelling = true
	_travel_elapsed = 0.0
	
	var distance := start_pos.distance_to(target_node.global_position)
	_travel_duration = maxf(distance / maxf(speed, 1.0), min_duration)
	
	await _reach_target()
	
	_is_travelling = false
	emit_signal("travel_finished")
	queue_free()
	
func _reach_target() -> void:
	while is_instance_valid(_target_node):
		var to_target := _target_node.global_position - global_position
		if to_target.length() < 8.0:  # threshold sampai
			break
		rotation = to_target.angle()
		await get_tree().process_frame

func _process(delta: float) -> void:
	if not _is_travelling:
		return
	
	# update interpolasi scale & z
	_travel_elapsed += delta
	var t := clampf(_travel_elapsed / _travel_duration, 0.0, 1.0)
	if _target_visual_scale != Vector2.ZERO:
		visual.scale = _start_visual_scale.lerp(_target_visual_scale, t)
	z_index = roundi(lerpf(float(_start_z), float(_target_z), t))
	
	# gerak homing
	if _target_node != null and is_instance_valid(_target_node):
		var to_target := _target_node.global_position - global_position
		global_position += to_target.normalized() * speed * delta

func set_interpolation_targets(target_scale: Vector2, target_z: int) -> void:
	_start_visual_scale = projectile_scale  # ← ambil dari export, bukan visual.scale
	_start_z = z_order                      # ← ambil dari export juga
	_target_visual_scale = target_scale
	_target_z = target_z
	
func _setup_visual() -> void:
	if visual == null:
		return
	visual.scale = projectile_scale
	visual.play("travel")  
