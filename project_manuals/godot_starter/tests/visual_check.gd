extends SceneTree

var _failures: Array[String] = []

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
	
	# Set a default window size for consistent screenshots
	root.title = "CRISIS ACTOR - Visual Check"
	
	await process_frame
	await process_frame

	# References
	var search_input: LineEdit = app.get_node("Root/Columns/ContentPanel/ContentMargin/ContentRows/SearchContainer/SearchInput") as LineEdit
	var search_count: Label = app.get_node("Root/Columns/ContentPanel/ContentMargin/ContentRows/SearchContainer/SearchCount") as Label
	var doc_selector: OptionButton = app.get_node("Root/Columns/ContentPanel/ContentMargin/ContentRows/SearchContainer/DocSelector") as OptionButton
	var comp_label: Label = app.get_node("Root/Columns/OpsPanel/OpsMargin/OpsRows/ClocksGrid/CompLabel") as Label
	var comp_inc: Button = app.get_node("Root/Columns/OpsPanel/OpsMargin/OpsRows/ClocksGrid/CompInc") as Button
	
	var add_white_btn: Button = app.get_node("Root/Columns/OpsPanel/OpsMargin/OpsRows/CardAddFlow/AddWhiteBtn") as Button
	var form_panel: PanelContainer = app.get_node("Root/Columns/OpsPanel/OpsMargin/OpsRows/CardFormPanel") as PanelContainer
	var input_title: LineEdit = app.get_node("Root/Columns/OpsPanel/OpsMargin/OpsRows/CardFormPanel/FormMargin/FormRows/InputTitle") as LineEdit
	var input_fact: LineEdit = app.get_node("Root/Columns/OpsPanel/OpsMargin/OpsRows/CardFormPanel/FormMargin/FormRows/InputFact") as LineEdit
	var form_submit_btn: Button = app.get_node("Root/Columns/OpsPanel/OpsMargin/OpsRows/CardFormPanel/FormMargin/FormRows/FormButtons/FormSubmitBtn") as Button

	# Find dynamic guidelines button
	var guidelines_btn: Button = null
	var ops_rows = app.get_node("Root/Columns/OpsPanel/OpsMargin/OpsRows")
	for child in ops_rows.get_children():
		if child is Button and child.text.contains("表現調整ガイドライン"):
			guidelines_btn = child as Button
			break

	# 1. Capture Initial State (Rulebook)
	await _capture("visual_check_01_init.png")

	# 2. Select EP2, expand guidelines, and increment clock
	var ep2_index := -1
	for index in range(doc_selector.item_count):
		if doc_selector.get_item_text(index) == "シナリオ EP2":
			ep2_index = index
			break
	if ep2_index >= 0:
		doc_selector.select(ep2_index)
		doc_selector.item_selected.emit(ep2_index)
		await process_frame
		await process_frame
		
		# Expand guidelines
		if guidelines_btn:
			guidelines_btn.button_pressed = true
			guidelines_btn.toggled.emit(true)
			await process_frame
		
		# Increment clock
		comp_inc.pressed.emit()
		await process_frame
		await process_frame
		
		await _capture("visual_check_02_ep2_guidelines.png")

	# 3. Select EP4 and verify clock representation
	var ep4_index := -1
	for index in range(doc_selector.item_count):
		if doc_selector.get_item_text(index) == "シナリオ EP4":
			ep4_index = index
			break
	if ep4_index >= 0:
		doc_selector.select(ep4_index)
		doc_selector.item_selected.emit(ep4_index)
		await process_frame
		await process_frame
		
		await _capture("visual_check_03_ep4_init.png")
		
		# 4. Advance EP4 clock to max (complicity_clock is currently 1, increment 5 times to make it 6)
		for k in range(5):
			comp_inc.pressed.emit()
			await process_frame
		await process_frame
		
		await _capture("visual_check_04_ep4_clock_max.png")

	# 5. Open card form
	add_white_btn.pressed.emit()
	await process_frame
	await process_frame
	await _capture("visual_check_05_card_form.png")

	# Submit a test card
	input_title.text = "テスト公開審判カード"
	input_fact.text = "広報庁による最終的な要約版の公開プロセスを完了した。"
	form_submit_btn.pressed.emit()
	await process_frame
	await process_frame

	# Close guidelines to clean up UI space
	if guidelines_btn:
		guidelines_btn.button_pressed = false
		guidelines_btn.toggled.emit(false)
		await process_frame

	# 6. Capture main screen with card added
	await _capture("visual_check_06_card_added.png")

	# 7. Search verification (Input "広報庁")
	search_input.text = "広報庁"
	search_input.text_changed.emit("広報庁")
	await create_timer(0.2).timeout
	await process_frame
	await _capture("visual_check_07_search_highlight.png")

	# Finish
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
