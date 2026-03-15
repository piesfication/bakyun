extends Node2D

signal icon_clicked(icon)

var level_data: Dictionary
var is_active: bool = false

@onready var anim = $AnimatedSprite2D

func activate(data: Dictionary):
    level_data = data
    is_active = true
    visible = true
    anim.play("popup")
    await anim.animation_finished
    anim.play("idle")

func deactivate():
    is_active = false
    visible = false

var is_selected: bool = false

func on_selected():
    is_selected = true
    anim.play("clicked")
    await anim.animation_finished
    anim.play("idle_after_clicked")

func on_deselected():
    is_selected = false
    anim.play("return_to_idle")
    await anim.animation_finished
    anim.play("idle")
    

func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
    if event is InputEventMouseButton and event.pressed and is_active and not is_selected:
        icon_clicked.emit(self)
        
