extends Node

const SAVE_PATH: String = "user://neo_sovereign_save.cfg"
const LEGACY_PHASE6_SAVE_PATH: String = "user://phase6_progress.cfg"

var data: float = 0.0
var miners_owned: int = 0
var hp_level: int = 0
var damage_level: int = 0

var best_scores: Array[int] = [0, 0, 0]
var runs_completed: int = 0

const INITIAL_SECTOR_STATES: Dictionary = {
	"core_chamber": "ONLINE",
	"expedition_gate": "ONLINE",
	"material_locker": "ONLINE",
	"observation_cage": "COLLAPSED",
	"proto_vat": "ONLINE",
	"research_log": "LOCKED",
	"arena_terminal": "LOCKED"
}
var sector_states: Dictionary = INITIAL_SECTOR_STATES.duplicate()
var current_combat_sector: String = ""

const SECTOR_CONNECTIONS: Array[Dictionary] = [
	{"from": "core_chamber", "to": "expedition_gate"},
	{"from": "core_chamber", "to": "material_locker"},
	{"from": "core_chamber", "to": "observation_cage"},
	{"from": "core_chamber", "to": "proto_vat"},
	{"from": "proto_vat", "to": "research_log"},
	{"from": "research_log", "to": "arena_terminal"}
]

func _ready() -> void:
	load_data()

func save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("resources", "data", data)
	cfg.set_value("resources", "miners_owned", miners_owned)
	cfg.set_value("upgrades", "hp_level", hp_level)
	cfg.set_value("upgrades", "damage_level", damage_level)
	cfg.set_value("progress", "best_scores", best_scores)
	cfg.set_value("progress", "runs_completed", runs_completed)
	cfg.set_value("progress", "sector_states", sector_states)
	
	var result := cfg.save(SAVE_PATH)
	if result != OK:
		push_warning("Failed to save global data: %s" % error_string(result))

func load_data() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		data = cfg.get_value("resources", "data", 0.0)
		miners_owned = int(cfg.get_value("resources", "miners_owned", 0))
		hp_level = int(cfg.get_value("upgrades", "hp_level", 0))
		damage_level = int(cfg.get_value("upgrades", "damage_level", 0))
		
		var loaded_scores = cfg.get_value("progress", "best_scores", null)
		if loaded_scores is Array and (loaded_scores as Array).size() == 3:
			for i in range(3):
				best_scores[i] = int((loaded_scores as Array)[i])
		
		runs_completed = int(cfg.get_value("progress", "runs_completed", 0))
		
		var loaded_sectors = cfg.get_value("progress", "sector_states", null)
		if loaded_sectors is Dictionary:
			for key in loaded_sectors:
				sector_states[key] = loaded_sectors[key]
	else:
		# 既存のPhase 6セーブデータがあればマイグレーション
		if cfg.load(LEGACY_PHASE6_SAVE_PATH) == OK:
			runs_completed = int(cfg.get_value("progress", "runs_completed", 0))
			var loaded_scores = cfg.get_value("progress", "best_scores", null)
			if loaded_scores is Array and (loaded_scores as Array).size() == 3:
				for i in range(3):
					best_scores[i] = int((loaded_scores as Array)[i])
			else:
				var legacy_best := int(cfg.get_value("progress", "best_score", 0))
				best_scores[0] = legacy_best
			save_data() # マイグレーション結果を新ファイルに保存

func complete_sector(sector_id: String) -> void:
	if sector_states.get(sector_id) == "ONLINE":
		sector_states[sector_id] = "CLEARED"
		_unlock_next_sectors(sector_id)
		save_data()

func _unlock_next_sectors(sector_id: String) -> void:
	for conn in SECTOR_CONNECTIONS:
		if conn["from"] == sector_id:
			var to_id = conn["to"]
			if sector_states.get(to_id) == "LOCKED":
				sector_states[to_id] = "ONLINE"
