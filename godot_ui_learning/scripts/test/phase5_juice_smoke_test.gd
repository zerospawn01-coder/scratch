extends Node
class_name Phase5JuiceSmokeTest

const GAME_SCENE_PATH := "res://scenes/game/game_scene.tscn"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	Engine.time_scale = 1.0
	GlobalData.data = 999.0
	GlobalData.miners_owned = 0
	GlobalData.hp_level = 0
	GlobalData.damage_level = 0

	var scene := load(GAME_SCENE_PATH) as PackedScene
	if not scene:
		push_error("Failed to load %s" % GAME_SCENE_PATH)
		get_tree().quit(1)
		return

	var root := scene.instantiate()
	get_tree().root.add_child(root)
	await get_tree().process_frame

	root.call("_on_hack_pressed")
	await get_tree().process_frame

	_assert_bool(_has_floating_text(root), "FloatingText should spawn on hack")

	var overlay := root.get_node("GlitchOverlay")
	_assert_bool(float(overlay.get("strength")) > 0.0, "Glitch overlay should boost on hack")

	var shake_target := root.get_node("MarginContainer") as Control
	var before_x := shake_target.position.x
	root.call("_on_buy_miner_pressed")
	await get_tree().process_frame

	_assert_bool(not is_equal_approx(shake_target.position.x, before_x), "Purchase should shake the UI shell")

	# Clocks Fast-Forward: Wait for tweens to finish (1.5s game time, which is 0.15s real time at time_scale=10)
	Engine.time_scale = 10.0
	await get_tree().create_timer(1.5).timeout

	# Cleanup Verification: Assert floating text is queue_freed (no leak)
	_assert_bool(not _has_floating_text(root), "FloatingText should be automatically cleaned up")

	# Reset Coordinates Verification: Shaken container should return to 0
	_assert_bool(is_equal_approx(shake_target.position.x, 0.0), "MarginContainer X position should reset to 0 after shake")

	Engine.time_scale = 1.0
	print("[PHASE5_JUICE] Cleanup check, coordinate reset, and timescale assertions passed")
	get_tree().quit(0)

func _has_floating_text(root: Node) -> bool:
	for child in root.get_children():
		if child is Label and str(child.text).begins_with("+1 DATA"):
			return true
	return false

func _assert_bool(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
