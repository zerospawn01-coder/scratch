extends SceneTree

var impact_count := 0
var damage_event_count := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("\n============================================================")
	print(" [A0 REGRESSION] VFX-GATE-04 RAPID INPUT SAFETY")
	print("============================================================")

	var arena_script = load("res://scripts/arena_battle_manager.gd")
	var arena: Node = arena_script.new()
	var attacker := Node3D.new()
	var defender := Node3D.new()
	attacker.position = Vector3(-2.5, 0, 0)
	defender.position = Vector3(2.5, 0, 0)
	root.add_child(attacker)
	root.add_child(defender)
	root.add_child(arena)
	arena.highlight_mode = false
	arena.player_stats = {
		"id": "A0-RAPID-P", "hash": "a0-rapid-input-test",
		"vital_integrity": 100, "neural_control": 80,
		"mutation_load": 10, "core_stress": 20,
		"atk": 30, "node": attacker
	}
	arena.enemy_stats = {
		"id": "A0-RAPID-E", "name": "RAPID INPUT DUMMY",
		"vital_integrity": 1000, "hostility_index": 70,
		"mutation_surge": false, "atk": 20, "node": defender
	}
	arena.is_in_battle = true
	arena.is_player_turn = true
	arena.combat_phase_changed.connect(_on_combat_phase_changed)
	arena.combatant_damaged.connect(_on_combatant_damaged)

	var attacker_origin := attacker.position
	var defender_origin := defender.position
	for i in range(8):
		arena.execute_auditor_intervention("NERVOUS_CORE_SUPPRESSION")

	var timeout_at := Time.get_ticks_msec() + 3000
	while arena._attack_in_progress and Time.get_ticks_msec() < timeout_at:
		await process_frame
	var completed: bool = not arena._attack_in_progress
	arena.is_in_battle = false

	var attacker_drift := attacker.position.distance_to(attacker_origin)
	var defender_drift := defender.position.distance_to(defender_origin)
	var passed: bool = completed \
		and impact_count == 1 \
		and damage_event_count == 1 \
		and attacker_drift < 0.05 \
		and defender_drift < 0.05 \
		and absf(Engine.time_scale - 1.0) < 0.01 \
		and not arena._attack_in_progress

	print("[VFX-GATE-04] %s" % ("PASS" if passed else "FAIL"))
	print("[VFX-GATE-04] rapid_inputs=8 accepted_attacks=%d impacts=%d damage_events=%d" % [impact_count, impact_count, damage_event_count])
	print("[VFX-GATE-04] attacker_drift=%.4f defender_drift=%.4f time_scale=%.3f attack_in_progress=%s" % [
		attacker_drift, defender_drift, Engine.time_scale, arena._attack_in_progress
	])
	print("[VFX-GATE-04] completion=%s" % ("COMPLETED" if completed else "TIMEOUT"))
	print("============================================================\n")
	Engine.time_scale = 1.0
	quit(0 if passed else 1)

func _on_combat_phase_changed(_phase: int, phase_name: String) -> void:
	if phase_name == "IMPACT":
		impact_count += 1

func _on_combatant_damaged(_target: Node3D, _damage: int, _is_critical: bool) -> void:
	damage_event_count += 1
