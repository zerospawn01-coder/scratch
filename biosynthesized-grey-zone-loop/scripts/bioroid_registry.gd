extends Node

## Aether Fountain — Sovereign Audit Ledger Singleton
## Manages Bioroid Deployment Payloads and Post-Combat Audit Records

var active_deployment_payload: Dictionary = {}
var audit_ledger: Array[Dictionary] = []

## Register formal deployment payload from Gene Mixer
func register_deployment_payload(payload: Dictionary) -> void:
	active_deployment_payload = payload.duplicate(true)
	var hash_preview = str(active_deployment_payload.get("bioroid_hash", "")).substr(0, 16)
	print("[BioroidRegistry] Active Deployment Payload Registered:")
	print("  - ID: ", active_deployment_payload.get("bioroid_id", "UNKNOWN"))
	print("  - HASH: ", hash_preview, "...")
	print("  - DNA: ", active_deployment_payload.get("dna_ratio", {}))

## Retrieve active deployment payload with fail-closed default
func get_deployment_payload() -> Dictionary:
	if active_deployment_payload.is_empty():
		# Fail-closed default baseline: Alden Standard Specimen
		return {
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
	return active_deployment_payload

const GENESIS_HASH: String = "0000000000000000000000000000000000000000000000000000000000000000"

## Helper to calculate cryptographic entry hash from canonical serialized audit data
func compute_entry_hash(record: Dictionary) -> String:
	var index_str := str(record.get("ledger_index", 0))
	var prev_hash := str(record.get("previous_entry_hash", GENESIS_HASH))
	var run_id := str(record.get("run_id", ""))
	var bioroid_hash := str(record.get("bioroid_hash", ""))
	var opponent_id := str(record.get("opponent_id", ""))
	var result := str(record.get("result", ""))
	var final_status := str(record.get("final_status", ""))
	var combat_seed := str(record.get("combat_seed", 0))
	var turns := str(record.get("turns_elapsed", record.get("turns", 0)))
	var damage := str(record.get("damage_taken", 0))

	var raw_canonical := "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
		index_str, prev_hash, run_id, bioroid_hash, opponent_id, result, final_status, combat_seed, turns, damage
	]
	return raw_canonical.sha256_text()

## Record detailed post-combat audit log with cryptographic hash chain linking
func record_audit_entry(audit_record: Dictionary) -> void:
	var record = audit_record.duplicate(true)
	record["ledger_index"] = audit_ledger.size() + 1
	record["recorded_at"] = Time.get_datetime_string_from_system()

	# Establish cryptographic hash chain
	var prev_hash = GENESIS_HASH
	if not audit_ledger.is_empty():
		prev_hash = audit_ledger[-1].get("entry_hash", GENESIS_HASH)
	record["previous_entry_hash"] = prev_hash
	record["entry_hash"] = compute_entry_hash(record)

	audit_ledger.append(record)
	
	var hash_preview = str(record.get("bioroid_hash", "N/A")).substr(0, 16)
	var entry_hash_preview = str(record.get("entry_hash", "N/A")).substr(0, 16)
	print("\n============================================================")
	print(" [SOVEREIGN AUDIT LEDGER] NEW ENTRY COMMITTED #", record["ledger_index"])
	print("  RUN ID:       ", record.get("run_id", "N/A"))
	print("  SUBJECT HASH: ", hash_preview, "...")
	print("  ENTRY HASH:   ", entry_hash_preview, "...")
	print("  PREV HASH:    ", str(record.get("previous_entry_hash", "N/A")).substr(0, 16), "...")
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

## Cryptographic Ledger Verification
## Validates monotonic indexing, predecessor hash continuity, and payload integrity.
func verify_ledger_integrity() -> Dictionary:
	if audit_ledger.is_empty():
		return {
			"is_valid": true,
			"error": "",
			"verified_count": 0,
			"broken_index": -1
		}

	var expected_prev_hash := GENESIS_HASH
	for i in range(audit_ledger.size()):
		var entry: Dictionary = audit_ledger[i]
		var expected_index := i + 1

		# 1. Monotonic Index Integrity
		if entry.get("ledger_index", -1) != expected_index:
			return {
				"is_valid": false,
				"error": "Index mismatch at position %d (got %s, expected %d)" % [i, str(entry.get("ledger_index")), expected_index],
				"verified_count": i,
				"broken_index": expected_index
			}

		# 2. Previous Hash Link Continuity
		if entry.get("previous_entry_hash", "") != expected_prev_hash:
			return {
				"is_valid": false,
				"error": "Broken hash chain at entry #%d (previous_entry_hash mismatch)" % expected_index,
				"verified_count": i,
				"broken_index": expected_index
			}

		# 3. Entry Hash Payload Integrity
		var calculated_hash := compute_entry_hash(entry)
		if entry.get("entry_hash", "") != calculated_hash:
			return {
				"is_valid": false,
				"error": "Tampered payload detected at entry #%d (stored %s != computed %s)" % [
					expected_index, str(entry.get("entry_hash")), calculated_hash
				],
				"verified_count": i,
				"broken_index": expected_index
			}

		expected_prev_hash = entry.get("entry_hash", "")

	return {
		"is_valid": true,
		"error": "",
		"verified_count": audit_ledger.size(),
		"broken_index": -1
	}


