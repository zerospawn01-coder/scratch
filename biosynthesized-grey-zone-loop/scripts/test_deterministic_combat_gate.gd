extends SceneTree

# =============================================================================
# Deterministic Combat RNG Gate Suite (V0)
# Verifies:
#   1. Same combat seed produces 100% identical damage rolls, crits, and vital states.
#   2. Different combat seeds produce divergent outcomes.
#   3. Isolation: Global RNG state is not leaked or relied upon for combat math.
# =============================================================================

func _init() -> void:
	print("\n============================================================")
	print(" [COMBAT RNG GATE] DETERMINISTIC ARENA COMBAT VERIFICATION")
	print(" Testing Seeded Combat Math & Determinism")
	print("============================================================\n")

	var passed_checks: Array[String] = []
	var failed_checks: Array[String] = []

	var arena_script = load("res://scripts/arena_battle_manager.gd")
	if not arena_script:
		printerr("FATAL: Could not load res://scripts/arena_battle_manager.gd")
		quit(1)
		return

	# --- Helper to simulate a deterministic battle sequence ---
	var run_simulation = func(seed_val: int) -> Dictionary:
		var arena = arena_script.new()
		var attacker = Node3D.new()
		var defender = Node3D.new()
		root.add_child(attacker)
		root.add_child(defender)
		root.add_child(arena)

		arena.deployment_payload = {
			"run_id": "RUN-RNG-TEST",
			"combat_seed": seed_val,
			"bioroid_id": "BIO-TEST-001",
			"bioroid_name": "ALDEN",
			"bioroid_hash": "hash_deterministic_combat_001",
			"dna_ratio": {"ald": 60, "kln": 25, "chm": 15},
			"stats": {
				"vital_integrity": 100,
				"neural_control": 88,
				"mutation_load": 12,
				"core_stress": 35,
				"atk": 30,
				"ep": 60
			}
		}
		arena._initialize_from_payload()
		arena.player_stats["node"] = attacker
		arena.enemy_stats["node"] = defender

		var damages: Array[int] = []
		var crits: Array[bool] = []

		arena.combatant_damaged.connect(func(_target: Node3D, dmg: int, is_crit: bool):
			damages.append(dmg)
			crits.append(is_crit)
		)

		# Execute a fixed sequence of 4 attacks
		arena._apply_attack(arena.player_stats, arena.enemy_stats, 1.0, 0.25)
		arena._apply_attack(arena.enemy_stats, arena.player_stats, 1.0, 0.25)
		arena._apply_attack(arena.player_stats, arena.enemy_stats, 1.2, 0.25)
		arena._apply_attack(arena.enemy_stats, arena.player_stats, 1.2, 0.25)

		var result = {
			"damages": damages,
			"crits": crits,
			"player_vital": arena.player_stats["vital_integrity"],
			"enemy_vital": arena.enemy_stats["vital_integrity"],
			"total_damage_taken": arena.total_damage_taken
		}

		attacker.queue_free()
		defender.queue_free()
		arena.queue_free()
		return result

	# -------------------------------------------------------------------------
	# RNG-GATE-01: Identical Seed Repetition Test (Seed: 44291)
	# -------------------------------------------------------------------------
	print(">>> [RNG-GATE-01] Running simulation with Seed 44291 (Run A & Run B)...")
	var sim_a1 = run_simulation.call(44291)
	var sim_a2 = run_simulation.call(44291)

	var damages_match = (sim_a1["damages"] == sim_a2["damages"])
	var crits_match = (sim_a1["crits"] == sim_a2["crits"])
	var vitals_match = (sim_a1["player_vital"] == sim_a2["player_vital"] and sim_a1["enemy_vital"] == sim_a2["enemy_vital"])

	if damages_match and crits_match and vitals_match:
		passed_checks.append("RNG-GATE-01 PASS: 100% identical sequence for Seed 44291 (Damages: " + str(sim_a1["damages"]) + ", Crits: " + str(sim_a1["crits"]) + ")")
		print("  [PASS] Seed 44291 reproduced exactly: Damages=" + str(sim_a1["damages"]) + " Vitals=(P:" + str(sim_a1["player_vital"]) + ", E:" + str(sim_a1["enemy_vital"]) + ")")
	else:
		failed_checks.append("RNG-GATE-01 FAIL: Non-deterministic combat rolls detected under same seed")
		print("  [FAIL] Run A: " + str(sim_a1) + " vs Run B: " + str(sim_a2))

	# -------------------------------------------------------------------------
	# RNG-GATE-02: Divergence with Different Seed (Seed: 99901)
	# -------------------------------------------------------------------------
	print(">>> [RNG-GATE-02] Running simulation with Divergent Seed 99901...")
	var sim_b = run_simulation.call(99901)

	var is_divergent = (sim_a1["damages"] != sim_b["damages"] or sim_a1["player_vital"] != sim_b["player_vital"] or sim_a1["enemy_vital"] != sim_b["enemy_vital"])

	if is_divergent:
		passed_checks.append("RNG-GATE-02 PASS: Seed 99901 produced divergent combat results (Damages: %s)" % str(sim_b["damages"]))
		print("  [PASS] Divergence verified: Seed 44291 Damages=%s vs Seed 99901 Damages=%s" % [
			str(sim_a1["damages"]), str(sim_b["damages"])
		])
	else:
		failed_checks.append("RNG-GATE-02 FAIL: Different seeds unexpectedly produced identical rolls")
		print("  [FAIL] Seed 44291 and 99901 were identical")

	# -------------------------------------------------------------------------
	# RNG-GATE-03: Global RNG Isolation
	# -------------------------------------------------------------------------
	print(">>> [RNG-GATE-03] Testing Global RNG isolation...")
	# Perturb global RNG multiple times
	for i in range(50):
		randf()
		randi()

	var sim_a3 = run_simulation.call(44291)
	if sim_a3["damages"] == sim_a1["damages"] and sim_a3["crits"] == sim_a1["crits"]:
		passed_checks.append("RNG-GATE-03 PASS: Global RNG mutation does not alter seeded combat roll sequence")
		print("  [PASS] Global RNG perturbation had zero effect on seeded simulation")
	else:
		failed_checks.append("RNG-GATE-03 FAIL: Global RNG state leaked into combat calculations")
		print("  [FAIL] Perturbation altered result: %s vs %s" % [str(sim_a3["damages"]), str(sim_a1["damages"])])

	# =========================================================================
	# Summary
	# =========================================================================
	print("\n============================================================")
	print(" COMBAT RNG GATE RESULTS: %d / %d PASSED" % [passed_checks.size(), passed_checks.size() + failed_checks.size()])
	print("============================================================")
	for p in passed_checks:
		print("  PASS: " + p)
	for f in failed_checks:
		print("  FAIL: " + f)

	if failed_checks.is_empty():
		print("\n  [CANONICAL] Deterministic Combat RNG v0 -- ALL GATES PASSED.")
	else:
		print("\n  [HOLD] %d gate(s) failed." % failed_checks.size())
	print("============================================================\n")

	quit(0 if failed_checks.is_empty() else 1)
