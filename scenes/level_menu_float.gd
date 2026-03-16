extends Control

@export var phone_node_path: NodePath = NodePath("Phone")
@export var icon_container_path: NodePath = NodePath("IconFollowControl")
@export var background_node_path: NodePath = NodePath("Background")
@export var map_manager_node_path: NodePath = NodePath("MapManager")

@export var phone_float_amplitude: float = 6.0
@export var icon_float_amplitude: float = 8.0
@export var background_float_amplitude: float = 4.0
@export var map_manager_float_amplitude: float = 5.0
@export var float_speed: float = 1.2
@export var background_map_float_speed: float = 0.5
@export var icon_phase_offset: float = 0.6
@export var background_phase_offset: float = 0.25
@export var map_manager_phase_offset: float = 1.0

var _phone_node: Control
var _icon_container: Control
var _background_node: Node2D
var _map_manager_node: Control
var _phone_base_position: Vector2
var _icon_base_position: Vector2
var _background_base_position: Vector2
var _map_manager_base_position: Vector2

func _ready():
	_phone_node = get_node_or_null(phone_node_path) as Control
	_icon_container = get_node_or_null(icon_container_path) as Control
	_background_node = get_node_or_null(background_node_path) as Node2D
	_map_manager_node = get_node_or_null(map_manager_node_path) as Control

	if _phone_node != null:
		_phone_base_position = _phone_node.position
	if _icon_container != null:
		_icon_base_position = _icon_container.position
	if _background_node != null:
		_background_base_position = _background_node.position
	if _map_manager_node != null:
		_map_manager_base_position = _map_manager_node.position

func _process(_delta: float):
	var t = Time.get_ticks_msec() * 0.001
	if _phone_node != null:
		_phone_node.position = _phone_base_position + Vector2(0.0, sin(t * float_speed) * phone_float_amplitude)
	if _icon_container != null:
		_icon_container.position = _icon_base_position + Vector2(0.0, sin(t * float_speed + icon_phase_offset) * icon_float_amplitude)
	if _background_node != null:
		_background_node.position = _background_base_position + Vector2(0.0, sin(t * background_map_float_speed + background_phase_offset) * background_float_amplitude)
	if _map_manager_node != null:
		_map_manager_node.position = _map_manager_base_position + Vector2(0.0, sin(t * background_map_float_speed + map_manager_phase_offset) * map_manager_float_amplitude)
