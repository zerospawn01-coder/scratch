extends Node2D

var _hsm: LimboHSM
var _idle_state: LimboState
var _patrol_state: LimboState
var _attack_state: LimboState
var _recharge_state: LimboState

var battery: float = 100.0
var enemy_detected: bool = false
var patrol_time: float = 0.0

func _ready() -> void:
	print("[DroneAgent] Initializing minimal LimboHSM...")
	_setup_hsm()
	print("[DroneAgent] HSM setup complete. Initial state: ", _hsm.get_active_state().name)

func _process(delta: float) -> void:
	if _hsm:
		_hsm.update(delta)

func _setup_hsm() -> void:
	_hsm = LimboHSM.new()
	add_child(_hsm)
	
	_idle_state = LimboState.new()
	_idle_state.name = "Idle"
	_idle_state.call_on_enter(Callable(self, "_on_idle_enter"))
	_idle_state.call_on_update(Callable(self, "_on_idle_update"))
	
	_patrol_state = LimboState.new()
	_patrol_state.name = "Patrol"
	_patrol_state.call_on_enter(Callable(self, "_on_patrol_enter"))
	_patrol_state.call_on_update(Callable(self, "_on_patrol_update"))
	
	_attack_state = LimboState.new()
	_attack_state.name = "Attack"
	_attack_state.call_on_enter(Callable(self, "_on_attack_enter"))
	_attack_state.call_on_update(Callable(self, "_on_attack_update"))
	
	_recharge_state = LimboState.new()
	_recharge_state.name = "Recharge"
	_recharge_state.call_on_enter(Callable(self, "_on_recharge_enter"))
	_recharge_state.call_on_update(Callable(self, "_on_recharge_update"))
	
	_hsm.add_child(_idle_state)
	_hsm.add_child(_patrol_state)
	_hsm.add_child(_attack_state)
	_hsm.add_child(_recharge_state)
	
	# Transitions
	_hsm.add_transition(_idle_state, _patrol_state, &"patrol")
	_hsm.add_transition(_idle_state, _recharge_state, &"recharge")
	_hsm.add_transition(_idle_state, _attack_state, &"attack")
	
	_hsm.add_transition(_patrol_state, _idle_state, &"idle")
	_hsm.add_transition(_patrol_state, _recharge_state, &"recharge")
	_hsm.add_transition(_patrol_state, _attack_state, &"attack")
	
	_hsm.add_transition(_attack_state, _idle_state, &"idle")
	_hsm.add_transition(_recharge_state, _idle_state, &"idle")
	
	_hsm.initial_state = _idle_state
	_hsm.initialize(self)
	_hsm.set_active(true)

# --- Idle State ---
func _on_idle_enter() -> void:
	print("[DroneAgent] IDLE: Waiting for instructions. Battery: ", round(battery), "%")
	patrol_time = 0.0

func _on_idle_update(delta: float) -> void:
	if enemy_detected:
		_hsm.dispatch(&"attack")
		return
	if battery < 20.0:
		_hsm.dispatch(&"recharge")
		return
		
	patrol_time += delta
	if patrol_time > 2.0:
		_hsm.dispatch(&"patrol")

# --- Patrol State ---
func _on_patrol_enter() -> void:
	print("[DroneAgent] PATROL: Starting patrol route...")

func _on_patrol_update(delta: float) -> void:
	battery -= delta * 5.0 # Consume battery
	
	if enemy_detected:
		_hsm.dispatch(&"attack")
		return
	if battery < 20.0:
		_hsm.dispatch(&"recharge")
		return

# --- Attack State ---
func _on_attack_enter() -> void:
	print("[DroneAgent] ATTACK: Engaging target! PEW PEW!")
	
func _on_attack_update(delta: float) -> void:
	battery -= delta * 20.0
	if not enemy_detected:
		print("[DroneAgent] ATTACK: Target lost.")
		_hsm.dispatch(&"idle")
	elif battery <= 0.0:
		print("[DroneAgent] ATTACK: Critical battery failure!")
		_hsm.dispatch(&"recharge")

# --- Recharge State ---
func _on_recharge_enter() -> void:
	print("[DroneAgent] RECHARGE: Docking...")
	
func _on_recharge_update(delta: float) -> void:
	battery += delta * 40.0
	if battery >= 100.0:
		battery = 100.0
		print("[DroneAgent] RECHARGE: Battery full.")
		_hsm.dispatch(&"idle")
