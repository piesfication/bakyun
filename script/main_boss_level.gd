extends "res://main.gd"

@export var boss_spawn_position: Vector2 = Vector2(800, 512)
@export var post_boss_delay_before_ui_hide: float = 0.4
@export var post_boss_delay_after_ui_hide: float = 0.3
@export var post_boss_damage_hud_fade_duration: float = 0.35
@export var post_boss_parallax_move_duration: float = 0.8
@export var post_boss_parallax_bg_target: Vector2 = Vector2(640, 368)
@export var post_boss_parallax_bg2_target: Vector2 = Vector2(640, 360)
@export var post_boss_timeline: String = "timeline_41"
@export var play_intro_timeline_before_boss: bool = false
@export var intro_timeline: String = ""
@export var intro_spawn_signal: String = "spawn_boss"
@export var spawn_boss_in_neutral_mode: bool = true
@export var start_summon_signal: String = "start_summon"
@export var phase_transition_timeline: String = ""
@export var phase_transition_resume_signal: String = "start_summon_phase_2"
@export var hide_health_bar_on_phase_transition: bool = true

@onready var combo = $LevelEndOverlay/ComboCounter
var boss_spawned: bool = false
var _post_boss_sequence_started: bool = false
var _combo_counter_disabled: bool = false
var _boss_ref: Node = null
var _first_combat_started: bool = false
var _phase_two_intermission_started: bool = false
var _phase_transition_waiting_resume: bool = false
var _timeline_mode_active: bool = false
var _damage_hud_was_visible_before_timeline: bool = false

func _ready() -> void:
	Dialogic.signal_event.connect(on_dialogic_signal);
	next_z_index = base_z_index
	_setup_main_runtime_systems()
	if play_intro_timeline_before_boss:
		await _start_intro_timeline_or_spawn_fallback()
	else:
		_spawn_boss_once()

func _begin_level_end_sequence(is_loss: bool) -> void:
	if not is_loss and has_node("/root/StoryProgress"):
		StoryProgress.mark_chapter_completed(4)
	super._begin_level_end_sequence(is_loss)

enum AnimMode {
	MOVE_ONLY,
	FADE_ONLY,
	MOVE_AND_FADE
}
func animate_node(node: CanvasItem, duration := 0.5, mode := AnimMode.MOVE_AND_FADE, target_global_pos := Vector2.ZERO):
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)

	if mode == AnimMode.FADE_ONLY or mode == AnimMode.MOVE_AND_FADE:
		node.modulate.a = 0
		node.visible = true
		tween.tween_property(node, "modulate:a", 1.0, duration)

	if mode == AnimMode.MOVE_ONLY or mode == AnimMode.MOVE_AND_FADE:
		if mode == AnimMode.MOVE_ONLY:
			tween.tween_property(node, "position", target_global_pos, duration)
		else:
			tween.parallel().tween_property(node, "position", target_global_pos, duration)

@onready var baku_smile = $CanvasLayer/BakuYunaExpression/BakuSmile
@onready var baku_shock  = $CanvasLayer/BakuYunaExpression/BakuShock
@onready var yuna_smile = $CanvasLayer/BakuYunaExpression/YunaSmile
@onready var yuna_shock = $CanvasLayer/BakuYunaExpression/YunaShock

@onready var alpha = $CanvasLayer/BossAnim
@onready var alphabody = $CanvasLayer/BossAnim/Base
@onready var alphadevour = $CanvasLayer/BossAnim/DevourAnim

func on_dialogic_signal(arg: String):
	if _should_resume_first_combat_from_signal(arg):
		await _resume_first_combat_from_timeline()
		return

	if _should_resume_phase_two_from_signal(arg):
		await _resume_phase_two_combat_from_timeline()
		return

	if _should_spawn_boss_from_dialogic_signal(arg):
		_spawn_boss_once()
		return

	if (arg == "trigger_bakumono") :
		
		baku_smile.modulate.a = 0
		baku_smile.visible = true
		
		animate_node(baku_smile, 0.5, AnimMode.MOVE_AND_FADE, Vector2(0, 216))
		animate_node(baku_shock, 0.5, AnimMode.MOVE_ONLY, Vector2(0, 216))
	
		pass
	
	if (arg == "trigger_yuokai") :
		
		yuna_smile.modulate.a = 0
		yuna_smile.visible = true
		
		animate_node(yuna_smile, 0.5, AnimMode.MOVE_AND_FADE, Vector2(0, 216))
		animate_node(yuna_shock, 0.5, AnimMode.MOVE_ONLY, Vector2(0, 216))
	
		pass
		
	if (arg == "devour baku") :
		alphabody.visible = true
		alphadevour.visible = false
		animate_node(alpha, 0.5, AnimMode.MOVE_AND_FADE, Vector2(594, 346))
		await get_tree().create_timer(1.2).timeout
		baku_shock.visible = true
		baku_smile.visible = false
		await get_tree().create_timer(1.2).timeout
		alphadevour.visible = true
		alphabody.visible = false
		alphadevour.play("devour")
		
	if (arg == "devour yuna") :
		alphabody.visible = true
		alphadevour.visible = false
		animate_node(alpha, 0.5, AnimMode.MOVE_AND_FADE, Vector2(594, 346))
		await get_tree().create_timer(1.2).timeout
		yuna_shock.visible = true
		yuna_smile.visible = false
		await get_tree().create_timer(1.2).timeout
		alphadevour.visible = true
		alphabody.visible = false
		alphadevour.play("devour")
		
		
	if (arg == "bakumono_level") :
		LoadingManager.set_target_scene("res://scenes/main_bakumono.tscn")
		await Transition.fade_out()
		get_tree().change_scene_to_file("res://scenes/loading_screen.tscn")
		await Transition.fade_in() # fade out
		
	if (arg == "yuokai_level") :
		LoadingManager.set_target_scene("res://scenes/main_yuokai.tscn")
		await Transition.fade_out()
		get_tree().change_scene_to_file("res://scenes/loading_screen.tscn")
		await Transition.fade_in() # fade out

func _start_intro_timeline_or_spawn_fallback() -> void:
	var intro := intro_timeline.strip_edges()
	if intro.is_empty():
		push_warning("play_intro_timeline_before_boss aktif, tapi intro_timeline kosong. Boss akan spawn langsung.")
		_spawn_boss_once()
		return
	await _enter_timeline_mode(true)
	Dialogic.start(intro)

func _should_spawn_boss_from_dialogic_signal(arg: String) -> bool:
	if boss_spawned:
		return false
	var expected_signal := intro_spawn_signal.strip_edges()
	if expected_signal.is_empty():
		return false
	return arg == expected_signal
		

func _process(_delta: float) -> void:
	# Boss-only level: disable regular enemy wave spawning.
	pass

func _spawn_boss_once() -> void:
	if boss_spawned:
		return
	if enemy_scene == null:
		push_warning("enemy_scene belum diset untuk boss level")
		return

	var boss = enemy_scene.instantiate()
	if boss == null:
		push_warning("Gagal instantiate boss scene")
		return

	if spawn_boss_in_neutral_mode and boss.has_method("set_initial_combat_active"):
		boss.call("set_initial_combat_active", false)

	# Spawn boss dari atas viewport supaya tidak ada visual snap/teleport
	var viewport_rect := get_viewport_rect()
	boss.position = Vector2(viewport_rect.size.x * 0.5, -220.0)
	boss.z_index = max(next_z_index, z_front_min)
	next_z_index -= 1
	enemy_container.add_child(boss)
	_boss_ref = boss

	boss_spawned = true
	current_enemy_count = 1
	boss.tree_exited.connect(_on_boss_removed)
	if boss.has_signal("boss_defeated"):
		boss.connect("boss_defeated", Callable(self, "_on_boss_defeated"))
	if boss.has_signal("boss_hp_changed"):
		boss.connect("boss_hp_changed", Callable(self, "_on_boss_hp_changed"))

	if spawn_boss_in_neutral_mode:
		_set_boss_combat_active(false)

func _on_boss_removed() -> void:
	current_enemy_count = 0
	_boss_ref = null
	await _run_post_boss_sequence()

func _on_boss_defeated() -> void:
	await _run_post_boss_sequence()

func _run_post_boss_sequence() -> void:
	if _post_boss_sequence_started:
		return
	_post_boss_sequence_started = true

	# Delay after boss dies
	await get_tree().create_timer(post_boss_delay_before_ui_hide).timeout

	await _enter_timeline_mode()
	_disable_and_hide_combo_counter(true)
	
	# Delay antara UI hide dan parallax move
	await get_tree().create_timer(post_boss_delay_after_ui_hide).timeout
	
	await _move_parallax_story_focus()
	_start_post_boss_timeline()

func _start_post_boss_timeline() -> void:
	var timeline_to_play := post_boss_timeline.strip_edges()
	if timeline_to_play.is_empty():
		push_warning("post_boss_timeline kosong, Dialogic tidak dijalankan")
		return
	Dialogic.start(timeline_to_play)

func _fade_out_damage_hud_if_visible() -> bool:
	var root := get_tree().current_scene
	if root == null:
		return false

	var damage_hud := root.find_child("DamageHud", true, false)
	if damage_hud == null or not is_instance_valid(damage_hud):
		return false
	if not (damage_hud is CanvasItem):
		return false

	var damage_hud_canvas := damage_hud as CanvasItem
	if not damage_hud_canvas.visible:
		return false

	var fade_duration := maxf(post_boss_damage_hud_fade_duration, 0.01)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(damage_hud_canvas, "modulate:a", 0.0, fade_duration)
	await tween.finished
	damage_hud_canvas.visible = false
	return true

func _fade_in_damage_hud_if_needed() -> void:
	if not _damage_hud_was_visible_before_timeline:
		return

	var root := get_tree().current_scene
	if root == null:
		return

	var damage_hud := root.find_child("DamageHud", true, false)
	if damage_hud == null or not is_instance_valid(damage_hud):
		return
	if not (damage_hud is CanvasItem):
		return

	var damage_hud_canvas := damage_hud as CanvasItem
	damage_hud_canvas.visible = true
	damage_hud_canvas.modulate.a = 0.0

	var fade_duration := maxf(post_boss_damage_hud_fade_duration, 0.01)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(damage_hud_canvas, "modulate:a", 1.0, fade_duration)
	await tween.finished

func _disable_crosshair_and_restore_cursor() -> void:
	# Hide crosshair
	_disable_and_hide_combo_counter(false)
	if crosshair_node != null and is_instance_valid(crosshair_node):
		if crosshair_node.has_method("set_force_hidden"):
			crosshair_node.set_force_hidden(true)
		elif crosshair_node is CanvasItem:
			(crosshair_node as CanvasItem).visible = false
	
	# Restore normal cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _disable_and_hide_combo_counter(permanent: bool = false) -> void:
	_combo_counter_disabled = permanent

	if combo_counter_node != null and is_instance_valid(combo_counter_node):
		if combo_counter_node.has_method("reset"):
			combo_counter_node.reset()
		if combo_counter_node is CanvasItem:
			(combo_counter_node as CanvasItem).visible = false
		combo_counter_node.set_process(false)

	if combo != null and is_instance_valid(combo):
		combo.visible = false

func _restore_combo_counter_after_timeline() -> void:
	if combo_counter_node != null and is_instance_valid(combo_counter_node):
		if combo_counter_node is CanvasItem:
			(combo_counter_node as CanvasItem).visible = true
		combo_counter_node.set_process(true)

	if combo != null and is_instance_valid(combo):
		combo.visible = true

func _enter_timeline_mode(instant: bool = false) -> void:
	if _timeline_mode_active:
		return

	await _set_ultimate_ui_pulled_out(true, true, instant)
	_set_boss_health_bar_visible(false)
	if instant:
		_damage_hud_was_visible_before_timeline = _hide_damage_hud_instant_if_visible()
	else:
		_damage_hud_was_visible_before_timeline = await _fade_out_damage_hud_if_visible()
	_disable_and_hide_combo_counter(false)
	if crosshair_node != null and is_instance_valid(crosshair_node):
		if crosshair_node.has_method("set_force_hidden"):
			crosshair_node.set_force_hidden(true)
		elif crosshair_node is CanvasItem:
			(crosshair_node as CanvasItem).visible = false
	_set_crosshair_shoot_enabled(false)
	_set_combat_cast_locked(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_timeline_mode_active = true

func _hide_damage_hud_instant_if_visible() -> bool:
	var root := get_tree().current_scene
	if root == null:
		return false

	var damage_hud := root.find_child("DamageHud", true, false)
	if damage_hud == null or not is_instance_valid(damage_hud):
		return false
	if not (damage_hud is CanvasItem):
		return false

	var damage_hud_canvas := damage_hud as CanvasItem
	if not damage_hud_canvas.visible:
		return false

	damage_hud_canvas.modulate.a = 0.0
	damage_hud_canvas.visible = false
	return true

func _exit_timeline_mode() -> void:
	if not _timeline_mode_active:
		return

	await _set_ultimate_ui_pulled_out(false, true)
	_set_boss_health_bar_visible(_is_boss_combat_active())
	await _fade_in_damage_hud_if_needed()
	_restore_combo_counter_after_timeline()
	if crosshair_node != null and is_instance_valid(crosshair_node):
		if crosshair_node.has_method("set_force_hidden"):
			crosshair_node.set_force_hidden(false)
		elif crosshair_node is CanvasItem:
			(crosshair_node as CanvasItem).visible = true
	_set_crosshair_shoot_enabled(true)
	_set_combat_cast_locked(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	_timeline_mode_active = false

func _set_boss_combat_active(active: bool) -> void:
	if _boss_ref == null or not is_instance_valid(_boss_ref):
		return
	if _boss_ref.has_method("set_combat_active"):
		_boss_ref.call("set_combat_active", active)

func _set_boss_health_bar_visible(visible: bool) -> void:
	if _boss_ref == null or not is_instance_valid(_boss_ref):
		return
	if _boss_ref.has_method("set_health_bar_visible"):
		_boss_ref.call("set_health_bar_visible", visible)

func _is_boss_combat_active() -> bool:
	if _boss_ref == null or not is_instance_valid(_boss_ref):
		return false
	if _boss_ref.has_method("is_combat_active"):
		return bool(_boss_ref.call("is_combat_active"))
	return false

func _should_resume_first_combat_from_signal(arg: String) -> bool:
	if not boss_spawned:
		return false
	if _first_combat_started:
		return false
	if _phase_two_intermission_started:
		return false
	var expected := start_summon_signal.strip_edges()
	if expected.is_empty():
		return false
	return arg == expected

func _should_resume_phase_two_from_signal(arg: String) -> bool:
	if not _phase_transition_waiting_resume:
		return false
	var expected := phase_transition_resume_signal.strip_edges()
	if expected.is_empty():
		return false
	return arg == expected

func _resume_first_combat_from_timeline() -> void:
	await _exit_timeline_mode()
	_set_boss_combat_active(true)
	_set_boss_health_bar_visible(true)
	_first_combat_started = true

func _resume_phase_two_combat_from_timeline() -> void:
	_phase_transition_waiting_resume = false
	await _exit_timeline_mode()
	_set_boss_combat_active(true)
	_set_boss_health_bar_visible(true)

func _on_boss_hp_changed(old_hp: int, new_hp: int) -> void:
	if _phase_two_intermission_started:
		return
	if new_hp <= 0:
		return
	if _boss_ref == null or not is_instance_valid(_boss_ref):
		return

	var hp_per_layer := int(_boss_ref.get("hp_per_layer"))
	if hp_per_layer <= 0:
		return

	var crossed_to_last_layer := old_hp > hp_per_layer and new_hp <= hp_per_layer
	if not crossed_to_last_layer:
		return

	_phase_two_intermission_started = true
	_set_boss_combat_active(false)
	if hide_health_bar_on_phase_transition:
		_set_boss_health_bar_visible(false)

	_phase_transition_waiting_resume = true
	var timeline_name := phase_transition_timeline.strip_edges()
	if timeline_name.is_empty():
		return

	await _enter_timeline_mode()
	Dialogic.start(timeline_name)

func on_player_hit(character: String = "baku") -> void:
	if _combo_counter_disabled:
		return
	super.on_player_hit(character)

func on_player_miss() -> void:
	if _combo_counter_disabled:
		return
	super.on_player_miss()

func _move_parallax_story_focus() -> void:
	var root := get_tree().current_scene
	if root == null:
		return

	var bg_sprite := root.get_node_or_null("ParallaxBackground/ParallaxLayer/Sprite2D") as Node2D
	var bg2_sprite := root.get_node_or_null("ParallaxBackground2/ParallaxLayer/Sprite2D3") as Node2D
	if bg_sprite == null and bg2_sprite == null:
		return

	var move_duration := maxf(post_boss_parallax_move_duration, 0.01)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_parallel(true)

	if bg_sprite != null:
		tween.tween_property(bg_sprite, "position", post_boss_parallax_bg_target, move_duration)
	if bg2_sprite != null:
		tween.tween_property(bg2_sprite, "position", post_boss_parallax_bg2_target, move_duration)

	await tween.finished

@onready var overlay = $CanvasLayer3/Overlay
func _on_devour_anim_frame_changed() -> void:
	if alphadevour.frame >= 4:
		Transition.play_crt_glitch_burst()
	if alphadevour.frame == 5:
		animate_node(overlay, 0.2, AnimMode.FADE_ONLY)
		
