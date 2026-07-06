extends Control

const NODE_DEFINITIONS: Array[Dictionary] = [
	{
		"id": "core_chamber",
		"name": "Core Chamber",
		"gridX": 0.0,
		"gridY": 0.0,
		"type": "hub"
	},
	{
		"id": "expedition_gate",
		"name": "Expedition Gate",
		"gridX": 0.0,
		"gridY": -2.0,
		"type": "combat"
	},
	{
		"id": "material_locker",
		"name": "Material Locker",
		"gridX": -2.5,
		"gridY": 0.0,
		"type": "combat"
	},
	{
		"id": "observation_cage",
		"name": "Observation Cage",
		"gridX": 2.5,
		"gridY": 0.0,
		"type": "combat"
	},
	{
		"id": "proto_vat",
		"name": "Proto Vat",
		"gridX": 0.0,
		"gridY": 2.0,
		"type": "combat"
	},
	{
		"id": "research_log",
		"name": "Research Log",
		"gridX": 0.0,
		"gridY": 4.0,
		"type": "combat"
	},
	{
		"id": "arena_terminal",
		"name": "Arena Terminal",
		"gridX": 0.0,
		"gridY": 6.0,
		"type": "combat"
	}
]

const GRID_SPACING_X = 140.0
const GRID_SPACING_Y = 80.0

var center_offset: Vector2 = Vector2.ZERO
var node_buttons: Dictionary = {}

func _ready() -> void:
	center_offset = size / 2.0
	
	_build_map()

func _build_map() -> void:
	for child in get_children():
		if child is Button:
			child.queue_free()
		
		
	node_buttons.clear()
	
	# Generate Nodes
	for def in NODE_DEFINITIONS:
		var pos = center_offset + Vector2(def.gridX * GRID_SPACING_X, def.gridY * GRID_SPACING_Y)
		
		var btn = Button.new()
		btn.text = def.name
		btn.custom_minimum_size = Vector2(160, 60)
		btn.add_theme_font_size_override("font_size", 14)
		
		var state = GlobalData.sector_states.get(def.id, "LOCKED")
		
		if state == "LOCKED" or state == "COLLAPSED":
			btn.disabled = true
			btn.modulate = Color(0.4, 0.4, 0.4)
		elif state == "CLEARED":
			btn.modulate = Color(0.2, 0.8, 0.3) # Greenish
		elif state == "ONLINE":
			if def.type == "hub":
				btn.modulate = Color(0.3, 0.6, 1.0) # Blueish
			else:
				btn.modulate = Color(1.0, 0.5, 0.2) # Orange
				
		if state == "COLLAPSED":
			btn.text += "\n[COLLAPSED]"
		elif state == "LOCKED":
			btn.text += "\n[LOCKED]"
		elif state == "CLEARED":
			btn.text += "\n[CLEARED]"
		elif state == "ONLINE" and def.type != "hub":
			btn.text += "\n[COMBAT READY]"
			
		btn.set_anchors_preset(Control.PRESET_CENTER)
		add_child(btn)
		btn.position = pos - btn.custom_minimum_size / 2.0
		
		btn.pressed.connect(_on_node_pressed.bind(def.id, def.type))
		node_buttons[def.id] = btn
		
	queue_redraw()

func _draw() -> void:
	for conn in GlobalData.SECTOR_CONNECTIONS:
		var from_btn = node_buttons.get(conn.from)
		var to_btn = node_buttons.get(conn.to)
		
		if from_btn and to_btn:
			var p1 = from_btn.position + from_btn.size / 2.0
			var p2 = to_btn.position + to_btn.size / 2.0
			var color = Color(0.3, 0.3, 0.3, 0.5)
			
			var state_to = GlobalData.sector_states.get(conn.to, "LOCKED")
			if state_to == "ONLINE" or state_to == "CLEARED":
				color = Color(0.0, 1.0, 0.8, 0.5)
			elif state_to == "COLLAPSED":
				color = Color(1.0, 0.0, 0.0, 0.3)
				
			draw_line(p1, p2, color, 4.0)

func _on_node_pressed(sector_id: String, type: String) -> void:
	if type == "hub":
		get_tree().change_scene_to_file("res://scenes/game/game_scene.tscn")
	else:
		GlobalData.current_combat_sector = sector_id
		get_tree().change_scene_to_file("res://scenes/ui/ui_glitch_phase6.tscn")
