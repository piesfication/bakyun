extends Node2D

@export var flap_amplitude: float = 30.0
@export var flap_frequency: float = 1.2

var _flap_time: float = 0.0
var _prev_flap_y: float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	_flap_time += delta
	var flap_y := sin(_flap_time * flap_frequency * TAU) * flap_amplitude
	global_position.y += flap_y - _prev_flap_y
	_prev_flap_y = flap_y
