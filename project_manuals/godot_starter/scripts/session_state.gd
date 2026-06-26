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

var unprocessed_debt: int = 0:
	set(val):
		if not _is_undoing:
			_save_history()
		unprocessed_debt = clamp(val, 0, 10)
		state_changed.emit()

var white_cards: Array[Dictionary] = []
var gray_cards: Array[Dictionary] = []
var black_cards: Array[Dictionary] = []
var rough_cards: Array[Dictionary] = []
var dominant_white_cards: Array[Dictionary] = []
var investigation_cards: Array[Dictionary] = []
var suspicion_cards: Array[Dictionary] = []
var protected_cards: Array[Dictionary] = []
var classification_cards: Array[Dictionary] = []
var audit_events: Array[Dictionary] = []

var safety_checks_used: int = 0:
	set(val):
		if not _is_undoing:
			_save_history()
		safety_checks_used = val
		state_changed.emit()

var audit_pauses_used: int = 0:
	set(val):
		if not _is_undoing:
			_save_history()
		audit_pauses_used = val
		state_changed.emit()

var emergency_injunctions_used: int = 0:
	set(val):
		if not _is_undoing:
			_save_history()
		emergency_injunctions_used = val
		state_changed.emit()

var _history: Array[Dictionary] = []
var _is_undoing := false

func log_audit_event(type: String, details: Dictionary) -> void:
	var time_dict := Time.get_time_dict_from_system()
	var timestamp := "%02d:%02d:%02d" % [time_dict["hour"], time_dict["minute"], time_dict["second"]]
	audit_events.append({
		"timestamp": timestamp,
		"type": type,
		"details": details
	})

func _save_history() -> void:
	var snapshot := {
		"credibility": credibility,
		"reality_contamination": reality_contamination,
		"audit_debt": audit_debt,
		"complicity_clock": complicity_clock,
		"equipment_wear": equipment_wear,
		"current_phase": current_phase,
		"unprocessed_debt": unprocessed_debt,
		"safety_checks_used": safety_checks_used,
		"audit_pauses_used": audit_pauses_used,
		"emergency_injunctions_used": emergency_injunctions_used,
		"white_cards": white_cards.duplicate(true),
		"gray_cards": gray_cards.duplicate(true),
		"black_cards": black_cards.duplicate(true),
		"rough_cards": rough_cards.duplicate(true),
		"dominant_white_cards": dominant_white_cards.duplicate(true),
		"investigation_cards": investigation_cards.duplicate(true),
		"suspicion_cards": suspicion_cards.duplicate(true),
		"protected_cards": protected_cards.duplicate(true),
		"classification_cards": classification_cards.duplicate(true),
		"audit_events": audit_events.duplicate(true)
	}
	_history.append(snapshot)
	if _history.size() > 20:
		_history.remove_at(0)

func undo() -> bool:
	if _history.is_empty():
		return false
	
	_is_undoing = true
	var snapshot: Dictionary = _history.pop_back()
	
	credibility = snapshot["credibility"]
	reality_contamination = snapshot["reality_contamination"]
	audit_debt = snapshot["audit_debt"]
	complicity_clock = snapshot["complicity_clock"]
	equipment_wear = snapshot["equipment_wear"]
	current_phase = snapshot["current_phase"]
	unprocessed_debt = snapshot["unprocessed_debt"]
	safety_checks_used = snapshot.get("safety_checks_used", 0)
	audit_pauses_used = snapshot.get("audit_pauses_used", 0)
	emergency_injunctions_used = snapshot.get("emergency_injunctions_used", 0)
	white_cards = snapshot["white_cards"]
	gray_cards = snapshot["gray_cards"]
	black_cards = snapshot["black_cards"]
	rough_cards = snapshot["rough_cards"]
	dominant_white_cards = snapshot["dominant_white_cards"]
	investigation_cards = snapshot["investigation_cards"]
	suspicion_cards = snapshot["suspicion_cards"]
	protected_cards = snapshot["protected_cards"]
	classification_cards = snapshot["classification_cards"]
	audit_events = snapshot.get("audit_events", [])
	
	_is_undoing = false
	log_audit_event("AUDIT_EVENT_REVERTED", {"reason": "undo_triggered"})
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
	log_audit_event("CARD_CREATED", {"type": "white", "title": title, "owner": owner})
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
	log_audit_event("CARD_CREATED", {"type": "gray", "title": title, "owner": owner})
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
	log_audit_event("CARD_CREATED", {"type": "black", "title": title, "owner": owner})
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
	log_audit_event("CARD_CREATED", {"type": "rough", "title": title, "owner": responsible_pc})
	state_changed.emit()

func add_dominant_white_card(title: String, premise: String, effect: String, exposure_risk: String, owner: String) -> void:
	_save_history()
	dominant_white_cards.append({
		"title": title,
		"premise": premise,
		"effect": effect,
		"exposure_risk": exposure_risk,
		"owner": owner,
		"phase": current_phase
	})
	log_audit_event("CARD_CREATED", {"type": "dominant", "title": title, "owner": owner})
	state_changed.emit()

func add_investigation_card(title: String, unresolved_fact: String, protection: String, next_hook: String, owner: String) -> void:
	_save_history()
	investigation_cards.append({
		"title": title,
		"unresolved_fact": unresolved_fact,
		"protection": protection,
		"next_hook": next_hook,
		"owner": owner,
		"phase": current_phase
	})
	log_audit_event("CARD_CREATED", {"type": "investigation", "title": title, "owner": owner})
	state_changed.emit()

func add_suspicion_card(title: String, claim: String, source: String, public_effect: String, owner: String) -> void:
	_save_history()
	suspicion_cards.append({
		"title": title,
		"claim": claim,
		"source": source,
		"public_effect": public_effect,
		"owner": owner,
		"phase": current_phase
	})
	log_audit_event("CARD_CREATED", {"type": "suspicion", "title": title, "owner": owner})
	state_changed.emit()

func add_protected_card(title: String, preserved_item: String, restriction: String, next_agenda: String, owner: String) -> void:
	_save_history()
	protected_cards.append({
		"title": title,
		"preserved_item": preserved_item,
		"restriction": restriction,
		"next_agenda": next_agenda,
		"owner": owner,
		"phase": current_phase
	})
	log_audit_event("CARD_CREATED", {"type": "protected", "title": title, "owner": owner})
	state_changed.emit()

func add_classification_card(title: String, source_info: String, classification: String, rationale: String, owner: String) -> void:
	_save_history()
	classification_cards.append({
		"title": title,
		"source_info": source_info,
		"classification": classification,
		"rationale": rationale,
		"owner": owner,
		"phase": current_phase
	})
	log_audit_event("CARD_CREATED", {"type": "classification", "title": title, "owner": owner})
	state_changed.emit()

func remove_card(type: String, index: int) -> void:
	_save_history()
	var card_title := "名称不明"
	match type:
		"white":
			card_title = white_cards[index].get("title", card_title)
			white_cards.remove_at(index)
		"gray":
			card_title = gray_cards[index].get("title", card_title)
			gray_cards.remove_at(index)
		"black":
			card_title = black_cards[index].get("title", card_title)
			black_cards.remove_at(index)
		"rough":
			card_title = rough_cards[index].get("title", card_title)
			rough_cards.remove_at(index)
		"dominant":
			card_title = dominant_white_cards[index].get("title", card_title)
			dominant_white_cards.remove_at(index)
		"investigation":
			card_title = investigation_cards[index].get("title", card_title)
			investigation_cards.remove_at(index)
		"suspicion":
			card_title = suspicion_cards[index].get("title", card_title)
			suspicion_cards.remove_at(index)
		"protected":
			card_title = protected_cards[index].get("title", card_title)
			protected_cards.remove_at(index)
		"classification":
			card_title = classification_cards[index].get("title", card_title)
			classification_cards.remove_at(index)
	log_audit_event("CARD_DELETED", {"type": type, "title": card_title})
	state_changed.emit()

func convert_card(from_type: String, index: int, to_type: String) -> void:
	_save_history()
	var source_card: Dictionary
	match from_type:
		"white": source_card = white_cards[index]
		"gray": source_card = gray_cards[index]
		"black": source_card = black_cards[index]
		"rough": source_card = rough_cards[index]
		"dominant": source_card = dominant_white_cards[index]
		"investigation": source_card = investigation_cards[index]
		"suspicion": source_card = suspicion_cards[index]
		"protected": source_card = protected_cards[index]
		"classification": source_card = classification_cards[index]
	
	var title: String = source_card.get("title", "名称不明")
	
	# Delete original card
	match from_type:
		"white": white_cards.remove_at(index)
		"gray": gray_cards.remove_at(index)
		"black": black_cards.remove_at(index)
		"rough": rough_cards.remove_at(index)
		"dominant": dominant_white_cards.remove_at(index)
		"investigation": investigation_cards.remove_at(index)
		"suspicion": suspicion_cards.remove_at(index)
		"protected": protected_cards.remove_at(index)
		"classification": classification_cards.remove_at(index)
	
	# Build converted card
	var new_card := {
		"title": title,
		"phase": current_phase
	}
	
	match to_type:
		"white":
			new_card["official_fact"] = source_card.get("contradiction", source_card.get("sealed_truth", source_card.get("what_was_sloppy", source_card.get("claim", "公式事実"))))
			new_card["hidden_cost"] = "変換による代償"
			new_card["next_constraint"] = "変換による次回前提条件"
			new_card["owner"] = source_card.get("owner", source_card.get("responsible_pc", "GM"))
			white_cards.append(new_card)
		"black":
			new_card["sealed_truth"] = source_card.get("contradiction", source_card.get("official_fact", "裏の真実"))
			new_card["evidence"] = "変換による証拠"
			new_card["linked_white_card"] = "対立する白カード名"
			new_card["owner"] = source_card.get("owner", "GM")
			black_cards.append(new_card)
		"investigation":
			new_card["unresolved_fact"] = source_card.get("sealed_truth", source_card.get("contradiction", "未確定事実"))
			new_card["protection"] = "変換による保護理由"
			new_card["next_hook"] = "次回への棘"
			new_card["owner"] = source_card.get("owner", "GM")
			investigation_cards.append(new_card)
		"protected":
			new_card["preserved_item"] = source_card.get("sealed_truth", "保全対象")
			new_card["restriction"] = "一時停止される処理"
			new_card["next_agenda"] = "次フェーズ議題"
			new_card["owner"] = source_card.get("owner", "GM")
			protected_cards.append(new_card)
		"classification":
			new_card["source_info"] = source_card.get("sealed_truth", "分類対象情報")
			new_card["classification"] = "PUBLIC-SAFE"
			new_card["rationale"] = "変換による分類理由"
			new_card["owner"] = source_card.get("owner", "GM")
			classification_cards.append(new_card)
		"gray":
			new_card["contradiction"] = source_card.get("what_was_sloppy", source_card.get("claim", "矛盾点"))
			new_card["rot_stage"] = 0
			new_card["owner"] = source_card.get("responsible_pc", source_card.get("owner", "GM"))
			gray_cards.append(new_card)
	
	log_audit_event("CARD_CONVERTED", {
		"from": from_type,
		"to": to_type,
		"title": title
	})
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
	
	if unprocessed_debt >= 3 and unprocessed_debt <= 4:
		warnings.append("⚠️ 【未処理負債: 圧力】現場が軋み始めています。フェーズ終了時に必ず「ノイズ」が1件発生します。")
	elif unprocessed_debt >= 5 and unprocessed_debt <= 6:
		warnings.append("⚠️ 【未処理負債: 破綻前】演出に明らかな異常。異常混入イベント表から1件発生させます！")
	elif unprocessed_debt >= 7 and unprocessed_debt <= 8:
		warnings.append("🚨 【未処理負債: 破綻】制御不能寸前。場にある灰カード1枚が強制的に「腐爛+1」されます！")
	elif unprocessed_debt >= 9:
		warnings.append("🚨 【未処理負債: 強制クライマックス】防壁崩壊！即座に黒カード露出か現実混入が表面化し、最終解決へ移行します。")
		
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
	md += "- **機材劣化**: %d/6\n" % equipment_wear
	md += "- **未処理負債**: %d/10\n\n" % unprocessed_debt
	
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

	md += "## ■ 支配的白カード（今回の前提） [%d]\n" % dominant_white_cards.size()
	for i in range(dominant_white_cards.size()):
		var c = dominant_white_cards[i]
		md += "### %d. %s (担当PC: %s / Phase %d)\n" % [i + 1, c["title"], c["owner"], c["phase"]]
		md += "- **前提化された公式説明**: %s\n" % c["premise"]
		md += "- **運用効果**: %s\n" % c["effect"]
		md += "- **露出時リスク**: %s\n\n" % c["exposure_risk"]

	md += "## ■ 調査対象カード（保護された未確定事実） [%d]\n" % investigation_cards.size()
	for i in range(investigation_cards.size()):
		var c = investigation_cards[i]
		md += "### %d. %s (担当PC: %s / Phase %d)\n" % [i + 1, c["title"], c["owner"], c["phase"]]
		md += "- **未確定事実**: %s\n" % c["unresolved_fact"]
		md += "- **保護理由**: %s\n" % c["protection"]
		md += "- **次回への棘**: %s\n\n" % c["next_hook"]

	md += "## ■ 疑惑カード（世論ノイズ） [%d]\n" % suspicion_cards.size()
	for i in range(suspicion_cards.size()):
		var c = suspicion_cards[i]
		md += "### %d. %s (発生源: %s / Phase %d)\n" % [i + 1, c["title"], c["source"], c["phase"]]
		md += "- **疑惑の主張**: %s\n" % c["claim"]
		md += "- **世論への影響**: %s\n" % c["public_effect"]
		md += "- **記録者**: %s\n\n" % c["owner"]

	md += "## ■ 保全中カード（Emergency Injunction） [%d]\n" % protected_cards.size()
	for i in range(protected_cards.size()):
		var c = protected_cards[i]
		md += "### %d. %s (保全者: %s / Phase %d)\n" % [i + 1, c["title"], c["owner"], c["phase"]]
		md += "- **保全対象**: %s\n" % c["preserved_item"]
		md += "- **一時停止される処理**: %s\n" % c["restriction"]
		md += "- **次フェーズ議題**: %s\n\n" % c["next_agenda"]

	md += "## ■ 公開区分カード（アーカイブ分類） [%d]\n" % classification_cards.size()
	for i in range(classification_cards.size()):
		var c = classification_cards[i]
		md += "### %d. %s (分類者: %s / Phase %d)\n" % [i + 1, c["title"], c["owner"], c["phase"]]
		md += "- **分類対象情報**: %s\n" % c["source_info"]
		md += "- **公開区分**: %s\n" % c["classification"]
		md += "- **分類理由**: %s\n\n" % c["rationale"]
		
	md += "## ■ 監査ログ履歴 (Audit Log) [%d]\n" % audit_events.size()
	for i in range(audit_events.size()):
		var e = audit_events[i]
		var details_str := ""
		var details_dict: Dictionary = e.get("details", {})
		for key in details_dict.keys():
			details_str += "%s: %s, " % [key, details_dict[key]]
		if details_str.ends_with(", "):
			details_str = details_str.left(details_str.length() - 2)
		md += "- **[%s] %s** — %s\n" % [e["timestamp"], e["type"], details_str]
	md += "\n"
	
	return md


func to_dict() -> Dictionary:
	return {
		"credibility": credibility,
		"reality_contamination": reality_contamination,
		"audit_debt": audit_debt,
		"complicity_clock": complicity_clock,
		"equipment_wear": equipment_wear,
		"current_phase": current_phase,
		"unprocessed_debt": unprocessed_debt,
		"safety_checks_used": safety_checks_used,
		"audit_pauses_used": audit_pauses_used,
		"emergency_injunctions_used": emergency_injunctions_used,
		"white_cards": white_cards.duplicate(true),
		"gray_cards": gray_cards.duplicate(true),
		"black_cards": black_cards.duplicate(true),
		"rough_cards": rough_cards.duplicate(true),
		"dominant_white_cards": dominant_white_cards.duplicate(true),
		"investigation_cards": investigation_cards.duplicate(true),
		"suspicion_cards": suspicion_cards.duplicate(true),
		"protected_cards": protected_cards.duplicate(true),
		"classification_cards": classification_cards.duplicate(true),
		"audit_events": audit_events.duplicate(true)
	}


func from_dict(dict: Dictionary) -> void:
	_is_undoing = true
	if dict.has("credibility"): credibility = int(dict["credibility"])
	if dict.has("reality_contamination"): reality_contamination = int(dict["reality_contamination"])
	if dict.has("audit_debt"): audit_debt = int(dict["audit_debt"])
	if dict.has("complicity_clock"): complicity_clock = int(dict["complicity_clock"])
	if dict.has("equipment_wear"): equipment_wear = int(dict["equipment_wear"])
	if dict.has("current_phase"): current_phase = int(dict["current_phase"])
	if dict.has("unprocessed_debt"): unprocessed_debt = int(dict["unprocessed_debt"])
	safety_checks_used = int(dict.get("safety_checks_used", 0))
	audit_pauses_used = int(dict.get("audit_pauses_used", 0))
	emergency_injunctions_used = int(dict.get("emergency_injunctions_used", 0))

	white_cards.clear()
	gray_cards.clear()
	black_cards.clear()
	rough_cards.clear()
	dominant_white_cards.clear()
	investigation_cards.clear()
	suspicion_cards.clear()
	protected_cards.clear()
	classification_cards.clear()
	audit_events.clear()

	if dict.has("white_cards"):
		for card in dict["white_cards"]:
			white_cards.append(card)
	if dict.has("gray_cards"):
		for card in dict["gray_cards"]:
			gray_cards.append(card)
	if dict.has("black_cards"):
		for card in dict["black_cards"]:
			black_cards.append(card)
	if dict.has("rough_cards"):
		for card in dict["rough_cards"]:
			rough_cards.append(card)
	if dict.has("dominant_white_cards"):
		for card in dict["dominant_white_cards"]:
			dominant_white_cards.append(card)
	if dict.has("investigation_cards"):
		for card in dict["investigation_cards"]:
			investigation_cards.append(card)
	if dict.has("suspicion_cards"):
		for card in dict["suspicion_cards"]:
			suspicion_cards.append(card)
	if dict.has("protected_cards"):
		for card in dict["protected_cards"]:
			protected_cards.append(card)
	if dict.has("classification_cards"):
		for card in dict["classification_cards"]:
			classification_cards.append(card)
	if dict.has("audit_events"):
		for event in dict["audit_events"]:
			audit_events.append(event)
			
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
