class_name DialogueController
extends Node

# =============================================================================
# NPC Dialogue System & Manager (Aether Fountain v1.0)
# Principle: generation_is_not_authority & state_integrity
# Provides deterministic dialogue retrieval, line playback, and UI event hooks.
# =============================================================================

signal dialogue_started(dialogue_id: String, context: String)
signal line_displayed(speaker_id: String, speaker_name: String, text: String, emotion: String)
signal dialogue_completed(dialogue_id: String)

const DIALOGUE_DATA_PATH: String = "res://data/npc_dialogues.json"

var _dialogue_database: Dictionary = {}
var _characters: Dictionary = {}
var _active_dialogue_id: String = ""
var _current_line_index: int = 0
var _active_lines: Array = []
var is_active: bool = false

func _init() -> void:
	load_dialogue_database(DIALOGUE_DATA_PATH)

## Load JSON dialogue asset into memory
func load_dialogue_database(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_warning("[DialogueManager] Dialogue file not found: %s" % path)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("[DialogueManager] Could not open dialogue file: %s" % path)
		return false
	var content := file.get_as_text()
	var json := JSON.new()
	var parse_result := json.parse(content)
	if parse_result != OK:
		push_warning("[DialogueManager] JSON parse error in dialogue database: %s" % json.get_error_message())
		return false
	var data = json.get_data()
	if not (data is Dictionary):
		push_warning("[DialogueManager] Root dialogue data is not a Dictionary")
		return false

	_characters = data.get("characters", {})
	_dialogue_database = data.get("dialogues", {})
	return true

## Start playback of a dialogue by ID
func play_dialogue(dialogue_id: String) -> bool:
	if not _dialogue_database.has(dialogue_id):
		push_warning("[DialogueManager] Unknown dialogue ID: %s" % dialogue_id)
		return false

	var d_data: Dictionary = _dialogue_database[dialogue_id]
	_active_dialogue_id = dialogue_id
	_active_lines = d_data.get("lines", [])
	_current_line_index = 0
	is_active = true

	dialogue_started.emit(_active_dialogue_id, d_data.get("context", ""))
	_display_current_line()
	return true

## Start playback by context string
func play_context(context_id: String) -> bool:
	for d_id in _dialogue_database.keys():
		var d_data: Dictionary = _dialogue_database[d_id]
		if d_data.get("context", "") == context_id:
			return play_dialogue(d_id)
	push_warning("[DialogueManager] No dialogue matching context: %s" % context_id)
	return false

## Advance to the next line in the active dialogue
func advance_line() -> bool:
	if not is_active:
		return false
	_current_line_index += 1
	if _current_line_index >= _active_lines.size():
		var completed_id := _active_dialogue_id
		is_active = false
		_active_dialogue_id = ""
		_active_lines = []
		dialogue_completed.emit(completed_id)
		return false
	else:
		_display_current_line()
		return true

func _display_current_line() -> void:
	if _current_line_index < 0 or _current_line_index >= _active_lines.size():
		return
	var line_dict: Dictionary = _active_lines[_current_line_index]
	var speaker_id: String = line_dict.get("speaker", "UNKNOWN")
	var text: String = line_dict.get("text", "")
	var emotion: String = line_dict.get("emotion", "NEUTRAL")

	var char_data: Dictionary = _characters.get(speaker_id, {})
	var speaker_name: String = char_data.get("name", speaker_id)

	line_displayed.emit(speaker_id, speaker_name, text, emotion)

func get_character(speaker_id: String) -> Dictionary:
	return _characters.get(speaker_id, {})

func has_dialogue(dialogue_id: String) -> bool:
	return _dialogue_database.has(dialogue_id)
