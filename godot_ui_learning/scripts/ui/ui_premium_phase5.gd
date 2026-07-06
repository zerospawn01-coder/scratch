extends Control

@onready var start_button: Button = $MarginContainer/VBoxContainer/ButtonContainer/StartButton
@onready var option_button: Button = $MarginContainer/VBoxContainer/ButtonContainer/OptionButton
@onready var quit_button: Button = $MarginContainer/VBoxContainer/ButtonContainer/QuitButton

func _ready() -> void:
	print("Phase 5: UI Premium (Shader & Neon) Scene Ready.")
	
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_start_pressed() -> void:
	# Change scene to the game scene
	get_tree().change_scene_to_file("res://scenes/ui/ui_map_phase7.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
