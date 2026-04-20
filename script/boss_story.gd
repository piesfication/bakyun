extends Node2D

@export var flap_amplitude: float = 20.0
@export var flap_frequency: float = 1.1

var flap_time = 0.0

var start_pos = Vector2(632, 0)
var end_pos = Vector2(632, 285)

var min_scale = 0.1
var max_scale = 0.2

var speed = 0.2
var t = 0.0

var state = "waiting"
var idle_time = 0.0

@onready var sprite = $AnimatedSprite2D
@onready var sprite2 = $AnimatedSprite2D/BotAnim
@onready var sprite3 = $AnimatedSprite2D/TopAnim
@onready var sprite4 = $AnimatedSprite2D/MidAnim

func _ready() -> void:
	global_position = start_pos
	scale = Vector2(min_scale, min_scale)  # 
	Dialogic.signal_event.connect(on_dialogic_signal)

func trigger_move():
	state = "moving"
	t = 0.0

func _process(delta):
	flap_time += delta

	var base_pos: Vector2

	if state == "waiting":
		base_pos = start_pos
		scale = Vector2(min_scale, min_scale)

	# 🔹 MOVING
	elif state == "moving":
		t += speed * delta
		t = clamp(t, 0, 1)

		base_pos = start_pos.lerp(end_pos, t)

		var s = lerp(min_scale, max_scale, t)
		scale = Vector2(s, s)

		if t >= 1.0:
			state = "idle"
			idle_time = 0.0

	# 🔹 IDLE (SETELAH SAMPAI)
	elif state == "idle":
		idle_time += delta

		var offset_x = sin(idle_time * 2.0) * 10
		base_pos = end_pos + Vector2(offset_x, 0)
		
		if offset_x > 0:
			sprite.flip_h = false  # ke kanan
			sprite2.flip_h = false 
			sprite3.flip_h = false 
			sprite4.flip_h = false 
		else:
			sprite.flip_h = true   # ke kiri   :     
			sprite2.flip_h = true 
			sprite3.flip_h = true 
			sprite4.flip_h = true 

	# 🔹 FLAP
	var flap_y = sin(flap_time * flap_frequency * TAU) * flap_amplitude

	position = base_pos + Vector2(0, flap_y)

func on_dialogic_signal(arg: String):
	
	if arg == "boss entrance":
		trigger_move()
	
