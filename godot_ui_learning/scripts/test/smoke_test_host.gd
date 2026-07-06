extends Node

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var test_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test="):
			test_path = arg.substr("--test=".length())
			break

	if test_path.is_empty():
		push_error("Missing --test=<script> argument")
		get_tree().quit(1)
		return

	var test_script := load(test_path)
	if test_script == null:
		push_error("Failed to load test script: %s" % test_path)
		get_tree().quit(1)
		return


	var test_node: Node = test_script.new()
	if test_node == null:
		push_error("Failed to instantiate test script: %s" % test_path)
		get_tree().quit(1)
		return

	get_tree().root.add_child(test_node)
