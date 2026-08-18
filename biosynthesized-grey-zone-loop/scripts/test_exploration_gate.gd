extends SceneTree

# =============================================================================
# EXP Gate Verification Suite — Exploration Loop Minimum Integration Tests
# 7 conditions: Exploration -> Gene Mixer -> Arena -> Audit Log -> Exploration
# Principle: generation_is_not_authority
# =============================================================================

func _init() -> void:
	print("\n============================================================")
	print(" [EXP GATE] AETHER FOUNTAIN EXPLORATION LOOP INTEGRATION")
	print(" Testing 7 Canonical Loop Conditions")
	print("============================================================\n")

	var passed_checks: Array[String] = []
	var failed_checks: Array[String] = []

	# --- Setup nodes ---
	var expedition_script = load("res://scripts/expedition_manager.gd")
	var expedition: Node = expedition_script.new()
	expedition.name = "ExpeditionManager"

	var registry_script = load("res://scripts/bioroid_registry.gd")
	var registry: Node = registry_script.new()
	registry.name = "BioroidRegistry"

	var GeneMixerController = load("res://scripts/gene_mixer_controller.gd")

	root.add_child(expedition)
	root.add_child(registry)

	# -------------------------------------------------------------------------
	# EXP-GATE-01: Exploration yields gene_fragments >= 1
	# -------------------------------------------------------------------------
	print(">>> [EXP-GATE-01] Explore sector -> gene_fragment yield >= 1...")
	var incident = expedition.explore_next_sector()
	var resources = expedition.get_resources()
	if resources.get("gene_fragments", 0) >= 1 and incident.get("fragments_recovered", 0) >= 1:
		passed_checks.append("EXP-GATE-01 PASS: %d fragment(s) acquired (incident=%s)" % [resources["gene_fragments"], incident.get("incident_type")])
		print("  [PASS] fragments=%d incident=%s" % [resources["gene_fragments"], incident.get("incident_type")])
	else:
		failed_checks.append("EXP-GATE-01 FAIL: No fragments acquired")
		print("  [FAIL] fragments=%d" % resources.get("gene_fragments", 0))

	# -------------------------------------------------------------------------
	# EXP-GATE-02: Acquired resources are passed to Gene Mixer (fragment count > 0)
	# -------------------------------------------------------------------------
	print(">>> [EXP-GATE-02] Resources reach Gene Mixer (fragment count > 0)...")
	# Explore a second sector to build up resources
	expedition.explore_next_sector()
	var handoff = expedition.return_to_lab()
	var fragments_handed_off: int = handoff.get("gene_fragments", 0)
	if fragments_handed_off >= 2:
		passed_checks.append("EXP-GATE-02 PASS: %d fragment(s) handed off to Gene Mixer" % fragments_handed_off)
		print("  [PASS] fragments_handed_off=%d" % fragments_handed_off)
	else:
		failed_checks.append("EXP-GATE-02 FAIL: insufficient fragments in handoff (got %d)" % fragments_handed_off)
		print("  [FAIL] fragments=%d" % fragments_handed_off)

	# -------------------------------------------------------------------------
	# EXP-GATE-03: Gene Mixer produces a valid specimen from expedition resources
	# DNA ratios driven by fragment count (fragment-seeded synthesis)
	# -------------------------------------------------------------------------
	print(">>> [EXP-GATE-03] Gene Mixer synthesizes specimen from expedition resources...")
	# Fragment count influences DNA weight distribution (simple proportional mapping)
	var frag_total: int = fragments_handed_off
	var dna_ratios: Dictionary = {
		"alden":    clamp(frag_total * 20, 10, 70),
		"tsellina": clamp(frag_total * 10, 10, 40),
		"elphadia": 100 - clamp(frag_total * 20, 10, 70) - clamp(frag_total * 10, 10, 40)
	}
	var seed_val: int = handoff.get("incident_count", 1) * 7331
	var specimen = GeneMixerController.synthesize(dna_ratios, seed_val)

	var has_id = specimen.get("individual_id", "") != ""
	var has_hash = specimen.get("individual_hash", "") != ""
	if has_id and has_hash:
		passed_checks.append("EXP-GATE-03 PASS: Specimen synthesized (id=%s hash=%s...)" % [specimen["individual_id"], specimen["individual_hash"].substr(0, 12)])
		print("  [PASS] id=%s hash=%s..." % [specimen["individual_id"], specimen["individual_hash"].substr(0, 12)])
	else:
		failed_checks.append("EXP-GATE-03 FAIL: Synthesis returned empty id or hash")
		print("  [FAIL] id='%s' hash='%s'" % [specimen.get("individual_id",""), specimen.get("individual_hash","")])

	# -------------------------------------------------------------------------
	# EXP-GATE-04: Specimen hash correctly flows into ArenaDeploymentPayload
	# -------------------------------------------------------------------------
	print(">>> [EXP-GATE-04] Specimen hash reaches ArenaDeploymentPayload...")
	var payload: Dictionary = {
		"run_id":       "RUN-EXP-GATE-001",
		"bioroid_id":   specimen.get("individual_id", ""),
		"bioroid_name": specimen.get("dominant_nation", "UNKNOWN").to_upper(),
		"bioroid_hash": specimen.get("individual_hash", ""),
		"dna_ratio":    {"ald": dna_ratios["alden"], "kln": dna_ratios["tsellina"], "chm": dna_ratios["elphadia"]},
		"stats": {
			"vital_integrity": 100,
			"neural_control":  int(70 + dna_ratios["alden"] * 0.2),
			"mutation_load":   int(5 + dna_ratios["elphadia"] * 0.3),
			"core_stress":     35,
			"atk":             int(20 + dna_ratios["alden"] * 0.25),
			"ep":              60
		},
		"mutation_profile": {"surge_risk": "LOW", "instability_rate": 0.05},
		"sprite_path":      "res://assets/bioroids/sprites/bio_ald_def001_alden_front.png",
		"generated_at":     Time.get_datetime_string_from_system()
	}
	registry.register_deployment_payload(payload)
	var retrieved = registry.get_deployment_payload()
	var hash_match: bool = retrieved.get("bioroid_hash", "") == specimen.get("individual_hash", "")
	if hash_match and retrieved.get("run_id") == "RUN-EXP-GATE-001":
		passed_checks.append("EXP-GATE-04 PASS: Hash propagated to payload (hash=%s...)" % specimen["individual_hash"].substr(0, 12))
		print("  [PASS] hash=%s... in payload" % specimen["individual_hash"].substr(0, 12))
	else:
		failed_checks.append("EXP-GATE-04 FAIL: Hash mismatch in payload")
		print("  [FAIL] hash mismatch: got '%s'" % retrieved.get("bioroid_hash",""))

	# -------------------------------------------------------------------------
	# EXP-GATE-05: Arena result is committed to Audit Log
	# (Simulated: directly call registry.record_audit_entry as Arena would)
	# -------------------------------------------------------------------------
	print(">>> [EXP-GATE-05] Arena result committed to Audit Log...")
	var audit_before: int = registry.get_audit_record_count()
	var audit_record: Dictionary = {
		"run_id":          payload["run_id"],
		"bioroid_id":      payload["bioroid_id"],
		"bioroid_hash":    payload["bioroid_hash"],
		"opponent_id":     "SUBJECT AF-09",
		"result":          "SUPPRESSION_SUCCESS",
		"cause":           "TARGET SUPPRESSION SUCCESSFUL",
		"intervention_used": ["NERVOUS_CORE_SUPPRESSION"],
		"final_status":    "SUPPRESSED-STABLE",
		"damage_taken":    18,
		"turns":           3
	}
	registry.record_audit_entry(audit_record)
	var audit_after: int = registry.get_audit_record_count()
	var latest = registry.get_latest_audit_entry()
	if audit_after == audit_before + 1 and latest.get("run_id") == payload["run_id"]:
		passed_checks.append("EXP-GATE-05 PASS: Audit entry #%d committed (run=%s)" % [audit_after, latest.get("run_id")])
		print("  [PASS] entry #%d committed" % audit_after)
	else:
		failed_checks.append("EXP-GATE-05 FAIL: Audit count did not increment (before=%d after=%d)" % [audit_before, audit_after])
		print("  [FAIL] audit count %d -> %d" % [audit_before, audit_after])

	# -------------------------------------------------------------------------
	# EXP-GATE-06: After audit, Exploration can start a new cycle (return path)
	# Resources reset to 0 after return_to_lab, new exploration yields fresh data
	# -------------------------------------------------------------------------
	print(">>> [EXP-GATE-06] Exploration starts fresh cycle after lab return...")
	# expedition.return_to_lab() was already called in GATE-02 — state should be reset
	var fresh_resources = expedition.get_resources()
	var is_reset: bool = (fresh_resources.get("gene_fragments", -1) == 0 and
						  fresh_resources.get("incident_count", -1) == 0 and
						  fresh_resources.get("sector_log", ["x"]).is_empty())

	if is_reset:
		# Confirm new expedition can accumulate fragments
		expedition.explore_next_sector()
		var new_resources = expedition.get_resources()
		if new_resources.get("gene_fragments", 0) >= 1:
			passed_checks.append("EXP-GATE-06 PASS: Fresh cycle started, fragment=%d" % new_resources["gene_fragments"])
			print("  [PASS] state reset + new cycle yielded fragment=%d" % new_resources["gene_fragments"])
		else:
			failed_checks.append("EXP-GATE-06 FAIL: New cycle produced no fragments")
			print("  [FAIL] new cycle yielded 0 fragments")
	else:
		failed_checks.append("EXP-GATE-06 FAIL: Resources not reset after return_to_lab (fragments=%d)" % fresh_resources.get("gene_fragments", -1))
		print("  [FAIL] resources not reset")

	# -------------------------------------------------------------------------
	# EXP-GATE-07: After 1 full loop, system state is clean
	# (time_scale=1.0, ledger count stable, no extra nodes)
	# -------------------------------------------------------------------------
	print(">>> [EXP-GATE-07] Full loop: system state clean after one cycle...")
	var time_scale_ok: bool = abs(Engine.time_scale - 1.0) < 0.01
	var ledger_stable: bool = registry.get_audit_record_count() == 1  # only one from GATE-05
	var node_count_ok: bool = root.get_child_count() <= 10  # baseline: expedition + registry + a few engine nodes

	if time_scale_ok and ledger_stable and node_count_ok:
		passed_checks.append("EXP-GATE-07 PASS: Clean state (time_scale=%.2f, ledger=%d, nodes=%d)" % [Engine.time_scale, registry.get_audit_record_count(), root.get_child_count()])
		print("  [PASS] time_scale=%.2f | ledger=%d | nodes=%d" % [Engine.time_scale, registry.get_audit_record_count(), root.get_child_count()])
	else:
		var msg = "EXP-GATE-07 FAIL:"
		if not time_scale_ok: msg += " time_scale=%.3f" % Engine.time_scale
		if not ledger_stable: msg += " ledger=%d(expected 1)" % registry.get_audit_record_count()
		if not node_count_ok: msg += " nodes=%d" % root.get_child_count()
		failed_checks.append(msg)
		print("  [FAIL] %s" % msg)

	# =========================================================================
	# Summary
	# =========================================================================
	print("\n============================================================")
	print(" EXP GATE RESULTS: %d / %d PASSED" % [passed_checks.size(), passed_checks.size() + failed_checks.size()])
	print("============================================================")
	for p in passed_checks:
		print("  PASS: " + p)
	for f in failed_checks:
		print("  FAIL: " + f)

	if failed_checks.is_empty():
		print("\n  [CANONICAL] Exploration Loop v0 -- ALL EXP GATES PASSED.")
		print("  Exploration -> Gene Mixer -> Arena -> Audit Log -> Exploration: LOOP CLOSED.")
	else:
		print("\n  [HOLD] %d gate(s) failed. Fix before promoting to canonical." % failed_checks.size())

	print("============================================================\n")
	quit()
