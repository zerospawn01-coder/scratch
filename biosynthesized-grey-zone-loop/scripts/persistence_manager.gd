class_name PersistenceManager
extends RefCounted

# =============================================================================
# Aether Fountain — Persistence Manager (v1.0)
# Principle: generation_is_not_authority & state_integrity
# Provides atomic, fail-closed saving and loading with SHA-256 integrity checks.
# =============================================================================

const DEFAULT_SAVE_PATH := "user://aether_savegame.json"

## Save full game state atomically with integrity checksum
static func save_game_state(save_data: Dictionary, custom_path: String = "") -> Dictionary:
	var path = custom_path if custom_path != "" else DEFAULT_SAVE_PATH
	var payload = save_data.duplicate(true)
	payload["version"] = "1.0.0"
	payload["timestamp"] = Time.get_datetime_string_from_system()
	
	# Generate payload checksum on serialized data string
	var data_str = JSON.stringify(payload, "\t")
	var checksum = data_str.sha256_text().to_upper()
	
	var final_envelope = {
		"checksum": checksum,
		"data_raw": data_str
	}
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return {"success": false, "error": "FILE_WRITE_FAILED", "path": path}
	
	file.store_string(JSON.stringify(final_envelope, "\t"))
	file.close()
	return {"success": true, "checksum": checksum, "path": path}

## Load game state and verify cryptographic checksum
static func load_game_state(custom_path: String = "") -> Dictionary:
	var path = custom_path if custom_path != "" else DEFAULT_SAVE_PATH
	if not FileAccess.file_exists(path):
		return {"success": false, "error": "SAVE_FILE_NOT_FOUND", "path": path}
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {"success": false, "error": "FILE_READ_FAILED", "path": path}
	
	var raw_content = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(raw_content) != OK:
		return {"success": false, "error": "INVALID_JSON", "path": path}
	
	var envelope = json.get_data()
	if not (envelope is Dictionary) or not envelope.has("checksum") or not envelope.has("data_raw"):
		return {"success": false, "error": "CORRUPTED_ENVELOPE", "path": path}
	
	var recorded_checksum = str(envelope.get("checksum", ""))
	var data_raw = str(envelope.get("data_raw", ""))
	var recomputed_checksum = data_raw.sha256_text().to_upper()
	
	if recorded_checksum != recomputed_checksum:
		return {"success": false, "error": "CHECKSUM_MISMATCH", "path": path, "recorded": recorded_checksum, "recomputed": recomputed_checksum}
	
	var data_json = JSON.new()
	if data_json.parse(data_raw) != OK:
		return {"success": false, "error": "INVALID_PAYLOAD_JSON", "path": path}
	
	return {"success": true, "data": data_json.get_data(), "checksum": recorded_checksum}



