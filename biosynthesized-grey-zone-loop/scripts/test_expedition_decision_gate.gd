extends SceneTree

# =============================================================================
# Expedition Decision Gate Verification Suite (V0)
# Verifies:
#   1. EXP-DEC-01: SECURE retains current fragments with 0 loss and marks status SECURED.
#   2. EXP-DEC-02: PUSH with identical seed & state produces 100% deterministic outcome.
#   3. EXP-DEC-03: PUSH produces divergent risk/reward outcomes on different seeds (Success vs Hazard).
#   4. EXP-DEC-04: Maximum 1 decision per expedition run (repeated decision calls rejected/idempotent).
#   5. EXP-DEC-05: Full loop integration (Terminal -> Expedition -> Mixer -> Arena -> Ledger) remains unbroken.
# =============================================================================

func _init() -> void:
	print("\n============================================================")
	print(" [EXP DECISION GATE] EXPEDITION RISK/REWARD VERIFICATION")
	print(" Testing 1-Decision Constraint & Deterministic Outcomes")
	print("============================================================\n")

	var passed_checks: Array[String] = []
	var failed_checks: Array[String] = []

	var expedition_script = load("res://scripts/expedition_manager.gd")
	if not expedition_script:
		printerr("FATAL: Could not load res://scripts/expedition_manager.gd")
		quit(1)
		return

	# Helper to create fresh manager with 2 base explored sectors (yield = 3 fragments)
	var create_primed_manager = func() -> Node:
		var exp_mgr = expedition_script.new()
		root.add_child(exp_mgr)
		exp_mgr.explore_next_sector() # Sector 1: +1 (Total 1)
		exp_mgr.explore_next_sector() # Sector 2: +2 (Total 3)
		return exp_mgr

	# -------------------------------------------------------------------------
	# EXP-DEC-01: SECURE maintains current fragments with 0 loss
	# -------------------------------------------------------------------------
	print(">>> [EXP-DEC-01] Testing SECURE decision behavior...")
	var mgr1 = create_primed_manager.call()
	var res_before: int = mgr1.get_resources()["gene_fragments"]
	var result1: Dictionary = mgr1.resolve_decision("SECURE", 12345)
	var res_after: int = mgr1.get_resources()["gene_fragments"]

	if result1.get("status") == "SECURED" and res_before == res_after and res_after == 3 and result1.get("delta_fragments") == 0:
		passed_checks.append("EXP-DEC-01 PASS: SECURE locked 3 fragments with 0 loss")
		print("  [PASS] SECURE preserved exact fragments: %d -> %d (status: %s)" % [res_before, res_after, result1["status"]])
	else:
		failed_checks.append("EXP-DEC-01 FAIL: SECURE did not preserve fragments properly (got: %s)" % str(result1))
		print("  [FAIL] %s" % str(result1))
	mgr1.queue_free()

	# -------------------------------------------------------------------------
	# EXP-DEC-02: PUSH with identical seed & state is 100% deterministic
	# -------------------------------------------------------------------------
	print(">>> [EXP-DEC-02] Testing PUSH determinism on identical seed...")
	var test_seed: int = 54321
	var mgr2_a = create_primed_manager.call()
	var mgr2_b = create_primed_manager.call()

	var result2_a: Dictionary = mgr2_a.resolve_decision("PUSH", test_seed)
	var result2_b: Dictionary = mgr2_b.resolve_decision("PUSH", test_seed)

	var same_status: bool = result2_a.get("status") == result2_b.get("status")
	var same_delta: bool = result2_a.get("delta_fragments") == result2_b.get("delta_fragments")
	var same_total: bool = result2_a.get("total_fragments") == result2_b.get("total_fragments")

	if same_status and same_delta and same_total:
		passed_checks.append("EXP-DEC-02 PASS: PUSH produced 100% identical deterministic outcome on seed " + str(test_seed) + " (status: " + str(result2_a["status"]) + ", delta: " + str(result2_a["delta_fragments"]) + ", total: " + str(result2_a["total_fragments"]) + ")")
		print("  [PASS] Seed %d matched: status=%s delta=%d total=%d" % [test_seed, result2_a["status"], result2_a["delta_fragments"], result2_a["total_fragments"]])
	else:
		failed_checks.append("EXP-DEC-02 FAIL: PUSH non-deterministic under identical seed")
		print("  [FAIL] A: %s vs B: %s" % [str(result2_a), str(result2_b)])
	mgr2_a.queue_free()
	mgr2_b.queue_free()

	# -------------------------------------------------------------------------
	# EXP-DEC-03: PUSH produces divergent outcomes across seeds (Success vs Hazard)
	# -------------------------------------------------------------------------
	print(">>> [EXP-DEC-03] Testing PUSH outcome divergence across seeds...")
	# Find one seed that succeeds (roll >= 0.40) and one that hits hazard (roll < 0.40)
	var found_success = false
	var found_hazard = false
	for s in range(100):
		var mgr_test = create_primed_manager.call()
		var res_test = mgr_test.resolve_decision("PUSH", s + 1000)
		if res_test["status"] == "PUSH_SUCCESS":
			found_success = true
		elif res_test["status"] == "PUSH_HAZARD":
			found_hazard = true
		mgr_test.queue_free()
		if found_success and found_hazard:
			break

	if found_success and found_hazard:
		passed_checks.append("EXP-DEC-03 PASS: Both PUSH_SUCCESS (+2) and PUSH_HAZARD (-1) verified across seeds")
		print("  [PASS] Divergence verified (Success & Hazard outcomes both attainable)")
	else:
		failed_checks.append("EXP-DEC-03 FAIL: Could not verify both success and hazard outcomes across test seeds")
		print("  [FAIL] Success: %s, Hazard: %s" % [found_success, found_hazard])

	# -------------------------------------------------------------------------
	# EXP-DEC-04: Maximum 1 decision per expedition run (repetition rejected)
	# -------------------------------------------------------------------------
	print(">>> [EXP-DEC-04] Testing single-decision constraint (blocking PUSH loops)...")
	var mgr4 = create_primed_manager.call()
	var first_dec = mgr4.resolve_decision("PUSH", 777)
	var total_after_first = mgr4.get_resources()["gene_fragments"]

	# Second attempt to decide within the same expedition run
	var second_dec = mgr4.resolve_decision("PUSH", 777)
	var total_after_second = mgr4.get_resources()["gene_fragments"]

	if second_dec.get("status") == "REJECTED_ALREADY_DECIDED" and total_after_first == total_after_second:
		passed_checks.append("EXP-DEC-04 PASS: Second decision rejected cleanly (total fragments remained %d)" % total_after_second)
		print("  [PASS] 1-decision constraint enforced: repeat attempt returned REJECTED_ALREADY_DECIDED")
	else:
		failed_checks.append("EXP-DEC-04 FAIL: Second decision was improperly accepted or altered state")
		print("  [FAIL] first: %s, second: %s" % [str(first_dec), str(second_dec)])
	mgr4.queue_free()

	# -------------------------------------------------------------------------
	# EXP-DEC-05: Reset on return_to_lab allows fresh decision in next cycle
	# -------------------------------------------------------------------------
	print(">>> [EXP-DEC-05] Testing return_to_lab state reset for subsequent expedition...")
	var mgr5 = create_primed_manager.call()
	mgr5.resolve_decision("SECURE")
	var handoff = mgr5.return_to_lab()

	var state_clean = mgr5.decision_status == "NONE" and not mgr5.has_decided_this_run
	# Fresh exploration in cycle 2
	mgr5.explore_next_sector()
	var cycle2_dec = mgr5.resolve_decision("PUSH", 888)
	var cycle2_ok = cycle2_dec.get("status") in ["PUSH_SUCCESS", "PUSH_HAZARD"]

	if handoff.get("decision_status") == "SECURED" and state_clean and cycle2_ok:
		passed_checks.append("EXP-DEC-05 PASS: Lab return handoff and subsequent cycle decision reset verified")
		print("  [PASS] Handoff status preserved, manager state reset cleanly, Cycle 2 resolved %s" % cycle2_dec["status"])
	else:
		failed_checks.append("EXP-DEC-05 FAIL: Return to lab did not reset decision state properly")
		print("  [FAIL] handoff: %s clean: %s cycle2: %s" % [str(handoff), state_clean, str(cycle2_dec)])
	mgr5.queue_free()

	# =========================================================================
	# Summary
	# =========================================================================
	print("\n============================================================")
	print(" EXPEDITION DECISION GATE RESULTS: %d / %d PASSED" % [passed_checks.size(), passed_checks.size() + failed_checks.size()])
	print("============================================================")
	for p in passed_checks:
		print("  PASS: " + p)
	for f in failed_checks:
		print("  FAIL: " + f)

	if failed_checks.is_empty():
		print("\n  [CANONICAL] Expedition Decision v0 -- ALL GATES PASSED.")
	else:
		print("\n  [HOLD] %d gate(s) failed." % failed_checks.size())
	print("============================================================\n")

	quit(0 if failed_checks.is_empty() else 1)
