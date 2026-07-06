extends Control

@export var base_miner_cost: int = 10
@export var miner_cost_multiplier: float = 1.15
@export var base_hp_upgrade_cost: int = 50
@export var hp_cost_multiplier: float = 1.3
@export var base_dmg_upgrade_cost: int = 80
@export var dmg_cost_multiplier: float = 1.4

@export var click_power: int = 1
@export var data_per_miner: int = 1

var current_miner_cost: int = 0
var current_hp_cost: int = 0
var current_dmg_cost: int = 0

const FloatingText := preload("res://scenes/vfx/floating_text.tscn")

@onready var data_label: Label = $MarginContainer/RootVBox/MainContent/Header/DataLabel
@onready var dps_label: Label = $MarginContainer/RootVBox/MainContent/Header/DpsLabel

@onready var hack_button: Button = $MarginContainer/RootVBox/MainContent/HackingPanel/HackButton

@onready var buy_miner_button: Button = $MarginContainer/RootVBox/MainContent/ShopPanel/BuyMinerButton
@onready var upgrade_hp_button: Button = $MarginContainer/RootVBox/MainContent/ShopPanel/UpgradeHpButton
@onready var upgrade_dmg_button: Button = $MarginContainer/RootVBox/MainContent/ShopPanel/UpgradeDmgButton

@onready var back_button: Button = $MarginContainer/RootVBox/TopBar/BackButton
@onready var deploy_button: Button = $MarginContainer/RootVBox/TopBar/DeployButton

@onready var main_content: Control = $MarginContainer/RootVBox/MainContent
@onready var shake_target: Control = $MarginContainer
@onready var glitch_overlay: ColorRect = $GlitchOverlay

func _ready() -> void:
	_calculate_costs()
	
	hack_button.pressed.connect(_on_hack_pressed)
	buy_miner_button.pressed.connect(_on_buy_miner_pressed)
	upgrade_hp_button.pressed.connect(_on_upgrade_hp_pressed)
	upgrade_dmg_button.pressed.connect(_on_upgrade_dmg_pressed)
	
	back_button.pressed.connect(_on_back_pressed)
	deploy_button.pressed.connect(_on_deploy_pressed)
	
	_update_ui()

func _calculate_costs() -> void:
	current_miner_cost = int(base_miner_cost * pow(miner_cost_multiplier, GlobalData.miners_owned))
	current_hp_cost = int(base_hp_upgrade_cost * pow(hp_cost_multiplier, GlobalData.hp_level))
	current_dmg_cost = int(base_dmg_upgrade_cost * pow(dmg_cost_multiplier, GlobalData.damage_level))

func _process(delta: float) -> void:
	if GlobalData.miners_owned > 0:
		GlobalData.data += (GlobalData.miners_owned * data_per_miner) * delta
		_update_ui()

func _on_hack_pressed() -> void:
	GlobalData.data += click_power
	
	if glitch_overlay:
		glitch_overlay.boost_peak = 0.15
		glitch_overlay.boost_duration = 0.1
		glitch_overlay.boost()
		
	var vfx := FloatingText.instantiate()
	add_child(vfx)
	var btn_rect = hack_button.get_global_rect()
	var center = btn_rect.position + btn_rect.size * 0.5
	vfx.setup("+" + str(click_power) + " DATA", center - Vector2(50, 40), Color(0.65, 1.0, 0.82))
	
	AudioManager.play_hack()
	_update_ui()

func _on_buy_miner_pressed() -> void:
	if GlobalData.data >= current_miner_cost:
		GlobalData.data -= current_miner_cost
		GlobalData.miners_owned += 1
		GlobalData.save_data()
		_shake_node(shake_target)
		AudioManager.play_buy()
		_calculate_costs()
		_update_ui()

func _on_upgrade_hp_pressed() -> void:
	if GlobalData.data >= current_hp_cost:
		GlobalData.data -= current_hp_cost
		GlobalData.hp_level += 1
		GlobalData.save_data()
		_shake_node(shake_target)
		AudioManager.play_buy()
		_calculate_costs()
		_update_ui()

func _on_upgrade_dmg_pressed() -> void:
	if GlobalData.data >= current_dmg_cost:
		GlobalData.data -= current_dmg_cost
		GlobalData.damage_level += 1
		GlobalData.save_data()
		_shake_node(shake_target)
		AudioManager.play_buy()
		_calculate_costs()
		_update_ui()

func _on_back_pressed() -> void:
	GlobalData.save_data()
	get_tree().change_scene_to_file("res://scenes/ui/ui_premium_phase5.tscn")

func _on_deploy_pressed() -> void:
	GlobalData.save_data()
	get_tree().change_scene_to_file("res://scenes/ui/ui_map_phase7.tscn")

func _update_ui() -> void:
	if data_label:
		data_label.text = "DATA: " + str(int(GlobalData.data))
	if dps_label:
		dps_label.text = "DPS: " + str(GlobalData.miners_owned * data_per_miner)
	
	if buy_miner_button:
		buy_miner_button.text = "BUY AUTO-MINER (Cost: %d)" % current_miner_cost
		buy_miner_button.disabled = GlobalData.data < current_miner_cost
		
	if upgrade_hp_button:
		upgrade_hp_button.text = "UPGRADE PILOT HP Lv%d (Cost: %d)" % [GlobalData.hp_level, current_hp_cost]
		upgrade_hp_button.disabled = GlobalData.data < current_hp_cost
		
	if upgrade_dmg_button:
		upgrade_dmg_button.text = "UPGRADE STRIKE DMG Lv%d (Cost: %d)" % [GlobalData.damage_level, current_dmg_cost]
		upgrade_dmg_button.disabled = GlobalData.data < current_dmg_cost

func _shake_node(node: Control) -> void:
	if not node:
		return
	var tween := create_tween()
	var original_pos := node.position
	tween.tween_property(node, "position:x", original_pos.x + 8.0, 0.04).set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "position:x", original_pos.x - 6.0, 0.04).set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "position:x", original_pos.x + 4.0, 0.04).set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "position:x", original_pos.x, 0.04).set_trans(Tween.TRANS_SINE)
