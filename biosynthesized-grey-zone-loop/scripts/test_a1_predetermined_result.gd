extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var registry: Node = load("res://scripts/bioroid_registry.gd").new()
	root.add_child(registry)
	registry.register_deployment_payload({
		"run_id": "A1-TEST-001",
		"bioroid_id": "BIO-A1-TEST",
		"bioroid_name": "A1 TEST",
		"bioroid_hash": "a1-fixed-hash",
		"dna_ratio": {"ald": 50, "kln": 30, "chm": 20},
		"stats": {"vital_integrity": 100, "neural_control": 85, "mutation_load": 14, "core_stress": 40, "atk": 25, "ep": 60},
		"sprite_path": "res://assets/bioroids/sprites/bio_ald_def001_alden_front.png"
	})
	var before: Dictionary = registry.get_combat_result()
	_check(not before.is_empty() and before.has("winner_id") and before.has("loser_id"), "A1-01")
	var first := await _play_once(registry)
	var after: Dictionary = registry.get_combat_result()
	_check(before == after, "A1-02")
	var second := await _play_once(registry)
	_check(first.get("winner_id") == second.get("winner_id") and first.get("loser_id") == second.get("loser_id"), "A1-03")
	_check(first.get("winner_id") == before.get("winner_id") and first.get("loser_id") == before.get("loser_id"), "A1-04")
	print("[A1] RESULT %s" % ("PASS 4/4" if failures.is_empty() else "FAIL " + str(failures)))
	quit(0 if failures.is_empty() else 1)

func _play_once(registry: Node) -> Dictionary:
	var packed := load("res://scenes/arena_battle_scene.tscn") as PackedScene
	var scene: Node = packed.instantiate()
	var auto_capture: Node = scene.get_node_or_null("AutoCapture")
	if auto_capture:
		auto_capture.free()
	var arena: Node = scene.get_node("ArenaBattleManager")
	arena.registry_override = registry
	var ended: Array[Dictionary] = []
	arena.battle_ended.connect(func(_won: bool, audit: Dictionary): ended.append(audit))
	root.add_child(scene)
	var frame_budget := 900
	while ended.is_empty() and frame_budget > 0:
		await process_frame
		frame_budget -= 1
	var result: Dictionary = ended[0] if not ended.is_empty() else {}
	scene.queue_free()
	await process_frame
	return result

func _check(condition: bool, gate: String) -> void:
	print("[%s] %s" % [gate, "PASS" if condition else "FAIL"])
	if not condition:
		failures.append(gate)
