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

## Record detailed post-combat audit log
func record_audit_entry(audit_record: Dictionary) -> void:
	var record = audit_record.duplicate(true)
	record["ledger_index"] = audit_ledger.size() + 1
	record["recorded_at"] = Time.get_datetime_string_from_system()
	audit_ledger.append(record)
	
	var hash_preview = str(record.get("bioroid_hash", "N/A")).substr(0, 16)
	print("\n============================================================")
	print(" [SOVEREIGN AUDIT LEDGER] NEW ENTRY COMMITTED #", record["ledger_index"])
	print("  RUN ID:       ", record.get("run_id", "N/A"))
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

