extends Node

func _ready() -> void:
	print("[TEST] Phase7MapNavigationSmokeTest starting...")
	
	# Mock GlobalData
	GlobalData.sector_states = {
		"core_chamber": "ONLINE",
		"expedition_gate": "ONLINE",
		"material_locker": "LOCKED",
		"observation_cage": "COLLAPSED",
		"proto_vat": "CLEARED",
		"research_log": "ONLINE",
		"arena_terminal": "LOCKED"
	}
	
	var MapScene = preload("res://scenes/ui/ui_map_phase7.tscn")
	var map_inst = MapScene.instantiate()
	add_child(map_inst)
	
	# wait 1 frame for ready to execute
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Test 1: Verify buttons are created and states are applied
	assert(map_inst.node_buttons.size() == 7, "Map should generate 7 nodes")
	var core_btn = map_inst.node_buttons["core_chamber"]
	var locker_btn = map_inst.node_buttons["material_locker"]
	var proto_btn = map_inst.node_buttons["proto_vat"]
	
	assert(core_btn.disabled == false, "Core chamber should be ONLINE and enabled")
	assert(locker_btn.disabled == true, "Material locker should be LOCKED and disabled")
	assert(proto_btn.disabled == false, "Proto vat should be CLEARED and enabled")
	print("[TEST] Step 1 Passed: Map nodes instantiated with correct states.")
	
	# Test 2: Test complete_sector logic in GlobalData
	GlobalData.complete_sector("research_log")
	assert(GlobalData.sector_states["research_log"] == "CLEARED", "Research log should be CLEARED")
	assert(GlobalData.sector_states["arena_terminal"] == "ONLINE", "Arena terminal should be unlocked to ONLINE")
	print("[TEST] Step 2 Passed: complete_sector logic correctly unlocks next nodes.")
	
	map_inst.queue_free()
	print("[TEST] Phase7MapNavigationSmokeTest passed!")
	get_tree().quit(0)
