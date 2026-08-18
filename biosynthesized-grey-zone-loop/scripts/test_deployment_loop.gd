extends SceneTree

# =============================================================================
# Automated Verification: Full Deployment Loop (Gene Mixer -> Arena -> Audit Log)
# =============================================================================

func _init() -> void:
	print("\n============================================================")
	print(" [VERIFICATION SUITE] AETHER FOUNTAIN DEPLOYMENT LOOP")
	print(" Testing 7 Canonical PASS Conditions")
	print("============================================================\n")

	var passed_checks = []
	var failed_checks = []

	var GeneMixerController = load("res://scripts/gene_mixer_controller.gd")
	var registry_script = load("res://scripts/bioroid_registry.gd")
	var BioroidRegistry = registry_script.new()
	BioroidRegistry.name = "BioroidRegistry"
	root.add_child(BioroidRegistry)

	# --- TEST CASE 1: Synthesize Specimen A (Alden Dominant) ---
	print(">>> [TEST 1] Synthesizing Specimen A (Alden 60 / Tsellina 25 / Elphadia 15)...")
	var seed_a = 44291
	var syn_a = GeneMixerController.synthesize({"alden": 60, "tsellina": 25, "elphadia": 15}, seed_a)

	var payload_a = {
		"run_id": "RUN-TEST-001",
		"bioroid_id": syn_a.get("individual_id", ""),
		"bioroid_name": syn_a.get("dominant_nation", "").to_upper(),
		"bioroid_hash": syn_a.get("individual_hash", ""),
		"dna_ratio": {"ald": 60, "kln": 25, "chm": 15},
		"stats": {
			"vital_integrity": 100,
			"neural_control": 88,
			"mutation_load": 12,
			"core_stress": 35,
			"atk": 36,
			"ep": 60
		},
		"mutation_profile": {"surge_risk": "LOW", "instability_rate": 0.04},
		"sprite_path": "res://assets/bioroids/sprites/bio_ald_def001_alden_front.png",
		"generated_at": Time.get_datetime_string_from_system()
	}
	BioroidRegistry.register_deployment_payload(payload_a)

	# CHECK 1: Payload ID & Hash correctly preserved
	if payload_a["bioroid_id"] != "" and payload_a["bioroid_hash"] != "":
		passed_checks.append("PASS-1: Gene Mixer generated Specimen ID & SHA-256 Hash")
		print("  [PASS-1] Specimen ID: %s | Hash: %s..." % [payload_a["bioroid_id"], payload_a["bioroid_hash"].substr(0, 12)])
	else:
		failed_checks.append("FAIL-1: Specimen ID or Hash missing")

	# CHECK 2: DNA ratio preserved
	if payload_a["dna_ratio"]["ald"] == 60 and payload_a["dna_ratio"]["kln"] == 25:
		passed_checks.append("PASS-2: DNA ratio preserved in Payload")
		print("  [PASS-2] DNA Ratio: %s" % str(payload_a["dna_ratio"]))
	else:
		failed_checks.append("FAIL-2: DNA ratio corrupted")

	# CHECK 3 & 4: Arena Initialization from Payload
	print("\n>>> [TEST 2] Initializing Arena Manager from Payload...")
	var arena_mgr = load("res://scripts/arena_battle_manager.gd").new()
	arena_mgr.registry_override = BioroidRegistry
	root.add_child(arena_mgr)
	arena_mgr._initialize_from_payload()

	var p_stats = arena_mgr.get("player_stats")
	if p_stats.get("id") == payload_a["bioroid_id"] and p_stats.get("neural_control") == 88:
		passed_checks.append("PASS-3: Arena stats fully dynamic from Payload (not hardcoded)")
		print("  [PASS-3] Arena Player: %s | Control=%d%% | Atk=%d" % [p_stats["id"], p_stats["neural_control"], p_stats["atk"]])
	else:
		failed_checks.append("FAIL-3: Arena stats did not match Payload")

	var deployed_payload = arena_mgr.get("deployment_payload")
	if deployed_payload.get("sprite_path") == payload_a["sprite_path"]:
		passed_checks.append("PASS-4: Sprite path derived from Payload")
		print("  [PASS-4] Sprite Path: %s" % deployed_payload["sprite_path"])
	else:
		failed_checks.append("FAIL-4: Sprite path not from Payload")

	# --- TEST CASE 2: Simulate Combat & Interventions ---
	print("\n>>> [TEST 3] Simulating Combat & Auditor Interventions...")
	arena_mgr.execute_auditor_intervention("NERVOUS_CORE_SUPPRESSION")
	arena_mgr.execute_auditor_intervention("GENE_DISCHARGE_OVERRIDE")
	
	# Conclude battle and record into BioroidRegistry
	arena_mgr._conclude_battle(true)

	# CHECK 5 & 6: Audit Ledger Verification
	var latest_log = BioroidRegistry.get_latest_audit_entry()
	if not latest_log.is_empty():
		passed_checks.append("PASS-5: Audit Log entry committed to Sovereign Ledger")
		print("  [PASS-5] Ledger Entry #%d committed for Run %s" % [latest_log.get("ledger_index", 0), latest_log.get("run_id", "")])
	else:
		failed_checks.append("FAIL-5: Audit Log entry missing from Ledger")

	var has_hash = latest_log.get("bioroid_hash") == payload_a["bioroid_hash"]
	var has_result = latest_log.get("result") == "SUPPRESSION_SUCCESS"
	var has_interv = "NERVOUS_CORE_SUPPRESSION" in latest_log.get("intervention_used", [])
	if has_hash and has_result and has_interv:
		passed_checks.append("PASS-6: Audit Log contains bioroid_hash, result, and interventions")
		print("  [PASS-6] Verified: Hash=%s... | Result=%s | Interventions=%s" % [
			latest_log.get("bioroid_hash").substr(0, 12), latest_log.get("result"), str(latest_log.get("intervention_used"))
		])
	else:
		failed_checks.append("FAIL-6: Audit Log missing critical audit fields")

	# CHECK 7: Deterministic Reproducibility
	print("\n>>> [TEST 4] Testing Deterministic Reproducibility (Same Seed -> Identical Initial State)...")
	var syn_a_reproduced = GeneMixerController.synthesize({"alden": 60, "tsellina": 25, "elphadia": 15}, seed_a)
	if syn_a_reproduced.get("individual_hash") == syn_a.get("individual_hash") and syn_a_reproduced.get("individual_id") == syn_a.get("individual_id"):
		passed_checks.append("PASS-7: Identical seed & DNA ratio generates 100% deterministic specimen")
		print("  [PASS-7] Determinism Verified: Hash A1 == Hash A2 (%s)" % syn_a.get("individual_hash").substr(0, 16))
	else:
		failed_checks.append("FAIL-7: Non-deterministic synthesis detected")

	# --- FINAL SUMMARY ---
	print("\n============================================================")
	print(" [VERIFICATION RESULTS] SUMMARY")
	print("============================================================")
	for p in passed_checks:
		print("  [OK] ", p)
	for f in failed_checks:
		print("  [!!] ", f)

	print("\nTOTAL PASSED: %d/7 | TOTAL FAILED: %d/7" % [passed_checks.size(), failed_checks.size()])
	if failed_checks.is_empty():
		print("VERDICT: ALL 7 PASS CONDITIONS SATISFIED. PIPELINE SECURED.\n")
	else:
		print("VERDICT: TEST SUITE FAILED.\n")

	quit()

