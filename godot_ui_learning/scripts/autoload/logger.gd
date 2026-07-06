extends Node

enum LogLevel {
	DEBUG,
	INFO,
	WARN,
	ERROR,
	AUDIT
}

var _ledger_file: FileAccess
var _log_path: String = "user://ledger.jsonl"
var _buffer: Array[String] = []
const MAX_BUFFER_SIZE = 10

func _ready() -> void:
	_open_ledger()

func set_ledger_path(path: String) -> void:
	flush()
	if _ledger_file:
		_ledger_file.close()
	_log_path = path
	_open_ledger()

func _open_ledger() -> void:
	_ledger_file = FileAccess.open(_log_path, FileAccess.READ_WRITE)
	if _ledger_file == null:
		_ledger_file = FileAccess.open(_log_path, FileAccess.WRITE)
	if _ledger_file != null:
		_ledger_file.seek_end()

func debug(category: String, message: String, data: Dictionary = {}) -> void:
	_log(LogLevel.DEBUG, category, message, data)

func info(category: String, message: String, data: Dictionary = {}) -> void:
	_log(LogLevel.INFO, category, message, data)

func warn(category: String, message: String, data: Dictionary = {}) -> void:
	_log(LogLevel.WARN, category, message, data)

func error(category: String, message: String, data: Dictionary = {}) -> void:
	_log(LogLevel.ERROR, category, message, data)

func audit(category: String, action: String, data: Dictionary = {}) -> void:
	_log(LogLevel.AUDIT, category, action, data)

func _log(level: LogLevel, category: String, message: String, data: Dictionary) -> void:
	var level_str = _level_to_string(level)
	
	var timestamp = Time.get_datetime_string_from_system(true)
	
	# Godot console print
	if level != LogLevel.DEBUG or OS.is_stdout_verbose():
		var console_msg = "[%s] [%s] %s" % [level_str, category, message]
		if data.size() > 0:
			console_msg += " | " + JSON.stringify(data)
			
		if level == LogLevel.ERROR:
			push_error(console_msg)
		elif level == LogLevel.WARN:
			push_warning(console_msg)
		else:
			print(console_msg)
			
	# Append to JSONL buffer
	var entry := {
		"timestamp": timestamp,
		"level": level_str,
		"category": category,
		"message": message,
		"data": data
	}
	
	_buffer.append(JSON.stringify(entry))
	
	if _buffer.size() >= MAX_BUFFER_SIZE or level >= LogLevel.WARN:
		flush()

func flush() -> void:
	if _buffer.is_empty():
		return
	if _ledger_file and _ledger_file.is_open():
		for line in _buffer:
			_ledger_file.store_line(line)
		_ledger_file.flush()
	_buffer.clear()

func _exit_tree() -> void:
	flush()
	if _ledger_file:
		_ledger_file.close()

func _level_to_string(level: LogLevel) -> String:
	match level:
		LogLevel.DEBUG: return "DEBUG"
		LogLevel.INFO: return "INFO"
		LogLevel.WARN: return "WARN"
		LogLevel.ERROR: return "ERROR"
		LogLevel.AUDIT: return "AUDIT"
	return "UNKNOWN"
