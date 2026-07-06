extends Control

@onready var glitch_overlay: Node = $GlitchOverlay
@onready var button_container: VBoxContainer = $MarginContainer/VBoxContainer/ButtonContainer
@onready var start_button: Button = $MarginContainer/VBoxContainer/ButtonContainer/StartButton
@onready var calibration_button: Button = $MarginContainer/VBoxContainer/ButtonContainer/OptionButton
@onready var quit_button: Button = $MarginContainer/VBoxContainer/ButtonContainer/QuitButton
@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel
@onready var stats_label: Label = $MarginContainer/VBoxContainer/StatsLabel
@onready var hint_label: Label = $MarginContainer/VBoxContainer/HintLabel
@onready var result_sub_label: Label = $MarginContainer/VBoxContainer/ResultSubLabel
@onready var player_panel: PanelContainer = $MarginContainer/VBoxContainer/BattleContainer/PlayerPanel
@onready var player_portrait_label: Label = $MarginContainer/VBoxContainer/BattleContainer/PlayerPanel/PlayerVBox/PlayerPortraitLabel
@onready var player_hp_bar: ProgressBar = $MarginContainer/VBoxContainer/BattleContainer/PlayerPanel/PlayerVBox/PlayerHpBar
@onready var player_state_label: Label = $MarginContainer/VBoxContainer/BattleContainer/PlayerPanel/PlayerVBox/PlayerStateLabel
@onready var enemy_panel: PanelContainer = $MarginContainer/VBoxContainer/BattleContainer/EnemyPanel
@onready var enemy_portrait_label: Label = $MarginContainer/VBoxContainer/BattleContainer/EnemyPanel/EnemyVBox/EnemyPortraitLabel
@onready var enemy_hp_bar: ProgressBar = $MarginContainer/VBoxContainer/BattleContainer/EnemyPanel/EnemyVBox/EnemyHpBar
@onready var enemy_state_label: Label = $MarginContainer/VBoxContainer/BattleContainer/EnemyPanel/EnemyVBox/EnemyStateLabel

const RUN_DURATION_SEC: float = 20.0
var PLAYER_MAX_HP: float = 100.0
const BASE_DECAY_PER_SEC: float = 8.0
const GUARD_RECOVERY: float = 7.5
var STRIKE_BASE_DAMAGE: float = 14.0
const BURST_BASE_DAMAGE: float = 30.0
const BURST_COST: float = 12.0
const BURST_COOLDOWN_SEC: float = 4.0
const SAVE_PATH: String = "user://phase6_progress.cfg"
const INPUT_DENSITY_WINDOW_SEC: float = 3.0
const INPUT_DENSITY_LOW: float = 1.6
const INPUT_DENSITY_HIGH: float = 7.0
const HINT_COLOR_DEFAULT := Color(0.9, 0.95, 1.0, 1.0)
const HINT_COLOR_LOW_INPUT := Color(0.55, 0.75, 1.0, 1.0)
const HINT_COLOR_OVER_INPUT := Color(1.0, 0.45, 0.45, 1.0)
const HINT_COLOR_PEAK := Color(1.0, 0.9, 0.45, 1.0)
const PANEL_NORMAL_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const PLAYER_HIT_COLOR := Color(1.0, 0.42, 0.38, 1.0)
const GUARD_FLASH_COLOR := Color(0.45, 0.85, 1.0, 1.0)
const ENEMY_HIT_COLOR := Color(1.0, 0.82, 0.28, 1.0)
const ENEMY_DEFEAT_COLOR := Color(0.65, 1.0, 0.82, 1.0)

var _run_active: bool = false
var _time_left: float = RUN_DURATION_SEC
var _score: int = 0
var _integrity: float = PLAYER_MAX_HP
var _combo: int = 0
var _best_scores: Array[int] = [0, 0, 0]
var _last_rank: String = "-"
var _runs_completed: int = 0
var _enemy_hp: float = 0.0
var _enemy_attack_timer: float = 0.0
var _enemy_intent_id: String = "lance"
var _enemy_intent_name: String = "STATIC LANCE"
var _enemy_intent_multiplier: float = 1.0
var _enemy_intent_guard_factor: float = 0.35
var _enemy_intent_charge_up: bool = false
var _enemy_next_intent_id: String = ""
var _guard_active: bool = false
var _burst_cooldown_left: float = 0.0
var _last_fail_mode: String = ""
var _player_reaction_tween: Tween
var _enemy_reaction_tween: Tween

var _guard_timestamp: float = 0.0
var _guard_cooldown_left: float = 0.0
var _stun_immunity_left: float = 0.0

var _pressure_seed: int = 0
var _last_pressure_value: float = 1.0
var _current_pressure: float = 1.0
var _difficulty_index: int = 0
var _difficulty_names: Array[String] = ["NORMAL", "HARD", "CHAOS"]
var _difficulty_pressure_gain: Array[float] = [1.0, 1.18, 1.35]
var _difficulty_cycle_speed: Array[float] = [0.7, 0.95, 1.2]
var _difficulty_wave_depth: Array[float] = [0.30, 0.38, 0.48]
var _difficulty_peak: Array[float] = [1.2, 1.35, 1.55]
var _difficulty_recovery_penalty_max: Array[float] = [1.6, 1.85, 2.15]
var _enemy_max_hp_by_difficulty: Array[float] = [120.0, 150.0, 180.0]
var _enemy_attack_interval_by_difficulty: Array[float] = [1.8, 1.5, 1.25]
var _enemy_base_damage_by_difficulty: Array[float] = [10.0, 12.0, 14.0]
var _clear_rank_s_threshold: Array[int] = [4200, 5600, 7200]
var _clear_rank_a_threshold: Array[int] = [3400, 4600, 6000]
var _clear_rank_b_threshold: Array[int] = [2700, 3600, 4700]
var _fail_rank_c_threshold: Array[int] = [1800, 2200, 2600]
var _fail_rank_d_threshold: Array[int] = [1100, 1400, 1700]
var _action_press_times: Array[float] = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	Logger.info("PHASE6", "UI Glitch Overlay Scene Ready.")
	_rng.randomize()
	var use_glitch_fx: bool = bool(ProjectSettings.get_setting("ui_fx/use_glitch_fx", true))
	glitch_overlay.visible = use_glitch_fx

	for child in button_container.get_children():
		if child is Button:
			var button := child as Button
			if not button.pressed.is_connected(_on_any_button_pressed):
				button.pressed.connect(_on_any_button_pressed)

	if not start_button.pressed.is_connected(_on_start_pressed):
		start_button.pressed.connect(_on_start_pressed)
	if not calibration_button.pressed.is_connected(_on_calibration_pressed):
		calibration_button.pressed.connect(_on_calibration_pressed)
	if not quit_button.pressed.is_connected(_on_quit_pressed):
		quit_button.pressed.connect(_on_quit_pressed)

	_load_progress()
	_init_sector_difficulty()
	_reset_run_state()
	_update_ui()

func _init_sector_difficulty() -> void:
	var sector = GlobalData.current_combat_sector
	match sector:
		"expedition_gate", "material_locker":
			_difficulty_index = 0
		"observation_cage", "proto_vat":
			_difficulty_index = 1
		"research_log", "arena_terminal":
			_difficulty_index = 2
		_:
			_difficulty_index = 0

func _process(delta: float) -> void:
	if not _run_active:
		return

	_time_left = maxf(_time_left - delta, 0.0)
	_prune_old_inputs(_elapsed_seconds())
	_current_pressure = _sample_pressure_multiplier(delta)
	_burst_cooldown_left = maxf(_burst_cooldown_left - delta, 0.0)
	_guard_cooldown_left = maxf(_guard_cooldown_left - delta, 0.0)
	_stun_immunity_left = maxf(_stun_immunity_left - delta, 0.0)
	_enemy_attack_timer = maxf(_enemy_attack_timer - delta, 0.0)
	
	if _guard_active and _elapsed_seconds() - _guard_timestamp > 1.0:
		_guard_active = false
		
	var decay_rate := (BASE_DECAY_PER_SEC + float(_combo) * 0.6) * _current_pressure
	_integrity = maxf(_integrity - decay_rate * delta, 0.0)

	if _enemy_attack_timer <= 0.0:
		_resolve_enemy_attack()

	if _enemy_hp <= 0.0:
		_end_run(true)
		return

	if _integrity <= 0.0:
		_last_fail_mode = "downed"
		_end_run(false)
	elif _time_left <= 0.0:
		_last_fail_mode = "timeout"
		_end_run(false)

	_update_ui()

func _on_any_button_pressed() -> void:
	if glitch_overlay and glitch_overlay.visible:
		glitch_overlay.boost()

func _on_start_pressed() -> void:
	if not _run_active:
		_start_battle()
		return

	_perform_strike()

func _on_calibration_pressed() -> void:
	if not _run_active:
		status_label.text = "STATUS: STANDBY"
		_set_hint_text("待機中は 1/2/3 で難易度変更。START SYSTEM で出撃します")
		_set_result_sub_text("")
		return

	_perform_guard()

func _on_quit_pressed() -> void:
	if _run_active:
		_perform_burst()
		return

	get_tree().change_scene_to_file("res://scenes/ui/ui_map_phase7.tscn")

func _end_run(cleared: bool) -> void:
	_run_active = false
	_update_action_labels()
	_last_rank = _evaluate_rank(cleared)
	_runs_completed += 1
	if _score > _best_scores[_difficulty_index]:
		_best_scores[_difficulty_index] = _score
	_save_progress()

	if cleared:
		GlobalData.complete_sector(GlobalData.current_combat_sector)
		AudioManager.play_win()
		status_label.text = "STATUS: RUN CLEARED | RANK %s" % _last_rank
		var clear_gap_text := _build_next_rank_gap_text(true)
		_set_hint_text("クリア: BEST[%s] %05d" % [_difficulty_names[_difficulty_index], _best_scores[_difficulty_index]])
		_set_result_sub_text("改善目標: %s" % clear_gap_text)
	else:
		AudioManager.play_lose()
		var reason := _build_failure_reason()
		var fail_gap_text := _build_next_rank_gap_text(false)
		status_label.text = "STATUS: CORE COLLAPSED | RANK %s" % _last_rank
		hint_label.text = "失敗: %s | BEST[%s] %05d" % [reason, _difficulty_names[_difficulty_index], _best_scores[_difficulty_index]]
		_set_result_sub_text("改善目標: %s" % fail_gap_text)
	_log_result_snapshot(cleared)
	_combo = 0
	_update_ui()

func _reset_run_state() -> void:
	_run_active = false
	_time_left = RUN_DURATION_SEC
	_score = 0
	_integrity = PLAYER_MAX_HP
	_combo = 0
	status_label.text = "STATUS: STANDBY"
	_current_pressure = 1.0
	_last_pressure_value = 1.0
	_action_press_times.clear()
	_guard_active = false
	_burst_cooldown_left = 0.0
	_enemy_hp = _enemy_max_hp()
	_enemy_attack_timer = _enemy_attack_interval()
	_queue_next_enemy_intent()
	_reset_battle_visuals()
	_update_action_labels()
	_update_standby_hint()
	_set_result_sub_text("")

func _update_ui() -> void:
	var time_text := "%04.1f" % _time_left
	var score_text := "%05d" % _score
	var player_hp_text := "%03d" % int(round(_integrity))
	var enemy_hp_text := "%03d" % int(round(_enemy_hp))
	stats_label.text = "TIME %s | SCORE %s | PILOT %s | DRONE %s | PRESSURE %.2f | DIFF %s" % [time_text, score_text, player_hp_text, enemy_hp_text, _current_pressure, _difficulty_names[_difficulty_index]]
	_update_battle_ui()

func _start_battle() -> void:
	PLAYER_MAX_HP = 100.0 + float(GlobalData.hp_level) * 20.0
	STRIKE_BASE_DAMAGE = 14.0 + float(GlobalData.damage_level) * 3.0
	_run_active = true
	_time_left = RUN_DURATION_SEC
	_score = 0
	_integrity = PLAYER_MAX_HP
	_enemy_hp = _enemy_max_hp()
	_combo = 0
	_action_press_times.clear()
	_guard_active = false
	_burst_cooldown_left = 0.0
	_last_fail_mode = ""
	_pressure_seed = randi()
	_last_pressure_value = 1.0
	_current_pressure = 1.0
	_queue_next_enemy_intent()
	_reset_battle_visuals()
	_update_action_labels()
	status_label.text = "STATUS: CORE ONLINE"
	_set_hint_text("STRIKE / GUARD / BURST で NULL DRONE を撃破してください")
	_set_result_sub_text("")
	_update_ui()

func _elapsed_ratio() -> float:
	return clampf((RUN_DURATION_SEC - _time_left) / RUN_DURATION_SEC, 0.0, 1.0)

func _elapsed_seconds() -> float:
	return RUN_DURATION_SEC - _time_left

func _sample_pressure_multiplier(delta: float) -> float:
	var ratio := _elapsed_ratio()
	var elapsed_sec := _elapsed_seconds()
	var seed_offset := float(_pressure_seed % 997) / 997.0
	var cycle_speed := _difficulty_cycle_speed[_difficulty_index]
	var cycle_position := fmod(elapsed_sec * cycle_speed + seed_offset * 2.0, 2.0)
	
	var pressure_gain := _difficulty_pressure_gain[_difficulty_index]
	var base_pressure := lerpf(1.0, 2.5 * pressure_gain, ratio)
	var wave_depth := _difficulty_wave_depth[_difficulty_index]
	var quiet_min := 1.0 - wave_depth
	var peak := _difficulty_peak[_difficulty_index]
	
	var wave_factor: float
	if cycle_position < 0.6:
		wave_factor = lerpf(1.0, quiet_min, cycle_position / 0.6)
	else:
		var recovery_time := (cycle_position - 0.6) / 1.4
		wave_factor = lerpf(quiet_min, peak, ease(recovery_time, -2.0))
	
	var final_pressure := base_pressure * wave_factor
	var smoothing_speed := 2.2
	_last_pressure_value = move_toward(_last_pressure_value, final_pressure, smoothing_speed * delta)
	return _last_pressure_value

func _record_calibration_press() -> void:
	var now_sec := _elapsed_seconds()
	_action_press_times.append(now_sec)
	_prune_old_inputs(now_sec)

func _prune_old_inputs(now_sec: float) -> void:
	while not _action_press_times.is_empty() and _action_press_times[0] < now_sec - INPUT_DENSITY_WINDOW_SEC:
		_action_press_times.remove_at(0)

func _recent_input_density() -> float:
	return float(_action_press_times.size()) / INPUT_DENSITY_WINDOW_SEC

func _build_failure_reason() -> String:
	if _last_fail_mode == "timeout":
		_set_hint_color(HINT_COLOR_PEAK)
		return "時間切れ。NULL DRONE 残HP %03d" % int(ceil(_enemy_hp))

	var density := _recent_input_density()
	if density < INPUT_DENSITY_LOW:
		_set_hint_color(HINT_COLOR_LOW_INPUT)
		return "入力不足で被弾過多 (直近3秒 %.2f 回/秒)" % density
	if density > INPUT_DENSITY_HIGH:
		_set_hint_color(HINT_COLOR_OVER_INPUT)
		return "過入力で効率低下 (直近3秒 %.2f 回/秒)" % density
	_set_hint_color(HINT_COLOR_PEAK)
	return "入力密度は適正。GUARD/BURST の切り方が課題 (%.2f 回/秒)" % density

func _update_standby_hint() -> void:
	var base := "START SYSTEM で出撃 | DIFF %s (1/2/3)" % _difficulty_names[_difficulty_index]
	if _runs_completed > 0:
		_set_hint_text("%s | BEST[%s] %05d" % [base, _difficulty_names[_difficulty_index], _best_scores[_difficulty_index]])
	else:
		_set_hint_text(base)

func _update_action_labels() -> void:
	if _run_active:
		start_button.text = "STRIKE"
		calibration_button.text = "GUARD"
		quit_button.text = "BURST"
	else:
		start_button.text = "START SYSTEM"
		calibration_button.text = "TACTICAL READY"
		quit_button.text = "EXIT"

func _set_hint_color(color: Color) -> void:
	hint_label.add_theme_color_override("font_color", color)

func _set_hint_text(text: String) -> void:
	_set_hint_color(HINT_COLOR_DEFAULT)
	hint_label.text = text

func _set_result_sub_text(text: String) -> void:
	result_sub_label.text = text

func _update_battle_ui() -> void:
	var player_hp_value := clampf(_integrity, 0.0, PLAYER_MAX_HP)
	var enemy_hp_value := clampf(_enemy_hp, 0.0, _enemy_max_hp())
	player_hp_bar.max_value = PLAYER_MAX_HP
	player_hp_bar.value = player_hp_value
	enemy_hp_bar.max_value = _enemy_max_hp()
	enemy_hp_bar.value = enemy_hp_value
	var burst_text := "BURST READY" if _burst_cooldown_left <= 0.0 else "BURST %.1fs" % _burst_cooldown_left
	var guard_text := "GUARD UP" if _guard_active else "GUARD OPEN"
	
	var bonus_hp := int(GlobalData.hp_level) * 20
	var hp_display_text = "%03d" % int(round(player_hp_value))
	if bonus_hp > 0:
		hp_display_text += " (+%d)" % bonus_hp
		
	player_state_label.text = "HP %s | %s | COMBO %02d" % [hp_display_text, burst_text, _combo]
	if _run_active:
		var intent_tags := []
		if _enemy_intent_charge_up:
			intent_tags.append("CHARGE")
		if _enemy_intent_guard_factor > 0.35:
			intent_tags.append("PIERCE")
		var intent_suffix := ""
		if not intent_tags.is_empty():
			intent_suffix = " [%s]" % "/".join(intent_tags)
		enemy_state_label.text = "INTENT %s%s x%.2f | %.1fs" % [_enemy_intent_name, intent_suffix, _enemy_intent_multiplier, _enemy_attack_timer]
		if _enemy_attack_timer < 0.8:
			enemy_state_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		else:
			enemy_state_label.remove_theme_color_override("font_color")
	elif _enemy_hp <= 0.0:
		enemy_state_label.text = "TARGET DOWN | %s" % guard_text
	elif _integrity <= 0.0:
		enemy_state_label.text = "PILOT DOWN | %s" % guard_text
	else:
		enemy_state_label.text = "TARGET LOCKED | %s" % guard_text

func _enemy_max_hp() -> float:
	return _enemy_max_hp_by_difficulty[_difficulty_index]

func _enemy_attack_interval() -> float:
	var base_interval := _enemy_attack_interval_by_difficulty[_difficulty_index]
	var haste := lerpf(1.0, 0.72, clampf((_current_pressure - 1.0) / 2.0, 0.0, 1.0))
	return base_interval * haste

func _queue_next_enemy_intent() -> void:
	if _enemy_next_intent_id != "":
		_set_enemy_intent_profile(_enemy_next_intent_id)
		_enemy_next_intent_id = ""
		return

	var roll := _rng.randf()
	var pressure_bias := clampf((_current_pressure - 1.0) / 1.5, 0.0, 1.0)
	if _guard_active and roll < 0.52 + pressure_bias * 0.18:
		_set_enemy_intent_profile("ripper")
	elif _combo >= 3 and roll < 0.45 + pressure_bias * 0.2:
		_set_enemy_intent_profile("lock")
	elif roll < 0.32:
		_set_enemy_intent_profile("lance")
	elif roll < 0.62:
		_set_enemy_intent_profile("sweep")
	elif roll < 0.84:
		_set_enemy_intent_profile("lock")
	else:
		_set_enemy_intent_profile("ripper")

func _set_enemy_intent_profile(intent_id: String) -> void:
	_enemy_intent_id = intent_id
	_enemy_intent_charge_up = false
	match intent_id:
		"lance":
			_enemy_intent_name = "STATIC LANCE"
			_enemy_intent_multiplier = 1.0
			_enemy_intent_guard_factor = 0.35
			_enemy_attack_timer = _enemy_attack_interval()
		"sweep":
			_enemy_intent_name = "ARC SWEEP"
			_enemy_intent_multiplier = 0.82
			_enemy_intent_guard_factor = 0.55
			_enemy_attack_timer = _enemy_attack_interval()
		"lock":
			_enemy_intent_name = "MORTAR LOCK"
			_enemy_intent_multiplier = 0.0
			_enemy_intent_guard_factor = 1.0
			_enemy_intent_charge_up = true
			_enemy_next_intent_id = "spike"
			_enemy_attack_timer = _enemy_attack_interval() * 0.8
		"spike":
			_enemy_intent_name = "MORTAR SPIKE"
			_enemy_intent_multiplier = 1.45
			_enemy_intent_guard_factor = 0.78
			_enemy_attack_timer = _enemy_attack_interval() * 0.9
		"ripper":
			_enemy_intent_name = "PHASE RIPPER"
			_enemy_intent_multiplier = 1.12
			_enemy_intent_guard_factor = 0.85
			_enemy_attack_timer = _enemy_attack_interval()
		"stunned":
			_enemy_intent_name = "SYSTEM STUNNED"
			_enemy_intent_multiplier = 0.0
			_enemy_intent_guard_factor = 1.0
			_enemy_attack_timer = 3.0
		_:
			_set_enemy_intent_profile("lance")

func _perform_strike() -> void:
	_record_calibration_press()
	var damage := STRIKE_BASE_DAMAGE + float(_combo) * 2.0 + _rng.randf_range(0.0, 4.0)
	damage *= lerpf(0.95, 1.15, clampf(_current_pressure / 2.5, 0.0, 1.0))
	
	var bonus_dmg := int(GlobalData.damage_level) * 3
	var base_strike_part := int(round(damage)) - bonus_dmg
	var strike_text = "%02d" % base_strike_part
	if bonus_dmg > 0:
		strike_text += " (+%d)" % bonus_dmg
		
	_apply_player_attack(damage, "PILOT STRIKE %s DMG" % strike_text)

func _perform_guard() -> void:
	if _guard_cooldown_left > 0.0:
		_set_hint_text("GUARD COOLING %.1fs" % _guard_cooldown_left)
		return

	_record_calibration_press()
	_guard_active = true
	_guard_timestamp = _elapsed_seconds()
	_guard_cooldown_left = 1.0
	var recovery_penalty_max := _difficulty_recovery_penalty_max[_difficulty_index]
	var recovery_penalty := lerpf(1.0, recovery_penalty_max, _elapsed_ratio())
	_integrity = minf(_integrity + (GUARD_RECOVERY / recovery_penalty), PLAYER_MAX_HP)
	_score += 40
	_set_hint_text("GUARD PRIMED: 次の攻撃を軽減します")
	_play_guard_ready_reaction()
	_update_ui()

func _perform_burst() -> void:
	if _burst_cooldown_left > 0.0:
		_set_hint_text("BURST COOLING %.1fs" % _burst_cooldown_left)
		return
	if _integrity <= BURST_COST:
		_set_hint_text("BURSTには INTEGRITY %d 以上が必要です" % int(ceil(BURST_COST) + 1))
		return

	_record_calibration_press()
	_integrity = maxf(_integrity - BURST_COST, 1.0)
	_burst_cooldown_left = BURST_COOLDOWN_SEC
	var damage := BURST_BASE_DAMAGE + float(_combo) * 3.0 + _rng.randf_range(2.0, 8.0)
	damage *= 1.0 + clampf(_current_pressure - 1.0, 0.0, 1.5) * 0.18
	
	if _enemy_intent_charge_up:
		if _stun_immunity_left <= 0.0:
			_set_enemy_intent_profile("stunned")
			_score += 300
			_apply_player_attack(damage, "INTERRUPT! BURST %02d DMG / STUNNED" % int(round(damage)))
		else:
			_enemy_intent_charge_up = false
			_queue_next_enemy_intent()
			_score += 100
			_apply_player_attack(damage, "INTERRUPT! BURST %02d DMG / (IMMUNE TO STUN)" % int(round(damage)))
	else:
		_apply_player_attack(damage, "BURST %02d DMG / -%d INTEGRITY" % [int(round(damage)), int(BURST_COST)])

func _apply_player_attack(damage: float, battle_hint: String) -> void:
	_combo += 1
	_enemy_hp = maxf(_enemy_hp - damage, 0.0)
	_score += int(round(damage * 20.0))
	_set_hint_text(battle_hint)
	_play_enemy_hit_reaction(damage)
	AudioManager.play_hit()
	if _enemy_hp <= 0.0:
		_score += int(round(_time_left * 60.0 + _integrity * 5.0))
		_play_enemy_defeat_reaction()
		_end_run(true)
		return
	_update_ui()

func _resolve_enemy_attack() -> void:
	if _enemy_intent_id == "stunned":
		_set_hint_text("SYSTEM REBOOTING... (NO DMG)")
		_stun_immunity_left = 8.0
		_queue_next_enemy_intent()
		return

	if _enemy_intent_charge_up:
		_set_hint_text("ENEMY %s: 次弾が強化されます" % _enemy_intent_name)
		Logger.debug("PHASE6_AI", "intent=%s | phase=charge" % _enemy_intent_id)
		_queue_next_enemy_intent()
		return

	var raw_damage := _enemy_base_damage_by_difficulty[_difficulty_index] * _enemy_intent_multiplier * _current_pressure
	var damage := raw_damage
	var combo_broken := true
	
	if _guard_active:
		damage *= _enemy_intent_guard_factor
		_guard_active = false
		var reaction_time = _elapsed_seconds() - _guard_timestamp
		if _enemy_intent_guard_factor <= 0.4 and reaction_time <= 0.4:
			_score += 90
			combo_broken = false
			var counter_dmg = raw_damage * 0.3
			_play_player_guard_reaction(damage)
			_apply_player_attack(counter_dmg, "PERFECT GUARD / COUNTER %.0f DMG" % counter_dmg)
		else:
			if reaction_time > 0.4:
				_set_hint_text("LATE GUARD: %s %.0f DMG" % [_enemy_intent_name, damage])
			else:
				_set_hint_text("GUARD CRACKED: %s %.0f DMG" % [_enemy_intent_name, damage])
			_play_player_hit_reaction(damage)
			AudioManager.play_hit()
	else:
		_set_hint_text("ENEMY %s: %.0f DMG" % [_enemy_intent_name, damage])
		_play_player_hit_reaction(damage)
		AudioManager.play_hit()
		
	_integrity = maxf(_integrity - damage, 0.0)
	if combo_broken:
		_combo = 0
	Logger.debug("PHASE6_AI", "intent=%s | damage=%.1f | guard_factor=%.2f" % [_enemy_intent_id, damage, _enemy_intent_guard_factor])
	_queue_next_enemy_intent()

func _reset_battle_visuals() -> void:
	_stop_reaction_tween(_player_reaction_tween)
	_stop_reaction_tween(_enemy_reaction_tween)
	player_panel.modulate = PANEL_NORMAL_COLOR
	enemy_panel.modulate = PANEL_NORMAL_COLOR
	player_panel.position = Vector2.ZERO
	enemy_panel.position = Vector2.ZERO
	player_panel.scale = Vector2.ONE
	enemy_panel.scale = Vector2.ONE
	player_portrait_label.text = "[=]"
	enemy_portrait_label.text = "<X>"

func _play_guard_ready_reaction() -> void:
	player_portrait_label.text = "[#]"
	_player_reaction_tween = _play_panel_reaction(player_panel, GUARD_FLASH_COLOR, 1.03, 0.18, 0.0)

func _play_player_guard_reaction(damage: float) -> void:
	player_portrait_label.text = "[#]"
	_player_reaction_tween = _play_panel_reaction(player_panel, GUARD_FLASH_COLOR, 1.04, 0.2, 4.0)
	Logger.debug("PHASE6_REACTION", "target=player | type=guard | damage=%.1f" % damage)

func _play_player_hit_reaction(damage: float) -> void:
	player_portrait_label.text = "[!]"
	_player_reaction_tween = _play_panel_reaction(player_panel, PLAYER_HIT_COLOR, 0.96, 0.24, -8.0)
	if glitch_overlay and glitch_overlay.visible:
		glitch_overlay.boost()
	Logger.debug("PHASE6_REACTION", "target=player | type=hit | damage=%.1f" % damage)

func _play_enemy_hit_reaction(damage: float) -> void:
	enemy_portrait_label.text = "<!>"
	_enemy_reaction_tween = _play_panel_reaction(enemy_panel, ENEMY_HIT_COLOR, 0.96, 0.2, 8.0)
	Logger.debug("PHASE6_REACTION", "target=enemy | type=hit | damage=%.1f" % damage)

func _play_enemy_defeat_reaction() -> void:
	_stop_reaction_tween(_enemy_reaction_tween)
	enemy_portrait_label.text = "<0>"
	enemy_panel.modulate = ENEMY_DEFEAT_COLOR
	enemy_panel.scale = Vector2.ONE
	_enemy_reaction_tween = create_tween()
	_enemy_reaction_tween.set_parallel(true)
	_enemy_reaction_tween.tween_property(enemy_panel, "scale", Vector2(1.08, 1.08), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_enemy_reaction_tween.tween_property(enemy_panel, "modulate", Color(0.4, 1.0, 0.7, 0.35), 0.35).set_delay(0.12)
	Logger.debug("PHASE6_REACTION", "target=enemy | type=defeat")

func _play_panel_reaction(panel: Control, flash_color: Color, scale_target: float, duration: float, x_shake: float) -> Tween:
	var tween := create_tween()
	tween.set_parallel(true)
	panel.modulate = flash_color
	panel.scale = Vector2.ONE
	panel.position = Vector2.ZERO
	tween.tween_property(panel, "modulate", PANEL_NORMAL_COLOR, duration)
	tween.tween_property(panel, "scale", Vector2(scale_target, scale_target), duration * 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, duration * 0.55).set_delay(duration * 0.45)
	if not is_zero_approx(x_shake):
		tween.tween_property(panel, "position:x", x_shake, duration * 0.25)
		tween.tween_property(panel, "position:x", -x_shake * 0.55, duration * 0.25).set_delay(duration * 0.25)
		tween.tween_property(panel, "position:x", 0.0, duration * 0.35).set_delay(duration * 0.5)
	return tween

func _stop_reaction_tween(tween: Tween) -> void:
	if tween and tween.is_valid():
		tween.kill()

func _log_result_snapshot(cleared: bool) -> void:
	var outcome := "CLEARED" if cleared else "FAILED"
	Logger.audit("PHASE6_RESULT", "Run finished", {
		"outcome": outcome,
		"status": status_label.text,
		"hint": hint_label.text,
		"sub": result_sub_label.text
	})

func _unhandled_input(event: InputEvent) -> void:
	if _run_active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			_difficulty_index = 0
		elif event.keycode == KEY_2:
			_difficulty_index = 1
		elif event.keycode == KEY_3:
			_difficulty_index = 2
		else:
			return
		_update_standby_hint()
		_update_ui()

func _evaluate_rank(cleared: bool) -> String:
	if not cleared:
		if _score >= _fail_rank_c_threshold[_difficulty_index]:
			return "C"
		if _score >= _fail_rank_d_threshold[_difficulty_index]:
			return "D"
		return "E"

	var composite := _score + int(round(_integrity * 12.0))
	if composite >= _clear_rank_s_threshold[_difficulty_index]:
		return "S"
	if composite >= _clear_rank_a_threshold[_difficulty_index]:
		return "A"
	if composite >= _clear_rank_b_threshold[_difficulty_index]:
		return "B"
	return "C"

func _build_next_rank_gap_text(cleared: bool) -> String:
	if cleared:
		var composite := _score + int(round(_integrity * 12.0))
		match _last_rank:
			"S":
				return "最高ランク到達"
			"A":
				return "次ランクSまで %d" % max(_clear_rank_s_threshold[_difficulty_index] - composite, 0)
			"B":
				return "次ランクAまで %d" % max(_clear_rank_a_threshold[_difficulty_index] - composite, 0)
			_:
				return "次ランクBまで %d" % max(_clear_rank_b_threshold[_difficulty_index] - composite, 0)

	match _last_rank:
		"E":
			return "次ランクDまで %d score" % max(_fail_rank_d_threshold[_difficulty_index] - _score, 0)
		"D":
			return "次ランクCまで %d score" % max(_fail_rank_c_threshold[_difficulty_index] - _score, 0)
		_:
			return "次ランクBにはランクリアが必要"

func _load_progress() -> void:
	_runs_completed = GlobalData.runs_completed
	_best_scores = GlobalData.best_scores

func _save_progress() -> void:
	GlobalData.runs_completed = _runs_completed
	GlobalData.best_scores = _best_scores
	GlobalData.save_data()
