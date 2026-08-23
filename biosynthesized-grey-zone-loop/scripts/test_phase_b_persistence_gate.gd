extends SceneTree

# =============================================================================
# Phase B Verification Gate — Persistence & Data Master Verification
# Verifies:
#   1. Master data loading: enemy_bioroids.json and gene_fragments.json
#   2. Persistence save and load with SHA-256 envelope checksum
#   3. Fault-injection: intentional checksum tampering triggers fail-closed error
# =============================================================================

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("\n============================================================")
	print(" [PHASE B GATE] PERSISTENCE & DATA-DRIVEN ARCHITECTURE")
	print("============================================================")

	# 1. Verify Enemy Master Data
	assert(FileAccess.file_exists("res://data/enemy_bioroids.json"), "enemy_bioroids.json must exist")
	var enemy_file = FileAccess.open("res://data/enemy_bioroids.json", FileAccess.READ)
	var enemy_json = JSON.new()
	assert(enemy_json.parse(enemy_file.get_as_text()) == OK, "enemy_bioroids.json must be valid JSON")
	var enemy_data = enemy_json.get_data()
	assert(enemy_data["enemies"].has("SUBJECT_AF09"), "SUBJECT_AF09 must be defined")
	print("[GATE-B1] PASS: Enemy master data loaded (entries: %d)" % enemy_data["enemies"].size())

	# 2. Verify Gene Fragment Master Data
	assert(FileAccess.file_exists("res://data/gene_fragments.json"), "gene_fragments.json must exist")
	var frag_file = FileAccess.open("res://data/gene_fragments.json", FileAccess.READ)
	var frag_json = JSON.new()
	assert(frag_json.parse(frag_file.get_as_text()) == OK, "gene_fragments.json must be valid JSON")
	var frag_data = frag_json.get_data()
	assert(frag_data["fragments"].has("FRAG_ALDEN_CERAMIC"), "FRAG_ALDEN_CERAMIC must be defined")
	print("[GATE-B2] PASS: Gene fragment master data loaded (entries: %d)" % frag_data["fragments"].size())

	# 3. Persistence Save & Load Round-trip Test
	var persistence_class = load("res://scripts/persistence_manager.gd")
	var test_save_path := "user://test_audit_save.json"
	var test_state := {
		"run_id": "RUN-TEST-9999",
		"cycle_count": 4,
		"resources": {"gene_fragments": 12, "contamination": 0.24},
		"ledger_snapshot": [
			{"index": 1, "hash": "HASH_1", "status": "STABLE"},
			{"index": 2, "hash": "HASH_2", "status": "STABLE"}
		]
	}

	var save_res = persistence_class.save_game_state(test_state, test_save_path)
	assert(save_res["success"] == true, "Save operation must succeed")
	print("[GATE-B3] PASS: Game state saved with checksum: %s" % save_res["checksum"])

	var load_res = persistence_class.load_game_state(test_save_path)
	if not load_res.get("success", false):
		print("[GATE-B4 DEBUG] load_res error details: ", load_res)
	assert(load_res["success"] == true, "Load operation must succeed")
	assert(load_res["data"]["run_id"] == "RUN-TEST-9999", "Loaded state run_id must match")
	assert(load_res["data"]["resources"]["gene_fragments"] == 12, "Resources must match exactly")
	print("[GATE-B4] PASS: Game state verified and loaded cleanly with matched checksum")


	# 4. Fault-Injection: Corrupt save file and verify fail-closed detection
	var raw_save = FileAccess.open(test_save_path, FileAccess.READ).get_as_text()
	var tampered_save = raw_save.replace("RUN-TEST-9999", "RUN-TAMPERED-0000")
	var corrupt_file = FileAccess.open(test_save_path, FileAccess.WRITE)
	corrupt_file.store_string(tampered_save)
	corrupt_file.close()

	var corrupt_load = persistence_class.load_game_state(test_save_path)
	assert(corrupt_load["success"] == false, "Tampered save file must fail loading")
	assert(corrupt_load["error"] == "CHECKSUM_MISMATCH", "Error must be CHECKSUM_MISMATCH")
	print("[GATE-B5] PASS: Save file tampering detected (reason: %s)" % corrupt_load["error"])

	print("============================================================")
	print(" PHASE B PERSISTENCE RESULTS: 5 / 5 GATES PASSED")
	print("============================================================\n")
	quit(0)
