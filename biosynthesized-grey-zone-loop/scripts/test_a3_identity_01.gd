extends SceneTree

func _init() -> void:
	var registry: Node = load("res://scripts/bioroid_registry.gd").new()
	var first: Dictionary = _register(registry, "BIO-LOT-001", "hash-lot-001")
	var second: Dictionary = _register(registry, "BIO-LOT-002", "hash-lot-002")
	var different: bool = first.opponent_id != second.opponent_id and first.opponent_name != second.opponent_name
	var complete: bool = ["opponent_id", "opponent_name", "opponent_model_id", "opponent_attribute", "opponent_threat_class"].all(func(key: String): return second.has(key))
	var winner_consistent: bool = second.winner_id == second.opponent_id
	print("[A3-IDENTITY-01] %s first=%s/%s second=%s/%s" % ["PASS" if different else "FAIL", first.opponent_id, first.opponent_name, second.opponent_id, second.opponent_name])
	print("[A3-IDENTITY-02] %s metadata_complete=%s winner_consistent=%s" % ["PASS" if complete and winner_consistent else "FAIL", complete, winner_consistent])
	quit(0 if different and complete and winner_consistent else 1)

func _register(registry: Node, unit_id: String, unit_hash: String) -> Dictionary:
	registry.register_deployment_payload({
		"bioroid_id": unit_id,
		"bioroid_hash": unit_hash,
		"stats": {"neural_control": 85, "mutation_load": 14, "core_stress": 40, "atk": 25}
	})
	return registry.get_combat_result()
