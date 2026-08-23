extends SceneTree

# =============================================================================
# NPC Dialogue Live Playthrough & Context Verification Suite
# Principle: generation_is_not_authority (Unified deterministic loop)
# Executes 1 full Sovereign Loop cycle while intercepting and logging every
# dialogue line triggered across FSM transitions and Sector incidents.
# =============================================================================

var terminal_ctrl: MainTerminalController
var current_step: int = 0
var timer: float = 0.0
var dialogue_log: Array[Dictionary] = []

func _init() -> void:
	print("\n============================================================")
	print(" [LIVE PLAYTHROUGH] NPC DIALOGUE EXPERIENCE & AUDIT RUN")
	print("============================================================\n")

	var main_scene = load("res://scenes/main_terminal.tscn")
	if not main_scene:
		push_error("Failed to load main_terminal.tscn")
		quit(1)
		return

	var root_node = main_scene.instantiate()
	terminal_ctrl = root_node as MainTerminalController
	if not terminal_ctrl:
		terminal_ctrl = root_node.get_node_or_null("MainTerminalController")

	if terminal_ctrl:
		terminal_ctrl._resolve_singletons_and_managers()
		if terminal_ctrl.dialogue_controller:
			terminal_ctrl.dialogue_controller.line_displayed.connect(func(speaker_id: String, speaker_name: String, text: String, emotion: String):
				var entry := {
					"step": current_step,
					"speaker_id": speaker_id,
					"speaker_name": speaker_name,
					"text": text,
					"emotion": emotion
				}
				dialogue_log.append(entry)
				print("  [NPC-LINE] %s (%s): \"%s\" [Emotion: %s]" % [speaker_name, speaker_id, text, emotion])
			)

	get_root().add_child(root_node)

func _process(delta: float) -> bool:
	timer += delta

	match current_step:
		0:
			if timer > 0.3:
				print("\n>>> [STEP 1: TERMINAL -> EXPEDITION]")
				terminal_ctrl.transition_to_state(MainTerminalController.State.STATE_EXPEDITION)
				timer = 0.0
				current_step = 1

		1:
			if timer > 0.4:
				print("\n>>> [STEP 2: EXPLORE SECTOR 1 (SPECIMEN_TRACE)]")
				var inc1 = terminal_ctrl.explore_sector()
				print("    Incident 1 Yield: %s" % inc1.get("description", ""))
				timer = 0.0
				current_step = 2

		2:
			if timer > 0.4:
				print("\n>>> [STEP 3: EXPLORE SECTOR 2 (ACTIVE_CULTURE)]")
				var inc2 = terminal_ctrl.explore_sector()
				print("    Incident 2 Yield: %s" % inc2.get("description", ""))
				timer = 0.0
				current_step = 3

		3:
			if timer > 0.4:
				print("\n>>> [STEP 4: EXPEDITION -> GENE LAB HANDOFF]")
				terminal_ctrl.return_from_expedition_to_mixer()
				timer = 0.0
				current_step = 4

		4:
			if timer > 0.4:
				print("\n>>> [STEP 5: SYNTHESIZE BIOROID & DEPLOY TO ARENA]")
				var ratios = {"alden": 55, "tsellina": 30, "elphadia": 15}
				terminal_ctrl.synthesize_and_deploy(ratios)
				timer = 0.0
				current_step = 5

		5:
			if timer > 0.5:
				print("\n>>> [STEP 6: ARENA COMBAT RESOLUTION -> LEDGER]")
				terminal_ctrl.on_arena_battle_concluded(true, {
					"run_id": terminal_ctrl.active_run_id,
					"result": "SUPPRESSION_SUCCESS",
					"turns": 3,
					"damage_dealt": 110,
					"damage_taken": 15
				})
				timer = 0.0
				current_step = 6

		6:
			if timer > 0.4:
				print("\n>>> [STEP 7: LEDGER COMMIT -> RETURN TO TERMINAL]")
				terminal_ctrl.transition_to_state(MainTerminalController.State.STATE_TERMINAL)
				timer = 0.0
				current_step = 7

		7:
			if timer > 0.3:
				_evaluate_playthrough_results()
				quit(0)
				return true

	return false

func _evaluate_playthrough_results() -> void:
	print("\n============================================================")
	print(" [PLAYTHROUGH EVALUATION] NPC DIALOGUE LOG AUDIT")
	print(" Total Dialogue Lines Fired: %d" % dialogue_log.size())
	print("============================================================")
	for i in range(dialogue_log.size()):
		var l = dialogue_log[i]
		print("  #%d [Step %d] %s: \"%s\"" % [i + 1, l["step"], l["speaker_name"], l["text"]])
	print("============================================================\n")
