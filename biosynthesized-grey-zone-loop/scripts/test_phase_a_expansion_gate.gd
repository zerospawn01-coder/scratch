extends SceneTree

# =============================================================================
# Phase A Verification Gate — Ledger Hash-Chain & Expedition Expansion Gate
# Verifies:
#   1. Cryptographic Hash-Chain construction and previous_hash linkage
#   2. Mathematical verification with verify_ledger_integrity()
#   3. Fault-injection: intentional tampering triggers fail-closed HASH_CORRUPTION
#   4. Parametric Expedition directives (HARVEST, DEEP_SCAN, PURGE) & contamination
# =============================================================================

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("\n============================================================")
	print(" [PHASE A GATE] LEDGER HASH-CHAIN & EXPEDITION EVENT GATE")
	print("============================================================")

	var registry_script = load("res://scripts/bioroid_registry.gd")
	var registry: Node = registry_script.new()
	root.add_child(registry)

	# 1. Verify Clean Ledger Initial State
	var initial_status = registry.verify_ledger_integrity()
	assert(initial_status["is_valid"] == true, "Empty ledger must be valid")
	print("[GATE-A1] PASS: Empty ledger verified as valid (reason: %s)" % initial_status["reason"])

	# 2. Record 3 Audit Entries & Verify Hash Continuity
	for i in range(3):
		var entry = {
			"run_id": "RUN-000%d" % (i + 1),
			"bioroid_hash": "HASH_SAMPLE_%04d" % (i + 1),
			"result": "SUPPRESSION_SUCCESS",
			"final_status": "SUPPRESSED-STABLE",
			"opponent_id": "SUBJECT AF-%02d" % (i + 1),
			"cause": "Decisive strike"
		}
		registry.record_audit_entry(entry)

	var valid_status = registry.verify_ledger_integrity()
	assert(valid_status["is_valid"] == true, "3-block ledger chain must be cryptographically valid")
	assert(valid_status["total_entries"] == 3, "Total entries must be 3")
	print("[GATE-A2] PASS: 3-block cryptographic hash-chain verified cleanly")

	# 3. Fault-Injection: Tamper with Block 2 and confirm corruption detection
	var tampered_entry = registry.audit_ledger[1].duplicate(true)
	tampered_entry["final_status"] = "CONTAINMENT-BREACH" # Modify audited payload
	registry.audit_ledger[1] = tampered_entry

	var corrupted_status = registry.verify_ledger_integrity()
	assert(corrupted_status["is_valid"] == false, "Tampered block must fail verification")
	assert(corrupted_status["reason"] == "HASH_CORRUPTION", "Failure reason must be HASH_CORRUPTION")
	assert(corrupted_status["error_index"] == 2, "Error index must point precisely to block 2")
	print("[GATE-A3] PASS: Fault-injection detected. Tampered block #2 failed (reason: %s)" % corrupted_status["reason"])

	# 4. Expedition Expansion & Directives Verification
	var expedition_script = load("res://scripts/expedition_manager.gd")
	var expedition: Node = expedition_script.new()
	root.add_child(expedition)

	# Directive 1: DEEP_SCAN on Sector 1
	var inc1 = expedition.explore_next_sector("DEEP_SCAN")
	assert(inc1["directive"] == "DEEP_SCAN", "Directive must be preserved")
	assert(inc1["fragments_recovered"] == 2, "DEEP_SCAN should yield +1 bonus fragment")
	assert(inc1["contamination_level"] > 0.0, "DEEP_SCAN should accumulate contamination")
	print("[GATE-A4] PASS: Sector 1 DEEP_SCAN executed (fragments: %d, contamination: %.2f)" % [
		inc1["fragments_recovered"], inc1["contamination_level"]
	])

	# Directive 2: PURGE on Sector 2
	var inc2 = expedition.explore_next_sector("PURGE")
	assert(inc2["directive"] == "PURGE", "Directive must be preserved")
	assert(inc2["contamination_level"] < inc1["contamination_level"] + 0.25, "PURGE must suppress contamination")
	print("[GATE-A5] PASS: Sector 2 PURGE executed (contamination suppressed to %.2f)" % inc2["contamination_level"])

	# Handoff to lab
	var handoff = expedition.return_to_lab()
	assert(handoff["gene_fragments"] >= 3, "Handoff must contain total recovered fragments")
	assert(expedition.get_resources()["gene_fragments"] == 0, "Expedition resources must reset upon lab return")
	print("[GATE-A6] PASS: Expedition return to lab completed cleanly (handoff fragments: %d)" % handoff["gene_fragments"])

	# 5. Gene Mixer Archetype & Nonlinear Calculation Verification
	var gene_mixer_class = load("res://scripts/gene_mixer_controller.gd")
	var mix1 = gene_mixer_class.synthesize({"alden": 0.8, "tsellina": 0.1, "elphadia": 0.1}, 1001)
	assert(mix1["archetype"] == "CERAMIC_STRIKER", "High Alden must yield CERAMIC_STRIKER")
	var mix2 = gene_mixer_class.synthesize({"alden": 0.1, "tsellina": 0.8, "elphadia": 0.1}, 1002)
	assert(mix2["archetype"] == "TITAN_AEGIS", "High Tsellina must yield TITAN_AEGIS")
	print("[GATE-A7] PASS: Gene Mixer archetype & non-linear synthesis verified (%s, %s)" % [
		mix1["archetype"], mix2["archetype"]
	])

	print("============================================================")
	print(" PHASE A EXPANSION RESULTS: 7 / 7 GATES PASSED")
	print("============================================================\n")
	quit(0)
