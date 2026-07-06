extends Node
class_name Phase6TimeoutSmokeTest

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
	get_tree().root.add_child(root)
	await get_tree().process_frame

	root.call("_start_battle")
	root.set("_time_left", 0.0)
	root.call("_process", 0.1)
	await get_tree().process_frame

	var status_text := str(root.get_node("MarginContainer/VBoxContainer/StatusLabel").text)
	if not status_text.begins_with("STATUS: CORE COLLAPSED"):
		push_error("Timeout should fail, got: %s" % status_text)
		get_tree().quit(1)
		return

	print("[PHASE6_TIMEOUT] timeout resolved as failure: %s" % status_text)
	get_tree().quit(0)
