extends SceneTree
class_name RunAllSmokeTests

func _init() -> void:
	var test_specs := [
		{"name": "Phase5JuiceSmokeTest", "script": "res://scripts/test/phase5_juice_smoke_test.gd"},
		{"name": "Phase6EndStateUISmokeTest", "script": "res://scripts/ui/phase6_end_state_ui_smoke_test.gd"},
		{"name": "Phase6EnemyAISmokeTest", "script": "res://scripts/ui/phase6_enemy_ai_smoke_test.gd"},
		{"name": "Phase6ReactionSmokeTest", "script": "res://scripts/ui/phase6_reaction_smoke_test.gd"},
		{"name": "Phase6TimeoutSmokeTest", "script": "res://scripts/ui/phase6_timeout_smoke_test.gd"},
		{"name": "Phase5Phase6PersistenceSmokeTest", "script": "res://scripts/test/phase5_phase6_persistence_smoke_test.gd"},
		{"name": "Phase6CombatDeepSmokeTest", "script": "res://scripts/test/phase6_combat_deep_smoke_test.gd"},
		{"name": "Phase7MapNavigationSmokeTest", "script": "res://scripts/test/phase7_map_navigation_smoke_test.gd"}
	]
	
	var executable := OS.get_executable_path()
	var project_path := ProjectSettings.globalize_path("res://")
	var all_passed := true
	var host_scene := "res://scenes/test/smoke_test_host.tscn"
		
	print("\n==================================================")
	print("[TEST RUNNER] Starting Master Smoke Test Suite...")
	print("==================================================\n")
	
	for spec in test_specs:
		print("[TEST RUNNER] Running: ", spec["script"])
		var output := []
		var args := ["--headless", "--path", project_path, "--scene", host_scene, "--", "--test=%s" % spec["script"]]
		var exit_code := OS.execute(executable, args, output, true)
		
		if output.size() > 0:
			var lines = output[0].split("\n")
			for line in lines:
				var t = line.strip_edges()
				if t != "":
					print("  | ", t)
					
		if exit_code != 0:
			printerr("[TEST RUNNER] FAILED: ", spec["script"], " (Exit Code: ", exit_code, ")\n")
			all_passed = false
		else:
			print("[TEST RUNNER] PASSED: ", spec["script"], "\n")
			
	print("==================================================")
	if all_passed:
		print("[TEST RUNNER] ALL TESTS PASSED.")
		quit(0)
	else:
		printerr("[TEST RUNNER] SOME TESTS FAILED.")
		quit(1)
