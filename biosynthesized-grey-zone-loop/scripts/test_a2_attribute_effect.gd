extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var on_first: Dictionary = await _play(true)
	var on_second: Dictionary = await _play(true)
	var off_run: Dictionary = await _play(false)
	var expected := ["ANTICIPATION:CORROSIVE:1.0", "IMPACT:CORROSIVE:1.0", "ANTICIPATION:CORROSIVE:1.0", "FINISH:CORROSIVE:2.0"]
	var gate_01: bool = on_first.events == expected
	var gate_03: bool = off_run.events.is_empty() and off_run.winner_id == on_first.winner_id and off_run.loser_id == on_first.loser_id
	var gate_04: bool = on_first.events == on_second.events and on_first.winner_id == on_second.winner_id and on_first.loser_id == on_second.loser_id
	print("[A2-EFFECT-01] %s events=%s" % ["PASS" if gate_01 else "FAIL", on_first.events])
	print("[A2-EFFECT-03] %s" % ["PASS" if gate_03 else "FAIL"])
	print("[A2-EFFECT-04] %s" % ["PASS" if gate_04 else "FAIL"])
	quit(0 if gate_01 and gate_03 and gate_04 else 1)

func _play(effects_enabled: bool) -> Dictionary:
	var registry: Node = load("res://scripts/bioroid_registry.gd").new()
	root.add_child(registry)
	registry.register_deployment_payload({
		"run_id": "A2-TEST",
		"bioroid_id": "BIO-A2-TEST",
		"bioroid_hash": "a2-fixed-hash",
		"dna_ratio": {},
		"stats": {"neural_control": 85, "mutation_load": 14, "core_stress": 40, "atk": 25, "ep": 60},
		"sprite_path": "res://assets/bioroids/sprites/bio_ald_def001_alden_front.png"
	})
	var scene: Node = (load("res://scenes/arena_battle_scene.tscn") as PackedScene).instantiate()
	var auto_capture: Node = scene.get_node_or_null("AutoCapture")
	if auto_capture:
		auto_capture.free()
	var arena: Node = scene.get_node("ArenaBattleManager")
	arena.registry_override = registry
	arena.attribute_effects_enabled = effects_enabled
	var events: Array[String] = []
	var audit: Dictionary = {}
	arena.attribute_effect_triggered.connect(func(stage: String, attribute: String, intensity: float): events.append("%s:%s:%.1f" % [stage, attribute, intensity]))
	arena.battle_ended.connect(func(_won: bool, record: Dictionary): audit = record)
	root.add_child(scene)
	var budget := 900
	while audit.is_empty() and budget > 0:
		await process_frame
		budget -= 1
	var result := {"events": events.duplicate(), "winner_id": audit.get("winner_id", ""), "loser_id": audit.get("loser_id", "")}
	scene.queue_free()
	registry.queue_free()
	await process_frame
	return result
