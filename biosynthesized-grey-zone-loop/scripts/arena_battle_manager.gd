extends Node

# =============================================================================
# Aether Fountain — Arena Observation & Combat Manager
# Fully dynamic initialization via ArenaDeploymentPayload
# Principle: generation_is_not_authority (audited and recorded in ledger)
# =============================================================================

signal battle_started
signal turn_changed(is_player_turn: bool)
signal combatant_damaged(target: Node3D, damage: int, is_critical: bool)
signal intervention_triggered(action_name: String)
signal battle_ended(player_won: bool, audit_record: Dictionary)

@export var max_ep: float = 100.0
var current_ep: float = 60.0

@export var ally_node: Node3D
@export var enemy_node: Node3D

var deployment_payload: Dictionary = {}
var player_stats: Dictionary = {}
var enemy_stats: Dictionary = {
	"id": "SUBJECT AF-09",
	"name": "LAMBDA ANOMALY",
	"vital_integrity": 100,
	"hostility_index": 88,
	"mutation_surge": true,
	"atk": 28,
	"node": null
}

var is_in_battle: bool = false
var is_player_turn: bool = true
var interventions_log: Array[String] = []
var turn_count: int = 0
var total_damage_taken: int = 0
var combat_seed: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# --- VFX Safety State ---
## Tween caches: kill() before creating new tween to prevent multi-fire corruption
var _attacker_lunge_tween: Tween = null
var _defender_knockback_tween: Tween = null
var _camera_shake_tween: Tween = null
## Hitstop token: prevents competing time_scale restorers from stacking
var _is_hitstopping: bool = false
var _previous_time_scale: float = 1.0
## Particle tracking: count live particles to detect runaway spawning
var _active_particle_count: int = 0
var _max_particles_allowed: int = 12

func _ready() -> void:
	_initialize_from_payload()

func _input(event: InputEvent) -> void:
	if not is_in_battle or not is_player_turn:
		return

	if event.is_action_pressed("action_attack"): # [Z] Nervous Core Suppression
		execute_auditor_intervention("NERVOUS_CORE_SUPPRESSION")
	elif event.is_action_pressed("action_synthesize"): # [X] Gene Discharge Override
		execute_auditor_intervention("GENE_DISCHARGE_OVERRIDE")

var registry_override: Node = null

func _get_registry_node() -> Node:
	if registry_override:
		return registry_override
	if is_inside_tree():
		var tree = get_tree()
		if tree and tree.root:
			var r = tree.root.get_node_or_null("BioroidRegistry")
			if r: return r
	if Engine.get_main_loop():
		var tree = Engine.get_main_loop() as SceneTree
		if tree and tree.root:
			return tree.root.get_node_or_null("BioroidRegistry")
	return null

## 完全動的初期化：BioroidRegistry の Payload を読み込み設定
func _initialize_from_payload() -> void:
	var reg = _get_registry_node()

	if reg and reg.has_method("get_deployment_payload"):
		deployment_payload = reg.call("get_deployment_payload")
	elif deployment_payload.is_empty():
		# Fail-closed fallback only if nothing is registered and payload is unset
		deployment_payload = {
			"run_id": "RUN-FALLBACK-001",
			"bioroid_id": "BIO-ALD-DEF001",
			"bioroid_name": "ALDEN",
			"bioroid_hash": "8f3a04497f2c5e1b98a0d7f214e6b28c",
			"dna_ratio": {"ald": 50, "kln": 30, "chm": 20},
			"stats": {
				"vital_integrity": 100,
				"neural_control": 85,
				"mutation_load": 14,
				"core_stress": 40,
				"atk": 32,
				"ep": 60
			},
			"mutation_profile": {"surge_risk": "LOW", "instability_rate": 0.05},
			"sprite_path": "res://assets/bioroids/sprites/type1_clean_ceramic_front_combat.png"
		}

	var s = deployment_payload.get("stats", {})
	player_stats = {
		"id": deployment_payload.get("bioroid_id", "BIO-SYN-001"),
		"name": deployment_payload.get("bioroid_name", "UNKNOWN"),
		"hash": deployment_payload.get("bioroid_hash", ""),
		"vital_integrity": int(s.get("vital_integrity", 100)),
		"neural_control": int(s.get("neural_control", 85)),
		"mutation_load": int(s.get("mutation_load", 14)),
		"core_stress": int(s.get("core_stress", 40)),
		"atk": int(s.get("atk", 30)),
		"node": null
	}
	current_ep = float(s.get("ep", 60))

	# スプライトの動的差し替え（Payload指定パス）
	if not ally_node:
		ally_node = get_parent().get_node_or_null("AllyBioroid")
	if ally_node:
		player_stats["node"] = ally_node
		var spr = ally_node.get_node_or_null("BioroidSprite") as Sprite3D
		var s_path = deployment_payload.get("sprite_path", "")
		if spr and ResourceLoader.exists(s_path):
			var tex = load(s_path) as Texture2D
			spr.texture = tex

	if not enemy_node:
		enemy_node = get_parent().get_node_or_null("EnemyBioroid")
	if enemy_node:
		enemy_stats["node"] = enemy_node

	# HUD の動的更新
	_update_observation_hud()

	start_arena_combat()

## 観測HUDの動的反映（左5層 / 右4層 / 下部コマンド）
func _update_observation_hud() -> void:
	var canvas = get_parent().get_node_or_null("AuditObservationHUD")
	if not canvas:
		return

	var ui_root = canvas.get_node_or_null("UIRoot")
	if not ui_root:
		return

	# 左パネル：味方バイオロイド
	var lp = ui_root.get_node_or_null("AllyAuditPanel")
	if lp:
		var lp_id = lp.get_node_or_null("Label")
		if not lp_id and lp.get_child_count() > 0:
			lp_id = lp.get_child(0) as Label
		if lp_id:
			lp_id.text = "%s [%s]" % [player_stats["id"], player_stats["name"]]

		var lp_nc = lp.get_node_or_null("Label3")
		if not lp_nc and lp.get_child_count() > 2:
			lp_nc = lp.get_child(2) as Label
		if lp_nc:
			lp_nc.text = "CONTROL: %d%%  |  MUTATION: %d%%" % [player_stats["neural_control"], player_stats["mutation_load"]]

		var nc_bar = lp.get_node_or_null("NeuralControlBar") as ProgressBar
		if nc_bar:
			nc_bar.value = player_stats["neural_control"]

		var lp_vi = lp.get_node_or_null("Label4")
		if not lp_vi and lp.get_child_count() > 4:
			lp_vi = lp.get_child(4) as Label
		if lp_vi:
			lp_vi.text = "CORE: %d%%  |  VITAL: %d%%" % [player_stats["core_stress"], player_stats["vital_integrity"]]

		var vi_bar = lp.get_node_or_null("VitalIntegrityBar") as ProgressBar
		if vi_bar:
			vi_bar.value = player_stats["vital_integrity"]

	# 右パネル：敵性変異体
	var rp = ui_root.get_node_or_null("EnemyAuditPanel")
	if rp:
		var rp_host = rp.get_node_or_null("HostilityBar") as ProgressBar
		if rp_host:
			rp_host.value = enemy_stats["hostility_index"]
		var rp_vi = rp.get_node_or_null("EnemyVitalBar") as ProgressBar
		if rp_vi:
			rp_vi.value = enemy_stats["vital_integrity"]

func start_arena_combat() -> void:
	is_in_battle = true
	is_player_turn = true
	turn_count = 1
	interventions_log.clear()
	total_damage_taken = 0

	# 決定論的戦闘乱数シードの確定
	if deployment_payload.has("combat_seed"):
		combat_seed = int(deployment_payload["combat_seed"])
	elif combat_seed == 0:
		var hash_str = str(player_stats.get("hash", "44291"))
		if hash_str.is_empty():
			hash_str = "44291"
		combat_seed = abs(hash_str.hash())
	rng.seed = combat_seed

	battle_started.emit()
	var hash_short = str(player_stats.get("hash", "")).substr(0, 12)
	print("\n[Arena Combat] === BATTLE INITIATED ===")
	print("  ALLIED UNIT: %s (HASH: %s...)" % [player_stats["id"], hash_short])
	print("  COMBAT SEED: %d" % combat_seed)
	print("  DNA RATIO:   %s" % str(deployment_payload.get("dna_ratio", {})))
	print("  STATS:       Vital=%d, Control=%d, Mutation=%d, Atk=%d" % [
		player_stats["vital_integrity"], player_stats["neural_control"], player_stats["mutation_load"], player_stats["atk"]
	])
	print("  OPPONENT:    %s [%s]" % [enemy_stats["id"], enemy_stats["name"]])
	print("=======================================\n")

## 外部監査官 緊急介入実行
func execute_auditor_intervention(action_name: String) -> void:
	if not is_in_battle or not is_player_turn:
		return

	interventions_log.append(action_name)
	intervention_triggered.emit(action_name)

	match action_name:
		"NERVOUS_CORE_SUPPRESSION":
			# [Z] 神経回路安定化：制御度+15%、変異負荷-8%、敵サージ抑制
			player_stats["neural_control"] = mini(player_stats["neural_control"] + 15, 100)
			player_stats["mutation_load"] = maxi(player_stats["mutation_load"] - 8, 5)
			enemy_stats["hostility_index"] = maxi(enemy_stats["hostility_index"] - 12, 20)
			_apply_attack(player_stats, enemy_stats, 1.2, 0.25)
			print("[Auditor Intervention] [Z] Nervous Core Stabilized. Enemy Surge suppressed.")

		"GENE_DISCHARGE_OVERRIDE":
			# [X] 遺伝子オーバードライブ放出（40 EP消費）
			if current_ep >= 40.0:
				current_ep -= 40.0
				player_stats["core_stress"] = mini(player_stats["core_stress"] + 15, 100)
				_apply_attack(player_stats, enemy_stats, 2.6, 0.45)
				print("[Auditor Intervention] [X] Critical Gene Discharge Override executed!")
			else:
				print("[Auditor Intervention] Insufficient EP for Gene Discharge!")
				return

	_update_observation_hud()

	# 敵ターンへ移行
	is_player_turn = false
	turn_changed.emit(false)
	var tree: SceneTree = null
	if is_inside_tree():
		tree = get_tree()
	elif Engine.get_main_loop():
		tree = Engine.get_main_loop() as SceneTree
	if tree:
		tree.create_timer(0.8).timeout.connect(_execute_enemy_turn)

func _execute_enemy_turn() -> void:
	if not is_in_battle or enemy_stats["vital_integrity"] <= 0:
		return

	turn_count += 1
	var surge_bonus = 1.3 if enemy_stats["mutation_surge"] else 1.0
	_apply_attack(enemy_stats, player_stats, 1.0 * surge_bonus, 0.15)

	_update_observation_hud()

	if player_stats["vital_integrity"] > 0:
		is_player_turn = true
		turn_changed.emit(true)

func _apply_attack(attacker: Dictionary, defender: Dictionary, multiplier: float, crit_rate: float) -> void:
	var is_crit = rng.randf() < crit_rate
	var base_dmg = int(attacker["atk"] * multiplier * rng.randf_range(0.9, 1.15))
	var final_dmg = base_dmg * (2 if is_crit else 1)

	if defender.has("vital_integrity"):
		defender["vital_integrity"] = maxi(defender["vital_integrity"] - final_dmg, 0)
		if defender == player_stats:
			total_damage_taken += final_dmg

	var attacker_node = attacker.get("node") as Node3D
	var defender_node = defender.get("node") as Node3D

	# 1. 攻撃者の踏み込み・突進 Tween (Lunge Animation)
	# 既存Tweenをkill()してから生成 — 連打時の座標破綻を防ぐ
	if attacker_node:
		if _attacker_lunge_tween and _attacker_lunge_tween.is_valid():
			_attacker_lunge_tween.kill()
		var orig_pos = attacker_node.position
		var target_dir = Vector3(1.2, 0, -0.1) if attacker == player_stats else Vector3(-1.2, 0, 0.1)
		_attacker_lunge_tween = attacker_node.create_tween()
		if _attacker_lunge_tween:
			_attacker_lunge_tween.tween_property(attacker_node, "position", orig_pos + target_dir, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_attacker_lunge_tween.tween_property(attacker_node, "position", orig_pos, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	# 2. 被弾者のノックバック & 衝撃シェイク (Impact Knockback)
	# 既存Tweenをkill()してから生成 — 連打時の元位置復帰漏れを防ぐ
	if defender_node:
		if _defender_knockback_tween and _defender_knockback_tween.is_valid():
			_defender_knockback_tween.kill()
		var orig_def_pos = defender_node.position
		var kb_dir = Vector3(0.5, 0.1, 0) if attacker == player_stats else Vector3(-0.5, 0.1, 0)
		_defender_knockback_tween = defender_node.create_tween()
		if _defender_knockback_tween:
			_defender_knockback_tween.tween_property(defender_node, "position", orig_def_pos + kb_dir, 0.08).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			_defender_knockback_tween.tween_property(defender_node, "position", orig_def_pos, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	# 3. 浮遊ダメージポップアップ (Floating 3D Combat Text)
	_spawn_damage_popup(defender_node, final_dmg, is_crit)

	# 4. 生体液/火花飛沫エフェクト (Bio-Fluid & Sparks)
	_spawn_impact_particles(defender_node, attacker == player_stats, is_crit)

	# 5. ヒットストップ & 監視カメラシェイク (Hitstop & Camera Shake)
	_trigger_hitstop_and_shake(is_crit)

	combatant_damaged.emit(defender_node, final_dmg, is_crit)
	print("[Combat] %s -> %s: %d DMG (Crit: %s) | Defender Vital: %d%%" % [
		attacker.get("id", attacker.get("name", "ATTACKER")),
		defender.get("id", defender.get("name", "DEFENDER")),
		final_dmg, is_crit, defender.get("vital_integrity", 0)
	])

	# 決着判定
	if defender["vital_integrity"] <= 0:
		_conclude_battle(attacker == player_stats)

## 3D浮遊ダメージ数値ポップアップ
func _spawn_damage_popup(target: Node3D, dmg: int, is_crit: bool) -> void:
	if not target or not target.get_parent():
		return

	var label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.007 if not is_crit else 0.010
	label.text = "-%d" % dmg if not is_crit else "CRITICAL\n-%d" % dmg
	label.modulate = Color(1.0, 0.85, 0.2) if not is_crit else Color(1.0, 0.15, 0.1)
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
	label.outline_size = 14

	var spawn_pos = target.position + Vector3(randf_range(-0.3, 0.3), 2.2, 0.3)
	label.position = spawn_pos
	target.get_parent().add_child(label)

	var tween = label.create_tween()
	if tween:
		var target_y = spawn_pos.y + (1.2 if is_crit else 0.8)
		tween.tween_property(label, "position:y", target_y, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.2)
		tween.tween_callback(label.queue_free)

## 被弾時の生体フルード・オイル飛沫
func _spawn_impact_particles(target: Node3D, is_enemy_hit: bool, is_crit: bool) -> void:
	if not target or not target.get_parent():
		return

	# 上限チェック：オブジェクト生成より前に行う
	# (オブジェクトを作った後にreturnするとSphereMesh/StandardMaterial3DがGCされずリークする)
	if _active_particle_count >= _max_particles_allowed:
		push_warning("[Arena VFX] Particle cap reached (%d). Skipping spawn." % _max_particles_allowed)
		return

	# ツリーが存在しない環境（headlessテスト等）では描画不可のため即リターン
	# (add_childせずにオブジェクトを作るとRIDリークの原因になる)
	if not target.is_inside_tree():
		return

	var p = CPUParticles3D.new()
	p.position = target.position + Vector3(0, 1.8, 0.1)
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 28 if is_crit else 16
	p.lifetime = 0.45
	p.direction = Vector3(randf_range(-1, 1), randf_range(0.5, 1.5), randf_range(0, 1)).normalized()
	p.spread = 45.0
	p.initial_velocity_min = 3.5 if not is_crit else 6.0
	p.initial_velocity_max = 6.0 if not is_crit else 9.0
	p.gravity = Vector3(0, -9.8, 0)

	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if is_enemy_hit:
		# 敵変異体被弾：暗赤色・琥珀の変異生体フルード
		mat.albedo_color = Color(0.85, 0.05, 0.08) if not is_crit else Color(1.0, 0.45, 0.1)
	else:
		# 味方バイオロイド被弾：ティール・青白の冷却オイル・エーテル飛沫
		mat.albedo_color = Color(0.1, 0.9, 0.85) if not is_crit else Color(0.3, 0.6, 1.0)

	var mesh = SphereMesh.new()
	mesh.radius = 0.04
	mesh.height = 0.08
	mesh.material = mat
	p.mesh = mesh

	_active_particle_count += 1
	target.get_parent().add_child(p)
	p.emitting = true

	# lifetime後に自動解放 — ignore_time_scale=true で実時間タイマーを使う
	target.get_tree().create_timer(0.7, true, false, true).timeout.connect(func():
		_active_particle_count -= 1
		if is_instance_valid(p):
			p.queue_free()
	)

## ヒットストップとカメラシェイク
## Safety: _is_hitstopping token + previous_scale restore でtime_scale漏れを防ぐ
func _trigger_hitstop_and_shake(is_crit: bool) -> void:
	# 既にヒットストップ中なら追加呼び出しを無視する（競合する復帰処理を防ぐ）
	if _is_hitstopping:
		return
	_is_hitstopping = true

	# タイムスケールによるインパクトの一時停止
	# 前回値を保存して必ず復元する（他のシステムがtime_scaleを変えていても安全）
	_previous_time_scale = Engine.time_scale
	Engine.time_scale = 0.05
	var real_duration = 0.06 if not is_crit else 0.14

	var tree: SceneTree = null
	if is_inside_tree():
		tree = get_tree()
	elif Engine.get_main_loop():
		tree = Engine.get_main_loop() as SceneTree
	if tree:
		# ignore_time_scale=true で実時間タイマーを使う（スロー中に待機しない）
		await tree.create_timer(real_duration, true, false, true).timeout
		Engine.time_scale = _previous_time_scale
		_is_hitstopping = false
	else:
		# ツリー外（テスト環境等）では即時復帰
		Engine.time_scale = _previous_time_scale
		_is_hitstopping = false

	# 監視カメラのシェイク（カメラシェイクTweenもキャッシュして多重発火防止）
	var cam = get_parent().get_node_or_null("ObservationCamera") as Camera3D
	if cam:
		if _camera_shake_tween and _camera_shake_tween.is_valid():
			_camera_shake_tween.kill()
		var orig_pos = cam.position
		var orig_rot = cam.rotation_degrees
		var shake_intensity = 0.08 if not is_crit else 0.18
		_camera_shake_tween = cam.create_tween()
		if _camera_shake_tween:
			for i in range(4):
				var offset = Vector3(randf_range(-shake_intensity, shake_intensity), randf_range(-shake_intensity, shake_intensity), 0)
				_camera_shake_tween.tween_property(cam, "position", orig_pos + offset, 0.03)
			_camera_shake_tween.tween_property(cam, "position", orig_pos, 0.04)
			_camera_shake_tween.tween_property(cam, "rotation_degrees", orig_rot, 0.04)

## 戦闘決着＆Sovereign Audit Ledger への正式記録コミット
func _conclude_battle(player_won: bool) -> void:
	is_in_battle = false

	var cause_str = ""
	if player_won:
		cause_str = "TARGET SUPPRESSION SUCCESSFUL — Neural control maintained above threshold"
	else:
		cause_str = "SPECIMEN DESTABILIZED — Excessive mutation load and core collapse"

	var final_status_str = "SUPPRESSED-STABLE" if (player_won and player_stats["mutation_load"] < 40) else ("CONTAINMENT-BREACH" if not player_won else "SURGE-WARNING")

	var audit_record: Dictionary = {
		"run_id": deployment_payload.get("run_id", "RUN-UNKNOWN"),
		"combat_seed": combat_seed,
		"bioroid_id": player_stats["id"],
		"bioroid_hash": player_stats["hash"],
		"dna_ratio": deployment_payload.get("dna_ratio", {}),
		"arena_id": "ARENA-SECTOR-04",
		"opponent_id": enemy_stats["id"],
		"initial_stats": deployment_payload.get("stats", {}),
		"turns_elapsed": turn_count,
		"actions_taken": turn_count,
		"damage_taken": total_damage_taken,
		"intervention_used": interventions_log.duplicate(),
		"result": "SUPPRESSION_SUCCESS" if player_won else "SPECIMEN_LOST",
		"cause": cause_str,
		"final_status": final_status_str,
		"remaining_vital": player_stats["vital_integrity"],
		"remaining_control": player_stats["neural_control"],
		"final_mutation_load": player_stats["mutation_load"]
	}

	# BioroidRegistry へ監査記録コミット
	var reg = _get_registry_node()
	if reg and reg.has_method("record_audit_entry"):
		reg.call("record_audit_entry", audit_record)

	battle_ended.emit(player_won, audit_record)

