extends Node

var scene_instance: Control
var test_passed: bool = false
var test_timeout: float = 15.0
var elapsed_time: float = 0.0

var step_id: int = 0
var step_timer: float = 0.0

func _ready() -> void:
	print("[TEST] Phase6CombatDeepSmokeTest starting...")
	Engine.time_scale = 10.0
	
	var packed_scene = load("res://scenes/ui/ui_glitch_phase6.tscn")
	scene_instance = packed_scene.instantiate()
	add_child(scene_instance)
	
	# Override settings for predictable test
	scene_instance._rng.seed = 42
	scene_instance._difficulty_index = 0 # NORMAL
	
	# Ensure GlobalData is ready
	GlobalData.hp_level = 1
	GlobalData.damage_level = 1
	
	# Start test sequence
	scene_instance._on_start_pressed()
	step_id = 1

func _process(delta: float) -> void:
	elapsed_time += delta
	if elapsed_time > test_timeout:
		print("[TEST] ERROR: Phase6CombatDeepSmokeTest timed out!")
		Engine.time_scale = 1.0
		get_tree().quit(1)
		return
		
	if not scene_instance or not is_instance_valid(scene_instance):
		return
		
	step_timer += delta
	match step_id:
		1: # Test 1: INTENT RED (Wait until < 0.8s)
			if scene_instance._enemy_attack_timer < 0.8:
				var label_color = scene_instance.enemy_state_label.get_theme_color("font_color")
				if label_color == Color(1.0, 0.4, 0.4):
					print("[TEST] Step 1 Passed: Intent label turns red.")
					step_id = 2
					step_timer = 0.0
				else:
					print("[TEST] ERROR: Intent label is not red! Color: ", label_color)
					Engine.time_scale = 1.0
					get_tree().quit(1)
					
		2: # Test 2: NORMAL GUARD (Late Guard)
			# Fast forward to attack, but set guard timestamp to 0.6s ago (late)
			if step_timer > 0.1:
				scene_instance._enemy_intent_id = "lance"
				scene_instance._enemy_intent_charge_up = false
				scene_instance._enemy_intent_multiplier = 1.0
				scene_instance._enemy_intent_guard_factor = 0.35 # Success factor
				scene_instance._guard_active = true
				scene_instance._guard_timestamp = scene_instance._elapsed_seconds() - 0.6
				scene_instance._combo = 5 # Give some combo
				scene_instance._resolve_enemy_attack()
				step_id = 3
				step_timer = 0.0
				
		3: # Check Normal Guard Result
			if scene_instance._combo == 0:
				print("[TEST] Step 2 Passed: LATE GUARD correctly broke combo.")
				step_id = 4
				step_timer = 0.0
			else:
				print("[TEST] ERROR: LATE GUARD did not break combo! Combo: ", scene_instance._combo)
				Engine.time_scale = 1.0
				get_tree().quit(1)

		4: # Test 3: PERFECT GUARD (Counter)
			if step_timer > 0.1:
				scene_instance._guard_cooldown_left = 0.0 # reset cooldown
				scene_instance._guard_active = true
				scene_instance._guard_timestamp = scene_instance._elapsed_seconds() - 0.2
				scene_instance._enemy_intent_id = "lance"
				scene_instance._enemy_intent_charge_up = false
				scene_instance._enemy_intent_multiplier = 1.0
				scene_instance._enemy_intent_guard_factor = 0.35
				scene_instance._combo = 5
				var old_score = scene_instance._score
				scene_instance.set_meta("old_score", old_score)
				scene_instance._resolve_enemy_attack()
				step_id = 5
				step_timer = 0.0
				
		5: # Check Perfect Guard Result
			if scene_instance._combo > 0 and scene_instance._score > scene_instance.get_meta("old_score"):
				print("[TEST] Step 3 Passed: PERFECT GUARD maintained combo and scored counter.")
				step_id = 6
				step_timer = 0.0
			else:
				print("[TEST] ERROR: PERFECT GUARD failed! Combo: ", scene_instance._combo)
				Engine.time_scale = 1.0
				get_tree().quit(1)
					
		6: # Test 4: BURST INTERRUPT & STUN
			if step_timer > 0.1:
				scene_instance._enemy_intent_charge_up = true
				scene_instance._integrity = 50.0 # Ensure enough HP for burst
				scene_instance._burst_cooldown_left = 0.0
				scene_instance._perform_burst()
				step_id = 7
				step_timer = 0.0
				
		7: # Check Stun Result
			if step_timer > 0.1:
				if scene_instance._enemy_intent_id == "stunned" and scene_instance._enemy_attack_timer > 2.0:
					print("[TEST] Step 4 Passed: BURST caused STUN.")
					step_id = 8
					step_timer = 0.0
				else:
					print("[TEST] ERROR: BURST did not cause STUN. Intent: ", scene_instance._enemy_intent_id)
					Engine.time_scale = 1.0
					get_tree().quit(1)
					
		8: # Test 5: STUN IMMUNITY
			if step_timer > 0.1:
				# Resolve the stun attack to get immunity
				scene_instance._resolve_enemy_attack()
				
				if scene_instance._stun_immunity_left > 0.0:
					# Now try to stun again on a charge
					scene_instance._enemy_intent_charge_up = true
					scene_instance._integrity = 50.0
					scene_instance._burst_cooldown_left = 0.0
					scene_instance._perform_burst()
					
					if scene_instance._enemy_intent_id != "stunned":
						print("[TEST] Step 5 Passed: STUN IMMUNITY prevented chain stun.")
						test_passed = true
						Engine.time_scale = 1.0
						get_tree().quit(0)
					else:
						print("[TEST] ERROR: STUN IMMUNITY failed. Enemy was stunned again.")
						Engine.time_scale = 1.0
						get_tree().quit(1)
				else:
					print("[TEST] ERROR: STUN IMMUNITY was not applied after recovery.")
					Engine.time_scale = 1.0
					get_tree().quit(1)
