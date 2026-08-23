extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("\n============================================================")
	print(" [A0 REGRESSION] VFX-GATE-01 TO 03")
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

	arena.player_stats = {"id": "A0-VFX-P", "vital_integrity": 100, "atk": 30, "node": attacker}
	arena.enemy_stats = {"id": "A0-VFX-E", "vital_integrity": 100, "atk": 20, "node": defender}
	arena.is_in_battle = true

	var attacker_origin := attacker.position
	await arena._apply_attack(arena.player_stats, arena.enemy_stats, 1.0, 0.0)
	var attacker_drift := attacker.position.distance_to(attacker_origin)
	var vfx_01 := attacker_drift < 0.05
	_report("VFX-GATE-01", vfx_01, "attacker_drift=%.4f expected<0.05" % attacker_drift)

	arena.enemy_stats["vital_integrity"] = 100
	var defender_origin := defender.position
	await arena._apply_attack(arena.player_stats, arena.enemy_stats, 1.0, 0.0)
	var defender_drift := defender.position.distance_to(defender_origin)
	var vfx_02 := defender_drift < 0.05
	_report("VFX-GATE-02", vfx_02, "defender_drift=%.4f expected<0.05" % defender_drift)

	Engine.time_scale = 1.0
	arena.enemy_stats["vital_integrity"] = 100
	await arena._apply_attack(arena.player_stats, arena.enemy_stats, 1.0, 0.0)
	await create_timer(0.2, true, false, true).timeout
	var vfx_03 := absf(Engine.time_scale - 1.0) < 0.01
	_report("VFX-GATE-03", vfx_03, "time_scale=%.3f expected=1.000+-0.010" % Engine.time_scale)

	var all_pass := vfx_01 and vfx_02 and vfx_03
	print("============================================================")
	print(" A0 VFX REGRESSION RESULT: %s" % ("3 / 3 PASS" if all_pass else "FAIL"))
	print("============================================================\n")
	quit(0 if all_pass else 1)

func _report(gate: String, passed: bool, evidence: String) -> void:
	print("[%s] %s: %s" % [gate, "PASS" if passed else "FAIL", evidence])
