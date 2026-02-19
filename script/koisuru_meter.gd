extends Control

enum HeartState {
	DEFAULT_BROKEN,
	DEFAULT_FULL,
	FILLING,
	FULL
}

@onready var ultcast_anim := $UltimateAnim
@onready var koisuru_meter := $Container/Control

enum RPointerState {
	DEFAULT, FILL, FULL, BLINK
}

enum LPointerState {
	DEFAULT, FILL, FULL, BLINK
}

var hstate := HeartState.DEFAULT_BROKEN
var rpstate := RPointerState.DEFAULT
var lpstate := LPointerState.DEFAULT


# Called when the node enters the scene tree for the first time.
@onready var left_follow  := $Container/Control/PathLeft/PathFollow2D
@onready var right_follow := $Container/Control/PathRight/PathFollow2D

@onready var heart := $Container/MidContainer/HeartSprite

@onready var right_pointer := $Container/Control/PathRight/PathFollow2D/PointerRightContainer/RightSprite
@onready var left_pointer := $Container/Control/PathLeft/PathFollow2D/PointerLeftContainer2/LeftSprite

func _ready():
	ultcast_anim.visible = false

var left_step := 0
var right_step := 0

const STEPS := 2
const STEP_SIZE := 1.0 / STEPS

func update_heart_visual():
	
	match hstate:
		HeartState.DEFAULT_BROKEN:
			heart.play("default_broken")
		HeartState.DEFAULT_FULL:
			
			ultcast_anim.visible = true
			koisuru_meter.visible = false
			
			ultcast_anim.play("full_idle")
			heart.play("default_full")
			
		HeartState.FILLING:
			heart.play("filling")
		HeartState.FULL:
			ultcast_anim.visible = true
			koisuru_meter.visible = false
			
			ultcast_anim.play("full")
			heart.play("full")
			
func update_rpointer_visual():
	
	match rpstate:
		RPointerState.FILL:
			right_pointer.play("fill")
		RPointerState.FULL:
			right_pointer.visible = false
		RPointerState.DEFAULT:
			right_pointer.play("default")
		RPointerState.BLINK:
			right_pointer.play("blink")
			
func update_lpointer_visual():
	
	match lpstate:
		LPointerState.FILL:
			left_pointer.play("fill")
		LPointerState.FULL:
			left_pointer.visible = false
			pass
		LPointerState.DEFAULT:
			left_pointer.play("default")
		LPointerState.BLINK:
			left_pointer.play("blink")		

func set_hstate(new_state: HeartState):
	if hstate == new_state:
		return
	hstate = new_state

func set_rpstate(new_state: RPointerState):
	if rpstate == new_state:
		return
	rpstate = new_state
	
func set_lpstate(new_state: LPointerState):
	if lpstate == new_state:
		return
	lpstate = new_state
	
func add_baku():
	if right_step >= STEPS:
		return
		
	set_hstate(HeartState.FILLING)
	set_rpstate(RPointerState.FILL)
	
	right_step += 1
	var ratio := float(right_step) / STEPS
	animate_pointer(right_follow, ratio)
	
	set_rpstate(RPointerState.FILL)
	
	if is_meter_full() == true:
		set_hstate(HeartState.FULL)
		
	else:
		set_hstate(HeartState.FILLING)
		
	update_heart_visual()
	update_rpointer_visual()
	
	if right_step >= STEPS - STEPS * 20/100:
		set_rpstate(RPointerState.BLINK)
		update_rpointer_visual()
		
	if right_step == STEPS:
		set_rpstate(RPointerState.FULL)
		update_rpointer_visual()
		
	
func add_yuna():
	if left_step >= STEPS:
		return

	left_step += 1
	var ratio := float(left_step) / STEPS
	animate_pointer(left_follow, ratio)
	
	set_lpstate(LPointerState.FILL)
	
	if is_meter_full() == true:
		set_hstate(HeartState.FULL)
		
	else:
		set_hstate(HeartState.FILLING)
		
	update_heart_visual()
	update_lpointer_visual()
	
	if left_step >= STEPS - STEPS * 20/100:
		set_lpstate(LPointerState.BLINK)
		update_lpointer_visual()
	
	if left_step == STEPS:
		set_lpstate(LPointerState.FULL)
		update_lpointer_visual()

func animate_pointer(follow: PathFollow2D, target_ratio: float):
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(
		follow,
		"progress_ratio",
		target_ratio,
		0.25
	)
	
func is_meter_full() -> bool:
	return left_step >= STEPS and right_step >= STEPS
	

func _on_left_sprite_animation_finished() -> void:
	if lpstate == LPointerState.FILL and (right_step >= STEPS - STEPS * 20/100) == false:
		set_lpstate(LPointerState.DEFAULT)
		
	update_lpointer_visual()
	pass # Replace with function body.


func _on_right_sprite_animation_finished() -> void:
	if rpstate == RPointerState.FILL and (left_step >= STEPS - STEPS * 20/100) == false:
		set_rpstate(RPointerState.DEFAULT)
		
	update_rpointer_visual()
	pass # Replace with function body.
	
func _on_heart_sprite_animation_finished() -> void:
	if hstate == HeartState.FILLING:
		set_hstate(HeartState.DEFAULT_BROKEN)
	if hstate == HeartState.FULL:
		set_hstate(HeartState.DEFAULT_FULL)
		
	update_heart_visual()
	pass # Replace with function body.

func _input(event):
	if Input.is_action_just_pressed("ulti"):
		try_cast_ulti()
		
		
func try_cast_ulti():
	if is_meter_full() == false:
		return

	ult_cast()

func ult_cast():
	
	koisuru_meter.visible = false
	ultcast_anim.visible = true
	ultcast_anim.play("cast_ult")
	heart.play("cast_ult")
	
 # nama animasi = nama skill
func _on_ultimate_anim_animation_finished() -> void:
	if hstate == HeartState.DEFAULT_FULL:
		set_hstate(HeartState.DEFAULT_BROKEN)
		set_lpstate(LPointerState.DEFAULT)
		set_rpstate(RPointerState.DEFAULT)
		update_heart_visual()
		update_lpointer_visual()
		update_rpointer_visual()
		reset_ult()
		
func reset_ult():
	ultcast_anim.visible = false
	koisuru_meter.visible = true
	left_step = 0
	right_step = 0
	left_follow.progress_ratio = 0
	right_follow.progress_ratio = 0
	left_pointer.visible = true
	right_pointer.visible = true
