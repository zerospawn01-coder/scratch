extends SceneTree

func _init() -> void:
	if ClassDB.class_exists("LimboHSM"):
		print("[LIMBOAI] SUCCESS: LimboHSM exists.")
	else:
		print("[LIMBOAI] ERROR: LimboHSM NOT FOUND.")
		
	if ClassDB.class_exists("BTPlayer"):
		print("[LIMBOAI] SUCCESS: BTPlayer exists.")
	else:
		print("[LIMBOAI] ERROR: BTPlayer NOT FOUND.")
		
	quit(0)
