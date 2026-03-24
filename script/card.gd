extends Node2D

@export var player_path: NodePath = NodePath("../../../Player")
@export var damage_flash_color: Color = Color(1.0, 0.7, 0.7, 1.0)
@export var damage_flash_duration: float = 0.08

@onready var anim_card: AnimatedSprite2D = $AnimCard

var player: Node
var current_character := "baku"
var base_scale := Vector2.ONE
var switch_tween: Tween
var damage_flash_tween: Tween


func _ready() -> void:
	anim_card.animation_finished.connect(_on_anim_card_animation_finished)
	base_scale = anim_card.scale

	if has_node(player_path):
		player = get_node(player_path)
	else:
		push_warning("Player node not found for Card UI.")
		return

	if player.has_signal("hp_changed"):
		player.connect("hp_changed", Callable(self, "_on_player_hp_changed"))
	if player.has_signal("character_switched"):
		player.connect("character_switched", Callable(self, "_on_character_switched"))

	if player.has_method("get_current_character_name"):
		current_character = String(player.call("get_current_character_name"))

	var hp_now := _get_display_hp_tier(int(player.get("current_hp")))
	play_idle_for_hp(hp_now)


func _on_character_switched(character_name: String) -> void:
	current_character = character_name.to_lower()
	play_switch_squash_stretch()
	var hp_now := _get_display_hp_tier(int(player.get("current_hp")))
	play_idle_for_hp(hp_now)


func _on_player_hp_changed(old_hp: int, new_hp: int) -> void:
	var old_tier := _get_display_hp_tier(old_hp)
	var new_tier := _get_display_hp_tier(new_hp)

	# Damaged HUD hanya untuk event HP turun.
	if new_hp >= old_hp:
		play_idle_for_hp(new_tier)
		return

	_play_damage_flash()

	var transition_anim := get_transition_animation(old_tier, new_tier)
	if transition_anim.is_empty():
		play_idle_for_hp(new_tier)
		return

	if anim_card.sprite_frames.has_animation(transition_anim):
		anim_card.sprite_frames.set_animation_loop(transition_anim, false)
		anim_card.play(transition_anim)
	else:
		play_idle_for_hp(new_hp)


func _on_anim_card_animation_finished() -> void:
	var hp_now := _get_display_hp_tier(int(player.get("current_hp")))
	play_idle_for_hp(hp_now)


func play_idle_for_hp(hp: int) -> void:
	var hp_clamped := clampi(hp, 0, 3)
	var idle_anim := "%s_idle_%d" % [current_character, hp_clamped]

	if anim_card.sprite_frames.has_animation(idle_anim):
		anim_card.sprite_frames.set_animation_loop(idle_anim, true)
		anim_card.play(idle_anim)


func get_transition_animation(old_hp: int, new_hp: int) -> String:
	if old_hp == 3 and new_hp == 2:
		return "%s_3_to_2" % current_character
	if old_hp == 2 and new_hp == 1:
		return "%s_2_to_1" % current_character
	if old_hp == 1 and new_hp == 0:
		return "%s_1_to_0" % current_character
	return ""

func _get_display_hp_tier(raw_hp: int) -> int:
	if player == null:
		return clampi(raw_hp, 0, 3)

	var max_hp := int(player.get("max_hp"))
	if max_hp <= 3:
		return clampi(raw_hp, 0, 3)
	if raw_hp <= 0:
		return 0

	# Petakan HP aktual ke 3 tier HUD: 3, 2, 1, 0.
	return clampi(int(ceili((float(raw_hp) / float(max_hp)) * 3.0)), 1, 3)


func play_switch_squash_stretch() -> void:
	if switch_tween and switch_tween.is_running():
		switch_tween.kill()

	anim_card.scale = base_scale
	switch_tween = create_tween()
	switch_tween.set_trans(Tween.TRANS_BACK)
	switch_tween.set_ease(Tween.EASE_OUT)

	# Quick squash then stretch, then settle back to original scale.
	var squash := Vector2(base_scale.x * 0.82, base_scale.y * 1.2)
	var stretch := Vector2(base_scale.x * 1.12, base_scale.y * 0.9)

	switch_tween.tween_property(anim_card, "scale", squash, 0.08)
	switch_tween.tween_property(anim_card, "scale", stretch, 0.09)
	switch_tween.tween_property(anim_card, "scale", base_scale, 0.1)

func _play_damage_flash() -> void:
	if anim_card == null:
		return
	if damage_flash_tween and damage_flash_tween.is_running():
		damage_flash_tween.kill()

	anim_card.modulate = damage_flash_color
	damage_flash_tween = create_tween()
	damage_flash_tween.set_trans(Tween.TRANS_SINE)
	damage_flash_tween.set_ease(Tween.EASE_OUT)
	damage_flash_tween.tween_property(anim_card, "modulate", Color.WHITE, damage_flash_duration)
