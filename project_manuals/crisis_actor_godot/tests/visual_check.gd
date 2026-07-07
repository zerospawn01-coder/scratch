extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		printerr("FAIL: main.tscn could not be loaded.")
		quit(1)
		return

	var app: Node = packed.instantiate()
	root.add_child(app)
	
	root.title = "CRISIS ACTOR - Visual Check"
	
	await process_frame
	await process_frame

	# 1. Capture Initial State
	await _capture("visual_check_01_init.png")

	# 2. Select EP2
	var scenario_opt: OptionButton = app.get("_scenario_option") as OptionButton
	scenario_opt.select(0)
	scenario_opt.item_selected.emit(0)
	app.call("_on_load_scenario_pressed")
	await process_frame
	await process_frame
	await _capture("visual_check_02_ep2_loaded.png")

	# 3. Open card form (simulate typing a card)
	var title_edit = app.get("_card_title_edit") as LineEdit
	var body_edit = app.get("_card_body_edit") as TextEdit
	title_edit.text = "テスト公開審判カード"
	body_edit.text = "広報庁による最終的な要約版の公開プロセスを完了した。"
	await process_frame
	await _capture("visual_check_05_card_form.png")
	
	app.call("_on_add_card_pressed")
	await process_frame
	await process_frame
	await _capture("visual_check_06_card_added.png")

	print("VISUAL_CHECK_COMPLETED")
	root.remove_child(app)
	app.queue_free()
	quit(0)

func _capture(filename: String) -> void:
	await process_frame
	await process_frame
	var img = root.get_viewport().get_texture().get_image()
	if img:
		var err = img.save_png("res://" + filename)
		if err == OK:
			print("Captured: %s" % filename)
		else:
			printerr("Failed to save capture: %s (error %d)" % [filename, err])
	else:
		printerr("Failed to get viewport image for %s" % filename)
