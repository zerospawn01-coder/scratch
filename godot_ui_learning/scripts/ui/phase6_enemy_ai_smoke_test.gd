extends Node
class_name Phase6EnemyAISmokeTest

const SCENE_PATH := "res://scenes/ui/ui_glitch_phase6.tscn"
const ENEMY_STATE_PATH := "MarginContainer/VBoxContainer/BattleContainer/EnemyPanel/EnemyVBox/EnemyStateLabel"

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
	root.set("_integrity", 100.0)
	root.call("_set_enemy_intent_profile", "lock")
	root.call("_resolve_enemy_attack")
	await get_tree().process_frame

	var charge_hint := str(root.get_node("MarginContainer/VBoxContainer/HintLabel").text)
	if "次弾が強化されます" not in charge_hint:
		push_error("Charge hint missing: %s" % charge_hint)
		get_tree().quit(1)
		return

	var enemy_state := str(root.get_node(ENEMY_STATE_PATH).text)
	if "MORTAR SPIKE" not in enemy_state:
		push_error("Charge follow-up missing: %s" % enemy_state)
		get_tree().quit(1)
		return

	root.set("_guard_active", true)
	root.set("_integrity", 100.0)
	root.call("_set_enemy_intent_profile", "ripper")
	root.call("_resolve_enemy_attack")
	await get_tree().process_frame

	var integrity := float(root.get("_integrity"))
	if integrity >= 100.0:
		push_error("Guard-pierce attack should still deal damage")
		get_tree().quit(1)
		return

	var post_hint := str(root.get_node("MarginContainer/VBoxContainer/HintLabel").text)
	if "GUARD CRACKED" not in post_hint:
		push_error("Guard crack hint missing: %s" % post_hint)
		get_tree().quit(1)
		return

	print("[PHASE6_AI_SMOKE] charge and pierce behaviors passed")
	get_tree().quit(0)
