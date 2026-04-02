extends Area2D

var is_profile_open = false
var current_profile: Node2D = null

@onready var overlay := $"../../../CanvasLayer3/Overlay"
@onready var bakuprofile := $"../../../CanvasLayer3/BakuProfile"
@onready var yunaprofile := $"../../../CanvasLayer3/YunaProfile"

func _ready():
	# Pastikan overlay bisa detect klik
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	overlay.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			hide_profile()
	)

func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
		show_profile_smooth(yunaprofile)
		
		bakuprofile.visible = false

func show_profile_smooth(node: Node2D):
	is_profile_open = true
	current_profile = node
	
	node.visible = true
	overlay.visible = true
	
	# Start di minimum kamu
	node.modulate.a = 0.0
	node.scale = Vector2(0.67, 0.67)
	overlay.modulate.a = 0.0

	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Overlay fade
	tween.tween_property(overlay, "modulate:a", 1.0, 0.1)
	
	# Fade profile
	tween.parallel().tween_property(node, "modulate:a", 1.0, 0.1)
	
	# 🔥 Overshoot lebih jauh biar keliatan
	tween.parallel().tween_property(node, "scale", Vector2(0.75, 0.75), 0.1)
	
	# Balik ke normal
	tween.tween_property(node, "scale", Vector2(0.68, 0.68), 0.15)
	
func hide_profile():
	if not is_profile_open:
		return
		
	is_profile_open = false
	
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	tween.tween_property(current_profile, "modulate:a", 0.0, 0.25)
	tween.parallel().tween_property(overlay, "modulate:a", 0.0, 0.25)
	
	# shrink tapi tetap >= 0.68 (biar sesuai rule kamu)
	tween.parallel().tween_property(current_profile, "scale", Vector2(0.68, 0.68), 0.25)
	
	tween.tween_callback(func():
		current_profile.visible = false
		overlay.visible = false
		current_profile = null
	)
