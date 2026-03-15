extends Control

@onready var message_list = $MessageList

const LevelCard = preload("res://scenes/level_chat.tscn")
const NpcBubble = preload("res://scenes/level_chat_yuna.tscn")

const GAP = 4
var is_animating: bool = false

const TINGGI_LAYAR = 600  # sesuaikan dengan tinggi area layar HP kamu dalam pixel

const TINGGI_CARD = 554
const TINGGI_BUBBLE = 254

var current_y = 0  # nanti sesuaikan dengan posisi awal MessageList di editor

func _ready():
    current_y = message_list.position.y

func tambah_chat(data: Dictionary):
    if is_animating:
        return
    
    is_animating = true
    
    var card = LevelCard.instantiate()
    message_list.add_child(card)
    card.setup(data)
    
    await get_tree().process_frame
    current_y -= TINGGI_CARD
    _pindah_ke(current_y)
    
    await get_tree().create_timer(0.6).timeout
    var bubble = NpcBubble.instantiate()
    message_list.add_child(bubble)
    bubble.setup(data)
    
    await get_tree().process_frame
    current_y -= TINGGI_BUBBLE
    _pindah_ke(current_y)
    
    is_animating = false

func _pindah_ke(target_y: float):
    var tween = create_tween()
    tween.tween_property(
        message_list,
        "position:y",
        target_y,
        0.3
    ).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
    
#func tambah_chat(data: Dictionary):
    #if is_animating:
        #return
    #
    #is_animating = true
    #
    #var card = LevelCard.instantiate()
    #message_list.add_child(card)
    #card.setup(data)
    #
    #await get_tree().process_frame
    #_scroll_ke_atas(TINGGI_LAYAR)  
    #
    #await get_tree().create_timer(0.6).timeout
    #var bubble = NpcBubble.instantiate()
    #message_list.add_child(bubble)
    #bubble.setup(data)
    #
    #await get_tree().process_frame
    #_scroll_ke_atas(bubble.size.y)  
    #
    #is_animating = false
    #
func _scroll_ke_atas(tinggi_baru: float):
    var tween = create_tween()
    tween.tween_property(
        message_list,
        "position:y",
        message_list.position.y - tinggi_baru,
        0.3
    ).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
