extends Control

@onready var chat_area =$"../CanvasLayer/Phone/PhoneSprite/Screen/TextureRect/ChatArea"
@onready var icons = get_children()  # ambil semua LevelIcon

var active_icons: Array = []
var selected_icon = null
@export_range(0.0, 1.0, 0.01, "suffix:s") var icon_stagger_delay: float = 0.08

func _ready():
	print(get_parent().get_children())
	
	for icon in icons:
		icon.visible = false
		
	await get_tree().create_timer(0.2).timeout
	await _generate_level_icons()


func _generate_level_icons() -> void:
	# Sembunyikan semua dulu
	for icon in icons:
		icon.deactivate()

	selected_icon = null
	
	# Pilih 3 random dari 6
	var shuffled = icons.duplicate()
	shuffled.shuffle()
	active_icons = shuffled.slice(0, 3)
	
	# Assign level data dan aktifkan
	var easy = LevelData.get_random_level("easy")
	var medium = LevelData.get_random_level("medium")
	var hard = LevelData.get_random_level("hard")
	var difficulties = [easy, medium, hard]
	difficulties.shuffle()
	
	for i in 3:
		var icon = active_icons[i]
		await icon.activate(difficulties[i])
		if not icon.icon_clicked.is_connected(_on_icon_clicked):
			icon.icon_clicked.connect(_on_icon_clicked)
		if i < 2 and icon_stagger_delay > 0.0:
			await get_tree().create_timer(icon_stagger_delay).timeout
		
func _on_icon_clicked(icon):
	if chat_area.is_animating:
		return
	if selected_icon == icon:
		return  # klik level yang sama, ignore
	
	if selected_icon != null:
		selected_icon.on_deselected()
	
	selected_icon = icon
	icon.on_selected()
	chat_area.tambah_chat(icon.level_data)
