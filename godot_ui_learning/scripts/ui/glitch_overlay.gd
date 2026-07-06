extends ColorRect
class_name GlitchOverlay

@export_range(0.0, 1.0, 0.01) var strength: float = 0.0:
	set(value):
		_strength = clampf(value, 0.0, 1.0)
		_apply_strength()
	get:
		return _strength

@export_range(0.05, 1.0, 0.01) var boost_duration: float = 0.2
@export_range(0.0, 0.2, 0.01) var boost_hold_time: float = 0.04
@export_range(0.0, 1.0, 0.01) var boost_peak: float = 1.0

var _strength: float = 0.0
var _shader_material: ShaderMaterial
var _boost_tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shader_material = material as ShaderMaterial
	if _shader_material == null:
		push_warning("GlitchOverlay requires a ShaderMaterial to drive strength.")
	_apply_strength()

func boost() -> void:
	if _boost_tween:
		_boost_tween.kill()

	strength = clampf(boost_peak, 0.0, 1.0)
	_boost_tween = create_tween()
	if boost_hold_time > 0.0:
		_boost_tween.tween_interval(boost_hold_time)
	_boost_tween.tween_property(self, "strength", 0.0, maxf(boost_duration - boost_hold_time, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _apply_strength() -> void:
	if _shader_material:
		_shader_material.set_shader_parameter("strength", _strength)
