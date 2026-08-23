extends Node

## Aether Fountain — Sovereign Audit Ledger Singleton
## Manages Bioroid Deployment Payloads and Post-Combat Audit Records

var active_deployment_payload: Dictionary = {}
var audit_ledger: Array[Dictionary] = []

## Register formal deployment payload from Gene Mixer
func register_deployment_payload(payload: Dictionary) -> void:
	active_deployment_payload = payload.duplicate(true)
	if not active_deployment_payload.has("combat_result"):
		active_deployment_payload["combat_result"] = _simulate_combat_result(active_deployment_payload)
	var hash_preview = str(active_deployment_payload.get("bioroid_hash", "")).substr(0, 16)
	print("[BioroidRegistry] Active Deployment Payload Registered:")
	print("  - ID: ", active_deployment_payload.get("bioroid_id", "UNKNOWN"))
	print("  - HASH: ", hash_preview, "...")
	print("  - DNA: ", active_deployment_payload.get("dna_ratio", {}))

## Retrieve active deployment payload with fail-closed default
func get_deployment_payload() -> Dictionary:
	if active_deployment_payload.is_empty():
		# Fail-closed default baseline: Alden Standard Specimen
		var default_payload := {
			"run_id": "RUN-DEFAULT-0001",
			"bioroid_id": "BIO-ALD-DEF001",
			"bioroid_name": "ALDEN",
			"bioroid_hash": "8f3a04497f2c5e1b98a0d7f214e6b28c",
			"dna_ratio": {"ald": 50, "kln": 30, "chm": 20},
			"stats": {
				"vital_integrity": 100,
				"neural_control": 85,
				"mutation_load": 14,
				"core_stress": 40,
				"atk": 25,
				"ep": 60
			},
			"mutation_profile": {"surge_risk": "LOW", "instability_rate": 0.05},
			"sprite_path": "res://assets/bioroids/sprites/bio_ald_def001_alden_front.png",
			"generated_at": Time.get_datetime_string_from_system()
		}
		default_payload["combat_result"] = _simulate_combat_result(default_payload)
		return default_payload
	return active_deployment_payload.duplicate(true)

func get_combat_result() -> Dictionary:
	return get_deployment_payload().get("combat_result", {}).duplicate(true)

func _simulate_combat_result(payload: Dictionary) -> Dictionary:
	var stats: Dictionary = payload.get("stats", {})
	var player_score := float(stats.get("neural_control", 0)) + float(stats.get("atk", 0)) * 2.0 - float(stats.get("mutation_load", 0)) - float(stats.get("core_stress", 0)) * 0.25
	var enemy_score := 130.0
	var player_wins := player_score >= enemy_score
	var player_id := str(payload.get("bioroid_id", "BIO-SYN-001"))
	var opponent_signature := str(payload.get("bioroid_hash", player_id)).sha256_text().to_upper()
	var enemy_id := "SUBJECT AF-%s" % opponent_signature.substr(0, 2)
	var enemy_name := "LAMBDA-%s" % opponent_signature.substr(2, 2)
	var enemy_model_id := "AF-LAMBDA/09"
	var winner_side := "PLAYER" if player_wins else "ENEMY"
	var loser_side := "ENEMY" if player_wins else "PLAYER"
	return {
		"winner_id": player_id if player_wins else enemy_id,
		"loser_id": enemy_id if player_wins else player_id,
		"opponent_id": enemy_id,
		"opponent_name": enemy_name,
		"opponent_model_id": enemy_model_id,
		"opponent_attribute": "CORROSIVE",
		"opponent_threat_class": "LAMBDA-4",
		"winner_side": winner_side,
		"loser_side": loser_side,
		"result_type": "SUPPRESSION_SUCCESS" if player_wins else "SPECIMEN_LOST",
		"highlight_duration": 5.0,
		"finish_type": "DECISIVE_STRIKE",
		"critical_moment": 4.0,
		"audit_reason": "Predetermined simulation score %.2f vs %.2f" % [player_score, enemy_score],
		"highlight_plan": [
			{"beat": "EXCHANGE", "attacker": "PLAYER", "attribute": "NONE"},
			{"beat": "COUNTER", "attacker": "ENEMY", "attribute": "CORROSIVE"},
			{"beat": "FINISH", "attacker": winner_side, "attribute": "CORROSIVE" if winner_side == "ENEMY" else "NONE"}
		]
	}

## Record detailed post-combat audit log
func record_audit_entry(audit_record: Dictionary) -> void:
	var record = audit_record.duplicate(true)
	record["ledger_index"] = audit_ledger.size() + 1
	record["recorded_at"] = Time.get_datetime_string_from_system()
	
	# Cryptographic Hash-Chain
	var prev_hash: String = "00000000000000000000000000000000"
	if not audit_ledger.is_empty():
		prev_hash = str(audit_ledger[-1].get("entry_hash", "00000000000000000000000000000000"))
	record["previous_hash"] = prev_hash
	
	var raw_header = "INDEX:%d:PREV:%s:RUN:%s:HASH:%s:RESULT:%s:STATUS:%s" % [
		record["ledger_index"],
		record["previous_hash"],
		str(record.get("run_id", "")),
		str(record.get("bioroid_hash", "")),
		str(record.get("result", "")),
		str(record.get("final_status", ""))
	]
	record["entry_hash"] = raw_header.sha256_text().to_upper().substr(0, 32)
	audit_ledger.append(record)
	
	var hash_preview = str(record.get("bioroid_hash", "N/A")).substr(0, 16)
	print("\n============================================================")
	print(" [SOVEREIGN AUDIT LEDGER] NEW ENTRY COMMITTED #", record["ledger_index"])
	print("  RUN ID:       ", record.get("run_id", "N/A"))
	print("  ENTRY HASH:   ", record.get("entry_hash", "N/A"))
	print("  PREV HASH:    ", record.get("previous_hash", "N/A"))
	print("  SUBJECT HASH: ", hash_preview, "...")
	print("  OPPONENT:     ", record.get("opponent_id", "N/A"))
	print("  RESULT:       ", record.get("result", "N/A"))
	print("  CAUSE:        ", record.get("cause", "N/A"))
	print("  INTERVENTION: ", record.get("intervention_used", []))
	print("  FINAL STATUS: ", record.get("final_status", "N/A"))
	print("============================================================\n")

func get_latest_audit_entry() -> Dictionary:
	if audit_ledger.is_empty():
		return {}
	return audit_ledger[-1]

## Return total number of committed audit entries.
## Read-only API — does not mutate ledger state.
func get_audit_record_count() -> int:
	return audit_ledger.size()

## Verify the mathematical integrity of the entire hash-chain
func verify_ledger_integrity() -> Dictionary:
	var total_entries = audit_ledger.size()
	if total_entries == 0:
		return {"is_valid": true, "total_entries": 0, "error_index": -1, "reason": "EMPTY_LEDGER"}
	
	var expected_prev_hash: String = "00000000000000000000000000000000"
	for i in range(total_entries):
		var entry = audit_ledger[i]
		var idx = entry.get("ledger_index", -1)
		if idx != i + 1:
			return {"is_valid": false, "total_entries": total_entries, "error_index": i + 1, "reason": "INDEX_MISMATCH"}
		
		if entry.get("previous_hash", "") != expected_prev_hash:
			return {"is_valid": false, "total_entries": total_entries, "error_index": i + 1, "reason": "PREV_HASH_MISMATCH"}
		
		var raw_header = "INDEX:%d:PREV:%s:RUN:%s:HASH:%s:RESULT:%s:STATUS:%s" % [
			entry["ledger_index"],
			entry["previous_hash"],
			str(entry.get("run_id", "")),
			str(entry.get("bioroid_hash", "")),
			str(entry.get("result", "")),
			str(entry.get("final_status", ""))
		]
		var recomputed_hash = raw_header.sha256_text().to_upper().substr(0, 32)
		if entry.get("entry_hash", "") != recomputed_hash:
			return {"is_valid": false, "total_entries": total_entries, "error_index": i + 1, "reason": "HASH_CORRUPTION"}
		
		expected_prev_hash = entry.get("entry_hash", "")
	
	return {"is_valid": true, "total_entries": total_entries, "error_index": -1, "reason": "INTEGRITY_VERIFIED"}

