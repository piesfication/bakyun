extends Control

@onready var yuna_label = $Message

func setup(data: Dictionary):
	yuna_label.text = data.line_yuna
