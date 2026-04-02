extends Node

@onready var player = $AudioStreamPlayer

func _ready() :
	player.volume_db = -30

func play_music(stream: AudioStream):
	if player == null:
		print("Player not found!")
		return

	if player.stream == stream and player.playing:
		return
	
	player.stream = stream
	player.play()

func stop_music():
	player.stop()
