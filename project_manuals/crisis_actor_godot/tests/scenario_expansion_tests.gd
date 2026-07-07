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
	var admin_edit: TextEdit = app.get("_admin_text_edit") as TextEdit
	var forbidden_label: Label = app.get("_forbidden_label") as Label
	var clock_label: Label = app.get("_clock_stage_label") as Label
	var conspiracy_clock_name_label: Label = app.get("_counter_name_labels")["conspiracy_clock"] as Label
	
	_assert(scenario_opt != null, "Scenario preset OptionButton should exist.")
	_assert(next_phase_btn != null, "Next Phase button should exist.")
	_assert(admin_edit != null, "Admin document TextEdit should exist.")
	_assert(forbidden_label != null, "Forbidden count label should exist.")
	_assert(clock_label != null, "Clock stage label should exist.")
	_assert(conspiracy_clock_name_label != null, "Conspiracy clock name label should exist.")

	# 1. Test Load Scenario EP3
	scenario_opt.select(1) # Index 1 is EP3
	scenario_opt.item_selected.emit(1)
	await process_frame
	app.call("_on_load_scenario_pressed")
	await process_frame

	_assert(app.get("_current_scenario_id") == "ep3", "Current scenario should be EP3.")
	_assert(app.get("_counters")["audit_debt"] == 1, "EP3 initial audit debt should be 1.")
	_assert(app.get("_counters")["budget"] == 5, "EP3 initial budget should be 5.")
	_assert(conspiracy_clock_name_label.text == "文化財化処理", "Conspiracy clock name should be updated to '文化財化処理'.")
	_assert(clock_label.text.contains("未分類"), "Initial clock stage for EP3 should be '未分類'.")

	# 2. Test EP3 Forbidden Words Auto-Replacement
	# Empty text first
	admin_edit.text = "これはテスト文書です。"
	app.call("_on_admin_text_changed")
	await process_frame
	_assert(app.get("_forbidden_count") == 0, "No forbidden words should be replaced yet.")

	# Enter text with EP3 forbidden words "祟り" and "人身御供"
	admin_edit.text = "昔の祟りを恐れ、人身御供を捧げる必要があった。"
	app.call("_on_admin_text_changed")
	await process_frame

	_assert(admin_edit.text.contains("地域資源"), "The word '祟り' should be replaced with '地域資源'.")
	_assert(admin_edit.text.contains("円滑な合意形成"), "The word '人身御供' should be replaced with '円滑な合意形成'.")
	_assert(not admin_edit.text.contains("祟り"), "The word '祟り' should not remain.")
	_assert(not admin_edit.text.contains("人身御供"), "The word '人身御供' should not remain.")
	_assert(app.get("_forbidden_count") == 2, "Forbidden count should increment to 2.")

	# 3. Test Clock Progression for EP3
	# Setup -> Phase 1
	next_phase_btn.pressed.emit()
	await process_frame
	# Phase 1 -> Phase 2
	next_phase_btn.pressed.emit()
	await process_frame
	# Phase 2 -> Phase 3 (conspiracy_clock should increment to 1)
	next_phase_btn.pressed.emit()
	await process_frame
	
	_assert(app.get("_counters")["conspiracy_clock"] == 1, "EP3 conspiracy clock should increment on Phase 3.")
	_assert(clock_label.text.contains("資料整理中"), "EP3 clock stage should update to '資料整理中'.")

	print("SCENARIO_EXPANSION_TEST: SUCCESS")
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
		print("SCENARIO_EXPANSION_PASS")
		quit(0)
	else:
		printerr("SCENARIO_EXPANSION_FAIL: %d failures" % _failures.size())
		quit(1)
