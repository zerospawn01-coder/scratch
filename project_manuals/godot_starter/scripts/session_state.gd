extends RefCounted
class_name SessionState

signal state_changed

var credibility: int = 3:
	set(val):
		if not _is_undoing:
			_save_history()
		credibility = clamp(val, 0, 6)
		state_changed.emit()

var reality_contamination: int = 1:
	set(val):
		if not _is_undoing:
			_save_history()
		reality_contamination = clamp(val, 0, 6)
		state_changed.emit()

var audit_debt: int = 0:
	set(val):
		if not _is_undoing:
			_save_history()
		audit_debt = clamp(val, 0, 6)
		state_changed.emit()

var complicity_clock: int = 0:
	set(val):
		if not _is_undoing:
			_save_history()
		complicity_clock = clamp(val, 0, 6)
		state_changed.emit()

var equipment_wear: int = 0:
	set(val):
		if not _is_undoing:
			_save_history()
		equipment_wear = clamp(val, 0, 6)
		state_changed.emit()

var current_phase: int = 1:
	set(val):
		if not _is_undoing:
			_save_history()
		current_phase = clamp(val, 1, 5)
		state_changed.emit()

var white_cards: Array[Dictionary] = []
var gray_cards: Array[Dictionary] = []
var black_cards: Array[Dictionary] = []
var rough_cards: Array[Dictionary] = []

var _history: Array[Dictionary] = []
var _is_undoing := false

func _save_history() -> void:
	var snapshot := {
		"credibility": credibility,
		"reality_contamination": reality_contamination,
		"audit_debt": audit_debt,
		"complicity_clock": complicity_clock,
		"equipment_wear": equipment_wear,
		"current_phase": current_phase,
		"white_cards": white_cards.duplicate(true),
		"gray_cards": gray_cards.duplicate(true),
		"black_cards": black_cards.duplicate(true),
		"rough_cards": rough_cards.duplicate(true)
	}
	_history.append(snapshot)
	if _history.size() > 20:
		_history.remove_at(0)

func undo() -> bool:
	if _history.is_empty():
		return false
	
	_is_undoing = true
	var snapshot: Dictionary = _history.pop_back()
	
	# Setting variables directly triggers setters, but _is_undoing blocks _save_history
	credibility = snapshot["credibility"]
	reality_contamination = snapshot["reality_contamination"]
	audit_debt = snapshot["audit_debt"]
	complicity_clock = snapshot["complicity_clock"]
	equipment_wear = snapshot["equipment_wear"]
	current_phase = snapshot["current_phase"]
	white_cards = snapshot["white_cards"]
	gray_cards = snapshot["gray_cards"]
	black_cards = snapshot["black_cards"]
	rough_cards = snapshot["rough_cards"]
	
	_is_undoing = false
	state_changed.emit()
	return true

func add_white_card(title: String, official_fact: String, hidden_cost: String, next_constraint: String, owner: String) -> void:
	_save_history()
	white_cards.append({
		"title": title,
		"official_fact": official_fact,
		"hidden_cost": hidden_cost,
		"next_constraint": next_constraint,
		"owner": owner,
		"phase": current_phase
	})
	state_changed.emit()

func add_gray_card(title: String, contradiction: String, rot_stage: int, owner: String) -> void:
	_save_history()
	gray_cards.append({
		"title": title,
		"contradiction": contradiction,
		"rot_stage": clamp(rot_stage, 0, 2),
		"owner": owner,
		"phase": current_phase
	})
	state_changed.emit()

func add_black_card(title: String, sealed_truth: String, evidence: String, linked_white_card: String, owner: String) -> void:
	_save_history()
	black_cards.append({
		"title": title,
		"sealed_truth": sealed_truth,
		"evidence": evidence,
		"linked_white_card": linked_white_card,
		"owner": owner,
		"phase": current_phase
	})
	state_changed.emit()

func add_rough_card(title: String, what_was_sloppy: String, responsible_pc: String, future_risk: String) -> void:
	_save_history()
	rough_cards.append({
		"title": title,
		"what_was_sloppy": what_was_sloppy,
		"responsible_pc": responsible_pc,
		"future_risk": future_risk,
		"phase": current_phase
	})
	state_changed.emit()

func remove_card(type: String, index: int) -> void:
	_save_history()
	match type:
		"white": white_cards.remove_at(index)
		"gray": gray_cards.remove_at(index)
		"black": black_cards.remove_at(index)
		"rough": rough_cards.remove_at(index)
	state_changed.emit()

func update_gray_rot(index: int, new_rot: int) -> void:
	_save_history()
	gray_cards[index]["rot_stage"] = clamp(new_rot, 0, 2)
	state_changed.emit()

func get_warnings() -> Array[String]:
	var warnings: Array[String] = []
	if reality_contamination >= 5:
		warnings.append("⚠️ 【現実混入率警告】現実の惨劇が演習に混入しています！保安局長がパニックを起こし、通報リスクが最大化しています。")
	if complicity_clock >= 3:
		warnings.append("⚠️ 【共犯クロック警告】オーディターの信用が失墜しています。Witness Claim（真実の刻印）の実行に追加コスト（予算1）が必要になります。")
	if equipment_wear >= 3:
		warnings.append("⚠️ 【機材劣化警告】特効機材の限界です！次のアクションで強制発火（現実混入率+1、または粗い演出の灰カード化）が起きます。")
	if credibility <= 0:
		warnings.append("🚨 【信憑性崩壊】演出の信憑性が完全に失われました！アルコン・シミュレーションズは社会的抹殺（即時敗北）を迎えます。")
	return warnings

func export_to_markdown() -> String:
	var md = ""
	md += "# CRISIS ACTOR - セッション記録\n"
	md += "※本ログは CRISIS ACTOR 卓上運用ツールによって自動生成されました。\n\n"
	md += "## ■ 最終セッションパラメータ\n"
	md += "- **信憑性**: %d/6\n" % credibility
	md += "- **現実混入率**: %d/6\n" % reality_contamination
	md += "- **監査負債**: %d/6\n" % audit_debt
	md += "- **共犯クロック**: %d/6\n" % complicity_clock
	md += "- **機材劣化**: %d/6\n\n" % equipment_wear
	
	md += "## ■ 固定された白カード（公式ログ） [%d]\n" % white_cards.size()
	for i in range(white_cards.size()):
		var c = white_cards[i]
		md += "### %d. %s (担当PC: %s / Phase %d)\n" % [i + 1, c["title"], c["owner"], c["phase"]]
		md += "- **公式事実**: %s\n" % c["official_fact"]
		md += "- **隠された代償**: %s\n" % c["hidden_cost"]
		md += "- **次回への檻（前提条件）**: %s\n\n" % c["next_constraint"]
		
	md += "## ■ 残存する灰カード（未処理の矛盾） [%d]\n" % gray_cards.size()
	for i in range(gray_cards.size()):
		var c = gray_cards[i]
		var rot_str = "0 (違和感)"
		if c["rot_stage"] == 1: rot_str = "1 (ノイズ混入)"
		elif c["rot_stage"] == 2: rot_str = "2 (強制発火)"
		md += "### %d. %s (担当PC: %s / Phase %d) — 腐爛: %s\n" % [i + 1, c["title"], c["owner"], c["phase"], rot_str]
		md += "- **矛盾点**: %s\n\n" % c["contradiction"]

	md += "## ■ 封印された黒カード（裏の真実） [%d]\n" % black_cards.size()
	for i in range(black_cards.size()):
		var c = black_cards[i]
		md += "### %d. %s (担当PC: %s / Phase %d)\n" % [i + 1, c["title"], c["owner"], c["phase"]]
		md += "- **裏の真実**: %s\n" % c["sealed_truth"]
		md += "- **物証・証拠**: %s\n" % c["evidence"]
		md += "- **対立・無力化対象（白カード）**: %s\n\n" % c["linked_white_card"]

	md += "## ■ 粗い演出カード（B級処理の責任） [%d]\n" % rough_cards.size()
	for i in range(rough_cards.size()):
		var c = rough_cards[i]
		md += "### %d. %s (責任PC: %s / Phase %d)\n" % [i + 1, c["title"], c["responsible_pc"], c["phase"]]
		md += "- **粗雑な処置**: %s\n" % c["what_was_sloppy"]
		md += "- **将来の弱点・リスク**: %s\n\n" % c["future_risk"]
		
	return md


func to_dict() -> Dictionary:
	return {
		"credibility": credibility,
		"reality_contamination": reality_contamination,
		"audit_debt": audit_debt,
		"complicity_clock": complicity_clock,
		"equipment_wear": equipment_wear,
		"current_phase": current_phase,
		"white_cards": white_cards.duplicate(true),
		"gray_cards": gray_cards.duplicate(true),
		"black_cards": black_cards.duplicate(true),
		"rough_cards": rough_cards.duplicate(true)
	}


func from_dict(dict: Dictionary) -> void:
	_is_undoing = true
	if dict.has("credibility"): credibility = int(dict["credibility"])
	if dict.has("reality_contamination"): reality_contamination = int(dict["reality_contamination"])
	if dict.has("audit_debt"): audit_debt = int(dict["audit_debt"])
	if dict.has("complicity_clock"): complicity_clock = int(dict["complicity_clock"])
	if dict.has("equipment_wear"): equipment_wear = int(dict["equipment_wear"])
	if dict.has("current_phase"): current_phase = int(dict["current_phase"])
	
	if dict.has("white_cards"):
		white_cards.clear()
		for card in dict["white_cards"]:
			white_cards.append(card)
	if dict.has("gray_cards"):
		gray_cards.clear()
		for card in dict["gray_cards"]:
			gray_cards.append(card)
	if dict.has("black_cards"):
		black_cards.clear()
		for card in dict["black_cards"]:
			black_cards.append(card)
	if dict.has("rough_cards"):
		rough_cards.clear()
		for card in dict["rough_cards"]:
			rough_cards.append(card)
			
	_is_undoing = false
	state_changed.emit()


func save_to_file(path: String) -> Error:
	var data := to_dict()
	var json_string := JSON.stringify(data, "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(json_string)
	file.close()
	return OK


func load_from_file(path: String) -> Error:
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var err := json.parse(json_string)
	if err != OK:
		return err
		
	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		return ERR_INVALID_DATA
		
	_save_history()
	from_dict(data)
	return OK
