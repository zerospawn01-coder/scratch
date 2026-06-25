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
	var search_input: LineEdit = app.get_node("Root/Columns/ContentPanel/ContentMargin/ContentRows/SearchContainer/SearchInput") as LineEdit
	var search_count: Label = app.get_node("Root/Columns/ContentPanel/ContentMargin/ContentRows/SearchContainer/SearchCount") as Label
	var prev_button: Button = app.get_node("Root/Columns/ContentPanel/ContentMargin/ContentRows/SearchContainer/PrevButton") as Button
	var next_button: Button = app.get_node("Root/Columns/ContentPanel/ContentMargin/ContentRows/SearchContainer/NextButton") as Button
	var doc_selector: OptionButton = app.get_node("Root/Columns/ContentPanel/ContentMargin/ContentRows/SearchContainer/DocSelector") as OptionButton
	var toc_toggle: Button = app.get_node("Root/Columns/ContentPanel/ContentMargin/ContentRows/SearchContainer/TOCToggleButton") as Button
	var doc_title: Label = app.get_node("Root/Columns/ContentPanel/ContentMargin/ContentRows/DocTitle") as Label
	var sidebar: VBoxContainer = app.get_node("Root/Columns/Sidebar") as VBoxContainer
	var ops_panel: PanelContainer = app.get_node("Root/Columns/OpsPanel") as PanelContainer
	var toc_panel: PanelContainer = app.get_node("Root/Columns/TOCPanel") as PanelContainer
	var toc_list: VBoxContainer = app.get_node("Root/Columns/TOCPanel/TOCMargin/TOCRows/TOCScroll/TOCList") as VBoxContainer
	var scenario_ep3_btn: Button = app.get_node("Root/Columns/Sidebar/ScenarioEp3Button") as Button

	# VTT References
	var cred_val: Label = app.get_node("Root/Columns/OpsPanel/OpsMargin/OpsRows/ClocksGrid/CredVal") as Label
	var cred_inc: Button = app.get_node("Root/Columns/OpsPanel/OpsMargin/OpsRows/ClocksGrid/CredInc") as Button
	var contam_inc: Button = app.get_node("Root/Columns/OpsPanel/OpsMargin/OpsRows/ClocksGrid/ContamInc") as Button
	var warnings_label: Label = app.get_node("Root/Columns/OpsPanel/OpsMargin/OpsRows/WarningsLabel") as Label
	var undo_btn: Button = app.get_node("Root/Columns/OpsPanel/OpsMargin/OpsRows/PhaseRow/UndoBtn") as Button
	
	var add_white_btn: Button = app.get_node("Root/Columns/OpsPanel/OpsMargin/OpsRows/CardAddFlow/AddWhiteBtn") as Button
	var form_panel: PanelContainer = app.get_node("Root/Columns/OpsPanel/OpsMargin/OpsRows/CardFormPanel") as PanelContainer
	var input_title: LineEdit = app.get_node("Root/Columns/OpsPanel/OpsMargin/OpsRows/CardFormPanel/FormMargin/FormRows/InputTitle") as LineEdit
	var input_fact: LineEdit = app.get_node("Root/Columns/OpsPanel/OpsMargin/OpsRows/CardFormPanel/FormMargin/FormRows/InputFact") as LineEdit
	var form_submit_btn: Button = app.get_node("Root/Columns/OpsPanel/OpsMargin/OpsRows/CardFormPanel/FormMargin/FormRows/FormButtons/FormSubmitBtn") as Button
	var card_list_container: VBoxContainer = app.get_node("Root/Columns/OpsPanel/OpsMargin/OpsRows/CardScroll/CardList") as VBoxContainer
	var export_btn: Button = app.get_node("Root/Columns/OpsPanel/OpsMargin/OpsRows/ExportBtn") as Button

	# 1. Base Viewer Asserts
	_assert(toc_list.get_child_count() > 0, "TOC should contain heading buttons.")
	_assert(search_count.text == "全文表示", "Initial document should render in full-text mode.")

	# 2. Search Navigation Tests
	var terms: Array[String] = [
		"B級処理",
		"現実混入率+1",
		"[黒カード]",
		"Witness Claim",
	]

	for term in terms:
		search_input.text = term
		search_input.text_changed.emit(term)
		await create_timer(0.1).timeout
		print("SEARCH %s => %s" % [term, search_count.text])
		_assert(search_count.text.ends_with("件ヒット"), "Search should complete for '%s'." % term)
		_assert(not search_count.text.begins_with("0 "), "Search should find at least one hit for '%s'." % term)

	search_input.text = "B級処理"
	search_input.text_changed.emit("B級処理")
	await create_timer(0.1).timeout
	var first_count := search_count.text
	next_button.pressed.emit()
	await process_frame
	_assert(search_count.text != first_count, "Next button should advance the active search match.")
	prev_button.pressed.emit()
	await process_frame
	_assert(search_count.text == first_count, "Prev button should return to the previous search match.")

	search_input.text = ""
	search_input.text_changed.emit("")
	await create_timer(0.1).timeout
	_assert(search_count.text == "全文表示", "Clearing search should restore full-text mode.")

	# 3. Clock Operations & Undo Tests
	var initial_cred = cred_val.text.to_int()
	cred_inc.pressed.emit()
	await process_frame
	_assert(cred_val.text.to_int() == initial_cred + 1, "Credibility should increment via UI button.")

	undo_btn.pressed.emit()
	await process_frame
	_assert(cred_val.text.to_int() == initial_cred, "Undo should restore credibility to original value.")

	# 4. Warnings Threshold Test
	_assert(warnings_label.text == "", "Warnings should be empty initially.")
	for k in range(5):
		contam_inc.pressed.emit()
		await process_frame
	_assert(warnings_label.text != "", "Warnings label should show alert when contamination >= 5.")

	# 5. Card Creation Test
	_assert(card_list_container.get_child_count() == 0, "Card list should be empty initially.")
	add_white_btn.pressed.emit()
	await process_frame
	_assert(form_panel.visible, "Card form panel should become visible on button press.")
	
	input_title.text = "Test White Card"
	input_fact.text = "Test Official Fact Description"
	form_submit_btn.pressed.emit()
	await process_frame
	_assert(not form_panel.visible, "Form panel should hide after submission.")
	_assert(card_list_container.get_child_count() == 1, "Card list container should contain 1 child card.")

	# 6. Save/Load and Exporter Test
	# Clear existing test files
	if FileAccess.file_exists("user://session_log.json"):
		DirAccess.remove_absolute("user://session_log.json")
	if FileAccess.file_exists("user://session_log.md"):
		DirAccess.remove_absolute("user://session_log.md")

	# Modify credibility via UI so it's different from default
	cred_inc.pressed.emit()
	await process_frame
	var saved_cred := cred_val.text.to_int()
	_assert(card_list_container.get_child_count() == 1, "Should have 1 card before save.")

	# Get save and load buttons
	var save_btn: Button = app.get_node("Root/Columns/OpsPanel/OpsMargin/OpsRows/SaveLoadRow/SaveBtn") as Button
	var load_btn: Button = app.get_node("Root/Columns/OpsPanel/OpsMargin/OpsRows/SaveLoadRow/LoadBtn") as Button
	_assert(save_btn != null, "SaveBtn should exist.")
	_assert(load_btn != null, "LoadBtn should exist.")

	# Save the session
	save_btn.pressed.emit()
	await process_frame
	_assert(FileAccess.file_exists("user://session_log.json"), "user://session_log.json should be created after save.")

	# Mutate the state (decrease credibility and remove card)
	var state_obj = app.get("state")
	_assert(state_obj != null, "State object should be accessible.")
	state_obj.credibility = 1
	state_obj.remove_card("white", 0)
	await process_frame

	_assert(cred_val.text.to_int() == 1, "Credibility should be mutated to 1.")
	_assert(card_list_container.get_child_count() == 0, "Card list should be empty after removing card.")

	# Load the session back
	load_btn.pressed.emit()
	await process_frame

	_assert(cred_val.text.to_int() == saved_cred, "Credibility should be restored to %d after load." % saved_cred)
	_assert(card_list_container.get_child_count() == 1, "Card list should have 1 card restored after load.")

	# Export Markdown log
	export_btn.pressed.emit()
	await process_frame
	_assert(FileAccess.file_exists("user://session_log.md"), "user://session_log.md should be created after export.")

	# Verify contents of exported Markdown
	var md_file := FileAccess.open("user://session_log.md", FileAccess.READ)
	_assert(md_file != null, "Should open exported Markdown file.")
	if md_file != null:
		var md_content := md_file.get_as_text()
		md_file.close()
		_assert(md_content.contains("# CRISIS ACTOR - セッション記録"), "Markdown should have the correct title.")
		_assert(md_content.contains("Test White Card"), "Markdown should contain card title.")
		_assert(md_content.contains("Test Official Fact Description"), "Markdown should contain card content.")

	await create_timer(2.1).timeout

	# 6.5. Scenario EP3 Click Test
	scenario_ep3_btn.pressed.emit()
	await process_frame
	_assert(doc_title.text == "シナリオ EP3", "Scenario EP3 button should switch the active document.")
	_assert(toc_list.get_child_count() > 0, "TOC should update for Episode 3.")

	search_input.text = "帳外帳"
	search_input.text_changed.emit("帳外帳")
	await create_timer(0.1).timeout
	print("SEARCH 帳外帳 => %s" % search_count.text)
	_assert(search_count.text.ends_with("件ヒット"), "Episode 3 search should complete for 帳外帳.")
	_assert(not search_count.text.begins_with("0 "), "Episode 3 should contain 帳外帳.")

	var ep3_terms: Array[String] = [
		"文化財化処理クロック",
		"黒塗り理由コード",
		"調査対象カード",
	]
	for term in ep3_terms:
		search_input.text = term
		search_input.text_changed.emit(term)
		await create_timer(0.1).timeout
		print("SEARCH %s => %s" % [term, search_count.text])
		_assert(search_count.text.ends_with("件ヒット"), "Episode 3 search should complete for %s." % term)
		_assert(not search_count.text.begins_with("0 "), "Episode 3 should contain %s." % term)

	# 7. TOC Toggle Tests
	var initial_toc_visibility := toc_panel.visible
	toc_toggle.pressed.emit()
	await process_frame
	_assert(toc_panel.visible != initial_toc_visibility, "TOC toggle should change panel visibility.")

	toc_toggle.pressed.emit()
	await process_frame
	_assert(toc_panel.visible == initial_toc_visibility, "TOC toggle should restore panel visibility.")

	doc_selector.select(1)
	doc_selector.item_selected.emit(1)
	await process_frame
	_assert(doc_title.text == "キャラクター", "Doc selector should switch the active document.")

	(app as Control).size = Vector2(700, 720)
	app.call("_on_window_resized")
	await process_frame
	_assert(not sidebar.visible, "Sidebar should be hidden on narrow layouts.")
	_assert(not ops_panel.visible, "Ops panel should be hidden on narrow layouts.")
	_assert(doc_selector.visible, "Doc selector should be visible on narrow layouts.")

	(app as Control).size = Vector2(1280, 720)
	app.call("_on_window_resized")
	await process_frame
	_assert(sidebar.visible, "Sidebar should be visible on desktop layouts.")
	_assert(ops_panel.visible, "Ops panel should be visible on desktop layouts.")
	_assert(not doc_selector.visible, "Doc selector should be hidden on desktop layouts.")

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
		return

	printerr("VIEWER_SMOKE_FAIL: %d failure(s)" % _failures.size())
	for failure in _failures:
		printerr("- %s" % failure)
	quit(1)
