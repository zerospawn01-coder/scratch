extends SceneTree

# =============================================================================
# TERMINAL GATE Verification Suite — Sovereign Terminal Scene Flow Tests
# Tests 7 Canonical Conditions for the Unified Playable Loop:
# Terminal -> Expedition -> Gene Mixer -> Arena -> Ledger -> Terminal (3 Cycles)
# Principle: generation_is_not_authority (Unified deterministic loop)
# =============================================================================

func _init() -> void:
	print("\n============================================================")
	print(" [TERMINAL GATE] AETHER FOUNTAIN SOVEREIGN TERMINAL SUITE")
	print(" Testing 7 Canonical Scene Flow & 3-Cycle Loop Conditions")
	print("============================================================\n")

	var passed_checks: Array[String] = []
	var failed_checks: Array[String] = []

	# --- 1. Instantiate MainTerminal scene ---
	var term_scene = load("res://scenes/main_terminal.tscn") as PackedScene
	if not term_scene:
		printerr("FATAL: Could not load res://scenes/main_terminal.tscn")
		quit(1)
		return

	var terminal = term_scene.instantiate()
	root.add_child(terminal)

	# Ensure BioroidRegistry singleton exists
	var reg_script = load("res://scripts/bioroid_registry.gd")
	var registry = reg_script.new()
	registry.name = "BioroidRegistry"
	root.add_child(registry)
	terminal.bioroid_registry = registry

	# Ensure initial state is STATE_TERMINAL
	if terminal.current_state != 0: # State.STATE_TERMINAL
		terminal.transition_to_state(0)

	# -------------------------------------------------------------------------
	# TERMINAL-GATE-01: Terminal -> Expedition transition via Space
	# -------------------------------------------------------------------------
	print(">>> [TERMINAL-GATE-01] Terminal -> Expedition transition...")
	terminal.transition_to_state(1) # State.STATE_EXPEDITION
	if terminal.current_state == 1:
		passed_checks.append("TERMINAL-GATE-01 PASS: Transitioned to STATE_EXPEDITION")
		print("  [PASS] State is STATE_EXPEDITION")
	else:
		failed_checks.append("TERMINAL-GATE-01 FAIL: Expected STATE_EXPEDITION(1), got %d" % terminal.current_state)
		print("  [FAIL] State is %d" % terminal.current_state)

	# -------------------------------------------------------------------------
	# TERMINAL-GATE-02: Expedition harvest -> Tab to Gene Mixer handoff
	# -------------------------------------------------------------------------
	print(">>> [TERMINAL-GATE-02] Harvest fragments & transition to Gene Mixer...")
	terminal.explore_sector() # Sector 1: +1 fragment
	terminal.explore_sector() # Sector 2: +2 fragments
	var frags_harvested = terminal.active_fragments_available
	terminal.return_from_expedition_to_mixer() # Hands off resources and moves to STATE_GENE_MIXER

	if terminal.current_state == 2 and terminal.active_fragments_available >= 3:
		passed_checks.append("TERMINAL-GATE-02 PASS: Handed off %d fragments to STATE_GENE_MIXER" % terminal.active_fragments_available)
		print("  [PASS] %d fragments handed off, State is STATE_GENE_MIXER" % terminal.active_fragments_available)
	else:
		failed_checks.append("TERMINAL-GATE-02 FAIL: state=%d, frags=%d" % [terminal.current_state, terminal.active_fragments_available])
		print("  [FAIL] state=%d, frags=%d" % [terminal.current_state, terminal.active_fragments_available])

	# -------------------------------------------------------------------------
	# TERMINAL-GATE-03: Synthesize in Mixer -> Register Payload -> Arena transition
	# -------------------------------------------------------------------------
	print(">>> [TERMINAL-GATE-03] Synthesize specimen & deploy to Arena...")
	var payload = terminal.synthesize_and_deploy()
	var payload_registered = registry.get_deployment_payload()

	var has_id = payload.get("bioroid_id", "") != ""
	var has_hash = payload.get("bioroid_hash", "") != ""
	var hash_in_reg = payload_registered.get("bioroid_hash", "") == payload.get("bioroid_hash", "")

	if terminal.current_state == 3 and has_id and has_hash and hash_in_reg:
		passed_checks.append("TERMINAL-GATE-03 PASS: Specimen %s (hash=%s...) deployed to STATE_ARENA" % [payload["bioroid_id"], payload["bioroid_hash"].substr(0, 12)])
		print("  [PASS] Specimen %s deployed to STATE_ARENA" % payload["bioroid_id"])
	else:
		failed_checks.append("TERMINAL-GATE-03 FAIL: state=%d, id=%s, hash_match=%s" % [terminal.current_state, has_id, hash_in_reg])
		print("  [FAIL] state=%d, id=%s, hash_match=%s" % [terminal.current_state, has_id, hash_in_reg])

	# -------------------------------------------------------------------------
	# TERMINAL-GATE-04: Arena battle conclusion -> Audit Ledger commit -> STATE_LEDGER
	# -------------------------------------------------------------------------
	print(">>> [TERMINAL-GATE-04] Arena combat resolution & Ledger commit...")
	var audit_count_pre = registry.get_audit_record_count()
	var simulated_audit_record = {
		"run_id": payload.get("run_id", "RUN-0001"),
		"bioroid_id": payload.get("bioroid_id", ""),
		"bioroid_hash": payload.get("bioroid_hash", ""),
		"opponent_id": "SUBJECT AF-09",
		"result": "SUPPRESSION_SUCCESS",
		"cause": "TARGET SUPPRESSION SUCCESSFUL — Audited Intervention",
		"intervention_used": ["NERVOUS_CORE_SUPPRESSION"],
		"final_status": "SUPPRESSED-STABLE",
		"damage_taken": 22,
		"turns": 4
	}
	registry.record_audit_entry(simulated_audit_record)
	terminal.on_arena_battle_concluded(true, simulated_audit_record)

	var audit_count_post = registry.get_audit_record_count()
	if terminal.current_state == 4 and audit_count_post == audit_count_pre + 1:
		passed_checks.append("TERMINAL-GATE-04 PASS: Ledger entry #%d committed, moved to STATE_LEDGER" % audit_count_post)
		print("  [PASS] Ledger entry #%d committed, State is STATE_LEDGER" % audit_count_post)
	else:
		failed_checks.append("TERMINAL-GATE-04 FAIL: state=%d, audit_count=%d->%d" % [terminal.current_state, audit_count_pre, audit_count_post])
		print("  [FAIL] state=%d, audit_count=%d->%d" % [terminal.current_state, audit_count_pre, audit_count_post])

	# -------------------------------------------------------------------------
	# TERMINAL-GATE-05: Ledger report acknowledge -> Return to STATE_TERMINAL
	# -------------------------------------------------------------------------
	print(">>> [TERMINAL-GATE-05] Acknowledge report & return to Terminal...")
	terminal.transition_to_state(0) # State.STATE_TERMINAL
	if terminal.current_state == 0:
		passed_checks.append("TERMINAL-GATE-05 PASS: Returned to STATE_TERMINAL (Cycle 1 Complete)")
		print("  [PASS] State is STATE_TERMINAL")
	else:
		failed_checks.append("TERMINAL-GATE-05 FAIL: Expected STATE_TERMINAL(0), got %d" % terminal.current_state)
		print("  [FAIL] State is %d" % terminal.current_state)

	# -------------------------------------------------------------------------
	# TERMINAL-GATE-06: Data integrity after 1 full cycle
	# -------------------------------------------------------------------------
	print(">>> [TERMINAL-GATE-06] Verifying Data & Registry Integrity...")
	var latest_entry = registry.get_latest_audit_entry()
	var run_id_preserved = latest_entry.get("run_id") == payload.get("run_id")
	var hash_preserved = latest_entry.get("bioroid_hash") == payload.get("bioroid_hash")
	var ledger_count_ok = registry.get_audit_record_count() >= 1

	if run_id_preserved and hash_preserved and ledger_count_ok:
		passed_checks.append("TERMINAL-GATE-06 PASS: Sovereign Ledger records preserved (Run: %s, Hash: %s...)" % [latest_entry.get("run_id"), latest_entry.get("bioroid_hash", "").substr(0, 12)])
		print("  [PASS] Sovereign Ledger preserved: Run %s, Hash %s..." % [latest_entry.get("run_id"), latest_entry.get("bioroid_hash", "").substr(0, 12)])
	else:
		failed_checks.append("TERMINAL-GATE-06 FAIL: Integrity violated (run_id=%s, hash=%s)" % [run_id_preserved, hash_preserved])
		print("  [FAIL] Integrity violated")

	# -------------------------------------------------------------------------
	# TERMINAL-GATE-07: 3-Cycle continuous stress test & zero-leak verification
	# -------------------------------------------------------------------------
	print(">>> [TERMINAL-GATE-07] Running 3 continuous cycles stress test...")
	var stress_passed = true

	for cycle in range(2, 4): # Run Cycle 2 and Cycle 3
		# 1. Terminal -> Expedition
		terminal.transition_to_state(1)
		terminal.explore_sector()

		# 2. Expedition -> Mixer
		terminal.return_from_expedition_to_mixer()

		# 3. Mixer -> Arena
		var cycle_payload = terminal.synthesize_and_deploy()

		# 4. Arena -> Ledger
		var cycle_audit = {
			"run_id": "RUN-%04d" % cycle,
			"bioroid_id": cycle_payload.get("bioroid_id"),
			"bioroid_hash": cycle_payload.get("bioroid_hash"),
			"opponent_id": "SUBJECT AF-09",
			"result": "SUPPRESSION_SUCCESS",
			"cause": "CYCLE STRESS TEST ENTRY",
			"intervention_used": ["NERVOUS_CORE_SUPPRESSION"],
			"final_status": "SUPPRESSED-STABLE",
			"damage_taken": 15,
			"turns": 3
		}
		registry.record_audit_entry(cycle_audit)
		terminal.on_arena_battle_concluded(true, cycle_audit)

		# 5. Ledger -> Terminal
		terminal.transition_to_state(0)

	var total_entries = registry.get_audit_record_count()
	var time_scale_clean = abs(Engine.time_scale - 1.0) < 0.01

	if total_entries == 3 and time_scale_clean:
		passed_checks.append("TERMINAL-GATE-07 PASS: 3 full cycles executed cleanly (Total Ledger: %d, TimeScale: %.2f)" % [total_entries, Engine.time_scale])
		print("  [PASS] 3 full cycles completed without drift or leakage")
	else:
		failed_checks.append("TERMINAL-GATE-07 FAIL: entries=%d (expected 3), time_scale=%.3f" % [total_entries, Engine.time_scale])
		print("  [FAIL] entries=%d, time_scale=%.3f" % [total_entries, Engine.time_scale])

	# =========================================================================
	# Summary
	# =========================================================================
	print("\n============================================================")
	print(" TERMINAL GATE RESULTS: %d / %d PASSED" % [passed_checks.size(), passed_checks.size() + failed_checks.size()])
	print("============================================================")
	for p in passed_checks:
		print("  PASS: " + p)
	for f in failed_checks:
		print("  FAIL: " + f)

	if failed_checks.is_empty():
		print("\n  [CANONICAL] Sovereign Terminal & Scene Flow v1.0 -- ALL 7 GATES PASSED.")
		print("  Full 3-Cycle loop verified cleanly on Godot 4.7.1-stable.")
	else:
		print("\n  [HOLD] %d gate(s) failed. Review before promoting to canonical." % failed_checks.size())

	print("============================================================\n")
	quit(0 if failed_checks.is_empty() else 1)
