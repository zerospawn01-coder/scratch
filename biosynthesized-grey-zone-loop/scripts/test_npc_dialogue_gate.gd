extends SceneTree

# =============================================================================
# NPC Dialogue System & Asset Verification Suite
# Verifies:
#   1. Dialogue JSON schema & Character dictionary integrity
#   2. Deterministic line-by-line playback & signal emission
#   3. Missing dialogue graceful fallback (Fail-Closed)
#   4. Multi-step conversation completion lifecycle
# =============================================================================

func _init() -> void:
	print("\n============================================================")
	print(" [NPC DIALOGUE GATE] AETHER FOUNTAIN DIALOGUE ASSET SUITE")
	print(" Testing NPC Schema, Character Data & Deterministic Playback")
	print("============================================================\n")

	var passed_checks: Array[String] = []
	var failed_checks: Array[String] = []

	var DialogueController = load("res://scripts/dialogue_controller.gd")
	if not DialogueController:
		printerr("FATAL: Could not load res://scripts/dialogue_controller.gd")
		quit(1)
		return

	var manager = DialogueController.new()
	root.add_child(manager)

	# -------------------------------------------------------------------------
	# DIALOGUE-GATE-01: JSON Load & Schema Validation
	# -------------------------------------------------------------------------
	print(">>> [DIALOGUE-GATE-01] Validating character database & dialogue entries...")
	var valeria = manager.get_character("DR_VALERIA")
	var operator = manager.get_character("OPERATOR_ZERO")

	if not valeria.is_empty() and not operator.is_empty() and manager.has_dialogue("EXPEDITION_DEPARTURE"):
		passed_checks.append("DIALOGUE-GATE-01 PASS: Database loaded cleanly (Dr. Valeria & Operator Zero verified)")
		print("  [PASS] Characters and dialogue table parsed correctly")
	else:
		failed_checks.append("DIALOGUE-GATE-01 FAIL: Incomplete character or dialogue database")
		print("  [FAIL] Database missing expected entries")

	# -------------------------------------------------------------------------
	# DIALOGUE-GATE-02: Playback & Line Advancement Lifecycle
	# -------------------------------------------------------------------------
	print(">>> [DIALOGUE-GATE-02] Testing sequential line advancement...")
	var lines_received: Array[Dictionary] = []
	var dialogue_done: bool = false

	manager.line_displayed.connect(func(speaker_id: String, speaker_name: String, text: String, emotion: String):
		lines_received.append({
			"speaker_id": speaker_id,
			"speaker_name": speaker_name,
			"text": text,
			"emotion": emotion
		})
	)

	var done_flags := {"completed": false}
	manager.dialogue_completed.connect(func(dialogue_id: String):
		if dialogue_id == "EXPEDITION_DEPARTURE":
			done_flags["completed"] = true
	)

	var play_ok = manager.play_dialogue("EXPEDITION_DEPARTURE")
	if play_ok and lines_received.size() == 1:
		# Advance to next line
		var advanced = manager.advance_line()
		if advanced and lines_received.size() == 2:
			# Advance past final line
			var finished = not manager.advance_line()
			if finished and done_flags["completed"] and not manager.is_active:
				passed_checks.append("DIALOGUE-GATE-02 PASS: 2-line dialogue advanced and completed cleanly")
				print("  [PASS] Playback lifecycle completed (lines=2, done=true)")
			else:
				failed_checks.append("DIALOGUE-GATE-02 FAIL: finished=%s dialogue_done=%s is_active=%s" % [finished, done_flags["completed"], manager.is_active])
				print("  [FAIL] finished=%s dialogue_done=%s is_active=%s" % [finished, done_flags["completed"], manager.is_active])
		else:
			failed_checks.append("DIALOGUE-GATE-02 FAIL: Line 2 advancement failed")
	else:
		failed_checks.append("DIALOGUE-GATE-02 FAIL: Initial line playback failed")

	# -------------------------------------------------------------------------
	# DIALOGUE-GATE-03: Unknown dialogue Fail-Closed handling
	# -------------------------------------------------------------------------
	print(">>> [DIALOGUE-GATE-03] Testing invalid dialogue ID handling (Fail-Closed)...")
	var unknown_res = manager.play_dialogue("NON_EXISTENT_DIALOGUE_XYZ")
	if not unknown_res and not manager.is_active:
		passed_checks.append("DIALOGUE-GATE-03 PASS: Unknown dialogue rejected gracefully without crash")
		print("  [PASS] Rejected non-existent dialogue ID")
	else:
		failed_checks.append("DIALOGUE-GATE-03 FAIL: Unknown dialogue handled incorrectly")
		print("  [FAIL] Unknown dialogue did not return false")

	# =========================================================================
	# Summary
	# =========================================================================
	print("\n============================================================")
	print(" NPC DIALOGUE GATE RESULTS: %d / %d PASSED" % [passed_checks.size(), passed_checks.size() + failed_checks.size()])
	print("============================================================")
	for p in passed_checks:
		print("  PASS: " + p)
	for f in failed_checks:
		print("  FAIL: " + f)

	if failed_checks.is_empty():
		print("\n  [CANONICAL] NPC Dialogue System v1.0 -- ALL GATES PASSED.")
	else:
		print("\n  [HOLD] %d gate(s) failed." % failed_checks.size())
	print("============================================================\n")

	quit(0 if failed_checks.is_empty() else 1)
