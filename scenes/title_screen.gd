extends Node2D

@export_range(0.0, 100.0, 0.1) var ba_float_amplitude: float = 12.0
@export_range(0.0, 100.0, 0.1) var kyun_float_amplitude: float = 12.0
@export_range(0.1, 10.0, 0.01) var float_speed: float = 1.6
@export_range(0.0, TAU, 0.01) var phase_offset: float = PI * 0.65

@onready var ba: AnimatedSprite2D = $CanvasLayer2/Title/Ba
@onready var kyun: AnimatedSprite2D = $CanvasLayer2/Title/Kyun

var _time_accum: float = 0.0
var _ba_base_position: Vector2
var _kyun_base_position: Vector2

func _ready() -> void:
	_ba_base_position = ba.position
	_kyun_base_position = kyun.position


func _process(delta: float) -> void:
	_time_accum += delta
	ba.position.y = _ba_base_position.y + sin(_time_accum * float_speed) * ba_float_amplitude
	kyun.position.y = _kyun_base_position.y + sin(_time_accum * float_speed + phase_offset) * kyun_float_amplitude
