extends CanvasLayer

@onready var rect = $CanvasLayer/ColorRect2
@onready var bakutitle = $CanvasLayer/Sprite2DBaku
@onready var yunatitle = $CanvasLayer/Sprite2DYuna
@onready var crt_rect: ColorRect = $CanvasLayer4/ColorRect

var _crt_default_params: Dictionary = {}
var _crt_burst_active: bool = false
var _crt_burst_hold_duration: float = 0.22
var _crt_burst_restore_duration: float = 0.11

func _ready():
	bakutitle.visible = false
	yunatitle.visible = false
	
	rect.modulate.a = 0
	bakutitle.modulate.a = 0
	yunatitle.modulate.a = 0
	_cache_crt_defaults()
	set_crt_discolor(false)


# ======================
# BAKU (FADE OUT)
# ======================
func fade_out():
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 1. Overlay fade in
	
	# 🔥 RESET STATE (INI YANG KURANG)
	bakutitle.visible = true
	bakutitle.scale = Vector2(1, 1)
	bakutitle.modulate.a = 0
	
	tween.tween_property(rect, "modulate:a", 1.0, 0.6)

	# 2. Setelah overlay solid → Baku masuk
	tween.tween_callback(func():
		bakutitle.visible = true
		bakutitle.scale = Vector2(0.8, 0.8)
		bakutitle.modulate.a = 0
	)

	# 3. Baku muncul (scale + alpha sync)
	tween.parallel().tween_property(bakutitle, "scale", Vector2(1.3, 1.3), 0.2)
	tween.parallel().tween_property(bakutitle, "modulate:a", 1.0, 0.2)

	await tween.finished
	# lanjut ke yuna phase
	var tween2 = create_tween()
	tween2.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

	# switch ke Yuna
	bakutitle.visible = false
	
	yunatitle.visible = true
	yunatitle.scale = Vector2(1.3, 1.3)
	yunatitle.modulate.a = 1.0

	# 1. Yuna keluar dulu (CEPAT + punchy)
	tween2.parallel().tween_property(yunatitle, "scale", Vector2(1, 1), 0.2)
	tween2.parallel().tween_property(yunatitle, "modulate:a", 0.0, 0.2)

	await tween2.finished  # ⬅️ tunggu Yuna FULL hilang

	yunatitle.visible = false
# ======================
# YUNA (FADE IN)
# ======================
func fade_in():
	
	# 2. BARU overlay fade out
	var tween2 = create_tween()
	tween2.tween_property(rect, "modulate:a", 0.0, 1.5)

	await tween2.finished

func set_crt_discolor(enabled: bool) -> void:
	if crt_rect == null or not is_instance_valid(crt_rect):
		return

	var shader_material := crt_rect.material as ShaderMaterial
	if shader_material == null:
		return

	shader_material.set_shader_parameter("discolor", enabled)

func play_crt_glitch_burst() -> void:
	if _crt_burst_active:
		return
	if crt_rect == null or not is_instance_valid(crt_rect):
		return

	var shader_material := crt_rect.material as ShaderMaterial
	if shader_material == null:
		return

	_crt_burst_active = true
	_apply_crt_burst_params(shader_material)

	await get_tree().create_timer(_crt_burst_hold_duration).timeout

	var restore_tween := create_tween()
	restore_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	restore_tween.tween_method(func(value: float) -> void:
		shader_material.set_shader_parameter("roll_speed", lerpf(14.0, float(_crt_default_params.get("roll_speed", 2.0)), value))
		shader_material.set_shader_parameter("roll_size", lerpf(22.0, float(_crt_default_params.get("roll_size", 15.0)), value))
		shader_material.set_shader_parameter("roll_variation", lerpf(2.8, float(_crt_default_params.get("roll_variation", 1.8)), value))
		shader_material.set_shader_parameter("distort_intensity", lerpf(0.1, float(_crt_default_params.get("distort_intensity", 0.01)), value))
		shader_material.set_shader_parameter("noise_opacity", lerpf(0.5, float(_crt_default_params.get("noise_opacity", 0.4)), value))
		shader_material.set_shader_parameter("noise_speed", lerpf(9.0, float(_crt_default_params.get("noise_speed", 4.0)), value))
		shader_material.set_shader_parameter("static_noise_intensity", lerpf(0.12, float(_crt_default_params.get("static_noise_intensity", 0.1)), value))
		shader_material.set_shader_parameter("aberration", lerpf(0.11, float(_crt_default_params.get("aberration", 0.01)), value))
		shader_material.set_shader_parameter("pixelate", bool(_crt_default_params.get("pixelate", false)))
		shader_material.set_shader_parameter("roll", bool(_crt_default_params.get("roll", true)))
	, 0.0, 1.0, _crt_burst_restore_duration)

	await restore_tween.finished
	_restore_crt_defaults(shader_material)
	_crt_burst_active = false

func get_crt_glitch_burst_duration() -> float:
	return _crt_burst_hold_duration + _crt_burst_restore_duration

func _cache_crt_defaults() -> void:
	if crt_rect == null or not is_instance_valid(crt_rect):
		return

	var shader_material := crt_rect.material as ShaderMaterial
	if shader_material == null:
		return

	_crt_default_params = {
		"resolution": shader_material.get_shader_parameter("resolution"),
		"scanlines_opacity": shader_material.get_shader_parameter("scanlines_opacity"),
		"grille_opacity": shader_material.get_shader_parameter("grille_opacity"),
		"roll_speed": shader_material.get_shader_parameter("roll_speed"),
		"roll_size": shader_material.get_shader_parameter("roll_size"),
		"roll_variation": shader_material.get_shader_parameter("roll_variation"),
		"distort_intensity": shader_material.get_shader_parameter("distort_intensity"),
		"noise_opacity": shader_material.get_shader_parameter("noise_opacity"),
		"noise_speed": shader_material.get_shader_parameter("noise_speed"),
		"static_noise_intensity": shader_material.get_shader_parameter("static_noise_intensity"),
		"aberration": shader_material.get_shader_parameter("aberration"),
		"brightness": shader_material.get_shader_parameter("brightness"),
		"discolor": shader_material.get_shader_parameter("discolor"),
		"warp_amount": shader_material.get_shader_parameter("warp_amount"),
		"vignette_intensity": shader_material.get_shader_parameter("vignette_intensity"),
		"vignette_opacity": shader_material.get_shader_parameter("vignette_opacity"),
		"pixelate": shader_material.get_shader_parameter("pixelate"),
		"roll": shader_material.get_shader_parameter("roll"),
		"clip_warp": shader_material.get_shader_parameter("clip_warp")
	}

func _apply_crt_burst_params(shader_material: ShaderMaterial) -> void:
	shader_material.set_shader_parameter("roll_speed", 14.0)
	shader_material.set_shader_parameter("roll_size", 22.0)
	shader_material.set_shader_parameter("roll_variation", 2.8)
	shader_material.set_shader_parameter("distort_intensity", 0.1)
	shader_material.set_shader_parameter("noise_opacity", 0.5)
	shader_material.set_shader_parameter("noise_speed", 9.0)
	shader_material.set_shader_parameter("static_noise_intensity", 0.12)
	shader_material.set_shader_parameter("aberration", 0.11)
	shader_material.set_shader_parameter("pixelate", true)
	shader_material.set_shader_parameter("roll", true)

func _restore_crt_defaults(shader_material: ShaderMaterial) -> void:
	if _crt_default_params.is_empty():
		return

	for key in _crt_default_params.keys():
		shader_material.set_shader_parameter(key, _crt_default_params[key])
