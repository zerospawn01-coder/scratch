extends Node

@export var output_filename: String = "exploration_demo.png"
@export var delay_seconds: float = 1.0

func _ready() -> void:
	print("[AutoCapture] Waiting %f seconds for scene rendering..." % delay_seconds)
	await get_tree().create_timer(delay_seconds).timeout
	
	var viewport = get_viewport()
	if viewport:
		var img = viewport.get_texture().get_image()
		if img:
			DirAccess.make_dir_recursive_absolute("res://screenshots")
			var save_path = "res://screenshots/" + output_filename
			var err = img.save_png(save_path)
			if err == OK:
				print("[AutoCapture] SUCCESS! Saved screenshot to: ", save_path)
			else:
				print("[AutoCapture] ERROR saving image: ", err)
	
	get_tree().quit(0)
