extends Control

const Data = preload("res://scripts/crisis_actor_data.gd")

var _root_panel: PanelContainer
var _session_summary: Label
var _role_summary: Label
var _phase_summary: Label
var _rules_text: RichTextLabel
var _phases_text: RichTextLabel
var _codes_text: RichTextLabel
var _audit_text: RichTextLabel
var _incident_title: Label
var _incident_desc: Label
var _incident_outcome: Label
var _dice_pool_spin: SpinBox
var _dice_results: Label
var _dice_summary: Label
var _admin_text_edit: TextEdit
var _admin_keyword_edit: LineEdit
var _admin_action_option: OptionButton
var _admin_code_option: OptionButton
var _culture_label: Label
var _forbidden_label: Label
var _cards_list: ItemList
var _card_detail: RichTextLabel
var _card_type_option: OptionButton
var _card_title_edit: LineEdit
var _card_owner_edit: LineEdit
var _card_body_edit: TextEdit
var _selected_card_index := -1
var _selected_role_index := 1
var _selected_phase := 1
var _selected_incident_index := 0
var _forbidden_count := 0
var _culture_clock := 0
var _dice_pool := 3
var _dice_results_array: Array[int] = []
var _dice_summary_data: Dictionary = {"description": ""}
var _is_updating_admin_text := false
var _is_updating_cards := false
var _cards: Array = []
var _audit_log: Array = []
var _counters := {
	"credibility": 3,
	"anomaly_rate": 1,
	"audit_debt": 0,
	"conspiracy_clock": 0,
	"decay_rate": 0,
	"budget": 5,
}

# Scenario Loader and Phase Flow
var _scenario_option: OptionButton
var _current_scenario_id: String = "ep2"
var _phase_flow_notes: Label
var _phase_label: Label
var _next_phase_btn: Button
var _current_phase_index := 0
const PHASES_FLOW := ["Setup", "Phase 1", "Phase 2", "Phase 3", "Phase 4 / Climax", "Ending", "Debrief"]

# Clocks and Counter Labels
var _counter_name_labels := {}
var _counter_value_labels := {}
var _clock_stage_label: Label

# Card transform target
var _card_transform_target_option: OptionButton

# Safety Kernel UI
var _safety_check_btn: Button
var _audit_pause_btn: Button
var _emergency_injunction_btn: Button
var _safety_kernel_label: Label
var _safety_checks_used := 0
var _audit_pauses_used := 0
var _emergency_injunctions_used := 0
var _emergency_injunction_limit := 1

# Ending Selector
var _ending_selector_container: HBoxContainer
var _ending_outcome_label: Label
var _export_md_btn: Button

# Arrays that were missing declarations in main.gd (added for GDScript safety)
var _role_buttons: Array[Button] = []
var _phase_buttons: Array[Button] = []

func _ready() -> void:
	randomize()
	_build_ui()
	_load_scenario("ep2")

func _build_ui() -> void:
	_root_panel = PanelContainer.new()
	_root_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_panel.add_theme_stylebox_override("panel", _make_style_box(Color("#0c0d0e"), Color("#1f2937"), 2, 0))
	add_child(_root_panel)

	var outer_margin := MarginContainer.new()
	outer_margin.add_theme_constant_override("margin_left", 20)
	outer_margin.add_theme_constant_override("margin_top", 20)
	outer_margin.add_theme_constant_override("margin_right", 20)
	outer_margin.add_theme_constant_override("margin_bottom", 20)
	_root_panel.add_child(outer_margin)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_theme_constant_override("separation", 14)
	outer_margin.add_child(outer_vbox)

	outer_vbox.add_child(_build_header())

	var split := HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 540
	outer_vbox.add_child(split)

	split.add_child(_build_rules_panel())
	split.add_child(_build_simulator_panel())

	outer_vbox.add_child(_build_footer())

func _build_header() -> Control:
	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", _make_style_box(Color("#111827"), Color("#374151"), 2, 8))
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.custom_minimum_size = Vector2(0, 96)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	header.add_child(hbox)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title_box)

	var title := Label.new()
	title.text = "CRISIS ACTOR"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#f8fafc"))
	title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Rules & Session Simulator / extracted from crisis-actor-rules-&-session-simulator"
	subtitle.add_theme_color_override("font_color", Color("#9ca3af"))
	subtitle.add_theme_font_size_override("font_size", 12)
	title_box.add_child(subtitle)

	var summary_box := VBoxContainer.new()
	summary_box.custom_minimum_size = Vector2(420, 0)
	hbox.add_child(summary_box)

	_session_summary = Label.new()
	_session_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_session_summary.add_theme_color_override("font_color", Color("#d1d5db"))
	summary_box.add_child(_session_summary)

	_role_summary = Label.new()
	_role_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_role_summary.add_theme_color_override("font_color", Color("#fca5a5"))
	summary_box.add_child(_role_summary)

	_phase_summary = Label.new()
	_phase_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_phase_summary.add_theme_color_override("font_color", Color("#a7f3d0"))
	summary_box.add_child(_phase_summary)

	return header

func _build_rules_panel() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_style_box(Color("#0f1115"), Color("#374151"), 2, 10))
	panel.custom_minimum_size = Vector2(520, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var top := VBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	vbox.add_child(top)

	var heading := Label.new()
	heading.text = "SEC-01 // RULES & AUDITING MANUAL"
	heading.add_theme_color_override("font_color", Color("#e5e7eb"))
	heading.add_theme_font_size_override("font_size", 14)
	top.add_child(heading)

	var hint := Label.new()
	hint.text = "Administrative audit regulation manual"
	hint.add_theme_color_override("font_color", Color("#6b7280"))
	hint.add_theme_font_size_override("font_size", 11)
	top.add_child(hint)

	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(tabs)

	_rules_text = _make_scrolled_rich_text(_build_roles_rules_text())
	_phases_text = _make_scrolled_rich_text(_build_phases_text())
	_codes_text = _make_scrolled_rich_text(_build_codes_text())

	tabs.add_child(_make_tab_page("役職 & 変数", _rules_text))
	tabs.add_child(_make_tab_page("進行フェーズ", _phases_text))
	tabs.add_child(_make_tab_page("黒塗り規則", _codes_text))

	return panel

func _make_tab_page(tab_name: String, text_widget: RichTextLabel) -> Control:
	var page := ScrollContainer.new()
	page.name = tab_name
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_widget.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(text_widget)
	return page

func _build_simulator_panel() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)
	scroll.add_child(vbox)

	vbox.add_child(_build_scenario_section())
	vbox.add_child(_build_session_flow_section())
	vbox.add_child(_build_session_state_section())
	vbox.add_child(_build_dice_section())
	vbox.add_child(_build_incident_section())
	vbox.add_child(_build_card_section())
	vbox.add_child(_build_admin_section())
	vbox.add_child(_build_audit_section())
	vbox.add_child(_build_safety_kernel_section())

	return scroll

func _build_section(title: String, subtitle: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_style_box(Color("#111827"), Color("#374151"), 1, 10))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_color_override("font_color", Color("#f8fafc"))
	title_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title_label)

	var sub_label := Label.new()
	sub_label.text = subtitle
	sub_label.add_theme_color_override("font_color", Color("#9ca3af"))
	sub_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(sub_label)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	vbox.add_child(inner)
	panel.set_meta("_inner", inner)
	return panel

func _section_inner(section: PanelContainer) -> VBoxContainer:
	return section.get_meta("_inner") as VBoxContainer

func _build_session_state_section() -> Control:
	var panel := _build_section("SESSION STATE", "角色 / 相位 / カウンターを管理する中枢")
	var inner := _section_inner(panel)

	var role_row := HBoxContainer.new()
	role_row.add_theme_constant_override("separation", 6)
	inner.add_child(role_row)

	for i in range(Data.ROLES.size()):
		var btn := Button.new()
		btn.text = Data.ROLES[i]["name"]
		btn.custom_minimum_size = Vector2(0, 30)
		btn.pressed.connect(_on_role_pressed.bind(i))
		_role_buttons.append(btn)
		role_row.add_child(btn)

	var phase_hint := Label.new()
	phase_hint.text = "Current phase is controlled from this panel."
	phase_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	phase_hint.add_theme_color_override("font_color", Color("#a7f3d0"))
	inner.add_child(phase_hint)

	var phase_row := HBoxContainer.new()
	phase_row.add_theme_constant_override("separation", 6)
	inner.add_child(phase_row)
	for i in range(Data.PHASES.size()):
		var phase_btn := Button.new()
		phase_btn.text = "P%d" % Data.PHASES[i]["phase"]
		phase_btn.custom_minimum_size = Vector2(0, 28)
		phase_btn.pressed.connect(_on_phase_pressed.bind(Data.PHASES[i]["phase"]))
		_phase_buttons.append(phase_btn)
		phase_row.add_child(phase_btn)

	var counter_box := VBoxContainer.new()
	counter_box.add_theme_constant_override("separation", 6)
	inner.add_child(counter_box)

	_add_counter_row(counter_box, "credibility", "信憑性", 6)
	_add_counter_row(counter_box, "anomaly_rate", "現実混入率", 6)
	_add_counter_row(counter_box, "audit_debt", "監査負債", 6)
	_add_counter_row(counter_box, "conspiracy_clock", "共犯クロック", 6)
	_add_counter_row(counter_box, "decay_rate", "機材劣化", 3)
	_add_counter_row(counter_box, "budget", "予算", 12)

	_clock_stage_label = Label.new()
	_clock_stage_label.add_theme_color_override("font_color", Color("#fca5a5"))
	_clock_stage_label.text = "進捗: 未招集"
	inner.add_child(_clock_stage_label)

	return panel

func _add_counter_row(parent: VBoxContainer, key: String, label_text: String, max_value: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.custom_minimum_size = Vector2(120, 0)
	name_label.add_theme_color_override("font_color", Color("#d1d5db"))
	row.add_child(name_label)

	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = max_value
	bar.custom_minimum_size = Vector2(0, 14)
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bar)

	var value_label := Label.new()
	value_label.text = "0 / %d" % max_value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(72, 0)
	value_label.add_theme_color_override("font_color", Color("#f8fafc"))
	row.add_child(value_label)

	_counter_value_labels[key] = value_label
	_counter_value_labels[key + "_max"] = max_value
	_counter_value_labels[key + "_bar"] = bar
	_counter_name_labels[key] = name_label

func _build_dice_section() -> Control:
	var panel := _build_section("DICE POOL", "D6ダイスプール判定 / 5=成功, 6=派手な成功, 1=ノイズ")
	var inner := _section_inner(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	inner.add_child(row)

	var pool_label := Label.new()
	pool_label.text = "Pool"
	row.add_child(pool_label)

	_dice_pool_spin = SpinBox.new()
	_dice_pool_spin.min_value = 1
	_dice_pool_spin.max_value = 5
	_dice_pool_spin.step = 1
	_dice_pool_spin.value = 3
	_dice_pool_spin.custom_minimum_size = Vector2(80, 0)
	row.add_child(_dice_pool_spin)

	var roll_btn := Button.new()
	roll_btn.text = "ROLL"
	roll_btn.pressed.connect(_roll_dice_pool)
	row.add_child(roll_btn)

	_dice_results = Label.new()
	_dice_results.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(_dice_results)

	_dice_summary = Label.new()
	_dice_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dice_summary.add_theme_color_override("font_color", Color("#9ca3af"))
	inner.add_child(_dice_summary)

	return panel

func _build_incident_section() -> Control:
	var panel := _build_section("INCIDENT SCENARIO", "演出強行 / 安全対処の二択を試す")
	var inner := _section_inner(panel)

	var scenario: Dictionary = Data.INCIDENT_SCENARIOS[_selected_incident_index]
	_incident_title = Label.new()
	_incident_title.text = scenario["title"]
	_incident_title.add_theme_color_override("font_color", Color("#fca5a5"))
	inner.add_child(_incident_title)

	_incident_desc = Label.new()
	_incident_desc.text = scenario["description"]
	_incident_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(_incident_desc)

	var opt_row := HBoxContainer.new()
	opt_row.add_theme_constant_override("separation", 8)
	inner.add_child(opt_row)

	for i in range(scenario["options"].size()):
		var option: Dictionary = scenario["options"][i]
		var btn := Button.new()
		btn.text = "演出強行" if option["id"] == "option_enforce" else "安全対処"
		btn.tooltip_text = option["text"]
		btn.custom_minimum_size = Vector2(0, 48)
		btn.pressed.connect(_on_incident_option_pressed.bind(i))
		opt_row.add_child(btn)

	_incident_outcome = Label.new()
	_incident_outcome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_incident_outcome.add_theme_color_override("font_color", Color("#a7f3d0"))
	inner.add_child(_incident_outcome)

	return panel

func _build_card_section() -> Control:
	var panel := _build_section("CARD WORKSHOP", "白・灰・黒・粗い演出カードを実体化する")
	var inner := _section_inner(panel)

	var form := GridContainer.new()
	form.columns = 2
	form.add_theme_constant_override("h_separation", 10)
	form.add_theme_constant_override("v_separation", 8)
	inner.add_child(form)

	form.add_child(_make_small_label("Type"))
	_card_type_option = OptionButton.new()
	for item in ["white", "gray", "black", "rough", "suspicion", "ritual"]:
		_card_type_option.add_item(item)
	form.add_child(_card_type_option)

	form.add_child(_make_small_label("Title"))
	_card_title_edit = LineEdit.new()
	_card_title_edit.placeholder_text = "カード名"
	form.add_child(_card_title_edit)

	form.add_child(_make_small_label("Owner"))
	_card_owner_edit = LineEdit.new()
	_card_owner_edit.placeholder_text = "任意"
	form.add_child(_card_owner_edit)

	form.add_child(_make_small_label("Body"))
	_card_body_edit = TextEdit.new()
	_card_body_edit.custom_minimum_size = Vector2(0, 72)
	form.add_child(_card_body_edit)

	var add_btn_row := HBoxContainer.new()
	add_btn_row.add_theme_constant_override("separation", 8)
	inner.add_child(add_btn_row)

	var add_btn := Button.new()
	add_btn.text = "ADD CARD"
	add_btn.pressed.connect(_on_add_card_pressed)
	add_btn_row.add_child(add_btn)

	var transform_btn := Button.new()
	transform_btn.text = "TRANSFORM SELECTED"
	transform_btn.pressed.connect(_on_transform_card_pressed)
	add_btn_row.add_child(transform_btn)

	var delete_btn := Button.new()
	delete_btn.text = "DELETE SELECTED"
	delete_btn.pressed.connect(_on_delete_card_pressed)
	add_btn_row.add_child(delete_btn)

	_card_transform_target_option = OptionButton.new()
	_card_transform_target_option.add_item("白 (white)", 0)
	_card_transform_target_option.set_item_metadata(0, "white")
	_card_transform_target_option.add_item("灰 (gray)", 1)
	_card_transform_target_option.set_item_metadata(1, "gray")
	_card_transform_target_option.add_item("黒 (black)", 2)
	_card_transform_target_option.set_item_metadata(2, "black")
	_card_transform_target_option.add_item("調査対象 (investigation)", 3)
	_card_transform_target_option.set_item_metadata(3, "investigation")
	_card_transform_target_option.add_item("保全中 (protected)", 4)
	_card_transform_target_option.set_item_metadata(4, "protected")
	_card_transform_target_option.add_item("公開区分 (classification)", 5)
	_card_transform_target_option.set_item_metadata(5, "classification")
	add_btn_row.add_child(_card_transform_target_option)

	_cards_list = ItemList.new()
	_cards_list.custom_minimum_size = Vector2(0, 160)
	_cards_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_list.item_selected.connect(_on_card_selected)
	inner.add_child(_cards_list)

	_card_detail = _make_scrolled_rich_text("")
	_card_detail.custom_minimum_size = Vector2(0, 120)
	inner.add_child(_card_detail)

	return panel

func _build_admin_section() -> Control:
	var panel := _build_section("ADMIN DOCUMENT", "禁止語の自動置換 / 黒塗り / 文化財化")
	var inner := _section_inner(panel)

	_admin_text_edit = TextEdit.new()
	_admin_text_edit.custom_minimum_size = Vector2(0, 280)
	_admin_text_edit.text = Data.INITIAL_ADMIN_DOC_TEXT
	_admin_text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_admin_text_edit.text_changed.connect(_on_admin_text_changed)
	inner.add_child(_admin_text_edit)

	var controls := GridContainer.new()
	controls.columns = 2
	controls.add_theme_constant_override("h_separation", 8)
	controls.add_theme_constant_override("v_separation", 6)
	inner.add_child(controls)

	controls.add_child(_make_small_label("Keyword"))
	_admin_keyword_edit = LineEdit.new()
	_admin_keyword_edit.placeholder_text = "検閲対象ワード"
	controls.add_child(_admin_keyword_edit)

	controls.add_child(_make_small_label("Action"))
	_admin_action_option = OptionButton.new()
	_admin_action_option.add_item("黒塗り")
	_admin_action_option.add_item("封印")
	_admin_action_option.add_item("文化財化")
	controls.add_child(_admin_action_option)

	controls.add_child(_make_small_label("Code"))
	_admin_code_option = OptionButton.new()
	for blackout in Data.BLACKOUT_CODES:
		_admin_code_option.add_item("%s / %s" % [blackout["code"], blackout["label"]])
	controls.add_child(_admin_code_option)

	var doc_btn_row := HBoxContainer.new()
	doc_btn_row.add_theme_constant_override("separation", 8)
	inner.add_child(doc_btn_row)

	var apply_btn := Button.new()
	apply_btn.text = "APPLY"
	apply_btn.pressed.connect(_on_apply_admin_action_pressed)
	doc_btn_row.add_child(apply_btn)

	var culture_btn := Button.new()
	culture_btn.text = "ADVANCE CULTURE"
	culture_btn.pressed.connect(_on_advance_culture_pressed)
	doc_btn_row.add_child(culture_btn)

	var reset_btn := Button.new()
	reset_btn.text = "RESET DOC"
	reset_btn.pressed.connect(_on_reset_doc_pressed)
	doc_btn_row.add_child(reset_btn)

	_culture_label = Label.new()
	_culture_label.add_theme_color_override("font_color", Color("#fde68a"))
	inner.add_child(_culture_label)

	_forbidden_label = Label.new()
	_forbidden_label.add_theme_color_override("font_color", Color("#a7f3d0"))
	inner.add_child(_forbidden_label)

	return panel

func _build_audit_section() -> Control:
	var panel := _build_section("AUDIT LOG", "直近の操作を上から表示する")
	var inner := _section_inner(panel)

	_audit_text = _make_scrolled_rich_text("")
	_audit_text.custom_minimum_size = Vector2(0, 220)
	inner.add_child(_audit_text)
	return panel

func _build_footer() -> Control:
	var footer := PanelContainer.new()
	footer.add_theme_stylebox_override("panel", _make_style_box(Color("#111827"), Color("#374151"), 2, 8))
	footer.custom_minimum_size = Vector2(0, 48)

	var label := Label.new()
	label.text = "ZIP SOURCE: crisis-actor-rules-&-session-simulator / Godot port with rules, simulator, admin doc editing, dice pool, incident options, and audit logging."
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("#6b7280"))
	footer.add_child(label)

	return footer

func _make_small_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color("#d1d5db"))
	return label

func _make_scrolled_rich_text(text: String) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = false
	label.fit_content = true
	label.text = text
	label.add_theme_color_override("default_color", Color("#d1d5db"))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return label

func _make_style_box(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.border_width_left = border_width
	box.border_width_right = border_width
	box.border_width_top = border_width
	box.border_width_bottom = border_width
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box

func _build_roles_rules_text() -> String:
	var text := "[b]ゲームの基本セットアップ[/b]\n"
	text += "プレイヤーは災害偽装チームの役職につき、対立する勝利条件を胸に、国家規模の不祥事を『ただの演習』へと書き換える冷酷な事務処理と心理戦に身を投じます。\n\n"
	text += "[b]配属役職と裏の顔[/b]\n"
	for role in Data.ROLES:
		text += "・%s\n" % role["name"]
		text += "  %s\n" % role["description"]
		text += "  秘密: %s\n" % role["secret"]
		text += "  勝利条件: %s\n\n" % role["win_condition"]
	text += "[b]管理カウンター[/b]\n"
	text += "・信憑性 (Credibility)\n・予算 (Budget)\n・準備時間 (Prep Time)\n"
	text += "・現実混入率 (Anomaly Rate)\n・監査負債 (Audit Debt)\n・共犯クロック (Conspiracy Clock)\n・機材劣化 (Decay Rate)\n"
	return text

func _build_phases_text() -> String:
	var text := "[b]5段階の崩壊プロセス[/b]\n"
	text += "セッションは以下のフェーズに沿って進行します。進むほどに『虚構』と『現実の災害』の境界が曖昧になり、事務作業（隠蔽）は冷酷さを増していきます。\n\n"
	for phase in Data.PHASES:
		text += "%s\n" % phase["title"]
		text += "%s\n" % phase["subtitle"]
		text += "%s\n" % phase["description"]
		text += "Objective: %s\n\n" % phase["objective"]
	return text

func _build_codes_text() -> String:
	var text := "[b]黒塗り理由コード[/b]\n"
	for blackout in Data.BLACKOUT_CODES:
		text += "%s / %s\n" % [blackout["code"], blackout["label"]]
		text += "  %s\n\n" % blackout["description"]
	text += "[b]禁止語の自動置換[/b]\n"
	for forbidden in Data.FORBIDDEN_WORDS:
		text += "・%s → %s\n" % [forbidden["forbidden"], forbidden["replacement"]]
		text += "  %s\n" % forbidden["description"]
	return text

func _seed_cards() -> void:
	_cards = [
		{
			"id": "card_setup_1",
			"type": "gray",
			"title": "台本にない一般避難者",
			"body": "演出エリアBに紛れ込んだ一般人。演出スモークを本物の災害だと思い込んでパニックを起こしそう。",
			"phase": 1,
			"rot_stage": 0,
			"created_at": "18:20",
			"owner": "",
		},
		{
			"id": "card_setup_2",
			"type": "rough",
			"title": "初期センサーの調整ミス",
			"body": "C地区に設置された大気質センサーのキャリブレーションが行われていない。微細な異常を大災害と誤認する恐れあり。",
			"phase": 1,
			"owner": "エンジニア",
			"created_at": "18:22",
		},
	]

func _refresh_all() -> void:
	_refresh_session_summary()
	_refresh_counter_rows()
	_refresh_role_buttons()
	_refresh_phase_buttons()
	_refresh_dice_ui()
	_refresh_incident_ui()
	_refresh_cards_ui()
	_refresh_admin_ui()
	_refresh_audit_log()
	
	if _ending_selector_container:
		_ending_selector_container.visible = (_current_phase_index == 5)
	_refresh_safety_kernel_ui()

func _refresh_session_summary() -> void:
	var role := _current_role()
	var phase := _current_phase_info()
	_session_summary.text = "ACTIVE ROLE: %s | PHASE: %s | CARDS: %d | AUDIT LOG: %d" % [role["name"], PHASES_FLOW[_current_phase_index], _cards.size(), _audit_log.size()]
	_role_summary.text = "Role summary: %s" % role["win_condition"]
	_phase_summary.text = "%s\n%s\n%s" % [phase["title"], phase["subtitle"], phase["objective"]]

func _refresh_role_buttons() -> void:
	for i in range(_role_buttons.size()):
		var btn := _role_buttons[i]
		btn.button_pressed = i == _selected_role_index

func _refresh_phase_buttons() -> void:
	for i in range(_phase_buttons.size()):
		var btn := _phase_buttons[i]
		btn.button_pressed = Data.PHASES[i]["phase"] == _selected_phase

func _refresh_counter_rows() -> void:
	for key in ["credibility", "anomaly_rate", "audit_debt", "conspiracy_clock", "decay_rate", "budget"]:
		var value_label := _counter_value_labels.get(key) as Label
		var bar := _counter_value_labels.get(key + "_bar") as ProgressBar
		if value_label == null or bar == null:
			continue
		var value := int(_counters[key])
		var max_value := int(_counter_value_labels[key + "_max"])
		value_label.text = "%d / %d" % [value, max_value]
		bar.value = value
		
	# Update clock stage text
	if _clock_stage_label:
		var scenario_data = Data.SCENARIOS.get(_current_scenario_id)
		if scenario_data:
			var clock_val = int(_counters["conspiracy_clock"])
			var stages = scenario_data["clock_stages"]
			if clock_val >= 0 and clock_val < stages.size():
				_clock_stage_label.text = "進捗: %s" % stages[clock_val]
				_clock_stage_label.visible = true
			else:
				_clock_stage_label.visible = false
		else:
			_clock_stage_label.visible = false

func _refresh_dice_ui() -> void:
	var results_text := []
	for n in _dice_results_array:
		results_text.append(str(n))
	_dice_results.text = "Results: [%s]" % ", ".join(results_text)
	_dice_summary.text = _dice_summary_data["description"]

func _refresh_incident_ui() -> void:
	var scenario: Dictionary = Data.INCIDENT_SCENARIOS[_selected_incident_index]
	_incident_title.text = scenario["title"]
	_incident_desc.text = scenario["description"]
	if _incident_outcome.text.is_empty():
		_incident_outcome.text = "Incident outcome will be written here after a choice is applied."

func _refresh_cards_ui() -> void:
	if _is_updating_cards:
		return
	_is_updating_cards = true
	_cards_list.clear()
	for card in _cards:
		_cards_list.add_item("%s [%s]" % [card["title"], card["type"]])
	if _selected_card_index >= 0 and _selected_card_index < _cards.size():
		_cards_list.select(_selected_card_index)
		_card_detail.text = _format_card_detail(_cards[_selected_card_index])
	else:
		_card_detail.text = "Select a card to inspect its current state."
	_is_updating_cards = false

func _refresh_admin_ui() -> void:
	_culture_label.text = "Culture clock: %d / 4" % _culture_clock
	_forbidden_label.text = "Forbidden word substitutions applied: %d" % _forbidden_count
	_admin_text_edit.text = _admin_text_edit.text if _admin_text_edit.text != "" else Data.INITIAL_ADMIN_DOC_TEXT

func _refresh_audit_log() -> void:
	var lines: Array[String] = []
	for entry in _audit_log:
		var line := "[%s] %s | %s" % [entry["timestamp"], entry["role"], entry["action"]]
		if entry["reason_code"] != "":
			line += " | %s" % entry["reason_code"]
		if entry["result_text"] != "":
			line += " | %s" % entry["result_text"]
		lines.append(line)
	_audit_text.text = "\n".join(lines)

func _current_role() -> Dictionary:
	return Data.ROLES[_selected_role_index]

func _current_phase_info() -> Dictionary:
	return Data.get_phase_info(_selected_phase)

func _add_audit_log(action: String, original_text: String = "", reason_code: String = "", result_text: String = "") -> void:
	var entry := {
		"timestamp": Time.get_time_string_from_system(),
		"role": _current_role()["name"],
		"action": action,
		"original_text": original_text,
		"reason_code": reason_code,
		"result_text": result_text,
	}
	_audit_log.push_front(entry)
	if _audit_log.size() > 30:
		_audit_log.resize(30)
	_refresh_audit_log()

func _apply_counter_modifiers(modifier: Dictionary) -> void:
	for key in modifier.keys():
		var value := int(modifier[key])
		match key:
			"credibility":
				_counters.credibility = clampi(int(_counters.credibility) + _scaled_clock_delta(value), 0, 6)
			"anomaly_rate":
				_counters.anomaly_rate = clampi(int(_counters.anomaly_rate) + _scaled_clock_delta(value), 0, 6)
			"audit_debt":
				_counters.audit_debt = clampi(int(_counters.audit_debt) + _scaled_clock_delta(value), 0, 6)
			"conspiracy_clock":
				_counters.conspiracy_clock = clampi(int(_counters.conspiracy_clock) + _scaled_clock_delta(value), 0, 6)
			"decay_rate":
				_counters.decay_rate = clampi(int(_counters.decay_rate) + _scaled_clock_delta(value), 0, 3)
			"budget":
				_counters.budget = max(0, int(_counters.budget) + value)
	_refresh_counter_rows()

func _scaled_clock_delta(value: int) -> int:
	if value == 0:
		return 0
	var magnitude := maxi(1, int(ceil(abs(float(value)) / 15.0)))
	return magnitude if value > 0 else -magnitude

func _roll_dice_pool() -> void:
	_dice_pool = int(_dice_pool_spin.value)
	_dice_results_array.clear()
	var clean_success := 0
	var spectacle_success := 0
	var noise := 0
	for _i in range(_dice_pool):
		var die := randi_range(1, 6)
		_dice_results_array.append(die)
		if die == 5:
			clean_success += 1
		elif die == 6:
			spectacle_success += 1
		elif die == 1:
			noise += 1
	var results_str := []
	for value in _dice_results_array:
		results_str.append(str(value))
	var description := "【成功なし】"
	if clean_success > 0 or spectacle_success > 0:
		description = "【成功】"
		if clean_success > 0 and spectacle_success == 0:
			description += " クリーン成功 %d" % clean_success
		elif spectacle_success > 0 and clean_success == 0:
			description += " 派手な成功 %d" % spectacle_success
		else:
			description += " 成功と派手な成功が混在"
	if noise > 0:
		description += " / ノイズ %d" % noise
	_dice_summary_data = {
		"clean": clean_success,
		"spectacle": spectacle_success,
		"noise": noise,
		"description": description,
	}
	_refresh_dice_ui()
	_add_audit_log("D6ダイスプール判定", "[%s]" % ", ".join(results_str), "DICE", description)

func _on_role_pressed(index: int) -> void:
	_selected_role_index = index
	_refresh_role_buttons()
	_refresh_session_summary()
	_add_audit_log("役職の選択", Data.ROLES[index]["name"], "ROLE-SELECT", "Role switched.")

func _on_phase_pressed(phase_number: int) -> void:
	_selected_phase = phase_number
	_refresh_phase_buttons()
	_refresh_session_summary()
	_add_audit_log("フェーズ変更", "Phase %d" % phase_number, "PHASE-SET", Data.get_phase_info(phase_number).get("title", ""))

func _on_incident_option_pressed(option_index: int) -> void:
	var scenario: Dictionary = Data.INCIDENT_SCENARIOS[_selected_incident_index]
	var option: Dictionary = scenario["options"][option_index]
	_apply_counter_modifiers(option["modifier"])
	_incident_outcome.text = option["outcome_text"]
	_add_audit_log("インシデント選択", option["text"], option["id"], option["outcome_text"])

func _on_add_card_pressed() -> void:
	var title := _card_title_edit.text.strip_edges()
	if title.is_empty():
		_add_audit_log("CARD_CREATED_FAILED", "", "CARD-ADD", "Title is empty.")
		return
	var card := {
		"id": "card_custom_%d" % Time.get_ticks_msec(),
		"type": _card_type_option.get_item_text(_card_type_option.selected),
		"title": title,
		"body": _card_body_edit.text,
		"owner": _card_owner_edit.text.strip_edges(),
		"phase": _selected_phase,
		"created_at": Time.get_time_string_from_system(),
	}
	_cards.append(card)
	_card_title_edit.text = ""
	_card_body_edit.text = ""
	_card_owner_edit.text = ""
	_selected_card_index = _cards.size() - 1
	_refresh_cards_ui()
	_add_audit_log("CARD_CREATED", "title: %s | type: %s" % [title, card["type"]], "CARD-ADD", card["body"])

func _on_transform_card_pressed() -> void:
	if _selected_card_index < 0 or _selected_card_index >= _cards.size():
		return
	var target_index = _card_transform_target_option.selected
	var target_type = _card_transform_target_option.get_item_metadata(target_index)
	var card: Dictionary = _cards[_selected_card_index]
	var old_type: String = card["type"]
	
	# Validate conversion
	var is_valid = false
	if old_type == "gray" and (target_type == "black" or target_type == "white"):
		is_valid = true
	elif old_type == "black" and (target_type == "investigation" or target_type == "protected" or target_type == "classification"):
		is_valid = true
	elif old_type == "suspicion" and (target_type == "gray" or target_type == "white"):
		is_valid = true
	elif old_type == "rough" and target_type == "gray":
		is_valid = true
		
	if not is_valid:
		print("[CardLifecycle] Invalid card conversion from ", old_type, " to ", target_type)
		_add_audit_log("CARD_CONVERTED_FAILED", card["title"], "CARD-TRANSFORM-FAIL", "%s から %s への変換は無効です。" % [old_type, target_type])
		return
		
	card["type"] = target_type
	_cards[_selected_card_index] = card
	_refresh_cards_ui()
	
	# Detailed conversion log
	_add_audit_log("CARD_CONVERTED", "from: %s | to: %s | title: %s" % [old_type, target_type, card["title"]], "CARD-TRANSFORM", "phase: Phase %d" % _selected_phase)

func _on_delete_card_pressed() -> void:
	if _selected_card_index < 0 or _selected_card_index >= _cards.size():
		return
	var card: Dictionary = _cards[_selected_card_index]
	_cards.remove_at(_selected_card_index)
	_selected_card_index = -1
	_refresh_cards_ui()
	_add_audit_log("CARD_DELETED", card["title"], "CARD-DELETE", "Card removed from table.")

func _on_card_selected(index: int) -> void:
	_selected_card_index = index
	if _selected_card_index >= 0 and _selected_card_index < _cards.size():
		_card_detail.text = _format_card_detail(_cards[_selected_card_index])

func _format_card_detail(card: Dictionary) -> String:
	var text := "[b]%s[/b]\n" % card["title"]
	text += "Type: %s\n" % card["type"]
	text += "Phase: %d\n" % int(card["phase"])
	text += "Owner: %s\n" % str(card.get("owner", ""))
	text += "Created: %s\n\n" % str(card["created_at"])
	text += "%s" % card["body"]
	return text

func _on_admin_text_changed() -> void:
	if _is_updating_admin_text:
		return
	var filtered := _apply_forbidden_words(_admin_text_edit.text)
	if filtered != _admin_text_edit.text:
		_is_updating_admin_text = true
		_admin_text_edit.text = filtered
		_is_updating_admin_text = false
	_refresh_admin_ui()

func _apply_forbidden_words(source_text: String) -> String:
	var text := source_text
	var replaced_count := 0
	
	# Global forbidden words
	for item in Data.FORBIDDEN_WORDS:
		var forbidden: String = item["forbidden"]
		var replacement: String = item["replacement"]
		if text.find(forbidden) != -1:
			text = text.replace(forbidden, replacement)
			replaced_count += 1
			_add_audit_log("禁止語の強制置換（検閲）", forbidden, "SYSTEM-AUTO", replacement)
			
	# Scenario-specific forbidden words
	var scenario_data = Data.SCENARIOS.get(_current_scenario_id)
	if scenario_data and scenario_data.has("forbidden_words"):
		for item in scenario_data["forbidden_words"]:
			var forbidden: String = item["forbidden"]
			var replacement: String = item["replacement"]
			if text.find(forbidden) != -1:
				text = text.replace(forbidden, replacement)
				replaced_count += 1
				_add_audit_log("禁止語の強制置換（検閲・シナリオ固有）", forbidden, "SYSTEM-AUTO", replacement)
				
	if replaced_count > 0:
		_forbidden_count += replaced_count
	return text

func _on_apply_admin_action_pressed() -> void:
	var keyword := _admin_keyword_edit.text.strip_edges()
	if keyword.is_empty():
		_add_audit_log("行政文書アクション失敗", "", "DOC-EMPTY", "Keyword was empty.")
		return
	var selected_code: Dictionary = Data.BLACKOUT_CODES[_admin_code_option.selected]
	var action_index := _admin_action_option.selected
	var replacement := ""
	var action_label := ""
	match action_index:
		0:
			replacement = "█████ [%s: %s]" % [selected_code["code"], selected_code["label"]]
			action_label = "黒塗りの適用（行政処分）"
		1:
			replacement = "【機密保管: %s】" % selected_code["label"]
			action_label = "Black Ledgerへの封印（黒カード作成）"
		2:
			var forbidden: Dictionary = Data.get_forbidden_replacement(keyword)
			replacement = forbidden.get("replacement", "[観光美化語: %s]" % keyword)
			action_label = "文化財化（美化・観光レトリック適用）"
	if _admin_text_edit.text.find(keyword) == -1:
		_add_audit_log("行政文書アクション失敗", keyword, "DOC-NO-MATCH", "Target word was not found.")
		return
	_is_updating_admin_text = true
	_admin_text_edit.text = _admin_text_edit.text.replace(keyword, replacement)
	_is_updating_admin_text = false
	_add_audit_log(action_label, keyword, selected_code["code"], replacement)
	_refresh_admin_ui()

func _on_advance_culture_pressed() -> void:
	if _culture_clock >= 4:
		return
	_culture_clock += 1
	var new_text := _admin_text_edit.text
	var change_log := ""
	if _culture_clock == 1:
		new_text = new_text.replace("有毒ガスが散布された", "微細な霧が発生した")
		new_text = new_text.replace("死亡者が発生した", "一時的な体調不良を訴える者がいた")
		change_log = "記述の微細な環境調整"
	elif _culture_clock == 2:
		new_text = new_text.replace("死亡者は0名である", "全参加者は安全に帰還した")
		new_text = new_text.replace("帰宅困難者（要経過観察）", "エネルギッシュな参加者")
		change_log = "観光誘致のための表現最適化"
	elif _culture_clock == 3:
		new_text = new_text.replace("失踪者が12名報告されている", "新規登録の地域ファンが12名誕生した")
		new_text = new_text.replace("人災ではなく", "天からの恵みと、住民の連帯感を示すものであり")
		change_log = "地方創生の文脈の挿入"
	else:
		new_text = """【地域の未来を創る！広域クリーンアップ・アドベンチャー（第3140回）実施レポート】

1. 経緯
本日、豊かな自然に囲まれた当地区にて、地域の絆を深める「広域クリーンアップ・アドベンチャー」が盛大に開催されました。一部機材の演出用システム微細挙動はありましたが、地域住民の皆様の『建設的フィードバック』により、よりクリーンな運営に向けた温かい一歩を踏み出すことができました。

2. イベントの成果
参加された全ての皆様が、笑顔でクリーンアップ活動を達成。一部で「行方がわからない」と噂された12名の皆様は、地域の隠れた魅力スポットを探索する「謎解きアドベンチャー」の特別ミッションに参加されており、全員がこの地を愛する新規地域ファンとなりました。本件は地域活性化における最高の災害記憶として、未来に受け継がれます。

3. 今後のビジョン
今回の美しい連帯は、風評被害の懸念を完全に払拭する『地域観光プロモーション』の美しい一枚の絵（公式記録）として永遠に保管されます。

編纂：観光振興推進事務局（元：倫理監査事務局）"""
		change_log = "行政報告書の『完全な地方PR資料化（文化財化）』完了"

	_is_updating_admin_text = true
	_admin_text_edit.text = new_text
	_is_updating_admin_text = false
	_add_audit_log("文化財化処理（PR化）進行 [段階 %d/4]" % _culture_clock, "公文書テキスト全体", "CULTURE-CLOCK", change_log)
	_refresh_admin_ui()

func _on_reset_doc_pressed() -> void:
	_is_updating_admin_text = true
	_admin_text_edit.text = Data.INITIAL_ADMIN_DOC_TEXT
	_is_updating_admin_text = false
	_forbidden_count = 0
	_culture_clock = 0
	_add_audit_log("行政文書の初期化", "編集中の全データ", "RESET", "初期報告書テンプレートに差し戻し")
	_refresh_admin_ui()

# --- Scenario & Phase Flow & Safety Kernel Additions ---

func _build_scenario_section() -> Control:
	var panel := _build_section("SCENARIO PRESET", "シナリオを選択して初期状態をロードする")
	var inner := _section_inner(panel)
	
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	inner.add_child(row)
	
	var label := Label.new()
	label.text = "シナリオ:"
	row.add_child(label)
	
	_scenario_option = OptionButton.new()
	_scenario_option.add_item("EP2: 診断書のない負傷者", 0)
	_scenario_option.set_item_metadata(0, "ep2")
	_scenario_option.add_item("EP3: 帳外神楽", 1)
	_scenario_option.set_item_metadata(1, "ep3")
	_scenario_option.item_selected.connect(_on_scenario_selected)
	row.add_child(_scenario_option)
	
	var load_btn := Button.new()
	load_btn.text = "シナリオ初期化"
	load_btn.pressed.connect(_on_load_scenario_pressed)
	row.add_child(load_btn)
	
	return panel

func _on_scenario_selected(index: int) -> void:
	var metadata = _scenario_option.get_item_metadata(index)
	_current_scenario_id = metadata

func _on_load_scenario_pressed() -> void:
	_load_scenario(_current_scenario_id)

func _load_scenario(scenario_id: String) -> void:
	var scenario_data = Data.SCENARIOS[scenario_id]
	print("[ScenarioLoader] Loading scenario: ", scenario_data["title"])
	
	# Clear existing cards and audit logs
	_cards.clear()
	_audit_log.clear()
	_selected_card_index = -1
	_forbidden_count = 0
	_culture_clock = 0
	_safety_checks_used = 0
	_audit_pauses_used = 0
	_emergency_injunctions_used = 0
	
	if _ending_outcome_label:
		_ending_outcome_label.text = ""
	
	# Load counters
	var counters_preset = scenario_data["initial_counters"]
	for key in counters_preset.keys():
		_counters[key] = counters_preset[key]
		
	# Load cards
	for card_data in scenario_data["initial_cards"]:
		var card = card_data.duplicate()
		card["created_at"] = Time.get_time_string_from_system()
		_cards.append(card)
		
	# Reset phase to Setup (index 0)
	_current_phase_index = 0
	_selected_phase = 1
	if _phase_label:
		_phase_label.text = "現在のフェーズ: Setup"
	_update_flow_notes()
	
	# Update Conspiracy Clock label name
	var clock_name = scenario_data["clock_name"]
	if _counter_name_labels.has("conspiracy_clock"):
		_counter_name_labels["conspiracy_clock"].text = clock_name
		
	# Add audit log
	_add_audit_log("SESSION_STARTED", scenario_data["title"], "BOOT", "Scenario loaded and session initialized.")
	
	# Refresh UI
	_refresh_all()

func _build_session_flow_section() -> Control:
	var panel := _build_section("SESSION FLOW", "セッションフェーズの進行管理")
	var inner := _section_inner(panel)
	
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	inner.add_child(row)
	
	_phase_label = Label.new()
	_phase_label.text = "現在のフェーズ: Setup"
	_phase_label.add_theme_font_size_override("font_size", 16)
	_phase_label.add_theme_color_override("font_color", Color("#f8fafc"))
	row.add_child(_phase_label)
	
	_next_phase_btn = Button.new()
	_next_phase_btn.text = "Next Phase ▶"
	_next_phase_btn.pressed.connect(_on_next_phase_pressed)
	row.add_child(_next_phase_btn)
	
	var notes_title := Label.new()
	notes_title.text = "【GM進行メモ】"
	notes_title.add_theme_color_override("font_color", Color("#9ca3af"))
	inner.add_child(notes_title)
	
	_phase_flow_notes = Label.new()
	_phase_flow_notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_phase_flow_notes.add_theme_color_override("font_color", Color("#d1d5db"))
	_phase_flow_notes.text = "シナリオをロードしてください。"
	inner.add_child(_phase_flow_notes)
	
	_ending_selector_container = HBoxContainer.new()
	_ending_selector_container.visible = false
	_ending_selector_container.add_theme_constant_override("separation", 8)
	inner.add_child(_ending_selector_container)
	
	var ending_label := Label.new()
	ending_label.text = "Ending選択:"
	_ending_selector_container.add_child(ending_label)
	
	var btn_a := Button.new()
	btn_a.text = "Aエンド"
	btn_a.pressed.connect(_on_ending_selected.bind("A"))
	_ending_selector_container.add_child(btn_a)
	
	var btn_b := Button.new()
	btn_b.text = "Bエンド"
	btn_b.pressed.connect(_on_ending_selected.bind("B"))
	_ending_selector_container.add_child(btn_b)
	
	var btn_c := Button.new()
	btn_c.text = "Cエンド"
	btn_c.pressed.connect(_on_ending_selected.bind("C"))
	_ending_selector_container.add_child(btn_c)
	
	_ending_outcome_label = Label.new()
	_ending_outcome_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ending_outcome_label.add_theme_color_override("font_color", Color("#a7f3d0"))
	_ending_outcome_label.text = ""
	inner.add_child(_ending_outcome_label)
	
	return panel

func _on_next_phase_pressed() -> void:
	if _current_phase_index >= PHASES_FLOW.size() - 1:
		print("[SessionFlow] Already at the final phase.")
		return
		
	_current_phase_index += 1
	var new_phase_name = PHASES_FLOW[_current_phase_index]
	_phase_label.text = "現在のフェーズ: %s" % new_phase_name
	
	if _current_phase_index == 0:
		_selected_phase = 1
	elif _current_phase_index >= 1 and _current_phase_index <= 4:
		_selected_phase = _current_phase_index
	elif _current_phase_index == 5:
		_selected_phase = 5
	elif _current_phase_index == 6:
		_selected_phase = 5
		
	if new_phase_name == "Phase 3":
		_counters["conspiracy_clock"] = clampi(int(_counters["conspiracy_clock"]) + 1, 0, 6)
		_add_audit_log("CLOCK_CHANGED", "conspiracy_clock", "SYSTEM", "Conspiracy clock increased on entering Phase 3.")
	elif new_phase_name == "Phase 4 / Climax":
		_counters["conspiracy_clock"] = clampi(int(_counters["conspiracy_clock"]) + 1, 0, 6)
		_add_audit_log("CLOCK_CHANGED", "conspiracy_clock", "SYSTEM", "Conspiracy clock increased on entering Phase 4.")
		
	_add_audit_log("PHASE_CHANGED", new_phase_name, "FLOW", "Session phase transitioned to %s." % new_phase_name)
	
	_refresh_all()
	_update_flow_notes()

func _update_flow_notes() -> void:
	if not _phase_flow_notes:
		return
	var notes = ""
	match _current_phase_index:
		0:
			notes = "初期カードの生成とセットアップを行います。PLの役職を確認してください。"
		1:
			notes = "演習の準備フェーズ。灰カードが発生します。PLは調査や隠蔽を開始できます。"
		2:
			notes = "演習本番。ノイズや異常値が発生し始めます。現実混入率の上昇に気をつけてください。"
		3:
			notes = "インシデント発生！「演出強行」か「安全対処」かの深刻な決断を迫られます。"
		4:
			notes = "クライマックス。公式記録（白カード化）の作成、または真実の暴露（黒カード化）の瀬戸際です。"
		5:
			notes = "セッションの結末。A/B/Cエンドのいずれかを選択し、公式ログを固定してください。"
		6:
			notes = "デブリーフィング（Fiction Closeの儀式）。セッション全体の監査ログをMarkdown出力して保存しましょう。"
	_phase_flow_notes.text = notes

func _build_safety_kernel_section() -> Control:
	var panel := _build_section("SAFETY KERNEL", "安全確認・一時停止・緊急差止")
	var inner := _section_inner(panel)
	
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	inner.add_child(row)
	
	_safety_check_btn = Button.new()
	_safety_check_btn.text = "Safety Check"
	_safety_check_btn.pressed.connect(_on_safety_check_pressed)
	row.add_child(_safety_check_btn)
	
	_audit_pause_btn = Button.new()
	_audit_pause_btn.text = "Audit Pause"
	_audit_pause_btn.pressed.connect(_on_audit_pause_pressed)
	row.add_child(_audit_pause_btn)
	
	_emergency_injunction_btn = Button.new()
	_emergency_injunction_btn.text = "Emergency Injunction"
	_emergency_injunction_btn.pressed.connect(_on_emergency_injunction_pressed)
	row.add_child(_emergency_injunction_btn)
	
	_export_md_btn = Button.new()
	_export_md_btn.text = "Markdown保存 & エクスポート"
	_export_md_btn.pressed.connect(_on_export_markdown_pressed)
	row.add_child(_export_md_btn)
	
	_safety_kernel_label = Label.new()
	_safety_kernel_label.text = "安全カウンター: Safety Checks: 0 | Audit Pauses: 0 | Emergency Injunctions: 0/1"
	_safety_kernel_label.add_theme_color_override("font_color", Color("#9ca3af"))
	inner.add_child(_safety_kernel_label)
	
	return panel

func _on_safety_check_pressed() -> void:
	_safety_checks_used += 1
	_add_audit_log("SAFETY_CHECK_USED", "Safety Check executed by players.", "SAFETY", "No game effect. Safety check counter: %d" % _safety_checks_used)
	_refresh_safety_kernel_ui()

func _on_audit_pause_pressed() -> void:
	_audit_pauses_used += 1
	_add_audit_log("AUDIT_PAUSE_USED", "Audit Pause executed by Auditor.", "SAFETY", "No game effect. Audit pause counter: %d" % _audit_pauses_used)
	_refresh_safety_kernel_ui()

func _on_emergency_injunction_pressed() -> void:
	if _emergency_injunctions_used >= _emergency_injunction_limit:
		print("[SafetyKernel] Emergency Injunction limit reached.")
		_add_audit_log("SAFETY_INJUNCTION_FAIL", "Limit reached", "SAFETY", "Emergency Injunction limit (1) already reached.")
		return
		
	if _selected_card_index < 0 or _selected_card_index >= _cards.size():
		print("[SafetyKernel] No card selected.")
		_add_audit_log("SAFETY_INJUNCTION_FAIL", "No card selected", "SAFETY", "Please select a black card first.")
		return
		
	var card = _cards[_selected_card_index]
	if card["type"] != "black":
		print("[SafetyKernel] Selected card is not a Black card.")
		_add_audit_log("SAFETY_INJUNCTION_FAIL", "Invalid card type", "SAFETY", "Emergency Injunction can only be applied to a Black card.")
		return
		
	card["type"] = "protected"
	_cards[_selected_card_index] = card
	_counters["audit_debt"] = clampi(int(_counters["audit_debt"]) - 1, 0, 6)
	_emergency_injunctions_used += 1
	
	_add_audit_log("EMERGENCY_INJUNCTION_USED", "Target: %s" % card["title"], "SAFETY", "Card converted to Protected. Audit debt decreased by 1.")
	
	_refresh_all()

func _refresh_safety_kernel_ui() -> void:
	if _safety_kernel_label:
		_safety_kernel_label.text = "安全カウンター: Safety Checks: %d | Audit Pauses: %d | Emergency Injunctions: %d/1" % [_safety_checks_used, _audit_pauses_used, _emergency_injunctions_used]

func _on_ending_selected(ending_type: String) -> void:
	var scenario_data = Data.SCENARIOS.get(_current_scenario_id)
	if not scenario_data:
		return
		
	var ending_text = scenario_data["endings"][ending_type]
	_ending_outcome_label.text = ending_text
	
	_add_audit_log("ENDING_SELECTED", "Ending: %s" % ending_type, "ENDING", ending_text)

func _on_export_markdown_pressed() -> void:
	var scenario_data = Data.SCENARIOS.get(_current_scenario_id)
	var scenario_title = scenario_data["title"] if scenario_data else "Unknown Scenario"
	
	# Append SESSION_CLOSED log
	_add_audit_log("SESSION_CLOSED", scenario_title, "SHUTDOWN", "Session closed and exported.")
	
	# Generate Markdown
	var md := "# CRISIS ACTOR - セッション記録\n\n"
	md += "## ■ 基本情報\n"
	md += "- **日時**: %s\n" % Time.get_datetime_string_from_system()
	md += "- **シナリオ**: %s\n" % scenario_title
	md += "- **フェーズ**: %s\n\n" % PHASES_FLOW[_current_phase_index]
	
	md += "## ■ カウンター状態\n"
	for key in _counters.keys():
		var max_val = _counter_value_labels.get(key + "_max", 6)
		md += "- **%s**: %d / %d\n" % [key, _counters[key], max_val]
	md += "\n"
	
	md += "## ■ 安全カウンター\n"
	md += "- **Safety Checks**: %d\n" % _safety_checks_used
	md += "- **Audit Pauses**: %d\n" % _audit_pauses_used
	md += "- **Emergency Injunctions**: %d / 1\n\n" % _emergency_injunctions_used
	
	md += "## ■ 終了時のカード状態\n"
	if _cards.size() == 0:
		md += "カードはありません。\n"
	else:
		for card in _cards:
			md += "### 【%s】%s\n" % [card["type"].to_upper(), card["title"]]
			md += "- **Owner**: %s\n" % str(card.get("owner", ""))
			md += "- **Phase**: %d\n" % int(card["phase"])
			md += "- **Content**: %s\n\n" % card["body"]
			
	md += "## ■ 結末 (Ending)\n"
	md += "%s\n\n" % _ending_outcome_label.text
	
	md += "## ■ 監査ログ履歴 (Audit Log)\n"
	for entry in _audit_log:
		md += "### **%s**\n" % entry["action"]
		md += "- **Time**: %s\n" % entry["timestamp"]
		md += "- **Actor**: %s\n" % entry["role"]
		if entry["original_text"] != "":
			md += "- **Details**: %s\n" % entry["original_text"]
		if entry["result_text"] != "":
			md += "- **Result**: %s\n" % entry["result_text"]
		md += "\n"
		
	# Write to user://session_log.md
	var file = FileAccess.open("user://session_log.md", FileAccess.WRITE)
	if file:
		file.store_string(md)
		file.close()
		print("[Exporter] Successfully saved session log to user://session_log.md")
	else:
		printerr("[Exporter] Failed to save session log.")
		
	# Copy to clipboard
	DisplayServer.clipboard_set(md)
	print("[Exporter] Copied markdown to clipboard.")
	
	# Show confirmation popup
	var dialog = AcceptDialog.new()
	dialog.title = "Export Success"
	dialog.dialog_text = "session_log.md saved to user:// and copied to clipboard."
	add_child(dialog)
	dialog.popup_centered()
