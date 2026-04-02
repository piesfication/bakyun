extends Area2D

@onready var overlay = $"../Overlay"
@onready var confirmation = $"../ConfrimBox"

var _clicked := false
@onready var con := $"../ConfrimBox"

func _ready():
	con.connect("canceled", _on_canceled)
	
func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
		if _clicked:
			return
		if event is InputEventMouseButton and event.pressed:
			_clicked = true
			show_confirmation()
			
func show_confirmation():
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Overlay fade
	confirmation.visible = true
	overlay.visible = true
	
	tween.tween_property(overlay, "modulate:a", 1.0, 0.1)
	
	tween.parallel().tween_property(confirmation, "modulate:a", 1.0, 0.1)

	tween.parallel().tween_property(confirmation, "scale", Vector2(0.75, 0.75), 0.1)
	
	tween.tween_property(confirmation, "scale", Vector2(0.67, 0.67), 0.15)

func _on_canceled():
	_clicked = false
