extends Node2D

@export var speed := 2
var time := 0.0

@onready var back := $Sky
@onready var grass := $Grass

var base_pos := {}

func _ready():
	base_pos[back] = back.position
	base_pos[grass] = grass.position

func _process(delta):
	time += delta * speed
	back.position.y = base_pos[back].y + sin(time * 1) * 15
	grass.position.y = base_pos[back].y + sin(time * 1) * 10
	grass.position.x = base_pos[back].x + sin(time * 1) * 15
