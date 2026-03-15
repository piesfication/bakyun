extends Node2D

signal hp_changed(old_hp: int, new_hp: int)
signal character_switched(character_name: String)

@export var max_hp := 30
var current_hp := max_hp

@onready var baku := $BakuMahou
@onready var yuna := $YunaMahou

var current_weapon: Node2D


func _ready():
	current_hp = max_hp

	baku.visible = true
	yuna.visible = false
	current_weapon = baku
	
	emit_signal("character_switched", get_current_character_name())


func _input(event):
	if event.is_action_pressed("switch"):
		switch_weapon()

func switch_weapon():
	current_weapon.visible = false

	if current_weapon == baku:
		current_weapon = yuna
	else:
		current_weapon = baku

	current_weapon.visible = true
	emit_signal("character_switched", get_current_character_name())


func get_current_character_name() -> String:
	if current_weapon == yuna:
		return "yuna"
	return "baku"


# ===== HP TETAP =====
func take_damage(amount: int):
	if amount <= 0:
		return

	var old_hp := current_hp
	current_hp = clamp(current_hp - amount, 0, max_hp)

	if current_hp != old_hp:
		emit_signal("hp_changed", old_hp, current_hp)

	print("Player HP:", current_hp)

	if current_hp <= 0:
		die()


func die():
	print("GAME OVER")
	get_tree().paused = true
