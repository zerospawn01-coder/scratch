extends Node
class_name Phase6ReactionSmokeTest

const SCENE_PATH := "res://scenes/ui/ui_glitch_phase6.tscn"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(SCENE_PATH) as PackedScene
	if not scene:
		push_error("Failed to load %s" % SCENE_PATH)
		get_tree().quit(1)
		return

	var root := scene.instantiate()
	root.name = "Phase6ReactionSmoke"
	get_tree().root.add_child(root)
	await get_tree().process_frame

	root.call("_start_battle")
	await get_tree().process_frame

	root.call("_perform_strike")
	await get_tree().process_frame

	root.call("_perform_guard")
	await get_tree().process_frame

	root.call("_resolve_enemy_attack")
	await get_tree().process_frame

	root.set("_enemy_hp", 1.0)
	root.call("_perform_strike")
	await get_tree().process_frame

	print("[PHASE6_SMOKE] reaction smoke completed")
	get_tree().quit(0)
