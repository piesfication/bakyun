extends CanvasLayer

@export_range(0.0, 100.0, 0.1) var bak_float_amplitude: float = 6.0
@export_range(0.0, 100.0, 0.1) var yun_float_amplitude: float = 6.0
@export_range(0.0, 100.0, 0.1) var con_float_amplitude: float = 6.0

var _time_accum: float = 0.0

@export_range(0.1, 10.0, 0.01) var float_speed: float = 1.6
@export_range(0.0, TAU, 0.01) var phase_offset: float = PI * 0.65

@onready var bakprofile:= $BakuProfile
@onready var yunprofile:= $YunaProfile

@onready var con:= $ConfrimBox
@onready var overlay:= $Overlay

var _bak_base_position: Vector2
var _yun_base_position: Vector2
var _con_base_position: Vector2

func _ready() -> void:
	
	con.connect("confirmed", _on_confirmed)
	con.connect("canceled", _on_canceled)
	
	_bak_base_position = bakprofile.position
	_yun_base_position = yunprofile.position
	_con_base_position = con.position

func _process(delta: float) -> void:
	_time_accum += delta
	bakprofile.position.y = _bak_base_position.y + sin(_time_accum * float_speed) * bak_float_amplitude
	yunprofile.position.y = _yun_base_position.y + sin(_time_accum * float_speed) * yun_float_amplitude
	con.position.y = _con_base_position.y + sin(_time_accum * float_speed) * con_float_amplitude


func _on_confirmed():
	
	await Transition.fade_out()  
	get_tree().quit()

func _on_canceled():
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	tween.tween_property(con, "modulate:a", 0.0, 0.25)
	tween.parallel().tween_property(overlay, "modulate:a", 0.0, 0.25)
	
	# shrink tapi tetap >= 0.68 (biar sesuai rule kamu)
	tween.parallel().tween_property(con, "scale", Vector2(0.75, 0.75), 0.1)
	tween.parallel().tween_property(con, "scale", Vector2(0.67, 0.67), 0.25)
	
	tween.tween_callback(func():
		con.visible = false
		overlay.visible = false
	)
