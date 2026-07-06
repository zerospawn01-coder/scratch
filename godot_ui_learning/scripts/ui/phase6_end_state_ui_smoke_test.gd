extends Node
class_name Phase6EndStateUISmokeTest

const SCENE_PATH := "res://scenes/ui/ui_glitch_phase6.tscn"
const PLAYER_BAR_PATH := "MarginContainer/VBoxContainer/BattleContainer/PlayerPanel/PlayerVBox/PlayerHpBar"
const ENEMY_BAR_PATH := "MarginContainer/VBoxContainer/BattleContainer/EnemyPanel/EnemyVBox/EnemyHpBar"
const PLAYER_STATE_PATH := "MarginContainer/VBoxContainer/BattleContainer/PlayerPanel/PlayerVBox/PlayerStateLabel"
const ENEMY_STATE_PATH := "MarginContainer/VBoxContainer/BattleContainer/EnemyPanel/EnemyVBox/EnemyStateLabel"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(SCENE_PATH) as PackedScene
	if not scene:
		push_error("Failed to load %s" % SCENE_PATH)
		get_tree().quit(1)
		return

	var timeout_root := scene.instantiate()
	get_tree().root.add_child(timeout_root)
	await get_tree().process_frame

	timeout_root.call("_start_battle")
	timeout_root.set("_enemy_hp", 37.0)
	timeout_root.set("_integrity", 42.0)
	timeout_root.set("_enemy_attack_timer", 99.0)
	timeout_root.set("_time_left", 0.0)
	timeout_root.call("_process", 0.0)
	await get_tree().process_frame

	_assert_progress_value(timeout_root, PLAYER_BAR_PATH, 42.0, "timeout player hp bar")
	_assert_progress_value(timeout_root, ENEMY_BAR_PATH, 37.0, "timeout enemy hp bar")
	_assert_label_contains(timeout_root, ENEMY_STATE_PATH, "TARGET LOCKED", "timeout enemy state")
	timeout_root.queue_free()
	await get_tree().process_frame

	var clear_root := scene.instantiate()
	get_tree().root.add_child(clear_root)
	await get_tree().process_frame

	clear_root.call("_start_battle")
	clear_root.set("_integrity", 58.0)
	clear_root.set("_enemy_hp", 1.0)
	clear_root.call("_perform_strike")
	await get_tree().process_frame

	_assert_progress_value(clear_root, PLAYER_BAR_PATH, 58.0, "clear player hp bar")
	_assert_progress_value(clear_root, ENEMY_BAR_PATH, 0.0, "clear enemy hp bar")
	_assert_label_contains(clear_root, ENEMY_STATE_PATH, "TARGET DOWN", "clear enemy state")

	print("[PHASE6_UI_END_STATE] timeout and clear UI assertions passed")
	get_tree().quit(0)

func _assert_progress_value(root: Node, node_path: String, expected: float, label: String) -> void:
	var bar := root.get_node(node_path) as ProgressBar
	if bar == null:
		push_error("Missing ProgressBar for %s" % label)
		get_tree().quit(1)
		return
	if not is_equal_approx(bar.value, expected):
		push_error("%s mismatch: expected %.2f got %.2f" % [label, expected, bar.value])
		get_tree().quit(1)

func _assert_label_contains(root: Node, node_path: String, expected: String, label: String) -> void:
	var target_label := root.get_node(node_path) as Label
	if target_label == null:
		push_error("Missing Label for %s" % label)
		get_tree().quit(1)
		return
	if expected not in target_label.text:
		push_error("%s mismatch: expected '%s' in '%s'" % [label, expected, target_label.text])
		get_tree().quit(1)
