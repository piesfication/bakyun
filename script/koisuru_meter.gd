extends Control

signal ultimate_casted

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
var ult_is_casting: bool = false
var ultimate_locked: bool = false


# Called when the node enters the scene tree for the first time.
@onready var left_follow  := $Container/Control/PathLeft/PathFollow2D
@onready var right_follow := $Container/Control/PathRight/PathFollow2D

@onready var heart := $Container/MidContainer/HeartSprite

@onready var right_pointer := $Container/Control/PathRight/PathFollow2D/PointerRightContainer/RightSprite
@onready var left_pointer := $Container/Control/PathLeft/PathFollow2D/PointerLeftContainer2/LeftSprite

@onready var left_fill: TextureProgressBar = $Container/Control/Base/LeftFill
@onready var right_fill: TextureProgressBar = $Container/Control/Base/RightFill

var _left_fill_ratio: float = 0.0
var _right_fill_ratio: float = 0.0

const FILL_ANIM_DURATION := 0.25

func _ready():
	print("left_fill node: ", left_fill)
	print("right_fill node: ", right_fill)
	hstate = HeartState.DEFAULT_BROKEN
	rpstate = RPointerState.DEFAULT
	lpstate = LPointerState.DEFAULT
	ult_is_casting = false
	koisuru_meter.visible = true
	ultcast_anim.visible = false
	update_heart_visual()
	update_rpointer_visual()
	update_lpointer_visual()
	_update_fill_bars(true)

var left_step := 0
var right_step := 0

const STEPS := 50
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

	_update_fill_bars()
		
	
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

	_update_fill_bars()


var _tween_left: Tween
var _tween_right: Tween

func _update_fill_bars(instant: bool = false) -> void:
	var target_left  := float(left_step)  / STEPS * 100.0
	var target_right := float(right_step) / STEPS * 100.0

	if instant:
		left_fill.value  = target_left
		right_fill.value = target_right
		return

	if _tween_left and _tween_left.is_valid():
		_tween_left.kill()
	if _tween_right and _tween_right.is_valid():
		_tween_right.kill()

	_tween_left = create_tween()
	_tween_left.tween_property(left_fill, "value", target_left, FILL_ANIM_DURATION)

	_tween_right = create_tween()
	_tween_right.tween_property(right_fill, "value", target_right, FILL_ANIM_DURATION)


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
	if ultimate_locked:
		return

	if Input.is_action_just_pressed("ulti"):
		try_cast_ulti()

func set_ultimate_locked(locked: bool) -> void:
	ultimate_locked = locked
		
		
func try_cast_ulti():
	if ult_is_casting:
		return
	if is_meter_full() == false:
		return

	ult_cast()

func ult_cast():
	ult_is_casting = true
	emit_signal("ultimate_casted")
	
	koisuru_meter.visible = false
	ultcast_anim.visible = true
	ultcast_anim.play("cast_ult")
	heart.play("cast_ult")
	
 # nama animasi = nama skill
func _on_ultimate_anim_animation_finished() -> void:
	if not ult_is_casting:
		return

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
	ult_is_casting = false
	left_step = 0
	right_step = 0
	left_follow.progress_ratio = 0
	right_follow.progress_ratio = 0
	left_pointer.visible = true
	right_pointer.visible = true
	_update_fill_bars(true)
