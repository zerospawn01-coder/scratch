extends SceneTree

# =============================================================================
# VFX Gate Verification Suite -- Arena Game Feel Safety Tests
# 7 conditions that must pass before Game Feel v0 is declared canonical.
# Principle: VFX must never corrupt logic state or leave runtime residue.
# =============================================================================

func _init() -> void:
	print("\n============================================================")
	print(" [VFX GATE] AETHER FOUNTAIN ARENA GAME FEEL SAFETY SUITE")
	print(" Testing 7 VFX Regression Conditions")
	print("============================================================\n")

	var passed_checks: Array[String] = []
	var failed_checks: Array[String] = []

	# -- Setup: create a minimal ArenaBattleManager node in the tree --
	var arena_script = load("res://scripts/arena_battle_manager.gd")
	var arena: Node = arena_script.new()
	arena.name = "ArenaBattleManager"

	var attacker_dummy := Node3D.new()
	attacker_dummy.name = "AldenDummy"
	attacker_dummy.position = Vector3(-2.5, 0, 0)

	var defender_dummy := Node3D.new()
	defender_dummy.name = "LambdaDummy"
	defender_dummy.position = Vector3(2.5, 0, 0)

	root.add_child(attacker_dummy)
	root.add_child(defender_dummy)
	root.add_child(arena)

	arena.player_stats = {
		"id": "BIO-GATE-TEST-P",
		"name": "ALDEN TEST",
		"vital_integrity": 100,
		"mutation_load": 10,
		"core_stress": 20,
		"atk": 30,
		"neural_control": 80,
		"ep": 60,
		"node": attacker_dummy
	}
	arena.enemy_stats = {
		"id": "SUBJECT-GATE-TEST-E",
		"name": "LAMBDA TEST",
		"vital_integrity": 100,
		"hostility_index": 70,
		"mutation_surge": false,
		"atk": 20,
		"node": defender_dummy
	}
	arena.is_in_battle = true
	arena.is_player_turn = true

	var initial_node_count: int = root.get_child_count()

	# -------------------------------------------------------------------------
	# VFX-GATE-01: Attacker Tween returns to origin after lunge
	# -------------------------------------------------------------------------
	print(">>> [VFX-GATE-01] Lunge Tween: attacker returns to origin...")
	var orig_attacker_pos: Vector3 = attacker_dummy.position
	arena._apply_attack(arena.player_stats, arena.enemy_stats, 1.0, 0.1)
	await create_timer(0.55, true, false, true).timeout
	var attacker_pos_diff = (attacker_dummy.position - orig_attacker_pos).length()
	if attacker_pos_diff < 0.05:
		passed_checks.append("VFX-GATE-01 PASS: Attacker returned to origin (drift=%.4f)" % attacker_pos_diff)
		print("  [PASS] drift=%.4f" % attacker_pos_diff)
	else:
		failed_checks.append("VFX-GATE-01 FAIL: drift=%.4f (expected <0.05)" % attacker_pos_diff)
		print("  [FAIL] drift=%.4f" % attacker_pos_diff)

	# -------------------------------------------------------------------------
	# VFX-GATE-02: Defender knockback Tween returns to origin
	# -------------------------------------------------------------------------
	print(">>> [VFX-GATE-02] Knockback Tween: defender returns to origin...")
	arena.enemy_stats["vital_integrity"] = 100
	var orig_defender_pos: Vector3 = defender_dummy.position
	arena._apply_attack(arena.player_stats, arena.enemy_stats, 1.0, 0.1)
	await create_timer(0.55, true, false, true).timeout
	var defender_pos_diff = (defender_dummy.position - orig_defender_pos).length()
	if defender_pos_diff < 0.05:
		passed_checks.append("VFX-GATE-02 PASS: Defender returned to origin (drift=%.4f)" % defender_pos_diff)
		print("  [PASS] drift=%.4f" % defender_pos_diff)
	else:
		failed_checks.append("VFX-GATE-02 FAIL: drift=%.4f (expected <0.05)" % defender_pos_diff)
		print("  [FAIL] drift=%.4f" % defender_pos_diff)

	# -------------------------------------------------------------------------
	# VFX-GATE-03: Engine.time_scale restores to 1.0 after hitstop
	# -------------------------------------------------------------------------
	print(">>> [VFX-GATE-03] Hitstop: time_scale must restore to 1.0...")
	Engine.time_scale = 1.0
	arena.enemy_stats["vital_integrity"] = 100
	arena._apply_attack(arena.player_stats, arena.enemy_stats, 1.0, 0.1)
	await create_timer(0.30, true, false, true).timeout
	if abs(Engine.time_scale - 1.0) < 0.01:
		passed_checks.append("VFX-GATE-03 PASS: time_scale=%.3f" % Engine.time_scale)
		print("  [PASS] time_scale=%.3f" % Engine.time_scale)
	else:
		failed_checks.append("VFX-GATE-03 FAIL: time_scale=%.3f -- LEAKED!" % Engine.time_scale)
		print("  [FAIL] time_scale=%.3f" % Engine.time_scale)
		Engine.time_scale = 1.0

	# -------------------------------------------------------------------------
	# VFX-GATE-04: Burst input (8 hits) -- no Tween accumulation or time_scale leak
	# -------------------------------------------------------------------------
	print(">>> [VFX-GATE-04] Burst (8 hits): no leak after rapid-fire...")
	arena.enemy_stats["vital_integrity"] = 100
	for i in range(8):
		arena._apply_attack(arena.player_stats, arena.enemy_stats, 1.0, 0.1)
	await create_timer(0.65, true, false, true).timeout
	if abs(Engine.time_scale - 1.0) < 0.01:
		passed_checks.append("VFX-GATE-04 PASS: time_scale=%.3f after 8-hit burst" % Engine.time_scale)
		print("  [PASS] time_scale=%.3f" % Engine.time_scale)
	else:
		failed_checks.append("VFX-GATE-04 FAIL: time_scale=%.3f leaked after burst" % Engine.time_scale)
		print("  [FAIL] time_scale=%.3f" % Engine.time_scale)
		Engine.time_scale = 1.0

	# -------------------------------------------------------------------------
	# VFX-GATE-05: Label3D popup is queue_free'd after lifetime
	# -------------------------------------------------------------------------
	print(">>> [VFX-GATE-05] Damage popup: Label3D freed after 1.1s...")
	arena.enemy_stats["vital_integrity"] = 100
	var pre_popup_count: int = root.get_child_count()
	arena._spawn_damage_popup(defender_dummy, 42, false)
	await create_timer(1.1, true, false, true).timeout
	var post_popup_count: int = root.get_child_count()
	if post_popup_count <= pre_popup_count:
		passed_checks.append("VFX-GATE-05 PASS: Label3D freed (nodes: %d -> %d)" % [pre_popup_count, post_popup_count])
		print("  [PASS] nodes %d -> %d" % [pre_popup_count, post_popup_count])
	else:
		failed_checks.append("VFX-GATE-05 FAIL: %d Label3D leaked" % (post_popup_count - pre_popup_count))
		print("  [FAIL] %d labels leaked" % (post_popup_count - pre_popup_count))

	# -------------------------------------------------------------------------
	# VFX-GATE-06: CPUParticles3D does not exceed _max_particles_allowed
	# -------------------------------------------------------------------------
	print(">>> [VFX-GATE-06] Particle cap: must not exceed max limit of 12...")
	arena._active_particle_count = 0
	for i in range(20):
		arena._spawn_impact_particles(defender_dummy, true, false)
	var final_particle_count: int = arena._active_particle_count
	if final_particle_count <= arena._max_particles_allowed:
		passed_checks.append("VFX-GATE-06 PASS: Particle count %d <= cap %d" % [final_particle_count, arena._max_particles_allowed])
		print("  [PASS] %d particles (cap=%d)" % [final_particle_count, arena._max_particles_allowed])
	else:
		failed_checks.append("VFX-GATE-06 FAIL: %d particles exceeded cap %d" % [final_particle_count, arena._max_particles_allowed])
		print("  [FAIL] %d > cap %d" % [final_particle_count, arena._max_particles_allowed])

	# -------------------------------------------------------------------------
	# VFX-GATE-07: Audit Log values unchanged after VFX execution
	# -------------------------------------------------------------------------
	print(">>> [VFX-GATE-07] Audit Log immutability: ledger must not be mutated by VFX...")
	var registry_script = load("res://scripts/bioroid_registry.gd")
	var registry: Node = registry_script.new()
	registry.name = "BioroidRegistry"
	root.add_child(registry)

	var reference_audit: Dictionary = {
		"run_id": "VFX-GATE-AUDIT-001",
		"result": "SUPPRESSED-STABLE",
		"damage_taken": 0,
		"turns": 0,
		"interventions": [],
		"cause": "PRE-VFX BASELINE"
	}
	registry.record_audit_entry(reference_audit)
	var committed_before: int = registry.get_audit_record_count()
	var record_before: Dictionary = registry.get_latest_audit_entry()

	# Fire VFX -- must have zero side effect on registry
	arena._spawn_damage_popup(defender_dummy, 99, true)
	arena._spawn_impact_particles(defender_dummy, false, true)
	await create_timer(0.2, true, false, true).timeout

	var committed_after: int = registry.get_audit_record_count()
	var record_after: Dictionary = registry.get_latest_audit_entry()

	var records_unchanged: bool = (committed_before == committed_after)
	var values_unchanged: bool = (record_before.get("run_id") == record_after.get("run_id") and record_before.get("result") == record_after.get("result"))

	if records_unchanged and values_unchanged:
		passed_checks.append("VFX-GATE-07 PASS: Ledger intact (count=%d, result=%s)" % [committed_after, record_after.get("result", "?")])
		print("  [PASS] ledger intact")
	else:
		failed_checks.append("VFX-GATE-07 FAIL: Ledger mutated by VFX (before=%d after=%d)" % [committed_before, committed_after])
		print("  [FAIL] ledger mutated!")

	# =========================================================================
	# Summary
	# =========================================================================
	print("\n============================================================")
	print(" VFX GATE RESULTS: %d / %d PASSED" % [passed_checks.size(), passed_checks.size() + failed_checks.size()])
	print("============================================================")
	for p in passed_checks:
		print("  PASS: " + p)
	for f in failed_checks:
		print("  FAIL: " + f)

	if failed_checks.is_empty():
		print("\n  [CANONICAL] Arena Game Feel v0 -- ALL VFX GATES PASSED.")
		print("  time_scale safe | Tween clean | Popup GC | Particle capped | Ledger intact")
	else:
		print("\n  [HOLD] %d gate(s) failed. Fix before promoting to canonical." % failed_checks.size())

	print("============================================================\n")
	quit()


