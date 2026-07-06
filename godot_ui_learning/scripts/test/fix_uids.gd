extends SceneTree

func _init() -> void:
	print("[UID_FIXER] Starting mass re-save to fix UID references...")
	var files: Array[String] = []
	_collect(files, "res://")
	
	for f in files:
		var res = load(f)
		if res:
			var err = ResourceSaver.save(res, f)
			if err == OK:
				print("[UID_FIXER] Re-saved: ", f)
			else:
				push_error("[UID_FIXER] Failed to save: " + f)
	print("[UID_FIXER] Mass re-save completed.")
	quit(0)

func _collect(files: Array[String], path: String) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name = dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full = path.path_join(name)
		if dir.current_is_dir():
			_collect(files, full)
		elif full.ends_with(".tscn") or full.ends_with(".tres") or full.ends_with(".gd"):
			files.append(full)
		name = dir.get_next()
	dir.list_dir_end()
