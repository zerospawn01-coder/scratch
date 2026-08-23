extends SceneTree

# =============================================================================
# Ledger Integrity Gate Verification Suite (V0)
# Verifies:
#   1. Genesis and hash chain continuity across sequential commits (Entry 1 -> 2 -> 3)
#   2. Payload tampering detection (modifying any data field causes verification failure)
#   3. Chain pointer tampering detection (altering previous_entry_hash or entry_hash fails)
#   4. Entry permutation detection (reordering ledger entries breaks monotonicity/chain)
# =============================================================================

func _init() -> void:
	print("\n============================================================")
	print(" [LEDGER INTEGRITY GATE] APPEND-ONLY HASH CHAIN VERIFICATION")
	print(" Testing Genesis Link, Monotonicity & Tamper Detection")
	print("============================================================\n")

	var passed_checks: Array[String] = []
	var failed_checks: Array[String] = []

	var registry_script = load("res://scripts/bioroid_registry.gd")
	if not registry_script:
		printerr("FATAL: Could not load res://scripts/bioroid_registry.gd")
		quit(1)
		return

	# Helper to populate 3 valid consecutive entries
	var create_populated_registry = func() -> Node:
		var reg: Node = registry_script.new()
		root.add_child(reg)

		var entries = [
			{
				"run_id": "RUN-0001",
				"bioroid_hash": "a1b2c3d4e5f60001",
				"opponent_id": "SUBJECT AF-09",
				"result": "SUPPRESSION_SUCCESS",
				"final_status": "SUPPRESSED-STABLE",
				"combat_seed": 44291,
				"turns_elapsed": 3,
				"damage_taken": 18
			},
			{
				"run_id": "RUN-0002",
				"bioroid_hash": "a1b2c3d4e5f60002",
				"opponent_id": "SUBJECT AF-09",
				"result": "SUPPRESSION_SUCCESS",
				"final_status": "SUPPRESSED-STABLE",
				"combat_seed": 44292,
				"turns_elapsed": 4,
				"damage_taken": 24
			},
			{
				"run_id": "RUN-0003",
				"bioroid_hash": "a1b2c3d4e5f60003",
				"opponent_id": "SUBJECT AF-09",
				"result": "SPECIMEN_LOST",
				"final_status": "CONTAINMENT-BREACH",
				"combat_seed": 44293,
				"turns_elapsed": 2,
				"damage_taken": 100
			}
		]

		for e in entries:
			reg.record_audit_entry(e)
		return reg

	# -------------------------------------------------------------------------
	# LEDGER-GATE-01: Genesis & Chain Continuity (3 Valid Entries)
	# -------------------------------------------------------------------------
	print(">>> [LEDGER-GATE-01] Validating unperturbed 3-entry cryptographic hash chain...")
	var reg1 = create_populated_registry.call()
	var verify1: Dictionary = reg1.verify_ledger_integrity()

	var genesis_ok: bool = reg1.audit_ledger[0]["previous_entry_hash"] == reg1.GENESIS_HASH
	var chain_1_to_2: bool = reg1.audit_ledger[1]["previous_entry_hash"] == reg1.audit_ledger[0]["entry_hash"]
	var chain_2_to_3: bool = reg1.audit_ledger[2]["previous_entry_hash"] == reg1.audit_ledger[1]["entry_hash"]
	var valid_overall: bool = verify1.get("is_valid", false) and verify1.get("verified_count", 0) == 3

	if genesis_ok and chain_1_to_2 and chain_2_to_3 and valid_overall:
		passed_checks.append("LEDGER-GATE-01 PASS: Genesis linked and 3-entry chain verified (verified_count=3)")
		print("  [PASS] Genesis: %s... | Links verified across 3 entries" % reg1.GENESIS_HASH.substr(0, 12))
	else:
		failed_checks.append("LEDGER-GATE-01 FAIL: Chain integrity failed on valid data (error: %s)" % verify1.get("error", "unknown"))
		print("  [FAIL] Genesis: %s link1: %s link2: %s valid: %s" % [genesis_ok, chain_1_to_2, chain_2_to_3, valid_overall])
	reg1.queue_free()

	# -------------------------------------------------------------------------
	# LEDGER-GATE-02: Payload Tamper Detection (Modify damage_taken in Entry #2)
	# -------------------------------------------------------------------------
	print(">>> [LEDGER-GATE-02] Testing payload tampering detection...")
	var reg2 = create_populated_registry.call()
	reg2.audit_ledger[1]["damage_taken"] = 999 # Alter 1 field in committed ledger

	var verify2: Dictionary = reg2.verify_ledger_integrity()
	if not verify2.get("is_valid", true) and verify2.get("broken_index", -1) == 2:
		passed_checks.append("LEDGER-GATE-02 PASS: Payload tamper in Entry #2 detected cleanly (broken_index=2)")
		print("  [PASS] Detected payload mutation at index 2: %s" % verify2.get("error", ""))
	else:
		failed_checks.append("LEDGER-GATE-02 FAIL: Payload tamper was not caught at expected index")
		print("  [FAIL] verify result: %s" % str(verify2))
	reg2.queue_free()

	# -------------------------------------------------------------------------
	# LEDGER-GATE-03: Chain Link Tamper Detection (Modify previous_entry_hash)
	# -------------------------------------------------------------------------
	print(">>> [LEDGER-GATE-03] Testing previous_entry_hash tampering detection...")
	var reg3 = create_populated_registry.call()
	reg3.audit_ledger[2]["previous_entry_hash"] = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"

	var verify3: Dictionary = reg3.verify_ledger_integrity()
	if not verify3.get("is_valid", true) and verify3.get("broken_index", -1) == 3:
		passed_checks.append("LEDGER-GATE-03 PASS: Broken predecessor hash detected at Entry #3 (broken_index=3)")
		print("  [PASS] Detected broken chain link at index 3: %s" % verify3.get("error", ""))
	else:
		failed_checks.append("LEDGER-GATE-03 FAIL: Broken predecessor hash was not caught at index 3")
		print("  [FAIL] verify result: %s" % str(verify3))
	reg3.queue_free()

	# -------------------------------------------------------------------------
	# LEDGER-GATE-04: Order Permutation Detection (Swap Entry #1 and Entry #2)
	# -------------------------------------------------------------------------
	print(">>> [LEDGER-GATE-04] Testing entry reordering/permutation detection...")
	var reg4 = create_populated_registry.call()
	var temp = reg4.audit_ledger[0]
	reg4.audit_ledger[0] = reg4.audit_ledger[1]
	reg4.audit_ledger[1] = temp

	var verify4: Dictionary = reg4.verify_ledger_integrity()
	if not verify4.get("is_valid", true) and verify4.get("broken_index", -1) != -1:
		passed_checks.append("LEDGER-GATE-04 PASS: Entry permutation rejected cleanly (detected at index %d)" % verify4.get("broken_index", -1))
		print("  [PASS] Detected entry reorder: %s" % verify4.get("error", ""))
	else:
		failed_checks.append("LEDGER-GATE-04 FAIL: Permuted ledger was unexpectedly accepted")
		print("  [FAIL] verify result: %s" % str(verify4))
	reg4.queue_free()

	# =========================================================================
	# Summary
	# =========================================================================
	print("\n============================================================")
	print(" LEDGER INTEGRITY GATE RESULTS: %d / %d PASSED" % [passed_checks.size(), passed_checks.size() + failed_checks.size()])
	print("============================================================")
	for p in passed_checks:
		print("  PASS: " + p)
	for f in failed_checks:
		print("  FAIL: " + f)

	if failed_checks.is_empty():
		print("\n  [CANONICAL] Append-Only Cryptographic Ledger Integrity v0 -- ALL GATES PASSED.")
	else:
		print("\n  [HOLD] %d gate(s) failed." % failed_checks.size())
	print("============================================================\n")

	quit(0 if failed_checks.is_empty() else 1)
