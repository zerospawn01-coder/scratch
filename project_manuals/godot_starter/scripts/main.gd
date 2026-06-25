extends Control

const SESSION_STATE_SCRIPT := preload("res://scripts/session_state.gd")

const DOCUMENTS: Array[Dictionary] = [
	{
		"title": "ルールブック",
		"path": "res://docs/crisis_actor/crisis_actor_rulebook.md",
		"button": "RulebookButton",
	},
	{
		"title": "キャラクター",
		"path": "res://docs/crisis_actor/crisis_actor_characters.md",
		"button": "CharactersButton",
	},
	{
		"title": "シナリオ EP1",
		"path": "res://docs/crisis_actor/crisis_actor_scenario_ep1.md",
		"button": "ScenarioButton",
	},
	{
		"title": "シナリオ EP2",
		"path": "res://docs/crisis_actor/crisis_actor_scenario_ep2.md",
		"button": "ScenarioEp2Button", # Note: not in sidebar layout but accessible via doc selector
	},
	{
		"title": "シナリオ EP3",
		"path": "res://docs/crisis_actor/crisis_actor_scenario_ep3.md",
		"button": "ScenarioEp3Button",
	},
	{
		"title": "ウォークスルー",
		"path": "res://docs/crisis_actor/walkthrough.md",
		"button": "WalkthroughButton",
	},
	{
		"title": "実装計画",
		"path": "res://docs/crisis_actor/implementation_plan.md",
		"button": "PlanButton",
	},
	{
		"title": "タスク",
		"path": "res://docs/crisis_actor/task.md",
		"button": "TaskButton",
	},
]

const QUICK_SEARCH_TERMS: Array[String] = [
	"B級処理",
	"粗い演出カード",
	"灰カード",
	"腐爛",
	"黒カード",
	"Witness Claim",
	"共犯クロック",
	"異議申立",
	"現実混入率",
	"ノイズ",
	"白カード",
	"帳外帳",
	"文化財化処理クロック",
	"黒塗り理由コード",
	"調査対象カード",
	"診断書",
	"検証委員会",
	"既往症",
	"瀬尾アキラ",
	"真田リョウ",
]

const BODY_COLOR := Color(0.92, 0.93, 0.95)
const MUTED_COLOR := Color(0.72, 0.76, 0.82)
const HIGHLIGHT_BG := Color(0.93, 0.80, 0.20)
const CURRENT_HIGHLIGHT_BG := Color(1.0, 0.46, 0.16)
const HIGHLIGHT_FG := Color(0.06, 0.06, 0.06)
const MOBILE_WIDTH := 1024.0
const COMPACT_TOC_WIDTH := 1100.0
const SEARCH_CHARS_TO_IGNORE := "[]【】 \t　"

@onready var _doc_title: Label = $Root/Columns/ContentPanel/ContentMargin/ContentRows/DocTitle
@onready var _document_body: RichTextLabel = $Root/Columns/ContentPanel/ContentMargin/ContentRows/DocumentBody
@onready var _sidebar: VBoxContainer = $Root/Columns/Sidebar
@onready var _search_input: LineEdit = $Root/Columns/ContentPanel/ContentMargin/ContentRows/SearchContainer/SearchInput
@onready var _search_count: Label = $Root/Columns/ContentPanel/ContentMargin/ContentRows/SearchContainer/SearchCount
@onready var _prev_button: Button = $Root/Columns/ContentPanel/ContentMargin/ContentRows/SearchContainer/PrevButton
@onready var _next_button: Button = $Root/Columns/ContentPanel/ContentMargin/ContentRows/SearchContainer/NextButton
@onready var _doc_selector: OptionButton = $Root/Columns/ContentPanel/ContentMargin/ContentRows/SearchContainer/DocSelector
@onready var _toc_toggle_button: Button = $Root/Columns/ContentPanel/ContentMargin/ContentRows/SearchContainer/TOCToggleButton
@onready var _quick_search_row: HFlowContainer = $Root/Columns/ContentPanel/ContentMargin/ContentRows/QuickSearchRow
@onready var _toc_list: VBoxContainer = $Root/Columns/TOCPanel/TOCMargin/TOCRows/TOCScroll/TOCList
@onready var _toc_panel: PanelContainer = $Root/Columns/TOCPanel

@onready var _ops_panel: PanelContainer = $Root/Columns/OpsPanel
@onready var _undo_btn: Button = $Root/Columns/OpsPanel/OpsMargin/OpsRows/PhaseRow/UndoBtn
@onready var _warnings_label: Label = $Root/Columns/OpsPanel/OpsMargin/OpsRows/WarningsLabel

@onready var _cred_val: Label = $Root/Columns/OpsPanel/OpsMargin/OpsRows/ClocksGrid/CredVal
@onready var _cred_dec: Button = $Root/Columns/OpsPanel/OpsMargin/OpsRows/ClocksGrid/CredDec
@onready var _cred_inc: Button = $Root/Columns/OpsPanel/OpsMargin/OpsRows/ClocksGrid/CredInc
@onready var _contam_val: Label = $Root/Columns/OpsPanel/OpsMargin/OpsRows/ClocksGrid/ContamVal
@onready var _contam_dec: Button = $Root/Columns/OpsPanel/OpsMargin/OpsRows/ClocksGrid/ContamDec
@onready var _contam_inc: Button = $Root/Columns/OpsPanel/OpsMargin/OpsRows/ClocksGrid/ContamInc
@onready var _debt_val: Label = $Root/Columns/OpsPanel/OpsMargin/OpsRows/ClocksGrid/DebtVal
@onready var _debt_dec: Button = $Root/Columns/OpsPanel/OpsMargin/OpsRows/ClocksGrid/DebtDec
@onready var _debt_inc: Button = $Root/Columns/OpsPanel/OpsMargin/OpsRows/ClocksGrid/DebtInc
@onready var _comp_val: Label = $Root/Columns/OpsPanel/OpsMargin/OpsRows/ClocksGrid/CompVal
@onready var _comp_dec: Button = $Root/Columns/OpsPanel/OpsMargin/OpsRows/ClocksGrid/CompDec
@onready var _comp_inc: Button = $Root/Columns/OpsPanel/OpsMargin/OpsRows/ClocksGrid/CompInc
@onready var _wear_val: Label = $Root/Columns/OpsPanel/OpsMargin/OpsRows/ClocksGrid/WearVal
@onready var _wear_dec: Button = $Root/Columns/OpsPanel/OpsMargin/OpsRows/ClocksGrid/WearDec
@onready var _wear_inc: Button = $Root/Columns/OpsPanel/OpsMargin/OpsRows/ClocksGrid/WearInc

@onready var _add_white_btn: Button = $Root/Columns/OpsPanel/OpsMargin/OpsRows/CardAddFlow/AddWhiteBtn
@onready var _add_gray_btn: Button = $Root/Columns/OpsPanel/OpsMargin/OpsRows/CardAddFlow/AddGrayBtn
@onready var _add_black_btn: Button = $Root/Columns/OpsPanel/OpsMargin/OpsRows/CardAddFlow/AddBlackBtn
@onready var _add_rough_btn: Button = $Root/Columns/OpsPanel/OpsMargin/OpsRows/CardAddFlow/AddRoughBtn

@onready var _card_form_panel: PanelContainer = $Root/Columns/OpsPanel/OpsMargin/OpsRows/CardFormPanel
@onready var _form_title: Label = $Root/Columns/OpsPanel/OpsMargin/OpsRows/CardFormPanel/FormMargin/FormRows/FormTitle
@onready var _input_title: LineEdit = $Root/Columns/OpsPanel/OpsMargin/OpsRows/CardFormPanel/FormMargin/FormRows/InputTitle
@onready var _input_fact: LineEdit = $Root/Columns/OpsPanel/OpsMargin/OpsRows/CardFormPanel/FormMargin/FormRows/InputFact
@onready var _input_cost: LineEdit = $Root/Columns/OpsPanel/OpsMargin/OpsRows/CardFormPanel/FormMargin/FormRows/InputCost
@onready var _input_constraint: LineEdit = $Root/Columns/OpsPanel/OpsMargin/OpsRows/CardFormPanel/FormMargin/FormRows/InputConstraint
@onready var _input_owner: LineEdit = $Root/Columns/OpsPanel/OpsMargin/OpsRows/CardFormPanel/FormMargin/FormRows/InputOwner
@onready var _form_cancel_btn: Button = $Root/Columns/OpsPanel/OpsMargin/OpsRows/CardFormPanel/FormMargin/FormRows/FormButtons/FormCancelBtn
@onready var _form_submit_btn: Button = $Root/Columns/OpsPanel/OpsMargin/OpsRows/CardFormPanel/FormMargin/FormRows/FormButtons/FormSubmitBtn
@onready var _card_list_container: VBoxContainer = $Root/Columns/OpsPanel/OpsMargin/OpsRows/CardScroll/CardList
@onready var _save_btn: Button = $Root/Columns/OpsPanel/OpsMargin/OpsRows/SaveLoadRow/SaveBtn
@onready var _load_btn: Button = $Root/Columns/OpsPanel/OpsMargin/OpsRows/SaveLoadRow/LoadBtn
@onready var _export_btn: Button = $Root/Columns/OpsPanel/OpsMargin/OpsRows/ExportBtn

@onready var _phase_1_btn: Button = $Root/Columns/OpsPanel/OpsMargin/OpsRows/PhaseRow/Phase1Btn
@onready var _phase_2_btn: Button = $Root/Columns/OpsPanel/OpsMargin/OpsRows/PhaseRow/Phase2Btn
@onready var _phase_3_btn: Button = $Root/Columns/OpsPanel/OpsMargin/OpsRows/PhaseRow/Phase3Btn
@onready var _phase_4_btn: Button = $Root/Columns/OpsPanel/OpsMargin/OpsRows/PhaseRow/Phase4Btn
@onready var _phase_5_btn: Button = $Root/Columns/OpsPanel/OpsMargin/OpsRows/PhaseRow/Phase5Btn

var state
var _current_raw_text := ""
var _current_doc_index := 0
var _current_match_index := -1
var _matches: Array[Dictionary] = []
var _heading_records: Array[Dictionary] = []
var _current_form_type := "white"
var _phase_buttons: Array[Button] = []
var _toc_user_visible := true
var _render_generation := 0
var _comp_desc_label: Label


func _ready() -> void:
	state = SESSION_STATE_SCRIPT.new()
	state.state_changed.connect(_on_state_changed)

	_document_body.bbcode_enabled = false
	_document_body.context_menu_enabled = true
	_document_body.fit_content = false

	for index in range(DOCUMENTS.size()):
		var btn_path := str(DOCUMENTS[index]["button"])
		if _sidebar.has_node(NodePath(btn_path)):
			var button := _sidebar.get_node(NodePath(btn_path)) as Button
			if button:
				button.pressed.connect(_show_document.bind(index))

	_doc_selector.clear()
	for document in DOCUMENTS:
		_doc_selector.add_item(str(document["title"]))
	_doc_selector.item_selected.connect(_show_document)

	_search_input.text_changed.connect(_on_search_changed)
	_prev_button.pressed.connect(_on_prev_pressed)
	_next_button.pressed.connect(_on_next_pressed)
	_toc_toggle_button.pressed.connect(_on_toc_toggle_pressed)
	get_viewport().size_changed.connect(_on_window_resized)

	_connect_clock_button(_cred_dec, "credibility", -1)
	_connect_clock_button(_cred_inc, "credibility", 1)
	_connect_clock_button(_contam_dec, "reality_contamination", -1)
	_connect_clock_button(_contam_inc, "reality_contamination", 1)
	_connect_clock_button(_debt_dec, "audit_debt", -1)
	_connect_clock_button(_debt_inc, "audit_debt", 1)
	_connect_clock_button(_comp_dec, "complicity_clock", -1)
	_connect_clock_button(_comp_inc, "complicity_clock", 1)
	_connect_clock_button(_wear_dec, "equipment_wear", -1)
	_connect_clock_button(_wear_inc, "equipment_wear", 1)

	_undo_btn.pressed.connect(_on_undo_pressed)
	_phase_buttons = [_phase_1_btn, _phase_2_btn, _phase_3_btn, _phase_4_btn, _phase_5_btn]
	for index in range(_phase_buttons.size()):
		_phase_buttons[index].pressed.connect(_on_phase_pressed.bind(index + 1))

	_add_white_btn.pressed.connect(_open_card_form.bind("white"))
	_add_gray_btn.pressed.connect(_open_card_form.bind("gray"))
	_add_black_btn.pressed.connect(_open_card_form.bind("black"))
	_add_rough_btn.pressed.connect(_open_card_form.bind("rough"))
	_form_cancel_btn.pressed.connect(func(): _card_form_panel.visible = false)
	_form_submit_btn.pressed.connect(_on_form_submit)
	_save_btn.pressed.connect(_on_save_pressed)
	_load_btn.pressed.connect(_on_load_pressed)
	_export_btn.pressed.connect(_on_export_pressed)

	_build_quick_search_buttons()
	_setup_tabletop_p1_features()
	_show_document(0)
	_on_state_changed()
	_on_window_resized()


func _connect_clock_button(button: Button, property_name: String, delta: int) -> void:
	button.pressed.connect(_adjust_clock.bind(property_name, delta))


func _adjust_clock(property_name: String, delta: int) -> void:
	state.set(property_name, int(state.get(property_name)) + delta)


func _show_document(index: int) -> void:
	_current_doc_index = index
	var document: Dictionary = DOCUMENTS[index]
	_doc_title.text = str(document["title"])
	_current_raw_text = _read_text(str(document["path"]))

	if _doc_selector.selected != index:
		_doc_selector.select(index)

	# Complicity label rename based on scenario
	var comp_label := $Root/Columns/OpsPanel/OpsMargin/OpsRows/ClocksGrid/CompLabel as Label
	if comp_label:
		if document["title"] == "シナリオ EP2":
			comp_label.text = "検証委員会"
		elif document["title"] == "シナリオ EP3":
			comp_label.text = "文化財処理"
		else:
			comp_label.text = "共犯"

	_search_input.clear()
	_current_match_index = -1
	_rebuild_toc()
	_render_document(false)
	_on_state_changed()
	_on_window_resized()


func _build_quick_search_buttons() -> void:
	for child in _quick_search_row.get_children():
		child.queue_free()

	for term in QUICK_SEARCH_TERMS:
		var button := Button.new()
		button.text = term
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = "この語で検索"
		button.pressed.connect(_on_quick_search_pressed.bind(term))
		_quick_search_row.add_child(button)


func _rebuild_toc() -> void:
	_heading_records.clear()
	for child in _toc_list.get_children():
		child.queue_free()

	var lines := _current_raw_text.split("\n")
	var in_code_block := false

	for index in range(lines.size()):
		var trimmed := str(lines[index]).strip_edges()
		if trimmed.begins_with("```"):
			in_code_block = not in_code_block
			continue
		if in_code_block:
			continue

		var level := _get_heading_level(trimmed)
		if level == 0:
			continue

		var title := trimmed.substr(level + 1).strip_edges()
		_heading_records.append({
			"title": title,
			"level": level,
			"paragraph": index,
		})

	for record in _heading_records:
		var level := int(record["level"])
		var title := str(record["title"])
		var paragraph := int(record["paragraph"])
		var button := Button.new()
		button.text = "%s %s" % [_heading_prefix(level), title]
		button.flat = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = "段落 %d に移動" % paragraph
		button.pressed.connect(_jump_to_paragraph.bind(paragraph))
		_toc_list.add_child(button)


func _render_document(preserve_scroll: bool) -> void:
	_render_generation += 1
	var render_token := _render_generation
	var scroll_value := _document_body.get_v_scroll_bar().value if preserve_scroll else 0.0
	var query := _search_input.text.strip_edges()

	_matches = _collect_matches(query)
	if _matches.is_empty():
		_current_match_index = -1
	elif _current_match_index < 0 or _current_match_index >= _matches.size():
		_current_match_index = 0

	_update_search_controls(query)

	_document_body.clear()
	_document_body.push_paragraph(HORIZONTAL_ALIGNMENT_LEFT)

	var lines := _current_raw_text.split("\n")
	for paragraph in range(lines.size()):
		if paragraph > 0:
			_document_body.newline()
		_render_line(str(lines[paragraph]), paragraph)

	_document_body.pop_all()

	if preserve_scroll:
		call_deferred("_restore_scroll_position", scroll_value, render_token)
	else:
		call_deferred("_jump_to_paragraph", 0, render_token)


func _render_line(line: String, paragraph: int) -> void:
	var trimmed := line.strip_edges()
	var heading_level := _get_heading_level(trimmed)
	var color := BODY_COLOR
	var font_size := 0
	var display_line := line

	if heading_level > 0:
		display_line = trimmed.substr(heading_level + 1).strip_edges()
		color = Color(0.94, 0.97, 1.0)
		font_size = 24 if heading_level == 1 else 18 if heading_level == 2 else 15
	elif trimmed.begins_with("> "):
		display_line = line.replace("> ", "")
		color = MUTED_COLOR
	elif trimmed.begins_with("* ") or trimmed.begins_with("- "):
		display_line = "  • " + trimmed.substr(2)
	elif trimmed.begins_with("```"):
		color = MUTED_COLOR

	var line_matches := _matches_for_paragraph(paragraph)
	_document_body.push_color(color)
	if font_size > 0:
		_document_body.push_font_size(font_size)

	if line_matches.is_empty():
		_document_body.add_text(display_line)
	else:
		_append_line_with_highlights(display_line, line, line_matches)

	if font_size > 0:
		_document_body.pop()
	_document_body.pop()


func _append_line_with_highlights(display_line: String, raw_line: String, line_matches: Array[Dictionary]) -> void:
	var offset := raw_line.find(display_line)
	if offset < 0:
		offset = 0

	var cursor := 0
	for match_record in line_matches:
		var start := int(match_record["start"]) - offset
		var end := int(match_record["end"]) - offset
		if end <= 0 or start >= display_line.length():
			continue

		start = maxi(start, 0)
		end = mini(end, display_line.length())
		if start > cursor:
			_document_body.add_text(display_line.substr(cursor, start - cursor))

		var is_current := int(match_record["index"]) == _current_match_index
		_document_body.push_bgcolor(CURRENT_HIGHLIGHT_BG if is_current else HIGHLIGHT_BG)
		_document_body.push_color(HIGHLIGHT_FG)
		_document_body.add_text(display_line.substr(start, end - start))
		_document_body.pop()
		_document_body.pop()
		cursor = end

	if cursor < display_line.length():
		_document_body.add_text(display_line.substr(cursor))


func _collect_matches(query: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var normalized_query := _normalize_query(query)
	if normalized_query.is_empty():
		return results

	var lines := _current_raw_text.split("\n")
	for paragraph in range(lines.size()):
		var line := str(lines[paragraph])
		var normalized := _normalize_line_with_map(line)
		var normalized_text := str(normalized["text"])
		var starts: Array[int] = normalized["starts"]
		var ends: Array[int] = normalized["ends"]
		var cursor := 0

		while true:
			var found := normalized_text.find(normalized_query, cursor)
			if found == -1:
				break

			results.append({
				"index": results.size(),
				"paragraph": paragraph,
				"start": starts[found],
				"end": ends[found + normalized_query.length() - 1],
			})
			cursor = found + normalized_query.length()

	return results


func _normalize_line_with_map(line: String) -> Dictionary:
	var normalized := ""
	var starts: Array[int] = []
	var ends: Array[int] = []

	for index in range(line.length()):
		var character := line.substr(index, 1)
		if SEARCH_CHARS_TO_IGNORE.contains(character):
			continue
		normalized += character.to_lower()
		starts.append(index)
		ends.append(index + 1)

	return {
		"text": normalized,
		"starts": starts,
		"ends": ends,
	}


func _normalize_query(query: String) -> String:
	var normalized := ""
	for index in range(query.length()):
		var character := query.substr(index, 1)
		if SEARCH_CHARS_TO_IGNORE.contains(character):
			continue
		normalized += character.to_lower()
	return normalized.strip_edges()


func _matches_for_paragraph(paragraph: int) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for match_record in _matches:
		if int(match_record["paragraph"]) == paragraph:
			results.append(match_record)
	return results


func _update_search_controls(query: String) -> void:
	var has_matches := not _matches.is_empty()
	_prev_button.disabled = not has_matches
	_next_button.disabled = not has_matches

	if query.is_empty():
		_search_count.text = "全文表示"
	elif has_matches:
		_search_count.text = "%d / %d 件ヒット" % [_current_match_index + 1, _matches.size()]
	else:
		_search_count.text = "0 件ヒット"


func _on_search_changed(_new_text: String) -> void:
	_render_document(true)
	if not _matches.is_empty():
		_scroll_to_current_match()


func _on_prev_pressed() -> void:
	if _matches.is_empty():
		return
	_current_match_index = (_current_match_index - 1 + _matches.size()) % _matches.size()
	_render_document(true)
	_scroll_to_current_match()


func _on_next_pressed() -> void:
	if _matches.is_empty():
		return
	_current_match_index = (_current_match_index + 1) % _matches.size()
	_render_document(true)
	_scroll_to_current_match()


func _on_quick_search_pressed(term: String) -> void:
	_search_input.text = term
	_search_input.caret_column = term.length()
	_search_input.grab_focus()
	_on_search_changed(term)


func _on_toc_toggle_pressed() -> void:
	_toc_user_visible = not _toc_user_visible
	_on_window_resized()


func _scroll_to_current_match() -> void:
	if _current_match_index < 0 or _current_match_index >= _matches.size():
		return
	_jump_to_paragraph(int(_matches[_current_match_index]["paragraph"]))


func _jump_to_paragraph(paragraph: int, render_token: int = -1) -> void:
	if render_token != -1 and render_token != _render_generation:
		return
	_document_body.scroll_to_paragraph(paragraph)


func _restore_scroll_position(value: float, render_token: int) -> void:
	if render_token != _render_generation:
		return
	_document_body.get_v_scroll_bar().value = value


func _on_window_resized() -> void:
	if not is_node_ready():
		return

	var width := size.x
	if width <= 1.0:
		width = get_viewport().get_visible_rect().size.x

	var mobile := width < MOBILE_WIDTH
	var compact_toc := width < COMPACT_TOC_WIDTH
	_sidebar.visible = not mobile
	_ops_panel.visible = not mobile
	_doc_selector.visible = mobile
	_toc_panel.visible = _toc_user_visible and not compact_toc and not _heading_records.is_empty()
	_toc_toggle_button.text = "目次を隠す" if _toc_panel.visible else "目次を表示"


func _on_state_changed() -> void:
	if not is_inside_tree():
		return

	_cred_val.text = str(state.credibility)
	_contam_val.text = str(state.reality_contamination)
	_debt_val.text = str(state.audit_debt)
	_comp_val.text = str(state.complicity_clock)
	_wear_val.text = str(state.equipment_wear)

	if _comp_desc_label:
		var doc_title: String = DOCUMENTS[_current_doc_index]["title"]
		if doc_title == "シナリオ EP2":
			var stages := [
				"未招集",
				"資料提出依頼",
				"医療記録照会",
				"証言整理",
				"争点限定",
				"報告書案作成",
				"最終報告書確定"
			]
			var idx := clampi(state.complicity_clock, 0, 6)
			_comp_desc_label.text = "進捗: %s" % stages[idx]
			_comp_desc_label.visible = true
		elif doc_title == "シナリオ EP3":
			var stages := [
				"未分類",
				"資料整理中",
				"仮分類完了",
				"展示名確定",
				"個人名削除",
				"解説文確定",
				"文化財化完了"
			]
			var idx := clampi(state.complicity_clock, 0, 6)
			_comp_desc_label.text = "進捗: %s" % stages[idx]
			_comp_desc_label.visible = true
		else:
			_comp_desc_label.visible = false

	for index in range(_phase_buttons.size()):
		_phase_buttons[index].button_pressed = state.current_phase == index + 1

	var warnings: Array[String] = state.get_warnings()
	if warnings.is_empty():
		_warnings_label.text = ""
		_warnings_label.visible = false
	else:
		_warnings_label.text = "\n".join(warnings)
		_warnings_label.visible = true

	_rebuild_card_list()


func _on_phase_pressed(phase: int) -> void:
	state.current_phase = phase


func _on_undo_pressed() -> void:
	state.undo()


func _open_card_form(type: String) -> void:
	_current_form_type = type
	_card_form_panel.visible = true
	_input_title.clear()
	_input_fact.clear()
	_input_cost.clear()
	_input_constraint.clear()
	_input_owner.clear()

	_input_cost.visible = true
	_input_constraint.visible = true
	_input_owner.visible = true

	match type:
		"white":
			_form_title.text = "白カード（公式ログ）追加"
			_input_title.placeholder_text = "題名 / タイトル"
			_input_fact.placeholder_text = "公式事実 (内容)"
			_input_cost.placeholder_text = "隠された代償"
			_input_constraint.placeholder_text = "次回への檻 (前提条件)"
			_input_owner.placeholder_text = "担当PC"
		"gray":
			_form_title.text = "灰カード（未処理の矛盾）追加"
			_input_title.placeholder_text = "題名 / タイトル"
			_input_fact.placeholder_text = "矛盾点 (内容)"
			_input_cost.visible = false
			_input_constraint.visible = false
			_input_owner.placeholder_text = "発見PC"
		"black":
			_form_title.text = "黒カード（封印された真実）追加"
			_input_title.placeholder_text = "題名 / タイトル"
			_input_fact.placeholder_text = "裏の真実 (内容)"
			_input_cost.placeholder_text = "物証・証拠"
			_input_constraint.placeholder_text = "対立する白カード名"
			_input_owner.placeholder_text = "記録PC"
		"rough":
			_form_title.text = "粗い演出カード追加"
			_input_title.placeholder_text = "題名 / タイトル"
			_input_fact.placeholder_text = "粗雑な処置 (内容)"
			_input_cost.placeholder_text = "将来のリスク・弱点"
			_input_constraint.visible = false
			_input_owner.placeholder_text = "責任PC"


func _on_form_submit() -> void:
	var title := _input_title.text.strip_edges()
	var fact := _input_fact.text.strip_edges()
	var cost := _input_cost.text.strip_edges()
	var constraint := _input_constraint.text.strip_edges()
	var owner := _input_owner.text.strip_edges()

	if title.is_empty():
		return

	match _current_form_type:
		"white":
			state.add_white_card(title, fact, cost, constraint, owner)
		"gray":
			state.add_gray_card(title, fact, 0, owner)
		"black":
			state.add_black_card(title, fact, cost, constraint, owner)
		"rough":
			state.add_rough_card(title, fact, owner, cost)

	_card_form_panel.visible = false
	# スクロールを最下部へ移動して新カードを即座に表示する
	await get_tree().process_frame
	var scroll := _card_list_container.get_parent() as ScrollContainer
	if scroll:
		scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value


func _on_export_pressed() -> void:
	var markdown_log: String = state.export_to_markdown()
	DisplayServer.clipboard_set(markdown_log)
	
	var file := FileAccess.open("user://session_log.md", FileAccess.WRITE)
	if file != null:
		file.store_string(markdown_log)
		file.close()
		_show_temporary_message("✅ ログをクリップボードと user://session_log.md に保存しました。")
	else:
		_show_temporary_message("❌ Markdown保存エラー: " + error_string(FileAccess.get_open_error()))


func _on_save_pressed() -> void:
	var err: Error = state.save_to_file("user://session_log.json")
	if err == OK:
		_show_temporary_message("✅ セッションを保存しました。")
	else:
		_show_temporary_message("❌ 保存エラー: " + error_string(err))


func _on_load_pressed() -> void:
	var err: Error = state.load_from_file("user://session_log.json")
	if err == OK:
		_show_temporary_message("✅ セッションを読み込みました。")
	else:
		_show_temporary_message("❌ 読込エラー: " + error_string(err))


var _msg_generation := 0

func _show_temporary_message(msg: String) -> void:
	_msg_generation += 1
	var my_gen := _msg_generation
	var original_text := _warnings_label.text
	var original_visible := _warnings_label.visible
	_warnings_label.text = msg
	_warnings_label.visible = true
	await get_tree().create_timer(2.0).timeout

	# 自分のメッセージがまだ表示中の世代なら元の状態へ戻す
	if _msg_generation == my_gen:
		_warnings_label.text = original_text
		_warnings_label.visible = original_visible


func _rebuild_card_list() -> void:
	for child in _card_list_container.get_children():
		child.queue_free()

	for index in range(state.white_cards.size()):
		var card: Dictionary = state.white_cards[index]
		_create_card_ui_node("white", index, str(card["title"]), str(card["official_fact"]), "担当: %s / Phase %d" % [card["owner"], card["phase"]])

	for index in range(state.gray_cards.size()):
		var card: Dictionary = state.gray_cards[index]
		var rot_str := "違和感"
		if int(card["rot_stage"]) == 1:
			rot_str = "ノイズ"
		elif int(card["rot_stage"]) == 2:
			rot_str = "強制発火"

		var desc := "矛盾: %s (発見: %s / Phase %d)" % [card["contradiction"], card["owner"], card["phase"]]
		_create_card_ui_node("gray", index, str(card["title"]), desc, "腐爛: %d (%s)" % [card["rot_stage"], rot_str])

	for index in range(state.black_cards.size()):
		var card: Dictionary = state.black_cards[index]
		var desc := "真実: %s\n証拠: %s\n対立白: %s" % [card["sealed_truth"], card["evidence"], card["linked_white_card"]]
		_create_card_ui_node("black", index, str(card["title"]), desc, "記録: %s / Phase %d" % [card["owner"], card["phase"]])

	for index in range(state.rough_cards.size()):
		var card: Dictionary = state.rough_cards[index]
		var desc := "処置: %s\nリスク: %s" % [card["what_was_sloppy"], card["future_risk"]]
		_create_card_ui_node("rough", index, str(card["title"]), desc, "責任: %s / Phase %d" % [card["responsible_pc"], card["phase"]])


func _create_card_ui_node(type: String, index: int, title: String, content: String, meta: String) -> void:
	var panel := PanelContainer.new()
	
	# Visibility enhancement for cards using StyleBoxFlat left-border
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.12, 0.13, 0.15)
	style_box.border_width_left = 4
	style_box.content_margin_left = 6
	style_box.content_margin_top = 6
	style_box.content_margin_right = 6
	style_box.content_margin_bottom = 6
	
	match type:
		"white":
			style_box.border_color = Color.WHITE
		"gray":
			style_box.border_color = Color(0.6, 0.6, 0.6)
		"black":
			style_box.border_color = Color(0.9, 0.3, 0.3)
		"rough":
			style_box.border_color = Color(0.9, 0.6, 0.2)
	
	panel.add_theme_stylebox_override("panel", style_box)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 6)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)

	var header := HBoxContainer.new()
	var type_label := Label.new()
	type_label.add_theme_font_size_override("font_size", 11)
	match type:
		"white":
			type_label.text = "[白] "
			type_label.add_theme_color_override("font_color", Color.WHITE)
		"gray":
			type_label.text = "[灰] "
			type_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		"black":
			type_label.text = "[黒] "
			type_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		"rough":
			type_label.text = "[粗] "
			type_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))
	header.add_child(type_label)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 12)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)

	var delete_button := Button.new()
	delete_button.text = "×"
	delete_button.flat = true
	delete_button.pressed.connect(func(): state.remove_card(type, index))
	header.add_child(delete_button)
	rows.add_child(header)

	if not content.is_empty():
		var content_label := Label.new()
		content_label.text = content
		content_label.add_theme_font_size_override("font_size", 10)
		content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rows.add_child(content_label)

	var meta_row := HBoxContainer.new()
	var meta_label := Label.new()
	meta_label.text = meta
	meta_label.add_theme_font_size_override("font_size", 9)
	meta_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	meta_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_row.add_child(meta_label)

	if type == "gray":
		var rot_dec := Button.new()
		rot_dec.text = " -"
		rot_dec.flat = true
		rot_dec.add_theme_font_size_override("font_size", 9)
		rot_dec.pressed.connect(func(): state.update_gray_rot(index, int(state.gray_cards[index]["rot_stage"]) - 1))
		meta_row.add_child(rot_dec)

		var rot_inc := Button.new()
		rot_inc.text = "+ "
		rot_inc.flat = true
		rot_inc.add_theme_font_size_override("font_size", 9)
		rot_inc.pressed.connect(func(): state.update_gray_rot(index, int(state.gray_cards[index]["rot_stage"]) + 1))
		meta_row.add_child(rot_inc)

	rows.add_child(meta_row)
	margin.add_child(rows)
	panel.add_child(margin)
	_card_list_container.add_child(panel)


func _get_heading_level(line: String) -> int:
	if line.begins_with("### "):
		return 3
	if line.begins_with("## "):
		return 2
	if line.begins_with("# "):
		return 1
	return 0


func _heading_prefix(level: int) -> String:
	match level:
		1:
			return "●"
		2:
			return "  •"
		3:
			return "    ▪"
		_:
			return "•"


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "Document not found: %s" % path

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "Could not open document: %s\n%s" % [path, error_string(FileAccess.get_open_error())]

	return file.get_as_text().replace("\r\n", "\n").replace("\r", "\n")


func _setup_tabletop_p1_features() -> void:
	var ops_rows := _ops_panel.get_node("OpsMargin/OpsRows") as VBoxContainer
	if not ops_rows:
		return

	# Separator
	var sep := HSeparator.new()
	ops_rows.add_child(sep)

	# Complicity clock status description label
	_comp_desc_label = Label.new()
	_comp_desc_label.add_theme_font_size_override("font_size", 12)
	_comp_desc_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	_comp_desc_label.visible = false
	ops_rows.add_child(_comp_desc_label)

	# Stagnation button
	var stagnant_btn := Button.new()
	stagnant_btn.text = "⚠️ 議論停滞：処理クロック+1"
	stagnant_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	stagnant_btn.pressed.connect(func():
		state.complicity_clock = int(state.complicity_clock) + 1
		_show_temporary_message("⚠️ 議論停滞により、処理クロックが進行しました。")
	)
	ops_rows.add_child(stagnant_btn)

	# Guidelines Toggle Button
	var guidelines_btn := Button.new()
	guidelines_btn.text = "表現調整ガイドライン 表示"
	guidelines_btn.toggle_mode = true
	ops_rows.add_child(guidelines_btn)

	# Guidelines Panel
	var guidelines_panel := PanelContainer.new()
	guidelines_panel.visible = false
	
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.12, 0.13, 0.15)
	style_box.border_width_left = 4
	style_box.border_color = Color(1.0, 0.84, 0.0) # Yellow edge
	style_box.content_margin_left = 8
	style_box.content_margin_top = 8
	style_box.content_margin_right = 8
	style_box.content_margin_bottom = 8
	guidelines_panel.add_theme_stylebox_override("panel", style_box)
	
	var guidelines_text := RichTextLabel.new()
	guidelines_text.bbcode_enabled = true
	guidelines_text.fit_content = true
	guidelines_text.text = (
		"[b][color=#ffd700]表現調整ガイドライン[/color][/b]\n" +
		"[color=#a0a0a0]禁止語 ➔ 推奨代替語[/color]\n" +
		"・[color=#ff6b6b]災害[/color] ➔ 地域記憶\n" +
		"・[color=#ff6b6b]人災[/color] ➔ 歴史的経緯\n" +
		"・[color=#ff6b6b]避難経路[/color] ➔ 祈りの道筋\n" +
		"・[color=#ff6b6b]補償[/color] ➔ 生活再建支援\n" +
		"・[color=#ff6b6b]抹消[/color] ➔ 記録不備\n" +
		"・[color=#ff6b6b]隠蔽[/color] ➔ 表現調整\n" +
		"・[color=#ff6b6b]責任[/color] ➔ 関係性\n" +
		"・[color=#ff6b6b]実験[/color] ➔ 誘導検証\n" +
		"・[color=#ff6b6b]失踪者[/color] ➔ 帳外対象者\n" +
		"・[color=#ff6b6b]告発[/color] ➔ 問題提起"
	)
	
	guidelines_panel.add_child(guidelines_text)
	ops_rows.add_child(guidelines_panel)

	guidelines_btn.toggled.connect(func(button_pressed: bool):
		guidelines_panel.visible = button_pressed
		guidelines_btn.text = "表現調整ガイドライン 非表示" if button_pressed else "表現調整ガイドライン 表示"
	)
