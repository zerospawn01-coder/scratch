class_name GeneMixerUI
extends Control

const GeneMixerController = preload("res://scripts/gene_mixer_controller.gd")

# =============================================================================
# 外部監査官 Gene Mixer タクティカル操作ターミナル (Gene Mixer UI)
# 三国比率スライダー・リアルタイム監査プレビュー・台帳ハッシュ記録・アリーナ出撃
# =============================================================================

signal mix_requested(record: Dictionary)
signal deploy_requested(record: Dictionary)

@export var pod_reference: Node3D

var ratio_alden: float = 60.0
var ratio_tsellina: float = 30.0
var ratio_elphadia: float = 10.0
var current_seed: int = 1337

var slider_alden: HSlider
var slider_tsellina: HSlider
var slider_elphadia: HSlider

var lbl_alden_val: Label
var lbl_tsellina_val: Label
var lbl_elphadia_val: Label

var lbl_dominant_preview: Label
var lbl_stats_preview: Label
var lbl_admission_gate: Label
var log_terminal_text: RichTextLabel
var btn_synthesize: Button
var btn_deploy: Button

var latest_synthesized_record: Dictionary = {}

func _ready() -> void:
	_create_ui_components()
	_update_preview()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("action_synthesize"):
		_on_synthesize_pressed()
	elif event.is_action_pressed("action_attack") and not latest_synthesized_record.is_empty():
		_on_deploy_pressed()

func _create_ui_components() -> void:
	# メイン監査パネル
	var main_panel = Panel.new()
	main_panel.name = "AuditorGeneMixerPanel"
	main_panel.position = Vector2(24, 24)
	main_panel.size = Vector2(440, 672)
	add_child(main_panel)

	# ヘッダータイトル
	var title = Label.new()
	title.text = "SOVEREIGN AUDIT // GENE MIXER v1.0\nFACILITY #04: CULTIVATION PROTOCOL"
	title.position = Vector2(16, 14)
	main_panel.add_child(title)

	# -------------------------------------------------------------
	# 1. オルデン比率 (Alden Ratio)
	# -------------------------------------------------------------
	var lbl_a = Label.new()
	lbl_a.text = "[ALDEN] Cybernetic DNA Ratio:"
	lbl_a.position = Vector2(16, 75)
	main_panel.add_child(lbl_a)

	slider_alden = HSlider.new()
	slider_alden.position = Vector2(16, 100); slider_alden.size = Vector2(320, 20)
	slider_alden.min_value = 0; slider_alden.max_value = 100; slider_alden.value = ratio_alden
	slider_alden.value_changed.connect(func(v): _on_slider_changed("alden", v))
	main_panel.add_child(slider_alden)

	lbl_alden_val = Label.new()
	lbl_alden_val.position = Vector2(350, 98); lbl_alden_val.text = "60%"
	main_panel.add_child(lbl_alden_val)

	# -------------------------------------------------------------
	# 2. チェリーナ比率 (Tsellina Ratio)
	# -------------------------------------------------------------
	var lbl_t = Label.new()
	lbl_t.text = "[TSELLINA] Military Frame Ratio:"
	lbl_t.position = Vector2(16, 135)
	main_panel.add_child(lbl_t)

	slider_tsellina = HSlider.new()
	slider_tsellina.position = Vector2(16, 160); slider_tsellina.size = Vector2(320, 20)
	slider_tsellina.min_value = 0; slider_tsellina.max_value = 100; slider_tsellina.value = ratio_tsellina
	slider_tsellina.value_changed.connect(func(v): _on_slider_changed("tsellina", v))
	main_panel.add_child(slider_tsellina)

	lbl_tsellina_val = Label.new()
	lbl_tsellina_val.position = Vector2(350, 158); lbl_tsellina_val.text = "30%"
	main_panel.add_child(lbl_tsellina_val)

	# -------------------------------------------------------------
	# 3. エルファディア比率 (Elphadia Ratio)
	# -------------------------------------------------------------
	var lbl_e = Label.new()
	lbl_e.text = "[ELPHADIA] Bio-Mutation Ratio:"
	lbl_e.position = Vector2(16, 195)
	main_panel.add_child(lbl_e)

	slider_elphadia = HSlider.new()
	slider_elphadia.position = Vector2(16, 220); slider_elphadia.size = Vector2(320, 20)
	slider_elphadia.min_value = 0; slider_elphadia.max_value = 100; slider_elphadia.value = ratio_elphadia
	slider_elphadia.value_changed.connect(func(v): _on_slider_changed("elphadia", v))
	main_panel.add_child(slider_elphadia)

	lbl_elphadia_val = Label.new()
	lbl_elphadia_val.position = Vector2(350, 218); lbl_elphadia_val.text = "10%"
	main_panel.add_child(lbl_elphadia_val)

	# -------------------------------------------------------------
	# 4. リアルタイム監査プレビュー (Audit Predictions)
	# -------------------------------------------------------------
	var pred_box = Panel.new()
	pred_box.position = Vector2(16, 255); pred_box.size = Vector2(408, 140)
	main_panel.add_child(pred_box)

	lbl_dominant_preview = Label.new()
	lbl_dominant_preview.position = Vector2(12, 8)
	pred_box.add_child(lbl_dominant_preview)

	lbl_stats_preview = Label.new()
	lbl_stats_preview.position = Vector2(12, 35)
	pred_box.add_child(lbl_stats_preview)

	lbl_admission_gate = Label.new()
	lbl_admission_gate.position = Vector2(12, 105)
	pred_box.add_child(lbl_admission_gate)

	# -------------------------------------------------------------
	# 5. 合成実行ボタン
	# -------------------------------------------------------------
	btn_synthesize = Button.new()
	btn_synthesize.text = "COMMENCE ADMISSION SYNTHESIS [X]"
	btn_synthesize.position = Vector2(16, 404); btn_synthesize.size = Vector2(408, 38)
	btn_synthesize.pressed.connect(_on_synthesize_pressed)
	main_panel.add_child(btn_synthesize)

	# -------------------------------------------------------------
	# 6. アリーナ出撃ボタン (Deploy Button)
	# -------------------------------------------------------------
	btn_deploy = Button.new()
	btn_deploy.text = "DEPLOY UNIT TO ARENA SIMULATION [Z]"
	btn_deploy.position = Vector2(16, 448); btn_deploy.size = Vector2(408, 38)
	btn_deploy.disabled = true
	btn_deploy.pressed.connect(_on_deploy_pressed)
	main_panel.add_child(btn_deploy)

	# -------------------------------------------------------------
	# 7. 監査台帳ログコンソール (Ledger Terminal Log)
	# -------------------------------------------------------------
	log_terminal_text = RichTextLabel.new()
	log_terminal_text.position = Vector2(16, 496); log_terminal_text.size = Vector2(408, 160)
	log_terminal_text.bbcode_enabled = true
	log_terminal_text.text = "[color=#00e0ff]>>> Sovereign Lockdown Protocol Active.[/color]\n>>> Waiting for Auditor Synthesis Input..."
	main_panel.add_child(log_terminal_text)

func _on_slider_changed(nation: String, val: float) -> void:
	match nation:
		"alden":
			ratio_alden = val
			lbl_alden_val.text = "%d%%" % int(val)
		"tsellina":
			ratio_tsellina = val
			lbl_tsellina_val.text = "%d%%" % int(val)
		"elphadia":
			ratio_elphadia = val
			lbl_elphadia_val.text = "%d%%" % int(val)

	_update_preview()

func _update_preview() -> void:
	var result = GeneMixerController.synthesize({
		"alden": ratio_alden,
		"tsellina": ratio_tsellina,
		"elphadia": ratio_elphadia
	}, current_seed)

	var dom = result.get("dominant_nation", "").to_upper()
	var sec = result.get("secondary_nation", "").to_upper()
	lbl_dominant_preview.text = "FRAME: %s (Base) + %s (Attachment)" % [dom, sec]

	var s = result.get("stats", {})
	lbl_stats_preview.text = "HP: %d | Durability: %.1f | Analysis: %.1f%%\nMutation Risk Index: %.2f%%" % [
		s.get("max_hp", 0), s.get("durability", 0.0), s.get("analysis_efficiency", 0.0), s.get("mutation_rate", 0.0) * 100.0
	]

	var is_anomaly = result.get("admission_gate", {}).get("is_lambda_anomaly", false)
	if is_anomaly:
		lbl_admission_gate.text = "ADMISSION GATE: [!] LAMBDA ANOMALY (RESTRICTED)"
	else:
		lbl_admission_gate.text = "ADMISSION GATE: [OK] COMPLIANT (ADMITTED)"

	# 培養槽へリアルタイムプレビューを反映
	if pod_reference and pod_reference.has_method("apply_synthesis_parameters"):
		pod_reference.call("apply_synthesis_parameters", result)

func _on_synthesize_pressed() -> void:
	current_seed = randi_range(1000, 99999)
	var result = GeneMixerController.synthesize({
		"alden": ratio_alden,
		"tsellina": ratio_tsellina,
		"elphadia": ratio_elphadia
	}, current_seed)

	latest_synthesized_record = result
	btn_deploy.disabled = false

	# BioroidRegistry シングルトンへの公式ペイロード登録
	var reg = get_node_or_null("/root/BioroidRegistry")
	if reg and reg.has_method("register_deployment_payload"):
		var dom = result.get("dominant_nation", "alden")
		var sprite = "res://assets/bioroids/sprites/bio_ald_def001_alden_front.png"
		var is_anomaly = result.get("admission_gate", {}).get("is_lambda_anomaly", false)
		if is_anomaly:
			sprite = "res://assets/bioroids/sprites/subject_af09_lambda_anomaly_front.png"
			
		var stats_data = result.get("stats", {})
		var payload = {
			"run_id": "RUN-" + str(current_seed),
			"bioroid_id": result.get("individual_id", "BIO-SYN-001"),
			"bioroid_name": dom.to_upper(),
			"bioroid_hash": result.get("individual_hash", "0000000000000000"),
			"dna_ratio": {
				"ald": int(ratio_alden),
				"kln": int(ratio_tsellina),
				"chm": int(ratio_elphadia)
			},
			"stats": {
				"vital_integrity": 100,
				"neural_control": int(clamp(stats_data.get("durability", 80.0), 40, 100)),
				"mutation_load": int(clamp(stats_data.get("mutation_rate", 0.1) * 100.0, 5, 95)),
				"core_stress": int(randi_range(25, 45)),
				"atk": int(stats_data.get("max_hp", 100) * 0.25),
				"ep": 60
			},
			"mutation_profile": {
				"surge_risk": "CRITICAL" if is_anomaly else "LOW",
				"instability_rate": stats_data.get("mutation_rate", 0.05)
			},
			"sprite_path": sprite,
			"generated_at": Time.get_datetime_string_from_system()
		}
		reg.call("register_deployment_payload", payload)

	# 監査台帳ログの追記
	var id = result.get("individual_id", "")
	var hash_str = result.get("individual_hash", "")
	var status_str = result.get("admission_gate", {}).get("status", "")
	
	var log_entry = "\n[color=#00ffc8]>> [RECORD SAVED][/color] ID: %s\n   HASH: %s\n   GATE: %s" % [
		id, hash_str, status_str
	]
	log_terminal_text.append_text(log_entry)

	mix_requested.emit(result)

	if pod_reference and pod_reference.has_method("start_synthesis"):
		pod_reference.call("start_synthesis", result)

func _on_deploy_pressed() -> void:
	if latest_synthesized_record.is_empty():
		return

	print("[GeneMixerUI] Deploying Unit %s to Arena Simulation!" % latest_synthesized_record.get("individual_id", ""))
	deploy_requested.emit(latest_synthesized_record)

	# アリーナシーンへの遷移
	if ResourceLoader.exists("res://scenes/arena_battle_scene.tscn"):
		get_tree().change_scene_to_file("res://scenes/arena_battle_scene.tscn")

