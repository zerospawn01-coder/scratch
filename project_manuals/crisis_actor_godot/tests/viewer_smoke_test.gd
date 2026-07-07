extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("main.tscn could not be loaded.")
		_finish()
		return

	var app: Node = packed.instantiate()
	root.add_child(app)
	await process_frame
	await process_frame

	# References
	var scenario_opt: OptionButton = app.get("_scenario_option") as OptionButton
	var next_phase_btn: Button = app.get("_next_phase_btn") as Button
	var phase_label: Label = app.get("_phase_label") as Label
	var safety_check_btn: Button = app.get("_safety_check_btn") as Button
	var audit_pause_btn: Button = app.get("_audit_pause_btn") as Button
	var emergency_btn: Button = app.get("_emergency_injunction_btn") as Button
	var export_btn: Button = app.get("_export_md_btn") as Button
	
	_assert(scenario_opt != null, "Scenario preset OptionButton should exist.")
	_assert(next_phase_btn != null, "Next Phase button should exist.")
	_assert(phase_label != null, "Phase label should exist.")
	_assert(safety_check_btn != null, "Safety Check button should exist.")
	_assert(audit_pause_btn != null, "Audit Pause button should exist.")
	_assert(emergency_btn != null, "Emergency Injunction button should exist.")
	_assert(export_btn != null, "Export Markdown button should exist.")

	# 1. Test Scenario loading
	_assert(app.get("_current_scenario_id") == "ep2", "Default scenario should be EP2.")
	_assert(app.get("_cards").size() == 3, "EP2 should start with 3 cards.")
	_assert(app.get("_counters")["audit_debt"] == 2, "EP2 initial audit debt should be 2.")
	
	# Select EP3
	scenario_opt.select(1)
	scenario_opt.item_selected.emit(1)
	await process_frame
	
	# Trigger load scenario
	app.call("_on_load_scenario_pressed")
	await process_frame
	_assert(app.get("_current_scenario_id") == "ep3", "Scenario should switch to EP3.")
	_assert(app.get("_cards").size() == 3, "EP3 should start with 3 cards.")
	_assert(app.get("_counters")["audit_debt"] == 1, "EP3 initial audit debt should be 1.")
	
	# Switch back to EP2 for testing flow
	scenario_opt.select(0)
	scenario_opt.item_selected.emit(0)
	app.call("_on_load_scenario_pressed")
	await process_frame
	
	# 2. Test Phase Progression & Clock Increments
	_assert(phase_label.text.contains("Setup"), "Phase should start at Setup.")
	var clock_label: Label = app.get("_clock_stage_label") as Label
	_assert(clock_label != null, "Clock stage label should exist.")
	_assert(clock_label.text.contains("未招集"), "Initial clock stage for EP2 should be '未招集'.")
	_assert(app.get("_counters")["conspiracy_clock"] == 0, "Initial conspiracy_clock should be 0.")

	# Setup -> Phase 1
	next_phase_btn.pressed.emit()
	await process_frame
	_assert(phase_label.text.contains("Phase 1"), "Phase should advance to Phase 1.")
	_assert(app.get("_counters")["conspiracy_clock"] == 0, "conspiracy_clock should remain 0 in Phase 1.")

	# Phase 1 -> Phase 2
	next_phase_btn.pressed.emit()
	await process_frame
	_assert(phase_label.text.contains("Phase 2"), "Phase should advance to Phase 2.")
	_assert(app.get("_counters")["conspiracy_clock"] == 0, "conspiracy_clock should remain 0 in Phase 2.")

	# Phase 2 -> Phase 3 (conspiracy_clock should increment to 1)
	next_phase_btn.pressed.emit()
	await process_frame
	_assert(phase_label.text.contains("Phase 3"), "Phase should advance to Phase 3.")
	_assert(app.get("_counters")["conspiracy_clock"] == 1, "conspiracy_clock should increment to 1 on Phase 3.")
	_assert(clock_label.text.contains("資料提出依頼"), "Clock stage should update to '資料提出依頼'.")

	# Phase 3 -> Phase 4 / Climax (conspiracy_clock should increment to 2)
	next_phase_btn.pressed.emit()
	await process_frame
	_assert(phase_label.text.contains("Phase 4"), "Phase should advance to Phase 4.")
	_assert(app.get("_counters")["conspiracy_clock"] == 2, "conspiracy_clock should increment to 2 on Phase 4.")
	_assert(clock_label.text.contains("医療記録照会"), "Clock stage should update to '医療記録照会'.")
	
	# 3. Test Card adding and converting
	var initial_card_count = app.get("_cards").size()
	
	# Add Card
	var title_edit = app.get("_card_title_edit") as LineEdit
	var body_edit = app.get("_card_body_edit") as TextEdit
	title_edit.text = "Test Custom Card"
	body_edit.text = "This is a custom test card body"
	app.call("_on_add_card_pressed")
	await process_frame
	_assert(app.get("_cards").size() == initial_card_count + 1, "Card count should increase by 1.")
	
	# Convert Card (Gray -> Black)
	# Find a Gray card
	var cards_list: ItemList = app.get("_cards_list") as ItemList
	var gray_card_idx := -1
	var cards_array = app.get("_cards")
	for i in range(cards_array.size()):
		if cards_array[i]["type"] == "gray":
			gray_card_idx = i
			break
	_assert(gray_card_idx >= 0, "There should be at least one Gray card.")
	
	# Select it
	app.call("_on_card_selected", gray_card_idx)
	cards_list.select(gray_card_idx)
	cards_list.item_selected.emit(gray_card_idx)
	await process_frame
	
	# Transform dropdown selection -> Black
	var transform_opt = app.get("_card_transform_target_option") as OptionButton
	var black_item_idx = -1
	for idx in range(transform_opt.item_count):
		if transform_opt.get_item_metadata(idx) == "black":
			black_item_idx = idx
			break
	_assert(black_item_idx >= 0, "Black option should exist in transform target dropdown.")
	transform_opt.select(black_item_idx)
	
	# Trigger Transform
	app.call("_on_transform_card_pressed")
	await process_frame
	_assert(app.get("_cards")[gray_card_idx]["type"] == "black", "Selected card should be converted to Black.")

	# Test Invalid Card transform validation (e.g. Gray -> Protected should fail)
	# Add a temporary Gray card
	title_edit.text = "Temp Gray Card"
	body_edit.text = "Temp Gray body"
	var type_opt = app.get("_card_type_option") as OptionButton
	var gray_type_idx = -1
	for idx in range(type_opt.item_count):
		if type_opt.get_item_text(idx) == "gray":
			gray_type_idx = idx
			break
	_assert(gray_type_idx >= 0, "Gray option should exist in type dropdown.")
	type_opt.select(gray_type_idx)
	app.call("_on_add_card_pressed")
	await process_frame

	var temp_card_idx = app.get("_cards").size() - 1
	app.call("_on_card_selected", temp_card_idx)
	cards_list.select(temp_card_idx)
	await process_frame

	# Select Protected transform target
	var protected_item_idx = -1
	for idx in range(transform_opt.item_count):
		if transform_opt.get_item_metadata(idx) == "protected":
			protected_item_idx = idx
			break
	_assert(protected_item_idx >= 0, "Protected option should exist in transform target dropdown.")
	transform_opt.select(protected_item_idx)

	# Trigger Transform (should be invalid/blocked)
	app.call("_on_transform_card_pressed")
	await process_frame
	_assert(app.get("_cards")[temp_card_idx]["type"] == "gray", "Gray to Protected conversion should be rejected.")

	# Verify failed audit log exists
	var has_failed_log = false
	for log_entry in app.get("_audit_log"):
		if log_entry["action"] == "CARD_CONVERTED_FAILED" and log_entry["original_text"] == "Temp Gray Card":
			has_failed_log = true
			break
	_assert(has_failed_log, "A CARD_CONVERTED_FAILED audit entry should be logged on rejected conversion.")

	# Delete the temporary card
	app.call("_on_delete_card_pressed")
	await process_frame
	
	# 4. Test Safety Kernel Actions
	var prev_checks = app.get("_safety_checks_used")
	safety_check_btn.pressed.emit()
	await process_frame
	_assert(app.get("_safety_checks_used") == prev_checks + 1, "Safety Checks count should increase.")

	var prev_pauses = app.get("_audit_pauses_used")
	audit_pause_btn.pressed.emit()
	await process_frame
	_assert(app.get("_audit_pauses_used") == prev_pauses + 1, "Audit Pauses count should increase.")
	
	# Select the Black card we converted earlier to test Emergency Injunction
	app.call("_on_card_selected", gray_card_idx) # It's now black
	cards_list.select(gray_card_idx)
	await process_frame
	
	var prev_injunctions = app.get("_emergency_injunctions_used")
	var prev_debt = app.get("_counters")["audit_debt"]
	emergency_btn.pressed.emit()
	await process_frame
	_assert(app.get("_emergency_injunctions_used") == prev_injunctions + 1, "Emergency Injunction count should increase.")
	_assert(app.get("_cards")[gray_card_idx]["type"] == "protected", "Selected Black card should be converted to Protected.")
	_assert(app.get("_counters")["audit_debt"] == prev_debt - 1, "Audit debt should decrease by 1.")
	
	# 5. Ending Phase A/B/C selection
	# Advance phases to Ending (current phase: Phase 4)
	while not phase_label.text.contains("Ending"):
		next_phase_btn.pressed.emit()
		await process_frame
		
	# Select Ending B
	var ending_container = app.get("_ending_selector_container") as HBoxContainer
	_assert(ending_container.visible, "Ending selector should be visible in Ending phase.")
	
	# Click Ending B button
	var btn_b: Button = null
	for child in ending_container.get_children():
		if child is Button and child.text == "Bエンド":
			btn_b = child
			break
	_assert(btn_b != null, "Ending B button should exist.")
	btn_b.pressed.emit()
	await process_frame
	_assert(app.get("_ending_outcome_label").text.contains("Bエンド"), "Ending B description should be displayed.")
	
	# Advance to Debrief
	next_phase_btn.pressed.emit()
	await process_frame
	_assert(phase_label.text.contains("Debrief"), "Phase should advance to Debrief.")
	
	# 6. Test Exporter
	if FileAccess.file_exists("user://session_log.md"):
		DirAccess.remove_absolute("user://session_log.md")
	
	# Trigger Export
	export_btn.pressed.emit()
	await process_frame
	
	_assert(FileAccess.file_exists("user://session_log.md"), "session_log.md should be saved to user:// path.")
	var exported_file = FileAccess.open("user://session_log.md", FileAccess.READ)
	_assert(exported_file != null, "Should be able to read session_log.md.")
	if exported_file != null:
		var md = exported_file.get_as_text()
		exported_file.close()
		# Format verification
		_assert(md.contains("CRISIS ACTOR - セッション記録"), "Markdown should have the title.")
		_assert(md.contains("## ■ 基本情報"), "Markdown should have info section.")
		_assert(md.contains("## ■ カウンター状態"), "Markdown should have counters section.")
		_assert(md.contains("## ■ 安全カウンター"), "Markdown should have safety counters section.")
		_assert(md.contains("## ■ 終了時のカード状態"), "Markdown should have cards section.")
		_assert(md.contains("## ■ 結末 (Ending)"), "Markdown should have ending section.")
		_assert(md.contains("## ■ 監査ログ履歴 (Audit Log)"), "Markdown should have audit logs section.")
		# Detail verification
		_assert(md.contains("- **シナリオ**: シナリオ EP2: 診断書のない負傷者"), "Markdown should show correct scenario name.")
		_assert(md.contains("- **Safety Checks**: 1"), "Markdown should show correct safety check count.")
		_assert(md.contains("- **Audit Pauses**: 1"), "Markdown should show correct audit pause count.")
		_assert(md.contains("- **Emergency Injunctions**: 1 / 1"), "Markdown should show correct emergency injunction count.")
		# Events verification
		_assert(md.contains("SESSION_STARTED"), "Markdown should contain session started audit event.")
		_assert(md.contains("PHASE_CHANGED"), "Markdown should contain phase change audit events.")
		_assert(md.contains("CARD_CONVERTED"), "Markdown should contain card conversion audit event.")
		_assert(md.contains("EMERGENCY_INJUNCTION_USED"), "Markdown should contain injunction audit event.")
		_assert(md.contains("SESSION_CLOSED"), "Markdown should contain session closed audit event.")
		_assert(md.contains("Bエンド"), "Markdown should contain selected ending description.")
		
	print("VIEWER_SMOKE_TEST: SUCCESS")
	root.remove_child(app)
	app.queue_free()
	_finish()

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	_failures.append(message)
	printerr("FAIL: %s" % message)

func _finish() -> void:
	if _failures.is_empty():
		print("VIEWER_SMOKE_PASS")
		quit(0)
	else:
		printerr("VIEWER_SMOKE_FAIL: %d failures" % _failures.size())
		quit(1)
