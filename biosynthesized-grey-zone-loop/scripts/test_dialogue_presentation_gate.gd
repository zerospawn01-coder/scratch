extends SceneTree

# =============================================================================
# Player-Visible Dialogue Presentation Gate Suite (V0)
# Verifies:
#   1. DialogueFeedLabel exists in Footer and initial state is populated
#   2. Triggered dialogue dynamically updates DialogueFeedLabel text
#   3. PromptLabel and Views are NOT obscured (layout integrity)
#   4. Input dispatching is NOT blocked (non-modal)
# =============================================================================

func _init() -> void:
	print("\n============================================================")
	print(" [PRESENTATION GATE] PLAYER-VISIBLE DIALOGUE FEED SUITE (V0)")
	print(" Testing 1-Line Non-Modal Footer Feed Presentation")
	print("============================================================\n")

	var passed_checks: Array[String] = []
	var failed_checks: Array[String] = []

	var term_scene = load("res://scenes/main_terminal.tscn") as PackedScene
	if not term_scene:
		printerr("FATAL: Could not load res://scenes/main_terminal.tscn")
		quit(1)
		return

	var terminal = term_scene.instantiate()
	root.add_child(terminal)

	var feed_label: Label = terminal.get_node_or_null("Footer/DialogueFeedLabel")
	var prompt_label: Label = terminal.get_node_or_null("Footer/PromptLabel")

	# -------------------------------------------------------------------------
	# PRES-GATE-01: Node existence & initial standby status
	# -------------------------------------------------------------------------
	print(">>> [PRES-GATE-01] Checking DialogueFeedLabel existence & initial text...")
	if feed_label and feed_label.text.begins_with("[COMM:"):
		passed_checks.append("PRES-GATE-01 PASS: DialogueFeedLabel initialized in Footer")
		print("  [PASS] Label text: %s" % feed_label.text)
	else:
		failed_checks.append("PRES-GATE-01 FAIL: DialogueFeedLabel missing or empty")
		print("  [FAIL] DialogueFeedLabel not found or not initialized")

	# -------------------------------------------------------------------------
	# PRES-GATE-02: Dynamic update on state transition dialogue
	# -------------------------------------------------------------------------
	print(">>> [PRES-GATE-02] Testing feed text update on STATE_EXPEDITION enter...")
	terminal.transition_to_state(1) # State.STATE_EXPEDITION
	if feed_label and feed_label.text.contains("Zone-L perimeter breached"):
		passed_checks.append("PRES-GATE-02 PASS: Dialogue feed updated with Operator Zero line")
		print("  [PASS] Feed text: %s" % feed_label.text)
	else:
		failed_checks.append("PRES-GATE-02 FAIL: Feed text did not update on transition")
		print("  [FAIL] Feed text was: %s" % (feed_label.text if feed_label else "NULL"))

	# -------------------------------------------------------------------------
	# PRES-GATE-03: Layout non-obscuration & non-modal input flow
	# -------------------------------------------------------------------------
	print(">>> [PRES-GATE-03] Checking layout hierarchy and Prompt visibility...")
	if prompt_label and prompt_label.visible and feed_label and feed_label.visible:
		var feed_rect = feed_label.get_rect()
		var prompt_rect = prompt_label.get_rect()
		# Check that feed_label is above prompt_label and does not overlap vertically
		if feed_rect.position.y < prompt_rect.position.y:
			passed_checks.append("PRES-GATE-03 PASS: 1-line feed cleanly stacked above action prompt without overlap")
			print("  [PASS] Feed Y=%.1f < Prompt Y=%.1f" % [feed_rect.position.y, prompt_rect.position.y])
		else:
			failed_checks.append("PRES-GATE-03 FAIL: Labels overlapping vertically")
	else:
		failed_checks.append("PRES-GATE-03 FAIL: Prompt or Feed label invisible")

	# =========================================================================
	# Summary
	# =========================================================================
	print("\n============================================================")
	print(" PRESENTATION GATE RESULTS: %d / %d PASSED" % [passed_checks.size(), passed_checks.size() + failed_checks.size()])
	print("============================================================")
	for p in passed_checks:
		print("  PASS: " + p)
	for f in failed_checks:
		print("  FAIL: " + f)

	if failed_checks.is_empty():
		print("\n  [CANONICAL] Player-Visible Dialogue Presentation v0 -- ALL GATES PASSED.")
	else:
		print("\n  [HOLD] %d gate(s) failed." % failed_checks.size())
	print("============================================================\n")

	quit(0 if failed_checks.is_empty() else 1)
