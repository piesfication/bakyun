extends Node2D

@export var speed := 2
var time := 0.0

@onready var back := $Back
@onready var back2 := $Back2
@onready var front := $Front
@onready var sea := $Sea

var base_pos := {}

func _ready():
	base_pos[back] = back.position
	base_pos[back2] = back2.position
	base_pos[front] = front.position
	base_pos[sea] = sea.position

func _process(delta):
	time += delta * speed
	back.position.y = base_pos[back].y + sin(time * 1) * 5
	back2.position.y = base_pos[back2].y + sin(time * 1) * 5
	front.position.y = base_pos[front].y + sin(time * 1) * 5
	sea.position.y = base_pos[sea].y + sin(time * 1.5) * 5
