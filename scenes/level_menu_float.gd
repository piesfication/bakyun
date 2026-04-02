extends Control

@export var phone_node_path: NodePath = NodePath("Phone")
@export var background_node_path: NodePath = NodePath("Background")
@export var map_manager_node_path: NodePath = NodePath("MapManager")

@export var phone_float_amplitude: float = 6.0
@export var background_float_amplitude: float = 4.0
@export var phone_float_speed: float = 1.2
@export var background_float_speed: float = 0.5
@export var background_phase_offset: float = 0.25
@export_range(0.0, 1.0, 0.01) var background_scale_padding: float = 0.06

var _phone_node: Control
var _background_node: Node2D
var _map_manager_node: Control
var _phone_base_position: Vector2
var _background_base_position: Vector2
var _map_manager_base_position: Vector2
var _background_base_scale: Vector2

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_phone_node = get_node_or_null(phone_node_path) as Control
	_background_node = get_node_or_null(background_node_path) as Node2D
	_map_manager_node = get_node_or_null(map_manager_node_path) as Control

	if _phone_node != null:
		_phone_base_position = _phone_node.position
	if _background_node != null:
		_background_base_position = _background_node.position
		_background_base_scale = _background_node.scale
		var scale_mul := 1.0 + maxf(background_scale_padding, 0.0)
		_background_node.scale = _background_base_scale * scale_mul
	if _map_manager_node != null:
		_map_manager_base_position = _map_manager_node.position

func _process(_delta: float):
	var t = Time.get_ticks_msec() * 0.001
	if _phone_node != null:
		_phone_node.position = _phone_base_position + Vector2(0.0, sin(t * phone_float_speed) * phone_float_amplitude)
	if _background_node != null:
		var bg_float_y := sin(t * background_float_speed + background_phase_offset) * background_float_amplitude
		_background_node.position = _background_base_position + Vector2(0.0, bg_float_y)
		if _map_manager_node != null:
			_map_manager_node.position = _map_manager_base_position + Vector2(0.0, bg_float_y)
