extends Node
class_name Phase5Phase6PersistenceSmokeTest

const MENU_SCENE_PATH := "res://scenes/ui/ui_premium_phase5.tscn"
const GAME_SCENE_PATH := "res://scenes/game/game_scene.tscn"
const COMBAT_SCENE_PATH := "res://scenes/ui/ui_glitch_phase6.tscn"
const SAVE_PATH := "user://neo_sovereign_save.cfg"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	await get_tree().process_frame

	var menu_scene := load(MENU_SCENE_PATH) as PackedScene
	_assert_bool(menu_scene != null, "Failed to load menu scene")

	get_tree().change_scene_to_packed(menu_scene)
	await _wait_for_scene(MENU_SCENE_PATH, "menu scene")

	var menu_root := get_tree().current_scene
	_assert_scene(menu_root, MENU_SCENE_PATH, "menu scene")

	menu_root.call("_on_start_pressed")
	var MAP_SCENE_PATH := "res://scenes/ui/ui_map_phase7.tscn"
	await _wait_for_scene(MAP_SCENE_PATH, "map scene after START SYSTEM")

	var map_root := get_tree().current_scene
	_assert_scene(map_root, MAP_SCENE_PATH, "map scene after START SYSTEM")
	
	map_root.call("_on_node_pressed", "core_chamber", "hub")
	await _wait_for_scene(GAME_SCENE_PATH, "game scene after Core Chamber")

	var game_root := get_tree().current_scene
	_assert_scene(game_root, GAME_SCENE_PATH, "game scene after Core Chamber")

	GlobalData.data = 74.0
	GlobalData.miners_owned = 3
	GlobalData.hp_level = 2
	GlobalData.damage_level = 1
	GlobalData.save_data()

	game_root.call("_update_ui")
	game_root.call("_on_deploy_pressed")
	await _wait_for_scene(MAP_SCENE_PATH, "map scene after RETURN TO MAP")
	map_root = get_tree().current_scene
	
	map_root.call("_on_node_pressed", "expedition_gate", "combat")
	await _wait_for_scene(COMBAT_SCENE_PATH, "combat scene after selecting node")

	var combat_root := get_tree().current_scene
	_assert_scene(combat_root, COMBAT_SCENE_PATH, "combat scene after selecting node")

	combat_root.call("_on_quit_pressed")
	await _wait_for_scene(MAP_SCENE_PATH, "map scene after EXIT combat")

	var returned_root := get_tree().current_scene
	_assert_scene(returned_root, MAP_SCENE_PATH, "map scene after EXIT combat")
	
	returned_root.call("_on_node_pressed", "core_chamber", "hub")
	await _wait_for_scene(GAME_SCENE_PATH, "game scene returned")
	var returned_game := get_tree().current_scene

	_assert_bool(is_equal_approx(GlobalData.data, 74.0), "GlobalData.data should survive roundtrip")
	_assert_bool(GlobalData.miners_owned == 3, "GlobalData.miners_owned should survive roundtrip")
	_assert_bool(GlobalData.hp_level == 2, "GlobalData.hp_level should survive roundtrip")
	_assert_bool(GlobalData.damage_level == 1, "GlobalData.damage_level should survive roundtrip")

	var data_label := returned_game.get_node("MarginContainer/RootVBox/MainContent/Header/DataLabel") as Label
	_assert_bool(data_label != null, "Returned game scene should expose DataLabel")
	_assert_bool(data_label.text == "DATA: 74", "Returned game scene DATA label should show 74")

	var cfg := ConfigFile.new()
	_assert_bool(cfg.load(SAVE_PATH) == OK, "Save file should load after roundtrip")
	_assert_bool(is_equal_approx(float(cfg.get_value("resources", "data", -1.0)), 74.0), "Save file data should be 74")
	_assert_bool(int(cfg.get_value("resources", "miners_owned", -1)) == 3, "Save file miners should be 3")
	_assert_bool(int(cfg.get_value("upgrades", "hp_level", -1)) == 2, "Save file hp_level should be 2")
	_assert_bool(int(cfg.get_value("upgrades", "damage_level", -1)) == 1, "Save file damage_level should be 1")

	print("[PHASE5_PHASE6_PERSISTENCE] roundtrip assertions passed")
	get_tree().quit()

func _wait_for_scene(scene_path: String, label: String) -> void:
	for _i in range(20):
		await get_tree().process_frame
		var current := get_tree().current_scene
		if current != null and str(current.scene_file_path) == scene_path:
			return
	push_error("Timed out waiting for %s" % label)
	get_tree().quit(1)

func _assert_scene(node: Node, scene_path: String, label: String) -> void:
	_assert_bool(node != null, "Missing %s" % label)
	_assert_bool(str(node.scene_file_path) == scene_path, "%s mismatch" % label)

func _assert_bool(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
