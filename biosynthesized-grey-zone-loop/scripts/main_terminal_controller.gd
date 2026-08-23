class_name MainTerminalController
extends Control

# =============================================================================
# Aether Fountain — Sovereign Auditor Main Terminal & Scene Flow Controller
# Philosophy: generation_is_not_authority (Unified deterministic loop)
# Coordinates: Terminal -> Expedition -> Gene Mixer -> Arena -> Ledger -> Terminal
# =============================================================================

signal state_changed(new_state: int, state_name: String)
signal loop_completed(run_id: String, audit_entry: Dictionary)

enum State {
	STATE_TERMINAL = 0,
	STATE_EXPEDITION = 1,
	STATE_GENE_MIXER = 2,
	STATE_ARENA = 3,
	STATE_LEDGER = 4
}

const STATE_NAMES: Dictionary = {
	State.STATE_TERMINAL: "STATE_TERMINAL",
	State.STATE_EXPEDITION: "STATE_EXPEDITION",
	State.STATE_GENE_MIXER: "STATE_GENE_MIXER",
	State.STATE_ARENA: "STATE_ARENA",
	State.STATE_LEDGER: "STATE_LEDGER"
}

@export var current_state: State = State.STATE_TERMINAL

# Manager references
var bioroid_registry: Node = null
var expedition_manager: Node = null

# Active run tracking
var current_run_index: int = 1
var active_run_id: String = "RUN-0001"
var active_fragments_available: int = 0
var active_specimen_payload: Dictionary = {}
var latest_audit_report: Dictionary = {}

# UI Node References (Optional in headless, wired if present in scene)
@onready var terminal_view: Control = get_node_or_null("Views/TerminalView")
@onready var expedition_view: Control = get_node_or_null("Views/ExpeditionView")
@onready var gene_mixer_view: Control = get_node_or_null("Views/GeneMixerView")
@onready var arena_view: Control = get_node_or_null("Views/ArenaView")
@onready var ledger_view: Control = get_node_or_null("Views/LedgerView")
var dialogue_controller: Node = null

# Status UI Labels
@onready var lbl_header_status: Label = get_node_or_null("Header/StatusLabel")
@onready var lbl_prompt: Label = get_node_or_null("Footer/PromptLabel")
@onready var lbl_ledger_summary: Label = get_node_or_null("Views/TerminalView/RightConsolePanel/LedgerSummaryPanel/LedgerSummaryLabel")
@onready var lbl_run_context: Label = get_node_or_null("Views/TerminalView/CenterConsolePanel/LogSubBox/RunContextLabel")
@onready var lbl_dialogue_feed: Label = get_node_or_null("Footer/DialogueFeedLabel")
@onready var img_specimen_visual: TextureRect = get_node_or_null("Views/TerminalView/LiveFeedFrame/SpecimenVisual")
@onready var lbl_cargo_val: Label = get_node_or_null("Views/TerminalView/CenterConsolePanel/TelemetryGrid/BoxCargo/Val")

# TabBar References
@onready var btn_tab_overview: Button = get_node_or_null("Footer/TabBar/TabOverview")
@onready var btn_tab_expedition: Button = get_node_or_null("Footer/TabBar/TabExpedition")
@onready var btn_tab_gene_mixer: Button = get_node_or_null("Footer/TabBar/TabGeneMixer")
@onready var btn_tab_arena: Button = get_node_or_null("Footer/TabBar/TabArena")
@onready var btn_tab_ledger: Button = get_node_or_null("Footer/TabBar/TabLedger")

func _ready() -> void:
	_resolve_singletons_and_managers()
	_update_run_id()
	_connect_dialogue_feed()
	transition_to_state(State.STATE_TERMINAL)

func _connect_dialogue_feed() -> void:
	if not lbl_dialogue_feed:
		lbl_dialogue_feed = get_node_or_null("Footer/DialogueFeedLabel")
	if dialogue_controller and dialogue_controller.has_signal("line_displayed"):
		if not dialogue_controller.line_displayed.is_connected(_on_dialogue_line_displayed):
			dialogue_controller.line_displayed.connect(_on_dialogue_line_displayed)

func _on_dialogue_line_displayed(speaker_id: String, speaker_name: String, text: String, emotion: String) -> void:
	if not lbl_dialogue_feed:
		lbl_dialogue_feed = get_node_or_null("Footer/DialogueFeedLabel")
	if lbl_dialogue_feed:
		lbl_dialogue_feed.text = "[COMM: %s] %s" % [speaker_name.to_upper(), text]

func _resolve_singletons_and_managers() -> void:
	# If already resolved, do nothing
	if bioroid_registry and expedition_manager and dialogue_controller:
		return

	# Resolve BioroidRegistry
	if not bioroid_registry:
		if is_inside_tree():
			var r = get_tree().root
			if r.has_node("BioroidRegistry"):
				bioroid_registry = r.get_node("BioroidRegistry")
		
		if not bioroid_registry:
			var reg_script = load("res://scripts/bioroid_registry.gd")
			if reg_script:
				bioroid_registry = reg_script.new()
				bioroid_registry.name = "BioroidRegistry"
				if is_inside_tree():
					get_tree().root.add_child(bioroid_registry)

	# Resolve ExpeditionManager
	if not expedition_manager:
		var exp_script = load("res://scripts/expedition_manager.gd")
		if exp_script:
			expedition_manager = exp_script.new()
			expedition_manager.name = "ExpeditionManager"
			add_child(expedition_manager)

	# Resolve DialogueController
	if not dialogue_controller:
		var dlg_script = load("res://scripts/dialogue_controller.gd")
		if dlg_script:
			dialogue_controller = dlg_script.new()
			dialogue_controller.name = "DialogueController"
			add_child(dialogue_controller)
			_connect_dialogue_feed()

func _update_run_id() -> void:
	var total_runs = 0
	if bioroid_registry and bioroid_registry.has_method("get_audit_record_count"):
		total_runs = bioroid_registry.get_audit_record_count()
	current_run_index = total_runs + 1
	active_run_id = "RUN-%04d" % current_run_index

# =============================================================================
# Input Handling & State Dispatcher
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return

	if event is InputEventKey:
		var key = event as InputEventKey
		if key.physical_keycode == KEY_SPACE or key.keycode == KEY_SPACE:
			_handle_space_action()
		elif key.physical_keycode == KEY_TAB or key.keycode == KEY_TAB:
			_handle_tab_action()
		elif key.physical_keycode == KEY_Z or key.keycode == KEY_Z:
			_handle_z_action()
		elif key.physical_keycode == KEY_X or key.keycode == KEY_X:
			_handle_x_action()

func _handle_space_action() -> void:
	match current_state:
		State.STATE_TERMINAL:
			# Advance from Terminal to Expedition
			transition_to_state(State.STATE_EXPEDITION)
		State.STATE_EXPEDITION:
			# In expedition, Space acts as alternative to explore sector
			explore_sector()
		State.STATE_GENE_MIXER:
			# Synthesize and advance to Arena
			synthesize_and_deploy()
		State.STATE_ARENA:
			# In Arena, Z/X are interventions; Space triggers battle start if not running
			pass
		State.STATE_LEDGER:
			# Advance from Ledger back to Terminal (Completing 1 cycle)
			transition_to_state(State.STATE_TERMINAL)

func _handle_tab_action() -> void:
	match current_state:
		State.STATE_EXPEDITION:
			# Return to lab from expedition
			return_from_expedition_to_mixer()
		State.STATE_GENE_MIXER:
			# Skip to Arena if specimen already synthesized
			if not active_specimen_payload.is_empty():
				transition_to_state(State.STATE_ARENA)

func _handle_z_action() -> void:
	match current_state:
		State.STATE_EXPEDITION:
			explore_sector()
		State.STATE_ARENA:
			var arena_mgr = _get_arena_manager()
			if arena_mgr and arena_mgr.has_method("execute_auditor_intervention"):
				arena_mgr.execute_auditor_intervention("NERVOUS_CORE_SUPPRESSION")

func _handle_x_action() -> void:
	match current_state:
		State.STATE_ARENA:
			var arena_mgr = _get_arena_manager()
			if arena_mgr and arena_mgr.has_method("execute_auditor_intervention"):
				arena_mgr.execute_auditor_intervention("GENE_DISCHARGE_OVERRIDE")

# =============================================================================
# State Transitions & Sub-View Management
# =============================================================================

func transition_to_state(new_state: State, trigger_dialogue: bool = true) -> void:
	_resolve_singletons_and_managers()
	current_state = new_state
	var state_str = STATE_NAMES.get(new_state, "UNKNOWN")
	print("[MainTerminal] Transitioning to: %s" % state_str)

	_update_view_visibilities()
	_on_enter_state(new_state, trigger_dialogue)

	state_changed.emit(new_state, state_str)

func _on_enter_state(state: State, trigger_dialogue: bool = true) -> void:
	_refresh_navigation_tabs(state)
	match state:
		State.STATE_TERMINAL:
			_update_run_id()
			_refresh_terminal_view()
		State.STATE_EXPEDITION:
			_refresh_expedition_view()
			if trigger_dialogue and dialogue_controller:
				dialogue_controller.play_context("STATE_EXPEDITION_ENTER")
		State.STATE_GENE_MIXER:
			_refresh_gene_mixer_view()
		State.STATE_ARENA:
			_init_arena_view()
			if trigger_dialogue and dialogue_controller:
				dialogue_controller.play_context("STATE_ARENA_ENTER")
		State.STATE_LEDGER:
			_refresh_ledger_view()
			if trigger_dialogue and dialogue_controller:
				dialogue_controller.play_context("STATE_LEDGER_ENTER")

func _refresh_navigation_tabs(state: State) -> void:
	if not btn_tab_overview:
		btn_tab_overview = get_node_or_null("Footer/TabBar/TabOverview")
		btn_tab_expedition = get_node_or_null("Footer/TabBar/TabExpedition")
		btn_tab_gene_mixer = get_node_or_null("Footer/TabBar/TabGeneMixer")
		btn_tab_arena = get_node_or_null("Footer/TabBar/TabArena")
		btn_tab_ledger = get_node_or_null("Footer/TabBar/TabLedger")
	
	if btn_tab_overview:
		btn_tab_overview.text = "☵ OVERVIEW [ACTIVE]" if state == State.STATE_TERMINAL else "☵ OVERVIEW"
	if btn_tab_expedition:
		btn_tab_expedition.text = "❖ EXPEDITION [ACTIVE]" if state == State.STATE_EXPEDITION else "❖ EXPEDITION"
	if btn_tab_gene_mixer:
		btn_tab_gene_mixer.text = "⌬ GENE MIXER [ACTIVE]" if state == State.STATE_GENE_MIXER else "⌬ GENE MIXER"
	if btn_tab_arena:
		btn_tab_arena.text = "⚔ ARENA [ACTIVE]" if state == State.STATE_ARENA else "⚔ ARENA"
	if btn_tab_ledger:
		btn_tab_ledger.text = "📜 AUDIT LEDGER [ACTIVE]" if state == State.STATE_LEDGER else "📜 AUDIT LEDGER"

func _update_view_visibilities() -> void:
	if terminal_view: terminal_view.visible = (current_state == State.STATE_TERMINAL)
	if expedition_view: expedition_view.visible = (current_state == State.STATE_EXPEDITION)
	if gene_mixer_view: gene_mixer_view.visible = (current_state == State.STATE_GENE_MIXER)
	if arena_view: arena_view.visible = (current_state == State.STATE_ARENA)
	if ledger_view: ledger_view.visible = (current_state == State.STATE_LEDGER)

# =============================================================================
# Domain Operations (Expedition -> Mixer -> Arena -> Ledger)
# =============================================================================

## 1. Expedition: Explore sector
func explore_sector() -> Dictionary:
	if not expedition_manager:
		_resolve_singletons_and_managers()
	
	var incident = {}
	if expedition_manager and expedition_manager.has_method("explore_next_sector"):
		incident = expedition_manager.explore_next_sector()
		var res = expedition_manager.get_resources()
		active_fragments_available = res.get("gene_fragments", 0)
		_refresh_expedition_view()

		if dialogue_controller:
			var incident_type: String = incident.get("incident_type", "")
			match incident_type:
				"SPECIMEN_TRACE":
					dialogue_controller.play_context("SECTOR_INCIDENT_SPECIMEN_TRACE")
				"ACTIVE_CULTURE":
					dialogue_controller.play_context("SECTOR_INCIDENT_ACTIVE_CULTURE")
	return incident

## 2. Expedition -> Gene Mixer handoff
func return_from_expedition_to_mixer() -> void:
	if not expedition_manager:
		_resolve_singletons_and_managers()

	if expedition_manager and expedition_manager.has_method("return_to_lab"):
		var handoff = expedition_manager.return_to_lab()
		active_fragments_available = handoff.get("gene_fragments", 0)
		print("[MainTerminal] Returned from expedition with %d fragments" % active_fragments_available)
	
	transition_to_state(State.STATE_GENE_MIXER)

## 3. Gene Mixer: Synthesize and register payload for Arena
func synthesize_and_deploy(custom_ratios: Dictionary = {}) -> Dictionary:
	var GeneMixerController = load("res://scripts/gene_mixer_controller.gd")
	var dna_ratios = custom_ratios
	if dna_ratios.is_empty():
		# Default proportional distribution based on available fragments
		var frags = max(active_fragments_available, 1)
		var ald = clampi(frags * 20 + 20, 30, 70)
		var kln = clampi(frags * 10 + 15, 15, 40)
		var chm = maxi(100 - ald - kln, 10)
		dna_ratios = {"alden": ald, "tsellina": kln, "elphadia": chm}

	var seed_val = current_run_index * 1337 + active_fragments_available * 41
	var specimen = GeneMixerController.synthesize(dna_ratios, seed_val)

	active_specimen_payload = {
		"run_id": active_run_id,
		"bioroid_id": specimen.get("individual_id", "BIO-ALD-DEF001"),
		"bioroid_name": specimen.get("dominant_nation", "ALDEN").to_upper(),
		"bioroid_hash": specimen.get("individual_hash", "0000000000000000"),
		"dna_ratio": {"ald": dna_ratios["alden"], "kln": dna_ratios["tsellina"], "chm": dna_ratios["elphadia"]},
		"stats": {
			"vital_integrity": 100,
			"neural_control": int(70 + dna_ratios["alden"] * 0.2),
			"mutation_load": int(5 + dna_ratios["elphadia"] * 0.3),
			"core_stress": 35,
			"atk": int(22 + dna_ratios["alden"] * 0.25),
			"ep": 60
		},
		"mutation_profile": {"surge_risk": "LOW", "instability_rate": 0.05},
		"sprite_path": "res://assets/bioroids/sprites/bio_ald_def001_alden_front.png",
		"generated_at": Time.get_datetime_string_from_system()
	}

	if bioroid_registry and bioroid_registry.has_method("register_deployment_payload"):
		bioroid_registry.register_deployment_payload(active_specimen_payload)

	if dialogue_controller:
		dialogue_controller.play_dialogue("GENE_MIXER_SYNTHESIS")

	transition_to_state(State.STATE_ARENA, false)
	return active_specimen_payload

## 4. Arena -> Ledger conclusion callback
func on_arena_battle_concluded(player_won: bool, audit_record: Dictionary) -> void:
	latest_audit_report = audit_record.duplicate(true)
	print("[MainTerminal] Battle concluded. Result: %s" % latest_audit_report.get("result", "UNKNOWN"))
	loop_completed.emit(active_run_id, latest_audit_report)
	transition_to_state(State.STATE_LEDGER)

# =============================================================================
# View Refresh & Helpers
# =============================================================================

func _get_arena_manager() -> Node:
	if arena_view:
		return arena_view.get_node_or_null("ArenaBattleManager")
	return null

func _init_arena_view() -> void:
	var arena_mgr = _get_arena_manager()
	if arena_mgr:
		if not arena_mgr.battle_ended.is_connected(on_arena_battle_concluded):
			arena_mgr.battle_ended.connect(on_arena_battle_concluded)
		if arena_mgr.has_method("start_arena_combat"):
			arena_mgr.start_arena_combat()

func _refresh_terminal_view() -> void:
	if lbl_header_status:
		lbl_header_status.text = "STATE: TERMINAL | ZONE-Λ (CONTAINMENT) | %s" % active_run_id
	if lbl_prompt:
		lbl_prompt.text = "> NEXT ACTION: [SPACE] INITIATE ZONE-Λ EXPEDITION"
	if lbl_run_context:
		lbl_run_context.text = "[SYSTEM LOG: ONLINE]\nSPECIMEN: %s / ZONE-Λ / Sector 02\nHarvest: Gene Fragment x%d recovered\nGENE FRAGMENTS AVAILABLE: %d\nDr. Valeria: Neural stability matrices binding smoothly.\nSovereign Protocol: Immutable Ledger active." % [
			active_specimen_payload.get("bioroid_id", "BIO-ALD-DEF001"),
			active_fragments_available,
			active_fragments_available
		]
	if lbl_cargo_val:
		if active_fragments_available == 0:
			lbl_cargo_val.text = "0 [DEPLETED]"
			lbl_cargo_val.add_theme_color_override("font_color", Color(1.0, 0.7, 0.1, 1.0))
		else:
			lbl_cargo_val.text = "%d [READY]" % active_fragments_available
			lbl_cargo_val.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4, 1.0))
	if lbl_ledger_summary and bioroid_registry and bioroid_registry.has_method("get_audit_record_count"):
		lbl_ledger_summary.text = "COMMITTED LEDGER ENTRIES: %d\n\nINTERVENTIONS:\n• [Z] NERVE STABILIZATION\n• [X] GENE DISCHARGE" % bioroid_registry.get_audit_record_count()
	
	if img_specimen_visual:
		var sprite_p = active_specimen_payload.get("sprite_path", "res://assets/bioroids/sprites/bio_ald_def001_alden_front.png")
		if ResourceLoader.exists(sprite_p):
			img_specimen_visual.texture = load(sprite_p)

func _refresh_expedition_view() -> void:
	if lbl_prompt:
		lbl_prompt.text = "> EXPEDITION IN PROGRESS: [Z/SPACE] EXPLORE SECTOR | [TAB] RETURN TO LAB"

func _refresh_gene_mixer_view() -> void:
	if lbl_prompt:
		lbl_prompt.text = "> GENE MIXER: [SPACE] SYNTHESIZE & DEPLOY TO ARENA | [TAB] ADVANCE"

func _refresh_ledger_view() -> void:
	if lbl_prompt:
		lbl_prompt.text = "> AUDIT LEDGER COMMITTED: [SPACE] RETURN TO TERMINAL CONSOLE"
