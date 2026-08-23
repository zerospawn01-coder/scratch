extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://scenes/main_terminal.tscn") as PackedScene
	var terminal = scene.instantiate()
	root.add_child(terminal)

	var capture_script = load("res://scripts/auto_capture.gd")
	var capture = capture_script.new()
	capture.output_filename = "main_terminal_pc_console.png"
	capture.delay_seconds = 0.5
	terminal.add_child(capture)
