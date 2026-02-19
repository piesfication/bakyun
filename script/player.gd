extends Node2D

@export var max_hp := 3
var current_hp := max_hp

@onready var baku := $BakuMahou
@onready var yuna := $YunaMahou

var current_weapon: Node2D


func _ready():
	current_hp = max_hp

	baku.visible = true
	yuna.visible = false
	current_weapon = baku


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


# ===== HP TETAP =====
func take_damage(amount: int):
	current_hp -= amount
	print("Player HP:", current_hp)

	if current_hp <= 0:
		die()


func die():
	print("GAME OVER")
	get_tree().paused = true
