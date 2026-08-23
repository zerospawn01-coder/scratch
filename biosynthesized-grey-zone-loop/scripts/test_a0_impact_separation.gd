extends SceneTree

var observed_phases: Array[String] = ["READY"]
var damage_event_count := 0
var impact_entry_vital := -1
var impact_entry_damage_events := -1
var impact_entry_defender_position := Vector3.INF
var impact_entry_time_scale := -1.0
var impact_entry_particle_count := -1
var impact_entry_popup_count := -1
var arena: Node
var defender_dummy: Node3D

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("\n============================================================")
	print(" [A0 STRUCT] IMPACT SEPARATION")
	print("============================================================")

	var arena_script = load("res://scripts/arena_battle_manager.gd")
	arena = arena_script.new()
	arena.name = "ArenaBattleManager"
	arena.registry_override = Node.new()
	arena.deployment_payload = {"stats": {"vital_integrity": 100, "neural_control": 85, "mutation_load": 14, "core_stress": 40, "atk": 30, "ep": 60}}
	var attacker_dummy := Node3D.new()
	attacker_dummy.name = "AldenDummy"
	attacker_dummy.position = Vector3(-2.5, 0, 0)
	defender_dummy = Node3D.new()
	defender_dummy.name = "LambdaDummy"
	defender_dummy.position = Vector3(2.5, 0, 0)
	root.add_child(attacker_dummy)
	root.add_child(defender_dummy)
	root.add_child(arena)

	arena.player_stats = {"id": "A0-ATTACKER", "vital_integrity": 100, "atk": 30, "node": attacker_dummy}
	arena.enemy_stats = {"id": "A0-DEFENDER", "vital_integrity": 100, "atk": 20, "node": defender_dummy}
	arena.is_in_battle = true
	arena.combat_phase_changed.connect(_on_combat_phase_changed)
	arena.combatant_damaged.connect(_on_combatant_damaged)

	var attacker_origin := attacker_dummy.position
	var defender_origin := defender_dummy.position
	var attacker_rotation := attacker_dummy.rotation_degrees
	var defender_rotation := defender_dummy.rotation_degrees
	var attacker_scale := attacker_dummy.scale
	var defender_scale := defender_dummy.scale
	var pre_vital: int = arena.enemy_stats["vital_integrity"]
	var pre_time_scale := Engine.time_scale
	print("[A0] PRE vital=%d attacker=%s defender=%s" % [pre_vital, attacker_origin, defender_origin])

	await arena._apply_attack(arena.player_stats, arena.enemy_stats, 1.0, 0.0)
	await create_timer(0.25, true, false, true).timeout

	var final_vital: int = arena.enemy_stats["vital_integrity"]
	var emitted_damage := pre_vital - final_vital
	var expected_phases: Array[String] = ["READY", "ANTICIPATION", "ATTACK", "IMPACT", "RECOVERY", "READY"]
	var struct_01 := observed_phases == expected_phases and observed_phases.count("IMPACT") == 1
	var struct_02 := impact_entry_vital == pre_vital and impact_entry_damage_events == 0 and damage_event_count == 1 and final_vital == pre_vital - emitted_damage
	var struct_03 := impact_entry_defender_position.is_equal_approx(defender_origin) and is_equal_approx(impact_entry_time_scale, pre_time_scale) and impact_entry_particle_count == 0 and impact_entry_popup_count == 0
	var struct_04 := attacker_dummy.position.is_equal_approx(attacker_origin) \
		and defender_dummy.position.is_equal_approx(defender_origin) \
		and attacker_dummy.rotation_degrees.is_equal_approx(attacker_rotation) \
		and defender_dummy.rotation_degrees.is_equal_approx(defender_rotation) \
		and attacker_dummy.scale.is_equal_approx(attacker_scale) \
		and defender_dummy.scale.is_equal_approx(defender_scale) \
		and is_equal_approx(Engine.time_scale, 1.0)

	_report("A0-STRUCT-01", struct_01, "phases=%s impact_count=%d" % [observed_phases, observed_phases.count("IMPACT")])
	_report("A0-STRUCT-02", struct_02, "impact_vital=%d pre_vital=%d impact_events=%d final_events=%d final_vital=%d damage=%d" % [impact_entry_vital, pre_vital, impact_entry_damage_events, damage_event_count, final_vital, emitted_damage])
	_report("A0-STRUCT-03", struct_03, "defender_origin=%s impact_position=%s time_scale=%.3f particles=%d popups=%d" % [defender_origin, impact_entry_defender_position, impact_entry_time_scale, impact_entry_particle_count, impact_entry_popup_count])
	_report("A0-STRUCT-04", struct_04, "positions=(%s,%s) rotations=(%s,%s) scales=(%s,%s) time_scale=%.3f" % [attacker_dummy.position, defender_dummy.position, attacker_dummy.rotation_degrees, defender_dummy.rotation_degrees, attacker_dummy.scale, defender_dummy.scale, Engine.time_scale])

	var all_pass := struct_01 and struct_02 and struct_03 and struct_04
	print("============================================================")
	print(" A0 STRUCT RESULT: %s" % ("4 / 4 PASS" if all_pass else "FAIL"))
	print("============================================================\n")
	quit(0 if all_pass else 1)

func _on_combat_phase_changed(_phase: int, phase_name: String) -> void:
	observed_phases.append(phase_name)
	print("[A0] PHASE %s" % phase_name)
	if phase_name == "IMPACT":
		impact_entry_vital = arena.enemy_stats["vital_integrity"]
		impact_entry_damage_events = damage_event_count
		impact_entry_defender_position = defender_dummy.position
		impact_entry_time_scale = Engine.time_scale
		impact_entry_particle_count = arena._active_particle_count
		impact_entry_popup_count = _count_popups()

func _on_combatant_damaged(_target: Node3D, _damage: int, _is_critical: bool) -> void:
	damage_event_count += 1

func _count_popups() -> int:
	var count := 0
	for child in root.get_children():
		if child is Label3D:
			count += 1
	return count

func _report(gate: String, passed: bool, evidence: String) -> void:
	print("[%s] %s: %s" % [gate, "PASS" if passed else "FAIL", evidence])
