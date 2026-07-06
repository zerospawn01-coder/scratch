extends Node2D

var drone_script = preload("res://experiments/ai_poc/drone_agent.gd")
var drone

func _ready() -> void:
	print("[TEST] Starting LimboAI Drone PoC Simulation...")
	drone = drone_script.new()
	add_child(drone)
	
	# Simulate environment changes
	await get_tree().create_timer(2.5).timeout
	print("[SIMULATION] Spawning enemy!")
	drone.enemy_detected = true
	
	await get_tree().create_timer(3.0).timeout
	print("[SIMULATION] Enemy destroyed.")
	drone.enemy_detected = false
	
	await get_tree().create_timer(5.0).timeout
	print("[SIMULATION] Draining battery to force recharge...")
	drone.battery = 15.0
	
	await get_tree().create_timer(3.0).timeout
	print("[TEST] LimboAI Drone PoC Simulation Complete.")
	get_tree().quit(0)
