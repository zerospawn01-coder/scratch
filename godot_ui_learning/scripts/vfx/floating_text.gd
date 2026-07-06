extends Label

@export var float_distance: float = 60.0
@export var float_duration: float = 0.8
@export var random_spread: float = 20.0

var _configured: bool = false
var _animation_started: bool = false

func _ready() -> void:
	# Ignore mouse events
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_try_start_animation()

func setup(text_str: String, start_pos: Vector2, color: Color = Color.WHITE) -> void:
	text = text_str
	position = start_pos
	add_theme_color_override("font_color", color)
	_configured = true
	_try_start_animation()

func _try_start_animation() -> void:
	if not _configured or _animation_started:
		return

	_animation_started = true
	var tween := create_tween()
	tween.set_parallel(true)

	# pop scale
	scale = Vector2(0.5, 0.5)
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2).set_delay(0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# float up & random drift
	var target_y := position.y - float_distance
	var target_x := position.x + randf_range(-random_spread, random_spread)
	tween.tween_property(self, "position:y", target_y, float_duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:x", target_x, float_duration).set_trans(Tween.TRANS_LINEAR)

	# fade out
	modulate.a = 1.0
	tween.tween_property(self, "modulate:a", 0.0, float_duration * 0.4).set_delay(float_duration * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.chain().tween_callback(queue_free)
