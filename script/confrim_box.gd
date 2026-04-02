extends Control

signal confirmed
signal canceled

func _ready():
	print("CONFIRMATION BOX READY")
	
func _on_button_pressed() -> void:
	print("nonono")
	emit_signal("canceled")
	
func _on_button_2_pressed() -> void:
	print("yesyesyes")
	emit_signal("confirmed")
