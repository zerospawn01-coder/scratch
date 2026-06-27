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
	var add_gray_btn: Button = app.get_node("Root/Columns/OpsPanel/OpsMargin/OpsRows/CardAddFlow/AddGrayBtn") as Button
	var add_black_btn: Button = app.get_node("Root/Columns/OpsPanel/OpsMargin/OpsRows/CardAddFlow/AddBlackBtn") as Button
	var add_investigation_btn: Button = app.get_node("Root/Columns/OpsPanel/OpsMargin/OpsRows/CardAddFlow/AddInvestigationBtn") as Button
	
	var form_panel: PanelContainer = app.get_node("Root/Columns/OpsPanel/OpsMargin/OpsRows/CardFormPanel") as PanelContainer
	var input_title: LineEdit = app.get_node("Root/Columns/OpsPanel/OpsMargin/OpsRows/CardFormPanel/FormMargin/FormRows/InputTitle") as LineEdit
	var input_fact: LineEdit = app.get_node("Root/Columns/OpsPanel/OpsMargin/OpsRows/CardFormPanel/FormMargin/FormRows/InputFact") as LineEdit
	var input_cost: LineEdit = app.get_node("Root/Columns/OpsPanel/OpsMargin/OpsRows/CardFormPanel/FormMargin/FormRows/InputCost") as LineEdit
	var input_constraint: LineEdit = app.get_node("Root/Columns/OpsPanel/OpsMargin/OpsRows/CardFormPanel/FormMargin/FormRows/InputConstraint") as LineEdit
	var input_owner: LineEdit = app.get_node("Root/Columns/OpsPanel/OpsMargin/OpsRows/CardFormPanel/FormMargin/FormRows/InputOwner") as LineEdit
	var form_submit_btn: Button = app.get_node("Root/Columns/OpsPanel/OpsMargin/OpsRows/CardFormPanel/FormMargin/FormRows/FormButtons/FormSubmitBtn") as Button
	var card_list_container: VBoxContainer = app.get_node("Root/Columns/OpsPanel/OpsMargin/OpsRows/CardScroll/CardList") as VBoxContainer

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
		
		# Increment unprocessed debt to 3 to trigger warning
		var clocks_grid: GridContainer = app.get_node("Root/Columns/OpsPanel/OpsMargin/OpsRows/ClocksGrid") as GridContainer
		var c_count := clocks_grid.get_child_count()
		var unproc_inc := clocks_grid.get_child(c_count - 1) as Button
		unproc_inc.pressed.emit()
		unproc_inc.pressed.emit()
		unproc_inc.pressed.emit()
		await process_frame
		await process_frame
		
		await _capture("visual_check_04_ep4_clock_max.png")

	# 4.5. Test Audit Pause Button & Message
	if app.get("_audit_pause_btn"):
		var pause_btn = app.get("_audit_pause_btn") as Button
		if pause_btn:
			pause_btn.pressed.emit()
			await process_frame
			await process_frame
			await _capture("visual_check_05b_safety_pause.png")
			# Wait a bit for the warning message timer to settle or reset
			await create_timer(2.1).timeout
			await process_frame

	# 5. Open card form
	add_white_btn.pressed.emit()
	await process_frame
	await process_frame
	await _capture("visual_check_05_card_form.png")

	# Submit a test card
	input_title.text = "テスト公開審判カード"
	input_fact.text = "広報庁による最終的な要約版の公開プロセスを完了した。"
	input_cost.text = "公式説明として固定される。"
	input_constraint.text = "対応する黒カードの露出時、未処理負債+2。"
	input_owner.text = "PC1"
	form_submit_btn.pressed.emit()
	await process_frame
	await process_frame

	# Submit an extended card type (Investigation).
	add_investigation_btn.pressed.emit()
	await process_frame
	input_title.text = "調査対象: 瀬尾アキラの呼吸器症状"
	input_fact.text = "確定診断ではないが、消去できない症状記録。"
	input_cost.text = "追加調査が必要なため白カード化不可。"
	input_constraint.text = "次回セッション冒頭で再照会される。"
	input_owner.text = "PC2"
	form_submit_btn.pressed.emit()
	await process_frame
	await process_frame

	# Submit a Black card
	add_black_btn.pressed.emit()
	await process_frame
	input_title.text = "消された証言"
	input_fact.text = "避難訓練の途中で、何者かが非常扉をロックしたという証言。"
	input_cost.text = "ロックに使われた鍵"
	input_constraint.text = "白カード「非常扉は常時解放されていた」と対立。"
	input_owner.text = "PC2"
	form_submit_btn.pressed.emit()
	await process_frame
	await process_frame

	# Apply Emergency Injunction to the Black card.
	var target_btn: Button = null
	for card_panel in card_list_container.get_children():
		var margin = card_panel.get_child(0)
		var rows = margin.get_child(0)
		for row_child in rows.get_children():
			if row_child is HBoxContainer:
				for btn in row_child.get_children():
					if btn is Button and btn.text == "[緊急差止]":
						target_btn = btn as Button
						break
	if target_btn:
		target_btn.pressed.emit()
		await process_frame
		await process_frame

	# Close guidelines to clean up UI space
	if guidelines_btn:
		guidelines_btn.button_pressed = false
		guidelines_btn.toggled.emit(false)
		await process_frame

	# Force scroll to bottom to show all added cards
	var card_scroll := card_list_container.get_parent() as ScrollContainer
	if card_scroll:
		card_scroll.scroll_vertical = 99999
		await process_frame
		await process_frame

	# 6. Capture main screen with card added
	await _capture("visual_check_06_card_added.png")

	# 7. Search verification (Input "広報庁")
	search_input.text = "広報庁"
	search_input.text_changed.emit("広報庁")
	await create_timer(0.2).timeout
	if card_scroll:
		card_scroll.scroll_vertical = 99999
		await process_frame
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
